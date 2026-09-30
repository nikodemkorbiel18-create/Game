--!strict
-- Rarity tiers. Rank drives ordering, UI color, egg ornament and base hatch time.

export type Rarity = {
	Id: string,
	Rank: number,
	DisplayName: string,
	Color: string, -- hex
	Color2: string?, -- second gradient stop (Cosmic, Divine, Eternal)
	HatchTime: number, -- seconds before size/mutation multipliers
	Ornament: string, -- egg shell ornament (see Visual/EggBuilder)
	AuraSize: number, -- 0 = no aura
	SellConfirm: boolean,
}

local list: { Rarity } = {
	{ Id = "Common", Rank = 1, DisplayName = "Common", Color = "#B8C0CC", HatchTime = 10, Ornament = "Plain", AuraSize = 0, SellConfirm = false },
	{ Id = "Uncommon", Rank = 2, DisplayName = "Uncommon", Color = "#4CD964", HatchTime = 30, Ornament = "Banded", AuraSize = 0, SellConfirm = false },
	{ Id = "Rare", Rank = 3, DisplayName = "Rare", Color = "#3FA9F5", HatchTime = 90, Ornament = "Gem", AuraSize = 0, SellConfirm = false },
	{ Id = "Epic", Rank = 4, DisplayName = "Epic", Color = "#A259FF", HatchTime = 300, Ornament = "Wings", AuraSize = 1, SellConfirm = false },
	{ Id = "Legendary", Rank = 5, DisplayName = "Legendary", Color = "#FFC93C", HatchTime = 900, Ornament = "Crown", AuraSize = 1.5, SellConfirm = true },
	{ Id = "Mythic", Rank = 6, DisplayName = "Mythic", Color = "#FF4757", HatchTime = 2700, Ornament = "Horns", AuraSize = 2, SellConfirm = true },
	{ Id = "Cosmic", Rank = 7, DisplayName = "Cosmic", Color = "#34E7E4", Color2 = "#FF4FD8", HatchTime = 7200, Ornament = "Stars", AuraSize = 2.5, SellConfirm = true },
	{ Id = "Secret", Rank = 8, DisplayName = "Secret", Color = "#141414", Color2 = "#7CFF4F", HatchTime = 21600, Ornament = "Glitch", AuraSize = 3, SellConfirm = true },
	{ Id = "Divine", Rank = 9, DisplayName = "Divine", Color = "#FFF6D5", Color2 = "#FFD86B", HatchTime = 43200, Ornament = "Halo", AuraSize = 3.5, SellConfirm = true },
	{ Id = "Eternal", Rank = 10, DisplayName = "Eternal", Color = "#FF9ECF", Color2 = "#8FE3FF", HatchTime = 86400, Ornament = "SakuraCrystal", AuraSize = 4, SellConfirm = true },
}

local byId: { [string]: Rarity } = {}
local byRank: { [number]: Rarity } = {}
for _, rarity in list do
	byId[rarity.Id] = rarity
	byRank[rarity.Rank] = rarity
end

local Rarities = {
	List = list,
	ById = byId,
	ByRank = byRank,
	MaxRank = #list,
}

function Rarities.Get(id: string): Rarity
	local rarity = byId[id]
	assert(rarity, "Unknown rarity " .. tostring(id))
	return rarity
end

function Rarities.Rank(id: string): number
	return Rarities.Get(id).Rank
end

-- One tier higher (used by Awakened characters), capped at the top tier.
function Rarities.Next(id: string): Rarity
	local rank = math.min(Rarities.Rank(id) + 1, #list)
	return byRank[rank]
end

return Rarities
