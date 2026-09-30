--!strict
-- Zone ambience and event weather:
--   * music per zone (Config/Sounds) and a lighting/fog tint per zone palette
--   * Sakura Storm petals, Eclipse Hour red-violet sky, Matsuri fireworks over the plaza

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local Ambience = {}

local defaults = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
}
local currentZone = -1
local colorCorrection: ColorCorrectionEffect
local petals: ParticleEmitter
local petalAnchor: Part
local lowGraphics = false

local function zoneAt(position: Vector3): number
	for _, part in CollectionService:GetTagged("Zone") do
		if part:IsA("BasePart") then
			local localPoint = part.CFrame:PointToObjectSpace(position)
			local half = part.Size / 2
			if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z then
				local id = part:GetAttribute("ZoneId")
				return if type(id) == "number" then id else 0
			end
		end
	end
	return 0
end

local function activeEvents(): { [string]: boolean }
	local raw = ReplicatedStorage:GetAttribute("ActiveEvents")
	local ok, list = pcall(function()
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "[]")
	end)
	local set = {}
	if ok and type(list) == "table" then
		for _, entry in list do
			if type(entry) == "table" and type(entry.Id) == "string" then
				set[entry.Id] = true
			end
		end
	end
	return set
end

local function applyZone(zoneId: number)
	if zoneId == currentZone then
		return
	end
	currentZone = zoneId
	local info = TweenInfo.new(1.5)
	local zone = Zones.ById[zoneId]
	if zone then
		Sound.SetMusic(zone.Theme.Music)
		TweenService:Create(Lighting, info, {
			Ambient = Color3.fromHex(zone.Theme.Ambient):Lerp(Color3.new(0.5, 0.5, 0.5), 0.6),
			OutdoorAmbient = Color3.fromHex(zone.Theme.Ambient):Lerp(Color3.new(0.5, 0.5, 0.5), 0.4),
			FogColor = Color3.fromHex(zone.Theme.FogColor),
			FogEnd = zone.Theme.FogEnd,
		}):Play()
	else
		Sound.SetMusic(if activeEvents().Matsuri then "Matsuri" else "Home")
		TweenService:Create(Lighting, info, defaults):Play()
	end
end

local function firework(center: Vector3)
	if lowGraphics then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(center + Vector3.new(math.random(-60, 60), math.random(50, 80), math.random(-40, 40)))
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromHSV(math.random(), 0.8, 1))
	burst.Size = NumberSequence.new(2.5, 0)
	burst.Speed = NumberRange.new(25, 40)
	burst.Lifetime = NumberRange.new(1, 1.6)
	burst.Drag = 3
	burst.LightEmission = 1
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = anchor
	anchor.Parent = workspace
	burst:Emit(80)
	task.delay(2.5, function()
		anchor:Destroy()
	end)
end

local function updateWeather()
	local events = activeEvents()
	local sakura = events.SakuraStorm == true and not lowGraphics
	petals.Enabled = sakura
	local eclipse = events.EclipseHour == true
	TweenService:Create(colorCorrection, TweenInfo.new(2), {
		TintColor = if eclipse then Color3.fromRGB(220, 150, 230) else Color3.new(1, 1, 1),
		Saturation = if eclipse then 0.15 else 0,
		Contrast = if eclipse then 0.1 else 0,
	}):Play()
end

function Ambience.Init()
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "EventTint"
	colorCorrection.Parent = Lighting
	petalAnchor = Instance.new("Part")
	petalAnchor.Name = "PetalWeather"
	petalAnchor.Anchored = true
	petalAnchor.CanCollide = false
	petalAnchor.CanQuery = false
	petalAnchor.CanTouch = false
	petalAnchor.Transparency = 1
	petalAnchor.Size = Vector3.new(120, 1, 120)
	petalAnchor.Parent = workspace
	petals = Instance.new("ParticleEmitter")
	petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	petals.Color = ColorSequence.new(Color3.fromHex("#FFB7C5"), Color3.fromHex("#FFE5EC"))
	petals.Size = NumberSequence.new(0.6, 0.3)
	petals.Rate = 60
	petals.Lifetime = NumberRange.new(5, 7)
	petals.Speed = NumberRange.new(3, 6)
	petals.Acceleration = Vector3.new(2, -3, 1)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Enabled = false
	petals.Parent = petalAnchor
end

function Ambience.Start()
	State.OnChange("Settings", function(settings)
		if type(settings) == "table" then
			lowGraphics = settings.LowGraphics == true
			updateWeather()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("ActiveEvents"):Connect(updateWeather)
	updateWeather()
	task.spawn(function()
		local fireworkTimer = 0
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				applyZone(zoneAt(root.Position))
				petalAnchor.CFrame = CFrame.new(root.Position + Vector3.new(0, 40, 0))
				fireworkTimer += 0.5
				if fireworkTimer >= 1.5 and activeEvents().Matsuri and currentZone == 0 then
					fireworkTimer = 0
					local stage = CollectionService:GetTagged("EventStage")[1]
					if stage and stage:IsA("BasePart") then
						firework(stage.Position)
					end
				end
			end
		end
	end)
end

return Ambience
