--!strict
-- Treadmill tiers. Standing on your treadmill gains Speed every second (works AFK).
-- Tier 1 is the $1,000 unlock. Each tier re-skins the treadmill in its zone's style.

export type Treadmill = {
	Tier: number,
	DisplayName: string,
	Gain: number, -- Speed per second before multipliers
	Price: number,
	Belt: string, -- belt color
	Frame: string, -- frame color
	Accent: string,
	Material: string, -- Enum.Material name for the belt
}

local list: { Treadmill } = {
	{ Tier = 1, DisplayName = "Gym Class Treadmill", Gain = 1, Price = 1000, Belt = "#3A3A3A", Frame = "#F1F1F1", Accent = "#FF8FAB", Material = "SmoothPlastic" },
	{ Tier = 2, DisplayName = "Ramen-Stall Belt", Gain = 5, Price = 15000, Belt = "#2B2D42", Frame = "#E63946", Accent = "#3FF2FF", Material = "Fabric" },
	{ Tier = 3, DisplayName = "Shrine Stone Path", Gain = 25, Price = 250000, Belt = "#8D8D8D", Frame = "#C1121F", Accent = "#FF9E00", Material = "Slate" },
	{ Tier = 4, DisplayName = "Boardwalk Runner", Gain = 100, Price = 6000000, Belt = "#C68B59", Frame = "#48CAE4", Accent = "#FFD166", Material = "WoodPlanks" },
	{ Tier = 5, DisplayName = "Ninja Log Runner", Gain = 400, Price = 150000000, Belt = "#6B4F3A", Frame = "#2B2B3A", Accent = "#C1121F", Material = "Wood" },
	{ Tier = 6, DisplayName = "Idol Stage Belt", Gain = 1500, Price = 3500000000, Belt = "#1A1423", Frame = "#FF70A6", Accent = "#70D6FF", Material = "Glass" },
	{ Tier = 7, DisplayName = "Mecha Conveyor", Gain = 6000, Price = 60000000000, Belt = "#343A40", Frame = "#FFBA08", Accent = "#4361EE", Material = "DiamondPlate" },
	{ Tier = 8, DisplayName = "Enchanted Path", Gain = 25000, Price = 80000000000, Belt = "#80FFDB", Frame = "#D6CCC2", Accent = "#577590", Material = "Glass" },
	{ Tier = 9, DisplayName = "Demon Forge Belt", Gain = 100000, Price = 600000000000, Belt = "#2E1F27", Frame = "#1B1B1E", Accent = "#FF4800", Material = "CrackedLava" },
	{ Tier = 10, DisplayName = "Celestial Cloud Runner", Gain = 400000, Price = 5000000000000, Belt = "#FFFFFF", Frame = "#FFD86B", Accent = "#FFB7C5", Material = "Neon" },
}

local Treadmills = {
	List = list,
	MaxTier = #list,
}

function Treadmills.Get(tier: number): Treadmill?
	return list[tier]
end

return Treadmills
