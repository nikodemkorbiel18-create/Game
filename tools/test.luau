--!nocheck
-- Unit tests for pure game modules. Run: lune run tools/test
local rbx = require("./lib/rbx")
local env = rbx.load()

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2)
	end
end
local function near(a, b, tol, msg)
	if math.abs(a - b) > (tol or 1e-6) then
		error((msg or "") .. " expected ~" .. tostring(b) .. " got " .. tostring(a), 2)
	end
end

local Shared = "ReplicatedStorage/Shared/"
local NumberFormat = env.require(Shared .. "Util/NumberFormat")
local TimeFormat = env.require(Shared .. "Util/TimeFormat")
local Formulas = env.require(Shared .. "Util/Formulas")
local WeightedRandom = env.require(Shared .. "Util/WeightedRandom")
local EventSchedule = env.require(Shared .. "Util/EventSchedule")
local Characters = env.require(Shared .. "Config/Characters")
local Zones = env.require(Shared .. "Config/Zones")
local Rarities = env.require(Shared .. "Config/Rarities")
local Sizes = env.require(Shared .. "Config/Sizes")
local Mutations = env.require(Shared .. "Config/Mutations")
local Treadmills = env.require(Shared .. "Config/Treadmills")
local Trails = env.require(Shared .. "Config/Trails")
local Shop = env.require(Shared .. "Config/Shop")
local Rebirths = env.require(Shared .. "Config/Rebirths")
local Codes = env.require(Shared .. "Config/Codes")
local Fusion = env.require(Shared .. "Config/Fusion")
local Events = env.require(Shared .. "Config/Events")
local Monetization = env.require(Shared .. "Config/Monetization")
local PropLibrary = env.require(Shared .. "Visual/PropLibrary")

test("NumberFormat suffixes", function()
	eq(NumberFormat.Short(0), "0")
	eq(NumberFormat.Short(999), "999")
	eq(NumberFormat.Short(1000), "1K")
	eq(NumberFormat.Short(1234), "1.23K")
	eq(NumberFormat.Short(999999), "999.99K")
	eq(NumberFormat.Short(2.5e6), "2.5M")
	eq(NumberFormat.Short(7e9), "7B")
	eq(NumberFormat.Short(1.2e12), "1.2T")
	eq(NumberFormat.Short(1e15), "1Qd")
	eq(NumberFormat.Short(1e18), "1Qn")
	eq(NumberFormat.Short(1e21), "1Sx")
	eq(NumberFormat.Short(1e24), "1Sp")
	eq(NumberFormat.Short(1e27), "1Oc")
	eq(NumberFormat.Short(1e30), "1No")
	eq(NumberFormat.Short(1e33), "1Dc")
	eq(NumberFormat.Short(0.45), "0.4")
	eq(NumberFormat.Cash(1500), "$1.5K")
	eq(NumberFormat.Commas(1234567), "1,234,567")
end)

test("TimeFormat", function()
	eq(TimeFormat.Short(45), "45s")
	eq(TimeFormat.Short(185), "3m 05s")
	eq(TimeFormat.Short(3720), "1h 02m")
	eq(TimeFormat.Clock(299), "4:59")
	eq(TimeFormat.ParseDateEnd("1970-01-01"), 86399)
	eq(TimeFormat.ParseDateEnd("2027-12-31"), 1830297599)
end)

test("WalkSpeed formula", function()
	near(Formulas.WalkSpeed(0), 16)
	near(Formulas.WalkSpeed(250), 16 + 7 * math.log10(251))
	eq(Formulas.WalkSpeed(1e30), 100)
end)

test("Guardian speeds: at-speed Normal escapes, Large does not", function()
	for _, zone in Zones.List do
		local player = Formulas.WalkSpeed(zone.RecSpeed)
		local guardian = Formulas.GuardianWalkSpeed(zone.Id)
		assert(player * Sizes.Get(3).Carry > guardian, "zone " .. zone.Id .. " normal egg should escape")
		assert(player * Sizes.Get(5).Carry < guardian, "zone " .. zone.Id .. " huge egg should be caught")
	end
end)

test("KgScale spans +/-20%", function()
	near(Sizes.KgScale(3, 5), 0.8)
	near(Sizes.KgScale(3, 9.9), 1.2)
	near(Sizes.KgScale(6, 105), 1.0, 1e-3)
end)

test("Size chances sum to 100", function()
	local total = 0
	for _, size in Sizes.List do
		total += size.Chance
	end
	near(total, 100)
end)

