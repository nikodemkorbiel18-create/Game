--!strict
-- Zones (biomes), their Guardians and egg spawn tables.
-- Map geometry lives in Studio (see docs/STUDIO_SETUP.md); this module only holds data.

export type GuardianAbility = {
	Type: string,
	Enabled: boolean,
	Interval: number?,
	Duration: number?,
	Multiplier: number?,
	Radius: number?,
	Distance: number?,
}

export type Guardian = {
	Id: string,
	DisplayName: string,
	Template: string, -- model name in ServerStorage.Assets.Guardians
	Count: number,
	DetectRadiusMult: number,
	Ability: GuardianAbility,
	Color: string,
}

export type SpecialRoll = {
	Rarity: string,
	Chance: number, -- per reset, one pedestal is upgraded
}

export type Zone = {
	Id: number,
	Key: string,
	DisplayName: string,
	Setting: string,
	RecSpeed: number,
	HardGate: boolean,
	Guardian: Guardian,
	EggTheme: {
		Name: string,
		Overlay: string,
		Model: string, -- optional mesh egg in ReplicatedStorage.Assets.Eggs
		Palette: { string },
	},
	RarityWeights: { [string]: number },
	Special: { SpecialRoll },
	Theme: {
		Floor: string,
		Wall: string,
		Accent: string,
		Ambient: string,
		FogColor: string,
		FogEnd: number,
		Music: string,
	},
}

