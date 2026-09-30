--!strict
-- Speed stat, server-owned WalkSpeed/JumpHeight (with carry, slow and stun modifiers),
-- the treadmill (AFK Speed gain) and the Roblox group bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Endgame = require(Shared.Config.Endgame)
local Treadmills = require(Shared.Config.Treadmills)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local Signal = require(Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Prompts = require(script.Parent.Parent.Lib.Prompts)
local World = require(script.Parent.Parent.Lib.World)

local SpeedService = {}

local DEFAULT_JUMP_HEIGHT = 7.2

type Slow = { Multiplier: number, EndsAt: number }
type Modifiers = {
	Carry: number,
	CarryJump: number,
	Slows: { [string]: Slow },
	StunnedUntil: number,
}

local modifiers: { [Player]: Modifiers } = {}
local onTreadmill: { [Player]: boolean } = {}

SpeedService.TreadmillChanged = Signal.new() :: Signal.Signal<Player>

local function mods(player: Player): Modifiers
	local current = modifiers[player]
	if not current then
		current = { Carry = 1, CarryJump = 1, Slows = {}, StunnedUntil = 0 }
		modifiers[player] = current
	end
	return current
end

function SpeedService.BaseWalkSpeed(player: Player): number
	local data = DataService.Get(player)
	return Formulas.WalkSpeed(if data then data.Speed else 0)
end

function SpeedService.Apply(player: Player)
	local humanoid = World.Humanoid(player)
	if not humanoid then
		return
	end
	local current = mods(player)
	local now = os.clock()
	local walk = SpeedService.BaseWalkSpeed(player) * current.Carry
	for key, slow in current.Slows do
		if slow.EndsAt <= now then
			current.Slows[key] = nil
		else
			walk *= slow.Multiplier
		end
	end
	if player:GetAttribute("InGauntlet") == true then
		walk = math.min(walk, Endgame.Boss.WalkSpeedCap)
	end
	local jump = DEFAULT_JUMP_HEIGHT * current.CarryJump
	if current.StunnedUntil > now then
		walk = 0
		jump = 0
	end
	humanoid.WalkSpeed = walk
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = jump
	player:SetAttribute("WalkSpeed", walk)
end

function SpeedService.SetCarryModifier(player: Player, carry: number, jump: number)
	local current = mods(player)
	current.Carry = carry
	current.CarryJump = jump
	SpeedService.Apply(player)
end

function SpeedService.ClearCarryModifier(player: Player)
	SpeedService.SetCarryModifier(player, 1, 1)
end

function SpeedService.ApplySlow(player: Player, source: string, multiplier: number, duration: number)
	local current = mods(player)
	current.Slows[source] = { Multiplier = multiplier, EndsAt = os.clock() + duration }
	player:SetAttribute("SlowedUntil", os.clock() + duration)
	SpeedService.Apply(player)
	task.delay(duration + 0.05, function()
		if player.Parent then
			SpeedService.Apply(player)
		end
	end)
end

function SpeedService.Stun(player: Player, duration: number)
	local current = mods(player)
	current.StunnedUntil = math.max(current.StunnedUntil, os.clock() + duration)
	player:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + duration)
	SpeedService.Apply(player)
	task.delay(duration + 0.05, function()
		if player.Parent then
			SpeedService.Apply(player)
		end
	end)
end

function SpeedService.IsStunned(player: Player): boolean
	return mods(player).StunnedUntil > os.clock()
end

