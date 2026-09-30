--!nocheck
-- The Heavenly Gatekeeper gauntlet (three rising terraces with ramps) and Celestial Sakura
-- Heights (zone 11) on the clouds, with the golden gate and the Sacred Tree Incubator.

local C = require("./Common")
local Vector3, CFrame, Enum = C.Vector3, C.CFrame, C.Enum

local Gauntlet = {}

local HALF_WIDTH = 50

-- solid block whose top surface is at `top`, spanning z range
local function terrace(parent, name, top, zMin, zMax, color)
	return C.part({
		Name = name,
		Size = Vector3.new(HALF_WIDTH * 2, math.max(top, 0.4), zMax - zMin),
		CFrame = CFrame.new(0, math.max(top, 0.4) / 2 - (if top <= 0.4 then 0.3 else 0), (zMin + zMax) / 2),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- ramp rising from `bottom` at zMax to `top` at zMin
local function ramp(parent, name, bottom, top, zMin, zMax, color)
	local height = top - bottom
	local length = zMax - zMin
	C.part({
		Name = name,
		Class = "WedgePart",
		Size = Vector3.new(HALF_WIDTH * 2, height, length),
		CFrame = CFrame.new(0, bottom + height / 2, (zMin + zMax) / 2) * CFrame.Angles(0, math.rad(180), 0),
		Color = color,
		Parent = parent,
	})
	if bottom > 0.5 then
		C.part({ Name = name .. "Base", Size = Vector3.new(HALF_WIDTH * 2, bottom, length), CFrame = CFrame.new(0, bottom / 2, (zMin + zMax) / 2), Color = color, Parent = parent })
	end
end

local function area(parent, phase, zMin, zMax, floorTop, origin)
	C.part({
		Name = "Phase" .. phase .. "Area",
		Size = Vector3.new(HALF_WIDTH * 2, 24, zMax - zMin),
		CFrame = CFrame.new(0, floorTop + 12, (zMin + zMax) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Tags = { "GauntletArea" },
		Attributes = { Phase = phase, FloorY = floorTop, OriginX = origin.X, OriginY = origin.Y, OriginZ = origin.Z },
		Parent = parent,
	})
end

function Gauntlet.Build(map, zonesFolder, ZonesConfig, ZonesMap)
	local folder = C.folder("Gauntlet", map)
	local cloud = "#F8F9FA"
	local gold = "#FFD86B"

	-- approach from zone 10
	terrace(folder, "Approach", 0.1, -445, -423, "#E0E1DD")
	C.part({
		Name = "GauntletStart",
		Size = Vector3.new(HALF_WIDTH * 2, 14, 4),
		CFrame = CFrame.new(0, 7, -438),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Tags = { "GauntletStart" },
		Parent = folder,
	})
	local banner = C.part({
		Name = "GauntletSign",
		Size = Vector3.new(30, 5, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(0, 20, -426), Vector3.new(0, 20, -416)),
		Color = "#1B1B1E",
		CanCollide = false,
		Tags = { "ZoneGate" },
		Attributes = { ZoneId = 11 },
		Parent = folder,
	})
	C.label(banner, "HEAVENLY GATEKEEPER'S GAUNTLET", { Color = gold, Subtext = "Reach the golden gate with fewer than 3 hits" })

	-- phase 1: shockwave rings (jump them)
	terrace(folder, "Terrace1", 0.1, -492, -445, cloud)
	area(folder, 1, -492, -445, 0.1, Vector3.new(0, 0.1, -468))
	C.part({ Name = "StompMark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 8, 8), CFrame = CFrame.new(0, 0.3, -468) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	ramp(folder, "Ramp1", 0.1, 13, -505, -492, cloud)

	-- phase 2: falling golden petals
	terrace(folder, "Terrace2", 13, -552, -505, cloud)
	area(folder, 2, -552, -505, 13, Vector3.new(0, 13, -528.5))
	ramp(folder, "Ramp2", 13, 26, -565, -552, cloud)

	-- phase 3: sweeping staff (jump over it)
	terrace(folder, "Terrace3", 26, -615, -565, cloud)
	area(folder, 3, -615, -565, 26, Vector3.new(0, 26, -590))
	C.part({ Name = "StaffPivot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 4, 4), CFrame = CFrame.new(0, 29, -590) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = Enum.Material.Metal, Parent = folder })
	ramp(folder, "Ramp3", 26, 40, -629, -615, cloud)

	-- gate terrace, finish line and the golden gate
	terrace(folder, "GateTerrace", 40, -642, -629, cloud)
	C.part({
		Name = "GauntletFinish",
		Size = Vector3.new(HALF_WIDTH * 2, 14, 4),
		CFrame = CFrame.new(0, 47, -636),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Tags = { "GauntletFinish" },
		Parent = folder,
	})
	local gate = C.model("HeavenGate", folder)
	for _, x in { -22, 22 } do
		C.part({ Name = "GatePillar", Size = Vector3.new(4, 30, 4), CFrame = CFrame.new(x, 55, -642), Color = gold, Material = Enum.Material.Metal, Parent = gate })
	end
	C.part({ Name = "GateArch", Size = Vector3.new(50, 4, 5), CFrame = CFrame.new(0, 71, -642), Color = gold, Material = Enum.Material.Metal, Parent = gate })
	C.part({
		Name = "GateBarrier",
		Size = Vector3.new(40, 28, 1),
		CFrame = CFrame.new(0, 54, -642),
		Color = gold,
		Material = Enum.Material.ForceField,
		Transparency = 0.3,
		Tags = { "HeavenGate" },
		Parent = gate,
	})
	for _, x in { -37, 37 } do
		C.part({ Name = "GateWall", Size = Vector3.new(26, 30, 2), CFrame = CFrame.new(x, 55, -642), Color = "#FFF6D5", Parent = gate })
	end

	-- the Heavenly Gatekeeper (placeholder statue; decorative, the hazards are server-run)
	local boss = C.model("HeavenlyGatekeeper", folder)
	boss:AddTag("GauntletBoss")
	local bx, bz = -38, -655
	C.part({ Name = "Legs", Size = Vector3.new(10, 12, 6), CFrame = CFrame.new(bx, 46, bz), Color = "#E0E1DD", Material = Enum.Material.Marble, Parent = boss })
	C.part({ Name = "Body", Size = Vector3.new(14, 14, 8), CFrame = CFrame.new(bx, 59, bz), Color = gold, Material = Enum.Material.Metal, Parent = boss })
	C.part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9), CFrame = CFrame.new(bx, 70.5, bz), Color = "#E0E1DD", Material = Enum.Material.Marble, Parent = boss })
	C.part({ Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 12, 12), CFrame = CFrame.new(bx, 78, bz) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = Enum.Material.Neon, CanCollide = false, Parent = boss })
	C.part({ Name = "Staff", Size = Vector3.new(1.6, 34, 1.6), CFrame = CFrame.new(bx + 10, 57, bz - 2), Color = "#9C6B3E", Parent = boss })

	-- zone 11 cloud platform
	local layout = ZonesMap.Layouts[11]
	local zone = ZonesConfig.Get(11)
	local zoneFolder = ZonesMap.BuildZone(zonesFolder, zone, layout)
	local heights = C.folder("Placeholder", zoneFolder)
	terrace(heights, "CloudFloor", 40, -800, -642, "#FFFFFF")
	for index = 1, 14 do
		local side = if index % 2 == 0 then 1 else -1
		C.part({
			Name = "CloudPuff",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(14, 14, 14),
			CFrame = CFrame.new(side * (52 + (index % 3) * 3), 38 + (index % 4) * 2, -650 - index * 11),
			Color = "#FFFFFF",
			CanCollide = false,
			Parent = heights,
		})
	end
	-- sacred tree
	C.part({ Name = "SacredTrunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 9, 9), CFrame = CFrame.new(0, 57, -786) * CFrame.Angles(0, 0, math.rad(90)), Color = "#6F4E37", Material = Enum.Material.Wood, Parent = heights })
	for index, offset in { Vector3.new(0, 80, -786), Vector3.new(-12, 74, -782), Vector3.new(12, 75, -790), Vector3.new(0, 72, -774) } do
		C.part({ Name = "SacredBlossom" .. index, Shape = Enum.PartType.Ball, Size = Vector3.new(24, 20, 24), CFrame = CFrame.new(offset), Color = "#FFB7C5", CanCollide = false, Parent = heights })
	end
	local altar = C.part({
		Name = "SacredIncubator",
		Size = Vector3.new(9, 3, 9),
		CFrame = CFrame.new(0, 41.5, -768),
		Color = gold,
		Material = Enum.Material.Marble,
		Tags = { "SacredIncubator" },
		Parent = heights,
	})
	C.label(altar, "SACRED TREE INCUBATOR", { Color = "#FFB7C5", Billboard = true, Subtext = "Bring an unhatched egg" })
	C.part({ Name = "IncubatorGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 10, 10), CFrame = CFrame.new(0, 43.2, -768) * CFrame.Angles(0, 0, math.rad(90)), Color = "#FFB7C5", Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, Parent = heights })
	return folder
end

return Gauntlet
