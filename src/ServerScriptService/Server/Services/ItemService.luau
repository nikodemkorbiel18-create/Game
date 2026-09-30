--!strict
-- Consumable items: Sticky Ofuda Traps (freeze Guardians that touch them) and Smoke Bombs
-- (break every nearby Guardian's line of sight).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Rebirths = require(Shared.Config.Rebirths)
local Tags = require(Shared.Config.Tags)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local GuardianService = require(script.Parent.GuardianService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local World = require(script.Parent.Parent.Lib.World)

local ItemService = {}

type Trap = { Part: BasePart, Owner: Player, ExpiresAt: number }

local traps: { Trap } = {}
local lastUse: { [Player]: { [string]: number } } = {}

function ItemService.TrapCapacity(player: Player): number
	local data = DataService.Get(player)
	local rebirths = if data then data.Rebirths else 0
	return Items.OfudaTrap.Capacity + rebirths * Rebirths.Rewards.TrapCapacity + PassService.TrapCapacityBonus(player)
end

function ItemService.Capacity(player: Player, itemId: string): number
	if itemId == "OfudaTrap" then
		return ItemService.TrapCapacity(player)
	end
	return Items.SmokeBomb.Capacity
end

function ItemService.Count(player: Player, itemId: string): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return if itemId == "OfudaTrap" then data.Traps else data.SmokeBombs
end

-- Adds items up to capacity (force ignores capacity, for rewards). Returns amount added.
function ItemService.Add(player: Player, itemId: string, amount: number, force: boolean?): number
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return 0
	end
	local current = ItemService.Count(player, itemId)
	local room = if force then amount else math.max(0, ItemService.Capacity(player, itemId) - current)
	local added = math.min(amount, room)
	if itemId == "OfudaTrap" then
		data.Traps += added
		DataService.Changed(player, "Traps")
	else
		data.SmokeBombs += added
		DataService.Changed(player, "SmokeBombs")
	end
	return added
end

local function onCooldown(player: Player, key: string, cooldown: number): boolean
	local times = lastUse[player]
	if not times then
		times = {}
		lastUse[player] = times
	end
	local now = os.clock()
	if times[key] and now - times[key] < cooldown then
		return true
	end
	times[key] = now
	return false
end

local function groundPosition(player: Player): Vector3?
	local root = World.Root(player)
	if not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)
end

local function placeTrap(player: Player)
	local data = DataService.Get(player)
	if not data or data.Traps <= 0 then
		AnnouncementService.Error(player, "No Ofuda Traps left! Buy more at the Item Shop.")
		return
	end
	if SpeedService.IsStunned(player) or onCooldown(player, "Trap", Items.OfudaTrap.Cooldown) then
		return
	end
	local owned = 0
	for _, trap in traps do
		if trap.Owner == player then
			owned += 1
		end
	end
	if owned >= Items.OfudaTrap.MaxPlacedPerPlayer then
		AnnouncementService.Error(player, "You can only have " .. Items.OfudaTrap.MaxPlacedPerPlayer .. " traps out at once.")
		return
	end
	local position = groundPosition(player)
	if not position or PlotService.PlotAt(position) then
		AnnouncementService.Error(player, "Traps only work out in the zones.")
		return
	end
	data.Traps -= 1
	DataService.Changed(player, "Traps")
	local part = Instance.new("Part")
	part.Name = "OfudaTrap"
	part.Size = Vector3.new(3, 0.15, 3)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, math.rad(math.random(0, 90)), 0)
	part.Color = Color3.fromHex("#F2E8CF")
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local seal = Instance.new("Part")
	seal.Name = "Seal"
	seal.Size = Vector3.new(1.2, 0.17, 1.2)
	seal.CFrame = part.CFrame
	seal.Color = Color3.fromHex("#D00000")
	seal.Material = Enum.Material.Neon
	seal.Anchored = true
	seal.CanCollide = false
	seal.CanQuery = false
	seal.CanTouch = false
	seal.Parent = part
	part:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(part, Tags.Trap)
	part.Parent = workspace
	table.insert(traps, { Part = part :: BasePart, Owner = player, ExpiresAt = os.clock() + Items.OfudaTrap.Lifetime })
end

local function useSmoke(player: Player)
	local data = DataService.Get(player)
	if not data or data.SmokeBombs <= 0 then
		AnnouncementService.Error(player, "No Smoke Bombs! Buy some at the Item Shop.")
		return
	end
	if onCooldown(player, "Smoke", Items.SmokeBomb.Cooldown) then
		return
	end
	local root = World.Root(player)
	if not root then
		return
	end
	data.SmokeBombs -= 1
	DataService.Changed(player, "SmokeBombs")
	GuardianService.BlindNear(root.Position, Items.SmokeBomb.Radius, Items.SmokeBomb.Duration)
	Remote.FireAll("Effect", { Type = "Smoke", Position = root.Position, Duration = Items.SmokeBomb.Duration })
end

local function checkTraps()
	local now = os.clock()
	for index = #traps, 1, -1 do
		local trap = traps[index]
		local expired = now >= trap.ExpiresAt or trap.Part.Parent == nil
		if not expired then
			local freeze = PassService.TrapFreeze(trap.Owner)
			local frozen = GuardianService.FreezeNear(trap.Part.Position, Items.OfudaTrap.TriggerRadius, freeze)
			if frozen > 0 then
				expired = true
				Remote.FireAll("Effect", { Type = "TrapSprung", Position = trap.Part.Position })
				if trap.Owner.Parent then
					AnnouncementService.Notify(trap.Owner, "Your Ofuda Trap froze a Guardian!", "Success")
				end
			end
		end
		if expired then
			trap.Part:Destroy()
			table.remove(traps, index)
		end
	end
end

function ItemService.Init()
	Remote.OnEvent("PlaceTrap", placeTrap, 3)
	Remote.OnEvent("UseSmoke", useSmoke, 3)
end

function ItemService.Start()
	DataService.Loaded:Connect(function(player)
		DataService.SetDerived(player, "TrapCapacity", ItemService.TrapCapacity(player))
	end)
	PassService.Changed:Connect(function(player)
		DataService.SetDerived(player, "TrapCapacity", ItemService.TrapCapacity(player))
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		for index = #traps, 1, -1 do
			if traps[index].Owner == player then
				traps[index].Part:Destroy()
				table.remove(traps, index)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			checkTraps()
		end
	end)
end

return ItemService