function SpeedService.AddSpeed(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Speed += amount
	DataService.Changed(player, "Speed")
	SpeedService.Apply(player)
	SpeedService.PublishDerived(player)
end

function SpeedService.Gain(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return Formulas.TreadmillGain({
		TreadmillTier = data.TreadmillTier,
		Trail = if data.EquippedTrail ~= "" then data.EquippedTrail else nil,
		Rebirths = data.Rebirths,
		DoubleSpeed = PassService.Owns(player, "DoubleSpeed"),
	})
end

function SpeedService.PublishDerived(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	DataService.SetDerived(player, "SpeedGain", SpeedService.Gain(player))
	DataService.SetDerived(player, "WalkSpeed", Formulas.WalkSpeed(data.Speed))
end

-- Treadmill look + prompt text for the owner's current tier
function SpeedService.UpdateTreadmill(player: Player)
	local plot = PlotService.Get(player)
	local data = DataService.Get(player)
	if not plot or not data or not plot.Treadmill then
		return
	end
	local treadmill = Treadmills.Get(math.max(1, data.TreadmillTier))
	local unlocked = data.TreadmillTier >= 1
	local model = plot.Treadmill
	model:SetAttribute("Tier", data.TreadmillTier)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and treadmill then
			if descendant.Name == "Belt" then
				descendant.Color = Color3.fromHex(treadmill.Belt)
				local ok, material = pcall(function()
					return (Enum.Material :: any)[treadmill.Material]
				end)
				descendant.Material = if ok and material then material else Enum.Material.SmoothPlastic
				descendant.Transparency = if unlocked then 0 else 0.5
			elseif descendant.Name == "Frame" or descendant.Name == "Rail" then
				descendant.Color = Color3.fromHex(treadmill.Frame)
			elseif descendant.Name == "Accent" or descendant.Name == "Console" then
				descendant.Color = Color3.fromHex(treadmill.Accent)
			end
		end
	end
	local prompt = model:FindFirstChild("TreadmillPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		local nextTier = Treadmills.Get(data.TreadmillTier + 1)
		if nextTier then
			prompt.Enabled = true
			prompt.ActionText = (if unlocked then "Upgrade " else "Unlock ") .. NumberFormat.Cash(nextTier.Price)
			prompt.ObjectText = nextTier.DisplayName
		else
			prompt.Enabled = false
		end
	end
	SpeedService.TreadmillChanged:Fire(player)
end

function SpeedService.BuyTreadmill(player: Player, spend: (Player, number) -> boolean): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local nextTier = Treadmills.Get(data.TreadmillTier + 1)
	if not nextTier then
		return false, "Your treadmill is maxed out!"
	end
	if not spend(player, nextTier.Price) then
		return false, "You need " .. NumberFormat.Cash(nextTier.Price)
	end
	data.TreadmillTier = nextTier.Tier
	DataService.Changed(player, "TreadmillTier")
	SpeedService.UpdateTreadmill(player)
	SpeedService.PublishDerived(player)
	AnnouncementService.Notify(player, nextTier.DisplayName .. " unlocked!", "Success")
	return true, nil
end

-- Hook set by IncomeService (spend cash); used by the treadmill prompt
SpeedService.Spend = nil :: ((Player, number) -> boolean)?

function SpeedService.IsOnTreadmill(player: Player): boolean
	return onTreadmill[player] == true
end

local function tick()
	for _, player in DataService.LoadedPlayers() do
		local data = DataService.Get(player)
		local plot = PlotService.Get(player)
		local root = World.Root(player)
		local standing = false
		if data and plot and root and plot.TreadmillBelt and data.TreadmillTier >= 1 and player:GetAttribute("Carrying") ~= true then
			standing = World.InsideFootprint(root.Position, plot.TreadmillBelt, 8, 0.5)
		end
		if standing ~= (onTreadmill[player] == true) then
			onTreadmill[player] = standing
			player:SetAttribute("OnTreadmill", standing)
		end
		if standing and data then
			local gain = SpeedService.Gain(player)
			data.Speed += gain
			DataService.Changed(player, "Speed")
			SpeedService.Apply(player)
		end
	end
end

local function checkGroup(player: Player)
	local data = DataService.Get(player)
	if not data or GameSettings.GroupId == 0 or data.GroupRewardClaimed then
		return
	end
	local ok, inGroup = pcall(player.IsInGroupAsync, player, GameSettings.GroupId)
	if ok and inGroup then
		data.GroupRewardClaimed = true
		SpeedService.AddSpeed(player, GameSettings.GroupSpeedReward)
		AnnouncementService.Notify(player, "Thanks for joining the group! +" .. NumberFormat.Short(GameSettings.GroupSpeedReward) .. " Speed", "Reward", 5)
	end
end

function SpeedService.CheckGroup(player: Player)
	checkGroup(player)
end

function SpeedService.Init()
	for _, plot in PlotService.All() do
		local model = plot.Treadmill
		if model then
			local anchor = plot.TreadmillBelt or model:FindFirstChildWhichIsA("BasePart")
			if anchor then
				local prompt = Prompts.Create(anchor, {
					Name = "TreadmillPrompt",
					ActionText = "Unlock",
					ObjectText = "Treadmill",
					HoldDuration = 0.3,
					Range = 12,
				})
				Prompts.OnTriggered(prompt, function()
					return 0.3
				end, function(player)
					if plot.Owner ~= player then
						AnnouncementService.Error(player, "That's not your treadmill!")
						return
					end
					local spend = SpeedService.Spend
					if not spend then
						return
					end
					local ok, err = SpeedService.BuyTreadmill(player, spend)
					if not ok and err then
						AnnouncementService.Error(player, err)
					end
				end)
			end
		end
	end
end

function SpeedService.Start()
	DataService.Loaded:Connect(function(player)
		SpeedService.PublishDerived(player)
		SpeedService.Apply(player)
		task.spawn(checkGroup, player)
	end)
	PlotService.PlotAssigned:Connect(function(player)
		SpeedService.UpdateTreadmill(player)
	end)
	PassService.Changed:Connect(function(player)
		SpeedService.PublishDerived(player)
	end)
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			modifiers[player] = nil
			SpeedService.Apply(player)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		modifiers[player] = nil
		onTreadmill[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return SpeedService
