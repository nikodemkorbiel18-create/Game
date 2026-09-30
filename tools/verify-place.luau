--!nocheck
-- Sanity checks for a built place: tag counts, plot orientation, required assets.
-- Usage: lune run tools/verify-place [file]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local file = process.args[1] or "StealAChibi.rbxl"
local place = roblox.deserializePlace(fs.readFile(file))
local counts = {}
for _, d in place:GetDescendants() do
	for _, tag in d:GetTags() do
		counts[tag] = (counts[tag] or 0) + 1
	end
end
local names = {}
for tag in counts do
	table.insert(names, tag)
end
table.sort(names)
for _, tag in names do
	print(string.format("  %-18s %d", tag, counts[tag]))
end
for _, base in place:GetService("Workspace"):GetChildren() do
	if base:HasTag("Plot") then
		print(string.format("  %s PlotId=%s entrance=%s", base.Name, tostring(base:GetAttribute("PlotId")), tostring(base:GetAttribute("EntranceSide"))))
	end
end
local rs = place:GetService("ReplicatedStorage")
local ss = place:GetService("ServerStorage")
print("  Shared modules:", #rs.Shared:GetDescendants())
print("  Server scripts:", #place:GetService("ServerScriptService").Server:GetDescendants())
print("  Client scripts:", #place:GetService("StarterPlayer").StarterPlayerScripts.Client:GetDescendants())
for _, folder in { rs.Assets.Eggs, ss.Assets.Guardians } do
	for _, child in folder:GetChildren() do
		print("  asset:", folder:GetFullName() .. "." .. child.Name)
	end
end
