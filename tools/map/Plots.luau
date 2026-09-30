--!nocheck
-- Adds gameplay fixtures to the five existing bases (Base1..Base5): pen slots, treadmill,
-- cash register, collect plate, barrier button + field, owner sign, spawn point and a
-- visible floor outline. Everything is placed in a frame where -Z points at the base's
-- entrance (the side of the fence with the gap).

local C = require("./Common")
local Vector3, CFrame, Enum = C.Vector3, C.CFrame, C.Enum

local Plots = {}

local PLOT_COLORS = { "#FF8FAB", "#8ECAE6", "#FFD166", "#80ED99", "#C77DFF" }
local COLUMNS, ROWS = 8, 5

local function fenceCenters(base)
	local centers = {}
	for _, d in base:GetDescendants() do
		if d:IsA("Model") and d.Name == "Fence" then
			table.insert(centers, C.center(d))
		end
	end
	return centers
end

-- Direction (unit Vector3 in XZ) from the floor center toward the fence gap
local function entranceDirection(base, floor)
	local center = floor.CFrame.Position
	local counts = { ["+X"] = 0, ["-X"] = 0, ["+Z"] = 0, ["-Z"] = 0 }
	for _, p in fenceCenters(base) do
		local dx, dz = p.X - center.X, p.Z - center.Z
		if math.abs(dx) > math.abs(dz) then
			counts[if dx > 0 then "+X" else "-X"] += 1
		else
			counts[if dz > 0 then "+Z" else "-Z"] += 1
		end
	end
	local best, bestCount = "-Z", math.huge
	for side, count in counts do
		if count < bestCount then
			best, bestCount = side, count
		end
	end
	local dirs = {
		["+X"] = Vector3.new(1, 0, 0),
		["-X"] = Vector3.new(-1, 0, 0),
		["+Z"] = Vector3.new(0, 0, 1),
		["-Z"] = Vector3.new(0, 0, -1),
	}
	return dirs[best], best
end

