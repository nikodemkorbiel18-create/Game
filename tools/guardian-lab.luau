--!nocheck
-- Guardian balance lab (headless). For every zone: a player at exactly the zone's
-- recommended Speed grabs an egg while the Guardian stands D studs behind them, then runs
-- straight home. Reports escape/catch for Normal and Huge eggs at several distances.
-- Run: lune run tools/guardian-lab [--zones=1-11]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Emu = require("./emu")

local Vector3, CFrame = roblox.Vector3, require("./lib/cframe")

local firstZone, lastZone = 1, 11
local trace = table.find(process.args, "--trace") ~= nil
local onlyDistance = nil
for _, arg in process.args do
	onlyDistance = tonumber(string.match(arg, "^%-%-distance=(%d+)$")) or onlyDistance
	local a, b = string.match(arg, "^%-%-zones=(%d+)%-(%d+)$")
	if a then
		firstZone, lastZone = tonumber(a), tonumber(b)
	end
end

local world = Emu.new({ place = "StealAChibi.rbxl", quiet = true })
world:StartServer()
world:Run(1)
local player = world:AddPlayer("Runner", 777)
world:Run(4)

local Services = "ServerScriptService.Server.Services."
local DataService = world:ServerRequire(Services .. "DataService")
local SpeedService = world:ServerRequire(Services .. "SpeedService")
local EggSpawnService = world:ServerRequire(Services .. "EggSpawnService")
local GuardianService = world:ServerRequire(Services .. "GuardianService")
local CarryService = world:ServerRequire(Services .. "CarryService")
local Zones = world:ServerRequire("ReplicatedStorage.Shared.Config.Zones")
local GameSettings = world:ServerRequire("ReplicatedStorage.Shared.Config.GameSettings")

world:Server(function()
	local d = DataService.Get(player.player)
	d.BossCleared = true
	d.Tutorial.Done = true -- no new-player mercy for the test runner
	player.player:SetAttribute("BossCleared", true)
end)

local DISTANCES = { 12, 20, 30, 45, 70 }

