--!nocheck
-- Station Plaza: the hub between the bases and zone 1. Kiosks for the Trail Shop, Item
-- Shop, Fusion Pod, Sell Counter, Codes Board, the event stage (Festival Egg pedestals)
-- and three global leaderboards on the back wall.

local C = require("./Common")
local Vector3, CFrame, Enum = C.Vector3, C.CFrame, C.Enum

local Plaza = {}

local function kiosk(parent, name, tag, position, facing, color, title, subtitle)
	local model = C.model(name, parent)
	local look = CFrame.lookAt(position, position + facing)
	local counter = C.part({
		Name = "Counter",
		Size = Vector3.new(10, 3.5, 4),
		CFrame = look * CFrame.new(0, 1.75, 0),
		Color = "#F4F1EA",
		Tags = { tag },
		Parent = model,
	})
	C.part({ Name = "CounterTrim", Size = Vector3.new(10.2, 0.4, 4.2), CFrame = look * CFrame.new(0, 3.6, 0), Color = color, Material = Enum.Material.Neon, Parent = model })
	for _, x in { -4.6, 4.6 } do
		C.part({ Name = "Post", Size = Vector3.new(0.6, 9, 0.6), CFrame = look * CFrame.new(x, 4.5, 2.4), Color = "#6F4E37", Parent = model })
	end
	C.part({ Name = "Roof", Size = Vector3.new(12, 0.8, 7), CFrame = look * CFrame.new(0, 9.2, 0.8), Color = color, Parent = model })
	local sign = C.part({ Name = "Sign", Size = Vector3.new(10, 2.6, 0.4), CFrame = look * CFrame.new(0, 7.2, -0.6), Color = "#1B1B1E", Parent = model })
	C.label(sign, title, { Color = color, Subtext = subtitle })
	return model, counter
end

function Plaza.Build(map)
	local plaza = C.folder("Plaza", map)
	local south = Vector3.new(0, 0, -1)
	local north = Vector3.new(0, 0, 1)
	kiosk(plaza, "TrailShop", "TrailShop", Vector3.new(-40, 0, 690), north, "#FFB7C5", "TRAIL SHOP", "Speed boosting trails")
	kiosk(plaza, "ItemShop", "ItemShop", Vector3.new(40, 0, 690), north, "#FFD166", "ITEM SHOP", "Ofuda traps & smoke bombs")
	kiosk(plaza, "FusionPod", "FusionPod", Vector3.new(-40, 0, 792), south, "#C77DFF", "FUSION POD", "3 of a kind = Awakened!")
	kiosk(plaza, "SellCounter", "SellCounter", Vector3.new(40, 0, 792), south, "#4CD964", "SELL COUNTER", "30x income per chibi")

	-- Fusion pod capsule
	C.part({
		Name = "PodCapsule",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		CFrame = CFrame.new(-40, 3.5, 799),
		Color = "#E0AAFF",
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		CanCollide = false,
		Parent = plaza,
	})

	-- Codes board
	local codes = C.model("CodesBoard", plaza)
	local boardPos = Vector3.new(-18, 0, 802)
	local look = CFrame.lookAt(boardPos, boardPos + south)
	for _, x in { -4, 4 } do
		C.part({ Name = "Post", Size = Vector3.new(0.6, 8, 0.6), CFrame = look * CFrame.new(x, 4, 0), Color = "#6F4E37", Parent = codes })
	end
	local board = C.part({
		Name = "Board",
		Size = Vector3.new(9, 5, 0.5),
		CFrame = look * CFrame.new(0, 6, 0),
		Color = "#2B2D42",
		Tags = { "CodesBoard" },
		Parent = codes,
	})
	C.label(board, "CODES", { Color = "#80ED99", Subtext = "Redeem codes here" })

	-- Event stage with Festival Egg pedestals
	local stage = C.model("EventStage", plaza)
	local stagePos = Vector3.new(16, 0, 800)
	local platform = C.part({
		Name = "Platform",
		Size = Vector3.new(18, 1.5, 12),
		CFrame = CFrame.new(stagePos + Vector3.new(0, 0.75, 0)),
		Color = "#6A040F",
		Material = Enum.Material.WoodPlanks,
		Tags = { "EventStage" },
		Parent = stage,
	})
	local backdrop = C.part({ Name = "Backdrop", Size = Vector3.new(18, 10, 0.6), CFrame = CFrame.new(stagePos + Vector3.new(0, 6.5, 5.7)), Color = "#1B1B1E", Parent = stage })
	C.label(backdrop, "MATSURI STAGE", { Color = "#FF9F1C", Face = "Front", Subtext = "Festival Eggs appear during Matsuri Nights" })
	for index = 1, 4 do
		C.part({
			Name = "FestivalPedestal" .. index,
			Size = Vector3.new(2.6, 1.2, 2.6),
			CFrame = CFrame.new(stagePos + Vector3.new(-6.75 + (index - 1) * 4.5, 2.1, -1.5)),
			Color = "#FFD166",
			Material = Enum.Material.Marble,
			Tags = { "FestivalPedestal" },
			Attributes = { PedestalIndex = index },
			Parent = stage,
		})
	end
	for index = 0, 4 do
		C.part({
			Name = "Lantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.8, 1.4),
			CFrame = CFrame.new(stagePos + Vector3.new(-8 + index * 4, 11.8, 5)),
			Color = "#FF9F1C",
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = stage,
		})
	end
	platform:SetAttribute("Stage", true)

	-- Leaderboards on the back wall, facing the plaza
	local boards = C.folder("Leaderboards", plaza)
	for index, spec in { { "TotalEarned", -95, "TOP EARNERS" }, { "Rebirths", 0, "MOST REBIRTHS" }, { "HighestIncome", 95, "HIGHEST $/s" } } do
		local position = Vector3.new(spec[2], 44, 921.4)
		C.part({
			Name = "Leaderboard_" .. spec[1],
			Size = Vector3.new(30, 26, 1),
			CFrame = CFrame.lookAt(position, position + south),
			Color = "#1B1B1E",
			Tags = { "Leaderboard" },
			Attributes = { Board = spec[1], Title = spec[3], Order = index },
			Parent = boards,
		})
	end
	return plaza
end

return Plaza
