--!nocheck
-- Brings the voxel art (assets/models/*/parts/*.json, made by tools/blender/build.py) into
-- the game without rebuilding the map:
--   1. every model is saved as assets/models/<set>/rbxm/<Model>.rbxm (drag into Studio)
--   2. StealAChibi.rbxl gets the freshly built code from src/ and the models in its asset
--      folders, replacing older copies. Nothing else in the place changes.
-- Usage: lune run tools/import-art [place]     (default StealAChibi.rbxl)
--        lune run tools/import-art --rbxm-only

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local rbx = require("./lib/rbx")
local C = require("./map/Common")
local Art = require("./map/Art")

local rbxmOnly = table.find(process.args, "--rbxm-only") ~= nil
local output = "StealAChibi.rbxl"
for _, arg in process.args do
	if string.sub(arg, 1, 2) ~= "--" then
		output = arg
	end
end

local entries = Art.List()
assert(#entries > 0, "No part layouts found in " .. Art.Root .. "/*/parts - run tools/blender/build.py first")
for _, entry in entries do
	local dir = Art.Root .. "/" .. entry.set .. "/rbxm"
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	fs.writeFile(dir .. "/" .. entry.name .. ".rbxm", roblox.serializeModel({ Art.Build(entry.data) }))
	print(string.format("  %-24s %4d parts -> %s/%s.rbxm", entry.name, entry.data.partCount, dir, entry.name))
end
if rbxmOnly then
	return
end

print("Building code...")
local env = rbx.load()
print("Updating " .. output .. "...")
local place = roblox.deserializePlace(fs.readFile(output))
C.transplantCode(env.game, place)
local count = Art.Insert(place)
fs.writeFile(output, roblox.serializePlace(place))
local check = roblox.deserializePlace(fs.readFile(output))
print(string.format("Done: %d voxel models, %d instances", count, #check:GetDescendants()))
