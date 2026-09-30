--!nocheck
-- Scripted playthrough against the real game scripts in the headless emulator.
-- Run: lune run tools/smoke [--verbose]
--
-- Each step drives fake players the way a person would (walking, holding prompts,
-- clicking UI, firing remotes) and checks server state. Any script error printed by the
-- game fails the run.

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Emu = require("./emu")

local Vector3, CFrame = roblox.Vector3, require("./lib/cframe")

local verbose = table.find(process.args, "--verbose") ~= nil
local only = nil
for _, arg in process.args do
	local name = string.match(arg, "^%-%-only=(.+)$")
	if name then
		only = name
	end
end

local world = Emu.new({ place = "StealAChibi.rbxl", quiet = not verbose })
local R = Emu.Runtime
local game = Emu.I.wrap(world.game) -- for code run inside client/server contexts

local results = {}
local function step(name, fn)
	if only and not string.find(string.lower(name), string.lower(only), 1, true) then
		return
	end
	local errorsBefore = #R.errors
	local ok, err = pcall(fn)
	local newErrors = #R.errors - errorsBefore
	if ok and newErrors == 0 then
		print("PASS  " .. name)
		table.insert(results, { name = name, ok = true })
	else
		print("FAIL  " .. name)
		if not ok then
			print("      " .. tostring(err))
		end
		for i = errorsBefore + 1, #R.errors do
			print("      script error: " .. string.sub(R.errors[i], 1, 600))
		end
		table.insert(results, { name = name, ok = false })
	end
end

local function check(condition, message, ...)
	if not condition then
		error(string.format(message, ...), 2)
	end
end

-- Somewhere in Station Plaza: outside every base and beyond zone 1's chase range
local PLAZA = Vector3.new(-20, 5, 718)

-- Server helpers ----------------------------------------------------------------------------

world:StartServer()
world:Run(1)

local Services = "ServerScriptService.Server.Services."
local DataService = world:ServerRequire(Services .. "DataService")
local PlotService = world:ServerRequire(Services .. "PlotService")
local CarryService = world:ServerRequire(Services .. "CarryService")

local function data(client)
	return world:Server(function()
		return DataService.Get(client.player)
	end)
end

local function plotOf(client)
	return world:Server(function()
		return PlotService.Get(client.player)
	end)
end

local function carrying(client)
	return client.real:GetAttribute("Carrying") == true
end

local function penCount(client)
	local n = 0
	for _ in data(client).Pen do
		n += 1
	end
	return n
end

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- A pedestal in `zoneId` with an egg on it (prompt enabled), nearest to `from`
local function eggPedestal(zoneId, from)
	local best, bestDistance = nil, math.huge
	for _, part in world:Tagged("EggPedestal") do
		local real = Emu.I.realOf(part)
		if real:GetAttribute("ZoneId") == zoneId then
			local prompt = real:FindFirstChild("GrabPrompt")
			if prompt and prompt.Enabled then
				local d = flat(real.CFrame.Position, from)
				if d < bestDistance then
					best, bestDistance = real, d
				end
			end
		end
	end
	return best
end

local function grabEgg(client, zoneId)
	-- like a player: if the Guardian gets you first, back off and try again
	for _ = 1, 4 do
		local pedestal = eggPedestal(zoneId, client:Position())
		check(pedestal, "no egg available in zone %d", zoneId)
		local target = pedestal.CFrame.Position + Vector3.new(0, 0, 3)
		check(client:WalkTo(target, 120), "%s could not walk to zone %d egg", client.name, zoneId)
		local ok = client:HoldPrompt(pedestal:FindFirstChild("GrabPrompt"), 0.6)
		world:Run(0.3)
		if ok and carrying(client) then
			return pedestal
		end
		client:WalkTo(PLAZA, 60)
		world:Run(5)
	end
	error(client.name .. " could not grab an egg in zone " .. zoneId)
end

-- Grab a zone 1 egg and carry it out to the plaza (retrying if a Guardian gets you)
local function grabToPlaza(client)
	for _ = 1, 4 do
		grabEgg(client, 1)
		client:WalkTo(PLAZA, 60)
		world:Run(0.3)
		if carrying(client) then
			return
		end
		world:Run(5)
	end
	error(client.name .. " could not carry an egg to the plaza")
end

