--!nocheck
-- Just enough physics for server logic: raycasts against part boxes, Humanoid walking
-- (MoveTo at WalkSpeed with ground following), Touched events for character roots,
-- humanoid health/state, and R15-style player characters.

local roblox = require("@lune/roblox")
local Runtime = require("./Runtime")
local I = require("./Instances")
local Classes = require("./Classes")
local S = require("./Shared")

local Vector3, CFrame = roblox.Vector3, require("../lib/cframe")
local Enum = roblox.Enum
local wrap, unwrap, selfReal, states = I.wrap, I.unwrap, I.selfReal, I.states
local method, event, prop = I.method, I.event, I.prop

local Physics = {}

-- Spatial grid of anchored parts; unanchored parts are checked brute force ---------------

local CELL = 32
local grid = {} -- key -> { [part] = true }
local partCells = {} -- part -> { keys }
local dynamic = {} -- unanchored parts in Workspace
local bigStatic = {} -- anchored parts too large for the grid
local workspaceReal = nil

local function cellKey(x, z)
	return x * 100003 + z
end

local function removeFromGrid(part)
	local keys = partCells[part]
	if keys then
		for _, key in keys do
			local cell = grid[key]
			if cell then
				cell[part] = nil
			end
		end
		partCells[part] = nil
	end
	dynamic[part] = nil
	bigStatic[part] = nil
end

local function footprint(part)
	local cf, half = part.CFrame, part.Size / 2
	local r = CFrame.new().Rotation
	local ax = math.abs
	local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = ax(rx.X) * half.X + ax(ry.X) * half.Y + ax(rz.X) * half.Z
	local ez = ax(rx.Z) * half.X + ax(ry.Z) * half.Y + ax(rz.Z) * half.Z
	local p = cf.Position
	return p.X - ex, p.X + ex, p.Z - ez, p.Z + ez
end

function Physics.setWorkspace(real)
	workspaceReal = real
end

local function insertPart(part)
	removeFromGrid(part)
	if not workspaceReal or not part:IsDescendantOf(workspaceReal) then
		return
	end
	if not part.Anchored then
		dynamic[part] = true
		return
	end
	local x0, x1, z0, z1 = footprint(part)
	local cx0, cx1 = math.floor(x0 / CELL), math.floor(x1 / CELL)
	local cz0, cz1 = math.floor(z0 / CELL), math.floor(z1 / CELL)
	if (cx1 - cx0 + 1) * (cz1 - cz0 + 1) > 400 then
		-- huge part (baseplate, boundaries): keep it in the brute-force list
		bigStatic[part] = true
		return
	end
	local keys = {}
	for cx = cx0, cx1 do
		for cz = cz0, cz1 do
			local key = cellKey(cx, cz)
			local cell = grid[key]
			if not cell then
				cell = {}
				grid[key] = cell
			end
			cell[part] = true
			table.insert(keys, key)
		end
	end
	partCells[part] = keys
end

local dirty = {}
Classes.partMoved = function(part)
	if partCells[part] or bigStatic[part] or part.Anchored then
		dirty[part] = true
	end
end

local function flushDirty()
	for part in dirty do
		local st = states[part]
		if st and st.destroyed then
			removeFromGrid(part)
		else
			insertPart(part)
		end
	end
	table.clear(dirty)
end

table.insert(I.onEnterGame, function(real)
	if real:IsA("BasePart") then
		dirty[real] = true
	end
end)
table.insert(I.onLeaveGame, function(real)
	if real:IsA("BasePart") then
		dirty[real] = nil
		removeFromGrid(real)
	end
end)

