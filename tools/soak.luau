--!nocheck
-- Soak test: five bots play at once for a while (grabbing, delivering, collecting,
-- training, buying, slapping, raiding, joining and leaving). Any script error fails.
-- Run: lune run tools/soak [--minutes=15] [--seed=1] [--verbose]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Emu = require("./emu")

local Vector3, CFrame = roblox.Vector3, require("./lib/cframe")
local R = Emu.Runtime
local I = Emu.I

local minutes, seed, verbose = 15, 1, false
for _, arg in process.args do
	minutes = tonumber(string.match(arg, "^%-%-minutes=(.+)$")) or minutes
	seed = tonumber(string.match(arg, "^%-%-seed=(.+)$")) or seed
	verbose = verbose or arg == "--verbose"
end

local world = Emu.new({ place = "StealAChibi.rbxl", quiet = not verbose, seed = seed })
world:StartServer()
world:Run(1)
local rng = Emu.Random.new(seed)
local game = I.wrap(world.game)

local Services = "ServerScriptService.Server.Services."
local DataService = world:ServerRequire(Services .. "DataService")
local PlotService = world:ServerRequire(Services .. "PlotService")
local Zones = world:ServerRequire("ReplicatedStorage.Shared.Config.Zones")

local stats = { grabs = 0, deliveries = 0, collects = 0, raids = 0, slaps = 0, purchases = 0, rejoins = 0, trains = 0 }

local function data(bot)
	local d = nil
	local done = false
	R.spawnIn(Emu.Shared.server, function()
		d = DataService.Get(bot.client.player)
		done = true
	end)
	return d
end

local function plot(bot)
	local p = nil
	R.spawnIn(Emu.Shared.server, function()
		p = PlotService.Get(bot.client.player)
	end)
	return p
end

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Non-blocking remote call from a bot
local function invoke(bot, name, ...)
	local args = table.pack(...)
	R.spawnIn(bot.client.ctx, function()
		local remote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer(table.unpack(args, 1, args.n))
		else
			remote:FireServer(table.unpack(args, 1, args.n))
		end
	end)
end

local mine = function(bot)
	return function(c)
		return c == Emu.Shared.server or c == bot.client.ctx
	end
end

local function beginHold(bot, prompt)
	local pps = world.game:GetService("ProximityPromptService")
	local proxy = I.wrap(prompt)
	I.fireTo(pps, "PromptButtonHoldBegan", mine(bot), proxy, bot.client.player)
	I.fireTo(prompt, "PromptButtonHoldBegan", mine(bot), bot.client.player)
end

local function endHold(bot, prompt)
	local pps = world.game:GetService("ProximityPromptService")
	local proxy = I.wrap(prompt)
	I.fireTo(pps, "PromptTriggered", mine(bot), proxy, bot.client.player)
	I.fireTo(prompt, "Triggered", mine(bot), bot.client.player)
	I.fireTo(prompt, "TriggerEnded", mine(bot), bot.client.player)
end

local bots = {}

local function newBot(name, userId)
	local client = world:AddPlayer(name, userId)
	local bot = { name = name, userId = userId, client = client, task = nil, nextThink = 0 }
	table.insert(bots, bot)
	return bot
end

local function setTask(bot, t)
	bot.task = t
	t.started = world:Now()
end

