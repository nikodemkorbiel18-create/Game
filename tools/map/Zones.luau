--!nocheck
-- Zone gameplay content: bounds, nest + 8 egg pedestals, Guardian spawns and patrol
-- waypoints, cover objects and the zone sign/torii gate. Zones 1-3 reuse the existing
-- school / ramen / shrine art; zones 4-10 get placeholder architecture in their palette.

local C = require("./Common")
local Vector3, CFrame, Enum = C.Vector3, C.CFrame, C.Enum

local Zones = {}

-- z ranges run from home (+Z) toward the endgame (-Z). Corridor is centered on x = 0.
Zones.Layouts = {
	[1] = {
		ZMin = 573.8, ZMax = 672.8, Existing = true, Nest = { 0, 594 }, Radius = 8,
		Waypoints = { { -5, 660 }, { 5, 660 }, { 5, 586 }, { -5, 586 } },
		Cover = { { "Locker", -7, 640, 2, 7, 2, "#7D8CC4" }, { "Locker", 7, 618, 2, 7, 2, "#7D8CC4" } },
	},
	[2] = {
		ZMin = 460, ZMax = 574, Existing = true, Nest = { 0, 484 }, Radius = 10,
		Waypoints = { { -30, 558 }, { 30, 558 }, { 30, 478 }, { -30, 478 } },
		Cover = { { "VendingMachine", -34, 532, 4, 8, 3, "#3A86FF" }, { "VendingMachine", 34, 508, 4, 8, 3, "#FF006E" }, { "NoodleStall", -22, 505, 8, 5, 5, "#E63946" } },
	},
	[3] = {
		ZMin = 347, ZMax = 461, Existing = true, Nest = { 27, 373 }, Radius = 9,
		Waypoints = { { 22, 450 }, { 38, 450 }, { 38, 362 }, { 22, 362 } },
		Cover = { { "StoneLantern", 33, 428, 3, 7, 3, "#9A9A9A" }, { "StoneLantern", -32, 402, 3, 7, 3, "#9A9A9A" }, { "FoxStatue", 22, 405, 4, 6, 4, "#BFBFBF" } },
	},
	[4] = { ZMin = 237, ZMax = 347 },
	[5] = { ZMin = 127, ZMax = 237 },
	[6] = { ZMin = 17, ZMax = 127 },
	[7] = { ZMin = -93, ZMax = 17 },
	[8] = { ZMin = -203, ZMax = -93 },
	[9] = { ZMin = -313, ZMax = -203 },
	[10] = { ZMin = -423, ZMax = -313 },
	[11] = { ZMin = -800, ZMax = -642, FloorY = 40, Nest = { 0, -712 }, Radius = 11 },
}

Zones.CorridorHalfWidth = 57
Zones.WallX = 58.5

local function floorY(layout)
	return layout.FloorY or 0.1
end

local function coverPiece(parent, spec, y)
	local name, x, z, sx, sy, sz, color = table.unpack(spec)
	return C.part({
		Name = name,
		Size = Vector3.new(sx, sy, sz),
		CFrame = CFrame.new(x, y + sy / 2, z),
		Color = color,
		Parent = parent,
	})
end

local function torii(parent, zone, layout, color)
	local y = floorY(layout)
	local z = layout.ZMax - 3
	local gate = C.model("ToriiGate", parent)
	for _, x in { -24, 24 } do
		C.part({ Name = "Pillar", Size = Vector3.new(2.2, 24, 2.2), CFrame = CFrame.new(x, y + 12, z), Color = color, Parent = gate })
	end
	C.part({ Name = "Kasagi", Size = Vector3.new(56, 2.2, 3.4), CFrame = CFrame.new(0, y + 24.5, z), Color = "#1B1B1E", Parent = gate })
	C.part({ Name = "Nuki", Size = Vector3.new(50, 1.6, 2), CFrame = CFrame.new(0, y + 20, z), Color = color, Parent = gate })
	return gate
end