-- Ray vs a part: oriented box, or a wedge (box cut by its slope: the high edge is at the
-- back, +Z local, and the slope faces the front). Returns t in [0, 1] along `dir`, normal.
local function rayBox(origin, dir, part)
	local cf = part.CFrame
	local half = part.Size / 2
	local o = cf:PointToObjectSpace(origin)
	local d = cf:VectorToObjectSpace(dir)
	local tmin, tmax = -math.huge, math.huge
	local normalAxis, normalSign = nil, 0
	for _, axis in { "X", "Y", "Z" } do
		local oa, da, h = o[axis], d[axis], half[axis]
		if math.abs(da) < 1e-9 then
			if oa < -h or oa > h then
				return nil
			end
		else
			local t1 = (-h - oa) / da
			local t2 = (h - oa) / da
			local sign = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				sign = 1
			end
			if t1 > tmin then
				tmin = t1
				normalAxis = axis
				normalSign = sign
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return nil
			end
		end
	end
	local localNormal = Vector3.new(
		if normalAxis == "X" then normalSign else 0,
		if normalAxis == "Y" then normalSign else 0,
		if normalAxis == "Z" then normalSign else 0
	)
	if part.ClassName == "WedgePart" and half.Z > 1e-6 then
		-- solid part of the box: y <= k * z
		local k = half.Y / half.Z
		local f0 = o.Y - k * o.Z
		local f1 = d.Y - k * d.Z
		local a, b = tmin, tmax
		if math.abs(f1) < 1e-12 then
			if f0 > 0 then
				return nil
			end
		else
			local tPlane = -f0 / f1
			if f1 > 0 then
				-- inside the solid before the plane
				b = math.min(b, tPlane)
			else
				-- inside the solid after the plane
				if tPlane > a then
					a = tPlane
					localNormal = Vector3.new(0, 1, -k).Unit
				end
			end
		end
		if a > b then
			return nil
		end
		tmin, tmax = a, b
	end
	if tmax < 0 or tmin < 0 then
		return nil -- behind the origin, or the ray starts inside the part (Roblox ignores those)
	end
	return tmin, cf:VectorToWorldSpace(localNormal)
end

local function isAncestorIn(part, set)
	local node = part
	while node do
		if set[node] then
			return true
		end
		node = node.Parent
	end
	return false
end

-- params: { filter = { [real]=true }, include = bool, respectCanCollide = bool, ctx }
function Physics.raycast(origin, direction, params)
	flushDirty()
	params = params or {}
	local length = direction.Magnitude
	if length < 1e-6 then
		return nil
	end
	local unit = direction / length
	local candidates = {}
	local steps = math.ceil(length / (CELL / 2))
	local seenCells = {}
	for i = 0, steps do
		local p = origin + unit * math.min(length, i * CELL / 2)
		local key = cellKey(math.floor(p.X / CELL), math.floor(p.Z / CELL))
		if not seenCells[key] then
			seenCells[key] = true
			local cell = grid[key]
			if cell then
				for part in cell do
					candidates[part] = true
				end
			end
		end
	end
	for part in bigStatic do
		candidates[part] = true
	end
	if not params.staticOnly then
		for part in dynamic do
			candidates[part] = true
		end
	end
	local bestT, bestPart, bestNormal = math.huge, nil, nil
	local ctx = params.ctx
	for part in candidates do
		local st = states[part]
		if not (st and st.destroyed) and part.CanQuery then
			local skip = false
			if params.respectCanCollide and not part.CanCollide then
				skip = true
			end
			if not skip and params.filter then
				local inSet = isAncestorIn(part, params.filter)
				if params.include then
					skip = not inSet
				else
					skip = inSet
				end
			end
			if not skip and ctx and not I.visible(part, ctx) then
				skip = true
			end
			if not skip then
				local t, normal = rayBox(origin, direction, part)
				if t and t <= 1 and t * length < bestT then
					bestT = t * length
					bestPart = part
					bestNormal = normal
				end
			end
		end
	end
	if not bestPart then
		return nil
	end
	return {
		Instance = wrap(bestPart),
		Position = origin + unit * bestT,
		Normal = bestNormal,
		Material = bestPart.Material,
		Distance = bestT,
	}
end

-- RaycastParams / OverlapParams as plain objects
local RaycastParams = {}
RaycastParams.__index = RaycastParams
Physics.RaycastParams = {
	new = function()
		return setmetatable({
			FilterDescendantsInstances = {},
			FilterType = Enum.RaycastFilterType.Exclude,
			IgnoreWater = false,
			CollisionGroup = "Default",
			RespectCanCollide = false,
			BruteForceAllSlow = false,
			_kind = "RaycastParams",
		}, RaycastParams)
	end,
}
function RaycastParams:AddToFilter(value)
	if type(value) == "table" then
		for _, v in value do
			table.insert(self.FilterDescendantsInstances, v)
		end
	else
		table.insert(self.FilterDescendantsInstances, value)
	end
end
Physics.OverlapParams = Physics.RaycastParams