local function build(base, plotId)
	local floor = base:FindFirstChild("Part") or base:FindFirstChild("Floor")
	assert(floor and floor:IsA("BasePart"), base.Name .. " has no floor part")
	floor.Name = "Floor"
	floor:AddTag("PlotFloor")
	base:AddTag("Plot")
	base:SetAttribute("PlotId", plotId)
	base.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local color = PLOT_COLORS[plotId] or "#FFFFFF"
	local dir, side = entranceDirection(base, floor)
	local top = floor.CFrame.Position + Vector3.new(0, floor.Size.Y / 2, 0)
	local frame = CFrame.lookAt(top, top + dir)
	base:SetAttribute("EntranceSide", side)

	local old = base:FindFirstChild("Fixtures")
	if old then
		old:Destroy()
	end
	local fixtures = C.folder("Fixtures", base)
	local function at(x, y, z)
		return frame * CFrame.new(x, y, z)
	end

	-- Pen slots: row 1 is closest to the entrance
	local slots = C.folder("PenSlots", fixtures)
	for row = 1, ROWS do
		for column = 1, COLUMNS do
			local index = (row - 1) * COLUMNS + column
			local slot = C.part({
				Name = string.format("Slot%02d", index),
				Size = Vector3.new(6, 1, 6),
				CFrame = at(-31.5 + (column - 1) * 9, 0.5, -4 + (row - 1) * 10),
				Color = "#F4F1EA",
				Material = Enum.Material.SmoothPlastic,
				Tags = { "PenSlot" },
				Attributes = { SlotIndex = index, PlotId = plotId },
				Parent = slots,
			})
			C.part({
				Name = "Rim",
				Size = Vector3.new(6.4, 0.3, 6.4),
				CFrame = slot.CFrame * CFrame.new(0, -0.4, 0),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = slot,
			})
		end
	end

	-- Treadmill
	local treadmill = C.model("Treadmill", fixtures)
	treadmill:AddTag("Treadmill")
	treadmill:SetAttribute("PlotId", plotId)
	C.part({ Name = "Frame", Size = Vector3.new(7, 0.6, 15), CFrame = at(-29, 0.3, -24), Color = "#F1F1F1", Parent = treadmill })
	C.part({ Name = "Belt", Size = Vector3.new(5.4, 0.3, 13.4), CFrame = at(-29, 0.75, -24), Color = "#3A3A3A", Material = Enum.Material.Fabric, Parent = treadmill })
	C.part({ Name = "Rail", Size = Vector3.new(0.4, 3, 0.4), CFrame = at(-31.6, 2.1, -30.4), Color = "#F1F1F1", Parent = treadmill })
	C.part({ Name = "Rail", Size = Vector3.new(0.4, 3, 0.4), CFrame = at(-26.4, 2.1, -30.4), Color = "#F1F1F1", Parent = treadmill })
	local console = C.part({ Name = "Console", Size = Vector3.new(5.6, 1.2, 0.8), CFrame = at(-29, 3.8, -30.6), Color = "#FF8FAB", Parent = treadmill })
	C.label(console, "TREADMILL", { Color = "#FFFFFF", Face = "Back" })
	C.part({ Name = "Accent", Size = Vector3.new(0.3, 0.2, 13.4), CFrame = at(-31.9, 0.7, -24), Color = "#FF8FAB", Material = Enum.Material.Neon, CanCollide = false, Parent = treadmill })
	C.part({ Name = "Accent", Size = Vector3.new(0.3, 0.2, 13.4), CFrame = at(-26.1, 0.7, -24), Color = "#FF8FAB", Material = Enum.Material.Neon, CanCollide = false, Parent = treadmill })

	-- Cash register + collect plate
	local register = C.part({ Name = "CashRegister", Size = Vector3.new(4, 3, 3), CFrame = at(28, 1.5, -33), Color = "#FFD166", Tags = { "CashRegister" }, Parent = fixtures })
	C.part({ Name = "RegisterTop", Size = Vector3.new(3, 1.2, 2), CFrame = register.CFrame * CFrame.new(0, 2.1, 0.3), Color = "#2B2D42", Parent = register })
	local plate = C.part({
		Name = "CollectPlate",
		Size = Vector3.new(7, 0.4, 7),
		CFrame = at(28, 0.2, -24),
		Color = "#4CD964",
		Material = Enum.Material.Neon,
		Tags = { "CollectPlate" },
		Parent = fixtures,
	})
	C.label(plate, "COLLECT", { Color = "#FFFFFF", Face = "Top" })

	-- Barrier Lock button and force field
	C.part({ Name = "BarrierPost", Size = Vector3.new(1.6, 3, 1.6), CFrame = at(37, 1.5, -14), Color = "#2B2D42", Parent = fixtures })
	local button = C.part({
		Name = "BarrierButton",
		Size = Vector3.new(1.4, 0.5, 1.4),
		CFrame = at(37, 3.25, -14),
		Color = "#E63946",
		Material = Enum.Material.Neon,
		Tags = { "BarrierButton" },
		Parent = fixtures,
	})
	C.label(button, "BARRIER LOCK", { Color = "#FF8FAB", Billboard = true })
	C.part({
		Name = "BarrierField",
		Size = Vector3.new(92, 32, 92),
		CFrame = at(0, 16, 0),
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Tags = { "BarrierField" },
		Parent = fixtures,
	})

	-- Owner sign, facing out of the entrance
	C.part({ Name = "SignPost", Size = Vector3.new(0.8, 10, 0.8), CFrame = at(-38.5, 5, -43.5), Color = "#6F4E37", Parent = fixtures })
	C.part({ Name = "SignPost", Size = Vector3.new(0.8, 10, 0.8), CFrame = at(-24.5, 5, -43.5), Color = "#6F4E37", Parent = fixtures })
	C.part({
		Name = "OwnerSign",
		Size = Vector3.new(15, 6, 0.6),
		CFrame = at(-31.5, 11, -43.5),
		Color = "#2B2D42",
		Tags = { "PlotSign" },
		Parent = fixtures,
	})
	C.part({ Name = "SignTrim", Size = Vector3.new(15.6, 0.4, 0.8), CFrame = at(-31.5, 14.1, -43.5), Color = color, Material = Enum.Material.Neon, Parent = fixtures })

	-- Spawn point
	C.part({
		Name = "PlotSpawn",
		Size = Vector3.new(4, 1, 4),
		CFrame = at(0, 0.5, -20),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Tags = { "PlotSpawn" },
		Parent = fixtures,
	})

	-- Visible boundary outline
	local outline = C.folder("Outline", fixtures)
	local half = floor.Size.X / 2 - 0.3
	for _, edge in { { 0, -half, 90, 0.6 }, { 0, half, 90, 0.6 }, { -half, 0, 0.6, 90 }, { half, 0, 0.6, 90 } } do
		C.part({
			Name = "Edge",
			Size = Vector3.new(edge[3], 0.15, edge[4]),
			CFrame = at(edge[1], 0.08, edge[2]),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = outline,
		})
	end
	return frame
end

function Plots.Build(workspace)
	local count = 0
	for plotId = 1, 5 do
		local base = workspace:FindFirstChild("Base" .. plotId)
		if base then
			build(base, plotId)
			count += 1
		else
			print("  ! Base" .. plotId .. " not found")
		end
	end
	return count
end

return Plots