local function trial(zoneId, rank, distance)
	local zone = Zones.Get(zoneId)
	-- reset the runner
	world:Server(function()
		if CarryService.IsCarrying(player.player) then
			CarryService.EndCarry(player.player)
		end
		local d = DataService.Get(player.player)
		d.Speed = zone.RecSpeed
		player.player:SetAttribute("StunnedUntil", 0)
		player.player:SetAttribute("SlowedUntil", 0)
		SpeedService.Apply(player.player)
	end)
	-- stage an egg
	-- always the same pedestal (index 1), refilled for every trial
	local pedestalPart = world:Server(function()
		local pedestal = EggSpawnService.Pedestal(zoneId, 1)
		if pedestal and not pedestal.Egg then
			EggSpawnService.ResetAll()
		end
		if pedestal and pedestal.Egg then
			pedestal.Egg.SizeTier = rank
			return pedestal.Part
		end
		return nil
	end)
	if not pedestalPart then
		return "no egg"
	end
	local pedestal = Emu.I.realOf(pedestalPart).CFrame.Position
	-- park the zone's Guardians behind the pedestal (away from home, which is +Z)
	local bounds = world:Server(function()
		local out
		for _, guardian in GuardianService.All() do
			if guardian.Zone.Id == zoneId then
				local spot = pedestal + Vector3.new(0, 3, -distance)
				guardian.Model:PivotTo(CFrame.new(spot))
				guardian.State = "Patrol"
				guardian.Target = nil
				guardian.PauseUntil = os.clock() + 1000
				guardian.FrozenUntil = os.clock() + 30 -- held still until the egg is grabbed
				guardian.BlindUntil = 0
				guardian.NextAbility = 0
				guardian.Awake = true
				guardian.Humanoid:MoveTo(spot)
				out = guardian.ZoneBounds
			end
		end
		return out
	end)
	local maxZ = if bounds then Emu.I.realOf(bounds).CFrame.Position.Z + Emu.I.realOf(bounds).Size.Z / 2 else pedestal.Z + 120
	player:StopWalking()
	player:Teleport(pedestal + Vector3.new(0, 3, 2.5))
	local rootState = Emu.I.states[player:Root()]
	if rootState and rootState.virtual then
		rootState.virtual.AssemblyLinearVelocity = nil
	end
	world:Run(0.1)
	local ok, why = player:HoldPrompt(Emu.I.wrap(Emu.I.realOf(pedestalPart):FindFirstChild("GrabPrompt")), GameSettings.GrabHoldTime + 0.05)
	if not ok or not player.real:GetAttribute("Carrying") then
		if os.getenv and false then
			print(why)
		end
		local stunned = world:Server(function()
			return SpeedService.IsStunned(player.player)
		end)
		return "no grab(" .. tostring(why or (if stunned then "stunned" else "?")) .. ")"
	end
	local ws = player:Humanoid().WalkSpeed
	-- release the Guardians already chasing and facing the thief (in real play they notice
	-- you as soon as you step into the nest, before the grab finishes)
	world:Server(function()
		for _, guardian in GuardianService.All() do
			if guardian.Zone.Id == zoneId then
				guardian.FrozenUntil = 0
				guardian.Target = player.player
				guardian.State = "Chase"
				guardian.StateSince = os.clock()
				guardian.ChaseStart = os.clock()
				guardian.LastDistance = math.huge
				guardian.LastPosition = nil
				local from = guardian.Root.Position
				guardian.Model:PivotTo(CFrame.lookAt(from, Vector3.new(pedestal.X, from.Y, pedestal.Z + 5)))
			end
		end
	end)
	local goal = Vector3.new(pedestal.X, pedestal.Y + 3, maxZ + GameSettings.Guardian.ReturnDistance + 15)
	local h = Emu.Physics.hstate(player:Humanoid())
	local deadline = world:Now() + 40
	while world:Now() < deadline do
		if not player.real:GetAttribute("Carrying") then
			return "CAUGHT", ws
		end
		local p = player:Position()
		if trace and math.floor(world:Now() * 5) ~= math.floor((world:Now() - world.dt) * 5) then
			local line = string.format("  t=%.1f runner z=%.0f y=%.1f", world:Now(), p.Z, p.Y)
			for _, g in world:Server(function()
				local out = {}
				for _, guardian in GuardianService.All() do
					if guardian.Zone.Id == zoneId then
						table.insert(out, { guardian.State, guardian.Root.Position, guardian.Humanoid.WalkSpeed })
					end
				end
				return out
			end) do
				line ..= string.format(" | %s z=%.0f y=%.1f ws=%.1f d=%.1f", g[1], g[2].Z, g[2].Y, g[3], (g[2] - p).Magnitude)
			end
			print(line)
		end
		if p.Z >= goal.Z - 1 then
			return "escaped", ws
		end
		h.moveTarget = goal
		h.moveStart = world:Now()
		world:Step()
	end
	return "timeout", ws
end

print("zone  guardianWS | Normal (player WS) by start distance | Huge (player WS) by start distance")
print("distances: " .. table.concat(DISTANCES, ", "))
for zoneId = firstZone, lastZone do
	local zone = Zones.Get(zoneId)
	local guardianWS = world:Server(function()
		for _, guardian in GuardianService.All() do
			if guardian.Zone.Id == zoneId then
				return math.max(GameSettings.Guardian.MinWalkSpeed, 0.8 * (16 + 7 * math.log10(1 + zone.RecSpeed)))
			end
		end
		return 0
	end)
	local line = string.format("%2d %-24s %5.1f |", zoneId, zone.Guardian.Ability.Type, guardianWS)
	for _, rank in { 3, 5 } do
		local ws
		local cells = {}
		for _, distance in (if onlyDistance then { onlyDistance } else DISTANCES) do
			local result, speed = trial(zoneId, rank, distance)
			ws = speed or ws
			table.insert(cells, if result == "escaped" then "ok" elseif result == "CAUGHT" then "XX" else result)
			-- cool down away from the nest so stuns and grace periods expire
			player:StopWalking()
			player:Teleport(Vector3.new(-20, 5, 718))
			world:Run(5)
		end
		line ..= string.format(" %s(%4.1f) %s |", if rank == 3 then "N" else "H", ws or 0, table.concat(cells, " "))
	end
	print(line)
end
print(string.format("script errors: %d", #Emu.Runtime.errors))
for _, e in Emu.Runtime.errors do
	print(string.sub(e, 1, 800))
end
