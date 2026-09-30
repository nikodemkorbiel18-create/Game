--!nocheck
-- Class members Lune doesn't provide: generic Instance API, parts and models (pivots,
-- welded assemblies), attachments, GUI geometry, remotes and bindables, prompts, sounds,
-- particles and animation tracks.

local roblox = require("@lune/roblox")
local Runtime = require("./Runtime")
local I = require("./Instances")
local S = require("./Shared")

local Vector3, Vector2, CFrame = roblox.Vector3, roblox.Vector2, roblox.CFrame

local wrap, unwrap, selfReal, states = I.wrap, I.unwrap, I.selfReal, I.states
local method, event, prop = I.method, I.event, I.prop

local Classes = {}

-- Generic Instance --------------------------------------------------------------------

prop("Instance", "Parent", function(real, st)
	local ctx = Runtime.ctx
	if ctx and st.hiddenFor and st.hiddenFor[ctx] then
		return nil
	end
	return wrap(real.Parent)
end, function(real, _st, value)
	I.setParent(real, unwrap(value))
end)

prop("Instance", "ClassName", function(_real, st)
	return st.class
end, function()
	error("Unable to assign property ClassName. Property is read only", 3)
end)

method("Instance", "Destroy", function(self)
	I.destroy(selfReal(self, "Destroy"))
end)
method("Instance", "Remove", function(self)
	I.setParent(selfReal(self, "Remove"), nil)
end)
method("Instance", "ClearAllChildren", function(self)
	local real = selfReal(self, "ClearAllChildren")
	for _, child in I.children(real, Runtime.ctx) do
		I.destroy(child)
	end
end)
method("Instance", "Clone", function(self)
	local real = selfReal(self, "Clone")
	if not real.Archivable then
		return nil
	end
	return wrap(I.clone(real))
end)

method("Instance", "GetChildren", function(self)
	return I.wrapList(I.children(selfReal(self, "GetChildren"), Runtime.ctx))
end)
method("Instance", "GetDescendants", function(self)
	return I.wrapList(I.descendants(selfReal(self, "GetDescendants"), Runtime.ctx))
end)

local function findChild(real, predicate, recursive)
	local ctx = Runtime.ctx
	for _, child in I.children(real, ctx) do
		if predicate(child) then
			return child
		end
	end
	if recursive then
		for _, child in I.children(real, ctx) do
			local found = findChild(child, predicate, true)
			if found then
				return found
			end
		end
	end
	return nil
end