local function zoneSign(parent, zone, layout, tall)
	local y = floorY(layout) + (if tall then 21 else 22)
	local z = layout.ZMax - 2.5
	local sign = C.part({
		Name = "ZoneSign",
		Size = Vector3.new(24, 5, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(0, y, z), Vector3.new(0, y, z + 10)),
		Color = "#1B1B1E",
		CanCollide = false,
		Tags = { "ZoneGate" },
		Attributes = { ZoneId = zone.Id },
		Parent = parent,
	})
	C.label(sign, string.format("ZONE %d · %s", zone.Id, string.upper(zone.DisplayName)), {
		Color = zone.Theme.Accent,
		Subtext = "Recommended Speed: " .. tostring(zone.RecSpeed),
	})
	return sign
end

-- Placeholder architecture for zones without art yet
local DECOR = {
	BeachEpisodeCoast = function(parent, layout, zone)
		local y = floorY(layout)
		C.part({ Name = "Water", Size = Vector3.new(40, 0.3, layout.ZMax - layout.ZMin), CFrame = CFrame.new(-37, y + 0.05, (layout.ZMin + layout.ZMax) / 2), Color = "#48CAE4", Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, Parent = parent })
		for index, z in { layout.ZMax - 20, layout.ZMax - 55, layout.ZMin + 30 } do
			local x = if index % 2 == 0 then 44 else -44
			C.part({ Name = "PalmTrunk", Size = Vector3.new(1.4, 16, 1.4), CFrame = CFrame.new(x, y + 8, z), Color = "#9C6644", Parent = parent })
			C.part({ Name = "PalmLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(x, y + 16, z), Color = "#2D6A4F", Parent = parent })
		end
		C.part({ Name = "Pier", Size = Vector3.new(10, 1, 40), CFrame = CFrame.new(-30, y + 0.5, layout.ZMin + 40), Color = "#C68B59", Material = Enum.Material.WoodPlanks, Parent = parent })
		C.part({ Name = "FestivalStall", Size = Vector3.new(10, 6, 6), CFrame = CFrame.new(34, y + 3, layout.ZMax - 40), Color = "#FF6B6B", Parent = parent })
	end,
	HiddenNinjaVillage = function(parent, layout, zone)
		local y = floorY(layout)
		for _, spec in { { -38, layout.ZMax - 25 }, { 38, layout.ZMin + 45 } } do
			C.part({ Name = "Watchtower", Size = Vector3.new(8, 18, 8), CFrame = CFrame.new(spec[1], y + 9, spec[2]), Color = "#6B5E4A", Material = Enum.Material.Wood, Parent = parent })
			C.part({ Name = "TowerRoof", Class = "WedgePart", Size = Vector3.new(10, 4, 10), CFrame = CFrame.new(spec[1], y + 20, spec[2]), Color = "#3E3B32", Parent = parent })
		end
		C.part({ Name = "RopeBridge", Size = Vector3.new(6, 0.6, 30), CFrame = CFrame.new(-20, y + 8, (layout.ZMin + layout.ZMax) / 2), Color = "#9C6644", Material = Enum.Material.WoodPlanks, Parent = parent })
		C.part({ Name = "Waterfall", Size = Vector3.new(16, 24, 2), CFrame = CFrame.new(40, y + 12, layout.ZMax - 60), Color = "#90E0EF", Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Parent = parent })
	end,
	IdolConcertDome = function(parent, layout, zone)
		local y = floorY(layout)
		C.part({ Name = "Stage", Size = Vector3.new(40, 3, 16), CFrame = CFrame.new(0, y + 1.5, layout.ZMin + 10), Color = "#3D1A5B", Parent = parent })
		for index = -3, 3 do
			C.part({ Name = "StageLight", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(index * 6, y + 26, layout.ZMin + 12), Color = if index % 2 == 0 then "#FF70A6" else "#70D6FF", Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		end
		for row = 0, 2 do
			for col = -4, 4 do
				if math.abs(col) > 1 then
					C.part({ Name = "Glowstick", Size = Vector3.new(0.3, 2, 0.3), CFrame = CFrame.new(col * 8, y + 1, layout.ZMax - 20 - row * 8), Color = if (row + col) % 2 == 0 then "#FF70A6" else "#70D6FF", Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
				end
			end
		end
	end,
	MechaHangar = function(parent, layout, zone)
		local y = floorY(layout)
		C.part({ Name = "RobotLegL", Size = Vector3.new(6, 24, 6), CFrame = CFrame.new(-38, y + 12, layout.ZMin + 40), Color = "#ADB5BD", Material = Enum.Material.DiamondPlate, Parent = parent })
		C.part({ Name = "RobotLegR", Size = Vector3.new(6, 24, 6), CFrame = CFrame.new(-38, y + 12, layout.ZMin + 60), Color = "#ADB5BD", Material = Enum.Material.DiamondPlate, Parent = parent })
		C.part({ Name = "RobotBody", Size = Vector3.new(10, 16, 28), CFrame = CFrame.new(-38, y + 32, layout.ZMin + 50), Color = "#E5383B", Material = Enum.Material.Metal, Parent = parent })
		C.part({ Name = "Catwalk", Size = Vector3.new(6, 0.6, layout.ZMax - layout.ZMin - 10), CFrame = CFrame.new(40, y + 10, (layout.ZMin + layout.ZMax) / 2), Color = "#FFBA08", Material = Enum.Material.DiamondPlate, Parent = parent })
		C.part({ Name = "LaunchRail", Size = Vector3.new(2, 0.4, layout.ZMax - layout.ZMin - 10), CFrame = CFrame.new(20, y + 0.2, (layout.ZMin + layout.ZMax) / 2), Color = "#4361EE", Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	end,
	IsekaiKingdom = function(parent, layout, zone)
		local y = floorY(layout)
		for _, x in { -40, 40 } do
			C.part({ Name = "CastleTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 10, 10), CFrame = CFrame.new(x, y + 13, layout.ZMin + 20) * CFrame.Angles(0, 0, math.rad(90)), Color = "#D6CCC2", Material = Enum.Material.Cobblestone, Parent = parent })
			C.part({ Name = "TowerRoof", Class = "WedgePart", Size = Vector3.new(11, 7, 11), CFrame = CFrame.new(x, y + 29.5, layout.ZMin + 20), Color = "#577590", Parent = parent })
		end
		C.part({ Name = "GuildHall", Size = Vector3.new(16, 12, 14), CFrame = CFrame.new(38, y + 6, layout.ZMax - 35), Color = "#BC6C25", Material = Enum.Material.WoodPlanks, Parent = parent })
		for index = 1, 4 do
			C.part({ Name = "Slime", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(-40 + index * 4, y + 1.5, layout.ZMax - 25 - index * 6), Color = "#80ED99", Material = Enum.Material.Glass, Transparency = 0.2, Parent = parent })
		end
	end,
	DemonLordsCastle = function(parent, layout, zone)
		local y = floorY(layout)
		C.part({ Name = "LavaMoatL", Size = Vector3.new(8, 0.3, layout.ZMax - layout.ZMin), CFrame = CFrame.new(-46, y + 0.1, (layout.ZMin + layout.ZMax) / 2), Color = "#FF4800", Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		C.part({ Name = "LavaMoatR", Size = Vector3.new(8, 0.3, layout.ZMax - layout.ZMin), CFrame = CFrame.new(46, y + 0.1, (layout.ZMin + layout.ZMax) / 2), Color = "#FF4800", Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		for index = 0, 4 do
			C.part({ Name = "GothicPillar", Size = Vector3.new(3, 26, 3), CFrame = CFrame.new(if index % 2 == 0 then -32 else 32, y + 13, layout.ZMax - 12 - index * 20), Color = "#2E1F27", Material = Enum.Material.Slate, Parent = parent })
		end
		C.part({ Name = "Throne", Size = Vector3.new(8, 12, 4), CFrame = CFrame.new(0, y + 6, layout.ZMin + 4), Color = "#6A040F", Parent = parent })
	end,
	SpiritRealm = function(parent, layout, zone)
		local y = floorY(layout)
		C.part({ Name = "RiverOfStars", Size = Vector3.new(12, 0.3, layout.ZMax - layout.ZMin), CFrame = CFrame.new(-28, y + 0.1, (layout.ZMin + layout.ZMax) / 2), Color = "#7FDBFF", Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, Parent = parent })
		for index = 1, 10 do
			C.part({ Name = "FloatingLantern", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2.4, 2), CFrame = CFrame.new(-45 + (index * 37) % 90, y + 10 + (index % 3) * 4, layout.ZMax - index * 10), Color = "#FFD6A5", Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		end
		for index = 0, 2 do
			C.part({ Name = "GhostHouse", Size = Vector3.new(10, 9, 10), CFrame = CFrame.new(40, y + 4.5, layout.ZMax - 20 - index * 30), Color = "#3C096C", Transparency = 0.2, Parent = parent })
		end
	end,
}

local function buildNest(parent, zone, layout)
	local y = floorY(layout)
	local nx, nz = layout.Nest[1], layout.Nest[2]
	local radius = layout.Radius or 10
	local nest = C.part({
		Name = "Nest",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2 + 7, radius * 2 + 7),
		CFrame = CFrame.new(nx, y + 0.2, nz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = zone.Theme.Accent,
		Material = Enum.Material.Grass,
		Tags = { "Nest" },
		Attributes = { ZoneId = zone.Id, Radius = radius },
		Parent = parent,
	})
	C.part({
		Name = "NestRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.45, radius * 2 + 7.6, radius * 2 + 7.6),
		CFrame = nest.CFrame * CFrame.new(-0.02, 0, 0),
		Color = zone.Theme.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local pedestals = C.folder("Pedestals", parent)
	for index = 1, 8 do
		local angle = math.rad((index - 1) * 45)
		local position = Vector3.new(nx + math.sin(angle) * radius, y + 1.0, nz + math.cos(angle) * radius)
		C.part({
			Name = string.format("Pedestal%d", index),
			Size = Vector3.new(3.2, 1.6, 3.2),
			CFrame = CFrame.lookAt(position, Vector3.new(nx, position.Y, nz)),
			Color = "#F4F1EA",
			Material = Enum.Material.Marble,
			Tags = { "EggPedestal" },
			Attributes = { ZoneId = zone.Id, PedestalIndex = index },
			Parent = pedestals,
		})
	end
	local spawns = C.folder("GuardianSpawns", parent)
	for index = 1, zone.Guardian.Count do
		local offset = if zone.Guardian.Count == 1 then 0 else (if index == 1 then -5 else 5)
		C.part({
			Name = "GuardianSpawn" .. index,
			Size = Vector3.new(2, 1, 2),
			CFrame = CFrame.new(nx + offset, y + 0.5, nz),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Tags = { "GuardianSpawn" },
			Attributes = { ZoneId = zone.Id, Index = index },
			Parent = spawns,
		})
	end
end

local function buildWaypoints(parent, zone, layout)
	local y = floorY(layout)
	local points = layout.Waypoints
	if not points then
		local near, far = layout.ZMin + 16, layout.ZMax - 20
		points = { { -36, far }, { 36, far }, { 36, near }, { -36, near } }
	end
	local folder = C.folder("Waypoints", parent)
	for order, point in points do
		C.part({
			Name = "Waypoint" .. order,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(point[1], y + 0.5, point[2]),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Tags = { "GuardianWaypoint" },
			Attributes = { ZoneId = zone.Id, Order = order },
			Parent = folder,
		})
	end
end

local function buildBounds(parent, zone, layout)
	local y = floorY(layout)
	local length = layout.ZMax - layout.ZMin
	C.part({
		Name = "ZoneBounds",
		Size = Vector3.new(Zones.CorridorHalfWidth * 2 + 10, 70, length),
		CFrame = CFrame.new(0, y + 35, (layout.ZMin + layout.ZMax) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Tags = { "Zone" },
		Attributes = { ZoneId = zone.Id },
		Parent = parent,
	})
end

local function buildShell(parent, zone, layout)
	local y = floorY(layout)
	local length = layout.ZMax - layout.ZMin
	local centerZ = (layout.ZMin + layout.ZMax) / 2
	C.part({ Name = "Floor", Size = Vector3.new(Zones.CorridorHalfWidth * 2, 0.4, length), CFrame = CFrame.new(0, y - 0.2, centerZ), Color = zone.Theme.Floor, Material = Enum.Material.SmoothPlastic, Parent = parent })
	for _, side in { -1, 1 } do
		C.part({ Name = "Wall", Size = Vector3.new(2, 30, length), CFrame = CFrame.new(side * Zones.WallX, y + 15, centerZ), Color = zone.Theme.Wall, Parent = parent })
		C.part({ Name = "WallTrim", Size = Vector3.new(2.4, 0.8, length), CFrame = CFrame.new(side * Zones.WallX, y + 30.4, centerZ), Color = zone.Theme.Accent, Material = Enum.Material.Neon, Parent = parent })
	end
	-- cover objects for breaking line of sight
	local cover = C.folder("Cover", parent)
	local specs = {
		{ -24, layout.ZMax - 30, 8, 7, 3 },
		{ 22, layout.ZMax - 45, 3, 7, 8 },
		{ -30, layout.ZMin + 48, 3, 7, 10 },
		{ 30, layout.ZMin + 55, 9, 7, 3 },
		{ 0, layout.ZMax - 62, 10, 5, 3 },
	}
	for index, spec in specs do
		C.part({ Name = "Cover" .. index, Size = Vector3.new(spec[3], spec[4], spec[5]), CFrame = CFrame.new(spec[1], y + spec[4] / 2, spec[2]), Color = zone.Theme.Wall, Parent = cover })
	end
end

function Zones.BuildZone(mapZones, zone, layout)
	local folder = C.folder(string.format("Zone%02d_%s", zone.Id, zone.Key), mapZones)
	local gameplay = C.folder("Gameplay", folder)
	if not layout.Nest then
		layout.Nest = { 0, layout.ZMin + 26 }
	end
	buildBounds(gameplay, zone, layout)
	buildNest(gameplay, zone, layout)
	buildWaypoints(gameplay, zone, layout)
	if layout.Existing then
		local cover = C.folder("Cover", folder)
		for _, spec in layout.Cover or {} do
			coverPiece(cover, spec, floorY(layout))
		end
		zoneSign(folder, zone, layout, false)
	elseif zone.Id ~= 11 then
		local shell = C.folder("Placeholder", folder)
		buildShell(shell, zone, layout)
		torii(shell, zone, layout, zone.Theme.Accent)
		zoneSign(shell, zone, layout, true)
		local decorate = DECOR[zone.Key]
		if decorate then
			decorate(shell, layout, zone)
		end
	end
	return folder
end

-- Connector floors between zones that have gaps, plus invisible outer walls
function Zones.BuildBoundaries(map, lastZone)
	local folder = C.folder("Boundaries", map)
	local minZ = if lastZone >= 11 then Zones.Layouts[11].ZMin - 5 else Zones.Layouts[lastZone].ZMin - 20
	local maxZ = 673
	local length = maxZ - minZ
	for _, side in { -1, 1 } do
		C.part({
			Name = "OuterWall",
			Size = Vector3.new(4, 160, length),
			CFrame = CFrame.new(side * 72, 60, (maxZ + minZ) / 2),
			Transparency = 1,
			CanQuery = false,
			Parent = folder,
		})
	end
	C.part({
		Name = "EndWall",
		Size = Vector3.new(150, 160, 4),
		CFrame = CFrame.new(0, 60, minZ - 2),
		Transparency = 1,
		CanQuery = false,
		Parent = folder,
	})
end

return Zones
