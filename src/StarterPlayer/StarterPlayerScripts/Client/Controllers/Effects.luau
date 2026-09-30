--!strict
-- Client-only juice: pen idle animations + catchphrase bubbles, egg wobble before hatching,
-- rainbow/orbit mutation FX, "CAUGHT!" manga text, knockback ragdoll, floating cash text,
-- low-graphics mode and hiding other players' trails.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local NumberFormat = require(Shared.Util.NumberFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local Effects = {}

local lowGraphics = false
local hideTrails = false

type Animated = { Model: Model, Base: CFrame, Phase: number, NextTalk: number, EmoteUntil: number }
local penModels: { [Model]: Animated } = {}

local function setAuras(enabled: boolean)
	for _, emitter in CollectionService:GetTagged("AuraFX") do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = enabled
		end
	end
end

local function applyTrailVisibility()
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			for _, descendant in other.Character:GetDescendants() do
				if descendant:IsA("Trail") or (descendant:IsA("ParticleEmitter") and descendant.Name == "TrailParticles") then
					(descendant :: any).Enabled = not hideTrails
				end
			end
		end
	end
end

local function speechBubble(model: Model, text: string)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 3.5, 0)
	gui.MaxDistance = 45
	gui.Adornee = root
	gui.LightInfluence = 0
	local bubble = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Paper,
		Corner = UDim.new(0, 18),
		Stroke = { Thickness = 3, Border = true },
		Parent = gui,
	})
	UI.Text({
		Text = text,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		TextColor3 = Theme.Colors.Ink,
		Stroke = { Thickness = 0, Transparency = 1 },
		TextWrapped = true,
		TextMax = 18,
		Parent = bubble,
	})
	gui.Parent = root
	task.delay(4, function()
		gui:Destroy()
	end)
end

local function trackPenModel(model: Instance)
	if not model:IsA("Model") or penModels[model] then
		return
	end
	penModels[model] = {
		Model = model,
		Base = model:GetPivot(),
		Phase = math.random() * math.pi * 2,
		NextTalk = os.clock() + 5 + math.random() * 25,
		EmoteUntil = 0,
	}
end

