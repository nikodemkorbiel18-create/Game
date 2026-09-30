--!strict
-- Guardian AI. Same core behaviour for every zone:
--   IDLE (at nest) -> PATROL (tagged waypoints) -> ALERT ("!", 0.4s windup) -> CHASE ->
--   CATCH (egg teleports home, knockback + 1.5s ragdoll, "CAUGHT!") or RETURN.
-- Guardians only chase players carrying an egg from THEIR nest, or standing inside the nest
-- radius. Chasing uses Humanoid:MoveTo every 0.1s and switches to PathfindingService only
-- when blocked for more than 0.5s. Flavour abilities are toggled in Config/Zones.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Tags = require(Shared.Config.Tags)
local Zones = require(Shared.Config.Zones)
local Formulas = require(Shared.Util.Formulas)

local SpeedService = require(script.Parent.SpeedService)
local PlotService = require(script.Parent.PlotService)
local CarryService = require(script.Parent.CarryService)
local EggSpawnService = require(script.Parent.EggSpawnService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local World = require(script.Parent.Parent.Lib.World)
local GuardianBuilder = require(script.Parent.Parent.Lib.GuardianBuilder)

type State = "Idle" | "Patrol" | "Alert" | "Chase" | "Return" | "Frozen"

type Guardian = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Zone: Zones.Zone,
	ZoneBounds: BasePart?,
	NestCenter: Vector3,
	NestRadius: number,
	Spawn: CFrame,
	Waypoints: { Vector3 },
	WaypointIndex: number,
	State: State,
	StateSince: number,
	Target: Player?,
	ChaseStart: number,
	PauseUntil: number,
	LastDistance: number,
	LastPosition: Vector3?,
	BlockedSince: number?,
	Path: { Vector3 }?,
	PathIndex: number,
	PathUntil: number,
	FrozenUntil: number,
	BlindUntil: number,
	NextAbility: number,
	BurstUntil: number,
	BurstMultiplier: number,
	Awake: boolean,
	AlertGui: BillboardGui,
}

local GuardianService = {}

local guardians: { Guardian } = {}
local folder: Folder

local function zoneBounds(zoneId: number): BasePart?
	for _, part in World.TaggedParts(Tags.Zone) do
		if part:GetAttribute("ZoneId") == zoneId then
			return part
		end
	end
	return nil
end

local function nestFor(zoneId: number): (Vector3?, number)
	for _, part in World.TaggedParts(Tags.Nest) do
		if part:GetAttribute("ZoneId") == zoneId then
			local radius = part:GetAttribute("Radius")
			return part.Position, (if type(radius) == "number" then radius else 10) + 8
		end
	end
	return nil, GameSettings.Guardian.NestRadius
end

local function waypointsFor(zoneId: number): { Vector3 }
	local list = {}
	for _, part in World.TaggedParts(Tags.GuardianWaypoint) do
		if part:GetAttribute("ZoneId") == zoneId then
			table.insert(list, part)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Order") :: number) < (b:GetAttribute("Order") :: number)
	end)
	local points = {}
	for _, part in list do
		table.insert(points, part.Position)
	end
	return points
end

local function makeAlertGui(model: Model): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "AlertGui"
	gui.Size = UDim2.fromOffset(90, 90)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.Text = "!"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = model.PrimaryPart
	return gui
end

local function setState(guardian: Guardian, state: State)
	if guardian.State == state then
		return
	end
	guardian.State = state
	guardian.StateSince = os.clock()
	guardian.Model:SetAttribute("State", state)
	guardian.AlertGui.Enabled = state == "Alert" or state == "Chase"
	local label = guardian.AlertGui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = if state == "Frozen" then "zZ" else "!"
		label.TextColor3 = if state == "Frozen" then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(255, 60, 60)
	end
	if state == "Frozen" then
		guardian.AlertGui.Enabled = true
	end
	if state ~= "Chase" and state ~= "Alert" then
		guardian.Target = nil
		guardian.Path = nil
	end
end

local function baseSpeed(guardian: Guardian): number
	return Formulas.GuardianWalkSpeed(guardian.Zone.Id)
