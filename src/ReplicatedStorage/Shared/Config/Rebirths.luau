--!strict
-- Rebirth requirements, rewards and titles.

export type Requirement = {
	Cash: number,
	Rarity: string, -- must own (pen or inventory) any character of this rarity or higher
}

local requirements: { Requirement } = {
	{ Cash = 1e6, Rarity = "Epic" },
	{ Cash = 15e6, Rarity = "Legendary" },
	{ Cash = 200e6, Rarity = "Mythic" },
	{ Cash = 3e9, Rarity = "Cosmic" },
	{ Cash = 50e9, Rarity = "Secret" },
}

local titles = {
	"Rookie Thief",
	"Egg Bandit",
	"Phantom Thief",
	"Legendary Heister",
	"Shadow Collector",
	"Moonlit Rogue",
	"Celestial Outlaw",
	"Myth Stealer",
	"Eternal Trickster",
	"Chibi Sovereign",
}

local Rebirths = {
	Rewards = {
		CashBonus = 0.5, -- +50% cash per rebirth (additive)
		LuckBonus = 0.10, -- +10% Lucky Hatch chance per rebirth
		TreadmillBonus = 0.25, -- +25% treadmill gain per rebirth
		PenSlots = 1,
		TrapCapacity = 1,
	},
	MaxBonusPenSlots = 10, -- physical pedestals available for rebirth slots
	ProtectedKeepEvery = 2, -- keep 1 Protected character per 2 rebirths
	BossClearResets = true,
	Titles = titles,
	LateCashMultiplier = 15, -- rebirth 6+: previous cash requirement x15
	LateRarity = "Divine",
}

-- Requirement for reaching `rebirthNumber` (1 = first rebirth).
function Rebirths.Requirement(rebirthNumber: number): Requirement
	if rebirthNumber <= #requirements then
		return requirements[rebirthNumber]
	end
	local cash = requirements[#requirements].Cash
	for _ = #requirements + 1, rebirthNumber do
		cash *= Rebirths.LateCashMultiplier
	end
	return { Cash = cash, Rarity = Rebirths.LateRarity }
end

function Rebirths.Title(rebirths: number): string?
	if rebirths <= 0 then
		return nil
	end
	return titles[math.min(rebirths, #titles)]
end

function Rebirths.ProtectedKeepCount(newRebirthCount: number): number
	return math.floor(newRebirthCount / Rebirths.ProtectedKeepEvery)
end

return Rebirths