local function toParams(params)
	if params == nil then
		return { ctx = Runtime.ctx }
	end
	if type(params) ~= "table" or params._kind ~= "RaycastParams" then
		error("Unable to cast to RaycastParams", 3)
	end
	local filter = {}
	for _, inst in params.FilterDescendantsInstances do
		local real = unwrap(inst)
		if typeof(real) ~= "Instance" then
			error("FilterDescendantsInstances must contain Instances", 3)
		end
		filter[real] = true
	end
	local ft = params.FilterType
	local include = typeof(ft) == "EnumItem" and (ft.Name == "Include" or ft.Name == "Whitelist")
	return { filter = filter, include = include, respectCanCollide = params.RespectCanCollide, ctx = Runtime.ctx }
end

method("WorldRoot", "Raycast", function(self, origin, direction, params)
	selfReal(self, "Raycast")
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		error("Unable to cast to Vector3", 2)
	end
	return Physics.raycast(origin, direction, toParams(params))
end)
method("WorldRoot", "Spherecast", function(self, origin, _radius, direction, params)
	return Physics.raycast(origin, direction, toParams(params))
end)
method("WorldRoot", "Blockcast", function(self, cf, _size, direction, params)
	return Physics.raycast(cf.Position, direction, toParams(params))
end)

local function partsNear(center, radius, params)
	flushDirty()
	local out = {}
	local p = toParams(params)
	local function consider(part)
		local st = states[part]
		if st and st.destroyed then
			return
		end
		if p.filter and next(p.filter) then
			local inSet = isAncestorIn(part, p.filter)
			if (p.include and not inSet) or (not p.include and inSet) then
				return
			end
		end
		local localP = part.CFrame:PointToObjectSpace(center)
		local half = part.Size / 2
		local clamped = Vector3.new(
			math.clamp(localP.X, -half.X, half.X),
			math.clamp(localP.Y, -half.Y, half.Y),
			math.clamp(localP.Z, -half.Z, half.Z)
		)
		if (clamped - localP).Magnitude <= radius then
			table.insert(out, wrap(part))
		end
	end
	local seen = {}
	for cx = math.floor((center.X - radius) / CELL), math.floor((center.X + radius) / CELL) do
		for cz = math.floor((center.Z - radius) / CELL), math.floor((center.Z + radius) / CELL) do
			for part in grid[cellKey(cx, cz)] or {} do
				if not seen[part] then
					seen[part] = true
					consider(part)
				end
			end
		end
	end
	for _, set in { dynamic, bigStatic } do
		for part in set do
			if not seen[part] then
				seen[part] = true
				consider(part)
			end
		end
	end
	return out
end
method("WorldRoot", "GetPartBoundsInRadius", function(self, center, radius, params)
	return partsNear(center, radius, params)
end)
method("WorldRoot", "GetPartBoundsInBox", function(self, cf, size, params)
	return partsNear(cf.Position, size.Magnitude / 2, params)
end)
method("WorldRoot", "GetPartsInPart", function(self, part, params)
	local real = unwrap(part)
	return partsNear(real.CFrame.Position, real.Size.Magnitude / 2, params)
end)
method("WorldRoot", "FindPartOnRay", function(self, ray, ignore)
	local params = Physics.RaycastParams.new()
	if ignore then
		params.FilterDescendantsInstances = { ignore }
	end
	local hit = Physics.raycast(ray.Origin, ray.Direction, toParams(params))
	if hit then
		return hit.Instance, hit.Position, hit.Normal, hit.Material
	end
	return nil, ray.Origin + ray.Direction, Vector3.yAxis, Enum.Material.Air
end)

-- Humanoids ---------------------------------------------------------------------------------

local humanoids = {} -- real Humanoid -> true
Physics.humanoids = humanoids

local function hstate(real)
	local st = states[real] or I.getState(real)
	if not st.humanoid then
		st.humanoid = {
			state = Enum.HumanoidStateType.Running,
			enabled = {},
			moveTarget = nil,
			moveStart = 0,
			moveDir = Vector3.zero,
			dead = false,
		}
	end
	return st.humanoid, st
end
Physics.hstate = hstate

local function rootOf(humanoid)
	local model = humanoid.Parent
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	local primary = model:IsA("Model") and model.PrimaryPart
	return primary
end
Physics.rootOf = rootOf

table.insert(I.onCreate, function(real)
	if real.ClassName == "Humanoid" then
		humanoids[real] = true
	end
end)
table.insert(I.onEnterGame, function(real)
	if real.ClassName == "Humanoid" then
		humanoids[real] = true
	end
end)