method("Instance", "FindFirstChild", function(self, name, recursive)
	local real = selfReal(self, "FindFirstChild")
	if type(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	return wrap(findChild(real, function(c)
		return c.Name == name
	end, recursive))
end)
method("Instance", "FindFirstChildOfClass", function(self, class)
	return wrap(findChild(selfReal(self, "FindFirstChildOfClass"), function(c)
		return c.ClassName == class
	end))
end)
method("Instance", "FindFirstChildWhichIsA", function(self, class, recursive)
	return wrap(findChild(selfReal(self, "FindFirstChildWhichIsA"), function(c)
		return c:IsA(class)
	end, recursive))
end)
method("Instance", "FindFirstDescendant", function(self, name)
	return wrap(findChild(selfReal(self, "FindFirstDescendant"), function(c)
		return c.Name == name
	end, true))
end)
local function findAncestor(real, predicate)
	local node = real.Parent
	while node do
		if predicate(node) then
			return wrap(node)
		end
		node = node.Parent
	end
	return nil
end
method("Instance", "FindFirstAncestor", function(self, name)
	return findAncestor(selfReal(self, "FindFirstAncestor"), function(n)
		return n.Name == name
	end)
end)
method("Instance", "FindFirstAncestorOfClass", function(self, class)
	return findAncestor(selfReal(self, "FindFirstAncestorOfClass"), function(n)
		return n.ClassName == class
	end)
end)
method("Instance", "FindFirstAncestorWhichIsA", function(self, class)
	return findAncestor(selfReal(self, "FindFirstAncestorWhichIsA"), function(n)
		return n:IsA(class)
	end)
end)

method("Instance", "WaitForChild", function(self, name, timeout)
	local real = selfReal(self, "WaitForChild")
	if type(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	local start = Runtime.now
	local warned = false
	while true do
		local found = findChild(real, function(c)
			return c.Name == name
		end)
		if found then
			return wrap(found)
		end
		if timeout and Runtime.now - start >= timeout then
			return nil
		end
		if not warned and not timeout and Runtime.now - start >= 5 then
			warned = true
			Runtime.print("WARN", string.format('Infinite yield possible on \'%s:WaitForChild("%s")\'', I.fullName(real), name))
		end
		Runtime.task.wait()
	end
end)

method("Instance", "IsDescendantOf", function(self, other)
	local real = selfReal(self, "IsDescendantOf")
	local target = unwrap(other)
	local node = real.Parent
	while node do
		if node == target then
			return true
		end
		node = node.Parent
	end
	return false
end)
method("Instance", "IsAncestorOf", function(self, other)
	local real = selfReal(self, "IsAncestorOf")
	local node = unwrap(other)
	node = node and node.Parent
	while node do
		if node == real then
			return true
		end
		node = node.Parent
	end
	return false
end)
method("Instance", "GetFullName", function(self)
	return I.fullName(selfReal(self, "GetFullName"))
end)
local debugIds = 0
method("Instance", "GetDebugId", function(self)
	local st = states[selfReal(self, "GetDebugId")]
	if not st.debugId then
		debugIds += 1
		st.debugId = "EMU_" .. debugIds
	end
	return st.debugId
end)
method("Instance", "GetActor", function()
	return nil
end)
method("Instance", "IsPropertyModified", function()
	return false
end)

-- Attributes
local allowedAttributeTypes = {
	string = true,
	boolean = true,
	number = true,
	UDim = true,
	UDim2 = true,
	BrickColor = true,
	Color3 = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	NumberSequence = true,
	ColorSequence = true,
	NumberRange = true,
	Rect = true,
	Font = true,
	EnumItem = true,
}

local function getAttribute(real, st, name, ctx)
	if ctx and st.attrOverlay and st.attrOverlay[ctx] then
		local entry = st.attrOverlay[ctx][name]
		if entry then
			return entry.v
		end
	end
	return real:GetAttribute(name)
end

local function fireAttribute(real, st, name, onlyCtx)
	local filter = function(ctx)
		if onlyCtx then
			return ctx == onlyCtx
		end
		return I.visible(real, ctx)
	end
	if st.signals and st.signals.AttributeChanged then
		st.signals.AttributeChanged:FireFiltered(filter, name)
	end
	local signal = st.attrSignals and st.attrSignals[name]
	if signal then
		signal:FireFiltered(filter)
	end
end

method("Instance", "GetAttribute", function(self, name)
	local real = selfReal(self, "GetAttribute")
	if type(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	return getAttribute(real, states[real], name, Runtime.ctx)
end)

method("Instance", "GetAttributes", function(self)
	local real = selfReal(self, "GetAttributes")
	local st = states[real]
	local result = real:GetAttributes()
	local ctx = Runtime.ctx
	if ctx and st.attrOverlay and st.attrOverlay[ctx] then
		for name, entry in st.attrOverlay[ctx] do
			result[name] = entry.v
		end
	end
	return result
end)

method("Instance", "SetAttribute", function(self, name, value)
	local real = selfReal(self, "SetAttribute")
	local st = states[real]
	if type(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	if #name > 100 or not string.match(name, "^[%w_]+$") or string.sub(name, 1, 3) == "RBX" then
		error(string.format("Attribute name '%s' is invalid", name), 2)
	end
	if value ~= nil and not allowedAttributeTypes[typeof(value)] then
		error(string.format("%s is not a supported attribute type", typeof(value)), 2)
	end
	if type(value) == "number" and value ~= value then
		Runtime.note("SetAttribute(" .. name .. ", NaN) on " .. I.fullName(real))
	end
	local ctx = Runtime.ctx
	if ctx and ctx.kind == "client" and st.owner ~= ctx then
		local old = getAttribute(real, st, name, ctx)
		st.attrOverlay = st.attrOverlay or {}
		st.attrOverlay[ctx] = st.attrOverlay[ctx] or {}
		st.attrOverlay[ctx][name] = { v = value }
		if old ~= value then
			fireAttribute(real, st, name, ctx)
		end
		return
	end
	local old = real:GetAttribute(name)
	local ok, err = pcall(real.SetAttribute, real, name, value)
	if not ok then
		error(tostring(err), 2)
	end
	if st.attrOverlay then
		for _, overlay in st.attrOverlay do
			overlay[name] = nil
		end
	end
	if old ~= value then
		fireAttribute(real, st, name)
	end
end)

method("Instance", "GetAttributeChangedSignal", function(self, name)
	local real = selfReal(self, "GetAttributeChangedSignal")
	local st = states[real]
	st.attrSignals = st.attrSignals or {}
	local signal = st.attrSignals[name]
	if not signal then
		signal = Runtime.newSignal("AttributeChanged:" .. name)
		st.attrSignals[name] = signal
	end
	return signal
end)

method("Instance", "GetPropertyChangedSignal", function(self, name)
	local real = selfReal(self, "GetPropertyChangedSignal")
	local st = states[real]
	if not I.propInfo(st.class, name) and not (I.Members[st.class] and I.Members[st.class][name]) then
		error(string.format("%s is not a valid property name.", tostring(name)), 2)
	end
	st.propSignals = st.propSignals or {}
	local signal = st.propSignals[name]
	if not signal then
		signal = Runtime.newSignal("Changed:" .. name)
		st.propSignals[name] = signal
	end
	return signal
end)

-- Tags
method("Instance", "AddTag", function(self, tag)
	local real = selfReal(self, "AddTag")
	if real:HasTag(tag) then
		return
	end
	local ctx = Runtime.ctx
	local st = states[real]
	if ctx and ctx.kind == "client" and st.owner ~= ctx then
		Runtime.note(string.format("client %s added tag %s to replicated %s (applied globally)", ctx.label, tag, I.fullName(real)))
	end
	real:AddTag(tag)
	if I.inGame(real) then
		I.indexTag(real, tag, true)
	end
end)
method("Instance", "RemoveTag", function(self, tag)
	local real = selfReal(self, "RemoveTag")
	real:RemoveTag(tag)
	I.unindexTag(real, tag, true)
end)
method("Instance", "HasTag", function(self, tag)
	return selfReal(self, "HasTag"):HasTag(tag)
end)
method("Instance", "GetTags", function(self)
	return selfReal(self, "GetTags"):GetTags()
end)

event("Instance", "ChildAdded")
event("Instance", "ChildRemoved")
event("Instance", "DescendantAdded")
event("Instance", "DescendantRemoving")
event("Instance", "Destroying")
event("Instance", "Changed")
event("Instance", "AttributeChanged")
event("Instance", "AncestryChanged", function(_real, st, n)
	local previous = st.ancestryCount or 0
	st.ancestryCount = n
	I.trackAncestryListeners(n - previous)
end)

-- Parts, models and welded assemblies --------------------------------------------------

local jointClasses = {
	Weld = true,
	Motor6D = true,
	ManualWeld = true,
	Motor = true,
	Snap = true,
	Glue = true,
	WeldConstraint = true,
}
-- Assemblies are cached until any joint or Anchored flag changes
local jointVersion = 0
local assemblyCache = {}
local function bumpJoints()
	jointVersion += 1
	table.clear(assemblyCache)
end
Classes.bumpJoints = bumpJoints

local partJoints = {} -- part -> { [joint] = true }
local jointParts = {} -- joint -> { p0, p1 }

local function linkJoint(joint)
	bumpJoints()
	local old = jointParts[joint]
	if old then
		if partJoints[old[1]] then
			partJoints[old[1]][joint] = nil
		end
		if partJoints[old[2]] then
			partJoints[old[2]][joint] = nil
		end
		jointParts[joint] = nil
	end
	local p0, p1 = joint.Part0, joint.Part1
	if p0 and p1 then
		jointParts[joint] = { p0, p1 }
		partJoints[p0] = partJoints[p0] or {}
		partJoints[p0][joint] = true
		partJoints[p1] = partJoints[p1] or {}
		partJoints[p1][joint] = true
	end
end

local function jointActive(joint): boolean
	local st = states[joint]
	if st and st.destroyed then
		return false
	end
	if joint.Parent == nil then
		return false
	end
	local ok, enabled = pcall(function()
		return joint.Enabled
	end)
	return not ok or enabled ~= false
end

-- Parts rigidly connected to `start` (not crossing anchored parts other than start)
local computeAssembly
local function assembly(start, exclude)
	if exclude == nil then
		local cached = assemblyCache[start]
		if cached then
			return cached[1], cached[2]
		end
		local list, seen = computeAssembly(start, nil)
		assemblyCache[start] = { list, seen }
		return list, seen
	end
	return computeAssembly(start, exclude)
end

computeAssembly = function(start, exclude)
	local seen = { [start] = true }
	local list = {}
	local queue = { start }
	local head = 1
	while queue[head] do
		local part = queue[head]
		head += 1
		local joints = partJoints[part]
		if joints and (part == start or not part.Anchored) then
			for joint in joints do
				if joint ~= exclude and jointActive(joint) then
					local pair = jointParts[joint]
					local other = if pair[1] == part then pair[2] else pair[1]
					if not seen[other] then
						seen[other] = true
						table.insert(list, other)
						table.insert(queue, other)
					end
				end
			end
		end
	end
	return list, seen
end

local function moveAssembly(part, delta, exclude)
	if not partJoints[part] then
		return
	end
	local list = assembly(part, exclude)
	for _, other in list do
		if not other.Anchored then
			other.CFrame = delta * other.CFrame
		end
	end
end

local function setPartCFrame(real, cf)
	local old = real.CFrame
	real.CFrame = cf
	if partJoints[real] then
		moveAssembly(real, cf * old:Inverse())
	end
end
Classes.setPartCFrame = setPartCFrame

local function snapJoint(joint)
	local pair = jointParts[joint]
	if not pair or not jointActive(joint) then
		return
	end
	local ok, c0, c1 = pcall(function()
		return joint.C0, joint.C1
	end)
	if not ok then
		return -- WeldConstraint keeps the current offset
	end
	local p0, p1 = pair[1], pair[2]
	if p1.Anchored and p0.Anchored then
		return
	end
	if p1.Anchored and not p0.Anchored then
		local target = p1.CFrame * c1 * c0:Inverse()
		local delta = target * p0.CFrame:Inverse()
		local list, seen = assembly(p0, joint)
		if seen[p1] then
			p0.CFrame = target
			return
		end
		p0.CFrame = target
		for _, other in list do
			if not other.Anchored then
				other.CFrame = delta * other.CFrame
			end
		end
		return
	end
	local target = p0.CFrame * c0 * c1:Inverse()
	local delta = target * p1.CFrame:Inverse()
	local list, seen = assembly(p1, joint)
	p1.CFrame = target
	if seen[p0] then
		return
	end
	for _, other in list do
		if not other.Anchored then
			other.CFrame = delta * other.CFrame
		end
	end
end

local function isJoint(real)
	return jointClasses[real.ClassName] == true
end

table.insert(I.onEnterGame, function(real, moved)
	if isJoint(real) then
		linkJoint(real)
		if I.booted and not moved then
			snapJoint(real)
		end
	end
end)
table.insert(I.onCreate, function(real)
	if jointClasses[real.ClassName] then
		linkJoint(real)
	end
end)
for _, name in { "Part0", "Part1" } do
	I.onPropSet[name] = I.onPropSet[name] or {}
	table.insert(I.onPropSet[name], function(real)
		if isJoint(real) then
			linkJoint(real)
			snapJoint(real)
		end
	end)
end
table.insert(I.onLeaveGame, function(real)
	if jointClasses[real.ClassName] then
		bumpJoints()
	end
end)
I.onPropSet.Enabled = I.onPropSet.Enabled or {}
table.insert(I.onPropSet.Enabled, function(real)
	if jointClasses[real.ClassName] then
		bumpJoints()
	end
end)
for _, name in { "C0", "C1", "Enabled" } do
	I.onPropSet[name] = I.onPropSet[name] or {}
	table.insert(I.onPropSet[name], function(real)
		if isJoint(real) then
			snapJoint(real)
		end
	end)
end

Classes.partJoints = partJoints

-- A client writing to a replicated part only changes its own view, except for parts of its
-- own character (the client owns their physics in Roblox).
local function localWriter(real, st)
	local ctx = Runtime.ctx
	if not ctx or ctx.kind ~= "client" or st.owner == ctx then
		return nil
	end
	local character = ctx.player and ctx.player.Character
	if character and (real == character or real:IsDescendantOf(character)) then
		return nil
	end
	return ctx
end
Classes.localWriter = localWriter

local function overlayGet(st, key)
	local ctx = Runtime.ctx
	if ctx and st.overlay and st.overlay[ctx] then
		return st.overlay[ctx][key]
	end
	return nil
end

local function overlaySet(st, ctx, key, value)
	st.overlay = st.overlay or {}
	st.overlay[ctx] = st.overlay[ctx] or {}
	st.overlay[ctx][key] = value
end

local function clearOverlay(st, key)
	if st.overlay then
		for _, overlay in st.overlay do
			overlay[key] = nil
		end
	end
end

local function currentCFrame(real, st)
	return overlayGet(st, "CFrame") or real.CFrame
end
Classes.currentCFrame = currentCFrame

-- Write a part's CFrame from game code (respects client-local writes, moves assemblies)
local function writeCFrame(real, st, cf, key)
	local ctx = localWriter(real, st)
	if ctx then
		overlaySet(st, ctx, "CFrame", cf)
		I.firePropChanged(real, st, key or "CFrame", ctx)
		return
	end
	clearOverlay(st, "CFrame")
	setPartCFrame(real, cf)
	Classes.partMoved(real)
	I.firePropChanged(real, st, key or "CFrame")
end
Classes.writeCFrame = writeCFrame

prop("BasePart", "CFrame", function(real, st)
	return currentCFrame(real, st)
end, function(real, st, value)
	if typeof(value) ~= "CFrame" then
		error("Unable to assign property CFrame. CFrame expected, got " .. typeof(value), 3)
	end
	if value.Position.X ~= value.Position.X then
		Runtime.note("NaN CFrame assigned to " .. I.fullName(real))
	end
	writeCFrame(real, st, value)
end)
prop("BasePart", "Position", function(real, st)
	return currentCFrame(real, st).Position
end, function(real, st, value)
	if typeof(value) ~= "Vector3" then
		error("Unable to assign property Position. Vector3 expected, got " .. typeof(value), 3)
	end
	local ctx = localWriter(real, st)
	local cf = CFrame.new(value) * currentCFrame(real, st).Rotation
	if ctx then
		overlaySet(st, ctx, "CFrame", cf)
		I.firePropChanged(real, st, "Position", ctx)
		return
	end
	clearOverlay(st, "CFrame")
	real.CFrame = cf -- Position moves only this part (WeldConstraint semantics)
	Classes.partMoved(real)
	I.firePropChanged(real, st, "Position")
end)
local function orientationOf(cf)
	local x, y, z = cf:ToOrientation()
	return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
end
prop("BasePart", "Orientation", function(real, st)
	return orientationOf(currentCFrame(real, st))
end, function(real, st, value)
	local cf = currentCFrame(real, st)
	writeCFrame(real, st, CFrame.new(cf.Position) * CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z)), "Orientation")
end)
prop("BasePart", "Rotation", function(real, st)
	local x, y, z = currentCFrame(real, st):ToEulerAnglesXYZ()
	return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
end, function(real, st, value)
	local cf = currentCFrame(real, st)
	writeCFrame(real, st, CFrame.new(cf.Position) * CFrame.Angles(math.rad(value.X), math.rad(value.Y), math.rad(value.Z)), "Rotation")
end)
prop("BasePart", "Size", function(real, st)
	return overlayGet(st, "Size") or real.Size
end, function(real, st, value)
	if typeof(value) ~= "Vector3" then
		error("Unable to assign property Size. Vector3 expected, got " .. typeof(value), 3)
	end
	local ctx = localWriter(real, st)
	if ctx then
		overlaySet(st, ctx, "Size", value)
		I.firePropChanged(real, st, "Size", ctx)
		return
	end
	clearOverlay(st, "Size")
	real.Size = value
	Classes.partMoved(real)
	I.firePropChanged(real, st, "Size")
end)
prop("BasePart", "Anchored", function(real, st)
	local v = overlayGet(st, "Anchored")
	if v ~= nil then
		return v
	end
	return real.Anchored
end, function(real, st, value)
	local ctx = localWriter(real, st)
	if ctx then
		overlaySet(st, ctx, "Anchored", value == true)
		return
	end
	clearOverlay(st, "Anchored")
	if real.Anchored ~= (value == true) then
		bumpJoints()
	end
	real.Anchored = value == true
	Classes.partMoved(real)
	I.firePropChanged(real, st, "Anchored")
end)
Classes.partMoved = function() end -- replaced by Physics

local function virtualVector(name)
	prop("BasePart", name, function(_real, st)
		return st.virtual and st.virtual[name] or Vector3.zero
	end, function(_real, st, value)
		st.virtual = st.virtual or {}
		st.virtual[name] = value
	end)
end
virtualVector("AssemblyLinearVelocity")
virtualVector("AssemblyAngularVelocity")
virtualVector("Velocity")
virtualVector("RotVelocity")

prop("BasePart", "BrickColor", function(real)
	return roblox.BrickColor.new(real.Color)
end, function(real, _st, value)
	if typeof(value) ~= "BrickColor" then
		error("Unable to assign property BrickColor. BrickColor expected, got " .. typeof(value), 3)
	end
	real.Color = value.Color
end)
prop("BasePart", "Mass", function(real)
	local s = real.Size
	return s.X * s.Y * s.Z * 0.7
end)
prop("BasePart", "AssemblyMass", function(real)
	local s = real.Size
	return s.X * s.Y * s.Z * 0.7
end)
prop("BasePart", "AssemblyRootPart", function(real)
	return wrap(real)
end)
prop("BasePart", "AssemblyCenterOfMass", function(real)
	return real.CFrame.Position
end)

local function anchoredInAssembly(real): boolean
	if real.Anchored then
		return true
	end
	local _, seen = assembly(real)
	for part in seen do
		if part.Anchored then
			return true
		end
	end
	return false
end

method("BasePart", "SetNetworkOwner", function(self, player)
	local real = selfReal(self, "SetNetworkOwner")
	if anchoredInAssembly(real) then
		error("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.", 2)
	end
	states[real].networkOwner = unwrap(player)
end)
method("BasePart", "SetNetworkOwnershipAuto", function(self)
	local real = selfReal(self, "SetNetworkOwnershipAuto")
	if anchoredInAssembly(real) then
		error("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.", 2)
	end
end)
method("BasePart", "GetNetworkOwner", function(self)
	return wrap(states[selfReal(self, "GetNetworkOwner")].networkOwner)
end)
method("BasePart", "CanSetNetworkOwnership", function(self)
	local real = selfReal(self, "CanSetNetworkOwnership")
	if anchoredInAssembly(real) then
		return false, "Cannot change network ownership of anchored parts"
	end
	return true
end)
method("BasePart", "GetMass", function(self)
	local s = selfReal(self, "GetMass").Size
	return s.X * s.Y * s.Z * 0.7
end)
method("BasePart", "GetConnectedParts", function(self)
	local list = assembly(selfReal(self, "GetConnectedParts"))
	return I.wrapList(list)
end)
method("BasePart", "GetJoints", function(self)
	local out = {}
	for joint in partJoints[selfReal(self, "GetJoints")] or {} do
		table.insert(out, wrap(joint))
	end
	return out
end)
method("BasePart", "GetTouchingParts", function()
	return {}
end)
method("BasePart", "ApplyImpulse", function(self, impulse)
	local real = selfReal(self, "ApplyImpulse")
	local st = states[real]
	st.virtual = st.virtual or {}
	st.virtual.AssemblyLinearVelocity = (st.virtual.AssemblyLinearVelocity or Vector3.zero) + impulse / math.max(1, real.Size.Magnitude)
end)
method("BasePart", "ApplyAngularImpulse", function() end)
method("BasePart", "GetRootPart", function(self)
	return self
end)
method("BasePart", "BreakJoints", function(self)
	local real = selfReal(self, "BreakJoints")
	for joint in table.clone(partJoints[real] or {}) do
		I.destroy(joint, { force = true })
	end
end)
method("BasePart", "Resize", function()
	return true
end)
method("BasePart", "GetPivot", function(self)
	local real = selfReal(self, "GetPivot")
	return currentCFrame(real, states[real]) * real.PivotOffset
end)
method("BasePart", "PivotTo", function(self, target)
	local real = selfReal(self, "PivotTo")
	if typeof(target) ~= "CFrame" then
		error("Unable to cast to CFrame", 2)
	end
	writeCFrame(real, states[real], target * real.PivotOffset:Inverse())
end)

-- Models
local function modelParts(real)
	local parts = {}
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end
Classes.modelParts = modelParts

local function boundsIn(parts, orientation)
	local inv = orientation:Inverse()
	local minV, maxV
	for _, part in parts do
		local cf, size = part.CFrame, part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local world = cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz)
					local localP = inv * world
					if minV then
						minV = minV:Min(localP)
						maxV = maxV:Max(localP)
					else
						minV, maxV = localP, localP
					end
				end
			end
		end
	end
	if not minV then
		return orientation, Vector3.zero
	end
	local center = orientation * ((minV + maxV) / 2)
	return CFrame.new(center) * orientation.Rotation, maxV - minV
end

local function worldPivot(real, st)
	local ok, pivot = pcall(function()
		return real.WorldPivot
	end)
	if ok and pivot then
		return pivot
	end
	if st.virtual and st.virtual.WorldPivot then
		return st.virtual.WorldPivot
	end
	local cf = boundsIn(modelParts(real), CFrame.identity)
	return cf
end

local function modelPivot(real)
	local st = states[real] or I.getState(real)
	local primary = real.PrimaryPart
	if primary then
		return currentCFrame(primary, states[primary] or I.getState(primary)) * primary.PivotOffset
	end
	local localPivot = overlayGet(st, "WorldPivot")
	if localPivot then
		return localPivot
	end
	return worldPivot(real, st)
end
Classes.modelPivot = modelPivot

local function pivotModel(real, target)
	local current = modelPivot(real)
	local delta = target * current:Inverse()
	local parts = modelParts(real)
	local mst = states[real] or I.getState(real)
	local writer = localWriter(real, mst)
	if writer then
		for _, part in parts do
			local pst = states[part] or I.getState(part)
			overlaySet(pst, writer, "CFrame", delta * currentCFrame(part, pst))
		end
		overlaySet(mst, writer, "WorldPivot", target)
		return
	end
	local moved = {}
	for _, part in parts do
		moved[part] = true
		part.CFrame = delta * part.CFrame
	end
	-- welded parts outside the model follow (e.g. something welded to a character)
	for _, part in parts do
		if partJoints[part] then
			local list = assembly(part)
			for _, other in list do
				if not moved[other] and not other.Anchored then
					moved[other] = true
					other.CFrame = delta * other.CFrame
				end
			end
		end
	end
	local st = states[real]
	local ok = pcall(function()
		real.WorldPivot = delta * worldPivot(real, st)
	end)
	if not ok and st then
		st.virtual = st.virtual or {}
		st.virtual.WorldPivot = target
	end
	for part in moved do
		Classes.partMoved(part)
	end
end
Classes.pivotModel = pivotModel

method("Model", "GetPivot", function(self)
	return modelPivot(selfReal(self, "GetPivot"))
end)
method("Model", "PivotTo", function(self, target)
	if typeof(target) ~= "CFrame" then
		error("Unable to cast to CFrame", 2)
	end
	pivotModel(selfReal(self, "PivotTo"), target)
end)
prop("Model", "WorldPivot", function(real, st)
	return worldPivot(real, st)
end, function(real, st, value)
	if not pcall(function()
		real.WorldPivot = value
	end) then
		st.virtual = st.virtual or {}
		st.virtual.WorldPivot = value
	end
end)
method("Model", "GetBoundingBox", function(self)
	local real = selfReal(self, "GetBoundingBox")
	return boundsIn(modelParts(real), modelPivot(real).Rotation)
end)
method("Model", "GetExtentsSize", function(self)
	local real = selfReal(self, "GetExtentsSize")
	local _, size = boundsIn(modelParts(real), modelPivot(real).Rotation)
	return size
end)
method("Model", "GetScale", function(self)
	local st = states[selfReal(self, "GetScale")]
	return st.virtual and st.virtual.Scale or 1
end)
method("Model", "ScaleTo", function(self, scale)
	local real = selfReal(self, "ScaleTo")
	local st = states[real]
	if type(scale) ~= "number" or scale <= 0 then
		error("Model:ScaleTo scale must be positive", 2)
	end
	local current = st.virtual and st.virtual.Scale or 1
	local factor = scale / current
	local pivot = modelPivot(real)
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			local offset = pivot:ToObjectSpace(d.CFrame)
			d.Size = d.Size * factor
			d.CFrame = pivot * (CFrame.new(offset.Position * factor) * offset.Rotation)
		elseif d:IsA("Attachment") then
			d.CFrame = CFrame.new(d.CFrame.Position * factor) * d.CFrame.Rotation
		elseif d:IsA("SpecialMesh") then
			d.Scale = d.Scale * factor
		elseif d:IsA("JointInstance") then
			d.C0 = CFrame.new(d.C0.Position * factor) * d.C0.Rotation
			d.C1 = CFrame.new(d.C1.Position * factor) * d.C1.Rotation
		end
	end
	st.virtual = st.virtual or {}
	st.virtual.Scale = scale
end)
method("Model", "MoveTo", function(self, position)
	local real = selfReal(self, "MoveTo")
	local pivot = modelPivot(real)
	pivotModel(real, CFrame.new(position) * pivot.Rotation)
end)
method("Model", "TranslateBy", function(self, delta)
	local real = selfReal(self, "TranslateBy")
	pivotModel(real, modelPivot(real) + delta)
end)
method("Model", "SetPrimaryPartCFrame", function(self, cf)
	local real = selfReal(self, "SetPrimaryPartCFrame")
	if not real.PrimaryPart then
		error("Model:SetPrimaryPartCFrame() failed because no PrimaryPart has been set", 2)
	end
	pivotModel(real, cf * real.PrimaryPart.PivotOffset)
end)
method("Model", "GetPrimaryPartCFrame", function(self)
	local real = selfReal(self, "GetPrimaryPartCFrame")
	return real.PrimaryPart and real.PrimaryPart.CFrame or CFrame.identity
end)
method("Model", "BreakJoints", function() end)
method("Model", "MakeJoints", function() end)

-- Attachments
local function attachmentParentCFrame(real)
	local parent = real.Parent
	if parent and parent:IsA("BasePart") then
		return parent.CFrame
	end
	return CFrame.identity
end
prop("Attachment", "WorldCFrame", function(real)
	return attachmentParentCFrame(real) * real.CFrame
end, function(real, _st, value)
	real.CFrame = attachmentParentCFrame(real):Inverse() * value
end)
prop("Attachment", "WorldPosition", function(real)
	return (attachmentParentCFrame(real) * real.CFrame).Position
end, function(real, _st, value)
	real.CFrame = CFrame.new(attachmentParentCFrame(real):PointToObjectSpace(value)) * real.CFrame.Rotation
end)
prop("Attachment", "Position", function(real)
	return real.CFrame.Position
end, function(real, _st, value)
	real.CFrame = CFrame.new(value) * real.CFrame.Rotation
end)
prop("Attachment", "Orientation", function(real)
	return orientationOf(real.CFrame)
end, function(real, _st, value)
	real.CFrame = CFrame.new(real.CFrame.Position) * CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z))
