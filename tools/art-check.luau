--!nocheck
-- Builds the voxel art through the game's real EggBuilder and CharacterBuilder in the
-- headless emulator and checks the asset conventions: per-character eggs, shell height and
-- pivot at every size, cosmetic tint, built-in rarity ornaments (and the fallback when the
-- rarity changes), orbiting parts, limb groups, mutations and Index silhouettes, plus the
-- Studio FBX import helper (assets/models/zone7/ImportFBX.lua).
-- Run: lune run tools/art-check

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Emu = require("./emu")

local Color3, Vector3 = roblox.Color3, roblox.Vector3
local CFrame = require("./lib/cframe")

local world = Emu.new({ place = "StealAChibi.rbxl", quiet = true })
local game = Emu.I.wrap(world.game) -- for code run inside the server context
world:StartServer()
world:Run(1)

local Shared = "ReplicatedStorage.Shared."
local EggBuilder = world:ServerRequire(Shared .. "Visual.EggBuilder")
local CharacterBuilder = world:ServerRequire(Shared .. "Visual.CharacterBuilder")
local Characters = world:ServerRequire(Shared .. "Config.Characters")
local Zones = world:ServerRequire(Shared .. "Config.Zones")
local Sizes = world:ServerRequire(Shared .. "Config.Sizes")

local failures = 0
local checks = 0
local function check(condition, message, ...)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL  " .. string.format(message, ...))
	end
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 0.02)
end

local function parts(model)
	local list = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	return list
end

local function bounds(model)
	local lowY, highY = math.huge, -math.huge
	for _, part in parts(model) do
		if part.Transparency < 1 then
			local half = part.Size.Y / 2
			lowY = math.min(lowY, part.Position.Y - half)
			highY = math.max(highY, part.Position.Y + half)
		end
	end
	return lowY, highY
end

local PROCEDURAL = { CrownRing = true, HornL = true, HornR = true, Spike = true, OrbitStar1 = true, Gem = true, WingL = true }
local EXPECTED_ORNAMENT = { Legendary = "Crown", Mythic = "Horns", Cosmic = "Stars" }