end

local function applySpeed(guardian: Guardian, multiplier: number)
	local now = os.clock()
	local speed = baseSpeed(guardian) * multiplier
	if guardian.BurstUntil > now then
		speed *= guardian.BurstMultiplier
	end
	if guardian.FrozenUntil > now then
		speed = 0
	end
	guardian.Humanoid.WalkSpeed = speed
end

local function inBounds(guardian: Guardian, position: Vector3, extra: number): boolean
	local bounds = guardian.ZoneBounds
	if not bounds then
		return (position - guardian.NestCenter).Magnitude < 120 + extra
	end
	local localPoint = bounds.CFrame:PointToObjectSpace(position)
	local half = bounds.Size / 2
	return math.abs(localPoint.X) <= half.X + extra and math.abs(localPoint.Z) <= half.Z + extra and math.abs(localPoint.Y) <= half.Y + extra
end

-- Is this player a valid target for this guardian?
-- After a catch, Guardians leave that player alone for a moment so a knocked-back player
-- can recover instead of being caught again every tick.
local graceUntil: { [Player]: number } = {}

local function isTarget(guardian: Guardian, player: Player): boolean
	local root = World.Root(player)
	if not root or not World.Humanoid(player) then
		return false
	end
	if (graceUntil[player] or 0) > os.clock() then
		return false
	end
	if PlotService.PlotAt(root.Position) then
		return false
	end
	if player:GetAttribute("Carrying") and player:GetAttribute("CarryOrigin") == "Wild" and player:GetAttribute("CarryZone") == guardian.Zone.Id then
		return inBounds(guardian, root.Position, GameSettings.Guardian.ReturnDistance)
	end
	if guardian.Zone.Guardian.Ability.Type == "Statue" and guardian.Zone.Guardian.Ability.Enabled and not guardian.Awake then
		return false
	end
	local radius = guardian.NestRadius * guardian.Zone.Guardian.DetectRadiusMult
	return (root.Position - guardian.NestCenter).Magnitude <= radius
end

