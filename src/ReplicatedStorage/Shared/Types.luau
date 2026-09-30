--!strict
-- Shared data shapes. Everything saved in a profile is plain data (no Instances).

export type Item = {
	Uid: string,
	Kind: "Egg" | "Character",
	CharacterId: string,
	SizeTier: number,
	Kg: number,
	Mutation: string?,
	Awakened: boolean?,
	Color: number?, -- cosmetic palette index
	EggModel: string?, -- shell theme (defaults to the character's EggModel)
	HatchRemaining: number?, -- seconds left, while not incubating in a pen
	HatchEndsAt: number?, -- unix time, while incubating in a pen
	Lucky: boolean?,
	Protected: boolean?,
	Tutorial: boolean?,
	Source: string?,
}

export type IndexEntry = {
	Discovered: boolean,
	Claimed: boolean,
	Variants: { [string]: boolean },
	Awakened: boolean?,
}

export type FusionJob = {
	EndsAt: number,
	Result: Item,
	Kind: string, -- "Awaken" or recipe id
}

export type IncubatorJob = {
	EndsAt: number,
	Item: Item,
}

export type ProfileData = {
	DataVersion: number,
	Cash: number,
	TotalEarned: number,
	Speed: number,
	TreadmillTier: number, -- 0 = not unlocked
	PenLevel: number,
	BarrierLevel: number,
	Rebirths: number,
	EquippedTrail: string,
	OwnedTrails: { [string]: boolean },
	Traps: number,
	SmokeBombs: number,
	Register: number,
	Pen: { [string]: Item },
	Inventory: { Item },
	Index: { [string]: IndexEntry },
	BossCleared: boolean,
	ProcessedPurchases: { string },
	RedeemedCodes: { [string]: boolean },
	Login: { Streak: number, LastDay: number, ClaimedDay: number },
	LastOnline: number,
	FirstJoin: number,
	Playtime: number,
	Tutorial: { Step: number, Done: boolean, GiftGiven: boolean },
	Settings: { Music: number, Sfx: number, LowGraphics: boolean, HideTrails: boolean },
	Fusion: { FusionJob },
	Incubator: { IncubatorJob },
	Boosts: { LuckEndsAt: number },
	Titles: { [string]: boolean },
	EquippedTitle: string,
	GroupRewardClaimed: boolean,
	SeenReveals: { [string]: boolean },
	Stats: { HighestIncome: number, EggsStolen: number, Hatched: number, EggsGrabbed: number },
	FirstEggPlaced: boolean,
	Credits: { [string]: number }, -- e.g. Instant Hatch bought with no matching egg
}

return {}
