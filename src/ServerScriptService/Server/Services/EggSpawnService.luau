--!strict
-- Zone nests: every EggResetInterval seconds (aligned to os.time, so all servers reset
-- together) each pedestal rolls a new egg: character by rarity weight -> size -> mutation
-- -> cosmetic color. Special rolls may upgrade one pedestal to Secret/Divine/Eternal.
-- Festival pedestals in Station Plaza spawn Festival Eggs during Matsuri Nights.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Tags = require(Shared.Config.Tags)
local Zones = require(Shared.Config.Zones)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local Events = require(Shared.Config.Events)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local EggBuilder = require(Shared.Visual.EggBuilder)

local EventService = require(script.Parent.EventService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Prompts = require(script.Parent.Parent.Lib.Prompts)
local World = require(script.Parent.Parent.Lib.World)

type Item = Types.Item

export type Pedestal = {
	Part: BasePart,
	ZoneId: number, -- 0 for festival pedestals
	Index: number,
	Festival: boolean,
	Egg: Item?,
	Model: Model?,
	Prompt: ProximityPrompt,
}

local EggSpawnService = {}

local pedestals: { Pedestal } = {}
local byKey: { [string]: Pedestal } = {}
local lastReset = -1
local rng = Random.new()

-- Fired when a player grabs an egg: (player, item, zoneId, pedestalIndex, festival)
EggSpawnService.EggGrabbed = Signal.new() :: Signal.Signal<Player, Item, number, number, boolean>
-- Set by CarryService: can this player pick something up right now?
EggSpawnService.CanGrab = nil :: ((Player) -> boolean)?

local function key(zoneId: number, index: number, festival: boolean): string
	return (if festival then "F" else "Z") .. zoneId .. ":" .. index
end

local function rollSize(): number
	local roll = rng:NextNumber() * 100
	local acc = 0
	for _, size in Sizes.List do
		acc += size.Chance
		if roll < acc then
			return size.Rank
		end
	end
	return 3
end

local function rollMutation(): string?
	local mult = EventService.MutationChanceMultiplier()
	local roll = rng:NextNumber() * 100
	local acc = 0
	for _, id in Mutations.Natural do
		acc += Mutations.ById[id].Chance * mult
		if roll < acc then
			return id
		end
	end
	return nil
end

local function makeItem(characterId: string, paletteSize: number, forcedMutation: string?): Item
	local sizeTier = rollSize()
	local size = Sizes.Get(sizeTier)
	return {
		Uid = World.MakeUid(),
		Kind = "Egg",
		CharacterId = characterId,
		SizeTier = sizeTier,
		Kg = math.floor((size.MinKg + (size.MaxKg - size.MinKg) * rng:NextNumber()) * 10) / 10,
		Mutation = forcedMutation or rollMutation(),
		Color = rng:NextInteger(1, math.max(1, paletteSize)),
	}
end

local function pickCharacter(pool: { Characters.Character }): Characters.Character?
	return WeightedRandom.PickList(pool, function(character)
		return character.SpawnWeight
	end, rng)
end

function EggSpawnService.RollZoneEgg(zoneId: number, forcedRarity: string?, forcedMutation: string?): Item?
	local zone = Zones.Get(zoneId)
	local rarity = forcedRarity
	if not rarity then
		local weights = table.clone(zone.RarityWeights)
		-- Server Luck: every tier above the zone's lowest gets x2 weight
		local luck = EventService.ServerLuck()
		local lowestRank = math.huge
		for id in weights do
			lowestRank = math.min(lowestRank, Rarities.Rank(id))
		end
		for id, weight in weights do
			if Rarities.Rank(id) > lowestRank then
				weights[id] = weight * luck
			end
			if id == "Secret" then
				weights[id] *= EventService.SecretChanceMultiplier(zoneId)
			end
		end
		rarity = WeightedRandom.PickMap(weights, rng)
	end
	if not rarity then
		return nil
	end
	local character = pickCharacter(Characters.ForZoneRarity(zoneId, rarity))
	if not character then
		return nil
	end
	return makeItem(character.Id, #zone.EggTheme.Palette, forcedMutation)
end

local function rollFestivalEgg(): Item?
	local rarity = WeightedRandom.PickMap(Events.FestivalRarityWeights, rng)
	local pool = {}
	for _, character in Characters.ForPool("Festival") do
		if character.Rarity == rarity then
			table.insert(pool, character)
		end
	end
	local character = pickCharacter(pool)
	if not character then
		return nil
	end
	return makeItem(character.Id, 4, nil)
end

local function clearPedestal(pedestal: Pedestal)
	if pedestal.Model then
		pedestal.Model:Destroy()
		pedestal.Model = nil
	end
	pedestal.Egg = nil
	pedestal.Prompt.Enabled = false
	pedestal.Part:SetAttribute("HasEgg", false)
end

local function setEgg(pedestal: Pedestal, item: Item)
	clearPedestal(pedestal)
	pedestal.Egg = item
	local model = EggBuilder.Build({
		CharacterId = item.CharacterId,
		SizeTier = item.SizeTier,
		Mutation = item.Mutation,
		Color = item.Color,
		EggModel = item.EggModel,
	})
	model.Name = "Egg_" .. pedestal.Index
	model:PivotTo(pedestal.Part.CFrame * CFrame.new(0, pedestal.Part.Size.Y / 2, 0))
	local character = Characters.Get(item.CharacterId)
	model:SetAttribute("CharacterId", item.CharacterId)
	model:SetAttribute("Rarity", character.Rarity)
	model:SetAttribute("SizeTier", item.SizeTier)
	model:SetAttribute("Kg", item.Kg)
	model:SetAttribute("Mutation", item.Mutation)
	model:SetAttribute("ZoneId", pedestal.ZoneId)
	model:SetAttribute("Festival", pedestal.Festival)
	CollectionService:AddTag(model, Tags.WorldEgg)
	model.Parent = pedestal.Part
	pedestal.Model = model
	pedestal.Prompt.Enabled = true
	pedestal.Part:SetAttribute("HasEgg", true)
end

local function announceIfRare(item: Item, place: string)
	local character = Characters.Get(item.CharacterId)
	local rarity = Rarities.Get(character.Rarity)
	if rarity.Rank >= GameSettings.AnnounceRank then
		AnnouncementService.Announce(
			string.format("A %s EGG APPEARED IN %s!", string.upper(rarity.DisplayName), string.upper(place)),
			rarity.Color2 or rarity.Color,
			"Spawn"
		)
	end
end

local function resetZone(zoneId: number)
	local zone = Zones.Get(zoneId)
	local zonePedestals = {}
	for _, pedestal in pedestals do
		if not pedestal.Festival and pedestal.ZoneId == zoneId then
			local item = EggSpawnService.RollZoneEgg(zoneId)
			if item then
				setEgg(pedestal, item)
				table.insert(zonePedestals, pedestal)
			end
		end
	end
	if #zonePedestals == 0 then
		return
	end
	-- special rolls: at most one pedestal upgraded per special entry
	for _, special in zone.Special do
		local chance = special.Chance * EventService.ServerLuck()
		if special.Rarity == "Secret" then
			chance *= EventService.SecretChanceMultiplier(zoneId)
		end
		if rng:NextNumber() < chance then
			local target = zonePedestals[rng:NextInteger(1, #zonePedestals)]
			local item = EggSpawnService.RollZoneEgg(zoneId, special.Rarity)
			if item then
				setEgg(target, item)
			end
		end
	end
	for _, pedestal in zonePedestals do
		local egg = pedestal.Egg
		if egg then
			announceIfRare(egg, zone.DisplayName)
		end
	end
end

local function resetFestival()
	local active = EventService.FestivalActive()
	for _, pedestal in pedestals do
		if pedestal.Festival then
			if active then
				local item = rollFestivalEgg()
				if item then
					setEgg(pedestal, item)
				end
			else
				clearPedestal(pedestal)
			end
		end
	end
end

function EggSpawnService.ResetAll()
	for _, zone in Zones.List do
		resetZone(zone.Id)
	end
	resetFestival()
end

function EggSpawnService.NextResetAt(): number
	local interval = GameSettings.EggResetInterval
	return (os.time() // interval + 1) * interval
end

local function onGrab(pedestal: Pedestal, player: Player)
	local item = pedestal.Egg
	if not item then
		return
	end
	local canGrab = EggSpawnService.CanGrab
	if canGrab and not canGrab(player) then
		return
	end
	clearPedestal(pedestal)
	EggSpawnService.EggGrabbed:Fire(player, item, pedestal.ZoneId, pedestal.Index, pedestal.Festival)
end

-- A wild egg goes home: back onto its pedestal if that pedestal is still empty.
function EggSpawnService.ReturnEgg(item: Item, zoneId: number, index: number, festival: boolean?)
	local pedestal = byKey[key(zoneId, index, festival == true)]
	if pedestal and pedestal.Egg == nil then
		item.HatchRemaining = nil
		setEgg(pedestal, item)
	end
end

function EggSpawnService.Pedestal(zoneId: number, index: number, festival: boolean?): Pedestal?
	return byKey[key(zoneId, index, festival == true)]
end

function EggSpawnService.PedestalsInZone(zoneId: number): { Pedestal }
	local list = {}
	for _, pedestal in pedestals do
		if not pedestal.Festival and pedestal.ZoneId == zoneId then
			table.insert(list, pedestal)
		end
	end
	return list
end

-- Admin: put a specific egg on a random pedestal in a zone
function EggSpawnService.AdminSpawn(zoneId: number, rarity: string?, mutation: string?): boolean
	local list = EggSpawnService.PedestalsInZone(zoneId)
	if #list == 0 then
		return false
	end
	local item = EggSpawnService.RollZoneEgg(zoneId, rarity, mutation)
	if not item then
		return false
	end
	setEgg(list[rng:NextInteger(1, #list)], item)
	announceIfRare(item, Zones.Get(zoneId).DisplayName)
	return true
end

local function register(part: BasePart, festival: boolean)
	local zoneId = if festival then 0 else part:GetAttribute("ZoneId")
	local index = part:GetAttribute("PedestalIndex")
	if type(zoneId) ~= "number" or type(index) ~= "number" then
		warn("[EggSpawnService] Pedestal missing ZoneId/PedestalIndex: " .. part:GetFullName())
		return
	end
	local prompt = Prompts.Create(part, {
		Name = "GrabPrompt",
		ActionText = "Grab Egg",
		ObjectText = "",
		HoldDuration = GameSettings.GrabHoldTime,
		Range = GameSettings.InteractRange,
	})
	prompt.Enabled = false
	local pedestal: Pedestal = {
		Part = part,
		ZoneId = zoneId,
		Index = index,
		Festival = festival,
		Egg = nil,
		Model = nil,
		Prompt = prompt,
	}
	Prompts.OnTriggered(prompt, function()
		return GameSettings.GrabHoldTime
	end, function(player)
		onGrab(pedestal, player)
	end)
	table.insert(pedestals, pedestal)
	byKey[key(zoneId, index, festival)] = pedestal
end

function EggSpawnService.Init()
	for _, part in World.TaggedParts(Tags.EggPedestal) do
		register(part, false)
	end
	for _, part in World.TaggedParts(Tags.FestivalPedestal) do
		register(part, true)
	end
	if #pedestals == 0 then
		warn("[EggSpawnService] No egg pedestals found (tag parts 'EggPedestal').")
	end
end

function EggSpawnService.Start()
	EventService.Started:Connect(function(id)
		if id == "Matsuri" then
			resetFestival()
		end
	end)
	EventService.Ended:Connect(function(id)
		if id == "Matsuri" then
			resetFestival()
		end
	end)
	task.spawn(function()
		while true do
			local resetIndex = os.time() // GameSettings.EggResetInterval
			if resetIndex ~= lastReset then
				lastReset = resetIndex
				EggSpawnService.ResetAll()
				ReplicatedStorage:SetAttribute("EggResetAt", EggSpawnService.NextResetAt())
			end
			task.wait(0.5)
		end
	end)
end

return EggSpawnService
