--!strict
-- Character Index rewards.

local Index = {
	DiscoveryCashMult = 60, -- first discovery pays 60x the character's base $/s
	DiscoverySpeedMult = 100, -- and 100x base $/s in Speed...
	-- ...capped at this fraction of the next zone's recommended Speed (min 100),
	-- so discoveries help without skipping zones.
	DiscoverySpeedCapFraction = 0.04,
	DiscoverySpeedCapMin = 100,
	ZoneCompletionBonus = 0.05, -- permanent +5% income per completed zone
	FullCompletion = { Trail = "MainCharacter", Title = "Main Character" },
	Categories = { "Zone", "Festival", "Gacha", "Fusion" },
}

return Index
