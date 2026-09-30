--!strict
-- 7-day login streak. Missing a UTC day resets the streak to day 1.
-- IncomeMinutes rewards pay that many minutes of your current $/s (with a floor).

export type Reward = {
	Kind: "IncomeMinutes" | "Traps" | "SmokeBombs" | "LuckBoost" | "SpeedMinutes",
	Amount: number,
	Minimum: number?,
	Label: string,
}

local LoginRewards: { { Reward } } = {
	{ { Kind = "IncomeMinutes", Amount = 5, Minimum = 500, Label = "5 min of income" } },
	{ { Kind = "Traps", Amount = 2, Label = "2 Ofuda Traps" } },
	{ { Kind = "IncomeMinutes", Amount = 10, Minimum = 2000, Label = "10 min of income" } },
	{ { Kind = "LuckBoost", Amount = 15, Label = "15 min Luck Boost" } },
	{ { Kind = "IncomeMinutes", Amount = 20, Minimum = 5000, Label = "20 min of income" } },
	{ { Kind = "SmokeBombs", Amount = 2, Label = "2 Smoke Bombs" } },
	{
		{ Kind = "IncomeMinutes", Amount = 45, Minimum = 25000, Label = "45 min of income" },
		{ Kind = "SpeedMinutes", Amount = 30, Minimum = 2000, Label = "30 min of Speed" },
	},
}

return LoginRewards
