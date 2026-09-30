--!strict
-- Carrying eggs and characters overhead: movement penalties, snatching, dropping,
-- returning items home, delivery into your own plot (ownership transfer), and the owner's
-- pen-slot actions (pick up / place). Server-authoritative: the client only sees results.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Tags = require(Shared.Config.Tags)
local Characters = require(Shared.Config.Characters)
local Sizes = require(Shared.Config.Sizes)
local Formulas = require(Shared.Util.Formulas)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local ModelUtil = require(Shared.Visual.ModelUtil)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local IncomeService = require(script.Parent.IncomeService)
local HatchService = require(script.Parent.HatchService)
local IndexService = require(script.Parent.IndexService)
local EggSpawnService = require(script.Parent.EggSpawnService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Prompts = require(script.Parent.Parent.Lib.Prompts)
local Remote = require(script.Parent.Parent.Lib.Remote)
local World = require(script.Parent.Parent.Lib.World)

type Item = Types.Item
type Plot = PlotService.Plot

export type Origin = "Wild" | "Festival" | "Own" | "Stolen"

export type CarryInfo = {
	Origin: Origin,
	ZoneId: number?,
	PedestalIndex: number?,
	Festival: boolean?,
	OwnerUserId: number?, -- original owner for Own / Stolen items
	FromSlot: number?,
	Recovered: boolean?, -- the owner took back their own stolen item
}

type Carry = {
	Item: Item,
	Info: CarryInfo,
	Model: Model,
	Prompt: ProximityPrompt,
	StartedAt: number,
	FullWarned: boolean,
}

type Dropped = {
	Item: Item,
	Info: CarryInfo,
	Model: Model,
	Prompt: ProximityPrompt,
	ExpiresAt: number,
}

local CarryService = {}

local carries: { [Player]: Carry } = {}
local dropped: { Dropped } = {}
local shoulderBackup: { [Motor6D]: CFrame? } = {}

-- (player, item, info, slotIndex?) after a carried item is delivered into the player's base
CarryService.Delivered = Signal.new() :: Signal.Signal<Player, Item, CarryInfo, number?>
-- (thief, owner, item) when a stolen item crosses into the thief's plot
CarryService.Stolen = Signal.new() :: Signal.Signal<Player, Player?, Item>
-- (player, item, info) whenever someone starts carrying
CarryService.Started = Signal.new() :: Signal.Signal<Player, Item, CarryInfo>

local function playerByUserId(userId: number?): Player?
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function CarryService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function CarryService.Get(player: Player): (Item?, CarryInfo?)
	local carry = carries[player]
	if carry then
		return carry.Item, carry.Info
	end
	return nil, nil
end

local function setShoulders(character: Model, raised: boolean)
	local joints = {}
	for _, name in { "RightShoulder", "LeftShoulder", "Right Shoulder", "Left Shoulder" } do
		local joint = character:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			table.insert(joints, joint)
		end
	end
	for _, joint in joints do
		if raised then
			if shoulderBackup[joint] == nil then
				shoulderBackup[joint] = joint.C0
			end
			local isR6 = string.find(joint.Name, " ") ~= nil
			local rotation = if isR6
				then CFrame.Angles(0, 0, math.rad(if string.find(joint.Name, "Right") then 160 else -160))
				else CFrame.Angles(math.rad(165), 0, 0)
			joint.C0 = (shoulderBackup[joint] :: CFrame) * rotation
		else
			local original = shoulderBackup[joint]
			if original then
				joint.C0 = original
				shoulderBackup[joint] = nil
			end
		end
	end
end

local function setAttributes(player: Player, item: Item?, info: CarryInfo?)
	player:SetAttribute("Carrying", item ~= nil)
	player:SetAttribute("CarryKind", item and item.Kind)
	player:SetAttribute("CarryCharacterId", item and item.CharacterId)
	player:SetAttribute("CarrySizeTier", item and item.SizeTier)
	player:SetAttribute("CarryKg", item and item.Kg)
	player:SetAttribute("CarryMutation", item and item.Mutation)
	player:SetAttribute("CarryAwakened", item and item.Awakened == true)
	player:SetAttribute("CarryRarity", item and Formulas.DisplayRarity(item))
	player:SetAttribute("CarryZone", if info and (info.Origin == "Wild") then info.ZoneId else 0)
	player:SetAttribute("CarryOrigin", info and info.Origin)
	player:SetAttribute("CarryOwner", if info and info.OwnerUserId then info.OwnerUserId else 0)
	player:SetAttribute("CarryHatchRemaining", if item and item.Kind == "Egg" then HatchService.Remaining(item) else nil)
end

-- origin an item has once `newCarrier` holds it
local function transferInfo(info: CarryInfo, newCarrier: Player): CarryInfo
	if info.Origin == "Wild" or info.Origin == "Festival" then
		return table.clone(info)
	end
	local copy = table.clone(info)
	if info.OwnerUserId == newCarrier.UserId then
		copy.Origin = "Own"
		copy.Recovered = info.Origin == "Stolen" or info.Recovered == true
	else
		copy.Origin = "Stolen"
	end
	return copy
end

local function onSnatch(carry: Carry, thief: Player)
	local victim: Player? = nil
	for player, current in carries do
		if current == carry then
			victim = player
		end
	end
	if not victim or victim == thief then
		return
	end
	if carries[thief] then
		AnnouncementService.Error(thief, "Your hands are full!")
		return
	end
	if SpeedService.IsStunned(thief) then
		return
	end
	if PlotService.IsInOwnPlot(victim) then
		AnnouncementService.Error(thief, "They're safe inside their base!")
		return
	end
	local item, info = CarryService.EndCarry(victim)
	if not item or not info then
		return
	end
	local newInfo = transferInfo(info, thief)
	if not CarryService.StartCarry(thief, item, newInfo) then
		if not CarryService.StartCarry(victim, item, info) then
			CarryService.ReturnHome(item, info)
		end
		return
	end
	AnnouncementService.Notify(victim, thief.DisplayName .. " snatched your " .. Characters.Get(item.CharacterId).DisplayName .. "!", "Theft")
	AnnouncementService.Notify(thief, "Snatched!", "Success")
	local owner = playerByUserId(info.OwnerUserId)
	if owner and owner ~= victim and owner ~= thief then
		Remote.Fire("TheftAlert", owner, { ThiefUserId = thief.UserId, ThiefName = thief.DisplayName, CharacterId = item.CharacterId })
	end
end

function CarryService.StartCarry(player: Player, item: Item, info: CarryInfo): boolean
	if carries[player] then
		return false
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") or not World.Humanoid(player) then
		return false
	end
	local model = PlotService.BuildItemModel(item)
	model.Name = "CarriedItem"
	if item.Kind == "Character" then
		model:ScaleTo(model:GetScale() * 0.8)
	end
	local root = ModelUtil.Weld(model)
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.25, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = root
	weld.Parent = root
	model.Parent = character
	CollectionService:AddTag(model, Tags.CarriedItem)

	local prompt = Prompts.Create(root, {
		Name = "SnatchPrompt",
		ActionText = "Snatch",
		ObjectText = player.DisplayName,
		HoldDuration = GameSettings.SnatchHoldTime,
		Range = GameSettings.InteractRange,
		KeyCode = Enum.KeyCode.E,
	})
	prompt:SetAttribute("CarrierUserId", player.UserId)
	local carry: Carry = { Item = item, Info = info, Model = model, Prompt = prompt, StartedAt = os.clock(), FullWarned = false }
	Prompts.OnTriggered(prompt, function()
		return GameSettings.SnatchHoldTime
	end, function(thief)
		onSnatch(carry, thief)
	end)
	carries[player] = carry
	local size = Sizes.Get(item.SizeTier)
	SpeedService.SetCarryModifier(player, size.Carry, size.Jump)
	setShoulders(character, true)
	setAttributes(player, item, info)
	CarryService.Started:Fire(player, item, info)
	return true
end

-- Stops carrying without deciding where the item goes. Returns it to the caller.
function CarryService.EndCarry(player: Player): (Item?, CarryInfo?)
	local carry = carries[player]
	if not carry then
		return nil, nil
	end
	carries[player] = nil
	carry.Model:Destroy()
	SpeedService.ClearCarryModifier(player)
	if player.Character then
		setShoulders(player.Character, false)
	end
	setAttributes(player, nil, nil)
	return carry.Item, carry.Info
end

-- Put an item into a specific pen slot (slot must be free)
function CarryService.PlaceInSlot(player: Player, item: Item, slotIndex: number): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local key = tostring(slotIndex)
	if data.Pen[key] ~= nil or slotIndex > PlotService.ActiveSlots(player) then
		return false
	end
	if item.Kind == "Egg" then
		HatchService.StartIncubation(player, item)
	end
	data.Pen[key] = item
	DataService.Changed(player, "Pen")
	PlotService.RenderSlot(player, slotIndex)
	PlotService.RefreshSlots(player)
	IncomeService.Recalculate(player)
	if item.Kind == "Character" then
		IndexService.Discover(player, item)
	end
	return true
end

function CarryService.StoreInInventory(player: Player, item: Item, force: boolean?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	if #data.Inventory >= GameSettings.InventoryCapacity and not force then
		return false
	end
	HatchService.Pause(item)
	table.insert(data.Inventory, item)
	DataService.Changed(player, "Inventory")
	if item.Kind == "Character" then
		IndexService.Discover(player, item)
	end
	return true
end

-- Give an item to a player: preferred slot -> first free slot -> inventory (-> forced)
function CarryService.GiveToPlayer(player: Player, item: Item, preferredSlot: number?, force: boolean?): (boolean, number?)
	local data = DataService.Get(player)
	if not data then
		return false, nil
	end
	if preferredSlot and data.Pen[tostring(preferredSlot)] == nil and preferredSlot <= PlotService.ActiveSlots(player) then
		if CarryService.PlaceInSlot(player, item, preferredSlot) then
			return true, preferredSlot
		end
	end
	local free = PlotService.FirstFreeSlot(player)
	if free and CarryService.PlaceInSlot(player, item, free) then
		return true, free
	end
	if CarryService.StoreInInventory(player, item, force) then
		return true, nil
	end
	return false, nil
end

-- Send an owned item back to its original owner (or its pedestal for wild eggs)
local function sendHome(item: Item, info: CarryInfo)
	if info.Origin == "Wild" or info.Origin == "Festival" then
		if info.ZoneId and info.PedestalIndex then
			EggSpawnService.ReturnEgg(item, info.ZoneId, info.PedestalIndex, info.Origin == "Festival")
		end
		return
	end
	local owner = playerByUserId(info.OwnerUserId)
	if owner then
		CarryService.GiveToPlayer(owner, item, info.FromSlot, true)
		if info.Origin == "Stolen" then
			AnnouncementService.Notify(owner, Characters.Get(item.CharacterId).DisplayName .. " made it back home!", "Success")
		end
	end
end

CarryService.ReturnHome = sendHome

local function removeDropped(entry: Dropped)
	local index = table.find(dropped, entry)
	if index then
		table.remove(dropped, index)
	end
	entry.Model:Destroy()
end

-- Drops the carried item on the ground where anyone can grab it for 10 seconds.
function CarryService.Drop(player: Player, reason: string?): boolean
	local root = World.Root(player)
	local position = if root then root.Position else nil
	local item, info = CarryService.EndCarry(player)
	if not item or not info then
		return false
	end
	if not position then
		sendHome(item, info)
		return true
	end
	local model = PlotService.BuildItemModel(item)
	model.Name = "DroppedItem"
	local groundY = position.Y - 3
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { model }
	if player.Character then
		table.insert(filter, player.Character)
	end
	rayParams.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(position, Vector3.new(0, -40, 0), rayParams)
	if hit then
		groundY = hit.Position.Y
	end
	model:PivotTo(CFrame.new(position.X, groundY, position.Z))
	local root2 = model.PrimaryPart :: BasePart
	local prompt = Prompts.Create(root2, {
		Name = "GrabPrompt",
		ActionText = "Grab",
		ObjectText = Characters.Get(item.CharacterId).DisplayName,
		HoldDuration = GameSettings.GrabHoldTime,
		Range = GameSettings.InteractRange,
	})
	model:SetAttribute("CharacterId", item.CharacterId)
	model:SetAttribute("Rarity", Formulas.DisplayRarity(item))
	model:SetAttribute("SizeTier", item.SizeTier)
	model:SetAttribute("Kg", item.Kg)
	model:SetAttribute("Mutation", item.Mutation)
	model:SetAttribute("Dropped", true)
	model:SetAttribute("ExpiresAt", workspace:GetServerTimeNow() + GameSettings.DroppedItemLifetime)
	CollectionService:AddTag(model, Tags.WorldEgg)
	model.Parent = workspace
	local entry: Dropped = {
		Item = item,
		Info = info,
		Model = model,
		Prompt = prompt,
		ExpiresAt = os.clock() + GameSettings.DroppedItemLifetime,
	}
	table.insert(dropped, entry)
	Prompts.OnTriggered(prompt, function()
		return GameSettings.GrabHoldTime
	end, function(grabber)
		if table.find(dropped, entry) == nil or carries[grabber] or SpeedService.IsStunned(grabber) then
			return
		end
		removeDropped(entry)
		if not CarryService.StartCarry(grabber, entry.Item, transferInfo(entry.Info, grabber)) then
			sendHome(entry.Item, entry.Info)
		end
	end)
	Remote.FireAll("Effect", { Type = "Drop", Position = position, Reason = reason })
	return true
end

-- Guardian catch: wild eggs teleport straight back to their pedestal; anything else drops.
function CarryService.KnockOut(player: Player)
	local _, info = CarryService.Get(player)
	if not info then
		return
	end
	if info.Origin == "Wild" or info.Origin == "Festival" then
		local item, carryInfo = CarryService.EndCarry(player)
		if item and carryInfo then
			sendHome(item, carryInfo)
		end
	else
		CarryService.Drop(player, "Caught")
	end
end

local function deliver(player: Player, carry: Carry)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local info = carry.Info
	if info.Origin == "Own" and not info.Recovered then
		return
	end
	local item = carry.Item
	if info.Origin == "Own" then
		-- the owner carried their stolen chibi back home
		CarryService.EndCarry(player)
		CarryService.GiveToPlayer(player, item, info.FromSlot, true)
		AnnouncementService.Notify(player, "Recovered " .. Characters.Get(item.CharacterId).DisplayName .. "!", "Success")
		return
	end
	local slotBefore = PlotService.FirstFreeSlot(player)
	local canPlace = slotBefore ~= nil or #data.Inventory < GameSettings.InventoryCapacity
	if not canPlace then
		if not carry.FullWarned then
			carry.FullWarned = true
			AnnouncementService.Error(player, "Your pen and inventory are full! Sell or fuse something first.")
		end
		return
	end
	CarryService.EndCarry(player)
	local ok, slot = CarryService.GiveToPlayer(player, item, nil, false)
	if not ok then
		if not CarryService.StartCarry(player, item, info) then
			CarryService.GiveToPlayer(player, item, nil, true)
		end
		return
	end
	if info.Origin == "Wild" or info.Origin == "Festival" then
		data.Stats.EggsGrabbed += 1
	elseif info.Origin == "Stolen" then
		data.Stats.EggsStolen += 1
		local owner = playerByUserId(info.OwnerUserId)
		if owner then
			AnnouncementService.Notify(owner, player.DisplayName .. " stole your " .. Characters.Get(item.CharacterId).DisplayName .. "!", "Theft", 5)
		end
		AnnouncementService.Notify(player, "Heist complete! " .. Characters.Get(item.CharacterId).DisplayName .. " is yours now.", "Success")
		CarryService.Stolen:Fire(player, owner, item)
	end
	DataService.Changed(player, "Stats")
	if slot == nil then
		AnnouncementService.Notify(player, "Pen full — sent to your inventory.", "Info")
	end
	Remote.Fire("Effect", player, { Type = "Deliver", CharacterId = item.CharacterId })
	CarryService.Delivered:Fire(player, item, info, slot)
end

local function deliveryLoop()
	for player, carry in carries do
		if player.Parent ~= Players then
			carries[player] = nil
			continue
		end
		if PlotService.IsInOwnPlot(player) then
			deliver(player, carry)
		end
	end
	local now = os.clock()
	for index = #dropped, 1, -1 do
		local entry = dropped[index]
		if now >= entry.ExpiresAt then
			removeDropped(entry)
			sendHome(entry.Item, entry.Info)
		end
	end
end

-- Owner interactions with their own pen slots
local function onSlotTriggered(player: Player, plot: Plot, slotIndex: number, _held: number)
	if plot.Owner ~= player then
		return -- raids are handled by StealService
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local key = tostring(slotIndex)
	local occupant = data.Pen[key]
	local carry = carries[player]
	if carry then
		if occupant then
			AnnouncementService.Error(player, "That slot is taken.")
			return
		end
		if slotIndex > PlotService.ActiveSlots(player) then
			AnnouncementService.Error(player, "Upgrade your pen to use this slot.")
			return
		end
		local item, info = CarryService.EndCarry(player)
		if item and info then
			if CarryService.PlaceInSlot(player, item, slotIndex) then
				if info.Origin ~= "Own" then
					CarryService.Delivered:Fire(player, item, info, slotIndex)
				end
			else
				CarryService.StartCarry(player, item, info)
			end
		end
		return
	end
	if occupant then
		data.Pen[key] = nil
		HatchService.Pause(occupant)
		DataService.Changed(player, "Pen")
		PlotService.RenderSlot(player, slotIndex)
		IncomeService.Recalculate(player)
		if not CarryService.StartCarry(player, occupant, { Origin = "Own", OwnerUserId = player.UserId, FromSlot = slotIndex }) then
			CarryService.PlaceInSlot(player, occupant, slotIndex)
		end
	end
end

-- Take an item out of a pen for a thief (called by StealService after validation)
function CarryService.TakeFromPen(owner: Player, slotIndex: number, thief: Player): boolean
	local data = DataService.Get(owner)
	if not data or carries[thief] then
		return false
	end
	local key = tostring(slotIndex)
	local item = data.Pen[key]
	if not item then
		return false
	end
	data.Pen[key] = nil
	HatchService.Pause(item)
	DataService.Changed(owner, "Pen")
	PlotService.RenderSlot(owner, slotIndex)
	IncomeService.Recalculate(owner)
	if not CarryService.StartCarry(thief, item, { Origin = "Stolen", OwnerUserId = owner.UserId, FromSlot = slotIndex }) then
		CarryService.PlaceInSlot(owner, item, slotIndex)
		return false
	end
	return true
end

-- Make sure nothing is lost when players leave mid-carry
local function onReleasing(player: Player, _data: Types.ProfileData)
	-- items this player owns that others are carrying or that lie on the ground
	for carrier, carry in carries do
		if carrier ~= player and carry.Info.OwnerUserId == player.UserId and carry.Info.Origin ~= "Wild" then
			local item = CarryService.EndCarry(carrier)
			if item then
				CarryService.GiveToPlayer(player, item, carry.Info.FromSlot, true)
				AnnouncementService.Notify(carrier, "The owner left — the chibi went home.", "Info")
			end
		end
	end
	for index = #dropped, 1, -1 do
		local entry = dropped[index]
		if entry.Info.OwnerUserId == player.UserId and entry.Info.Origin ~= "Wild" and entry.Info.Origin ~= "Festival" then
			removeDropped(entry)
			CarryService.GiveToPlayer(player, entry.Item, entry.Info.FromSlot, true)
		end
	end
	-- whatever this player is carrying
	local carry = carries[player]
	if carry then
		local item, info = CarryService.EndCarry(player)
		if item and info then
			if info.Origin == "Own" then
				CarryService.GiveToPlayer(player, item, info.FromSlot, true)
			else
				sendHome(item, info)
			end
		end
	end
end

local function hookCharacter(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				if carries[player] then
					CarryService.Drop(player, "Died")
				end
			end)
		end
	end)
	player.CharacterRemoving:Connect(function()
		if carries[player] then
			CarryService.Drop(player, "Respawn")
		end
	end)
end

function CarryService.Init()
	EggSpawnService.CanGrab = function(player: Player): boolean
		if carries[player] then
			AnnouncementService.Error(player, "You're already carrying something!")
			return false
		end
		if SpeedService.IsStunned(player) or not World.Humanoid(player) then
			return false
		end
		return true
	end
	Remote.OnEvent("StoreCarried", function(player)
		local carry = carries[player]
		if not carry or carry.Info.Origin ~= "Own" then
			return
		end
		if not PlotService.IsInOwnPlot(player) then
			AnnouncementService.Error(player, "Go back to your base to store it.")
			return
		end
		local data = DataService.Get(player)
		if data and #data.Inventory >= GameSettings.InventoryCapacity then
			AnnouncementService.Error(player, "Inventory full!")
			return
		end
		local item = CarryService.EndCarry(player)
		if item then
			CarryService.StoreInInventory(player, item, true)
			AnnouncementService.Notify(player, "Stored in inventory.", "Info")
		end
	end, 4)
end

function CarryService.Start()
	EggSpawnService.EggGrabbed:Connect(function(player, item, zoneId, index, festival)
		local ok = CarryService.StartCarry(player, item, {
			Origin = if festival then "Festival" else "Wild",
			ZoneId = zoneId,
			PedestalIndex = index,
			Festival = festival,
		})
		if not ok then
			EggSpawnService.ReturnEgg(item, zoneId, index, festival)
		end
	end)
	PlotService.SlotTriggered:Connect(onSlotTriggered)
	DataService.Releasing:Connect(onReleasing)
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			deliveryLoop()
		end
	end)
end

return CarryService
