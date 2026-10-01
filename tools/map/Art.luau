--!nocheck
-- Voxel art made with tools/blender: turns the part layouts in assets/models/<set>/parts/*.json
-- into Roblox models and drops them in the asset folders the game reads.
--
--   Char_*      -> ReplicatedStorage.Assets.Characters   (limb groups as sub-models, Root at the feet)
--   Egg_*       -> ReplicatedStorage.Assets.Eggs         (pivot at the shell centre)
--   Guardian_*  -> ServerStorage.Assets.Guardians
--
-- Part attributes the game reads: Tint (egg shell, recoloured with the cosmetic colour),
-- Orbit (spins around the model), OrnamentPart (built-in rarity ornament). Model
-- attributes: ShellHeight and Ornament on eggs.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

local Art = {}

Art.Root = "assets/models"

local function makePart(spec)
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	part.CFrame = CFrame.new(spec.position[1], spec.position[2], spec.position[3])
	part.Color = Color3.fromHex(spec.color)
	part.Material = Enum.Material[spec.material]
	part.Transparency = spec.transparency or 0
	part.Reflectance = spec.reflectance or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in spec.attributes or {} do
		part:SetAttribute(key, value)
	end
	return part
end

-- Lune only saves a model's pivot under its serialized name (setting WorldPivot is lost).
local function setPivot(model, cframe)
	model.WorldPivotData = cframe
end

local function allOrbit(group)
	for _, spec in group.parts do
		if not (spec.attributes and spec.attributes.Orbit) then
			return false
		end
	end
	return #group.parts > 0
end

-- Builds one model from a decoded part layout.
function Art.Build(data)
	local model = Instance.new("Model")
	model.Name = data.name
	for key, value in data.attributes or {} do
		model:SetAttribute(key, value)
	end
	local isEgg = data.kind == "Egg"
	for _, group in data.groups do
		-- eggs are flattened by EggBuilder anyway; orbiting pieces must be direct children
		-- so the client's orbit spinner finds them
		local flat = isEgg or allOrbit(group)
		local parent = model
		if not flat then
			parent = Instance.new("Model")
			parent.Name = group.name
			setPivot(parent, CFrame.new(group.pivot[1], group.pivot[2], group.pivot[3]))
			parent.Parent = model
		end
		for _, spec in group.parts do
			makePart(spec).Parent = parent
		end
	end
	if isEgg then
		local shellHeight = (data.attributes and data.attributes.ShellHeight) or data.size[2]
		setPivot(model, CFrame.new(0, shellHeight / 2, 0))
	else
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(1, 0.1, 1)
		root.CFrame = CFrame.new(0, 0.05, 0)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
		root.CanQuery = false
		root.CastShadow = false
		root.Massless = true
		root.Parent = model
		model.PrimaryPart = root
	end
	return model
end

-- Every part layout under assets/models/*/parts, as { set, name, path, data }.
function Art.List()
	local found = {}
	if not fs.isDir(Art.Root) then
		return found
	end
	for _, set in fs.readDir(Art.Root) do
		local dir = Art.Root .. "/" .. set .. "/parts"
		if fs.isDir(dir) then
			for _, file in fs.readDir(dir) do
				if string.sub(file, -5) == ".json" then
					local path = dir .. "/" .. file
					table.insert(found, { set = set, name = string.sub(file, 1, -6), path = path, data = serde.decode("json", fs.readFile(path)) })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.path < b.path
	end)
	return found
end

local function folderFor(place, name)
	local function child(parent, childName)
		local existing = parent:FindFirstChild(childName)
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = childName
		folder.Parent = parent
		return folder
	end
	if string.sub(name, 1, 5) == "Char_" then
		return child(child(place:GetService("ReplicatedStorage"), "Assets"), "Characters")
	elseif string.sub(name, 1, 4) == "Egg_" then
		return child(child(place:GetService("ReplicatedStorage"), "Assets"), "Eggs")
	elseif string.sub(name, 1, 9) == "Guardian_" then
		return child(child(place:GetService("ServerStorage"), "Assets"), "Guardians")
	end
	error("Don't know where " .. name .. " goes (expected Char_, Egg_ or Guardian_)")
end

-- Puts every voxel model into the place, replacing older copies. Returns the count.
function Art.Insert(place)
	local count = 0
	for _, entry in Art.List() do
		local folder = folderFor(place, entry.name)
		local old = folder:FindFirstChild(entry.name)
		if old then
			old:Destroy()
		end
		Art.Build(entry.data).Parent = folder
		count += 1
	end
	return count
end

return Art
