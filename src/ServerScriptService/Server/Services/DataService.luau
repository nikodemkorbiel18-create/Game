--!strict
-- Session-locked player profiles (ProfileStore), data migrations, and replication of
-- profile state to the owning client. Other services read and mutate profile data through
-- DataService.Get and call DataService.Changed so the client sees the update.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Items = require(Shared.Config.Items)
local NumberFormat = require(Shared.Util.NumberFormat)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local ProfileStore = require(script.Parent.Parent.Lib.ProfileStore)
local Remote = require(script.Parent.Parent.Lib.Remote)

type ProfileData = Types.ProfileData

local DataService = {}

local TEMPLATE: ProfileData = {
	DataVersion = GameSettings.DataVersion,
	Cash = 0,
	TotalEarned = 0,
	Speed = 0,
	TreadmillTier = 0,
	PenLevel = 1,
	BarrierLevel = 1,
	Rebirths = 0,
	EquippedTrail = "",
	OwnedTrails = {},
	Traps = Items.OfudaTrap.StartCount,
	SmokeBombs = 0,
	Register = 0,
	Pen = {},
	Inventory = {},
	Index = {},
	BossCleared = false,
	ProcessedPurchases = {},
	RedeemedCodes = {},
	Login = { Streak = 0, LastDay = 0, ClaimedDay = 0 },
	LastOnline = 0,
	FirstJoin = 0,
	Playtime = 0,
	Tutorial = { Step = 1, Done = false, GiftGiven = false },
	Settings = { Music = 0.6, Sfx = 0.8, LowGraphics = false, HideTrails = false },
	Fusion = {},
	Incubator = {},
	Boosts = { LuckEndsAt = 0 },
	Titles = {},
	EquippedTitle = "",
	GroupRewardClaimed = false,
	SeenReveals = {},
	Stats = { HighestIncome = 0, EggsStolen = 0, Hatched = 0, EggsGrabbed = 0 },
	FirstEggPlaced = false,
}

-- Data migrations: MIGRATIONS[n] upgrades a profile from version n - 1 to n.
-- Add a function here and bump GameSettings.DataVersion whenever the saved shape changes.
local MIGRATIONS: { [number]: (data: any) -> () } = {
	[1] = function(_data)
		-- initial version
	end,
}

type Profile = {
	Data: any,
	LastSavedData: any,
	OnSessionEnd: any,
	OnSave: any,
	IsActive: (self: any) -> boolean,
	EndSession: (self: any) -> (),
	Save: (self: any) -> (),
	AddUserId: (self: any, userId: number) -> (),
	Reconcile: (self: any) -> (),
}

local store = ProfileStore.New(GameSettings.DataStoreName, TEMPLATE)
ProfileStore.SetConstant("AUTO_SAVE_PERIOD", GameSettings.AutosaveInterval)

local profiles: { [Player]: Profile } = {}
local derived: { [Player]: { [string]: any } } = {}
local dirty: { [Player]: { [string]: boolean } } = {}
local previousOnline: { [Player]: number } = {}

-- Fired once the profile is loaded: (player, data, previousLastOnline)
DataService.Loaded = Signal.new() :: Signal.Signal<Player, ProfileData, number>
-- Fired right before the session ends so services can write final state: (player, data)
DataService.Releasing = Signal.new() :: Signal.Signal<Player, ProfileData>

local SYNC_EXCLUDE = { ProcessedPurchases = true }

local function migrate(data: any)
	local version = data.DataVersion or 0
	for target = version + 1, GameSettings.DataVersion do
		local step = MIGRATIONS[target]
		if step then
			step(data)
		end
		data.DataVersion = target
	end
end

local function makeLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = folder
	local speed = Instance.new("StringValue")
	speed.Name = "Speed"
	speed.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player: Player, data: ProfileData)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local cash = folder:FindFirstChild("Cash") :: StringValue?
	local speed = folder:FindFirstChild("Speed") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if cash then
		cash.Value = NumberFormat.Cash(data.Cash)
	end
	if speed then
		speed.Value = NumberFormat.Short(data.Speed)
	end
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	player:SetAttribute("Speed", data.Speed)
	player:SetAttribute("Rebirths", data.Rebirths)
end