local function setState(real, newState)
	local h = hstate(real)
	local old = h.state
	if old == newState then
		return
	end
	h.state = newState
	I.fire(real, "StateChanged", old, newState)
end

local function die(real)
	local h = hstate(real)
	if h.dead then
		return
	end
	if h.enabled[Enum.HumanoidStateType.Dead] == false then
		return
	end
	h.dead = true
	h.moveTarget = nil
	setState(real, Enum.HumanoidStateType.Dead)
	I.fire(real, "Died")
	Physics.onDied(real)
end
Physics.onDied = function() end

prop("Humanoid", "Health", function(real)
	return I.get(real, "Health")
end, function(real, st, value)
	local maxHealth = I.get(real, "MaxHealth")
	local v = math.clamp(tonumber(value) or 0, 0, maxHealth)
	local old = I.get(real, "Health")
	real.Health = v
	if old ~= v then
		I.fire(real, "HealthChanged", v)
		I.firePropChanged(real, st, "Health")
	end
	if v <= 0 then
		die(real)
	end
end)
prop("Humanoid", "RootPart", function(real)
	return wrap(rootOf(real))
end)
prop("Humanoid", "MoveDirection", function(real)
	return hstate(real).moveDir
end)
prop("Humanoid", "FloorMaterial", function()
	return Enum.Material.Plastic
end)
prop("Humanoid", "SeatPart", function()
	return nil
end)
-- Jumps follow a real arc: v0 = sqrt(2 g h) with the humanoid's jump height
local GRAVITY = 196.2
local function jumpHeight(real)
	if I.get(real, "UseJumpPower") then
		local power = I.get(real, "JumpPower")
		return power * power / (2 * GRAVITY)
	end
	return I.get(real, "JumpHeight")
end

local function startJump(real)
	local h = hstate(real)
	if h.jumpStart or h.dead then
		return false -- already airborne
	end
	local height = jumpHeight(real)
	if height <= 0.05 then
		return false -- carrying something too heavy to jump
	end
	h.jumpStart = Runtime.now
	h.jumpV0 = math.sqrt(2 * GRAVITY * height)
	setState(real, Enum.HumanoidStateType.Jumping)
	I.fire(real, "Jumping", true)
	return true
end
Physics.startJump = startJump

-- Height above the ground from the current jump (0 when grounded); ends the jump on landing
local function jumpOffset(real, h)
	if not h.jumpStart then
		return 0
	end
	local t = Runtime.now - h.jumpStart
	local offset = h.jumpV0 * t - 0.5 * GRAVITY * t * t
	if offset <= 0 and t > 0.05 then
		h.jumpStart = nil
		setState(real, Enum.HumanoidStateType.Landed)
		setState(real, Enum.HumanoidStateType.Running)
		return 0
	end
	return math.max(offset, 0)
end

prop("Humanoid", "Jump", function(real)
	return hstate(real).jumpStart ~= nil
end, function(real, _st, value)
	if value then
		startJump(real)
	end
end)

