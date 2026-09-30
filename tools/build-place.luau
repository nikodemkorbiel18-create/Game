--!nocheck
-- Builds StealAChibi.rbxl from the base map (assets/base-map.rbxl) plus all code in src/.
--   1. rojo builds the code into build/code.rbxl
--   2. the base map is loaded; code folders are transplanted into it
--   3. existing art is organized, gameplay fixtures and placeholder zones are generated
--   4. the finished place is written to StealAChibi.rbxl
-- Usage: lune run tools/build-place [lastZone]   (lastZone defaults to 11)

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local rbx = require("./lib/rbx")
local C = require("./map/Common")
local Plots = require("./map/Plots")
local Plaza = require("./map/Plaza")
local ZonesMap = require("./map/Zones")
local Gauntlet = require("./map/Gauntlet")

local lastZone = tonumber(process.args[1]) or 11
local output = process.args[2] or "StealAChibi.rbxl"

print("Building code...")
local env = rbx.load()
local ZonesConfig = env.require("ReplicatedStorage/Shared/Config/Zones")
local code = env.game

print("Loading base map...")
local place = roblox.deserializePlace(fs.readFile("assets/base-map.rbxl"))
local ws = place:GetService("Workspace")
local replicated = place:GetService("ReplicatedStorage")
local serverStorage = place:GetService("ServerStorage")
local serverScripts = place:GetService("ServerScriptService")
local starterPlayer = place:GetService("StarterPlayer")

local function transplant(fromParent, name, toParent)
	local child = fromParent:FindFirstChild(name)
	assert(child, "missing " .. name .. " in built code")
	local old = toParent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	child.Parent = toParent
end

transplant(code:GetService("ReplicatedStorage"), "Shared", replicated)
transplant(code:GetService("ServerScriptService"), "Server", serverScripts)
local codeStarterScripts = code:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local starterScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
transplant(codeStarterScripts, "Client", starterScripts)

-- Asset folders (artists drop real models here to replace placeholders)
local assetsReplicated = C.folder("Assets", replicated)
C.folder("Characters", assetsReplicated)
local eggAssets = C.folder("Eggs", assetsReplicated)
local assetsServer = C.folder("Assets", serverStorage)
local guardianAssets = C.folder("Guardians", assetsServer)
local unused = C.folder("Unsorted", serverStorage)

print("Organizing existing models...")
local map = C.folder("Map", ws)
local zonesFolder = C.folder("Zones", map)

local function move(instance, parent, newName)
	if instance then
		if newName then
			instance.Name = newName
		end
		instance.Parent = parent
		return true
	end
	return false
end

-- prop palette -> ServerStorage.Assets.Props
local props = ws:FindFirstChild("Models")
if props and props:IsA("Folder") then
	move(props, assetsServer, "Props")
end

-- guardians -> ServerStorage.Assets.Guardians
move(ws:FindFirstChild("HallMonitor"), guardianAssets)
local ramenWrapper = ws:FindFirstChild("RamenMaster")
if ramenWrapper then
	local inner = ramenWrapper:FindFirstChild("RamenMaster")
	if inner then
		move(inner, guardianAssets)
		ramenWrapper:Destroy()
	else
		move(ramenWrapper, guardianAssets)
	end
end

-- zone 3 mesh egg -> ReplicatedStorage.Assets.Eggs
local eggWrapper = ws:FindFirstChild("Egg_Zone3_Blocky")
if eggWrapper then
	local inner = eggWrapper:FindFirstChild("Egg_Zone3")
	if inner then
		move(inner, eggAssets)
		eggWrapper:Destroy()
	end
end

-- zone art
local function zoneArtFolder(zoneId)
	local zone = ZonesConfig.Get(zoneId)
	local folder = C.folder(string.format("Zone%02d_%s", zone.Id, zone.Key), zonesFolder)
	return C.folder("Art", folder)
end
local schoolArt = zoneArtFolder(1)
for _, child in ws:GetChildren() do
	if child.Name == "LeftWall_Classrooms" or child.Name == "RightWall_Windows" then
		move(child, schoolArt)
	elseif child.Name == "RightWall_Glass_Optional" then
		local center = C.center(child)
		if center.Z > 550 and center.Z < 700 then
			move(child, schoolArt)
		else
			move(child, unused)
		end
	elseif child:IsA("BasePart") and child.Name == "Part" and math.abs(child.Size.X - 114.2) < 0.5 and math.abs(child.CFrame.Position.Z - 623.2) < 2 then
		move(child, schoolArt, "SchoolFloor")
	end
end
move(ws:FindFirstChild("RamenStreet_AllInOne"), zoneArtFolder(2))
move(ws:FindFirstChild("KitsuneShrine_AllInOne"), zoneArtFolder(3))

print("Adding plot fixtures...")
print("  plots: " .. Plots.Build(ws))

print("Building Station Plaza...")
Plaza.Build(map)

print("Building zones 1-" .. lastZone .. "...")
for zoneId = 1, math.min(lastZone, 10) do
	ZonesMap.BuildZone(zonesFolder, ZonesConfig.Get(zoneId), ZonesMap.Layouts[zoneId])
end
if lastZone >= 11 then
	Gauntlet.Build(map, zonesFolder, ZonesConfig, ZonesMap)
end
ZonesMap.BuildBoundaries(map, lastZone)

-- Server settings
pcall(function()
	place:GetService("Players").MaxPlayers = 5
end)
pcall(function()
	place:GetService("Players").PreferredPlayers = 5
end)
ws.StreamingEnabled = true

print("Writing " .. output .. "...")
fs.writeFile(output, roblox.serializePlace(place))
local check = roblox.deserializePlace(fs.readFile(output))
print(string.format("Done: %d instances", #check:GetDescendants()))