local function animate(now: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for model, entry in penModels do
		if model.Parent == nil then
			penModels[model] = nil
			continue
		end
		local base = entry.Base
		if (base.Position - cameraPosition).Magnitude > 120 then
			continue
		end
		local t = now + entry.Phase
		local kind = model:GetAttribute("Kind")
		local offset = CFrame.identity
		if kind == "Egg" then
			local hatchAt = model:GetAttribute("HatchEndsAt")
			local left = if type(hatchAt) == "number" then hatchAt - workspace:GetServerTimeNow() else 999
			local intensity = if left < 10 then 12 elseif left < 30 then 7 elseif left < 120 then 3 else 1
			local speed = if left < 10 then 18 elseif left < 30 then 10 else 4
			offset = CFrame.Angles(0, 0, math.rad(math.sin(t * speed) * intensity))
		else
			local idle = model:GetAttribute("Idle")
			if idle == "Bob" or idle == "Tap" then
				offset = CFrame.new(0, math.abs(math.sin(t * (if idle == "Tap" then 5 else 2.5))) * 0.25, 0)
			elseif idle == "Sway" then
				offset = CFrame.Angles(0, 0, math.rad(math.sin(t * 2) * 6))
			elseif idle == "Bounce" then
				offset = CFrame.new(0, math.abs(math.sin(t * 3.5)) * 0.6, 0)
			elseif idle == "Float" then
				offset = CFrame.new(0, 0.4 + math.sin(t * 1.5) * 0.4, 0)
			elseif idle == "Sleepy" then
				offset = CFrame.Angles(math.rad(math.sin(t * 0.8) * 5), 0, math.rad(8))
			elseif idle == "Hover" then
				offset = CFrame.new(0, 0.3 + math.sin(t * 2) * 0.3, 0) * CFrame.Angles(0, math.rad(math.sin(t * 0.7) * 15), 0)
			end
			if now < entry.EmoteUntil then
				local emote = model:GetAttribute("Emote")
				local progress = 1 - (entry.EmoteUntil - now) / 1.2
				if emote == "Spin" or emote == "Twirl" then
					offset *= CFrame.Angles(0, progress * math.pi * 2, 0)
				elseif emote == "Jump" or emote == "Flip" then
					offset *= CFrame.new(0, math.sin(progress * math.pi) * 2.5, 0)
					if emote == "Flip" then
						offset *= CFrame.Angles(progress * math.pi * 2, 0, 0)
					end
				else
					offset *= CFrame.Angles(0, 0, math.rad(math.sin(progress * math.pi * 6) * 10))
				end
			end
			if now >= entry.NextTalk then
				entry.NextTalk = now + 18 + math.random() * 8
				local characterId = model:GetAttribute("CharacterId")
				local character = if type(characterId) == "string" then Characters.Find(characterId) else nil
				if character and #character.Catchphrases > 0 and (base.Position - cameraPosition).Magnitude < 45 then
					speechBubble(model, character.Catchphrases[math.random(1, #character.Catchphrases)])
					entry.EmoteUntil = now + 1.2
				end
			end
		end
		model:PivotTo(base * offset)
	end
end

local function spinOrbits(now: number)
	for _, model in CollectionService:GetTagged("OrbitFX") do
		if model:IsA("Model") and model.PrimaryPart then
			local pivot = model:GetPivot()
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") and (string.find(part.Name, "OrbitStar") or string.find(part.Name, "Petal")) then
					local original = part:GetAttribute("OrbitOffset")
					if typeof(original) ~= "CFrame" then
						original = pivot:ToObjectSpace(part.CFrame)
						part:SetAttribute("OrbitOffset", original)
					end
					part.CFrame = pivot * CFrame.Angles(0, now * 1.5, 0) * (original :: CFrame)
				end
			end
		end
	end
	for _, highlight in CollectionService:GetTagged("RainbowFX") do
		if highlight:IsA("Highlight") then
			highlight.OutlineColor = Color3.fromHSV((now * 0.3) % 1, 0.8, 1)
		end
	end
end

local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 70)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.LightInfluence = 0
	local label = UI.Text({ Text = text, Font = Theme.Fonts.Heading, TextColor3 = color, Size = UDim2.fromScale(1, 1), TextMax = 48, Stroke = { Thickness = 4 }, Parent = gui })
	gui.Parent = anchor
	UI.Tween(anchor, 1.4, { CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) })
	task.delay(0.9, function()
		UI.Tween(label, 0.5, { TextTransparency = 1 })
	end)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

function Effects.FloatingText(position: Vector3, text: string, color: Color3?)
	floatingText(position, text, color or Theme.Colors.Gold)
end

local function knockback(direction: Vector3, force: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = direction.Unit * force + Vector3.new(0, force * 0.6, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	task.delay(duration, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- Short particle burst at a world position (splash, smoke, bats, trap sparks...)
local BURSTS: { [string]: { Color: string, Count: number, Size: number, Speed: number, Lifetime: number, Texture: string } } = {
	Splash = { Color = "#FFE8B6", Count = 30, Size = 1.2, Speed = 12, Lifetime = 0.8, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	Smoke = { Color = "#CED4DA", Count = 60, Size = 6, Speed = 6, Lifetime = 2.2, Texture = "rbxasset://textures/particles/smoke_main.dds" },
	Bats = { Color = "#1B1B1E", Count = 40, Size = 1.4, Speed = 14, Lifetime = 1.2, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	TrapSprung = { Color = "#FF4D4D", Count = 40, Size = 1.2, Speed = 10, Lifetime = 0.9, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	Blink = { Color = "#9D4EDD", Count = 30, Size = 1.5, Speed = 8, Lifetime = 0.6, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	Burst = { Color = "#FFFFFF", Count = 20, Size = 1, Speed = 10, Lifetime = 0.5, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	Drop = { Color = "#FFD34D", Count = 20, Size = 0.8, Speed = 8, Lifetime = 0.6, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
	Hit = { Color = "#FFD86B", Count = 30, Size = 1.4, Speed = 14, Lifetime = 0.6, Texture = "rbxasset://textures/particles/sparkles_main.dds" },
}

function Effects.Burst(kind: string, position: Vector3)
	local spec = BURSTS[kind]
	if not spec or lowGraphics then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = spec.Texture
	particles.Color = ColorSequence.new(Color3.fromHex(spec.Color))
	particles.Size = NumberSequence.new(spec.Size, spec.Size * 0.3)
	particles.Transparency = NumberSequence.new(0.1, 1)
	particles.Speed = NumberRange.new(spec.Speed * 0.5, spec.Speed)
	particles.Lifetime = NumberRange.new(spec.Lifetime * 0.6, spec.Lifetime)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rate = 0
	particles.Parent = anchor
	anchor.Parent = workspace
	particles:Emit(spec.Count)
	task.delay(spec.Lifetime + 0.5, function()
		anchor:Destroy()
	end)
end

function Effects.Init() end

function Effects.Start()
	State.OnChange("Settings", function(settings)
		if type(settings) ~= "table" then
			return
		end
		lowGraphics = settings.LowGraphics == true
		hideTrails = settings.HideTrails == true
		setAuras(not lowGraphics)
		applyTrailVisibility()
	end)
	CollectionService:GetInstanceAddedSignal("AuraFX"):Connect(function(emitter)
		if lowGraphics and emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false
		end
	end)
	for _, model in CollectionService:GetTagged("PenModel") do
		trackPenModel(model)
	end
	CollectionService:GetInstanceAddedSignal("PenModel"):Connect(function(model)
		task.defer(trackPenModel, model)
	end)
	Players.PlayerAdded:Connect(function(other)
		other.CharacterAdded:Connect(function()
			task.wait(1)
			applyTrailVisibility()
		end)
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		accumulator = 0
		if lowGraphics then
			return
		end
		local now = os.clock()
		animate(now)
		spinOrbits(now)
	end)

	Net.Event("Knockback").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and typeof(payload.Direction) == "Vector3" then
			knockback(payload.Direction, payload.Force or 60, payload.Duration or 1.5)
		end
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(effect)
		if type(effect) ~= "table" then
			return
		end
		if effect.Type == "Collect" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				floatingText(root.Position + Vector3.new(0, 4, 0), "+" .. NumberFormat.Cash(effect.Amount or 0), Theme.Colors.Green)
			end
		elseif effect.Type == "Caught" then
			local target = Players:GetPlayerByUserId(effect.UserId or 0)
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				floatingText(root.Position + Vector3.new(0, 5, 0), "CAUGHT!", Theme.Colors.Red)
				if target == player then
					Sound.Play("Caught")
				end
			end
		elseif effect.Type == "Alert" then
			Sound.Play("Alert")
		elseif effect.Type == "Whistle" then
			Sound.Play("Whistle")
		elseif typeof(effect.Position) == "Vector3" and BURSTS[effect.Type] then
			Effects.Burst(effect.Type, effect.Position)
			if effect.Type == "TrapSprung" or effect.Type == "Hit" then
				Sound.Play("Slap", 0.7)
			end
		end
	end)
end

return Effects
