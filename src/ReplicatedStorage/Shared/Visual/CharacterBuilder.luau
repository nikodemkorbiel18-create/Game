--!strict
-- Builds character models. If ReplicatedStorage.Assets.Characters contains a model named
-- after the character's ModelName (e.g. "Char_KohanaNineTail"), that model is cloned and
-- scaled (direct-child parts with an Orbit attribute, like Hive's drones, spin around it).
-- Otherwise a clean placeholder chibi is assembled from primitives using the character's
-- Look config and Visual/PropLibrary.
--
-- The returned Model is anchored, non-colliding, has PrimaryPart "Root" at the feet and
-- faces -Z. Callers position it with Model:PivotTo().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = script.Parent.Parent
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local PropLibrary = require(script.Parent.PropLibrary)
local Effects = require(script.Parent.Effects)

type Look = Characters.Look

export type Options = {
	Scale: number?,
	Mutation: string?,
	Awakened: boolean?,
	Silhouette: boolean?, -- all black, no effects (undiscovered index entries)
	NoEffects: boolean?,
}

local CharacterBuilder = {}

local ANCHORS: { [string]: { [string]: Vector3 } } = {
	Chibi = {
		Root = Vector3.zero,
		Head = Vector3.new(0, 3.35, 0),
		Face = Vector3.new(0, 3.2, -1.05),
		HeadTop = Vector3.new(0, 4.45, 0),
		Back = Vector3.new(0, 1.7, 0.5),
		RightHand = Vector3.new(1.0, 1.05, -0.15),
		LeftHand = Vector3.new(-1.0, 1.05, -0.15),
	},
	Slime = {
		Root = Vector3.zero,
		Head = Vector3.new(0, 1.3, 0),
		Face = Vector3.new(0, 1.45, -1.45),
		HeadTop = Vector3.new(0, 2.45, 0),
		Back = Vector3.new(0, 1.2, 1.3),
		RightHand = Vector3.new(1.4, 0.8, -0.3),
		LeftHand = Vector3.new(-1.4, 0.8, -0.3),
	},
	Umbrella = {
		Root = Vector3.zero,
		Head = Vector3.new(0, 3.2, 0),
		Face = Vector3.new(0, 2.95, -1.55),
		HeadTop = Vector3.new(0, 3.95, 0),
		Back = Vector3.new(0, 3.0, 1.4),
		RightHand = Vector3.new(1.4, 2.8, 0),
		LeftHand = Vector3.new(-1.4, 2.8, 0),
	},
	Lantern = {
		Root = Vector3.zero,
		Head = Vector3.new(0, 2.2, 0),
		Face = Vector3.new(0, 2.3, -1.3),
		HeadTop = Vector3.new(0, 4.0, 0),
		Back = Vector3.new(0, 2.2, 1.3),
		RightHand = Vector3.new(1.45, 2.0, 0),
		LeftHand = Vector3.new(-1.45, 2.0, 0),
	},
	Mech = {
		Root = Vector3.zero,
		Head = Vector3.new(0, 4.25, 0),
		Face = Vector3.new(0, 4.1, -1.05),
		HeadTop = Vector3.new(0, 5.35, 0),
		Back = Vector3.new(0, 2.1, 0.95),
		RightHand = Vector3.new(1.65, 1.1, -0.25),
		LeftHand = Vector3.new(-1.65, 1.1, -0.25),
	},
}
ANCHORS.Petals = ANCHORS.Chibi
ANCHORS.Twins = ANCHORS.Chibi

type Builder = {
	Model: Model,
	Scale: number,
	Look: Look,
	Offset: Vector3,
}

local function resolveColor(look: Look, key: string): Color3
	local value: string? = (look :: any)[key]
	if value == nil then
		value = key
	end
	local ok, color = pcall(Color3.fromHex, value :: string)
	if ok then
		return color
	end
	return Color3.new(1, 0, 1)
end

local function makePart(
	builder: Builder,
	name: string,
	shape: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	rotation: Vector3?,
	material: string?,
	transparency: number?
): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if shape == "Ball" then
			basic.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			basic.Shape = Enum.PartType.Cylinder
		end
		part = basic
	end
	if shape == "Sphere" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	local s = builder.Scale
	part.Name = name
	part.Size = Vector3.new(math.max(size.X * s, 0.05), math.max(size.Y * s, 0.05), math.max(size.Z * s, 0.05))
	local rot = rotation or Vector3.zero
	part.CFrame = CFrame.new((position + builder.Offset) * s)
		* CFrame.fromOrientation(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	part.Color = color
	part.Material = if material then (Enum.Material :: any)[material] else Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = builder.Model
	return part
end

local function v(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function buildHead(builder: Builder, center: Vector3)
	local look = builder.Look
	local skin = resolveColor(look, "Skin")
	local hair = resolveColor(look, "Hair")
	local eyes = resolveColor(look, "Eyes")
	makePart(builder, "Head", "Sphere", Vector3.new(2.3, 2.15, 2.15), center, skin)
	local face = center + Vector3.new(0, -0.15, -1.0)
	makePart(builder, "EyeL", "Sphere", Vector3.new(0.4, 0.58, 0.12), face + Vector3.new(-0.42, 0.05, 0), eyes)
	makePart(builder, "EyeR", "Sphere", Vector3.new(0.4, 0.58, 0.12), face + Vector3.new(0.42, 0.05, 0), eyes)
	makePart(builder, "GlintL", "Ball", Vector3.new(0.15, 0.15, 0.15), face + Vector3.new(-0.36, 0.2, -0.06), Color3.new(1, 1, 1))
	makePart(builder, "GlintR", "Ball", Vector3.new(0.15, 0.15, 0.15), face + Vector3.new(0.48, 0.2, -0.06), Color3.new(1, 1, 1))
	makePart(builder, "BlushL", "Sphere", Vector3.new(0.38, 0.16, 0.06), face + Vector3.new(-0.72, -0.28, 0.08), Color3.fromHex("#FF8FAB"), nil, nil, 0.45)
	makePart(builder, "BlushR", "Sphere", Vector3.new(0.38, 0.16, 0.06), face + Vector3.new(0.72, -0.28, 0.08), Color3.fromHex("#FF8FAB"), nil, nil, 0.45)
	makePart(builder, "Mouth", "Block", Vector3.new(0.28, 0.07, 0.05), face + Vector3.new(0, -0.45, 0.02), Color3.fromHex("#5A2A27"))

	local style = look.HairStyle
	if style == "None" then
		return
	end
	if style == "Hood" then
		local outfit = resolveColor(look, "Outfit")
		makePart(builder, "HoodBack", "Sphere", Vector3.new(2.65, 2.5, 1.9), center + Vector3.new(0, 0.1, 0.55), outfit)
		makePart(builder, "HoodTop", "Sphere", Vector3.new(2.6, 1.45, 2.35), center + Vector3.new(0, 0.75, 0.05), outfit)
		makePart(builder, "Bangs", "Sphere", Vector3.new(1.6, 0.5, 0.4), center + Vector3.new(0, 0.45, -0.95), hair)
		return
	end
	if style == "Helmet" then
		local outfit = resolveColor(look, "Outfit")
		makePart(builder, "Helmet", "Sphere", Vector3.new(2.6, 2.4, 2.5), center + Vector3.new(0, 0.1, 0.05), outfit, nil, "Metal")
		makePart(builder, "Visor", "Block", Vector3.new(1.6, 0.25, 0.1), center + Vector3.new(0, 0, -1.22), resolveColor(look, "Accent"), nil, "Neon")
		return
	end
	makePart(builder, "HairCap", "Sphere", Vector3.new(2.45, 1.6, 2.4), center + Vector3.new(0, 0.6, 0.08), hair)
	makePart(builder, "Bangs", "Sphere", Vector3.new(2.0, 0.55, 0.5), center + Vector3.new(0, 0.62, -0.88), hair)
	if style == "Short" then
		makePart(builder, "HairBack", "Sphere", Vector3.new(2.3, 1.6, 1.0), center + Vector3.new(0, 0.05, 0.6), hair)
	elseif style == "Spiky" then
		for index = 0, 5 do
			local angle = math.rad(index * 60)
			local offset = Vector3.new(math.cos(angle) * 0.75, 1.2, math.sin(angle) * 0.75)
			makePart(builder, "Spike" .. index, "Wedge", Vector3.new(0.55, 0.9, 0.6), center + offset, hair, Vector3.new(0, -index * 60 + 90, 0))
		end
		makePart(builder, "HairBack", "Sphere", Vector3.new(2.3, 1.5, 1.0), center + Vector3.new(0, 0.1, 0.6), hair)
	elseif style == "Long" then
		makePart(builder, "HairBack", "Block", Vector3.new(2.2, 2.4, 0.6), center + Vector3.new(0, -0.45, 0.75), hair)
		makePart(builder, "HairSideL", "Block", Vector3.new(0.35, 1.8, 0.8), center + Vector3.new(-1.12, -0.35, 0.15), hair)
		makePart(builder, "HairSideR", "Block", Vector3.new(0.35, 1.8, 0.8), center + Vector3.new(1.12, -0.35, 0.15), hair)
	elseif style == "TwinTails" then
		makePart(builder, "TailL", "Sphere", Vector3.new(0.85, 2.3, 0.85), center + Vector3.new(-1.45, -0.45, 0.3), hair, Vector3.new(0, 0, -12))
		makePart(builder, "TailR", "Sphere", Vector3.new(0.85, 2.3, 0.85), center + Vector3.new(1.45, -0.45, 0.3), hair, Vector3.new(0, 0, 12))
	elseif style == "Bun" then
		makePart(builder, "Bun", "Ball", Vector3.new(1.0, 1.0, 1.0), center + Vector3.new(0, 1.45, 0.4), hair)
	elseif style == "Bob" then
		makePart(builder, "BobL", "Block", Vector3.new(0.42, 1.45, 1.7), center + Vector3.new(-1.1, -0.3, 0.1), hair)
		makePart(builder, "BobR", "Block", Vector3.new(0.42, 1.45, 1.7), center + Vector3.new(1.1, -0.3, 0.1), hair)
		makePart(builder, "BobBack", "Sphere", Vector3.new(2.35, 1.8, 1.0), center + Vector3.new(0, -0.15, 0.62), hair)
	elseif style == "Ponytail" then
		makePart(builder, "Ponytail", "Sphere", Vector3.new(0.75, 2.1, 0.75), center + Vector3.new(0, 0.1, 1.35), hair, Vector3.new(-30, 0, 0))
	elseif style == "Messy" then
		local tufts = { Vector3.new(0.6, 1.25, -0.2), Vector3.new(-0.5, 1.3, 0.1), Vector3.new(0.1, 1.4, 0.5), Vector3.new(-0.9, 0.9, -0.4), Vector3.new(0.95, 0.85, 0.3) }
		for index, offset in tufts do
			makePart(builder, "Tuft" .. index, "Ball", Vector3.new(0.7, 0.7, 0.7), center + offset, hair)
		end
		makePart(builder, "HairBack", "Sphere", Vector3.new(2.3, 1.6, 1.0), center + Vector3.new(0, 0.05, 0.6), hair)
	elseif style == "Ringlets" then
		for side = -1, 1, 2 do
			for index = 0, 2 do
				makePart(builder, "Ringlet", "Ball", Vector3.new(0.62, 0.62, 0.62), center + Vector3.new(side * 1.25, -0.2 - index * 0.5, 0.25), hair)
			end
		end
		makePart(builder, "HairBack", "Sphere", Vector3.new(2.3, 1.6, 1.0), center + Vector3.new(0, 0.05, 0.6), hair)
	end
end

local function buildChibiBody(builder: Builder)
	local look = builder.Look
	local skin = resolveColor(look, "Skin")
	local outfit = resolveColor(look, "Outfit")
	local outfit2 = resolveColor(look, "Outfit2")
	local shoe = Color3.fromHex("#2B2B2B")
	makePart(builder, "LegL", "Block", Vector3.new(0.55, 0.9, 0.6), Vector3.new(-0.33, 0.55, 0), outfit)
	makePart(builder, "LegR", "Block", Vector3.new(0.55, 0.9, 0.6), Vector3.new(0.33, 0.55, 0), outfit)
	makePart(builder, "ShoeL", "Block", Vector3.new(0.6, 0.25, 0.75), Vector3.new(-0.33, 0.12, -0.05), shoe)
	makePart(builder, "ShoeR", "Block", Vector3.new(0.6, 0.25, 0.75), Vector3.new(0.33, 0.12, -0.05), shoe)
	makePart(builder, "Torso", "Block", Vector3.new(1.4, 1.25, 0.9), Vector3.new(0, 1.6, 0), outfit)
	makePart(builder, "Collar", "Block", Vector3.new(1.45, 0.25, 0.95), Vector3.new(0, 2.15, 0), outfit2)
	makePart(builder, "ArmL", "Block", Vector3.new(0.45, 1.1, 0.5), Vector3.new(-0.95, 1.65, 0), outfit, Vector3.new(0, 0, -8))
	makePart(builder, "ArmR", "Block", Vector3.new(0.45, 1.1, 0.5), Vector3.new(0.95, 1.65, 0), outfit, Vector3.new(0, 0, 8))
	makePart(builder, "HandL", "Ball", Vector3.new(0.45, 0.45, 0.45), Vector3.new(-1.0, 1.05, -0.05), skin)
	makePart(builder, "HandR", "Ball", Vector3.new(0.45, 0.45, 0.45), Vector3.new(1.0, 1.05, -0.05), skin)
	buildHead(builder, ANCHORS.Chibi.Head)
end

local function buildBody(builder: Builder, body: string)
	local look = builder.Look
	if body == "Slime" then
		local skin = resolveColor(look, "Skin")
		makePart(builder, "SlimeBody", "Sphere", Vector3.new(3.0, 2.5, 3.0), Vector3.new(0, 1.25, 0), skin, nil, "SmoothPlastic", 0.12)
		makePart(builder, "SlimeShine", "Sphere", Vector3.new(0.8, 0.5, 0.3), Vector3.new(-0.7, 2.0, -1.1), Color3.new(1, 1, 1), nil, nil, 0.35)
		local eyes = resolveColor(look, "Eyes")
		makePart(builder, "EyeL", "Sphere", Vector3.new(0.4, 0.6, 0.12), Vector3.new(-0.45, 1.55, -1.42), eyes)
		makePart(builder, "EyeR", "Sphere", Vector3.new(0.4, 0.6, 0.12), Vector3.new(0.45, 1.55, -1.42), eyes)
		makePart(builder, "Mouth", "Block", Vector3.new(0.35, 0.08, 0.05), Vector3.new(0, 1.1, -1.48), Color3.fromHex("#1B4332"))
	elseif body == "Umbrella" then
		local outfit = resolveColor(look, "Outfit")
		makePart(builder, "Canopy", "Sphere", Vector3.new(3.3, 1.5, 3.3), Vector3.new(0, 3.2, 0), outfit)
		makePart(builder, "CanopyStripe", "Sphere", Vector3.new(0.6, 1.52, 3.32), Vector3.new(0, 3.2, 0), resolveColor(look, "Outfit2"))
		makePart(builder, "Tip", "Ball", Vector3.new(0.35, 0.35, 0.35), Vector3.new(0, 4.0, 0), resolveColor(look, "Accent"))
		makePart(builder, "Handle", "Block", Vector3.new(0.35, 2.3, 0.35), Vector3.new(0, 1.35, 0), Color3.fromHex("#8D6E63"))
		makePart(builder, "Geta", "Block", Vector3.new(0.7, 0.3, 1.0), Vector3.new(0, 0.15, -0.1), Color3.fromHex("#6F4E37"))
		makePart(builder, "Eye", "Sphere", Vector3.new(0.8, 0.9, 0.2), Vector3.new(0, 3.05, -1.52), Color3.new(1, 1, 1))
		makePart(builder, "Pupil", "Ball", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0, 3.05, -1.62), resolveColor(look, "Eyes"))
	elseif body == "Lantern" then
		local paper = resolveColor(look, "Outfit")
		makePart(builder, "Lantern", "Cylinder", Vector3.new(3.0, 2.7, 2.7), Vector3.new(0, 2.2, 0), paper, Vector3.new(0, 0, 90))
		for index, y in { 1.3, 2.2, 3.1 } do
			makePart(builder, "Rib" .. index, "Cylinder", Vector3.new(0.1, 2.78, 2.78), Vector3.new(0, y, 0), Color3.fromHex("#C9A66B"), Vector3.new(0, 0, 90))
		end
		makePart(builder, "CapTop", "Cylinder", Vector3.new(0.3, 2.0, 2.0), Vector3.new(0, 3.8, 0), Color3.fromHex("#1B1B1E"), Vector3.new(0, 0, 90))
		makePart(builder, "CapBottom", "Cylinder", Vector3.new(0.3, 2.0, 2.0), Vector3.new(0, 0.6, 0), Color3.fromHex("#1B1B1E"), Vector3.new(0, 0, 90))
		makePart(builder, "Band", "Cylinder", Vector3.new(0.35, 2.74, 2.74), Vector3.new(0, 1.75, 0), resolveColor(look, "Outfit2"), Vector3.new(0, 0, 90))
		local eyes = resolveColor(look, "Eyes")
		makePart(builder, "EyeL", "Sphere", Vector3.new(0.45, 0.35, 0.12), Vector3.new(-0.5, 2.6, -1.33), eyes)
		makePart(builder, "EyeR", "Sphere", Vector3.new(0.45, 0.35, 0.12), Vector3.new(0.5, 2.6, -1.33), eyes)
		makePart(builder, "Glow", "Ball", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 2.2, 0), resolveColor(look, "Accent"), nil, "Neon", 0.4)
	elseif body == "Mech" then
		local outfit = resolveColor(look, "Outfit")
		local outfit2 = resolveColor(look, "Outfit2")
		local accent = resolveColor(look, "Accent")
		makePart(builder, "SuitTorso", "Block", Vector3.new(2.5, 2.0, 1.8), Vector3.new(0, 2.1, 0), outfit, nil, "DiamondPlate")
		makePart(builder, "Cockpit", "Block", Vector3.new(1.5, 0.9, 0.1), Vector3.new(0, 2.35, -0.92), Color3.fromHex("#8ECAE6"), nil, "Glass", 0.3)
		makePart(builder, "SuitLegL", "Block", Vector3.new(0.9, 1.15, 1.0), Vector3.new(-0.62, 0.58, 0), outfit2, nil, "Metal")
		makePart(builder, "SuitLegR", "Block", Vector3.new(0.9, 1.15, 1.0), Vector3.new(0.62, 0.58, 0), outfit2, nil, "Metal")
		makePart(builder, "SuitArmL", "Block", Vector3.new(0.8, 1.6, 0.9), Vector3.new(-1.65, 2.0, 0), outfit2, nil, "Metal")
		makePart(builder, "SuitArmR", "Block", Vector3.new(0.8, 1.6, 0.9), Vector3.new(1.65, 2.0, 0), outfit2, nil, "Metal")
		makePart(builder, "FistL", "Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-1.65, 1.1, -0.25), accent)
		makePart(builder, "FistR", "Ball", Vector3.new(0.9, 0.9, 0.9), Vector3.new(1.65, 1.1, -0.25), accent)
		makePart(builder, "Thruster", "Cylinder", Vector3.new(0.8, 0.7, 0.7), Vector3.new(0, 2.3, 1.1), Color3.fromHex("#343A40"), Vector3.new(0, 90, 0))
		makePart(builder, "ThrusterGlow", "Ball", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 2.3, 1.5), accent, nil, "Neon")
		buildHead(builder, ANCHORS.Mech.Head)
	elseif body == "Twins" then
		local base = builder.Offset
		builder.Offset = base + Vector3.new(-1.15, 0, 0)
		buildChibiBody(builder)
		builder.Offset = base + Vector3.new(1.15, 0, 0)
		local originalHair = look.Hair
		look.Hair = look.Outfit2
		buildChibiBody(builder)
		look.Hair = originalHair
		builder.Offset = base
	else
		buildChibiBody(builder)
		if body == "Petals" then
			for _, child in builder.Model:GetChildren() do
				if child:IsA("BasePart") and not string.find(child.Name, "Eye") and not string.find(child.Name, "Glint") then
					child.Material = Enum.Material.Neon
					child.Transparency = 0.25
				end
			end
		end
	end
end

local function addProps(builder: Builder, body: string)
	local anchors = ANCHORS[body] or ANCHORS.Chibi
	for _, propName in builder.Look.Props do
		local parts = PropLibrary[propName]
		if parts == nil then
			warn("[CharacterBuilder] Unknown prop " .. propName)
			continue
		end
		for index, spec in parts do
			local anchor = anchors[spec.Anchor] or Vector3.zero
			makePart(
				builder,
				propName .. index,
				spec.Shape,
				v(spec.Size),
				anchor + v(spec.Offset),
				resolveColor(builder.Look, spec.Color),
				if spec.Rot then v(spec.Rot) else nil,
				spec.Material,
				spec.Transparency
			)
		end
	end
end

local function findAsset(modelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Characters")
	local found = folder and folder:FindFirstChild(modelName)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

local function finalize(model: Model, rootHeight: number)
	local root = model:FindFirstChild("Root") :: BasePart?
	if not root then
		local newRoot = Instance.new("Part")
		newRoot.Name = "Root"
		newRoot.Size = Vector3.new(1, 0.1, 1)
		newRoot.CFrame = CFrame.new(0, rootHeight, 0)
		newRoot.Transparency = 1
		newRoot.Anchored = true
		newRoot.CanCollide = false
		newRoot.CanQuery = false
		newRoot.CanTouch = false
		newRoot.Massless = true
		newRoot.Parent = model
		root = newRoot
	end
	model.PrimaryPart = root
end

function CharacterBuilder.Build(characterId: string, options: Options?): Model
	local opts: Options = options or {}
	local character = Characters.Get(characterId)
	local scale = opts.Scale or 1
	local model: Model
	local asset = findAsset(character.ModelName)
	if asset then
		model = asset:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.Massless = true
			end
		end
		if not model.PrimaryPart then
			local _, size = model:GetBoundingBox()
			local cf = model:GetPivot()
			finalize(model, cf.Position.Y - size.Y / 2)
		end
		model:ScaleTo(scale * model:GetScale())
		model:PivotTo(CFrame.new())
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("Orbit") == true then
				CollectionService:AddTag(model, "OrbitFX")
				break
			end
		end
	else
		model = Instance.new("Model")
		local look = table.clone(character.Look)
		local builder: Builder = { Model = model, Scale = scale, Look = look, Offset = Vector3.zero }
		local body = look.Body or "Chibi"
		buildBody(builder, body)
		addProps(builder, body)
		finalize(model, 0.05 * scale)
	end
	model.Name = character.ModelName
	model:SetAttribute("CharacterId", characterId)
	model:SetAttribute("Idle", character.Idle)
	model:SetAttribute("Emote", character.Emote)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	if opts.Silhouette then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = Color3.new(0.05, 0.05, 0.08)
				descendant.Material = Enum.Material.SmoothPlastic
				if descendant.Transparency < 1 then
					descendant.Transparency = 0
				end
			elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Light") or descendant:IsA("Highlight") then
				descendant:Destroy()
			end
		end
		return model
	end

	if not opts.NoEffects then
		local rarity = Rarities.Get(character.Rarity)
		if opts.Awakened then
			rarity = Rarities.Next(character.Rarity)
			Effects.AddAwakenedStar(model, scale)
		end
		Effects.AddRarityAura(model, rarity, scale)
		Effects.ApplyMutation(model, opts.Mutation, scale)
	end
	return model
end

-- Anchor position (at scale 1) for effects that follow a body point.
function CharacterBuilder.Anchor(characterId: string, anchor: string): Vector3
	local body = Characters.Get(characterId).Look.Body or "Chibi"
	local anchors = ANCHORS[body] or ANCHORS.Chibi
	return anchors[anchor] or Vector3.zero
end

return CharacterBuilder