local function goHome(client)
	local plot = plotOf(client)
	check(plot, "no plot")
	local floor = Emu.I.realOf(plot.Floor)
	check(client:WalkTo(floor.CFrame.Position + Vector3.new(0, 3, 0), 180), "%s could not walk home", client.name)
	world:Run(1)
end

-- Steps ---------------------------------------------------------------------------------------

local alice, bob

step("players join, load data and get a plot", function()
	alice = world:AddPlayer("Alice", 101)
	bob = world:AddPlayer("Bob", 202)
	world:Run(4)
	for _, c in { alice, bob } do
		check(c.real:GetAttribute("DataLoaded") == true, "%s data not loaded", c.name)
		check(type(c.real:GetAttribute("PlotId")) == "number", "%s has no plot", c.name)
		check(c:Root(), "%s has no character", c.name)
	end
	check(#world:Tagged("WorldEgg") > 50, "eggs did not spawn")
end)

step("HUD and tutorial are shown", function()
	check(alice:Gui():FindFirstChild("HUD"), "no HUD ScreenGui")
	check(#alice:FindText("SAKURA ACADEMY", true) > 0, "tutorial step 1 text not visible")
end)

local grabbedAt = 0
step("grab a zone 1 egg and carry it home", function()
	local before = penCount(alice)
	grabEgg(alice, 1)
	grabbedAt = world:Now()
	check(alice:Humanoid().WalkSpeed < 16, "carrying should slow the player (WalkSpeed %s)", alice:Humanoid().WalkSpeed)
	goHome(alice)
	check(not carrying(alice), "egg was not delivered")
	check(penCount(alice) == before + 1, "pen count did not increase")
end)

step("first egg hatches within the tutorial cap", function()
	local hatched = world:RunUntil(function()
		for _, item in data(alice).Pen do
			if item.Kind == "Character" then
				return true
			end
		end
		return false
	end, 20)
	check(hatched, "egg did not hatch within 20 s")
	world:Run(1)
	check(#alice:FindText("Tap to continue", false) + #alice:FindText("NEW", false) + #alice:FindText("CONTINUE", false) >= 0, "")
end)

step("income accrues and the collect plate pays out", function()
	world:Run(5)
	local d = data(alice)
	check(d.Register > 0, "register did not accumulate (Register=%s)", tostring(d.Register))
	local cashBefore = d.Cash
	local plot = plotOf(alice)
	local plate = Emu.I.realOf(plot.CollectPlate)
	check(alice:WalkTo(plate.CFrame.Position + Vector3.new(0, 3, 0), 30), "could not reach collect plate")
	world:Run(1)
	d = data(alice)
	check(d.Cash > cashBefore, "collect did not add cash (%s -> %s)", tostring(cashBefore), tostring(d.Cash))
	check(d.Cash >= 1000, "welcome gift missing (cash %s)", tostring(d.Cash))
end)

step("unlock the treadmill and train speed", function()
	local plot = plotOf(alice)
	local belt = Emu.I.realOf(plot.TreadmillBelt)
	local treadmill = Emu.I.realOf(plot.Treadmill)
	local prompt = treadmill:FindFirstChild("TreadmillPrompt", true)
	check(prompt, "no treadmill prompt")
	local promptPart = prompt.Parent
	check(alice:WalkTo(promptPart.CFrame.Position + Vector3.new(0, 0, 2), 30), "could not reach treadmill prompt")
	local ok, why = alice:HoldPrompt(prompt, prompt.HoldDuration + 0.1)
	check(ok, "treadmill prompt: %s", tostring(why))
	world:Run(0.5)
	check(data(alice).TreadmillTier >= 1, "treadmill not unlocked")
	local speedBefore = data(alice).Speed
	check(alice:WalkTo(belt.CFrame.Position + Vector3.new(0, 3, 0), 30), "could not reach belt")
	world:Run(6)
	check(data(alice).Speed > speedBefore, "speed did not increase on treadmill")
	check(alice:Humanoid().WalkSpeed > 16, "WalkSpeed did not increase")
end)

step("tutorial completes", function()
	world:Run(2)
	check(data(alice).Tutorial.Done == true, "tutorial not done (step %s)", tostring(data(alice).Tutorial.Step))
end)

local EggSpawnService = world:ServerRequire(Services .. "EggSpawnService")
local SpeedService = world:ServerRequire(Services .. "SpeedService")
local Zones = world:ServerRequire("ReplicatedStorage.Shared.Config.Zones")

local function admin(client, command, ...)
	local result = client:Invoke("Admin", command, ...)
	check(type(result) == "table" and result.Ok ~= false, "admin %s failed: %s", command, tostring(result and result.Message))
	return result
end

local function setSpeed(client, speed)
	world:Server(function()
		local d = DataService.Get(client.player)
		d.Speed = speed
		DataService.Changed(client.player, "Speed")
		SpeedService.Apply(client.player)
	end)
	world:Run(0.2)
end

-- Put an egg of the given size rank on a zone pedestal and return that pedestal's part
local function stageEgg(zoneId, rank)
	return world:Server(function()
		for index = 1, 8 do
			local pedestal = EggSpawnService.Pedestal(zoneId, index)
			if pedestal and pedestal.Egg then
				pedestal.Egg.SizeTier = rank
				return pedestal.Part
			end
		end
		return nil
	end)
end

local GuardianService = world:ServerRequire(Services .. "GuardianService")

-- Distance to the nearest Guardian of a zone that is NOT behind the position (home is +Z)
local function guardianDistance(zoneId, position)
	return world:Server(function()
		local best = math.huge
		for _, guardian in GuardianService.All() do
			if guardian.Zone.Id == zoneId then
				local p = guardian.Root.Position
				local behind = p.Z < position.Z - 5
				best = math.min(best, if behind then (p - position).Magnitude else 0)
			end
		end
		return best
	end)
end

local function runZone2(client, rank)
	local part = stageEgg(2, rank)
	check(part, "no zone 2 egg")
	local real = Emu.I.realOf(part)
	-- wait until the Guardian has patrolled away behind the nest, like a player timing their run
	client:Teleport(Vector3.new(-45, 5, 590))
	local clear = world:RunUntil(function()
		return guardianDistance(2, real.CFrame.Position) > 25
	end, 120)
	check(clear, "the zone 2 Guardian never moved behind the nest")
	local before = penCount(client)
	client:Teleport(real.CFrame.Position + Vector3.new(0, 3, 4))
	world:Run(0.2)
	local ok, why = client:HoldPrompt(real:FindFirstChild("GrabPrompt"), 0.6)
	check(ok, "grab: %s", tostring(why))
	world:Run(0.2)
	check(carrying(client), "not carrying the zone 2 egg")
	local walkSpeed = client:Humanoid().WalkSpeed
	-- run home around zone 1's nest
	client:WalkTo(Vector3.new(-45, 5, 600), 60)
	goHome(client)
	return penCount(client) > before, walkSpeed
end

step("guardian: at-speed Normal egg escapes, Huge egg is caught", function()
	setSpeed(alice, Zones.Get(2).RecSpeed)
	local escapedNormal, wsNormal = runZone2(alice, 3)
	world:Run(3)
	local escapedHuge, wsHuge = runZone2(alice, 5)
	print(string.format("      Normal egg (WalkSpeed %.1f): %s; Huge egg (WalkSpeed %.1f): %s", wsNormal, if escapedNormal then "escaped" else "caught", wsHuge, if escapedHuge then "escaped" else "caught"))
	check(escapedNormal, "at-speed player with a Normal egg was caught")
	check(not escapedHuge, "at-speed player with a Huge egg escaped")
end)

step("admin: egg reset and Secret spawn announcement", function()
	local seen = false
	local conn = alice:Do(function()
		local remote = game:GetService("ReplicatedStorage").Remotes.Announce
		return remote.OnClientEvent:Connect(function(payload)
			local text = if type(payload) == "table" then payload.Text else payload
			if type(text) == "string" and string.find(string.upper(text), "SECRET") then
				seen = true
			end
		end)
	end)
	admin(alice, "ResetEggs")
	admin(alice, "SpawnEgg", 9, "Secret", nil)
	world:Run(1)
	conn:Disconnect()
	check(seen, "no Secret announcement reached the client")
	check(#world:Tagged("WorldEgg") >= 80, "eggs missing after reset")
end)

step("snatch: another player steals a carried egg", function()
	setSpeed(bob, 1000)
	grabToPlaza(alice)
	local root = alice:Root()
	local snatch = alice:Character():FindFirstChild("SnatchPrompt", true)
	check(snatch, "no snatch prompt on the carrier")
	bob:Teleport(root.CFrame.Position + Vector3.new(3, 0, 0))
	alice:StopWalking()
	world:Run(0.2)
	local ok, why = bob:HoldPrompt(snatch, 1.05)
	check(ok, "snatch prompt: %s", tostring(why))
	world:Run(0.3)
	check(carrying(bob) and not carrying(alice), "snatch did not transfer the egg (alice %s, bob %s)", tostring(carrying(alice)), tostring(carrying(bob)))
	goHome(bob)
	check(not carrying(bob), "bob did not deliver the snatched egg")
end)

step("slap: Harisen knocks the egg out of a carrier's hands", function()
	grabToPlaza(alice)
	alice:StopWalking()
	local root = alice:Root()
	local pos = root.CFrame.Position
	world:Run(1.5)
	-- stand 4 studs away facing Alice
	local from = pos + Vector3.new(4, 0, 0)
	Emu.Classes.setPartCFrame(bob:Root(), CFrame.lookAt(from, pos))
	world:Run(0.1)
	bob:Fire("Slap")
	world:Run(0.5)
	check(not carrying(alice), "Alice still carries after being slapped")
	-- the dropped egg can be picked up
	local dropped
	for _, d in world.workspace:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.ActionText == "Grab" and d.Enabled then
			dropped = d
		end
	end
	check(dropped, "no pickup prompt for the dropped egg")
	world:Run(1.6)
	local part = dropped.Parent
	bob:Teleport(part.CFrame.Position + Vector3.new(2, 1, 0))
	world:Run(0.1)
	local ok, why = bob:HoldPrompt(dropped, dropped.HoldDuration + 0.1)
	check(ok, "pickup: %s", tostring(why))
	world:Run(0.3)
	check(carrying(bob), "Bob did not pick up the dropped egg")
	goHome(bob)
end)

step("raid: steal from a pen, theft alert, ownership on delivery", function()
	admin(alice, "EndShield")
	goHome(alice)
	world:Run(1)
	local d = data(alice)
	local slotIndex, item
	for key, it in d.Pen do
		slotIndex, item = tonumber(key), it
		break
	end
	check(slotIndex, "Alice has nothing in her pen")
	local plot = plotOf(alice)
	local slot = Emu.I.realOf(plot.Slots[slotIndex])
	local alerts = 0
	local conn = alice:Do(function()
		return game:GetService("ReplicatedStorage").Remotes.TheftAlert.OnClientEvent:Connect(function()
			alerts += 1
		end)
	end)
	bob:Teleport(slot.CFrame.Position + Vector3.new(0, 3, 3))
	world:Run(0.3)
	local ok, why = bob:HoldPrompt(slot:FindFirstChild("SlotPrompt"), 1.6)
	check(ok, "slot prompt: %s", tostring(why))
	world:Run(0.5)
	conn:Disconnect()
	check(carrying(bob), "Bob is not carrying Alice's chibi")
	check(alerts > 0, "Alice got no theft alert")
	check(data(alice).Pen[tostring(slotIndex)] == nil, "item still in Alice's pen")
	local bobBefore = penCount(bob) + #data(bob).Inventory
	goHome(bob)
	check(penCount(bob) + #data(bob).Inventory == bobBefore + 1, "stolen chibi did not reach Bob")
end)

step("barrier lock pushes raiders out and has a cooldown", function()
	local plot = plotOf(alice)
	local button = Emu.I.realOf(plot.BarrierButton)
	alice:Teleport(button.CFrame.Position + Vector3.new(0, 3, 2))
	bob:Teleport(Emu.I.realOf(plot.Floor).CFrame.Position + Vector3.new(5, 3, 5))
	world:Run(0.3)
	local ok, why = alice:HoldPrompt(button:FindFirstChild("BarrierPrompt"), 0.1)
	check(ok, "barrier prompt: %s", tostring(why))
	world:Run(1.5)
	local WorldLib = world:ServerRequire("ServerScriptService.Server.Lib.World")
	local inside = world:Server(function()
		local p = PlotService.Get(alice.player)
		return WorldLib.InsideFootprint(bob.player.Character.HumanoidRootPart.Position, p.Floor, 60, 0)
	end)
	check(not inside, "Bob is still inside Alice's base after Barrier Lock")
end)

step("anti-exploit: short holds, slap spam, bad remote arguments", function()
	-- instant trigger (no hold) on an egg must be rejected
	local pedestal = eggPedestal(1, alice:Position())
	alice:Teleport(pedestal.CFrame.Position + Vector3.new(0, 3, 3))
	world:Run(0.3)
	alice:HoldPrompt(pedestal:FindFirstChild("GrabPrompt"), 0.05)
	world:Run(0.2)
	check(not carrying(alice), "an instant trigger grabbed the egg")
	for _ = 1, 20 do
		bob:Fire("Slap")
	end
	for _, args in {
		{ "Shop", "Trail", 12345 },
		{ "Shop", "Item", "OfudaTrap", 1e9 },
		{ "Shop", { "table" } },
		{ "Inventory", "Place", string.rep("x", 500), -1 },
		{ "Sell", "notalist" },
		{ "Fusion", "Awaken", { 1, 2, 3 } },
		{ "Index", "Claim", nil },
		{ "Rebirth", "Confirm", "keep" },
		{ "RedeemCode", string.rep("A", 5000) },
		{ "Incubator", "Start", {} },
	} do
		local result = bob:Invoke(table.unpack(args))
		check(type(result) == "table", "%s returned %s", args[1], typeof(result))
	end
	bob:Fire("PlaceTrap", "junk", 1, 2)
	bob:Fire("TutorialAction", { nested = true })
	world:Run(1)
end)

step("economy: pen upgrade, items, trails, index, codes, login reward", function()
	admin(alice, "GiveCash", 1e12)
	world:Run(0.5)
	local penBefore = data(alice).PenLevel
	local r = alice:Invoke("Shop", "Pen")
	check(r.Ok, "pen upgrade: %s", tostring(r.Error))
	check(data(alice).PenLevel == penBefore + 1, "pen level did not increase")
	r = alice:Invoke("Shop", "Item", "OfudaTrap", 2)
	check(r.Ok, "buy traps: %s", tostring(r.Error))
	r = alice:Invoke("Shop", "Trail", "SakuraPetals")
	check(r.Ok or r.Error, "trail purchase returned nothing")
	r = alice:Invoke("Index", "ClaimAll")
	check(type(r) == "table", "index claim-all failed")
	r = alice:Invoke("LoginReward", "Claim")
	check(type(r) == "table", "login reward failed")
	r = alice:Invoke("RedeemCode", "NOTACODE")
	check(r.Ok == false, "bad code was accepted")
end)

step("inventory, equip best, sell and fusion", function()
	admin(alice, "GiveCharacter", "KohanaNineTail", 3, nil, false)
	admin(alice, "GiveCharacter", "KohanaNineTail", 3, nil, false)
	admin(alice, "GiveCharacter", "KohanaNineTail", 3, nil, false)
	world:Run(0.5)
	local r = alice:Invoke("Inventory", "EquipBest")
	check(type(r) == "table", "equip best failed")
	local d = data(alice)
	local uids = {}
	for _, item in d.Pen do
		if item.CharacterId == "KohanaNineTail" and item.Kind == "Character" and not item.Awakened then
			table.insert(uids, item.Uid)
		end
	end
	for _, item in d.Inventory do
		if item.CharacterId == "KohanaNineTail" and item.Kind == "Character" and not item.Awakened then
			table.insert(uids, item.Uid)
		end
	end
	check(#uids >= 3, "expected 3 copies, found %d", #uids)
	local pod = Emu.I.realOf(world:Tagged("FusionPod")[1])
	local podPosition = if pod:IsA("BasePart") then pod.CFrame.Position else Emu.Classes.modelPivot(pod).Position
	alice:Teleport(podPosition + Vector3.new(0, 3, 6))
	world:Run(0.3)
	r = alice:Invoke("Fusion", "Awaken", { uids[1], uids[2], uids[3] })
	check(r.Ok, "awaken: %s", tostring(r.Error))
	world:Run(125)
	r = alice:Invoke("Fusion", "Claim", 1)
	check(r.Ok, "claim fusion: %s", tostring(r.Error))
	local awakened = false
	for _, item in data(alice).Inventory do
		awakened = awakened or item.Awakened == true
	end
	for _, item in data(alice).Pen do
		awakened = awakened or item.Awakened == true
	end
	check(awakened, "no awakened chibi after fusion")
	-- sell something from the inventory
	local sellUid
	for _, item in data(alice).Inventory do
		if not item.Protected and not item.Awakened then
			sellUid = item.Uid
		end
	end
	if sellUid then
		local counter = Emu.I.realOf(world:Tagged("SellCounter")[1])
		local counterPosition = if counter:IsA("BasePart") then counter.CFrame.Position else Emu.Classes.modelPivot(counter).Position
		alice:Teleport(counterPosition + Vector3.new(0, 3, 6))
		world:Run(0.3)
		local cash = data(alice).Cash
		r = alice:Invoke("Sell", { sellUid }, true)
		check(r.Ok, "sell: %s", tostring(r.Error))
		check(data(alice).Cash > cash, "selling did not pay")
	end
end)

local function snapshot(client)
	local d = data(client)
	return { Cash = d.Cash, Speed = d.Speed, Pen = penCount(client), Inventory = #d.Inventory, Tier = d.TreadmillTier, PenLevel = d.PenLevel }
end

step("dying while carrying drops the egg; respawn keeps the HUD", function()
	grabToPlaza(alice)
	local humanoid = alice:Humanoid()
	world:Server(function()
		Emu.I.wrap(humanoid).Health = 0
	end)
	world:Run(1)
	check(not carrying(alice), "still carrying after dying")
	local died = alice:Character()
	check(world:RunUntil(function()
		return alice:Character() ~= died and alice:Root() ~= nil
	end, 10), "no respawn")
	world:Run(2)
	check(alice:Gui():FindFirstChild("HUD"), "HUD missing after respawn")
	local plot = plotOf(alice)
	local floor = Emu.I.realOf(plot.Floor)
	local position = alice:Position()
	check(flat(position, floor.CFrame.Position) < 60, "respawned away from the base (%.0f studs)", flat(position, floor.CFrame.Position))
end)

step("rejoin restores saved data", function()
	world:Run(2)
	local before = snapshot(alice)
	world:RemovePlayer(alice)
	world:Run(3)
	alice = world:AddPlayer("Alice", 101)
	world:Run(5)
	check(alice.real:GetAttribute("DataLoaded"), "data did not load on rejoin")
	local after = snapshot(alice)
	for key, value in before do
		if key == "Cash" then
			check(after.Cash >= value, "cash lost on rejoin (%s -> %s)", tostring(value), tostring(after.Cash))
		else
			check(after[key] == value, "%s changed on rejoin (%s -> %s)", key, tostring(value), tostring(after[key]))
		end
	end
end)

step("thief leaving mid-raid returns the chibi to its owner", function()
	admin(alice, "EndShield")
	goHome(alice)
	local d = data(alice)
	local slotIndex
	for key in d.Pen do
		slotIndex = tonumber(key)
		break
	end
	check(slotIndex, "Alice has an empty pen")
	local ownerCount = penCount(alice) + #data(alice).Inventory
	local plot = plotOf(alice)
	local slot = Emu.I.realOf(plot.Slots[slotIndex])
	bob:Teleport(slot.CFrame.Position + Vector3.new(0, 3, 3))
	world:Run(0.3)
	bob:HoldPrompt(slot:FindFirstChild("SlotPrompt"), 1.6)
	world:Run(0.3)
	check(carrying(bob), "raid did not start")
	world:RemovePlayer(bob)
	world:Run(2)
	check(penCount(alice) + #data(alice).Inventory == ownerCount, "chibi was not returned (had %d, now %d)", ownerCount, penCount(alice) + #data(alice).Inventory)
	bob = world:AddPlayer("Bob", 202)
	world:Run(5)
end)

step("owner leaving mid-raid keeps the chibi in their saved pen", function()
	admin(alice, "EndShield")
	goHome(alice)
	local slotIndex
	for key in data(alice).Pen do
		slotIndex = tonumber(key)
		break
	end
	check(slotIndex, "Alice has an empty pen")
	local ownerCount = penCount(alice) + #data(alice).Inventory
	local plot = plotOf(alice)
	local slot = Emu.I.realOf(plot.Slots[slotIndex])
	bob:Teleport(slot.CFrame.Position + Vector3.new(0, 3, 3))
	world:Run(0.3)
	bob:HoldPrompt(slot:FindFirstChild("SlotPrompt"), 1.6)
	world:Run(0.3)
	check(carrying(bob), "raid did not start")
	world:RemovePlayer(alice)
	world:Run(2)
	check(not carrying(bob), "Bob still carries the chibi of a player who left")
	alice = world:AddPlayer("Alice", 101)
	world:Run(5)
	check(penCount(alice) + #data(alice).Inventory == ownerCount, "Alice lost the chibi (had %d, now %d)", ownerCount, penCount(alice) + #data(alice).Inventory)
end)

step("events start and stop from the admin panel", function()
	for _, id in { "Matsuri", "SakuraStorm", "EclipseHour", "DoubleGrowth" } do
		admin(alice, "StartEvent", id, 1, false)
		world:Run(2)
		admin(alice, "StopEvent", id)
		world:Run(1)
	end
end)

step("gauntlet gate, admin clear, Sacred Tree incubator", function()
	setSpeed(alice, 5e9)
	admin(alice, "TeleportZone", 11)
	world:Run(1)
	check(alice:Position().Z > -445, "an uncleared player got into zone 11 (z=%.1f)", alice:Position().Z)
	admin(alice, "ClearBoss")
	world:Run(0.5)
	check(data(alice).BossCleared, "ClearBoss did not clear the gauntlet")
	admin(alice, "GiveCharacter", "KohanaNineTail", 3, nil, true)
	world:Run(0.5)
	-- move the egg from the pen to the inventory, then carry it up to the incubator
	for key, item in data(alice).Pen do
		if item.Kind == "Egg" then
			local stored = alice:Invoke("Inventory", "Store", tonumber(key))
			check(stored.Ok, "store egg: %s", tostring(stored.Error))
		end
	end
	local uid
	for _, item in data(alice).Inventory do
		if item.Kind == "Egg" then
			uid = item.Uid
		end
	end
	check(uid, "no egg in inventory")
	goHome(alice)
	local r = alice:Invoke("Inventory", "Carry", uid)
	check(r.Ok, "carry from inventory: %s", tostring(r.Error))
	admin(alice, "TeleportZone", 11)
	world:Run(1)
	local incubator = world:Tagged("SacredIncubator")[1]
	check(incubator, "no Sacred Incubator")
	local incubatorReal = Emu.I.realOf(incubator)
	local position = if incubatorReal:IsA("BasePart") then incubatorReal.CFrame.Position else Emu.Classes.modelPivot(incubatorReal).Position
	alice:Teleport(position + Vector3.new(0, 3, 8))
	world:Run(1)
	check(alice:Position().Z < -600, "cleared player was sent back from zone 11 (z=%.1f)", alice:Position().Z)
	local quote = alice:Invoke("Incubator", "Quote")
	check(type(quote) == "table", "no incubator quote")
	r = alice:Invoke("Incubator", "Start")
	check(r.Ok, "incubator start: %s", tostring(r.Error))
	world:Run(62)
	r = alice:Invoke("Incubator", "Claim", 1)
	check(r.Ok, "incubator claim: %s", tostring(r.Error))
end)

step("rebirth resets and keeps the right things", function()
	goHome(alice) -- deliver whatever the incubator step left in her hands
	admin(alice, "GiveCash", 2e6)
	admin(alice, "GiveCharacter", "KohanaNineTail", 3, nil, false)
	world:Run(0.5)
	local preview = alice:Invoke("Rebirth", "Preview")
	check(type(preview) == "table", "no rebirth preview")
	local indexBefore = 0
	for _ in data(alice).Index do
		indexBefore += 1
	end
	local trailsBefore = data(alice).OwnedTrails
	local r = alice:Invoke("Rebirth", "Confirm")
	check(r.Ok, "rebirth: %s", tostring(r.Error or r.Message))
	world:Run(1)
	local d = data(alice)
	check(d.Rebirths == 1, "rebirth count %s", tostring(d.Rebirths))
	check(d.Speed == 0 and d.TreadmillTier == 0 and d.PenLevel == 1, "speed/treadmill/pen not reset")
	check(not d.BossCleared, "gauntlet clear not reset")
	local indexAfter = 0
	for _ in d.Index do
		indexAfter += 1
	end
	check(indexAfter == indexBefore, "index changed on rebirth")
	for trail in trailsBefore do
		check(d.OwnedTrails[trail], "lost trail %s", trail)
	end
end)

step("every sidebar window opens and closes", function()
	local hud = alice:Gui():FindFirstChild("HUD")
	local opened = 0
	for _, d in Emu.I.descendants(hud, alice.ctx) do
		if d:IsA("TextButton") and d.Name == "Button" and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "Sidebar" then
			local key = d.Parent.Name
			alice:Click(d)
			world:Run(0.3)
			local windows = alice:Gui():FindFirstChild("Windows")
			local frame = windows and windows:FindFirstChild(key)
			if frame then
				check(frame.Visible, "window %s did not open", key)
				opened += 1
				alice:Click(frame:FindFirstChild("TitleBar"):FindFirstChild("Close"))
				world:Run(0.3)
				check(not frame.Visible, "window %s did not close", key)
			end
		end
	end
	check(opened >= 6, "only %d sidebar windows opened", opened)
end)

step("phone-sized player: HUD fits a 844x390 screen", function()
	local viewport = roblox.Vector2.new(844, 390)
	local phone = world:AddPlayer("Phone", 303, { viewport = viewport, input = { TouchEnabled = true, KeyboardEnabled = false, MouseEnabled = false } })
	world:Run(5)
	local offenders = {}
	for _, gui in phone:Gui():GetChildren() do
		local scale = gui:FindFirstChild("AutoScale")
		local s = if scale then scale.Scale else 1
		if gui:IsA("ScreenGui") and gui.Enabled then
			-- a UIScale on a ScreenGui lays children out on a (viewport / scale) canvas and
			-- then scales that canvas down to the screen
			phone.ctx.viewport = viewport / s
			for _, d in Emu.I.children(gui, phone.ctx) do
				if d:IsA("GuiObject") and d.Visible then
					local R = Emu.Runtime
					local previous = R.ctx
					R.ctx = phone.ctx
					local proxy = Emu.I.wrap(d)
					local pos = proxy.AbsolutePosition * s
					local size = proxy.AbsoluteSize * s
					R.ctx = previous
					if pos.X < -2 or pos.Y < -2 or pos.X + size.X > viewport.X + 2 or pos.Y + size.Y > viewport.Y + 2 then
						table.insert(offenders, string.format("%s.%s (%d,%d %dx%d)", gui.Name, d.Name, pos.X, pos.Y, size.X, size.Y))
					end
				end
			end
			phone.ctx.viewport = viewport
		end
	end
	world:RemovePlayer(phone)
	check(#offenders == 0, "off-screen at 844x390: %s", table.concat(offenders, "; "))
end)

step("shutdown saves every profile", function()
	admin(alice, "GiveCash", 12345)
	world:Run(0.5)
	local cash = data(alice).Cash
	check(world:Shutdown(), "BindToClose did not finish")
	local store
	for key, value in Emu.Shared.dataStores do
		if string.find(key, "StealAChibi_Profiles") then
			store = value
		end
	end
	check(store, "no profile store was written")
	local entry = store.entries["Player_101"] or store.entries["101"]
	if not entry then
		for key, value in store.entries do
			if string.find(key, "101") then
				entry = value
			end
		end
	end
	check(entry, "Alice's profile key not found")
	local saved = Emu.Services.jsonDecode(entry.text)
	local savedCash = saved.Data and saved.Data.Cash
	check(savedCash == cash, "saved cash %s ~= %s", tostring(savedCash), tostring(cash))
end)

-- Summary --------------------------------------------------------------------------------------

local failed = 0
for _, r in results do
	if not r.ok then
		failed += 1
	end
end
print(string.format("\n%d/%d steps passed, %d script errors, %d warnings (%.0f s simulated)", #results - failed, #results, #R.errors, #R.warnings, world:Now()))
if #R.warnings > 0 then
	local seen = {}
	for _, w in R.warnings do
		local key = string.gsub(w, "^%[.-%]%[.-%] ", "")
		if not seen[key] then
			seen[key] = true
			print("  " .. string.sub(w, 1, 300))
		end
	end
end
process.exit(if failed == 0 and #R.errors == 0 then 0 else 1)
