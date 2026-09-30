--!strict
-- Draws the Heavenly Gatekeeper's hazards locally from the shared deterministic math
-- (shockwave rings, the sweeping staff) plus petal telegraphs sent by the server, shows the
-- hit counter, and opens the golden gate for players who have cleared the gauntlet.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Endgame = require(Shared.Config.Endgame)
local GauntletMath = require(Shared.Util.Gauntlet)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local Gauntlet = {}

type Area = { Part: BasePart, Origin: Vector3, FloorY: number }

local areas: { [number]: Area } = {}
local rings: { { BasePart } } = {}
local staff: BasePart? = nil
local visuals: Folder
local hitsPill: Frame
local hitsLabel: TextLabel

local SEGMENTS = 40
local boss = Endgame.Boss

local function newPart(size: Vector3, color: Color3, transparency: number?): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0
	part.Parent = visuals
	return part
end

local function registerArea(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local phase = part:GetAttribute("Phase")
	if type(phase) ~= "number" then
		return
	end
	areas[phase] = {
		Part = part,
		Origin = Vector3.new(part:GetAttribute("OriginX") :: number, part:GetAttribute("OriginY") :: number, part:GetAttribute("OriginZ") :: number),
		FloorY = part:GetAttribute("FloorY") :: number,
	}
end

local function ring(index: number): { BasePart }
	local existing = rings[index]
	if existing then
		return existing
	end
	local segments = {}
	for _ = 1, SEGMENTS do
		table.insert(segments, newPart(Vector3.new(boss.Shockwave.Thickness, 1.2, 4), Color3.fromHex("#FFD86B"), 0.1))
	end
	rings[index] = segments
	return segments
end

local function near(area: Area?, distance: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return area ~= nil and root ~= nil and (root.Position - area.Part.Position).Magnitude < distance
end

local function render()
	local now = workspace:GetServerTimeNow()
	local area1 = areas[1]
	local radii = if near(area1, 260) then GauntletMath.ShockwaveRadii(now) else {}
	for index = 1, math.max(#radii, #rings) do
		local radius = radii[index]
		local segments = ring(index)
		for segmentIndex, segment in segments do
			if radius and area1 then
				local angle = (segmentIndex / SEGMENTS) * math.pi * 2
				local position = area1.Origin + Vector3.new(math.cos(angle) * radius, 0.7, math.sin(angle) * radius)
				segment.Size = Vector3.new(boss.Shockwave.Thickness, 1.2, math.max(1, radius * math.pi * 2 / SEGMENTS + 0.4))
				segment.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
				segment.Transparency = 0.1 + (radius / boss.Shockwave.MaxRadius) * 0.5
			else
				segment.Transparency = 1
			end
		end
	end
	local area3 = areas[3]
	if area3 and near(area3, 260) then
		if not staff then
			local created = newPart(Vector3.new(boss.Staff.Length, boss.Staff.Height * 0.8, boss.Staff.Thickness), Color3.fromHex("#FFD86B"))
			created.Material = Enum.Material.Metal
			staff = created
		end
		local angle = GauntletMath.StaffAngle(now)
		local s = staff :: BasePart
		s.Transparency = 0
		s.CFrame = CFrame.new(area3.Origin + Vector3.new(0, boss.Staff.Height * 0.45, 0)) * CFrame.Angles(0, -angle, 0)
	elseif staff then
		staff.Transparency = 1
	end
end

local function petals(payload: any)
	if typeof(payload.Positions) ~= "table" then
		return
	end
	local radius = payload.Radius or boss.Petals.Radius
	for _, position in payload.Positions do
		if typeof(position) ~= "Vector3" then
			continue
		end
		local marker = newPart(Vector3.new(0.3, radius * 2, radius * 2), Color3.fromHex("#FF4D6D"), 0.5);
		(marker :: Part).Shape = Enum.PartType.Cylinder
		marker.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local petal = newPart(Vector3.new(radius * 1.4, 0.6, radius), Color3.fromHex("#FFB7C5"))
		petal.CFrame = CFrame.new(position + Vector3.new(0, 40, 0))
		local wait = math.max(0.05, (payload.ImpactAt or 0) - workspace:GetServerTimeNow())
		UI.Tween(petal, wait, { CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.rad(180), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(wait, function()
			marker.Color = Color3.fromHex("#FFD86B")
			marker.Transparency = 0.2
			task.wait(0.3)
			marker:Destroy()
			petal:Destroy()
		end)
	end
end

local function updateGate()
	local cleared = player:GetAttribute("BossCleared") == true
	for _, part in CollectionService:GetTagged("HeavenGate") do
		if part:IsA("BasePart") then
			part.CanCollide = not cleared
			part.Transparency = if cleared then 0.85 else 0.3
		end
	end
end

function Gauntlet.Init()
	visuals = Instance.new("Folder")
	visuals.Name = "GauntletVisuals"
	visuals.Parent = workspace
	local screen = UI.Screen("GauntletHUD", 7)
	hitsPill = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(320, 48),
		BackgroundColor3 = Theme.Colors.Ink,
		Corner = UDim.new(1, 0),
		Stroke = { Color = Theme.Colors.Gold, Thickness = 3, Border = true },
		Visible = false,
		Parent = screen,
	})
	hitsLabel = UI.Text({ Text = "", Font = Theme.Fonts.Heading, TextColor3 = Theme.Colors.Gold, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), TextMax = 28, Parent = hitsPill })
end

function Gauntlet.Start()
	for _, part in CollectionService:GetTagged("GauntletArea") do
		registerArea(part)
	end
	CollectionService:GetInstanceAddedSignal("GauntletArea"):Connect(registerArea)
	CollectionService:GetInstanceAddedSignal("HeavenGate"):Connect(updateGate)
	player:GetAttributeChangedSignal("BossCleared"):Connect(updateGate)
	updateGate()
	local function updateHits()
		local inGauntlet = player:GetAttribute("InGauntlet") == true
		hitsPill.Visible = inGauntlet
		local hits = player:GetAttribute("GauntletHits")
		hitsLabel.Text = string.format("GATEKEEPER HITS  %d / %d", if type(hits) == "number" then hits else 0, boss.MaxHits + 1)
	end
	player:GetAttributeChangedSignal("InGauntlet"):Connect(updateHits)
	player:GetAttributeChangedSignal("GauntletHits"):Connect(updateHits)
	updateHits()
	Net.Event("Effect").OnClientEvent:Connect(function(effect)
		if type(effect) == "table" and effect.Type == "Petals" then
			petals(effect)
		end
	end)
	RunService.RenderStepped:Connect(render)
end

return Gauntlet
