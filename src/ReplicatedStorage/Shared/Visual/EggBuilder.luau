--!strict
-- Builds egg models. Readability rules from the brief:
--   SHAPE / ORNAMENT = rarity, COLOR = cosmetic only (zone palette), theme overlay = zone,
--   mutation visible on the shell, size = physical scale.
-- A model in ReplicatedStorage.Assets.Eggs named after the character's EggModel (e.g.
-- "Egg_Zone3", or "Egg_Bolt" for a per-character egg) replaces the placeholder shell;
-- rarity ornaments and mutation effects are still added. Optional asset conventions:
--   model attribute ShellHeight  height of the shell alone (studs); the pivot sits at the
--                                shell's centre, so ornaments can stick out above it
--   model attribute Ornament     rarity ornament built into the model ("Crown", ...); the
--                                procedural one is skipped when it matches the rarity
--   part attribute Tint          shell part recoloured with the cosmetic colour x factor
--   part attribute OrnamentPart  removed if the built-in ornament doesn't match the rarity
--   part attribute Orbit         spins around the egg (like OrbitStar parts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = script.Parent.Parent
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Zones = require(Shared.Config.Zones)
local Effects = require(script.Parent.Effects)

export type EggSpec = {
	CharacterId: string,
	SizeTier: number,
	Mutation: string?,
	Color: number?,
	EggModel: string?,
	Awakened: boolean?,
}

local SHELL = Vector3.new(2.2, 3.0, 2.2)

local SPECIAL_THEMES: { [string]: { Overlay: string, Palette: { string } } } = {
	Egg_Festival = { Overlay = "Festival", Palette = { "#FF9F1C", "#FFD60A", "#F72585", "#4361EE" } },
	Egg_Gacha = { Overlay = "Capsule", Palette = { "#FF8FAB", "#8ECAE6", "#FFB703", "#80ED99" } },
	Egg_Duet = { Overlay = "GlitterStars", Palette = { "#C77DFF", "#FFD670" } },
	Egg_Rival = { Overlay = "Rival", Palette = { "#FFFFFF", "#7209B7" } },
	Egg_Eclipse = { Overlay = "Eclipse", Palette = { "#1B1B1E", "#FFD60A" } },
}

local EggBuilder = {}

type Ctx = {
	Model: Model,
	Scale: number,
	Size: Vector3, -- scaled shell size
	Base: Color3,
	Center: Vector3,
}

local function part(ctx: Ctx, name: string, shape: string, size: Vector3, offset: Vector3, color: Color3, rotation: Vector3?, material: Enum.Material?, transparency: number?): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if shape == "Ball" then
			basic.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			basic.Shape = Enum.PartType.Cylinder
		end
		p = basic
	end
	if shape == "Sphere" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local s = ctx.Scale
	p.Name = name
	p.Size = Vector3.new(math.max(size.X * s, 0.05), math.max(size.Y * s, 0.05), math.max(size.Z * s, 0.05))
	local rot = rotation or Vector3.zero
	p.CFrame = CFrame.new(ctx.Center + offset * s) * CFrame.fromOrientation(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = ctx.Model
	return p
end

local function band(ctx: Ctx, name: string, y: number, color: Color3, thickness: number, material: Enum.Material?)
	-- a ring hugging the shell at relative height y (-1.5..1.5 at scale 1)
	local t = math.clamp(math.abs(y) / 1.5, 0, 1)
	local diameter = 2.28 * math.sqrt(math.max(0.05, 1 - t * t))
	part(ctx, name, "Cylinder", Vector3.new(thickness, diameter, diameter), Vector3.new(0, y, 0), color, Vector3.new(0, 0, 90), material)
end

local function overlay(ctx: Ctx, kind: string)
	local white = Color3.new(1, 1, 1)
	if kind == "SailorRibbon" then
		band(ctx, "Collar", -0.2, Color3.fromHex("#2E3A59"), 0.45)
		band(ctx, "CollarStripe", -0.45, white, 0.08)
		part(ctx, "BowL", "Wedge", Vector3.new(0.12, 0.45, 0.5), Vector3.new(-0.28, -0.2, -1.12), Color3.fromHex("#E63946"), Vector3.new(0, 90, 0))
		part(ctx, "BowR", "Wedge", Vector3.new(0.12, 0.45, 0.5), Vector3.new(0.28, -0.2, -1.12), Color3.fromHex("#E63946"), Vector3.new(0, -90, 0))
		part(ctx, "BowKnot", "Ball", Vector3.one * 0.22, Vector3.new(0, -0.2, -1.14), Color3.fromHex("#C1121F"))
		part(ctx, "Crest", "Cylinder", Vector3.new(0.06, 0.45, 0.45), Vector3.new(0, 0.55, -1.0), Color3.fromHex("#FFD34D"), Vector3.new(0, 90, 0))
	elseif kind == "NeonCeramic" then
		band(ctx, "NeonBand", 0.1, Color3.fromHex("#3FF2FF"), 0.14, Enum.Material.Neon)
		band(ctx, "NeonBand2", -0.6, Color3.fromHex("#FF4FA0"), 0.1, Enum.Material.Neon)
		part(ctx, "Sign", "Block", Vector3.new(0.7, 0.35, 0.08), Vector3.new(0, 0.55, -1.02), Color3.fromHex("#FF4FA0"), Vector3.new(-12, 0, 0), Enum.Material.Neon)
	elseif kind == "ShimenawaRope" then
		band(ctx, "Rope", -0.1, Color3.fromHex("#E9D8A6"), 0.35)
		for index, x in { -0.45, 0, 0.45 } do
			part(ctx, "Shide" .. index, "Block", Vector3.new(0.22, 0.55, 0.05), Vector3.new(x, -0.55, -1.08), white, Vector3.new(-8, 0, 0))
		end
		part(ctx, "Charm", "Block", Vector3.new(0.4, 0.6, 0.05), Vector3.new(0, 0.5, -1.02), Color3.fromHex("#F2E8CF"), Vector3.new(-15, 0, 0))
	elseif kind == "BeachStripes" then
		band(ctx, "Stripe1", 0.5, Color3.fromHex("#FF6B6B"), 0.3)
		band(ctx, "Stripe2", 0, Color3.fromHex("#FFD166"), 0.3)
		band(ctx, "Stripe3", -0.5, Color3.fromHex("#48CAE4"), 0.3)
		part(ctx, "Shell", "Wedge", Vector3.new(0.5, 0.35, 0.5), Vector3.new(0, 1.55, 0), Color3.fromHex("#FFE5B4"))
	elseif kind == "NinjaCloth" then
		part(ctx, "Wrap", "Cylinder", Vector3.new(0.4, 2.3, 2.3), Vector3.new(0, 0, 0), Color3.fromHex("#2B2B3A"), Vector3.new(0, 0, 60))
		part(ctx, "Knot", "Ball", Vector3.one * 0.55, Vector3.new(0, 1.45, 0.2), Color3.fromHex("#2B2B3A"))
		for index = 0, 3 do
			part(ctx, "StarBlade" .. index, "Wedge", Vector3.new(0.05, 0.3, 0.18), Vector3.new(0, 0.2, -1.12), Color3.fromHex("#ADB5BD"), Vector3.new(0, 90, index * 90), Enum.Material.Metal)
		end
	elseif kind == "GlitterStars" then
		for index, offset in { Vector3.new(0.6, 0.6, -0.8), Vector3.new(-0.7, 0.1, -0.75), Vector3.new(0.2, -0.6, -1.0), Vector3.new(-0.3, 1.0, 0.7), Vector3.new(0.8, -0.2, 0.6) } do
			part(ctx, "Star" .. index, "Ball", Vector3.one * 0.25, offset, Color3.fromHex("#FFF3B0"), nil, Enum.Material.Neon)
		end
	elseif kind == "ArmorCore" then
		band(ctx, "Plate1", 0.45, Color3.fromHex("#ADB5BD"), 0.4, Enum.Material.DiamondPlate)
		band(ctx, "Plate2", -0.45, Color3.fromHex("#ADB5BD"), 0.4, Enum.Material.DiamondPlate)
		part(ctx, "Core", "Ball", Vector3.one * 0.55, Vector3.new(0, 0, -1.02), Color3.fromHex("#4CC9F0"), nil, Enum.Material.Neon)
	elseif kind == "RuneCrystal" then
		band(ctx, "Rune1", 0.3, Color3.fromHex("#80FFDB"), 0.06, Enum.Material.Neon)
		band(ctx, "Rune2", -0.3, Color3.fromHex("#80FFDB"), 0.06, Enum.Material.Neon)
		part(ctx, "Crystal", "Wedge", Vector3.new(0.35, 0.7, 0.35), Vector3.new(0.9, 1.3, 0), Color3.fromHex("#B8F2E6"), nil, Enum.Material.Glass, 0.2)
	elseif kind == "ObsidianWings" then
		part(ctx, "HornL", "Wedge", Vector3.new(0.18, 0.5, 0.3), Vector3.new(-0.4, 1.5, 0), Color3.fromHex("#E9D8A6"))
		part(ctx, "HornR", "Wedge", Vector3.new(0.18, 0.5, 0.3), Vector3.new(0.4, 1.5, 0), Color3.fromHex("#E9D8A6"))
		part(ctx, "BatWingL", "Wedge", Vector3.new(0.08, 0.8, 1.0), Vector3.new(-1.25, 0.3, 0.2), Color3.fromHex("#3C1642"), Vector3.new(0, -70, 0))
		part(ctx, "BatWingR", "Wedge", Vector3.new(0.08, 0.8, 1.0), Vector3.new(1.25, 0.3, 0.2), Color3.fromHex("#3C1642"), Vector3.new(0, 70, 0))
	elseif kind == "Ghostfire" then
		part(ctx, "InnerFire", "Sphere", Vector3.new(1.0, 1.5, 1.0), Vector3.new(0, -0.1, 0), Color3.fromHex("#7FDBFF"), nil, Enum.Material.Neon)
	elseif kind == "HaloPetals" then
		part(ctx, "Halo", "Cylinder", Vector3.new(0.1, 1.6, 1.6), Vector3.new(0, 1.9, 0), Color3.fromHex("#FFD86B"), Vector3.new(0, 0, 90), Enum.Material.Neon)
		for index = 1, 5 do
			local angle = math.rad(index * 72)
			part(ctx, "Petal" .. index, "Sphere", Vector3.new(0.35, 0.06, 0.22), Vector3.new(math.cos(angle) * 1.0, 0.9, math.sin(angle) * 1.0), Color3.fromHex("#FFB7C5"), Vector3.new(15, index * 72, 0))
		end
	elseif kind == "Festival" then
		band(ctx, "Obi", 0, Color3.fromHex("#E63946"), 0.4)
		part(ctx, "Lantern", "Sphere", Vector3.new(0.5, 0.6, 0.5), Vector3.new(0, 0.6, -0.95), Color3.fromHex("#FFD166"), nil, Enum.Material.Neon)
	elseif kind == "Capsule" then
		part(ctx, "CapsuleTop", "Sphere", Vector3.new(2.32, 1.6, 2.32), Vector3.new(0, 0.7, 0), white, nil, Enum.Material.Glass, 0.45)
		band(ctx, "Seam", 0, Color3.fromHex("#2B2B2B"), 0.08)
	elseif kind == "Rival" then
		part(ctx, "HalfDark", "Sphere", Vector3.new(1.15, 3.02, 2.22), Vector3.new(0.56, 0, 0), Color3.fromHex("#7209B7"))
		part(ctx, "Sword", "Block", Vector3.new(0.12, 1.2, 0.06), Vector3.new(-0.4, 0.2, -1.05), Color3.fromHex("#BDE0FE"), nil, Enum.Material.Neon)
	elseif kind == "Eclipse" then
		part(ctx, "Corona", "Cylinder", Vector3.new(0.1, 3.4, 3.4), Vector3.new(0, 0, 0.3), Color3.fromHex("#FFD60A"), Vector3.new(0, 90, 0), Enum.Material.Neon, 0.3)
	end
end

local function ornament(ctx: Ctx, rarity: Rarities.Rarity)
	local color = Color3.fromHex(rarity.Color)
	local color2 = if rarity.Color2 then Color3.fromHex(rarity.Color2) else color
	local kind = rarity.Ornament
	if kind == "Banded" then
		band(ctx, "RarityBand", 0.75, color, 0.18)
	elseif kind == "Gem" then
		part(ctx, "Gem", "Ball", Vector3.one * 0.45, Vector3.new(0, 0.85, -0.85), color, nil, Enum.Material.Neon)
	elseif kind == "Wings" then
		part(ctx, "WingL", "Wedge", Vector3.new(0.1, 0.9, 1.1), Vector3.new(-1.25, 0.4, 0.1), Color3.new(1, 1, 1), Vector3.new(0, -80, 0))
		part(ctx, "WingR", "Wedge", Vector3.new(0.1, 0.9, 1.1), Vector3.new(1.25, 0.4, 0.1), Color3.new(1, 1, 1), Vector3.new(0, 80, 0))
		part(ctx, "WingTipL", "Wedge", Vector3.new(0.12, 0.45, 0.6), Vector3.new(-1.3, 0.55, 0.1), color, Vector3.new(0, -80, 0))
		part(ctx, "WingTipR", "Wedge", Vector3.new(0.12, 0.45, 0.6), Vector3.new(1.3, 0.55, 0.1), color, Vector3.new(0, 80, 0))
	elseif kind == "Crown" then
		part(ctx, "CrownRing", "Cylinder", Vector3.new(0.3, 1.0, 1.0), Vector3.new(0, 1.55, 0), color, Vector3.new(0, 0, 90), Enum.Material.Metal)
		for index = 0, 4 do
			local angle = math.rad(index * 72)
			part(ctx, "CrownSpike" .. index, "Wedge", Vector3.new(0.15, 0.35, 0.18), Vector3.new(math.sin(angle) * 0.45, 1.85, math.cos(angle) * 0.45), color, Vector3.new(0, math.deg(angle), 0), Enum.Material.Metal)
		end
	elseif kind == "Horns" then
		part(ctx, "HornL", "Wedge", Vector3.new(0.25, 0.7, 0.35), Vector3.new(-0.45, 1.55, 0), color, Vector3.new(0, 0, 20))
		part(ctx, "HornR", "Wedge", Vector3.new(0.25, 0.7, 0.35), Vector3.new(0.45, 1.55, 0), color, Vector3.new(0, 0, -20))
		part(ctx, "Spike", "Wedge", Vector3.new(0.2, 0.45, 0.25), Vector3.new(0, 1.7, 0.3), color)
	elseif kind == "Stars" then
		for index = 1, 3 do
			local angle = math.rad(index * 120)
			part(ctx, "OrbitStar" .. index, "Ball", Vector3.one * 0.35, Vector3.new(math.cos(angle) * 1.6, 0.3 + index * 0.25, math.sin(angle) * 1.6), if index % 2 == 0 then color2 else color, nil, Enum.Material.Neon)
		end
		CollectionService:AddTag(ctx.Model, "OrbitFX")
	elseif kind == "Glitch" then
		for index, data in { { -0.3, 0.4, -15 }, { 0.2, -0.1, 25 }, { -0.1, -0.6, -35 }, { 0.35, 0.8, 10 } } do
			part(ctx, "Crack" .. index, "Block", Vector3.new(0.06, 0.8, 0.06), Vector3.new(data[1], data[2], -1.05), color2, Vector3.new(0, 0, data[3]), Enum.Material.Neon)
		end
	elseif kind == "Halo" then
		part(ctx, "Halo", "Cylinder", Vector3.new(0.12, 1.8, 1.8), Vector3.new(0, 2.05, 0), color2, Vector3.new(0, 0, 90), Enum.Material.Neon)
	elseif kind == "SakuraCrystal" then
		part(ctx, "CrystalShell", "Sphere", Vector3.new(2.5, 3.3, 2.5), Vector3.zero, color, nil, Enum.Material.Glass, 0.45)
		for index = 1, 6 do
			local angle = math.rad(index * 60)
			part(ctx, "Petal" .. index, "Sphere", Vector3.new(0.4, 0.06, 0.25), Vector3.new(math.cos(angle) * 1.5, 1.2 + (index % 2) * 0.4, math.sin(angle) * 1.5), Color3.fromHex("#FFB7C5"), Vector3.new(20, index * 60, 0), Enum.Material.Neon)
		end
		CollectionService:AddTag(ctx.Model, "OrbitFX")
	end
end

-- factor < 1 darkens, factor > 1 lightens toward white (tools/blender/voxel.py `shade`)
local function shade(color: Color3, factor: number): Color3
	if factor >= 1 then
		return color:Lerp(Color3.new(1, 1, 1), math.min(factor - 1, 1))
	end
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function findAsset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Eggs")
	local found = folder and folder:FindFirstChild(name)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

local function themeFor(spec: EggSpec): (string, { string }, string)
	local character = Characters.Get(spec.CharacterId)
	local eggModel = spec.EggModel or character.EggModel
	local special = SPECIAL_THEMES[eggModel]
	if special then
		return eggModel, special.Palette, special.Overlay
	end
	local zone = Zones.ById[character.Zone]
	if zone then
		return eggModel, zone.EggTheme.Palette, zone.EggTheme.Overlay
	end
	return eggModel, { "#FFFFFF" }, "None"
end

function EggBuilder.Build(spec: EggSpec, scaleOverride: number?): Model
	local character = Characters.Get(spec.CharacterId)
	local rarity = if spec.Awakened then Rarities.Next(character.Rarity) else Rarities.Get(character.Rarity)
	local size = Sizes.Get(spec.SizeTier)
	local scale = scaleOverride or size.Scale
	local eggModel, palette, overlayKind = themeFor(spec)
	local colorIndex = math.clamp(spec.Color or 1, 1, #palette)

	local model = Instance.new("Model")
	model.Name = "Egg"
	local shellSize = SHELL * scale
	local ctx: Ctx = {
		Model = model,
		Scale = scale,
		Size = shellSize,
		Base = Color3.fromHex(palette[colorIndex]),
		Center = Vector3.new(0, shellSize.Y / 2, 0),
	}

	local asset = findAsset(eggModel)
	local builtInOrnament = false
	if asset then
		local clone = asset:Clone()
		local shellHeight = clone:GetAttribute("ShellHeight")
		if type(shellHeight) ~= "number" or shellHeight <= 0 then
			local _, assetSize = clone:GetBoundingBox()
			shellHeight = assetSize.Y
		end
		local fit = shellSize.Y / math.max(shellHeight :: number, 0.1)
		clone:ScaleTo(clone:GetScale() * fit)
		clone:PivotTo(CFrame.new(ctx.Center))
		builtInOrnament = clone:GetAttribute("Ornament") == rarity.Ornament
		local tintColor = if rarity.Ornament == "Glitch" then Color3.fromHex("#141414") else ctx.Base
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				if descendant:GetAttribute("OrnamentPart") and not builtInOrnament then
					continue -- wrong rarity (e.g. Awakened): destroyed with the clone
				end
				local tint = descendant:GetAttribute("Tint")
				if type(tint) == "number" then
					descendant.Color = shade(tintColor, tint)
				end
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				descendant.Parent = model
				if descendant:GetAttribute("Orbit") == true then
					CollectionService:AddTag(model, "OrbitFX")
				end
			end
		end
		clone:Destroy()
	else
		local shellColor = ctx.Base
		if rarity.Ornament == "Glitch" then
			shellColor = Color3.fromHex("#141414")
		end
		local shell = part(ctx, "Shell", "Sphere", SHELL, Vector3.zero, shellColor, nil, if overlayKind == "Ghostfire" then Enum.Material.Glass else Enum.Material.SmoothPlastic, if overlayKind == "Ghostfire" then 0.35 else 0)
		if overlayKind == "NeonCeramic" then
			shell.Reflectance = 0.15
		elseif overlayKind == "ObsidianWings" then
			shell.Material = Enum.Material.Slate
		elseif overlayKind == "RuneCrystal" then
			shell.Material = Enum.Material.Glass
			shell.Transparency = 0.15
		end
		overlay(ctx, overlayKind)
	end
	if not builtInOrnament then
		ornament(ctx, rarity)
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.1, 1) * scale
	root.CFrame = CFrame.new(0, 0.05 * scale, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	Effects.AddRarityAura(model, rarity, scale)
	Effects.ApplyMutation(model, spec.Mutation, scale)
	model:SetAttribute("CharacterId", spec.CharacterId)
	return model
end

-- Height of an egg of this size (used for billboards and carrying offsets)
function EggBuilder.Height(sizeTier: number): number
	return SHELL.Y * Sizes.Get(sizeTier).Scale
end

return EggBuilder
