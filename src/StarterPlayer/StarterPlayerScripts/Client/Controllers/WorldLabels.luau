--!strict
-- Renders text for parts tagged "WorldLabel" (kiosk signs, zone gates, plot buttons).
-- Attributes: LabelText, LabelSubtext, LabelColor, LabelFace, LabelBillboard.
-- Zone gate subtext turns green once your Speed reaches the recommendation.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local NumberFormat = require(ReplicatedStorage.Shared.Util.NumberFormat)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)

local WorldLabels = {}

local gateLabels: { [TextLabel]: number } = {}

local function colorOf(part: Instance): Color3
	local hex = part:GetAttribute("LabelColor")
	local ok, color = pcall(Color3.fromHex, if type(hex) == "string" then hex else "#FFFFFF")
	return if ok then color else Theme.Colors.White
end

local function build(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("WorldLabelGui") then
		return
	end
	local text = part:GetAttribute("LabelText")
	if type(text) ~= "string" then
		return
	end
	local subtext = part:GetAttribute("LabelSubtext")
	local gui: LayerCollector
	if part:GetAttribute("LabelBillboard") then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromScale(10, if subtext then 3 else 2)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 2.2, 0)
		billboard.MaxDistance = 90
		billboard.LightInfluence = 0
		gui = billboard
	else
		local surface = Instance.new("SurfaceGui")
		local face = part:GetAttribute("LabelFace")
		surface.Face = (Enum.NormalId :: any)[if type(face) == "string" then face else "Front"]
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 30
		surface.LightInfluence = 0
		surface.MaxDistance = 250
		gui = surface
	end
	gui.Name = "WorldLabelGui"
	local color = colorOf(part)
	UI.Text({
		Text = text,
		Font = Theme.Fonts.Heading,
		TextColor3 = color,
		Size = UDim2.fromScale(1, if subtext then 0.62 else 1),
		TextMax = 200,
		Stroke = { Thickness = 3 },
		Parent = gui,
	})
	if type(subtext) == "string" then
		local sub = UI.Text({
			Name = "Subtext",
			Text = subtext,
			Size = UDim2.fromScale(1, 0.34),
			Position = UDim2.fromScale(0, 0.64),
			TextMax = 120,
			Parent = gui,
		})
		if CollectionService:HasTag(part, "ZoneGate") then
			local zoneId = part:GetAttribute("ZoneId")
			if type(zoneId) == "number" then
				gateLabels[sub] = zoneId
			end
		end
	end
	gui.Parent = part
end

local function refreshGates(speed: number)
	for label, zoneId in gateLabels do
		if label.Parent == nil then
			gateLabels[label] = nil
			continue
		end
		local zone = Zones.ById[zoneId]
		if zone then
			local ready = speed >= zone.RecSpeed
			label.Text = string.format("Recommended Speed: %s%s", NumberFormat.Short(zone.RecSpeed), if zone.HardGate then " + Gatekeeper" else "")
			label.TextColor3 = if ready then Theme.Colors.Green else Theme.Colors.Red
		end
	end
end

function WorldLabels.Init() end

function WorldLabels.Start()
	for _, part in CollectionService:GetTagged("WorldLabel") do
		build(part)
	end
	CollectionService:GetInstanceAddedSignal("WorldLabel"):Connect(function(part)
		build(part)
		refreshGates(State.Get("Speed") or 0)
	end)
	State.OnChange("Speed", function(speed)
		refreshGates(speed or 0)
	end)
	local _ = Players.LocalPlayer
end

return WorldLabels
