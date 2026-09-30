--!strict
-- Balancing simulator: plays a greedy, non-paying player second by second using the real
-- config values and prints when each zone becomes reachable. Run from Lune
-- (lune run tools/simulate) or in Studio's command bar:
--   require(game.ReplicatedStorage.Shared.Balancing.Simulator).Run()

local Shared = script.Parent.Parent
local Config = Shared.Config
local Balancing = require(Config.Balancing)
local Characters = require(Config.Characters)
local Rarities = require(Config.Rarities)
local Sizes = require(Config.Sizes)
local Mutations = require(Config.Mutations)
local Zones = require(Config.Zones)
local Treadmills = require(Config.Treadmills)
local Trails = require(Config.Trails)
local Shop = require(Config.Shop)
local GameSettings = require(Config.GameSettings)
local Rebirths = require(Config.Rebirths)
local Formulas = require(Shared.Util.Formulas)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local Types = require(Shared.Types)

type Item = Types.Item

type PenEntry = { Item: Item, Income: number, HatchAt: number }

export type Result = {
	ZoneTimes: { [number]: number },
	FirstRebirthTime: number?,
	Log: { string },
	FinalIncome: number,
	FinalSpeed: number,
}

local Simulator = {}

local function rollEgg(zoneId: number, rng: Random): Item
	local zone = Zones.Get(zoneId)
	local rarity = WeightedRandom.PickMap(zone.RarityWeights, rng) :: string
	local pool = Characters.ForZoneRarity(zoneId, rarity)
	local character = WeightedRandom.PickList(pool, function(c)
		return c.SpawnWeight
	end, rng) :: Characters.Character
	local sizeTier = 1
	do
		local roll = rng:NextNumber() * 100
		local acc = 0
		for _, size in Sizes.List do
			acc += size.Chance
			if roll < acc then
				sizeTier = size.Rank
				break
			end
		end
	end
	local size = Sizes.Get(sizeTier)
	local mutation: string? = nil
	local roll = rng:NextNumber() * 100
	local acc = 0
	for _, id in Mutations.Natural do
		local m = Mutations.ById[id]
		acc += m.Chance
		if roll < acc then
			mutation = id
			break
		end
	end
	return {
		Uid = "",
		Kind = "Egg",
		CharacterId = character.Id,
		SizeTier = sizeTier,
		Kg = size.MinKg + (size.MaxKg - size.MinKg) * rng:NextNumber(),
		Mutation = mutation,
	}
end