-- Tasks: each has a target to walk to, then an action
local function eggTask(bot)
	local d = data(bot)
	if not d then
		return nil
	end
	local maxZone = 1
	for id = 1, 10 do
		if d.Speed >= Zones.Get(id).RecSpeed * 0.8 then
			maxZone = id
		end
	end
	local zoneId = rng:NextInteger(1, maxZone)
	local choices = {}
	for _, part in world:Tagged("EggPedestal") do
		local real = I.realOf(part)
		local prompt = real:FindFirstChild("GrabPrompt")
		if real:GetAttribute("ZoneId") == zoneId and prompt and prompt.Enabled then
			table.insert(choices, real)
		end
	end
	if #choices == 0 then
		return nil
	end
	local pedestal = choices[rng:NextInteger(1, #choices)]
	return {
		kind = "grab",
		target = pedestal.CFrame.Position + Vector3.new(0, 0, 3),
		prompt = pedestal:FindFirstChild("GrabPrompt"),
		hold = 0.6,
	}
end

local function homeTask(bot)
	local p = plot(bot)
	if not p then
		return nil
	end
	return { kind = "home", target = I.realOf(p.Floor).CFrame.Position + Vector3.new(rng:NextNumber(-10, 10), 3, rng:NextNumber(-10, 10)) }
end

local function collectTask(bot)
	local p = plot(bot)
	if not p or not p.CollectPlate then
		return nil
	end
	return { kind = "collect", target = I.realOf(p.CollectPlate).CFrame.Position + Vector3.new(0, 3, 0) }
end

local function trainTask(bot)
	local p = plot(bot)
	if not p or not p.TreadmillBelt then
		return nil
	end
	local d = data(bot)
	if d and d.TreadmillTier < 1 then
		local prompt = I.realOf(p.Treadmill):FindFirstChild("TreadmillPrompt", true)
		return { kind = "buyTreadmill", target = prompt.Parent.CFrame.Position + Vector3.new(0, 0, 2), prompt = prompt, hold = 0.4 }
	end
	return { kind = "train", target = I.realOf(p.TreadmillBelt).CFrame.Position + Vector3.new(0, 3, 0), duration = rng:NextNumber(8, 25) }
end

local function raidTask(bot)
	local victims = {}
	for _, other in bots do
		if other ~= bot and not other.left then
			local d = data(other)
			local p = plot(other)
			if d and p then
				for key in d.Pen do
					table.insert(victims, { slot = p.Slots[tonumber(key)] })
				end
			end
		end
	end
	if #victims == 0 then
		return nil
	end
	local pick = victims[rng:NextInteger(1, #victims)]
	local slot = I.realOf(pick.slot)
	return { kind = "raid", target = slot.CFrame.Position + Vector3.new(0, 3, 3), prompt = slot:FindFirstChild("SlotPrompt"), hold = 1.6 }
end

local function think(bot)
	local client = bot.client
	if not client:Root() or not client.real:GetAttribute("DataLoaded") then
		return
	end
	if client.real:GetAttribute("Carrying") then
		setTask(bot, homeTask(bot) or { kind = "wait", duration = 1 })
		return
	end
	local roll = rng:NextNumber()
	local t
	if roll < 0.45 then
		t = eggTask(bot)
	elseif roll < 0.6 then
		t = collectTask(bot)
	elseif roll < 0.75 then
		t = trainTask(bot)
	elseif roll < 0.85 then
		t = raidTask(bot)
	else
		local d = data(bot)
		if d then
			local choice = rng:NextInteger(1, 4)
			if choice == 1 then
				invoke(bot, "Shop", "Pen")
			elseif choice == 2 then
				invoke(bot, "Shop", "Treadmill")
			elseif choice == 3 then
				invoke(bot, "Inventory", "EquipBest")
			else
				invoke(bot, "Index", "ClaimAll")
			end
			stats.purchases += 1
		end
		t = { kind = "wait", duration = 1 }
	end
	setTask(bot, t or { kind = "wait", duration = 1 })
end

local function tryAct(bot)
	local t = bot.task
	local client = bot.client
	if t.kind == "wait" then
		if world:Now() - t.started >= t.duration then
			bot.task = nil
		end
		return
	end
	local root = client:Root()
	local humanoid = client:Humanoid()
	if not root or not humanoid then
		bot.task = nil
		return
	end
	if world:Now() - t.started > 90 then
		bot.task = nil -- stuck
		return
	end
	if t.holding then
		if world:Now() - t.holdStart >= t.hold then
			endHold(bot, t.prompt)
			if t.kind == "grab" then
				stats.grabs += 1
			elseif t.kind == "raid" then
				stats.raids += 1
			end
			bot.task = nil
		end
		return
	end
	local h = Emu.Physics.hstate(humanoid)
	if flat(root.CFrame.Position, t.target) > 1.2 then
		h.moveTarget = t.target
		h.moveStart = world:Now()
		return
	end
	h.moveTarget = nil
	if t.kind == "grab" or t.kind == "raid" or t.kind == "buyTreadmill" then
		if not t.prompt or not t.prompt.Parent then
			bot.task = nil
			return
		end
		t.holding = true
		t.holdStart = world:Now()
		beginHold(bot, t.prompt)
	elseif t.kind == "home" then
		stats.deliveries += 1
		bot.task = { kind = "wait", duration = 1.5, started = world:Now() }
	elseif t.kind == "collect" then
		stats.collects += 1
		bot.task = { kind = "wait", duration = 1, started = world:Now() }
	elseif t.kind == "train" then
		stats.trains += 1
		bot.task = { kind = "wait", duration = t.duration, started = world:Now() }
	end
end

-- Slap a nearby carrier now and then
local function maybeSlap(bot)
	local root = bot.client:Root()
	if not root or bot.client.real:GetAttribute("Carrying") then
		return
	end
	for _, other in bots do
		if other ~= bot and not other.left and other.client.real:GetAttribute("Carrying") then
			local otherRoot = other.client:Root()
			if otherRoot and (otherRoot.CFrame.Position - root.CFrame.Position).Magnitude < 7 and rng:NextNumber() < 0.3 then
				Emu.Classes.setPartCFrame(root, CFrame.lookAt(root.CFrame.Position, otherRoot.CFrame.Position))
				invoke(bot, "Slap")
				stats.slaps += 1
				return
			end
		end
	end
end

for i = 1, 5 do
	newBot("Bot" .. i, 1000 + i)
	world:Run(0.5)
end
world:Run(5)
-- give bots a head start so they spread across zones
for index, bot in bots do
	R.spawnIn(Emu.Shared.server, function()
		local d = DataService.Get(bot.client.player)
		if d then
			d.Speed = ({ 0, 300, 2000, 10000, 60000 })[index]
			d.Cash += 5000
		end
	end)
end

local total = minutes * 60
local lastReport = 0
while world:Now() < total do
	for _, bot in bots do
		if not bot.left then
			if not bot.task then
				think(bot)
			else
				tryAct(bot)
			end
			maybeSlap(bot)
		end
	end
	-- occasional leave / rejoin
	if rng:NextNumber() < 0.0008 then
		local bot = bots[rng:NextInteger(1, #bots)]
		if not bot.left then
			world:RemovePlayer(bot.client)
			bot.left = true
			bot.leftAt = world:Now()
		end
	end
	for _, bot in bots do
		if bot.left and world:Now() - bot.leftAt > 10 then
			bot.client = world:AddPlayer(bot.name, bot.userId)
			bot.left = false
			bot.task = nil
			stats.rejoins += 1
		end
	end
	world:Step()
	if world:Now() - lastReport >= 60 then
		lastReport = world:Now()
		print(string.format("[%4.0fs] errors=%d grabs=%d deliveries=%d collects=%d raids=%d slaps=%d buys=%d rejoins=%d", world:Now(), #R.errors, stats.grabs, stats.deliveries, stats.collects, stats.raids, stats.slaps, stats.purchases, stats.rejoins))
	end
end

world:Shutdown()
print(string.format("\nSoak finished: %.0f s simulated, %d script errors, %d warnings", world:Now(), #R.errors, #R.warnings))
local seen = {}
for _, line in R.errors do
	local key = string.sub(string.gsub(line, "^%[.-%]%[.-%] ", ""), 1, 200)
	if not seen[key] then
		seen[key] = true
		print(string.sub(line, 1, 1500))
	end
end
for _, line in R.warnings do
	local key = string.sub(string.gsub(line, "^%[.-%]%[.-%] ", ""), 1, 120)
	if not seen[key] then
		seen[key] = true
		print(string.sub(line, 1, 400))
	end
end
process.exit(if #R.errors == 0 then 0 else 1)
