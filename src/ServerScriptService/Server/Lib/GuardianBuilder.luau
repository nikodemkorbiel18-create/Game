--!strict
-- Prepares Guardian rigs. Uses ServerStorage.Assets.Guardians[template] when it exists
-- (e.g. the Hall Monitor and Ramen Master meshes) and otherwise builds a clean placeholder
-- from primitives. Any template is rigged at runtime: a HumanoidRootPart + Humanoid are
-- added if missing and every part is welded to the root, so artists can drop in plain
-- unrigged models.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local GuardianBuilder = {}

local function part(model: Model, name: string, shape: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, transparency: number?): BasePart
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
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.Anchored = true
	p.Parent = model
	return p
end

-- Placeholder guardian ~8 studs tall, facing -Z, feet at y = 0
local function placeholder(guardian: Zones.Guardian): Model
	local model = Instance.new("Model")
	model.Name = guardian.Template
	local main = Color3.fromHex(guardian.Color)
	local skin = Color3.fromHex("#F1C27D")
	local dark = Color3.fromHex("#1B1B1E")
	local white = Color3.new(1, 1, 1)
	local gold = Color3.fromHex("#FFD86B")
	local id = guardian.Id

	if id == "StoneKomainu" then
		local stone = Color3.fromHex("#9A9A9A")
		part(model, "Body", "Block", Vector3.new(4, 3.5, 7), Vector3.new(0, 4, 0), stone, Enum.Material.Slate)
		part(model, "Head", "Ball", Vector3.new(4.5, 4.5, 4.5), Vector3.new(0, 6.5, -3.5), stone, Enum.Material.Slate)
		part(model, "Mane", "Ball", Vector3.new(5.5, 5.5, 5.5), Vector3.new(0, 6.3, -2.8), Color3.fromHex("#7A7A7A"), Enum.Material.Slate)
		for _, offset in { Vector3.new(-1.5, 1.2, -2.5), Vector3.new(1.5, 1.2, -2.5), Vector3.new(-1.5, 1.2, 2.5), Vector3.new(1.5, 1.2, 2.5) } do
			part(model, "Leg", "Block", Vector3.new(1.4, 2.4, 1.4), offset, stone, Enum.Material.Slate)
		end
		part(model, "EyeL", "Ball", Vector3.new(0.7, 0.7, 0.7), Vector3.new(-0.9, 7, -5.6), Color3.fromHex("#FF7B00"), Enum.Material.Neon)
		part(model, "EyeR", "Ball", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.9, 7, -5.6), Color3.fromHex("#FF7B00"), Enum.Material.Neon)
		part(model, "Tail", "Ball", Vector3.new(2, 2, 2), Vector3.new(0, 6, 4), Color3.fromHex("#7A7A7A"), Enum.Material.Slate)
		return model
	end

	-- humanoid chibi guardian
	part(model, "LegL", "Block", Vector3.new(1.1, 2.4, 1.2), Vector3.new(-0.7, 1.2, 0), dark)
	part(model, "LegR", "Block", Vector3.new(1.1, 2.4, 1.2), Vector3.new(0.7, 1.2, 0), dark)
	part(model, "Torso", "Block", Vector3.new(3, 2.8, 1.8), Vector3.new(0, 3.8, 0), main)
	part(model, "ArmL", "Block", Vector3.new(0.9, 2.6, 1), Vector3.new(-2, 3.8, 0), main)
	part(model, "ArmR", "Block", Vector3.new(0.9, 2.6, 1), Vector3.new(2, 3.8, 0), main)
	local head = part(model, "Head", "Ball", Vector3.new(3.6, 3.6, 3.6), Vector3.new(0, 7, 0), skin)
	part(model, "EyeL", "Ball", Vector3.new(0.6, 0.8, 0.3), Vector3.new(-0.65, 7.1, -1.7), dark)
	part(model, "EyeR", "Ball", Vector3.new(0.6, 0.8, 0.3), Vector3.new(0.65, 7.1, -1.7), dark)

	if id == "LifeguardCaptain" then
		part(model, "Visor", "Block", Vector3.new(3.8, 0.3, 2), Vector3.new(0, 8.3, -1.2), Color3.fromHex("#FFD166"))
		part(model, "Whistle", "Ball", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 5, -1), Color3.fromHex("#E63946"))
		part(model, "Flag", "Block", Vector3.new(0.2, 1.4, 1.4), Vector3.new(2.2, 6, 0), Color3.fromHex("#E63946"))
	elseif id == "MaskedSentinel" then
		head.Color = dark
		part(model, "Mask", "Block", Vector3.new(2.6, 1, 0.4), Vector3.new(0, 7.2, -1.7), Color3.fromHex("#C1121F"))
		part(model, "Scarf", "Block", Vector3.new(0.6, 0.4, 3), Vector3.new(0.5, 5.6, 2), Color3.fromHex("#C1121F"))
	elseif id == "StageManager" then
		part(model, "Headset", "Block", Vector3.new(4, 0.4, 0.5), Vector3.new(0, 8.8, 0), dark)
		part(model, "Clipboard", "Block", Vector3.new(1.4, 1.8, 0.2), Vector3.new(-2.4, 3.6, -0.8), Color3.fromHex("#9C6644"))
		local lamp = part(model, "SpotlightLamp", "Cylinder", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 9.6, -0.6), gold, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Angle = 45
		light.Range = 30
		light.Brightness = 3
		light.Face = Enum.NormalId.Front
		light.Color = Color3.fromHex("#FFF3B0")
		light.Parent = lamp
	elseif id == "PatrolMech" then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.Material = Enum.Material.DiamondPlate
				child.Color = Color3.fromHex("#495057")
			end
		end
		(head :: Part).Shape = Enum.PartType.Block
		head.Size = Vector3.new(3.4, 2.6, 3)
		part(model, "Visor", "Block", Vector3.new(2.8, 0.6, 0.3), Vector3.new(0, 7.2, -1.6), Color3.fromHex("#FFBA08"), Enum.Material.Neon)
	elseif id == "KnightCaptain" then
		head.Color = Color3.fromHex("#CAD2C5")
		head.Material = Enum.Material.Metal
		part(model, "Plume", "Block", Vector3.new(0.4, 1.4, 2.4), Vector3.new(0, 9.2, 0), Color3.fromHex("#C1121F"))
		part(model, "Sword", "Block", Vector3.new(0.3, 4.5, 0.3), Vector3.new(2.3, 4.5, -1), Color3.fromHex("#E0E1DD"), Enum.Material.Metal)
		part(model, "Shield", "Block", Vector3.new(0.3, 2.6, 2.2), Vector3.new(-2.6, 3.8, -0.4), Color3.fromHex("#577590"))
	elseif id == "DemonGeneral" then
		part(model, "HornL", "Wedge", Vector3.new(0.5, 1.6, 0.8), Vector3.new(-1, 9, 0), Color3.fromHex("#E9D8A6"))
		part(model, "HornR", "Wedge", Vector3.new(0.5, 1.6, 0.8), Vector3.new(1, 9, 0), Color3.fromHex("#E9D8A6"))
		part(model, "Cape", "Block", Vector3.new(3.4, 4.5, 0.3), Vector3.new(0, 3.6, 1.1), Color3.fromHex("#3C1642"))
	elseif id == "MistveilSpirit" then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.Transparency = 0.35
				child.Material = Enum.Material.Glass
			end
		end
		part(model, "Veil", "Ball", Vector3.new(5, 7, 5), Vector3.new(0, 4.5, 0), Color3.fromHex("#A2D2FF"), Enum.Material.Glass, 0.55)
		part(model, "LanternCore", "Ball", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 7, -0.4), Color3.fromHex("#7FDBFF"), Enum.Material.Neon)
	elseif id == "CelestialWarden" then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "EyeL" and child.Name ~= "EyeR" and child.Name ~= "Head" then
				child.Color = Color3.fromHex("#FFF1C1")
			end
		end
		part(model, "Halo", "Cylinder", Vector3.new(0.3, 4, 4), Vector3.new(0, 9.8, 0), gold, Enum.Material.Neon)
		part(model, "Spear", "Block", Vector3.new(0.3, 7, 0.3), Vector3.new(2.3, 5, -1), gold, Enum.Material.Metal)
	end
	local halo = model:FindFirstChild("Halo")
	if halo and halo:IsA("BasePart") then
		halo.CFrame = halo.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
	local _ = white
	return model
