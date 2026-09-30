--!strict
-- Redeemable codes (Codes Board in Station Plaza). Codes are case-insensitive.
-- Expires is a UTC date "YYYY-MM-DD"; the code stops working at the end of that day.

export type CodeDef = {
	Code: string,
	Expires: string,
	Rewards: {
		Cash: number?,
		Speed: number?,
		Traps: number?,
		SmokeBombs: number?,
		LuckMinutes: number?,
	},
}

local Codes: { CodeDef } = {
	{ Code = "CHIBI", Expires = "2027-12-31", Rewards = { Cash = 2500, Speed = 250 } },
	{ Code = "STEALACHIBI", Expires = "2027-12-31", Rewards = { Cash = 5000, Traps = 3 } },
	{ Code = "LUCKYEGG", Expires = "2027-06-30", Rewards = { LuckMinutes = 15 } },
	{ Code = "SAKURA", Expires = "2027-06-30", Rewards = { Speed = 1000, SmokeBombs = 1 } },
	{ Code = "RELEASE", Expires = "2027-03-31", Rewards = { Cash = 10000, Speed = 500, Traps = 2 } },
}

return Codes