method("Humanoid", "MoveTo", function(self, position, part)
	local real = selfReal(self, "MoveTo")
	if typeof(position) ~= "Vector3" then
		error("Unable to cast to Vector3", 2)
	end
	local h = hstate(real)
	h.moveTarget = position
	h.movePart = unwrap(part)
	h.moveStart = Runtime.now
	humanoids[real] = true
end)
method("Humanoid", "Move", function(self, direction)
	local h = hstate(selfReal(self, "Move"))
	h.moveDir = direction
end)
method("Humanoid", "TakeDamage", function(self, amount)
	local real = selfReal(self, "TakeDamage")
	local model = real.Parent
	if model and model:FindFirstChildOfClass("ForceField") then
		return
	end
	wrap(real).Health = I.get(real, "Health") - amount
end)
method("Humanoid", "ChangeState", function(self, newState)
	local real = selfReal(self, "ChangeState")
	if typeof(newState) ~= "EnumItem" then
		error("Unable to cast to HumanoidStateType", 2)
	end
	if newState == Enum.HumanoidStateType.Dead then
		die(real)
		return
	end
	if newState == Enum.HumanoidStateType.Jumping then
		startJump(real)
		return
	end
	setState(real, newState)
end)
method("Humanoid", "GetState", function(self)
	return hstate(selfReal(self, "GetState")).state
end)
method("Humanoid", "SetStateEnabled", function(self, which, enabled)
	hstate(selfReal(self, "SetStateEnabled")).enabled[which] = enabled
end)
method("Humanoid", "GetStateEnabled", function(self, which)
	return hstate(selfReal(self, "GetStateEnabled")).enabled[which] ~= false
end)
method("Humanoid", "ApplyDescription", function() end)
method("Humanoid", "ApplyDescriptionReset", function() end)
method("Humanoid", "GetAppliedDescription", function()
	return I.new("HumanoidDescription")
end)
method("Humanoid", "EquipTool", function(self, tool)
	local real = selfReal(self, "EquipTool")
	I.setParent(unwrap(tool), real.Parent)
end)
method("Humanoid", "UnequipTools", function() end)
method("Humanoid", "RemoveAccessories", function(self)
	local real = selfReal(self, "RemoveAccessories")
	for _, child in real.Parent and real.Parent:GetChildren() or {} do
		if child:IsA("Accessory") then
			I.destroy(child)
		end
	end
end)
method("Humanoid", "GetAccessories", function(self)
	local real = selfReal(self, "GetAccessories")
	local out = {}
	for _, child in real.Parent and real.Parent:GetChildren() or {} do
		if child:IsA("Accessory") then
			table.insert(out, wrap(child))
		end
	end
	return out
end)
method("Humanoid", "AddAccessory", function(self, accessory)
	local real = selfReal(self, "AddAccessory")
	I.setParent(unwrap(accessory), real.Parent)
end)
method("Humanoid", "BuildRigFromAttachments", function() end)
method("Humanoid", "GetLimb", function()
	return Enum.Limb.Unknown
end)
method("Humanoid", "GetBodyPartR15", function()
	return Enum.BodyPartR15.Unknown
end)
for _, name in {
	"Died",
	"MoveToFinished",
	"Running",
	"StateChanged",
	"HealthChanged",
	"Jumping",
	"Touched",
	"Seated",
	"FreeFalling",
	"GettingUp",
	"Climbing",
	"FallingDown",
	"PlatformStanding",
	"Ragdoll",
	"Swimming",
	"AnimationPlayed",
	"StateEnabledChanged",
} do
	event("Humanoid", name)
end

-- Ground height under a point (top surface), ignoring `exclude`. Memoized on a 1-stud
-- grid; the memo is cleared whenever an anchored part moves or appears.
local groundMemo = {}
local groundMemoSize = 0
Physics.clearGroundMemo = function()
	table.clear(groundMemo)
	groundMemoSize = 0
end

local rawGroundAt
local function groundAt(position, exclude)
	local key = string.format("%d,%d,%d", math.floor(position.X), math.floor(position.Z), math.floor(position.Y / 2))
	local cached = groundMemo[key]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local t0 = os.clock()
	local result = rawGroundAt(position, exclude)
	Physics.groundTime = (Physics.groundTime or 0) + (os.clock() - t0)
	Physics.groundCalls = (Physics.groundCalls or 0) + 1
	if groundMemoSize > 200000 then
		Physics.clearGroundMemo()
	end
	groundMemo[key] = if result == nil then false else result
	groundMemoSize += 1
	return result
end

rawGroundAt = function(position, exclude)
	local filter = {}
	if exclude then
		filter[exclude] = true
	end
	local hit = Physics.raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), {
		filter = filter,
		include = false,
		respectCanCollide = true,
		staticOnly = true,
	})
	return hit and hit.Position.Y or nil
end
Physics.groundAt = groundAt

-- The WalkSpeed the humanoid actually moves at: players move at what their own client sees
local function effectiveWalkSpeed(real, st)
	local speed = real.WalkSpeed
	if st.overlay then
		local model = real.Parent
		for playerReal, ctx in S.clients do
			if playerReal.Character == model then
				local overlay = st.overlay[ctx]
				if overlay and overlay.WalkSpeed ~= nil then
					speed = overlay.WalkSpeed
				end
				break
			end
		end
	end
	return speed
end

local function hipOffset(real, root)
	local hip = real.HipHeight
	return hip + root.Size.Y / 2
end

