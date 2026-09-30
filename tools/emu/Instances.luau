--!nocheck
-- Instance proxies. Every Roblox instance that game code touches is a userdata proxy over a
-- Lune (rbx-dom) instance. Proxies add what Lune lacks: events, yielding methods, computed
-- properties, Destroy semantics, CollectionService indexing and a light client/server split
-- (instances a client creates are invisible to the server and other clients, and property
-- or attribute writes a client makes to replicated instances stay local to that client).

local roblox = require("@lune/roblox")
local Runtime = require("./Runtime")

local db = roblox.getReflectionDatabase()
local RealInstance = roblox.Instance

local I = {}

local toProxy = {} -- real -> proxy
local toReal = setmetatable({}, { __mode = "k" }) -- proxy -> real
local states = {} -- real -> state
I.states = states
I.gameReal = nil
I.NIL = newproxy(false) -- overlay marker for a local nil

-- Class info --------------------------------------------------------------------------

local chainCache = {}
local function classChain(class: string)
	local cached = chainCache[class]
	if cached then
		return cached
	end
	local chain = {}
	local current = class
	while current and current ~= "" do
		table.insert(chain, current)
		local info = db:GetClass(current)
		current = info and info.Superclass or nil
	end
	chainCache[class] = chain
	return chain
end
I.classChain = classChain

local propCache = {}
local function propInfo(class: string, name: string)
	local key = class .. "\0" .. name
	local cached = propCache[key]
	if cached ~= nil then
		return cached or nil
	end
	for _, c in classChain(class) do
		local info = db:GetClass(c)
		local prop = info and info.Properties[name]
		if prop then
			local entry = { Datatype = prop.Datatype, Scriptability = prop.Scriptability, Tags = prop.Tags }
			propCache[key] = entry
			return entry
		end
	end
	propCache[key] = false
	return nil
end
I.propInfo = propInfo

local function classIsA(class: string, base: string): boolean
	return table.find(classChain(class), base) ~= nil
end
I.classIsA = classIsA

-- Members registry: Members[class][name] = { kind = "method"|"event"|"prop", ... }
local Members = {}
I.Members = Members
local memberCache = {}

function I.method(class: string, name: string, fn)
	Members[class] = Members[class] or {}
	Members[class][name] = { kind = "method", fn = fn }
end

function I.event(class: string, name: string, onCount, onConnect)
	Members[class] = Members[class] or {}
	Members[class][name] = { kind = "event", onCount = onCount, onConnect = onConnect }
end

-- get(real, state, proxy) / set(real, state, value, proxy)
function I.prop(class: string, name: string, get, set)
	Members[class] = Members[class] or {}
	Members[class][name] = { kind = "prop", get = get, set = set }
end

local function resolve(class: string, name: string)
	local byClass = memberCache[class]
	if not byClass then
		byClass = {}
		memberCache[class] = byClass
	end
	local cached = byClass[name]
	if cached ~= nil then
		return cached
	end
	local found = false
	for _, c in classChain(class) do
		local m = Members[c]
		if m and m[name] then
			found = m[name]
			break
		end
	end
	byClass[name] = found
	return found
end

-- State ---------------------------------------------------------------------------------

local function getState(real)
	local st = states[real]
	if not st then
		st = { class = real.ClassName }
		states[real] = st
	end
	return st
end
I.getState = getState

-- Proxies -------------------------------------------------------------------------------

local indexFn, newindexFn

local function wrap(real)
	if real == nil then
		return nil
	end
	local proxy = toProxy[real]
	if proxy then
		return proxy
	end
	proxy = newproxy(true)
	local mt = getmetatable(proxy)
	mt.__index = indexFn
	mt.__newindex = newindexFn
	mt.__type = "Instance"
	mt.__tostring = function()
		return real.Name
	end
	mt.__metatable = "The metatable is locked"
	toProxy[real] = proxy
	toReal[proxy] = real
	getState(real)
	return proxy
end
I.wrap = wrap

local function unwrap(value)
	if value == nil then
		return nil
	end
	local real = toReal[value]
	if real then
		return real
	end
	return value
