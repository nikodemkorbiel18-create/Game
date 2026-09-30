--!strict
-- Celestial Sakura Heights: the Heavenly Gatekeeper gauntlet and the Sacred Tree Incubator.

local Endgame = {
	Boss = {
		DisplayName = "Heavenly Gatekeeper",
		MaxHits = 2, -- reaching the gate with fewer than 3 hits clears the gauntlet
		HitInvulnerability = 1.0,
		ResetOnRebirth = true,
		Shockwave = { Interval = 3.0, Speed = 32, MaxRadius = 70, Thickness = 3, JumpClearance = 2.2 },
		Petals = { Interval = 1.2, Warning = 1.2, Radius = 7, Count = 3 },
		Staff = { DegreesPerSecond = 80, Length = 60, Height = 2.4, Thickness = 2.5 },
	},
	Incubator = {
		Duration = 60,
		Fees = {
			Common = 10000,
			Uncommon = 50000,
			Rare = 250000,
			Epic = 1000000,
			Legendary = 5000000,
			Mythic = 25000000,
			Cosmic = 150000000,
			Secret = 1000000000,
			Divine = 10000000000,
			Eternal = 100000000000,
		} :: { [string]: number },
	},
}

return Endgame