local function findTarget(guardian: Guardian): Player?
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		if isTarget(guardian, player) then
			local position = World.Position(player) :: Vector3
			local distance = (position - guardian.Root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function catch(guardian: Guardian, player: Player)
	local playerRoot = World.Root(player)
	if not playerRoot then
		return
	end
	local carryingOurs = player:GetAttribute("Carrying") and player:GetAttribute("CarryZone") == guardian.Zone.Id
	if carryingOurs then
		CarryService.KnockOut(player)
	end
	local direction = (playerRoot.Position - guardian.Root.Position) * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		direction = guardian.Root.CFrame.LookVector
	end
	SpeedService.Stun(player, GameSettings.Guardian.RagdollTime)
	graceUntil[player] = os.clock() + GameSettings.Guardian.CatchGrace
	Remote.Fire("Knockback", player, { Direction = direction.Unit, Force = GameSettings.Guardian.KnockbackForce, Duration = GameSettings.Guardian.RagdollTime })
	Remote.FireAll("Effect", { Type = "Caught", UserId = player.UserId, Guardian = guardian.Zone.Guardian.DisplayName })
	setState(guardian, "Return")
end

local function useAbility(guardian: Guardian, target: Player, now: number)
	local ability = guardian.Zone.Guardian.Ability
	if not ability.Enabled then
		return
	end
	local targetPosition = World.Position(target)
	if not targetPosition then
		return
	end
	local distance = (targetPosition - guardian.Root.Position).Magnitude
	local kind = ability.Type
	if kind == "PetalField" then
		if distance <= (ability.Radius or 25) then
			SpeedService.ApplySlow(target, "PetalField", ability.Multiplier or 0.8, 0.35)
		end
		return
	end
	if kind == "Mech" then
		local toTarget = (targetPosition - guardian.Root.Position) * Vector3.new(1, 0, 1)
		local facing = guardian.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local straight = toTarget.Magnitude > 0.1 and facing.Magnitude > 0.1 and toTarget.Unit:Dot(facing.Unit) > 0.9
		guardian.BurstMultiplier = if straight then (ability.Multiplier or 1.25) else 0.85
		guardian.BurstUntil = now + 0.2
		return
	end
	if now < guardian.NextAbility then
		return
	end
	local interval = ability.Interval or 10
	if kind == "NoodleSplash" then
		if distance <= (ability.Radius or 30) then
			SpeedService.ApplySlow(target, "NoodleSplash", ability.Multiplier or 0.6, ability.Duration or 2)
			Remote.FireAll("Effect", { Type = "Splash", Position = targetPosition, Color = "#FFE8B6" })
			guardian.NextAbility = now + interval
		end
	elseif kind == "SprintBurst" or kind == "Charge" then
		guardian.BurstUntil = now + (ability.Duration or 1.5)
		guardian.BurstMultiplier = ability.Multiplier or 1.5
		guardian.NextAbility = now + interval
		Remote.FireAll("Effect", { Type = "Burst", Position = guardian.Root.Position })
	elseif kind == "Blink" then
		local toTarget = (targetPosition - guardian.Root.Position) * Vector3.new(1, 0, 1)
		if toTarget.Magnitude > 6 then
			local step = math.min(ability.Distance or 10, toTarget.Magnitude - 4)
			local destination = guardian.Root.Position + toTarget.Unit * step
			guardian.Model:PivotTo(CFrame.lookAt(destination, destination + toTarget.Unit))
			Remote.FireAll("Effect", { Type = "Blink", Position = destination })
			guardian.NextAbility = now + interval
		end
	elseif kind == "BatSwarm" then
		if distance <= (ability.Radius or 35) then
			SpeedService.ApplySlow(target, "BatSwarm", ability.Multiplier or 0.7, ability.Duration or 3)
			Remote.FireAll("Effect", { Type = "Bats", Position = targetPosition })
			guardian.NextAbility = now + interval
		end
	end
end

local function moveTo(guardian: Guardian, position: Vector3)
	guardian.Humanoid:MoveTo(position)
end

local function computePath(guardian: Guardian, destination: Vector3)
	local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 7, AgentCanJump = true, WaypointSpacing = 6 })
	local ok = pcall(function()
		path:ComputeAsync(guardian.Root.Position, destination)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local points = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
		guardian.Path = points
		guardian.PathIndex = 2
		guardian.PathUntil = os.clock() + 2.5
	end
end

local function chase(guardian: Guardian, now: number)
	local target = guardian.Target
	if not target or target.Parent ~= Players then
		setState(guardian, "Return")
		return
	end
	local root = World.Root(target)
	if not root or not isTarget(guardian, target) or now - guardian.ChaseStart > GameSettings.Guardian.MaxChaseTime or now < guardian.BlindUntil then
		setState(guardian, "Return")
		return
	end
	local distance = (root.Position - guardian.Root.Position).Magnitude
	if distance <= GameSettings.Guardian.CatchRadius then
		catch(guardian, target)
		return
	end
	useAbility(guardian, target, now)
	applySpeed(guardian, 1)
	-- blocked detection -> pathfinding fallback. "Blocked" means the Guardian itself barely
	-- moved since the last tick; a target simply outrunning it is not an obstacle.
	local position = guardian.Root.Position
	local lastPosition = guardian.LastPosition
	local expected = guardian.Humanoid.WalkSpeed * GameSettings.Guardian.ChaseTick
	if lastPosition and expected > 0 and World.FlatDistance(position, lastPosition) < expected * 0.25 then
		guardian.BlockedSince = guardian.BlockedSince or now
	else
		guardian.BlockedSince = nil
	end
	guardian.LastPosition = position
	guardian.LastDistance = distance
	local path = guardian.Path
	if path and now < guardian.PathUntil and guardian.PathIndex <= #path then
		local waypoint = path[guardian.PathIndex]
		if (waypoint - guardian.Root.Position).Magnitude < 4 then
			guardian.PathIndex += 1
		end
		moveTo(guardian, path[math.min(guardian.PathIndex, #path)])
		return
	end
	guardian.Path = nil
	local blockedSince = guardian.BlockedSince
	if blockedSince and now - blockedSince > GameSettings.Guardian.RepathBlockedTime and guardian.Zone.Guardian.Ability.Type ~= "Phase" then
		guardian.BlockedSince = nil
		task.spawn(computePath, guardian, root.Position)
	end
	moveTo(guardian, root.Position)
end

local function patrol(guardian: Guardian, now: number)
	applySpeed(guardian, 0.55)
	if now < guardian.PauseUntil then
		return
	end
	if #guardian.Waypoints == 0 then
		moveTo(guardian, guardian.NestCenter)
		return
	end
	local point = guardian.Waypoints[guardian.WaypointIndex]
	if World.FlatDistance(point, guardian.Root.Position) < 3 then
		guardian.WaypointIndex = guardian.WaypointIndex % #guardian.Waypoints + 1
		guardian.PauseUntil = now + GameSettings.Guardian.PatrolPause
		if guardian.WaypointIndex == 1 then
			setState(guardian, "Idle")
			guardian.PauseUntil = now + 3
		end
		return
	end
	moveTo(guardian, point)
end

local function tick(guardian: Guardian, now: number)
	local model = guardian.Model
	if model.Parent == nil then
		return
	end
	if guardian.Root.Position.Y < guardian.NestCenter.Y - 40 then
		guardian.Model:PivotTo(guardian.Spawn)
		setState(guardian, "Idle")
	end
	if guardian.FrozenUntil > now then
		setState(guardian, "Frozen")
		applySpeed(guardian, 0)
		guardian.Humanoid:MoveTo(guardian.Root.Position)
		return
	elseif guardian.State == "Frozen" then
		setState(guardian, "Return")
	end
	local ability = guardian.Zone.Guardian.Ability
	local statue = ability.Type == "Statue" and ability.Enabled
	if statue and guardian.Awake and now - guardian.StateSince > (ability.Duration or 5) and guardian.State ~= "Chase" then
		guardian.Awake = false
	end

	local state = guardian.State
	if state == "Idle" or state == "Patrol" or state == "Return" then
		if now >= guardian.BlindUntil then
			local target = findTarget(guardian)
			if target then
				guardian.Target = target
				setState(guardian, "Alert")
				guardian.Humanoid:MoveTo(guardian.Root.Position)
				Remote.Fire("Effect", target, { Type = "Alert" })
				if ability.Type == "Whistle" and ability.Enabled then
					Remote.FireAll("Effect", { Type = "Whistle", Position = guardian.Root.Position })
					for _, other in guardians do
						if other ~= guardian and (other.Root.Position - guardian.Root.Position).Magnitude <= (ability.Radius or 120) and isTarget(other, target) and (other.State == "Idle" or other.State == "Patrol") then
							other.Target = target
							setState(other, "Alert")
						end
					end
				end
				return
			end
		end
	end
	if state == "Alert" then
		guardian.Humanoid:MoveTo(guardian.Root.Position)
		if now - guardian.StateSince >= GameSettings.Guardian.AlertWindup then
			guardian.ChaseStart = now
			guardian.LastDistance = math.huge
			guardian.LastPosition = nil
			setState(guardian, "Chase")
		end
	elseif state == "Chase" then
		chase(guardian, now)
	elseif state == "Return" then
		applySpeed(guardian, 0.8)
		moveTo(guardian, guardian.NestCenter)
		if World.FlatDistance(guardian.Root.Position, guardian.NestCenter) < 6 then
			setState(guardian, if statue then "Idle" else "Patrol")
			guardian.PauseUntil = now + 2
		end
	elseif state == "Idle" then
		applySpeed(guardian, 0.5)
		if statue then
			guardian.Humanoid:MoveTo(guardian.Root.Position)
		elseif now >= guardian.PauseUntil then
			setState(guardian, "Patrol")
		end
	elseif state == "Patrol" then
		patrol(guardian, now)
	end
end

local function spawnGuardians()
	folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace
	for _, spawnPart in World.TaggedParts(Tags.GuardianSpawn) do
		local zoneId = spawnPart:GetAttribute("ZoneId")
		local zone = if type(zoneId) == "number" then Zones.ById[zoneId] else nil
		if not zone then
			continue
		end
		local nestCenter, nestRadius = nestFor(zone.Id)
		local model = GuardianBuilder.Build(zone.Guardian)
		local spawnCFrame = spawnPart.CFrame * CFrame.new(0, 4, 0)
		model:PivotTo(spawnCFrame)
		model.Parent = folder
		CollectionService:AddTag(model, Tags.Guardian)
		model:SetAttribute("ZoneId", zone.Id)
		local root = model.PrimaryPart :: BasePart
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		if zone.Guardian.Ability.Type == "Phase" and zone.Guardian.Ability.Enabled then
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CanCollide = descendant == root
				end
			end
		end
		local guardian: Guardian = {
			Model = model,
			Humanoid = humanoid,
			Root = root,
			Zone = zone,
			ZoneBounds = zoneBounds(zone.Id),
			NestCenter = nestCenter or spawnPart.Position,
			NestRadius = nestRadius,
			Spawn = spawnCFrame,
			Waypoints = waypointsFor(zone.Id),
			WaypointIndex = 1,
			State = "Idle",
			StateSince = os.clock(),
			Target = nil,
			ChaseStart = 0,
			PauseUntil = os.clock() + math.random() * 3,
			LastDistance = math.huge,
			BlockedSince = nil,
			Path = nil,
			PathIndex = 1,
			PathUntil = 0,
			FrozenUntil = 0,
			BlindUntil = 0,
			NextAbility = 0,
			BurstUntil = 0,
			BurstMultiplier = 1,
			Awake = false,
			AlertGui = makeAlertGui(model),
		}
		model:SetAttribute("State", "Idle")
		table.insert(guardians, guardian)
	end
end

-- Freeze every guardian within `radius` of a point (Ofuda trap). Returns how many.
function GuardianService.FreezeNear(position: Vector3, radius: number, duration: number): number
	local count = 0
	for _, guardian in guardians do
		if (guardian.Root.Position - position).Magnitude <= radius then
			guardian.FrozenUntil = math.max(guardian.FrozenUntil, os.clock() + duration)
			count += 1
		end
	end
	return count
end

-- Break line of sight (Smoke Bomb)
function GuardianService.BlindNear(position: Vector3, radius: number, duration: number): number
	local count = 0
	for _, guardian in guardians do
		if (guardian.Root.Position - position).Magnitude <= radius then
			guardian.BlindUntil = os.clock() + duration
			if guardian.State == "Chase" or guardian.State == "Alert" then
				setState(guardian, "Return")
			end
			count += 1
		end
	end
	return count
end

function GuardianService.All(): { Guardian }
	return guardians
end

function GuardianService.Init() end

function GuardianService.Start()
	Players.PlayerRemoving:Connect(function(player)
		graceUntil[player] = nil
	end)
	spawnGuardians()
	-- Stone Komainu wakes up when an egg is taken from its nest
	EggSpawnService.EggGrabbed:Connect(function(player, _item, zoneId)
		for _, guardian in guardians do
			if guardian.Zone.Id == zoneId and guardian.Zone.Guardian.Ability.Type == "Statue" and guardian.Zone.Guardian.Ability.Enabled then
				guardian.Awake = true
				guardian.Target = player
				guardian.BurstUntil = os.clock() + (guardian.Zone.Guardian.Ability.Duration or 5)
				guardian.BurstMultiplier = guardian.Zone.Guardian.Ability.Multiplier or 1.5
				setState(guardian, "Alert")
			end
		end
	end)
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, guardian in guardians do
				local ok, err = pcall(function(): nil
					tick(guardian, now)
					return nil
				end)
				if not ok then
					warn("[GuardianService] " .. tostring(err))
				end
			end
			task.wait(GameSettings.Guardian.ChaseTick)
		end
	end)
end

return GuardianService