end
I.unwrap = unwrap

function I.isProxy(value)
	return toReal[value] ~= nil
end

function I.realOf(proxy)
	return toReal[proxy]
end

local function selfReal(self, method: string)
	local real = toReal[self]
	if not real then
		error(string.format("Expected ':' not '.' calling member function %s", method), 3)
	end
	return real
end
I.selfReal = selfReal

function I.wrapList(list)
	local out = table.create(#list)
	for i, real in list do
		out[i] = wrap(real)
	end
	return out
end

-- Visibility ----------------------------------------------------------------------------

local function visible(real, ctx): boolean
	if ctx == nil then
		return true
	end
	local st = states[real]
	if st == nil then
		return true
	end
	if st.owner ~= nil and st.owner ~= ctx then
		return false
	end
	if st.privateTo ~= nil and ctx.kind == "client" and st.privateTo ~= ctx then
		return false
	end
	if st.hiddenFor and st.hiddenFor[ctx] then
		return false
	end
	return true
end
I.visible = visible

local hiddenCount = 0

-- Visible including every ancestor (for lookups that bypass the child tree)
local function visibleDeep(real, ctx): boolean
	if ctx == nil then
		return true
	end
	local node = real
	local checkAncestors = hiddenCount > 0 or ctx.kind == "client"
	while node do
		if not visible(node, ctx) then
			return false
		end
		if not checkAncestors then
			return true
		end
		local st = states[node]
		if st and st.serverOnly and ctx.kind == "client" and node ~= real then
			return false
		end
		node = node.Parent
	end
	return true
end
I.visibleDeep = visibleDeep

local function children(real, ctx)
	local st = states[real]
	if ctx and ctx.kind == "client" and st and st.serverOnly then
		return {}
	end
	local list = real:GetChildren()
	if ctx == nil then
		return list
	end
	local out = {}
	for _, child in list do
		if visible(child, ctx) then
			table.insert(out, child)
		end
	end
	return out
end
I.children = children

local function descendants(real, ctx, out)
	out = out or {}
	for _, child in children(real, ctx) do
		table.insert(out, child)
		descendants(child, ctx, out)
	end
	return out
end
I.descendants = descendants

local function fullName(real): string
	local parts = {}
	local node = real
	while node and node ~= I.gameReal do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, ".")
end
I.fullName = fullName

local function inGame(real): boolean
	local node = real
	while node do
		if node == I.gameReal then
			return true
		end
		node = node.Parent
	end
	return false
end
I.inGame = inGame

function I.isServerOnly(real): boolean
	local node = real
	while node do
		local st = states[node]
		if st and st.serverOnly then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Signals on instances ------------------------------------------------------------------

local function getSignal(real, st, name: string, onCount, onConnect)
	local signals = st.signals
	if not signals then
		signals = {}
		st.signals = signals
	end
	local signal = signals[name]
	if not signal then
		signal = Runtime.newSignal(name, onCount and function(n)
			onCount(real, st, n)
		end or nil)
		if onConnect then
			signal._onConnect = function(connection)
				onConnect(real, st, connection)
			end
		end
		signals[name] = signal
	end
	return signal
end
I.getSignal = getSignal

-- Fire an instance event to every context that can see the instance
function I.fire(real, name: string, ...)
	local st = states[real]
	local signal = st and st.signals and st.signals[name]
	if signal and #signal._conns > 0 then
		signal:FireFiltered(function(ctx)
			return visible(real, ctx)
		end, ...)
	end
end

function I.fireTo(real, name: string, filter, ...)
	local st = states[real]
	local signal = st and st.signals and st.signals[name]
	if signal and #signal._conns > 0 then
		signal:FireFiltered(filter, ...)
	end
end

function I.hasListeners(real, name: string): boolean
	local st = states[real]
	local signal = st and st.signals and st.signals[name]
	return signal ~= nil and #signal._conns > 0
end

local wrapValue

