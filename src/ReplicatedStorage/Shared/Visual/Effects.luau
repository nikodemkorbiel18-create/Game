--!strict
-- Shared visual effects for eggs and characters: rarity auras, mutation looks and the
-- Awakened star. Emitters are tagged "AuraFX" so low-graphics mode can switch them off,
-- and Rainbow highlights are tagged "RainbowFX" so clients can cycle their hue.

local CollectionService = game:GetService("CollectionService")

local Rarities = require(script.Parent.Parent.Config.Rarities)
local Mutations = require(script.Parent.Parent.Config.Mutations)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local Effects = {}

local function rootOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function heightOf(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y
end

local function emitter(parent: Instance, color: ColorSequence, rate: number, size: number, speed: number, lifetime: number): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = SPARKLE
	particles.Color = color
	particles.Rate = rate
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.LightEmission = 0.8
	particles.Parent = parent
	CollectionService:AddTag(particles, "AuraFX")
	return particles
end

local function attachmentAt(model: Model, name: string, height: number): Attachment?
	local root = rootOf(model)
	if not root then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = Vector3.new(0, height - root.Position.Y + model:GetPivot().Position.Y, 0)
	attachment.Parent = root
	return attachment
end

local function gradient(rarity: Rarities.Rarity): ColorSequence
	local first = Color3.fromHex(rarity.Color)
	local second = if rarity.Color2 then Color3.fromHex(rarity.Color2) else first
	return ColorSequence.new(first, second)
end

-- Sparkle aura that grows with rarity (Epic and above).
function Effects.AddRarityAura(model: Model, rarity: Rarities.Rarity, scale: number)
	if rarity.AuraSize <= 0 then
		return
	end
	local height = heightOf(model)
	local attachment = attachmentAt(model, "Aura", height * 0.5)
	if not attachment then
		return
	end
	emitter(attachment, gradient(rarity), 3 + rarity.AuraSize * 3, 0.35 * scale * (0.6 + rarity.AuraSize * 0.2), 2 * scale, 1.2)
	if rarity.Rank >= 7 then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(rarity.Color2 or rarity.Color)
		light.Brightness = 1.5
		light.Range = 8 * scale
		light.Parent = attachment
	end
end

function Effects.AddAwakenedStar(model: Model, scale: number)
	local height = heightOf(model)
	local star = Instance.new("Part")
	star.Name = "AwakenedStar"
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * 0.6 * scale
	star.Color = Color3.fromHex("#FFD34D")
	star.Material = Enum.Material.Neon
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.Massless = true
	star.CFrame = model:GetPivot() * CFrame.new(0, height + 0.8 * scale, 0)
	star.Parent = model
	model:SetAttribute("Awakened", true)
end

function Effects.ApplyMutation(model: Model, mutationId: string?, scale: number)
	local mutation = Mutations.Get(mutationId)
	if not mutation then
		return
	end
	model:SetAttribute("Mutation", mutation.Id)
	local color = Color3.fromHex(mutation.Color)
	local height = heightOf(model)
	local attachment = attachmentAt(model, "MutationFX", height * 0.55)

	if mutation.Visual == "Gold" then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 and descendant.Name ~= "AwakenedStar" then
				local name = descendant.Name
				if not (string.find(name, "Eye") or string.find(name, "Glint") or string.find(name, "Pupil")) then
					descendant.Color = descendant.Color:Lerp(color, 0.55)
				end
			end
		end
	elseif mutation.Visual == "Chrome" then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				descendant.Reflectance = math.max(descendant.Reflectance, 0.25)
			end
		end
	end

	if mutation.Visual ~= "Petals" then
		local highlight = Instance.new("Highlight")
		highlight.Name = "MutationOutline"
		highlight.FillTransparency = 1
		highlight.OutlineColor = color
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
		if mutation.Visual == "Rainbow" then
			CollectionService:AddTag(highlight, "RainbowFX")
		end
	end

	if attachment then
		if mutation.Visual == "Petals" then
			emitter(attachment, ColorSequence.new(Color3.fromHex("#FFB7C5"), Color3.fromHex("#FFE5EC")), 8, 0.3 * scale, 1.5 * scale, 2)
		elseif mutation.Visual == "KamiHalo" then
			emitter(attachment, ColorSequence.new(Color3.fromHex("#FFE08A"), Color3.fromHex("#FFB7C5")), 20, 0.4 * scale, 3 * scale, 1.6)
			local halo = Instance.new("Part")
			halo.Name = "KamiHalo"
			halo.Shape = Enum.PartType.Cylinder
			halo.Size = Vector3.new(0.15, 2.2, 2.2) * scale
			halo.Color = color
			halo.Material = Enum.Material.Neon
			halo.Transparency = 0.2
			halo.Anchored = true
			halo.CanCollide = false
			halo.CanQuery = false
			halo.CanTouch = false
			halo.Massless = true
			halo.CFrame = model:GetPivot() * CFrame.new(0, height + 0.5 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
			halo.Parent = model
		elseif mutation.Visual == "Rainbow" then
			emitter(
				attachment,
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4D4D")),
					ColorSequenceKeypoint.new(0.33, Color3.fromHex("#FFE14D")),
					ColorSequenceKeypoint.new(0.66, Color3.fromHex("#4DFF88")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("#4DA6FF")),
				}),
				10,
				0.35 * scale,
				2 * scale,
				1.4
			)
		else
			emitter(attachment, ColorSequence.new(color), 6, 0.3 * scale, 1.5 * scale, 1.2)
		end
	end
end

return Effects