-- Knockback: slide a root along its horizontal velocity, with ground friction
local function integrateVelocity(root, dt, model)
	local rst = states[root]
	local v = rst and rst.virtual and rst.virtual.AssemblyLinearVelocity
	if not v then
		return
	end
	local horizontal = Vector3.new(v.X, 0, v.Z)
	if horizontal.Magnitude < 0.5 then
		rst.virtual.AssemblyLinearVelocity = nil
		return
	end
	local pos = root.CFrame.Position + horizontal * dt
	local ground = groundAt(pos, model)
	if ground then
		pos = Vector3.new(pos.X, ground + root.Size.Y / 2 + 2, pos.Z)
	end
	Classes.setPartCFrame(root, CFrame.new(pos) * root.CFrame.Rotation)
	Classes.partMoved(root)
	rst.virtual.AssemblyLinearVelocity = horizontal * math.exp(-2.5 * dt)
end

function Physics.stepHumanoids(dt)
	for real in humanoids do
		local st = states[real]
		if not st or st.destroyed or real.Parent == nil then
			humanoids[real] = nil
		elseif st.humanoid then
			local hh = st.humanoid
			local cached = hh.root
			if not cached or cached.Parent ~= real.Parent then
				cached = rootOf(real)
				hh.root = cached
			end
			if cached then
				local rst = states[cached]
				if rst and rst.virtual and rst.virtual.AssemblyLinearVelocity and not cached.Anchored then
					integrateVelocity(cached, dt, real.Parent)
				end
			end
			local h = st.humanoid
			if h and h.jumpStart and not h.moveTarget and cached and not cached.Anchored then
				-- jumping in place
				local pos = cached.CFrame.Position
				local ground = groundAt(pos, real.Parent)
				local base = if ground then ground + hipOffset(real, cached) else pos.Y
				local y = base + jumpOffset(real, h)
				Classes.setPartCFrame(cached, CFrame.new(pos.X, y, pos.Z) * cached.CFrame.Rotation)
				Classes.partMoved(cached)
			end
			if h and h.moveTarget and not h.dead then
				local root = h.root
				if root and not root.Anchored and not I.get(real, "PlatformStand") and not I.get(real, "Sit") then
					local target = h.moveTarget
					if h.movePart then
						target = h.movePart.CFrame * target
					end
					local pos = root.CFrame.Position
					local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
					local distance = flat.Magnitude
					local speed = effectiveWalkSpeed(real, st)
					local step = speed * dt
					local model = real.Parent
					local newPos
					local arrived = false
					if distance <= math.max(step, 0.5) then
						newPos = Vector3.new(target.X, pos.Y, target.Z)
						arrived = true
					else
						newPos = pos + flat.Unit * step
					end
					local ground = groundAt(newPos, model)
					local y = pos.Y
					if ground then
						local desired = ground + hipOffset(real, root)
						if desired <= pos.Y + 4 then
							y = desired
						else
							-- a wall or step taller than a stride: climb it (no collision in the emulator)
							y = desired
						end
					end
					y += jumpOffset(real, h)
					newPos = Vector3.new(newPos.X, y, newPos.Z)
					local facing = if distance > 0.01 then CFrame.lookAt(newPos, newPos + flat.Unit) else CFrame.new(newPos) * root.CFrame.Rotation
					Classes.setPartCFrame(root, facing)
					Classes.partMoved(root)
					h.moveDir = if distance > 0.01 then flat.Unit else Vector3.zero
					if arrived then
						h.moveTarget = nil
						h.moveDir = Vector3.zero
						I.fire(real, "MoveToFinished", true)
					elseif Runtime.now - h.moveStart > 8 then
						h.moveTarget = nil
						h.moveDir = Vector3.zero
						I.fire(real, "MoveToFinished", false)
					end
				end
			end
		end
	end
end

-- Touched: check character root parts against parts that have Touched listeners -----------

local touchParts = {} -- part -> true
local touching = {} -- part -> { [root] = true }

event("BasePart", "Touched", function(real, _st, n)
	if n > 0 then
		touchParts[real] = true
	else
		touchParts[real] = nil
	end
end)
event("BasePart", "TouchEnded")

local function overlaps(part, other)
	local localP = part.CFrame:PointToObjectSpace(other.CFrame.Position)
	local half = part.Size / 2 + other.Size / 2 + Vector3.new(0.1, 0.2, 0.1)
	return math.abs(localP.X) <= half.X and math.abs(localP.Y) <= half.Y and math.abs(localP.Z) <= half.Z
end

