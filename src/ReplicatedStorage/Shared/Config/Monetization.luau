--!strict
-- Gamepasses and developer products. Create them on the Roblox website (Creator Hub >
-- your experience > Monetization) and paste the IDs here. Anything with Id = 0 is hidden
-- from the shop, so the game works before IDs exist.

export type Pass = {
	Key: string,
	Id: number,
	DisplayName: string,
	Description: string,
	SuggestedRobux: number,
}

export type Product = {
	Key: string,
	Id: number,
	DisplayName: string,
	Description: string,
	SuggestedRobux: number,
	Category: string,
}

local passes: { Pass } = {
	{ Key = "VIP", Id = 0, DisplayName = "VIP", Description = "x1.5 cash, gold name tag, 50% offline earnings for up to 12h.", SuggestedRobux = 399 },
	{ Key = "DoubleCash", Id = 0, DisplayName = "x2 Cash", Description = "Double all cash income.", SuggestedRobux = 499 },
	{ Key = "DoubleSpeed", Id = 0, DisplayName = "x2 Speed Gain", Description = "Double treadmill Speed gain.", SuggestedRobux = 299 },
	{ Key = "AutoCollect", Id = 0, DisplayName = "Auto-Collect", Description = "Cash goes straight to your wallet. No Collect Plate needed.", SuggestedRobux = 199 },
	{ Key = "ExtraPenSlots", Id = 0, DisplayName = "+6 Pen Slots", Description = "Six extra pen slots in your base.", SuggestedRobux = 349 },
	{ Key = "FasterHatch", Id = 0, DisplayName = "Faster Hatch", Description = "Eggs hatch 1.5x faster.", SuggestedRobux = 299 },
	{ Key = "TrapMaster", Id = 0, DisplayName = "Trap Master", Description = "+5 trap capacity and traps freeze Guardians for 4.5s.", SuggestedRobux = 149 },
	{ Key = "LongBarrier", Id = 0, DisplayName = "Long Barrier", Description = "Barrier Lock lasts 60s longer.", SuggestedRobux = 149 },
}

local products: { Product } = {
	{ Key = "SpeedPackSmall", Id = 0, DisplayName = "Speed Pack S", Description = "Instant Speed: 15 minutes of your best treadmill gain.", SuggestedRobux = 49, Category = "Speed" },
	{ Key = "SpeedPackMedium", Id = 0, DisplayName = "Speed Pack M", Description = "Instant Speed: 1 hour of your best treadmill gain.", SuggestedRobux = 149, Category = "Speed" },
	{ Key = "SpeedPackLarge", Id = 0, DisplayName = "Speed Pack L", Description = "Instant Speed: 4 hours of your best treadmill gain.", SuggestedRobux = 449, Category = "Speed" },
	{ Key = "LuckBoost", Id = 0, DisplayName = "Luck Boost (15 min)", Description = "+25% Lucky Hatch chance for 15 minutes.", SuggestedRobux = 79, Category = "Boost" },
	{ Key = "ServerLuck", Id = 0, DisplayName = "Server Luck (15 min)", Description = "Rare egg spawns x2 for everyone in the server for 15 minutes.", SuggestedRobux = 299, Category = "Boost" },
	{ Key = "InstantHatch1", Id = 0, DisplayName = "Instant Hatch (Common-Rare)", Description = "Hatch one Common, Uncommon or Rare egg right now.", SuggestedRobux = 19, Category = "InstantHatch" },
	{ Key = "InstantHatch2", Id = 0, DisplayName = "Instant Hatch (Epic-Legendary)", Description = "Hatch one Epic or Legendary egg right now.", SuggestedRobux = 49, Category = "InstantHatch" },
	{ Key = "InstantHatch3", Id = 0, DisplayName = "Instant Hatch (Mythic-Cosmic)", Description = "Hatch one Mythic or Cosmic egg right now.", SuggestedRobux = 129, Category = "InstantHatch" },
	{ Key = "InstantHatch4", Id = 0, DisplayName = "Instant Hatch (Secret+)", Description = "Hatch one Secret, Divine or Eternal egg right now.", SuggestedRobux = 399, Category = "InstantHatch" },
	{ Key = "GachaCapsule", Id = 0, DisplayName = "Gacha Capsule Egg", Description = "One random exclusive character egg. Odds are shown before you buy.", SuggestedRobux = 99, Category = "Gacha" },
}

local passByKey: { [string]: Pass } = {}
for _, pass in passes do
	passByKey[pass.Key] = pass
end
local productByKey: { [string]: Product } = {}
for _, product in products do
	productByKey[product.Key] = product
end

local Monetization = {
	Passes = passes,
	Products = products,
	PassByKey = passByKey,
	ProductByKey = productByKey,
	-- Multipliers granted by passes
	VIPCash = 1.5,
	DoubleCash = 2,
	DoubleSpeed = 2,
	ExtraPenSlots = 6,
	FasterHatch = 1.5,
	LongBarrierBonus = 60,
	-- Speed packs: minutes of the player's current treadmill gain, with a floor
	SpeedPacks = {
		SpeedPackSmall = { Minutes = 15, Minimum = 5000 },
		SpeedPackMedium = { Minutes = 60, Minimum = 25000 },
		SpeedPackLarge = { Minutes = 240, Minimum = 150000 },
	},
	LuckBoostMinutes = 15,
	ServerLuckMinutes = 15,
	ServerLuckMultiplier = 2,
	-- Which Instant Hatch product covers which rarity ranks
	InstantHatchTiers = {
		{ Key = "InstantHatch1", MinRank = 1, MaxRank = 3 },
		{ Key = "InstantHatch2", MinRank = 4, MaxRank = 5 },
		{ Key = "InstantHatch3", MinRank = 6, MaxRank = 7 },
		{ Key = "InstantHatch4", MinRank = 8, MaxRank = 10 },
	},
	ProcessedPurchaseCache = 100,
}

return Monetization
