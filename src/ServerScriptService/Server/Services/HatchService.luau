--!strict
-- Incubation: starts timers when eggs are placed, applies growth boosts, hatches eggs into
-- characters (with Lucky Hatch rolls), triggers the reveal, discovery and announcements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Rebirths = require(Shared.Config.Rebirths)
local Formulas = require(Shared.Util.Formulas)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local EventService = require(script.Parent.EventService)
local IncomeService = require(script.Parent.IncomeService)
local IndexService = require(script.Parent.IndexService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Signal = require(Shared.Util.Signal)

type Item = Types.Item

local HatchService = {}

-- (player, item) after an egg hatches
HatchService.Hatched = Signal.new() :: Signal.Signal<Player, Item>

function HatchService.Luck(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local luck = data.Rebirths * Rebirths.Rewards.LuckBonus
	if data.Boosts.LuckEndsAt > os.time() then
		luck += GameSettings.LuckBoostBonus
	end
	return math.min(luck, GameSettings.LuckCap)
end

function HatchService.GrowthMultiplier(player: Player): number
	return PassService.HatchSpeed(player) * EventService.HatchSpeed()
end

-- Seconds left on an egg that is not incubating in a pen
function HatchService.Remaining(item: Item): number
	if item.HatchEndsAt then
		return math.max(0, item.HatchEndsAt - os.time())
	end
	if item.HatchRemaining then
		return math.max(0, item.HatchRemaining)
	end
	return Formulas.HatchTime(item)
end

-- Pause incubation (egg leaves a pen)
function HatchService.Pause(item: Item)
	if item.Kind ~= "Egg" then
		return
	end
	item.HatchRemaining = HatchService.Remaining(item)
	item.HatchEndsAt = nil
end

-- Start / resume incubation for an egg that was just placed in a pen slot
function HatchService.StartIncubation(player: Player, item: Item)
	if item.Kind ~= "Egg" then
		return
	end
	local data = DataService.Get(player)
	local remaining = HatchService.Remaining(item)
	if data and not data.FirstEggPlaced then
		data.FirstEggPlaced = true
		remaining = math.min(remaining, GameSettings.TutorialHatchCap)
		item.Tutorial = true
	end
	item.HatchEndsAt = os.time() + math.ceil(remaining)
	item.HatchRemaining = nil
end

local function luckyBump(player: Player, item: Item)
	if item.SizeTier >= #Sizes.List then
		return
	end
	if math.random() >= HatchService.Luck(player) then
		return
	end
	local old = Sizes.Get(item.SizeTier)
	local new = Sizes.Get(item.SizeTier + 1)
	local fraction = (item.Kg - old.MinKg) / math.max(0.001, old.MaxKg - old.MinKg)
	item.SizeTier = new.Rank
	item.Kg = math.floor((new.MinKg + (new.MaxKg - new.MinKg) * math.clamp(fraction, 0, 1)) * 10) / 10
	item.Lucky = true
end

function HatchService.Hatch(player: Player, slotKey: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local item = data.Pen[slotKey]
	if not item or item.Kind ~= "Egg" then
		return
	end
	item.Kind = "Character"
	item.HatchEndsAt = nil
	item.HatchRemaining = nil
	item.Tutorial = nil
	luckyBump(player, item)
	data.Stats.Hatched += 1
	local character = Characters.Get(item.CharacterId)
	local firstTime = not data.SeenReveals[item.CharacterId]
	data.SeenReveals[item.CharacterId] = true
	DataService.Changed(player, "Pen", "Stats", "SeenReveals")
	local slotIndex = tonumber(slotKey) :: number
	PlotService.RenderSlot(player, slotIndex)
	IncomeService.Recalculate(player)
	IndexService.Discover(player, item)
	HatchService.Hatched:Fire(player, item)
	Remote.Fire("HatchReveal", player, {
		Item = item,
		Slot = slotIndex,
		FirstTime = firstTime,
	})
	local rarity = Rarities.Get(Formulas.DisplayRarity(item))
	if rarity.Rank >= GameSettings.AnnounceRank then
		AnnouncementService.Announce(
			string.format("%s HATCHED A %s: %s!", string.upper(player.DisplayName), string.upper(rarity.DisplayName), string.upper(character.DisplayName)),
			rarity.Color2 or rarity.Color,
			"Hatch"
		)
	end
end

-- Instantly finish one egg (Instant Hatch product / admin)
function HatchService.FinishNow(player: Player, slotKey: string): boolean
	local data = DataService.Get(player)
	local item = data and data.Pen[slotKey]
	if not item or item.Kind ~= "Egg" then
		return false
	end
	HatchService.Hatch(player, slotKey)
	return true
end

-- Egg in the pen with the longest remaining time within a rarity rank range
function HatchService.LongestEgg(player: Player, minRank: number, maxRank: number): string?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local best, bestRemaining = nil, -1
	for key, item in data.Pen do
		if item.Kind == "Egg" and item.HatchEndsAt then
			local rank = Rarities.Rank(Characters.Get(item.CharacterId).Rarity)
			local remaining = item.HatchEndsAt - os.time()
			if rank >= minRank and rank <= maxRank and remaining > bestRemaining then
				best, bestRemaining = key, remaining
			end
		end
	end
	return best
end

local lastTick = os.clock()

local function tick()
	local now = os.clock()
	local dt = now - lastTick
	lastTick = now
	local unix = os.time()
	for _, player in DataService.LoadedPlayers() do
		local data = DataService.Get(player)
		if data then
			local boost = HatchService.GrowthMultiplier(player)
			local changed = false
			for key, item in data.Pen do
				if item.Kind == "Egg" and item.HatchEndsAt then
					if boost > 1 then
						item.HatchEndsAt -= dt * (boost - 1)
						changed = true
					end
					if unix >= item.HatchEndsAt then
						HatchService.Hatch(player, key)
					elseif changed then
						local plot = PlotService.Get(player)
						local index = tonumber(key) :: number
						local slot = plot and plot.Slots[index]
						if slot then
							slot:SetAttribute("HatchEndsAt", item.HatchEndsAt)
						end
						local model = plot and plot.SlotModels[index]
						if model then
							model:SetAttribute("HatchEndsAt", item.HatchEndsAt)
						end
					end
				end
			end
			if changed then
				DataService.Changed(player, "Pen")
			end
			DataService.SetDerived(player, "Luck", HatchService.Luck(player))
			DataService.SetDerived(player, "GrowthMultiplier", boost)
		end
	end
end

function HatchService.Init() end

function HatchService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return HatchService