local function firePropChanged(real, st, name: string, onlyCtx)
	local filter = function(ctx)
		if onlyCtx then
			return ctx == onlyCtx
		end
		return visible(real, ctx)
	end
	local signals = st.signals
	if signals and signals.Changed and #signals.Changed._conns > 0 then
		if classIsA(st.class, "ValueBase") then
			if name == "Value" then
				signals.Changed:FireFiltered(filter, wrapValue(real.Value))
			end
		else
			signals.Changed:FireFiltered(filter, name)
		end
	end
	local propSignal = st.propSignals and st.propSignals[name]
	if propSignal and #propSignal._conns > 0 then
		propSignal:FireFiltered(filter)
	end
end
I.firePropChanged = firePropChanged

wrapValue = function(value)
	if typeof(value) == "Instance" then
		return wrap(value)
	end
	return value
end
I.wrapValue = wrapValue

-- Tag index -------------------------------------------------------------------------------

local tagIndex = {} -- tag -> { list = {}, pos = {} }
I.tagIndex = tagIndex
local tagSignals = {} -- tag -> { added = Signal, removed = Signal }

local function tagEntry(tag: string)
	local entry = tagIndex[tag]
	if not entry then
		entry = { list = {}, pos = {} }
		tagIndex[tag] = entry
	end
	return entry
end

function I.tagSignal(tag: string, which: string)
	local entry = tagSignals[tag]
	if not entry then
		entry = { added = Runtime.newSignal("InstanceAdded:" .. tag), removed = Runtime.newSignal("InstanceRemoved:" .. tag) }
		tagSignals[tag] = entry
	end
	return entry[which]
end

local function indexTag(real, tag: string, fireEvents: boolean)
	local entry = tagEntry(tag)
	if entry.pos[real] then
		return
	end
	table.insert(entry.list, real)
	entry.pos[real] = #entry.list
	if fireEvents then
		local signals = tagSignals[tag]
		if signals and #signals.added._conns > 0 then
			signals.added:FireFiltered(function(ctx)
				return visibleDeep(real, ctx)
			end, wrap(real))
		end
	end
end
I.indexTag = indexTag

