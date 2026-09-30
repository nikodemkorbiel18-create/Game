--!nocheck
-- Can the Heavenly Gatekeeper gauntlet be beaten, and does it punish players who ignore it?
-- A "careful" bot reads the same deterministic hazard math the client draws from
-- (Util/Gauntlet) and jumps shockwave rings, falling petals and the sweeping staff.
-- A "careless" bot just runs. Run: lune run tools/gauntlet-bot

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Emu = require("./emu")

local Vector3 = roblox.Vector3
local R = Emu.Runtime

local world = Emu.new({ place = "StealAChibi.rbxl", quiet = true })
world:StartServer()
world:Run(1)

local Services = "ServerScriptService.Server.Services."
local DataService = world:ServerRequire(Services .. "DataService")
local SpeedService = world:ServerRequire(Services .. "SpeedService")
local Zones = world:ServerRequire("ReplicatedStorage.Shared.Config.Zones")
local Endgame = world:ServerRequire("ReplicatedStorage.Shared.Config.Endgame")
local GauntletMath = world:ServerRequire("ReplicatedStorage.Shared.Util.Gauntlet")
local boss = Endgame.Boss

local function tagged(tag)
	local out = {}
	for _, proxy in world:Tagged(tag) do
		table.insert(out, Emu.I.realOf(proxy))
	end
	return out
end

local areas = {}
for _, part in tagged("GauntletArea") do
	areas[part:GetAttribute("Phase")] = {
		part = part,
		origin = Vector3.new(part:GetAttribute("OriginX"), part:GetAttribute("OriginY"), part:GetAttribute("OriginZ")),
		floorY = part:GetAttribute("FloorY"),
	}
end
local start = tagged("GauntletStart")[1]
local finish = tagged("GauntletFinish")[1]
assert(start and finish and areas[1] and areas[2] and areas[3], "gauntlet parts missing")

local function inside(part, position, margin)
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local BossService = world:ServerRequire(Services .. "BossService")

local function makeRunner(name, userId)
	local client = world:AddPlayer(name, userId)
	world:Run(4)
	world:Server(function()
		local d = DataService.Get(client.player)
		d.Speed = Zones.Get(11).RecSpeed
		SpeedService.Apply(client.player)
	end)
	-- petals announced by the server (the client draws the same warning circles)
	local petals = {}
	client:Do(function()
		Emu.I.wrap(world.game).ReplicatedStorage.Remotes.Effect.OnClientEvent:Connect(function(effect)
			if type(effect) == "table" and effect.Type == "Petals" then
				for _, position in effect.Positions do
					table.insert(petals, { position = position, impact = effect.ImpactAt, radius = effect.Radius })
				end
			end
		end)
	end)
	return { client = client, petals = petals, name = name }
end

local function attempt(runner, careful)
	local client, petals, name = runner.client, runner.petals, runner.name
	world:Server(function()
		BossService.ResetClear(client.player)
	end)
	client:StopWalking()
	local startPos = start.CFrame.Position
	client:Teleport(startPos + Vector3.new(0, 3, 12))
	world:Run(0.5 + math.random() * 3)
	local humanoid = client:Humanoid()
	local h = Emu.Physics.hstate(humanoid)
	local goal = finish.CFrame.Position + Vector3.new(0, 3, 0)
	local jumps = 0
	local deadline = world:Now() + 60
	local maxHits = 0
	local started = false
	while world:Now() < deadline do
		local root = client:Root()
		if not root then
			break
		end
		local position = root.CFrame.Position
		local inRun = client.real:GetAttribute("InGauntlet") == true
		started = started or inRun
		maxHits = math.max(maxHits, client.real:GetAttribute("GauntletHits") or 0)
		if client.real:GetAttribute("BossCleared") then
			break
		end
		if started and not inRun then
			break -- knocked back to the start: failed
		end
		if careful and not h.jumpStart then
			local now = world:Now() + R.epoch
			local soon = now + 0.12
			local danger = false
			local a1, a2, a3 = areas[1], areas[2], areas[3]
			if inside(a1.part, position, 2) then
				local distance = Vector3.new(position.X - a1.origin.X, 0, position.Z - a1.origin.Z).Magnitude
				for _, radius in GauntletMath.ShockwaveRadii(soon) do
					if math.abs(distance - radius) < boss.Shockwave.Thickness + 2 then
						danger = true
					end
				end
			elseif inside(a2.part, position, 2) then
				for _, petal in petals do
					local dt = petal.impact - now
					if dt > -0.05 and dt < 0.2 and Vector3.new(position.X - petal.position.X, 0, position.Z - petal.position.Z).Magnitude < petal.radius + 2 then
						danger = true
					end
				end
			elseif inside(a3.part, position, 2) then
				if GauntletMath.StaffDistance(soon, a3.origin, position) < boss.Staff.Thickness / 2 + 3 then
					danger = true
				end
			end
			if danger and Emu.Physics.startJump(humanoid) then
				jumps += 1
			end
		end
		h.moveTarget = goal
		h.moveStart = world:Now()
		world:Step()
	end
	local cleared = client.real:GetAttribute("BossCleared") == true
	client:StopWalking()
	return cleared, maxHits, jumps
end

local ATTEMPTS = tonumber(process.env.GAUNTLET_ATTEMPTS or "") or 8
local results = {}
for _, spec in { { "Careful", 901, true }, { "Careless", 902, false } } do
	local runner = makeRunner(spec[1], spec[2])
	local clears, hits = 0, 0
	for _ = 1, ATTEMPTS do
		local cleared, maxHits = attempt(runner, spec[3])
		if cleared then
			clears += 1
		end
		hits += maxHits
	end
	results[spec[1]] = { clears = clears, hits = hits }
	world:RemovePlayer(runner.client)
end
print(string.format("careful bot:  cleared %d/%d (avg %.1f hits)", results.Careful.clears, ATTEMPTS, results.Careful.hits / ATTEMPTS))
print(string.format("careless bot: cleared %d/%d (avg %.1f hits)", results.Careless.clears, ATTEMPTS, results.Careless.hits / ATTEMPTS))
print(string.format("script errors: %d", #R.errors))
for _, e in R.errors do
	print(string.sub(e, 1, 800))
end
local ok = results.Careful.clears >= ATTEMPTS * 0.75 and results.Careless.clears <= ATTEMPTS * 0.25 and #R.errors == 0
process.exit(if ok then 0 else 1)
