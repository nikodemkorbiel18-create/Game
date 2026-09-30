--!strict
-- Weighted picks. Pass a Random for deterministic results (tests, simulator).

local WeightedRandom = {}

export type Rng = { NextNumber: (self: Rng, min: number?, max: number?) -> number }

local function roll(rng: Random?): number
	if rng then
		return rng:NextNumber()
	end
	return math.random()
end

-- weights: { [key]: weight } -> key
function WeightedRandom.PickMap<K>(weights: { [K]: number }, rng: Random?): K?
	local total = 0
	local keys = {}
	for key, weight in weights do
		if weight > 0 then
			total += weight
			table.insert(keys, key)
		end
	end
	if total <= 0 then
		return nil
	end
	-- stable order so seeded rolls are reproducible
	table.sort(keys, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)
	local target = roll(rng) * total
	local acc = 0
	for _, key in keys do
		acc += weights[key]
		if target < acc then
			return key
		end
	end
	return keys[#keys]
end

-- list of items with a weight accessor -> item
function WeightedRandom.PickList<T>(items: { T }, weightOf: (T) -> number, rng: Random?): T?
	local total = 0
	for _, item in items do
		total += math.max(0, weightOf(item))
	end
	if total <= 0 then
		return nil
	end
	local target = roll(rng) * total
	local acc = 0
	for _, item in items do
		acc += math.max(0, weightOf(item))
		if target < acc then
			return item
		end
	end
	return items[#items]
end

-- Percent chance helper: Chance(2.5) -> true 2.5% of the time
function WeightedRandom.Chance(percent: number, rng: Random?): boolean
	return roll(rng) * 100 < percent
end

-- Converts a weights map to exact percentages (for odds displays)
function WeightedRandom.Odds<K>(weights: { [K]: number }): { [K]: number }
	local total = 0
	for _, weight in weights do
		total += math.max(0, weight)
	end
	local odds = {}
	for key, weight in weights do
		odds[key] = if total > 0 then math.max(0, weight) / total else 0
	end
	return odds
end

return WeightedRandom