local function onPlayerAdded(player: Player)
	local profile: Profile? = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	}) :: any
	if profile == nil then
		player:Kick("We couldn't load your data. Please rejoin!")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin!")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	local data = profile.Data :: ProfileData
	migrate(data)
	local now = os.time()
	if data.FirstJoin == 0 then
		data.FirstJoin = now
	end
	previousOnline[player] = data.LastOnline
	data.LastOnline = now
	profile.OnSave:Connect(function()
		if profile:IsActive() then
			(profile.Data :: ProfileData).LastOnline = os.time()
		end
	end)
	profiles[player] = profile
	derived[player] = derived[player] or {}
	makeLeaderstats(player)
	updateLeaderstats(player, data)
	player:SetAttribute("DataLoaded", true)
	DataService.Loaded:Fire(player, data, previousOnline[player])
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		local data = profile.Data :: ProfileData
		-- run releasing handlers synchronously so they can write final state
		DataService.Releasing:FireNow(player, data)
		data.LastOnline = os.time()
		profile:EndSession()
		profiles[player] = nil
	end
	derived[player] = nil
	dirty[player] = nil
	previousOnline[player] = nil
end

function DataService.Get(player: Player): ProfileData?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile.Data :: ProfileData
	end
	return nil
end

function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?): ProfileData?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.Get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.LoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		if player.Parent == Players then
			table.insert(list, player)
		end
	end
	return list
end

-- Mark profile keys as changed so they replicate to the owner's client this frame.
function DataService.Changed(player: Player, ...: string)
	local set = dirty[player]
	if not set then
		set = {}
		dirty[player] = set
	end
	for _, key in { ... } do
		set[key] = true
	end
end

-- Derived (non-saved) values the client needs, e.g. IncomePerSecond or owned passes.
function DataService.SetDerived(player: Player, key: string, value: any)
	local values = derived[player]
	if not values then
		values = {}
		derived[player] = values
	end
	if values[key] == value and type(value) ~= "table" then
		return
	end
	values[key] = value
	DataService.Changed(player, "@" .. key)
end

function DataService.GetDerived(player: Player, key: string): any
	local values = derived[player]
	return values and values[key]
end

local function snapshot(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local copy = {}
	for key, value in data :: any do
		if not SYNC_EXCLUDE[key] then
			copy[key] = value
		end
	end
	return { Data = copy, Derived = derived[player] or {} }
end

local function flush()
	for player, keys in dirty do
		local data = DataService.Get(player)
		if data and next(keys) then
			local payload = {}
			local derivedPayload = {}
			local hasDerived = false
			local touchesLeaderstats = false
			for key in keys do
				if string.sub(key, 1, 1) == "@" then
					local name = string.sub(key, 2)
					derivedPayload[name] = (derived[player] or {})[name]
					hasDerived = true
				elseif not SYNC_EXCLUDE[key] then
					payload[key] = (data :: any)[key]
					if key == "Cash" or key == "Speed" or key == "Rebirths" then
						touchesLeaderstats = true
					end
				end
			end
			if hasDerived then
				payload["@Derived"] = derivedPayload
			end
			Remote.Fire("StateChanged", player, payload)
			if touchesLeaderstats then
				updateLeaderstats(player, data)
			end
		end
		dirty[player] = nil
	end
end

-- Saves immediately and waits until the save containing `purchaseId` has landed.
function DataService.SaveAndConfirm(player: Player, purchaseId: string, timeout: number?): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	profile:Save()
	local deadline = os.clock() + (timeout or 20)
	while os.clock() < deadline do
		local saved = profile.LastSavedData :: any
		if saved and saved.ProcessedPurchases and table.find(saved.ProcessedPurchases, purchaseId) then
			return true
		end
		if not profile:IsActive() then
			return false
		end
		task.wait(0.25)
	end
	return false
end

function DataService.Init()
	Remote.OnInvoke("GetState", function(player)
		local data = DataService.WaitFor(player, 30)
		if not data then
			return { Ok = false }
		end
		local state = snapshot(player)
		return { Ok = true, State = state, ServerTime = os.time() }
	end, 2)
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	RunService.Heartbeat:Connect(flush)
	-- playtime
	task.spawn(function()
		while true do
			task.wait(1)
			for _, profile in profiles do
				if profile:IsActive() then
					(profile.Data :: ProfileData).Playtime += 1
				end
			end
		end
	end)
end

return DataService