end

local function rig(model: Model)
	local _, size = model:GetBoundingBox()
	local cf = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		local newRoot = Instance.new("Part")
		newRoot.Name = "HumanoidRootPart"
		newRoot.Size = Vector3.new(2, 2, 1)
		newRoot.Transparency = 1
		newRoot.CFrame = CFrame.new(cf.Position.X, bottom + size.Y * 0.45, cf.Position.Z)
		newRoot.Parent = model
		root = newRoot
	end
	local rootPart = root :: BasePart
	model.PrimaryPart = rootPart
	-- weld every part that isn't already held by a joint
	local jointed: { [BasePart]: boolean } = { [rootPart] = true }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
			local joint = descendant :: any
			if joint.Part1 then
				jointed[joint.Part1] = true
			end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not jointed[descendant] then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -6) == "Marker" then
			descendant.Transparency = 1
		end
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = descendant ~= rootPart
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	rootPart.CanCollide = true
	local h: Humanoid
	local existing = model:FindFirstChildOfClass("Humanoid")
	if existing then
		h = existing
	else
		h = Instance.new("Humanoid")
		h.Parent = model
	end
	h.RigType = Enum.HumanoidRigType.R15
	h.HipHeight = math.max(0.1, (rootPart.Position.Y - rootPart.Size.Y / 2) - bottom)
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.BreakJointsOnDeath = false
	h.MaxHealth = math.huge
	h.Health = math.huge
	h.AutoJumpEnabled = true
	h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end

function GuardianBuilder.Build(guardian: Zones.Guardian): Model
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Guardians")
	local template = folder and folder:FindFirstChild(guardian.Template)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = placeholder(guardian)
	end
	rig(model)
	model.Name = guardian.Id
	model:SetAttribute("GuardianId", guardian.Id)
	return model
end

return GuardianBuilder