end)
prop("Attachment", "WorldOrientation", function(real)
	return orientationOf(attachmentParentCFrame(real) * real.CFrame)
end)
prop("Attachment", "Axis", function(real)
	return real.CFrame.RightVector
end)
prop("Attachment", "WorldAxis", function(real)
	return (attachmentParentCFrame(real) * real.CFrame).RightVector
end)

-- GUI geometry -----------------------------------------------------------------------------

local function viewportOf(ctx)
	return (ctx and ctx.viewport) or S.defaultViewport
end
Classes.viewportOf = viewportOf

local function absSize(real, ctx)
	local class = real.ClassName
	if class == "ScreenGui" then
		return viewportOf(ctx)
	end
	if real:IsA("BillboardGui") or real:IsA("SurfaceGui") then
		local size = real.Size
		return Vector2.new(size.X.Offset + size.X.Scale * 50, size.Y.Offset + size.Y.Scale * 50)
	end
	if not real:IsA("GuiObject") then
		return viewportOf(ctx)
	end
	local parent = real.Parent
	local parentSize = if parent and parent:IsA("GuiBase2d") then absSize(parent, ctx) else viewportOf(ctx)
	local size = real.Size
	local w = parentSize.X * size.X.Scale + size.X.Offset
	local h = parentSize.Y * size.Y.Scale + size.Y.Offset
	for _, child in real:GetChildren() do
		if child.ClassName == "UIAspectRatioConstraint" then
			local ratio = child.AspectRatio
			if w / math.max(h, 1e-6) > ratio then
				w = h * ratio
			else
				h = w / ratio
			end
		elseif child.ClassName == "UISizeConstraint" then
			local minS, maxS = child.MinSize, child.MaxSize
			w = math.clamp(w, minS.X, math.max(minS.X, maxS.X))
			h = math.clamp(h, minS.Y, math.max(minS.Y, maxS.Y))
		end
	end
	return Vector2.new(math.max(w, 0), math.max(h, 0))