test("Every zone rarity has at least one character", function()
	for _, zone in Zones.List do
		for rarity, weight in zone.RarityWeights do
			if weight > 0 then
				assert(#Characters.ForZoneRarity(zone.Id, rarity) > 0, "zone " .. zone.Id .. " has no " .. rarity)
			end
		end
		for _, special in zone.Special do
			assert(#Characters.ForZoneRarity(zone.Id, special.Rarity) > 0, "zone " .. zone.Id .. " special " .. special.Rarity)
		end
		near(0, 0)
	end
end)

test("Zone weights sum to 100", function()
	for _, zone in Zones.List do
		local total = 0
		for _, weight in zone.RarityWeights do
			total += weight
		end
		near(total, 100, 1e-6, "zone " .. zone.Id)
	end
end)

test("Characters are valid", function()
	local count = 0
	for _, character in Characters.List do
		count += 1
		assert(Rarities.ById[character.Rarity], character.Id .. " rarity")
		assert(character.BaseIncome > 0, character.Id .. " income")
		assert(#character.Catchphrases >= 1, character.Id .. " catchphrases")
		for _, prop in character.Look.Props do
			assert(PropLibrary[prop], character.Id .. " unknown prop " .. prop)
		end
		for _, key in { "Skin", "Hair", "Outfit", "Outfit2", "Accent", "Eyes" } do
			assert(string.match(character.Look[key], "^#%x%x%x%x%x%x$"), character.Id .. " bad color " .. key)
		end
		if character.Pool == "Zone" then
			local rarity = Rarities.Get(character.Rarity)
			-- base income inside the brief's range for its rarity
			local ranges = {
				Common = { 1, 6 }, Uncommon = { 8, 50 }, Rare = { 40, 400 }, Epic = { 180, 5000 },
				Legendary = { 2000, 50000 }, Mythic = { 16000, 200000 }, Cosmic = { 400000, 2500000 },
				Secret = { 6e6, 20e6 }, Divine = { 60e6, 150e6 }, Eternal = { 500e6, 500e6 },
			}
			local range = ranges[rarity.Id]
			assert(character.BaseIncome >= range[1] and character.BaseIncome <= range[2], character.Id .. " income out of rarity range")
		end
	end
	eq(count, 63 + 3 + 6 + 3, "roster size")
end)

test("Fusion recipes reference real characters", function()
	for _, recipe in Fusion.Recipes do
		for _, id in recipe.Inputs do
			assert(Characters.Find(id), recipe.Id .. " input " .. id)
		end
		assert(Characters.Find(recipe.Result), recipe.Id .. " result")
	end
end)

test("Treadmill and trail tables are monotonic", function()
	for tier = 2, #Treadmills.List do
		assert(Treadmills.List[tier].Price > Treadmills.List[tier - 1].Price)
		assert(Treadmills.List[tier].Gain > Treadmills.List[tier - 1].Gain)
	end
	for index = 2, #Trails.List do
		assert(Trails.List[index].Multiplier > Trails.List[index - 1].Multiplier)
	end
	for level = 2, #Shop.PenLevels do
		assert(Shop.PenLevels[level].Slots > Shop.PenLevels[level - 1].Slots)
	end
end)

test("Rebirth requirements", function()
	eq(Rebirths.Requirement(1).Cash, 1e6)
	eq(Rebirths.Requirement(5).Rarity, "Secret")
	eq(Rebirths.Requirement(6).Cash, 50e9 * 15)
	eq(Rebirths.Requirement(7).Cash, 50e9 * 225)
	eq(Rebirths.Requirement(6).Rarity, "Divine")
	eq(Rebirths.ProtectedKeepCount(1), 0)
	eq(Rebirths.ProtectedKeepCount(2), 1)
	eq(Rebirths.Title(1), "Rookie Thief")
end)

test("Codes have valid dates", function()
	for _, code in Codes do
		assert(TimeFormat.ParseDateEnd(code.Expires), code.Code)
	end
end)

test("Weighted odds", function()
	local odds = WeightedRandom.Odds({ A = 60, B = 28, C = 9, D = 3 })
	near(odds.A, 0.6)
	local rng = rbx.Random.new(42)
	local counts = { A = 0, B = 0 }
	for _ = 1, 20000 do
		local pick = WeightedRandom.PickMap({ A = 75, B = 25 }, rng)
		counts[pick] += 1
	end
	near(counts.A / 20000, 0.75, 0.02)
end)

test("Gacha odds sum to 100", function()
	local total = 0
	for _, character in Characters.ForPool("Gacha") do
		total += character.SpawnWeight
	end
	eq(total, 100)
end)

test("Event schedule is deterministic and weekly events land on the right weekday", function()
	-- 2026-10-03 is a Saturday
	local saturday = TimeFormat.ParseDateEnd("2026-10-03") - 86399
	eq(EventSchedule._weekdayOf(saturday), 7)
	local matsuriStart = saturday + 18 * 3600
	local active = EventSchedule.Active(matsuriStart + 60)
	local found = false
	for _, window in active do
		if window.Id == "Matsuri" then
			found = true
			eq(window.StartsAt, matsuriStart)
		end
	end
	assert(found, "Matsuri should be active")
	-- hourly events: same answer twice, never longer than their duration
	local a = EventSchedule.Upcoming(1800000000)
	local b = EventSchedule.Upcoming(1800000000)
	eq(#a, #b)
	for i = 1, #a do
		eq(a[i].StartsAt, b[i].StartsAt)
		eq(a[i].EndsAt - a[i].StartsAt, Events.ById[a[i].Id].Duration)
	end
end)

test("Discovery speed rewards are capped", function()
	local mochi = Formulas.DiscoverySpeed("MochiKun")
	eq(mochi, 100)
	local eien = Formulas.DiscoverySpeed("Eien")
	assert(eien <= 500000000 * 0.5)
	eq(Formulas.DiscoveryCash("Nemuko"), 180)
end)

test("Monetization keys unique", function()
	local seen = {}
	for _, pass in Monetization.Passes do
		assert(not seen[pass.Key])
		seen[pass.Key] = true
	end
	for _, product in Monetization.Products do
		assert(not seen[product.Key])
		seen[product.Key] = true
	end
end)

test("Mutations", function()
	near(Mutations.IncomeMult("Golden"), 2)
	near(Mutations.IncomeMult(nil), 1)
	near(Mutations.HatchMult("KamiBloom"), 2)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	local process = require("@lune/process")
	process.exit(1)
end