local function unindexTag(real, tag: string, fireEvents: boolean)
	local entry = tagIndex[tag]
	if not entry then
		return
	end
	local pos = entry.pos[real]
	if not pos then
		return
	end
	local last = entry.list[#entry.list]
	entry.list[pos] = last
	entry.pos[last] = pos
	entry.list[#entry.list] = nil
	entry.pos[real] = nil
	if fireEvents then
		local signals = tagSignals[tag]
		if signals and #signals.removed._conns > 0 then
			signals.removed:FireFiltered(nil, wrap(real))
		end
	end
end
I.unindexTag = unindexTag

function I.getTagged(tag: string, ctx)
	local entry = tagIndex[tag]
	local out = {}
	if not entry then
		return out
	end
	for _, real in entry.list do
		if visibleDeep(real, ctx) then
			table.insert(out, wrap(real))
		end
	end
	return out
end

-- Hooks other modules register to observe tree changes (joints, physics grid, prompts...)
I.onEnterGame = {} -- fn(real) for each instance entering the DataModel
I.onLeaveGame = {} -- fn(real)
I.onPropSet = {} -- [propName] = { fn(real, st) }

local function walkSubtree(real, fn)
	fn(real)
	for _, d in real:GetDescendants() do
		fn(d)
	end
end
I.walkSubtree = walkSubtree

local function subtreeEntered(real)
	walkSubtree(real, function(node)
		for _, tag in node:GetTags() do
			indexTag(node, tag, true)
		end
		for _, hook in I.onEnterGame do
			hook(node)
		end
	end)
end

local function subtreeLeft(real)
	walkSubtree(real, function(node)
		for _, tag in node:GetTags() do
			unindexTag(node, tag, true)
		end
		for _, hook in I.onLeaveGame do
			hook(node)
		end
	end)
end

function I.buildIndex(gameReal)
	I.gameReal = gameReal
	for _, node in gameReal:GetDescendants() do
		for _, tag in node:GetTags() do
			indexTag(node, tag, false)
		end
		for _, hook in I.onEnterGame do
			hook(node)
		end
	end
end

-- Parenting -----------------------------------------------------------------------------

local ancestryListeners = 0
function I.trackAncestryListeners(delta)
	ancestryListeners += delta
end

local function isAncestorOf(a, b): boolean
	local node = b.Parent
	while node do
		if node == a then
			return true
		end
		node = node.Parent
	end
	return false
end

local function fireDescendantEvents(real, newParent, eventName)
	-- DescendantAdded / DescendantRemoving on every ancestor that listens
	local node = newParent
	local subtree
	while node do
		local st = states[node]
		local signal = st and st.signals and st.signals[eventName]
		if signal and #signal._conns > 0 then
			subtree = subtree or { real, table.unpack(real:GetDescendants()) }
			for _, d in subtree do
				signal:FireFiltered(function(ctx)
					return visible(d, ctx) and visible(node, ctx)
				end, wrap(d))
			end
		end
		node = node.Parent
	end
end

-- Server-authoritative parent change with all events
function I.setParent(real, newParent, opts)
	opts = opts or {}
	local st = getState(real)
	local ctx = Runtime.ctx
	if st.parentLocked and not opts.force then
		error(
			string.format(
				"The Parent property of %s is locked, current parent: NULL, new parent %s",
				real.Name,
				if newParent then newParent.Name else "NULL"
			),
			3
		)
	end
	if newParent ~= nil and typeof(newParent) ~= "Instance" then
		error("Unable to assign property Parent. Instance expected, got " .. typeof(newParent), 3)
	end
	-- A client moving a replicated instance only changes its own view
	if ctx and ctx.kind == "client" and st.owner ~= ctx and not opts.force then
		st.hiddenFor = st.hiddenFor or {}
		if newParent == nil then
			if not st.hiddenFor[ctx] then
				st.hiddenFor[ctx] = true
				hiddenCount += 1
				local oldParent = real.Parent
				if oldParent then
					I.fireTo(oldParent, "ChildRemoved", function(c)
						return c == ctx
					end, wrap(real))
				end
			end
		else
			Runtime.note(string.format("client %s reparented replicated %s locally (ignored)", ctx.label, fullName(real)))
		end
		return
	end
	if newParent == real or (newParent and isAncestorOf(real, newParent)) then
		error(
			string.format(
				"Attempt to set parent of %s to %s would result in circular reference",
				fullName(real),
				fullName(newParent)
			),
			3
		)
	end
	local oldParent = real.Parent
	if oldParent == newParent then
		return
	end
	local wasIn = oldParent ~= nil and inGame(oldParent)
	if oldParent then
		fireDescendantEvents(real, oldParent, "DescendantRemoving")
	end
	real.Parent = newParent
	local nowIn = newParent ~= nil and inGame(newParent)
	if wasIn and not nowIn then
		subtreeLeft(real)
	elseif nowIn and not wasIn then
		subtreeEntered(real)
	elseif nowIn and wasIn then
		for _, hook in I.onEnterGame do
			hook(real, true)
		end
	end
	if oldParent then
		I.fireTo(oldParent, "ChildRemoved", function(c)
			return visible(real, c)
		end, wrap(real))
	end
	if newParent then
		I.fireTo(newParent, "ChildAdded", function(c)
			return visible(real, c) and visible(newParent, c)
		end, wrap(real))
		fireDescendantEvents(real, newParent, "DescendantAdded")
	end
	if ancestryListeners > 0 then
		local parentProxy = wrap(newParent)
		walkSubtree(real, function(node)
			local nst = states[node]
			if nst and nst.signals and nst.signals.AncestryChanged then
				I.fire(node, "AncestryChanged", wrap(real), parentProxy)
			end
		end)
	end
	firePropChanged(real, st, "Parent")
end

function I.destroy(real, opts)
	opts = opts or {}
	local st = getState(real)
	local ctx = Runtime.ctx
	if st.destroyed then
		return
	end
	if ctx and ctx.kind == "client" and st.owner ~= ctx and not opts.force then
		-- Local destroy of a replicated instance: hide it for this client only
		I.setParent(real, nil)
		return
	end
	I.fire(real, "Destroying")
	for _, child in real:GetChildren() do
		I.destroy(child, { force = true, nested = true })
	end
	if real.Parent ~= nil then
		I.setParent(real, nil, { force = true })
	end
	st.destroyed = true
	st.parentLocked = true
	if st.signals then
		-- Deferred Destroying handlers still need to run; disconnect after them
		local signals = st.signals
		Runtime.deferIn(nil, function()
			for name, signal in signals do
				signal:DisconnectAll()
			end
		end)
	end
end

-- Property access -----------------------------------------------------------------------

local function rawGet(real, key)
	return real[key]
end
local function rawSet(real, key, value)
	real[key] = value
end

local virtualCache = {}
local function isVirtual(class: string, name: string): boolean
	local key = class .. "\0" .. name
	local cached = virtualCache[key]
	if cached ~= nil then
		return cached
	end
	local result = false
	local ok, probe = pcall(RealInstance.new, class)
	if ok then
		local okGet, err = pcall(rawGet, probe, name)
		if not okGet and string.find(tostring(err), "missing default value", 1, true) then
			result = true
		end
	end
	virtualCache[key] = result
	return result
end
I.isVirtual = isVirtual

-- Defaults for properties rbx-dom's database has no default for
local knownDefaults = {
	["Humanoid.Health"] = 100,
	["Humanoid.Jump"] = false,
	["Humanoid.PlatformStand"] = false,
	["Humanoid.Sit"] = false,
	["Sound.Pitch"] = 1,
	["Sound.MinDistance"] = 10,
	["Sound.MaxDistance"] = 10000,
	["Sound.EmitterSize"] = 10,
	["BasePart.Elasticity"] = 0.5,
	["BasePart.Friction"] = 0.3,
	["BaseScript.Enabled"] = true,
	["Lighting.ClockTime"] = 14,
	["Lighting.ShadowColor"] = roblox.Color3.fromRGB(178, 178, 183),
	["UICorner.CornerRadius"] = roblox.UDim.new(0, 8),
	["Camera.NearPlaneZ"] = -0.1,
	["Player.AccountAge"] = 365,
	["Player.CameraMaxZoomDistance"] = 128,
	["Player.CameraMinZoomDistance"] = 0.5,
	["Player.HealthDisplayDistance"] = 100,
	["Player.NameDisplayDistance"] = 100,
	["Sparkles.Color"] = roblox.Color3.fromRGB(144, 25, 255),
}

local defaultsByType = {
	ContentId = "",
	BrickColor = roblox.BrickColor.new("Medium stone grey"),
	Bool = false,
	Float32 = 0,
	Float64 = 0,
	Int32 = 0,
	Int64 = 0,
	String = "",
	Content = "",
	Vector3 = roblox.Vector3.zero,
	Vector2 = roblox.Vector2.zero,
	CFrame = roblox.CFrame.identity,
	Color3 = roblox.Color3.new(1, 1, 1),
	UDim2 = roblox.UDim2.new(),
	UDim = roblox.UDim.new(),
}

local function virtualGet(real, st, name: string)
	if st.virtual and st.virtual[name] ~= nil then
		return st.virtual[name]
	end
	for _, c in classChain(st.class) do
		local known = knownDefaults[c .. "." .. name]
		if known ~= nil then
			return known
		end
	end
	local info = propInfo(st.class, name)
	local datatype = info and info.Datatype or ""
	local default = defaultsByType[datatype]
	if default ~= nil then
		return default
	end
	if string.sub(datatype, 1, 5) == "Enum." then
		local enum = roblox.Enum[string.sub(datatype, 6)]
		local items = enum and enum:GetEnumItems()
		return items and items[1]
	end
	return nil
end
I.virtualGet = virtualGet

local function convertForProp(class: string, name: string, value)
	local info = propInfo(class, name)
	if not info then
		return value
	end
	local datatype = info.Datatype
	if string.sub(datatype, 1, 5) == "Enum." and (type(value) == "string" or type(value) == "number") then
		local enum = roblox.Enum[string.sub(datatype, 6)]
		for _, item in enum:GetEnumItems() do
			if item.Name == value or item.Value == value then
				return item
			end
		end
		error(string.format("Invalid value %s for enum %s", tostring(value), datatype), 4)
	end
	if datatype == "String" and type(value) == "number" then
		return tostring(value)
	end
	if (datatype == "Float32" or datatype == "Float64" or datatype == "Int32" or datatype == "Int64") and type(value) == "string" then
		local n = tonumber(value)
		if n then
			return n
		end
	end
	return value
end

local function readProperty(real, st, key, ctx)
	if ctx and ctx.kind == "client" and st.overlay then
		local overlay = st.overlay[ctx]
		if overlay then
			local v = overlay[key]
			if v ~= nil then
				if v == I.NIL then
					return nil, true
				end
				return v, true
			end
		end
	end
	local ok, value = pcall(rawGet, real, key)
	if ok then
		return value, true
	end
	local message = tostring(value)
	if string.find(message, "missing default value", 1, true) then
		return virtualGet(real, st, key), true
	end
	return message, false
end
-- Read a property as the server would see it (with defaults for unset properties)
function I.get(real, key)
	local value, ok = readProperty(real, getState(real), key, nil)
	if not ok then
		error(value, 2)
	end
	return value
end

I.readProperty = function(real, key)
	local value, ok = readProperty(real, getState(real), key, Runtime.ctx)
	if not ok then
		error(value, 2)
	end
	return wrapValue(value)
end

local nativeMethodCache = {}
local function nativeMethod(name: string, fn)
	local cached = nativeMethodCache[name]
	if cached then
		return cached
	end
	cached = function(self, ...)
		local real = selfReal(self, name)
		local args = table.pack(...)
		for i = 1, args.n do
			args[i] = unwrap(args[i])
		end
		local results = table.pack(real[name](real, table.unpack(args, 1, args.n)))
		for i = 1, results.n do
			local v = results[i]
			if typeof(v) == "Instance" then
				results[i] = wrap(v)
			elseif type(v) == "table" then
				for j, item in v do
					if typeof(item) == "Instance" then
						v[j] = wrap(item)
					end
				end
			end
		end
		return table.unpack(results, 1, results.n)
	end
	nativeMethodCache[name] = cached
	return cached
end

indexFn = function(proxy, key)
	local real = toReal[proxy]
	local st = states[real] or getState(real)
	local member = resolve(st.class, key)
	if member then
		local kind = member.kind
		if kind == "method" then
			return member.fn
		elseif kind == "event" then
			return getSignal(real, st, key, member.onCount, member.onConnect)
		elseif member.get then
			return member.get(real, st, proxy)
		end
	end
	local ctx = Runtime.ctx
	local value, ok = readProperty(real, st, key, ctx)
	if not ok then
		if string.find(value, "is not a valid member", 1, true) then
			error(string.format('%s is not a valid member of %s "%s"', tostring(key), st.class, fullName(real)), 2)
		end
		error(value, 2)
	end
	local t = typeof(value)
	if t == "Instance" then
		if propInfo(st.class, key) then
			return wrap(value)
		end
		-- Child lookup by name: respect visibility
		if visible(value, ctx) then
			if not (ctx and ctx.kind == "client" and st.serverOnly) then
				return wrap(value)
			end
		end
		for _, child in children(real, ctx) do
			if child.Name == key then
				return wrap(child)
			end
		end
		error(string.format('%s is not a valid member of %s "%s"', tostring(key), st.class, fullName(real)), 2)
	elseif t == "function" then
		return nativeMethod(key, value)
	end
	return value
end

newindexFn = function(proxy, key, value)
	local real = toReal[proxy]
	local st = states[real] or getState(real)
	local member = resolve(st.class, key)
	if member then
		if member.kind == "prop" and member.set then
			member.set(real, st, value, proxy)
			return
		elseif member.kind ~= "prop" or not member.get then
			error(string.format("%s is not a valid member of %s or cannot be assigned", tostring(key), st.class), 2)
		end
		-- get-only computed props fall through to the reflection checks below
	end
	local info = propInfo(st.class, key)
	if not info then
		error(string.format('%s is not a valid member of %s "%s"', tostring(key), st.class, fullName(real)), 2)
	end
	if info.Scriptability ~= "ReadWrite" and info.Scriptability ~= "Write" then
		error(string.format("Unable to assign property %s. Property is read only", tostring(key)), 2)
	end
	local raw = unwrap(value)
	if raw ~= nil and info.Datatype == "Ref" and typeof(raw) ~= "Instance" then
		error(string.format("Unable to assign property %s. Instance expected, got %s", key, typeof(value)), 2)
	end
	raw = convertForProp(st.class, key, raw)
	local ctx = Runtime.ctx
	if ctx and ctx.kind == "client" and st.owner ~= ctx then
		st.overlay = st.overlay or {}
		local overlay = st.overlay[ctx]
		if not overlay then
			overlay = {}
			st.overlay[ctx] = overlay
		end
		-- validate by writing to a scratch instance of the same class
		local okProbe, probe = pcall(RealInstance.new, st.class)
		if okProbe and raw ~= nil and not isVirtual(st.class, key) then
			local okSet, err = pcall(rawSet, probe, key, raw)
			if not okSet then
				error(string.format("Unable to assign property %s: %s", key, tostring(err)), 2)
			end
		end
		overlay[key] = if raw == nil then I.NIL else raw
		firePropChanged(real, st, key, ctx)
		return
	end
	local listening = (st.signals and st.signals.Changed) or (st.propSignals and st.propSignals[key])
	local old
	if listening then
		old = readProperty(real, st, key, nil)
	end
	local ok, err = pcall(rawSet, real, key, raw)
	if not ok then
		error(string.format("Unable to assign property %s. %s", tostring(key), tostring(err)), 2)
	end
	if st.overlay then
		for _, overlay in st.overlay do
			overlay[key] = nil
		end
	end
	local hooks = I.onPropSet[key]
	if hooks then
		for _, hook in hooks do
			hook(real, st)
		end
	end
	if listening and old ~= raw then
		firePropChanged(real, st, key)
	end
end

-- Creation --------------------------------------------------------------------------------

local notCreatable = {}
function I.new(class: string, parent)
	if type(class) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	local info = db:GetClass(class)
	if not info then
		error(string.format('Unable to create an Instance of type "%s"', class), 2)
	end
	if notCreatable[class] == nil then
		local tags = info.Tags or {}
		notCreatable[class] = table.find(tags, "NotCreatable") ~= nil or table.find(tags, "Service") ~= nil
	end
	if notCreatable[class] then
		error(string.format('Unable to create an Instance of type "%s"', class), 2)
	end
	local real = RealInstance.new(class)
	local st = getState(real)
	local ctx = Runtime.ctx
	if ctx and ctx.kind == "client" then
		st.owner = ctx
	end
	for _, hook in I.onCreate do
		hook(real, st)
	end
	if parent ~= nil then
		I.setParent(real, unwrap(parent))
	end
	return wrap(real)
end
I.onCreate = {}

-- Wrap an instance created by the emulator itself (no ownership)
function I.newRaw(class: string)
	local real = RealInstance.new(class)
	getState(real)
	for _, hook in I.onCreate do
		hook(real, states[real])
	end
	return real
end

function I.clone(real)
	local ok, copy = pcall(real.Clone, real)
	if not ok then
		error(copy, 3)
	end
	if copy == nil then
		return nil
	end
	local ctx = Runtime.ctx
	local owner = if ctx and ctx.kind == "client" then ctx else nil
	local source = { real, table.unpack(real:GetDescendants()) }
	local copies = { copy, table.unpack(copy:GetDescendants()) }
	for i, node in copies do
		local st = getState(node)
		st.owner = owner
		local sst = states[source[i]]
		if sst and sst.virtual then
			st.virtual = table.clone(sst.virtual)
		end
		for _, hook in I.onCreate do
			hook(node, st)
		end
	end
	return copy
end

return I