end
Classes.absSize = absSize

local function absPosition(real, ctx)
	if real.ClassName == "ScreenGui" or not real:IsA("GuiObject") then
		return Vector2.zero
	end
	local parent = real.Parent
	local parentSize = if parent and parent:IsA("GuiBase2d") then absSize(parent, ctx) else viewportOf(ctx)
	local parentPos = if parent and parent:IsA("GuiObject") then absPosition(parent, ctx) else Vector2.zero
	local pos, size, anchor = real.Position, absSize(real, ctx), real.AnchorPoint
	return Vector2.new(
		parentPos.X + parentSize.X * pos.X.Scale + pos.X.Offset - anchor.X * size.X,
		parentPos.Y + parentSize.Y * pos.Y.Scale + pos.Y.Offset - anchor.Y * size.Y
	)
end

prop("GuiBase2d", "AbsoluteSize", function(real)
	return absSize(real, Runtime.ctx)
end)
prop("GuiBase2d", "AbsolutePosition", function(real)
	return absPosition(real, Runtime.ctx)
end)
prop("GuiBase2d", "AbsoluteRotation", function(real)
	return if real:IsA("GuiObject") then real.Rotation else 0
end)
local function textBounds(real)
	local text = real.Text
	local size = real.TextSize
	local longest, lines = 0, 0
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		lines += 1
		longest = math.max(longest, utf8.len(line) or #line)
	end
	return Vector2.new(longest * size * 0.55, lines * size)
end
for _, class in { "TextLabel", "TextButton", "TextBox" } do
	prop(class, "TextBounds", textBounds)
	prop(class, "TextFits", function()
		return true
	end)
	prop(class, "ContentText", function(real)
		return real.Text
	end)
end
prop("ScrollingFrame", "AbsoluteCanvasSize", function(real)
	return absSize(real, Runtime.ctx)
end)
prop("ScrollingFrame", "AbsoluteWindowSize", function(real)
	return absSize(real, Runtime.ctx)
end)
prop("UIGridStyleLayout", "AbsoluteContentSize", function(real)
	local parent = real.Parent
	if not parent or not parent:IsA("GuiBase2d") then
		return Vector2.zero
	end
	local ctx = Runtime.ctx
	local w, h = 0, 0
	local horizontal = real.FillDirection == roblox.Enum.FillDirection.Horizontal
	for _, child in I.children(parent, ctx) do
		if child:IsA("GuiObject") and child.Visible then
			local s = absSize(child, ctx)
			if horizontal then
				w += s.X
				h = math.max(h, s.Y)
			else
				h += s.Y
				w = math.max(w, s.X)
			end
		end
	end
	return Vector2.new(w, h)
end)
prop("UIGridLayout", "AbsoluteCellSize", function(real)
	return Vector2.new(real.CellSize.X.Offset, real.CellSize.Y.Offset)
end)
prop("UIGridLayout", "AbsoluteCellCount", function()
	return Vector2.new(4, 4)
end)
prop("GuiObject", "GuiState", function()
	return roblox.Enum.GuiState.Idle
end)

for _, name in {
	"InputBegan",
	"InputEnded",
	"InputChanged",
	"MouseEnter",
	"MouseLeave",
	"MouseMoved",
	"MouseWheelForward",
	"MouseWheelBackward",
	"SelectionGained",
	"SelectionLost",
	"SelectionChanged",
	"TouchTap",
	"TouchLongPress",
	"TouchPan",
	"TouchSwipe",
} do
	event("GuiObject", name)
end
for _, name in {
	"Activated",
	"MouseButton1Click",
	"MouseButton1Down",
	"MouseButton1Up",
	"MouseButton2Click",
	"MouseButton2Down",
	"MouseButton2Up",
} do
	event("GuiButton", name)
end
event("TextBox", "FocusLost")
event("TextBox", "Focused")
event("TextBox", "ReturnPressedFromOnScreenKeyboard")
method("TextBox", "CaptureFocus", function() end)
method("TextBox", "ReleaseFocus", function() end)
method("TextBox", "IsFocused", function()
	return false
end)
local function tweenGui(real, props, callback)
	for k, v in props do
		real[k] = v
	end
	if callback then
		Runtime.task.defer(callback, roblox.Enum.TweenStatus.Completed)
	end
	return true
end
method("GuiObject", "TweenPosition", function(self, position, _dir, _style, _time, _override, callback)
	return tweenGui(selfReal(self, "TweenPosition"), { Position = position }, callback)
end)
method("GuiObject", "TweenSize", function(self, size, _dir, _style, _time, _override, callback)
	return tweenGui(selfReal(self, "TweenSize"), { Size = size }, callback)
end)
method("GuiObject", "TweenSizeAndPosition", function(self, size, position, _dir, _style, _time, _override, callback)
	return tweenGui(selfReal(self, "TweenSizeAndPosition"), { Size = size, Position = position }, callback)
end)
event("ScrollingFrame", "CanvasPositionChanged")

-- Camera
prop("Camera", "ViewportSize", function()
	return viewportOf(Runtime.ctx)
end)
local function project(real, point)
	local cf = real.CFrame
	local viewport = viewportOf(Runtime.ctx)
	local rel = cf:PointToObjectSpace(point)
	local depth = -rel.Z
	local fov = math.rad(real.FieldOfView)
	local scale = (viewport.Y / 2) / math.tan(fov / 2)
	if depth <= 0.01 then
		return Vector3.new(viewport.X / 2, viewport.Y / 2, depth), false
	end
	local x = viewport.X / 2 + rel.X / depth * scale
	local y = viewport.Y / 2 - rel.Y / depth * scale
	local onScreen = x >= 0 and y >= 0 and x <= viewport.X and y <= viewport.Y
	return Vector3.new(x, y, depth), onScreen
end
method("Camera", "WorldToViewportPoint", function(self, point)
	return project(selfReal(self, "WorldToViewportPoint"), point)
end)
method("Camera", "WorldToScreenPoint", function(self, point)
	return project(selfReal(self, "WorldToScreenPoint"), point)
end)
local function rayFrom(real, x, y, depth)
	local cf = real.CFrame
	local viewport = viewportOf(Runtime.ctx)
	local fov = math.rad(real.FieldOfView)
	local scale = (viewport.Y / 2) / math.tan(fov / 2)
	local dir = cf:VectorToWorldSpace(Vector3.new((x - viewport.X / 2) / scale, -(y - viewport.Y / 2) / scale, -1).Unit)
	return roblox.Ray.new(cf.Position, dir * (depth or 1))
end
method("Camera", "ViewportPointToRay", function(self, x, y, depth)
	return rayFrom(selfReal(self, "ViewportPointToRay"), x, y, depth)
end)
method("Camera", "ScreenPointToRay", function(self, x, y, depth)
	return rayFrom(selfReal(self, "ScreenPointToRay"), x, y, depth)
end)
method("Camera", "GetPartsObscuringTarget", function()
	return {}
end)
method("Camera", "ZoomToExtents", function() end)

-- Remotes and bindables -------------------------------------------------------------------

local function isArray(t): boolean
	local n = #t
	local count = 0
	for _ in t do
		count += 1
	end
	return count == n
end

-- Copy a value the way Roblox serializes remote arguments
local function serialize(value, toCtx, path, seen)
	local t = typeof(value)
	if t == "Instance" then
		local real = unwrap(value)
		if I.visibleDeep(real, toCtx) and not (toCtx.kind == "client" and I.isServerOnly(real)) then
			return value
		end
		return nil
	elseif t == "function" then
		Runtime.note("remote argument " .. path .. " is a function (dropped)")
		return nil
	elseif t == "table" then
		if Runtime.isSignal(value) or Runtime.isConnection(value) then
			Runtime.note("remote argument " .. path .. " is a signal/connection (dropped)")
			return nil
		end
		seen = seen or {}
		if seen[value] then
			error("Tables with cyclic references cannot be sent over remotes (" .. path .. ")", 0)
		end
		seen[value] = true
		local out = {}
		if getmetatable(value) ~= nil then
			Runtime.note("remote argument " .. path .. " has a metatable (stripped)")
		end
		if value[1] ~= nil then
			if not isArray(value) then
				Runtime.note("remote argument " .. path .. " is a mixed/sparse table; non-array keys are lost")
			end
			for i = 1, #value do
				out[i] = serialize(value[i], toCtx, path .. "[" .. i .. "]", seen)
			end
		else
			for k, v in value do
				local key = k
				if type(k) ~= "string" then
					Runtime.note(
						"remote argument " .. path .. " has a " .. typeof(k) .. " key " .. tostring(k) .. " (converted to string)"
					)
					key = tostring(k)
				end
				out[key] = serialize(v, toCtx, path .. "." .. key, seen)
			end
		end
		seen[value] = nil
		return out
	elseif t == "userdata" then
		Runtime.note("remote argument " .. path .. " is userdata (dropped)")
		return nil
	end
	return value
end
Classes.serialize = serialize

local function serializeArgs(args, toCtx, label)
	local out = { n = args.n }
	for i = 1, args.n do
		out[i] = serialize(args[i], toCtx, label .. " arg" .. i)
	end
	return out
end

local function deliverServerEvent(real, st, player, args)
	if player.Parent == nil then
		return
	end
	local signal = I.getSignal(real, st, "OnServerEvent")
	local hasServer = false
	for _, c in signal._conns do
		if c._ctx == S.server then
			hasServer = true
			break
		end
	end
	if not hasServer then
		st.serverQueue = st.serverQueue or {}
		table.insert(st.serverQueue, { player = player, args = args })
		if #st.serverQueue == 64 then
			Runtime.print("WARN", "Remote event invocation queue exhausted for " .. I.fullName(real))
		end
		return
	end
	signal:FireFiltered(function(c)
		return c == S.server
	end, wrap(player), table.unpack(args, 1, args.n))
end

local function deliverClientEvent(real, st, ctx, args)
	if ctx.dead then
		return
	end
	local signal = I.getSignal(real, st, "OnClientEvent")
	local has = false
	for _, c in signal._conns do
		if c._ctx == ctx then
			has = true
			break
		end
	end
	if not has then
		st.clientQueue = st.clientQueue or {}
		st.clientQueue[ctx] = st.clientQueue[ctx] or {}
		table.insert(st.clientQueue[ctx], args)
		return
	end
	signal:FireFiltered(function(c)
		return c == ctx
	end, table.unpack(args, 1, args.n))
end

local function remoteEventClass(class)
	event(class, "OnServerEvent", nil, function(real, st, connection)
		if connection._ctx ~= S.server then
			Runtime.note("OnServerEvent connected from a client on " .. I.fullName(real))
			return
		end
		local queue = st.serverQueue
		if queue then
			st.serverQueue = nil
			for _, entry in queue do
				Runtime.delayIn(S.server, 0, deliverServerEvent, real, st, entry.player, entry.args)
			end
		end
	end)
	event(class, "OnClientEvent", nil, function(real, st, connection)
		local ctx = connection._ctx
		if not ctx or ctx.kind ~= "client" then
			Runtime.note("OnClientEvent connected from the server on " .. I.fullName(real))
			return
		end
		local queue = st.clientQueue and st.clientQueue[ctx]
		if queue then
			st.clientQueue[ctx] = nil
			for _, args in queue do
				Runtime.delayIn(ctx, 0, deliverClientEvent, real, st, ctx, args)
			end
		end
	end)
	method(class, "FireServer", function(self, ...)
		local real = selfReal(self, "FireServer")
		local ctx = Runtime.ctx
		if not ctx or ctx.kind ~= "client" then
			error("FireServer can only be called from the client", 2)
		end
		local args = serializeArgs(table.pack(...), S.server, real.Name .. ":FireServer")
		local player = ctx.player
		Runtime.delayIn(S.server, S.latency, deliverServerEvent, real, states[real], player, args)
	end)
	method(class, "FireClient", function(self, player, ...)
		local real = selfReal(self, "FireClient")
		local ctx = Runtime.ctx
		if ctx and ctx.kind == "client" then
			error("FireClient can only be called from the server", 2)
		end
		local playerReal = unwrap(player)
		if typeof(playerReal) ~= "Instance" or not playerReal:IsA("Player") then
			error("FireClient: player argument must be a Player object", 2)
		end
		local target = S.clients[playerReal]
		if not target then
			return
		end
		local args = serializeArgs(table.pack(...), target, real.Name .. ":FireClient")
		Runtime.delayIn(target, S.latency, deliverClientEvent, real, states[real], target, args)
	end)
	method(class, "FireAllClients", function(self, ...)
		local real = selfReal(self, "FireAllClients")
		local ctx = Runtime.ctx
		if ctx and ctx.kind == "client" then
			error("FireAllClients can only be called from the server", 2)
		end
		local packed = table.pack(...)
		for playerReal, target in S.clients do
			if playerReal.Parent ~= nil then
				local args = serializeArgs(packed, target, real.Name .. ":FireAllClients")
				Runtime.delayIn(target, S.latency, deliverClientEvent, real, states[real], target, args)
			end
		end
	end)
end
remoteEventClass("RemoteEvent")
remoteEventClass("UnreliableRemoteEvent")

prop("RemoteFunction", "OnServerInvoke", function()
	error("OnServerInvoke is a callback member of RemoteFunction; you can only set the callback value, get is not available", 3)
end, function(_real, st, value)
	st.onServerInvoke = value
end)
prop("RemoteFunction", "OnClientInvoke", function()
	error("OnClientInvoke is a callback member of RemoteFunction; you can only set the callback value, get is not available", 3)
end, function(_real, st, value)
	st.onClientInvoke = st.onClientInvoke or {}
	st.onClientInvoke[Runtime.ctx] = value
end)

method("RemoteFunction", "InvokeServer", function(self, ...)
	local real = selfReal(self, "InvokeServer")
	local st = states[real]
	local ctx = Runtime.ctx
	if not ctx or ctx.kind ~= "client" then
		error("InvokeServer can only be called from the client", 2)
	end
	local thread = coroutine.running()
	local args = serializeArgs(table.pack(...), S.server, real.Name .. ":InvokeServer")
	local player = ctx.player
	Runtime.delayIn(S.server, S.latency, function()
		local waited = 0
		while not st.onServerInvoke do
			Runtime.task.wait()
			waited += 1
			if waited == 150 then
				Runtime.print("WARN", "InvokeServer on " .. real.Name .. " is waiting for OnServerInvoke to be set")
			end
		end
		local results = table.pack(pcall(st.onServerInvoke, wrap(player), table.unpack(args, 1, args.n)))
		if not results[1] then
			Runtime.print("ERROR", "OnServerInvoke " .. real.Name .. " errored: " .. tostring(results[2]))
		end
		local out
		if results[1] then
			out = { ok = true, values = serializeArgs(table.pack(select(2, table.unpack(results, 1, results.n))), ctx, real.Name .. " return") }
		else
			out = { ok = false, message = tostring(results[2]) }
		end
		Runtime.delayIn(ctx, S.latency, function()
			Runtime.resume(thread, out)
		end)
	end)
	local out = Runtime.suspend()
	if not out.ok then
		error(out.message, 2)
	end
	return table.unpack(out.values, 1, out.values.n)
end)

method("RemoteFunction", "InvokeClient", function(self, player, ...)
	local real = selfReal(self, "InvokeClient")
	local st = states[real]
	local target = S.clients[unwrap(player)]
	if not target then
		error("InvokeClient: player is not connected", 2)
	end
	local callbacks = st.onClientInvoke
	local callback = callbacks and callbacks[target]
	if not callback then
		error("InvokeClient: client has no OnClientInvoke", 2)
	end
	Runtime.task.wait(S.latency)
	local results = table.pack(callback(...))
	Runtime.task.wait(S.latency)
	return table.unpack(results, 1, results.n)
end)

event("BindableEvent", "Event")
method("BindableEvent", "Fire", function(self, ...)
	I.fire(selfReal(self, "Fire"), "Event", ...)
end)
prop("BindableFunction", "OnInvoke", function()
	error("OnInvoke is a callback member of BindableFunction; you can only set the callback value, get is not available", 3)
end, function(_real, st, value)
	st.onInvoke = value
end)
method("BindableFunction", "Invoke", function(self, ...)
	local st = states[selfReal(self, "Invoke")]
	while not st.onInvoke do
		Runtime.task.wait()
	end
	return st.onInvoke(...)
end)

-- Prompts, sounds, effects, animation ------------------------------------------------------

for _, name in { "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "PromptShown", "PromptHidden" } do
	event("ProximityPrompt", name)
end
method("ProximityPrompt", "InputHoldBegin", function() end)
method("ProximityPrompt", "InputHoldEnd", function() end)
event("ClickDetector", "MouseClick")
event("ClickDetector", "MouseHoverEnter")
event("ClickDetector", "MouseHoverLeave")

local function soundState(st)
	st.sound = st.sound or { playing = false, paused = false, generation = 0 }
	return st.sound
end
method("Sound", "Play", function(self)
	local real = selfReal(self, "Play")
	local st = states[real]
	local s = soundState(st)
	s.playing, s.paused = true, false
	s.generation += 1
	local generation = s.generation
	I.fire(real, "Played", I.get(real, "SoundId"))
	if not real.Looped then
		Runtime.delayIn(Runtime.ctx, 1, function()
			if s.generation == generation and s.playing then
				s.playing = false
				I.fire(real, "Ended", I.get(real, "SoundId"))
			end
		end)
	end
end)
method("Sound", "Stop", function(self)
	local real = selfReal(self, "Stop")
	local s = soundState(states[real])
	if s.playing then
		s.playing = false
		s.generation += 1
		I.fire(real, "Stopped", I.get(real, "SoundId"))
	end
end)
method("Sound", "Pause", function(self)
	local real = selfReal(self, "Pause")
	local s = soundState(states[real])
	s.paused = true
	s.playing = false
	I.fire(real, "Paused", I.get(real, "SoundId"))
end)
method("Sound", "Resume", function(self)
	local real = selfReal(self, "Resume")
	local s = soundState(states[real])
	s.paused = false
	s.playing = true
	I.fire(real, "Resumed", I.get(real, "SoundId"))
end)
prop("Sound", "IsPlaying", function(_real, st)
	return soundState(st).playing
end)
prop("Sound", "IsPaused", function(_real, st)
	return soundState(st).paused
end)
prop("Sound", "IsLoaded", function()
	return true
end)
prop("Sound", "TimeLength", function()
	return 1
end)
prop("Sound", "PlaybackLoudness", function()
	return 0
end)
for _, name in { "Ended", "Played", "Stopped", "Paused", "Resumed", "Loaded", "DidLoop" } do
	event("Sound", name)
end

method("ParticleEmitter", "Emit", function(self, count)
	selfReal(self, "Emit")
	if count ~= nil and type(count) ~= "number" then
		error("Emit expects a number", 2)
	end
end)
method("ParticleEmitter", "Clear", function() end)
method("Trail", "Clear", function() end)
method("Beam", "SetTextureOffset", function() end)
event("Explosion", "Hit")

-- Animation tracks
local AnimationTrack = {}
AnimationTrack.__index = AnimationTrack
function AnimationTrack:Play(_fade, _weight, speed)
	self.IsPlaying = true
	if speed then
		self.Speed = speed
	end
	self._generation += 1
	local generation = self._generation
	if not self.Looped then
		Runtime.delayIn(Runtime.ctx, self.Length / math.max(self.Speed, 0.01), function()
			if self._generation == generation and self.IsPlaying then
				self.IsPlaying = false
				self.Stopped:Fire()
				self.Ended:Fire()
			end
		end)
	end
end
function AnimationTrack:Stop()
	if self.IsPlaying then
		self.IsPlaying = false
		self._generation += 1
		self.Stopped:Fire()
		Runtime.delayIn(Runtime.ctx, 0.1, function()
			self.Ended:Fire()
		end)
	end
end
function AnimationTrack:AdjustSpeed(speed)
	self.Speed = speed
end
function AnimationTrack:AdjustWeight() end
function AnimationTrack:GetMarkerReachedSignal(name)
	return Runtime.newSignal("Marker:" .. tostring(name))
end
function AnimationTrack:GetTimeOfKeyframe()
	return 0
end
function AnimationTrack:Destroy()
	self:Stop()
end

local function loadAnimation(owner, animation)
	local animReal = unwrap(animation)
	if typeof(animReal) ~= "Instance" or not animReal:IsA("Animation") then
		error("Unable to cast value to Object", 3)
	end
	local track = setmetatable({
		Animation = animation,
		Name = animReal.Name,
		IsPlaying = false,
		Length = 1,
		Looped = false,
		Speed = 1,
		TimePosition = 0,
		WeightCurrent = 1,
		WeightTarget = 1,
		Priority = roblox.Enum.AnimationPriority.Core,
		Stopped = Runtime.newSignal("Stopped"),
		Ended = Runtime.newSignal("Ended"),
		DidLoop = Runtime.newSignal("DidLoop"),
		KeyframeReached = Runtime.newSignal("KeyframeReached"),
		_generation = 0,
		_isTrack = true,
	}, AnimationTrack)
	local st = states[owner]
	st.tracks = st.tracks or {}
	table.insert(st.tracks, track)
	return track
end
for _, class in { "Animator", "Humanoid", "AnimationController" } do
	method(class, "LoadAnimation", function(self, animation)
		return loadAnimation(selfReal(self, "LoadAnimation"), animation)
	end)
	method(class, "GetPlayingAnimationTracks", function(self)
		local out = {}
		for _, track in states[selfReal(self, "GetPlayingAnimationTracks")].tracks or {} do
			if track.IsPlaying then
				table.insert(out, track)
			end
		end
		return out
	end)
end
event("Animator", "AnimationPlayed")

-- Misc
method("DataStoreOptions", "SetExperimentalFeatures", function() end)
method("Tool", "Activate", function() end)
event("Tool", "Activated")
event("Tool", "Equipped")
event("Tool", "Unequipped")
event("Seat", "Changed")

return Classes
