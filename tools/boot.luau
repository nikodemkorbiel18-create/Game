--!nocheck
-- Boot the built place headlessly with two players and report script errors.
local Emu = require("./emu")
local world = Emu.new({ place = "StealAChibi.rbxl", quiet = false })
world:StartServer()
world:Run(2)
local alice = world:AddPlayer("Alice", 101)
local bob = world:AddPlayer("Bob", 202)
world:Run(20)
for _, c in { alice, bob } do
	print(c.name, "attrs:")
	local attrs = c.real:GetAttributes()
	local keys = {}
	for k in attrs do table.insert(keys, k) end
	table.sort(keys)
	for _, k in keys do print("   ", k, attrs[k]) end
	print("  character at", c:Position(), "walkspeed", c:Humanoid().WalkSpeed)
	local guis = {}
	for _, g in c:Gui():GetChildren() do table.insert(guis, g.Name) end
	print("  gui:", table.concat(guis, ", "), "#desc", #c:GuiDescendants())
end
print("WorldEggs", #world:Tagged("WorldEgg"), "Guardians", #world:Tagged("Guardian"), "PenItems", #world:Tagged("PenItem"))
print(string.format("errors=%d warnings=%d", #Emu.errors(), #Emu.warnings()))
