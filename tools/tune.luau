--!nocheck
-- Auto-tunes treadmill and trail prices so the simulator hits Balancing.ZoneTargets.
-- Prints suggested prices; copy them into Config/Treadmills and Config/Trails.
-- Usage: lune run tools/tune [passes] [runs]
local process = require("@lune/process")
local rbx = require("./lib/rbx")
local env = rbx.load()
local Simulator = env.require("ReplicatedStorage/Shared/Balancing/Simulator")
local Balancing = env.require("ReplicatedStorage/Shared/Config/Balancing")
local Treadmills = env.require("ReplicatedStorage/Shared/Config/Treadmills")
local Trails = env.require("ReplicatedStorage/Shared/Config/Trails")

local passes = tonumber(process.args[1]) or 3
local runs = tonumber(process.args[2]) or 4

local function roundNice(value)
	local magnitude = 10 ^ math.floor(math.log10(value))
	local step = magnitude / 2
	return math.max(step, math.floor(value / step + 0.5) * step)
end

local function quietRun()
	local sums, hits = {}, {}
	for run = 1, runs do
		local result = Simulator.Simulate(Balancing.Sim.Seed + run * 7919)
		for zoneId, time in result.ZoneTimes do
			sums[zoneId] = (sums[zoneId] or 0) + time
			hits[zoneId] = (hits[zoneId] or 0) + 1
		end
	end
	local averages = {}
	for zoneId, sum in sums do
		averages[zoneId] = sum / hits[zoneId] / 60
	end
	return averages
end

for pass = 1, passes do
	for zoneId = 2, 11 do
		local target = Balancing.ZoneTargets[zoneId]
		local averages = quietRun()
		local simulated = averages[zoneId] or (Balancing.Sim.HoursToSimulate * 60 * 1.5)
		local ratio = target / math.max(simulated, 0.5)
		if math.abs(ratio - 1) > 0.08 then
			local factor = math.clamp(ratio, 0.4, 4) ^ 0.85
			local fromTier = math.max(2, zoneId - 1)
			local pivotPrice = Treadmills.List[fromTier].Price
			for tier = fromTier, #Treadmills.List do
				Treadmills.List[tier].Price = roundNice(Treadmills.List[tier].Price * factor)
			end
			for _, trail in Trails.List do
				if trail.Price >= pivotPrice * 0.5 then
					trail.Price = roundNice(trail.Price * factor)
				end
			end
			print(string.format("pass %d zone %d: sim %.0f vs target %.0f -> x%.2f from tier %d", pass, zoneId, simulated, target, factor, fromTier))
		end
	end
end

print("\nFinal:")
Simulator.Run(6)
print("\nTreadmill prices:")
for _, treadmill in Treadmills.List do
	print(string.format("  Tier %2d %-24s %s", treadmill.Tier, treadmill.DisplayName, string.format("%.0f", treadmill.Price)))
end
print("Trail prices:")
for _, trail in Trails.List do
	print(string.format("  %-16s %s", trail.Id, string.format("%.0f", trail.Price)))
end