world:Server(function()
	local CollectionService = game:GetService("CollectionService")
	local palette = Zones.ById[7].EggTheme.Palette
	local zone7 = Characters.ForZone(7)
	check(#zone7 == 6, "expected 6 zone 7 characters, found %d", #zone7)

	for _, character in zone7 do
		local id = character.Id
		check(character.EggModel == "Egg_" .. id, "%s uses egg %s", id, tostring(character.EggModel))
		local asset = game.ReplicatedStorage.Assets.Eggs:FindFirstChild(character.EggModel)
		check(asset ~= nil, "%s: missing asset %s", id, character.EggModel)
		check(asset and asset:GetAttribute("Ornament") == EXPECTED_ORNAMENT[character.Rarity], "%s: built-in ornament %s for a %s", id, tostring(asset and asset:GetAttribute("Ornament")), character.Rarity)

		-- every size: shell sits on the ground and is the standard shell height
		for tier = 1, #Sizes.List do
			local egg = EggBuilder.Build({ CharacterId = id, SizeTier = tier, Color = 1 })
			local scale = Sizes.Get(tier).Scale
			local low = bounds(egg)
			check(near(low, 0, 0.03 * scale), "%s egg tier %d: bottom at %.3f", id, tier, low)
			local shellTop = -math.huge
			for _, part in parts(egg) do
				if part:GetAttribute("Tint") then
					shellTop = math.max(shellTop, part.Position.Y + part.Size.Y / 2)
				end
			end
			check(near(shellTop, EggBuilder.Height(tier), 0.03 * scale), "%s egg tier %d: shell top %.3f, expected %.3f", id, tier, shellTop, EggBuilder.Height(tier))
			egg:Destroy()
		end

		-- cosmetic colour tints the shell; built-in ornament replaces the procedural one
		for colorIndex = 1, #palette do
			local egg = EggBuilder.Build({ CharacterId = id, SizeTier = 3, Color = colorIndex })
			local expected = Color3.fromHex(palette[colorIndex])
			local tinted, matched = 0, 0
			for _, part in parts(egg) do
				if part:GetAttribute("Tint") == 1 then
					tinted += 1
					if near(part.Color.R, expected.R) and near(part.Color.G, expected.G) and near(part.Color.B, expected.B) then
						matched += 1
					end
				end
				check(not PROCEDURAL[part.Name], "%s egg: procedural ornament part %s added on top of the built-in one", id, part.Name)
			end
			check(tinted > 0 and matched == tinted, "%s egg colour %d: %d/%d shell parts tinted", id, colorIndex, matched, tinted)
			egg:Destroy()
		end

		local egg = EggBuilder.Build({ CharacterId = id, SizeTier = 3, Color = 2 })
		local orbiting = 0
		for _, child in egg:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("Orbit") then
				orbiting += 1
			end
		end
		local wantsOrbit = character.Rarity == "Cosmic" or id == "Hive"
		check((orbiting > 0) == wantsOrbit, "%s egg: %d orbiting parts", id, orbiting)
		check(CollectionService:HasTag(egg, "OrbitFX") == wantsOrbit, "%s egg: OrbitFX tag is %s", id, tostring(CollectionService:HasTag(egg, "OrbitFX")))
		egg:Destroy()

		-- an Awakened egg is one rarity up: the built-in ornament makes way for the right one
		local awakened = EggBuilder.Build({ CharacterId = id, SizeTier = 3, Color = 1, Awakened = true })
		local builtIn, procedural = 0, 0
		for _, part in parts(awakened) do
			if part:GetAttribute("OrnamentPart") then
				builtIn += 1
			end
			if PROCEDURAL[part.Name] or string.find(part.Name, "^Crack") then
				procedural += 1
			end
		end
		check(builtIn == 0 and procedural > 0, "%s awakened egg: %d built-in ornament parts, %d procedural", id, builtIn, procedural)
		awakened:Destroy()

		-- characters: feet on the ground, limb groups with joint pivots, scaling, effects
		local model = CharacterBuilder.Build(id)
		check(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Root", "%s: Root is the PrimaryPart", id)
		local low, high = bounds(model)
		check(near(low, -0.05, 0.03), "%s: feet at %.3f", id, low)
		check(high > 4.5 and high < 7, "%s: height %.2f studs", id, high - low)
		for _, group in { "Head", "Torso", "ArmR", "ArmL", "LegR", "LegL" } do
			local limb = model:FindFirstChild(group)
			check(limb ~= nil and limb:IsA("Model") and #limb:GetChildren() > 0, "%s: limb group %s", id, group)
		end
		check(CollectionService:HasTag(model, "OrbitFX") == (id == "Hive"), "%s: OrbitFX tag", id)
		model:Destroy()

		local big = CharacterBuilder.Build(id, { Scale = 1.5 })
		local bigLow, bigHigh = bounds(big)
		check(near(bigHigh - bigLow, (high - low) * 1.5, 0.05), "%s: Scale 1.5 gives %.2f studs", id, bigHigh - bigLow)
		big:Destroy()

		local golden = CharacterBuilder.Build(id, { Mutation = "Golden" })
		for _, part in parts(golden) do
			if part.Name == "EyeGlint" then
				check(near(part.Color.R, 1) and near(part.Color.G, 1) and near(part.Color.B, 1), "%s Golden: eye glint kept white", id)
			end
		end
		golden:Destroy()

		local silhouette = CharacterBuilder.Build(id, { Silhouette = true })
		for _, part in parts(silhouette) do
			if part.Transparency < 1 then
				check(part.Color.R < 0.1 and part.Color.G < 0.1 and part.Color.B < 0.1, "%s silhouette: %s not black", id, part.Name)
			end
		end
		silhouette:Destroy()
	end
end)

-- The Studio FBX import helper, fed a deliberately mangled "import" of every model (lying on
-- its back, facing backwards, scaled for inches and moved away), must put every piece back
-- exactly where the parts version has it, with the same limb groups, pivots and attributes.
local Art = require("./map/Art")
local helperSource = fs.readFile("assets/models/zone7/ImportFBX.lua")
local cut = string.find(helperSource, "--[[RUN]]", 1, true)
local module = roblox.Instance.new("ModuleScript")
module.Name = "ImportFBXCheck"
module.Source = string.sub(helperSource, 1, cut - 1) .. "\nreturn finish\n"
module.Parent = world.game:GetService("ServerStorage")
local finish = world:ServerRequire("ServerStorage.ImportFBXCheck")

local function tagsFor(part)
	local tags = {}
	if part:GetAttribute("Orbit") then
		table.insert(tags, "Orbit")
	end
	local hex = string.upper(string.sub(part.Color:ToHex(), 1, 6))
	if part.Material == roblox.Enum.Material.Neon then
		table.insert(tags, "Neon_" .. hex)
	elseif part.Material == roblox.Enum.Material.Glass then
		table.insert(tags, string.format("Glass_%s_%02d", hex, math.round(part.Transparency * 100)))
	end
	local tint = part:GetAttribute("Tint")
	if tint then
		table.insert(tags, string.format("Tint_%03d", math.round(tint * 100)))
	end
	return table.concat(tags, "_")
end

local function boxKey(part)
	local half = part.Size / 2
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local p = part.CFrame * (half * Vector3.new(x, y, z))
				lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
				hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
			end
		end
	end
	local function r(v) -- every voxel edge sits on the half-voxel grid
		local step = 0.1875 / 2
		return string.format("%d,%d,%d", math.round(v.X / step), math.round(v.Y / step), math.round(v.Z / step))
	end
	return r(lo) .. "|" .. r(hi)
end

local MANGLE = CFrame.new(40, 10, -25) * CFrame.Angles(math.rad(-90), math.rad(180), 0)
local SCALE = 2.54

for _, entry in Art.List() do
	local reference = Art.Build(entry.data)
	local expected = {}
	local fake = roblox.Instance.new("Model")
	fake.Name = entry.name
	for _, part in reference:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			table.insert(expected, boxKey(part))
			local group = if part.Parent ~= reference then part.Parent.Name
				elseif part:GetAttribute("OrnamentPart") then "Ornament"
				elseif part:GetAttribute("Orbit") and entry.data.kind ~= "Egg" then "Drones"
				else "Egg"
			local tags = tagsFor(part)
			local piece = part:Clone()
			piece.Name = if tags == "" then group else group .. "__" .. tags
			piece.Color = roblox.Color3.new(0.6, 0.6, 0.6) -- the importer's grey
			piece.Material = roblox.Enum.Material.Plastic
			piece.Transparency = 0
			for key in piece:GetAttributes() do
				piece:SetAttribute(key, nil)
			end
			piece.Size *= SCALE
			piece.CFrame = MANGLE * (CFrame.new(part.CFrame.Position * SCALE) * part.CFrame.Rotation)
			piece.Parent = fake
		end
	end
	local lo, hi = Vector3.new(entry.data.bounds[1][1], entry.data.bounds[1][2], entry.data.bounds[1][3]), Vector3.new(entry.data.bounds[2][1], entry.data.bounds[2][2], entry.data.bounds[2][3])
	local center = (lo + hi) / 2
	for name, offset in { FrontMarker = Vector3.new(0, 0, lo.Z - center.Z - 1), TopMarker = Vector3.new(0, hi.Y - center.Y + 1, 0) } do
		local marker = roblox.Instance.new("Part")
		marker.Name = name
		marker.Size = Vector3.one * 0.1875 * SCALE
		marker.CFrame = MANGLE * CFrame.new((center + offset) * SCALE)
		marker.Parent = fake
	end
	fake.Parent = world.game:GetService("Workspace")
	world:Server(function()
		local model = game.Workspace:FindFirstChild(entry.name)
		check(finish(model) == true, "%s: import helper refused the model", entry.name)
		local folderName = if entry.data.kind == "Egg" then "Eggs" else "Characters"
		local placed = game.ReplicatedStorage.Assets[folderName]:FindFirstChild(entry.name)
		check(placed == model, "%s: imported model not moved into Assets.%s", entry.name, folderName)
		check(game.ServerStorage.Unsorted:FindFirstChild(entry.name .. "_Parts") ~= nil, "%s: parts version not kept", entry.name)
		local got = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "Root" then
				table.insert(got, boxKey(part))
			end
		end
		table.sort(expected)
		table.sort(got)
		local same = #got == #expected
		for index = 1, math.min(#got, #expected) do
			if got[index] ~= expected[index] then
				same = false
				break
			end
		end
		check(same, "%s: imported pieces don't line up with the parts version (%s vs %s)", entry.name, tostring(got[1]), tostring(expected[1]))
		for _, group in entry.data.groups do
			local holder = model:FindFirstChild(group.name)
			if entry.data.kind ~= "Egg" and group.name ~= "Drones" then
				local pivot = holder and holder:GetPivot().Position
				check(pivot and near(pivot.X, group.pivot[1], 0.01) and near(pivot.Y, group.pivot[2], 0.01) and near(pivot.Z, group.pivot[3], 0.01), "%s: %s pivot %s", entry.name, group.name, tostring(pivot))
			end
		end
		if entry.data.kind == "Egg" then
			check(model:GetAttribute("Ornament") == entry.data.attributes.Ornament, "%s: Ornament attribute", entry.name)
			check(near(model:GetPivot().Position.Y, entry.data.attributes.ShellHeight / 2, 0.01), "%s: egg pivot", entry.name)
		else
			check(model.PrimaryPart and model.PrimaryPart.Name == "Root", "%s: Root", entry.name)
		end
		-- an imported egg still works with EggBuilder (tint + built-in ornament)
		if entry.data.kind == "Egg" then
			local characterId = string.sub(entry.name, 5)
			local egg = EggBuilder.Build({ CharacterId = characterId, SizeTier = 3, Color = 4 })
			local low = bounds(egg)
			check(near(low, 0, 0.03), "%s imported: egg bottom at %.3f", entry.name, low)
			egg:Destroy()
		end
	end)
end

for _, err in Emu.errors() do
	failures += 1
	print("script error: " .. string.sub(err, 1, 400))
end
print(string.format("%d/%d checks passed", checks - math.max(failures - #Emu.errors(), 0), checks))
if failures > 0 then
	error(failures .. " art checks failed")
end