local zones: { Zone } = {
	{
		Id = 1,
		Key = "SakuraAcademy",
		DisplayName = "Sakura Academy",
		Setting = "School courtyard, cherry trees, lockers, rooftop",
		RecSpeed = 0,
		HardGate = false,
		Guardian = {
			Id = "HallMonitor",
			DisplayName = "Hall Monitor Sensei",
			Template = "HallMonitor",
			Count = 1,
			DetectRadiusMult = 1,
			Ability = { Type = "Whistle", Enabled = true, Radius = 120 },
			Color = "#3D5A80",
		},
		EggTheme = {
			Name = "School-Crest Egg",
			Overlay = "SailorRibbon",
			Model = "Egg_Zone1",
			Palette = { "#FFD1DC", "#FFFFFF", "#BDE0FE", "#FFF3B0", "#CDB4DB" },
		},
		RarityWeights = { Common = 60, Uncommon = 28, Rare = 9, Epic = 3 },
		Special = {},
		Theme = { Floor = "#EBDCCB", Wall = "#F7C8D0", Accent = "#FF8FAB", Ambient = "#FFE9EF", FogColor = "#FFE4EC", FogEnd = 1200, Music = "Zone1" },
	},
	{
		Id = 2,
		Key = "NeonRamenAlley",
		DisplayName = "Neon Ramen Alley",
		Setting = "Night market, lanterns, arcade, vending machines",
		RecSpeed = 250,
		HardGate = false,
		Guardian = {
			Id = "RamenMaster",
			DisplayName = "Ramen Master",
			Template = "RamenMaster",
			Count = 1,
			DetectRadiusMult = 1,
			Ability = { Type = "NoodleSplash", Enabled = true, Interval = 8, Duration = 2, Multiplier = 0.6, Radius = 30 },
			Color = "#FF4FA0",
		},
		EggTheme = {
			Name = "Neon Ceramic Egg",
			Overlay = "NeonCeramic",
			Model = "Egg_Zone2",
			Palette = { "#F4E1C1", "#2B2D42", "#FFB4A2", "#A0C4FF", "#FFD6A5" },
		},
		RarityWeights = { Common = 57, Uncommon = 28, Rare = 10, Epic = 4, Legendary = 1 },
		Special = {},
		Theme = { Floor = "#2B2D42", Wall = "#3A0CA3", Accent = "#3FF2FF", Ambient = "#8E7DFF", FogColor = "#1B1035", FogEnd = 900, Music = "Zone2" },
	},
	{
		Id = 3,
		Key = "KitsuneShrineForest",
		DisplayName = "Kitsune Shrine Forest",
		Setting = "Torii paths, bamboo, fox statues, fireflies",
		RecSpeed = 1500,
		HardGate = false,
		Guardian = {
			Id = "StoneKomainu",
			DisplayName = "Stone Komainu",
			Template = "Guardian_StoneKomainu",
			Count = 1,
			DetectRadiusMult = 1,
			Ability = { Type = "Statue", Enabled = true, Duration = 5, Multiplier = 1.5 },
			Color = "#9A9A9A",
		},
		EggTheme = {
			Name = "Shimenawa Charm Egg",
			Overlay = "ShimenawaRope",
			Model = "Egg_Zone3",
			Palette = { "#FFFFFF", "#F2E8CF", "#E63946", "#FFB5A7", "#D8E2DC" },
		},
		RarityWeights = { Uncommon = 57, Rare = 28, Epic = 10, Legendary = 4, Mythic = 1 },
		Special = {},
		Theme = { Floor = "#4F6D3A", Wall = "#2D4A22", Accent = "#FF7B00", Ambient = "#FFC58F", FogColor = "#20301A", FogEnd = 800, Music = "Zone3" },
	},
	{
		Id = 4,
		Key = "BeachEpisodeCoast",
		DisplayName = "Beach Episode Coast",
		Setting = "Beach, pier, festival stalls, sunset",
		RecSpeed = 8000,
		HardGate = false,
		Guardian = {
			Id = "LifeguardCaptain",
			DisplayName = "Lifeguard Captain",
			Template = "Guardian_LifeguardCaptain",
			Count = 1,
			DetectRadiusMult = 1,
			Ability = { Type = "SprintBurst", Enabled = true, Interval = 10, Duration = 1.5, Multiplier = 1.5 },
			Color = "#E63946",
		},
		EggTheme = {
			Name = "Seashell Egg",
			Overlay = "BeachStripes",
			Model = "Egg_Zone4",
			Palette = { "#FFE5B4", "#48CAE4", "#FF6B6B", "#FFD166", "#FFFFFF" },
		},
		RarityWeights = { Uncommon = 57, Rare = 28, Epic = 10, Legendary = 4, Mythic = 1 },
		Special = {},
		Theme = { Floor = "#F6D7A7", Wall = "#48CAE4", Accent = "#FF9E6D", Ambient = "#FFC4A3", FogColor = "#FFB88C", FogEnd = 1500, Music = "Zone4" },
	},
	{
		Id = 5,
		Key = "HiddenNinjaVillage",
		DisplayName = "Hidden Ninja Village",
		Setting = "Rooftops, watchtowers, rope bridges, waterfall",
		RecSpeed = 40000,
		HardGate = false,
		Guardian = {
			Id = "MaskedSentinel",
			DisplayName = "Masked Sentinel",
			Template = "Guardian_MaskedSentinel",
			Count = 2,
			DetectRadiusMult = 1,
			Ability = { Type = "Blink", Enabled = true, Interval = 10, Distance = 10 },
			Color = "#2B2B3A",
		},
		EggTheme = {
			Name = "Shadow-Cloth Egg",
			Overlay = "NinjaCloth",
			Model = "Egg_Zone5",
			Palette = { "#3A3A4A", "#5C677D", "#7D8597", "#6A040F", "#1B263B" },
		},
		RarityWeights = { Rare = 60, Epic = 28, Legendary = 9, Mythic = 3 },
		Special = {},
		Theme = { Floor = "#6B5E4A", Wall = "#3E3B32", Accent = "#C1121F", Ambient = "#B8C5D6", FogColor = "#8AA1B1", FogEnd = 700, Music = "Zone5" },
	},
	{
		Id = 6,
		Key = "IdolConcertDome",
		DisplayName = "Idol Concert Dome",
		Setting = "Stage, glowstick crowd, backstage",
		RecSpeed = 200000,
		HardGate = false,
		Guardian = {
			Id = "StageManager",
			DisplayName = "Stage Manager",
			Template = "Guardian_StageManager",
			Count = 2,
			DetectRadiusMult = 1.6,
			Ability = { Type = "Spotlight", Enabled = true, Multiplier = 1.6 },
			Color = "#212529",
		},
		EggTheme = {
			Name = "Glitter Star Egg",
			Overlay = "GlitterStars",
			Model = "Egg_Zone6",
			Palette = { "#FF70A6", "#FF9770", "#FFD670", "#70D6FF", "#C77DFF" },
		},
		RarityWeights = { Epic = 60, Legendary = 28, Mythic = 9, Cosmic = 3 },
		Special = {},
		Theme = { Floor = "#1A1423", Wall = "#3D1A5B", Accent = "#FF70A6", Ambient = "#C77DFF", FogColor = "#2A0F3F", FogEnd = 900, Music = "Zone6" },
	},
	{
		Id = 7,
		Key = "MechaHangar",
		DisplayName = "Mecha Hangar",
		Setting = "Giant robot bay, catwalks, launch rails",
		RecSpeed = 1000000,
		HardGate = false,
		Guardian = {
			Id = "PatrolMech",
			DisplayName = "Patrol Mech",
			Template = "Guardian_PatrolMech",
			Count = 2,
			DetectRadiusMult = 1,
			Ability = { Type = "Mech", Enabled = true, Multiplier = 1.25 },
			Color = "#495057",
		},
		EggTheme = {
			Name = "Armor-Core Egg",
			Overlay = "ArmorCore",
			Model = "Egg_Zone7",
			Palette = { "#ADB5BD", "#F8F9FA", "#FFBA08", "#4361EE", "#E5383B" },
		},
		RarityWeights = { Legendary = 62, Mythic = 29, Cosmic = 9 },
		Special = {},
		Theme = { Floor = "#495057", Wall = "#343A40", Accent = "#FFBA08", Ambient = "#CED4DA", FogColor = "#6C757D", FogEnd = 900, Music = "Zone7" },
	},
	{
		Id = 8,
		Key = "IsekaiKingdom",
		DisplayName = "Isekai Kingdom",
		Setting = "Fantasy castle town, guild hall, slime meadows",
		RecSpeed = 5000000,
		HardGate = false,
		Guardian = {
			Id = "KnightCaptain",
			DisplayName = "Royal Knight Captain",
			Template = "Guardian_KnightCaptain",
			Count = 2,
			DetectRadiusMult = 1,
			Ability = { Type = "Charge", Enabled = true, Interval = 9, Duration = 1, Multiplier = 2 },
			Color = "#CAD2C5",
		},
		EggTheme = {
			Name = "Rune Crystal Egg",
			Overlay = "RuneCrystal",
			Model = "Egg_Zone8",
			Palette = { "#80FFDB", "#72EFDD", "#B8F2E6", "#AED9E0", "#FAF3DD" },
		},
		RarityWeights = { Legendary = 62, Mythic = 29, Cosmic = 9 },
		Special = {},
		Theme = { Floor = "#90BE6D", Wall = "#D6CCC2", Accent = "#577590", Ambient = "#FFF3B0", FogColor = "#CDEAC0", FogEnd = 1400, Music = "Zone8" },
	},
	{
		Id = 9,
		Key = "DemonLordsCastle",
		DisplayName = "Demon Lord's Castle",
		Setting = "Gothic halls, lava moat, bats",
		RecSpeed = 25000000,
		HardGate = false,
		Guardian = {
			Id = "DemonGeneral",
			DisplayName = "Demon General",
			Template = "Guardian_DemonGeneral",
			Count = 2,
			DetectRadiusMult = 1,
			Ability = { Type = "BatSwarm", Enabled = true, Interval = 12, Duration = 3, Multiplier = 0.7, Radius = 35 },
			Color = "#6A040F",
		},
		EggTheme = {
			Name = "Obsidian Bat Egg",
			Overlay = "ObsidianWings",
			Model = "Egg_Zone9",
			Palette = { "#1B1B1E", "#3C1642", "#6A040F", "#2E1F27", "#403D58" },
		},
		RarityWeights = { Mythic = 65, Cosmic = 34.5, Secret = 0.5 },
		Special = { { Rarity = "Secret", Chance = 0.025 } },
		Theme = { Floor = "#2E1F27", Wall = "#1B1B1E", Accent = "#FF4800", Ambient = "#9D4EDD", FogColor = "#3C1642", FogEnd = 700, Music = "Zone9" },
	},
	{
		Id = 10,
		Key = "SpiritRealm",
		DisplayName = "Spirit Realm",
		Setting = "Floating lanterns, river of stars, ghost town",
		RecSpeed = 120000000,
		HardGate = false,
		Guardian = {
			Id = "MistveilSpirit",
			DisplayName = "Mistveil Spirit",
			Template = "Guardian_MistveilSpirit",
			Count = 2,
			DetectRadiusMult = 1,
			Ability = { Type = "Phase", Enabled = true },
			Color = "#A2D2FF",
		},
		EggTheme = {
			Name = "Ghostfire Egg",
			Overlay = "Ghostfire",
			Model = "Egg_Zone10",
			Palette = { "#CAF0F8", "#ADE8F4", "#E0AAFF", "#BDE0FE", "#FFFFFF" },
		},
		RarityWeights = { Cosmic = 96.9, Secret = 3, Divine = 0.1 },
		Special = { { Rarity = "Secret", Chance = 0.025 }, { Rarity = "Divine", Chance = 0.006 } },
		Theme = { Floor = "#10002B", Wall = "#240046", Accent = "#7FDBFF", Ambient = "#9BB1FF", FogColor = "#10002B", FogEnd = 650, Music = "Zone10" },
	},
	{
		Id = 11,
		Key = "CelestialSakuraHeights",
		DisplayName = "Celestial Sakura Heights",
		Setting = "Clouds, giant sacred tree, golden gates",
		RecSpeed = 500000000,
		HardGate = true,
		Guardian = {
			Id = "CelestialWarden",
			DisplayName = "Celestial Warden",
			Template = "Guardian_CelestialWarden",
			Count = 2,
			DetectRadiusMult = 1,
			Ability = { Type = "PetalField", Enabled = true, Multiplier = 0.8, Radius = 25 },
			Color = "#FFF1C1",
		},
		EggTheme = {
			Name = "Halo Petal Egg",
			Overlay = "HaloPetals",
			Model = "Egg_Zone11",
			Palette = { "#FFFFFF", "#FFF6D5", "#FFE5EC", "#FFD86B", "#F8EDEB" },
		},
		RarityWeights = { Divine = 100 },
		Special = { { Rarity = "Divine", Chance = 0.006 }, { Rarity = "Eternal", Chance = 0.0015 } },
		Theme = { Floor = "#FFFFFF", Wall = "#FFE5EC", Accent = "#FFD86B", Ambient = "#FFF6E0", FogColor = "#FFF0F5", FogEnd = 1600, Music = "Zone11" },
	},
}

local byId: { [number]: Zone } = {}
for _, zone in zones do
	byId[zone.Id] = zone
end

local Zones = {
	List = zones,
	ById = byId,
	Count = #zones,
}

function Zones.Get(id: number): Zone
	local zone = byId[id]
	assert(zone, "Unknown zone " .. tostring(id))
	return zone
end

return Zones