function Simulator.Simulate(seed: number?): Result
	local sim = Balancing.Sim
	local rng = Random.new(seed or sim.Seed)
	local log = {}
	local t = 0
	local cash = 0
	local speed = 0
	local treadmillTier = 0
	local penLevel = 1
	local trail: string? = nil
	local ownedTrailIndex = 0
	local pen: { PenEntry } = {}
	local discovered: { [string]: boolean } = {}
	local zoneTimes: { [number]: number } = { [1] = 0 }
	local firstRebirth: number? = nil
	local busyUntil = 0
	local pendingItem: Item? = nil
	local nests: { [number]: { Item } } = {}
	local lastReset = -1
	local firstEgg = true
	local giftGiven = false
	local context: Formulas.IncomeContext = { Rebirths = 0, IndexBonus = 0, PassMultiplier = 1 }

	local function note(text: string)
		table.insert(log, string.format("[%6.1f min] %s", t / 60, text))
	end

	local function income(): number
		local total = 0
		for _, entry in pen do
			if t >= entry.HatchAt then
				total += entry.Income
			end
		end
		return total
	end

	local function accessibleZone(): number
		local best = 1
		for _, zone in Zones.List do
			if speed >= zone.RecSpeed then
				best = zone.Id
			end
		end
		return best
	end

	local function canCarry(zoneId: number, sizeTier: number): boolean
		return Formulas.WalkSpeed(speed) * Sizes.Get(sizeTier).Carry > Formulas.GuardianWalkSpeed(zoneId)
	end

	local function worstPen(): (number?, number)
		local worstIndex, worstValue = nil, math.huge
		for index, entry in pen do
			if entry.Income < worstValue then
				worstIndex, worstValue = index, entry.Income
			end
		end
		return worstIndex, worstValue
	end

	local function slots(): number
		return Shop.PenSlots(penLevel)
	end

	local limit = sim.HoursToSimulate * 3600
	while t < limit do
		-- egg resets
		local resetIndex = t // GameSettings.EggResetInterval
		if resetIndex ~= lastReset then
			lastReset = resetIndex
			local top = accessibleZone()
			for zoneId = math.max(1, top - 1), top do
				local eggs = {}
				for _ = 1, GameSettings.PedestalsPerNest do
					local egg = rollEgg(zoneId, rng)
					if rng:NextNumber() >= sim.Competition then
						table.insert(eggs, egg)
					end
				end
				nests[zoneId] = eggs
			end
		end

		-- income and hatching
		cash += income()
		for _, entry in pen do
			if t >= entry.HatchAt and entry.HatchAt >= t - 1 then
				local id = entry.Item.CharacterId
				if not discovered[id] then
					discovered[id] = true
					cash += Formulas.DiscoveryCash(id)
					speed += Formulas.DiscoverySpeed(id)
				end
			end
		end

		-- purchases (cheapest useful upgrade first)
		local bought = true
		while bought do
			bought = false
			local options = {}
			if treadmillTier < Treadmills.MaxTier then
				local nextTier = Treadmills.List[treadmillTier + 1]
				table.insert(options, { Price = nextTier.Price, Apply = function()
					treadmillTier += 1
					note("Treadmill -> " .. nextTier.DisplayName)
				end })
			end
			if penLevel < #Shop.PenLevels and #pen >= slots() then
				local level = Shop.PenLevels[penLevel + 1]
				table.insert(options, { Price = level.Price, Apply = function()
					penLevel += 1
					note("Pen level " .. penLevel .. " (" .. level.Slots .. " slots)")
				end })
			end
			local nextTrail = Trails.List[ownedTrailIndex + 1]
			if nextTrail and nextTrail.Price > 0 then
				table.insert(options, { Price = nextTrail.Price, Apply = function()
					ownedTrailIndex += 1
					trail = nextTrail.Id
					note("Trail " .. nextTrail.DisplayName)
				end })
			end
			table.sort(options, function(a, b)
				return a.Price < b.Price
			end)
			local option = options[1]
			if option and cash >= option.Price then
				cash -= option.Price
				option.Apply()
				bought = true
			end
		end

		-- action
		if t >= busyUntil then
			if pendingItem then
				-- trip finished: place the egg
				local item = pendingItem
				pendingItem = nil
				local hatch = Formulas.HatchTime(item)
				if firstEgg then
					hatch = math.min(hatch, GameSettings.TutorialHatchCap)
					firstEgg = false
				end
				local entry = { Item = item, Income = Formulas.EffectiveIncome(item, context), HatchAt = t + hatch }
				if #pen >= slots() then
					local worstIndex = worstPen()
					if worstIndex then
						cash += pen[worstIndex].Income * GameSettings.SellMultiplier
						table.remove(pen, worstIndex)
					end
				end
				table.insert(pen, entry)
				if not giftGiven then
					giftGiven = true
					cash += GameSettings.WelcomeGiftCash
				end
			end

			local top = accessibleZone()
			local bestZone, bestIndex, bestValue = nil, nil, 0
			for zoneId = math.max(1, top - 1), top do
				local eggs = nests[zoneId]
				if eggs then
					for index, item in eggs do
						if canCarry(zoneId, item.SizeTier) then
							local value = Formulas.EffectiveIncome(item, context)
							if value > bestValue then
								bestZone, bestIndex, bestValue = zoneId, index, value
							end
						end
					end
				end
			end
			local _, worstValue = worstPen()
			local wantsEgg = bestZone ~= nil and (#pen < slots() or bestValue > worstValue * 1.2)
			if wantsEgg and bestZone and bestIndex then
				local eggs = nests[bestZone]
				local item = table.remove(eggs, bestIndex) :: Item
				local distance = sim.HomeToZone1Distance + (bestZone - 1) * sim.ZoneSpacing
				local walk = Formulas.WalkSpeed(speed)
				local tripTime = distance / walk + distance / (walk * Sizes.Get(item.SizeTier).Carry) + sim.GrabOverhead
				busyUntil = t + math.ceil(tripTime)
				if rng:NextNumber() >= sim.CatchChanceAtSpeed * (if bestZone == top then 1 else 0.3) then
					pendingItem = item
				end
			elseif treadmillTier > 0 then
				speed += Formulas.TreadmillGain({ TreadmillTier = treadmillTier, Trail = trail, Rebirths = 0, DoubleSpeed = false })
			end
		end

		for _, zone in Zones.List do
			if zoneTimes[zone.Id] == nil and speed >= zone.RecSpeed then
				zoneTimes[zone.Id] = t
				note(string.format("Reached zone %d (%s) with %s income/s", zone.Id, zone.DisplayName, tostring(math.floor(income()))))
			end
		end
		if firstRebirth == nil then
			local requirement = Rebirths.Requirement(1)
			if cash >= requirement.Cash then
				for _, entry in pen do
					local character = Characters.Get(entry.Item.CharacterId)
					if Rarities.Rank(character.Rarity) >= Rarities.Rank(requirement.Rarity) and t >= entry.HatchAt then
						firstRebirth = t
						note("First rebirth available")
						break
					end
				end
			end
		end
		t += sim.TickSeconds
	end

	return { ZoneTimes = zoneTimes, FirstRebirthTime = firstRebirth, Log = log, FinalIncome = income(), FinalSpeed = speed }
end

-- Runs several seeds and prints average time-to-zone against the targets.
function Simulator.Run(runs: number?, verbose: boolean?): { [number]: number }
	local count = runs or 5
	local sums: { [number]: number } = {}
	local hits: { [number]: number } = {}
	local rebirthSum, rebirthHits = 0, 0
	for run = 1, count do
		local result = Simulator.Simulate(Balancing.Sim.Seed + run * 7919)
		if verbose and run == 1 then
			for _, line in result.Log do
				print(line)
			end
		end
		for zoneId, time in result.ZoneTimes do
			sums[zoneId] = (sums[zoneId] or 0) + time
			hits[zoneId] = (hits[zoneId] or 0) + 1
		end
		if result.FirstRebirthTime then
			rebirthSum += result.FirstRebirthTime
			rebirthHits += 1
		end
	end
	local averages = {}
	print(string.format("%-4s %-26s %10s %10s", "Zone", "Name", "Target", "Simulated"))
	for _, zone in Zones.List do
		local target = Balancing.ZoneTargets[zone.Id]
		local average = if hits[zone.Id] then sums[zone.Id] / hits[zone.Id] / 60 else nil
		if average then
			averages[zone.Id] = average
		end
		print(string.format(
			"%-4d %-26s %10s %10s%s",
			zone.Id,
			zone.DisplayName,
			if target then string.format("%.0f min", target) else "-",
			if average then string.format("%.0f min", average) else "never",
			if hits[zone.Id] and hits[zone.Id] < count then string.format(" (%d/%d runs)", hits[zone.Id], count) else ""
		))
	end
	if rebirthHits > 0 then
		print(string.format("First rebirth: %.0f min (target %d-%d min)", rebirthSum / rebirthHits / 60, Balancing.FirstRebirthTarget[1], Balancing.FirstRebirthTarget[2]))
	else
		print("First rebirth: not reached")
	end
	return averages
end

return Simulator