function Physics.stepTouches()
	if next(touchParts) == nil then
		return
	end
	local bodies = {}
	for playerReal in S.clients do
		local character = playerReal.Character
		if character then
			for _, d in character:GetChildren() do
				if d:IsA("BasePart") then
					table.insert(bodies, d)
				end
			end
		end
	end
	for part in touchParts do
		local st = states[part]
		if st and st.destroyed then
			touchParts[part] = nil
		elseif part.CanTouch then
			local current = touching[part] or {}
			local now = {}
			for _, body in bodies do
				if overlaps(part, body) then
					now[body] = true
					if not current[body] then
						I.fire(part, "Touched", wrap(body))
					end
				end
			end
			for body in current do
				if not now[body] then
					I.fire(part, "TouchEnded", wrap(body))
				end
			end
			touching[part] = now
		end
	end
end

-- Player characters --------------------------------------------------------------------------

local function newPart(name, size, cf, parent)
	local part = I.newRaw("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = false
	part.CanCollide = name == "HumanoidRootPart"
	part.Parent = parent
	return part
end

local function motor(name, p0, p1, c0, c1)
	local m = I.newRaw("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p1
	return m
end

local function attachment(name, parent, offset)
	local a = I.newRaw("Attachment")
	a.Name = name
	a.CFrame = CFrame.new(offset)
	a.Parent = parent
	return a
end

-- Build an R15-style rig (fewer limbs) standing at `cf` (root position)
function Physics.buildCharacter(name, cf)
	local model = I.newRaw("Model")
	model.Name = name
	local root = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), cf, model)
	root.Transparency = 1
	local lower = newPart("LowerTorso", Vector3.new(2, 0.4, 1), cf * CFrame.new(0, -0.2, 0), model)
	local upper = newPart("UpperTorso", Vector3.new(2, 1.6, 1), cf * CFrame.new(0, 0.8, 0), model)
	local head = newPart("Head", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 2.2, 0), model)
	local rightHand = newPart("RightHand", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(1.4, -0.4, 0), model)
	local leftHand = newPart("LeftHand", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(-1.4, -0.4, 0), model)
	local rightFoot = newPart("RightFoot", Vector3.new(0.6, 0.3, 1), cf * CFrame.new(0.5, -2.8, 0), model)
	local leftFoot = newPart("LeftFoot", Vector3.new(0.6, 0.3, 1), cf * CFrame.new(-0.5, -2.8, 0), model)
	motor("Root", root, lower, CFrame.new(0, -0.2, 0), CFrame.new())
	motor("Waist", lower, upper, CFrame.new(0, 1, 0), CFrame.new())
	motor("Neck", upper, head, CFrame.new(0, 1.4, 0), CFrame.new())
	motor("RightWrist", upper, rightHand, CFrame.new(1.4, -1.2, 0), CFrame.new())
	motor("LeftWrist", upper, leftHand, CFrame.new(-1.4, -1.2, 0), CFrame.new())
	motor("RightAnkle", lower, rightFoot, CFrame.new(0.5, -2.6, 0), CFrame.new())
	motor("LeftAnkle", lower, leftFoot, CFrame.new(-0.5, -2.6, 0), CFrame.new())
	attachment("RootAttachment", root, Vector3.zero)
	attachment("HatAttachment", head, Vector3.new(0, 0.6, 0))
	attachment("HairAttachment", head, Vector3.new(0, 0.6, 0))
	attachment("FaceFrontAttachment", head, Vector3.new(0, 0, -0.6))
	attachment("NeckAttachment", upper, Vector3.new(0, 0.8, 0))
	attachment("BodyBackAttachment", upper, Vector3.new(0, 0, 0.5))
	attachment("BodyFrontAttachment", upper, Vector3.new(0, 0, -0.5))
	attachment("WaistBackAttachment", lower, Vector3.new(0, 0, 0.5))
	attachment("RightGripAttachment", rightHand, Vector3.new(0, -0.2, 0))
	attachment("LeftGripAttachment", leftHand, Vector3.new(0, -0.2, 0))
	local face = I.newRaw("Decal")
	face.Name = "face"
	face.Parent = head
	local humanoid = I.newRaw("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	local animator = I.newRaw("Animator")
	animator.Parent = humanoid
	model.PrimaryPart = root
	humanoids[humanoid] = true
	hstate(humanoid)
	return model
end

return Physics
