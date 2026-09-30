--!strict
-- Trails: equip one; it multiplies treadmill Speed gain. Kept through rebirth.

export type Trail = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Multiplier: number,
	Price: number, -- cash; 0 = not for sale (reward only)
	Colors: { string },
	Particles: string?, -- optional particle style
	Width: number,
	Order: number,
}

local list: { Trail } = {
	{ Id = "SpeedLines", DisplayName = "Speed Lines", Rarity = "Common", Multiplier = 1.1, Price = 25000, Colors = { "#FFFFFF", "#B8C0CC" }, Width = 1.2, Order = 1 },
	{ Id = "SakuraPetals", DisplayName = "Sakura Petals", Rarity = "Uncommon", Multiplier = 1.25, Price = 400000, Colors = { "#FFB7C5", "#FFE5EC" }, Particles = "Petals", Width = 1.4, Order = 2 },
	{ Id = "PaperCharms", DisplayName = "Paper Charms", Rarity = "Rare", Multiplier = 1.4, Price = 12000000, Colors = { "#F2E8CF", "#D00000" }, Particles = "Charms", Width = 1.4, Order = 3 },
	{ Id = "RamenSteam", DisplayName = "Ramen Steam", Rarity = "Rare", Multiplier = 1.5, Price = 100000000, Colors = { "#FFFFFF", "#FFD6A5" }, Particles = "Steam", Width = 1.6, Order = 4 },
	{ Id = "LightningDash", DisplayName = "Lightning Dash", Rarity = "Epic", Multiplier = 1.75, Price = 4000000000, Colors = { "#FFD60A", "#00B4D8" }, Particles = "Sparks", Width = 1.6, Order = 5 },
	{ Id = "NeonAfterimage", DisplayName = "Neon Afterimage", Rarity = "Epic", Multiplier = 2.0, Price = 100000000000, Colors = { "#FF006E", "#3FF2FF" }, Width = 2, Order = 6 },
	{ Id = "FoxFire", DisplayName = "Fox Fire", Rarity = "Legendary", Multiplier = 2.5, Price = 2500000000000, Colors = { "#7FDBFF", "#FF9E00" }, Particles = "Foxfire", Width = 2, Order = 7 },
	{ Id = "Starfall", DisplayName = "Starfall", Rarity = "Mythic", Multiplier = 3.0, Price = 55000000000000, Colors = { "#FFD86B", "#7B2CBF" }, Particles = "Stars", Width = 2.2, Order = 8 },
	{ Id = "MechaThrusters", DisplayName = "Mecha Thrusters", Rarity = "Cosmic", Multiplier = 3.75, Price = 1500000000000000, Colors = { "#4361EE", "#FFBA08" }, Particles = "Thrust", Width = 2.2, Order = 9 },
	{ Id = "KamiHalo", DisplayName = "Kami Halo", Rarity = "Divine", Multiplier = 5.0, Price = 15000000000000000, Colors = { "#FFF6D5", "#FFD86B" }, Particles = "Halo", Width = 2.6, Order = 10 },
	{ Id = "MainCharacter", DisplayName = "Main Character", Rarity = "Eternal", Multiplier = 6.0, Price = 0, Colors = { "#FF9ECF", "#8FE3FF", "#FFD86B" }, Particles = "Petals", Width = 3, Order = 11 },
}

local byId: { [string]: Trail } = {}
for _, trail in list do
	byId[trail.Id] = trail
end

local Trails = {
	List = list,
	ById = byId,
}

function Trails.Get(id: string?): Trail?
	if id == nil then
		return nil
	end
	return byId[id]
end

function Trails.Multiplier(id: string?): number
	local trail = Trails.Get(id)
	return if trail then trail.Multiplier else 1
end

return Trails
