--!nocheck
-- Headless emulator core: a virtual clock, a coroutine scheduler that mirrors the Roblox
-- task library, execution contexts (the server and one per client) and RBXScriptSignals.
-- Nothing here touches instances; see Instances.luau for that.

local Runtime = {}

Runtime.now = 0 -- virtual seconds since boot (os.clock / time())
Runtime.epoch = 1790000000 -- virtual os.time() at boot
Runtime.frame = 0
Runtime.ctx = nil -- context of the running thread
Runtime.deferredSignals = true -- Workspace.SignalBehavior = Deferred
Runtime.errors = {} -- { { ctx, message } }
Runtime.warnings = {}
Runtime.log = {}
Runtime.quiet = false
Runtime.onError = nil

-- Contexts ---------------------------------------------------------------------------

local Context = {}
Context.__index = Context
Context.__tostring = function(self)
	return self.label
end

function Runtime.newContext(kind: string, label: string, player)
	return setmetatable({
		kind = kind,
		label = label,
		player = player, -- real Player instance for clients
		modules = {}, -- real ModuleScript -> returned value
		loading = {},
		G = {},
		shared = {},
	}, Context)
end

-- Output -----------------------------------------------------------------------------

local function ctxLabel()
	local ctx = Runtime.ctx
	return if ctx then ctx.label else "emu"
end

function Runtime.print(kind: string, message: string)
	local line = string.format("[%7.2f][%s] %s%s", Runtime.now, ctxLabel(), if kind == "" then "" else kind .. ": ", message)
	table.insert(Runtime.log, line)
	if kind == "ERROR" then
		table.insert(Runtime.errors, line)
	elseif kind == "WARN" or kind == "EMU" then
		table.insert(Runtime.warnings, line)
	end
	if not Runtime.quiet or kind == "ERROR" or kind == "WARN" or kind == "EMU" then
		print(line)
	end
end

function Runtime.reportError(err, thread)
	local message = tostring(err)
	local trace = if thread then debug.traceback(thread, message) else debug.traceback(message, 2)
	Runtime.print("ERROR", trace)
	if Runtime.onError then
		Runtime.onError(message)
	end
end

-- Emulator-level notes about fidelity problems or suspicious game behaviour
function Runtime.note(message: string)
	Runtime.print("EMU", message)
end

-- Threads ----------------------------------------------------------------------------

local threadCtx = setmetatable({}, { __mode = "k" })
local cancelled = setmetatable({}, { __mode = "k" })
local heap = {}
local seq = 0
local deferred = {}
local deferredHead = 1

local function heapPush(entry)
	table.insert(heap, entry)
	local i = #heap
	while i > 1 do
		local parent = i // 2
		local a, b = heap[parent], heap[i]
		if a.wake < b.wake or (a.wake == b.wake and a.seq < b.seq) then
			break
		end
		heap[parent], heap[i] = b, a
		i = parent
	end
end

local function heapPop()
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i = 1
		local n = #heap
		while true do
			local l, r = i * 2, i * 2 + 1
			local smallest = i
			local function less(x, y)
				local a, b = heap[x], heap[y]
				return a.wake < b.wake or (a.wake == b.wake and a.seq < b.seq)
			end
			if l <= n and less(l, smallest) then
				smallest = l
			end
			if r <= n and less(r, smallest) then
				smallest = r
			end
			if smallest == i then
				break
			end
			heap[i], heap[smallest] = heap[smallest], heap[i]
			i = smallest
		end
	end
	return top
end

function Runtime.threadContext(thread)
	return threadCtx[thread]
end

function Runtime.setThreadContext(thread, ctx)
	threadCtx[thread] = ctx
end

function Runtime.resume(thread, ...)
	if cancelled[thread] then
		return
	end
	local owner = threadCtx[thread]
	if owner and owner.dead then
		return
	end
	local status = coroutine.status(thread)
	if status ~= "suspended" then
		if status == "dead" then
			return
		end
		Runtime.note("attempt to resume a " .. status .. " thread")
		return
	end
	local previous = Runtime.ctx
	Runtime.ctx = threadCtx[thread] or previous
	local ok, err = coroutine.resume(thread, ...)
	Runtime.ctx = previous
	if not ok then
		Runtime.reportError(err, thread)
	end
end

local function toThread(fn)
	if type(fn) == "thread" then
		return fn
	end
	if type(fn) ~= "function" then
		error("invalid argument #1 to 'spawn' (function or thread expected)", 3)
	end
	return coroutine.create(fn)
end

local function adopt(thread)
	if threadCtx[thread] == nil then
		threadCtx[thread] = Runtime.ctx
	end
	return thread
end

-- Run fn in ctx on a new thread immediately (used by the emulator itself)
function Runtime.spawnIn(ctx, fn, ...)
	local thread = coroutine.create(fn)
	threadCtx[thread] = ctx
	Runtime.resume(thread, ...)
	return thread
end

function Runtime.deferIn(ctx, fn, ...)
	local thread = coroutine.create(fn)
	threadCtx[thread] = ctx
	table.insert(deferred, { thread = thread, args = table.pack(...) })
	return thread
end

function Runtime.delayIn(ctx, seconds, fn, ...)
	local thread = coroutine.create(fn)
	threadCtx[thread] = ctx
	seq += 1
	heapPush({ wake = Runtime.now + math.max(seconds or 0, 0), seq = seq, thread = thread, args = table.pack(...) })
	return thread
end

local task = {}

function task.spawn(fn, ...)
	local thread = adopt(toThread(fn))
	Runtime.resume(thread, ...)
	return thread
end

function task.defer(fn, ...)
	local thread = adopt(toThread(fn))
	table.insert(deferred, { thread = thread, args = table.pack(...) })
	return thread
end

function task.delay(seconds, fn, ...)
	local thread = adopt(toThread(fn))
	seq += 1
	heapPush({ wake = Runtime.now + math.max(tonumber(seconds) or 0, 0), seq = seq, thread = thread, args = table.pack(...) })
	return thread
end

function task.wait(seconds)
	local thread = coroutine.running()
	adopt(thread)
	local start = Runtime.now
	seq += 1
	heapPush({ wake = Runtime.now + math.max(tonumber(seconds) or 0, 0), seq = seq, thread = thread, waitStart = start })
	return coroutine.yield()
end

function task.cancel(thread)
	cancelled[thread] = true
	pcall(coroutine.close, thread)
end

function task.synchronize() end
function task.desynchronize() end

Runtime.task = task

-- Legacy globals
function Runtime.legacyWait(seconds)
	local elapsed = task.wait(math.max(seconds or 0, 1 / 30))
	return elapsed, Runtime.now
end

function Runtime.legacyDelay(seconds, fn)
	task.delay(math.max(seconds or 0, 1 / 30), fn)
end

function Runtime.legacySpawn(fn)
	task.defer(fn)
end

-- Yield the current thread until resume(thread, ...) is called by someone else
function Runtime.suspend()
	local thread = coroutine.running()
	adopt(thread)
	return coroutine.yield()
end

function Runtime.flushDeferred()
	local guard = 0
	while deferredHead <= #deferred do
		local entry = deferred[deferredHead]
		deferred[deferredHead] = nil
		deferredHead += 1
		guard += 1
		if guard > 100000 then
			Runtime.note("deferred queue did not drain (possible infinite task.defer loop)")
			break
		end
		if entry.fn then
			local previous = Runtime.ctx
			Runtime.ctx = entry.ctx
			entry.fn(table.unpack(entry.args, 1, entry.args.n))
			Runtime.ctx = previous
		else
			Runtime.resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
		end
	end
	if deferredHead > #deferred then
		table.clear(deferred)
		deferredHead = 1
	end
end

-- Resume every sleeping thread due at the current time (not ones scheduled during this pass)
function Runtime.runDue()
	local mark = seq
	while heap[1] and heap[1].wake <= Runtime.now and heap[1].seq <= mark do
		local entry = heapPop()
		if entry.waitStart then
			Runtime.resume(entry.thread, Runtime.now - entry.waitStart, Runtime.now)
		elseif entry.args then
			Runtime.resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
		else
			Runtime.resume(entry.thread)
		end
		Runtime.flushDeferred()
	end
end

function Runtime.pendingCount()
	return #heap
end

-- Signals ------------------------------------------------------------------------------

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	local index = table.find(signal._conns, self)
	if index then
		table.remove(signal._conns, index)
	end
	if signal._onCountChanged then
		signal._onCountChanged(#signal._conns)
	end
end
Connection.disconnect = Connection.Disconnect

local Signal = {}
Signal.__index = Signal
Signal.__tostring = function(self)
	return "Signal " .. (self._name or "?")
end

function Runtime.newSignal(name: string?, onCountChanged)
	return setmetatable({ _conns = {}, _name = name, _onCountChanged = onCountChanged, _isSignal = true }, Signal)
end

function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	local connection = setmetatable({ Connected = true, _fn = fn, _ctx = Runtime.ctx, _signal = self, _isConnection = true }, Connection)
	table.insert(self._conns, connection)
	if self._onCountChanged then
		self._onCountChanged(#self._conns)
	end
	if self._onConnect then
		self._onConnect(connection)
	end
	return connection
end
Signal.connect = Signal.Connect

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		if connection.Connected then
			connection:Disconnect()
			fn(...)
		end
	end)
	connection._once = true
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	adopt(thread)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		Runtime.resume(thread, ...)
	end)
	connection._ctx = Runtime.ctx
	return coroutine.yield()
end
Signal.wait = Signal.Wait

function Signal:ConnectParallel(fn)
	return self:Connect(fn)
end

function Signal:_count()
	return #self._conns
end

-- Fire to every connection whose context passes `filter` (nil = all).
function Signal:FireFiltered(filter, ...)
	local conns = self._conns
	if #conns == 0 then
		return
	end
	local snapshot = table.clone(conns)
	local args = table.pack(...)
	for _, connection in snapshot do
		local ctx = connection._ctx
		if connection.Connected and not (ctx and ctx.dead) and (filter == nil or filter(ctx)) then
			if Runtime.deferredSignals then
				local thread = coroutine.create(function()
					if connection.Connected then
						connection._fn(table.unpack(args, 1, args.n))
					end
				end)
				threadCtx[thread] = connection._ctx
				table.insert(deferred, { thread = thread, args = { n = 0 } })
			else
				Runtime.spawnIn(connection._ctx, connection._fn, table.unpack(args, 1, args.n))
			end
		end
	end
end

function Signal:Fire(...)
	self:FireFiltered(nil, ...)
end

-- Synchronous fire (used for RunService steps, which Roblox always runs immediately)
function Signal:FireNow(filter, ...)
	local conns = self._conns
	if #conns == 0 then
		return
	end
	for _, connection in table.clone(conns) do
		local ctx = connection._ctx
		if connection.Connected and not (ctx and ctx.dead) and (filter == nil or filter(ctx)) then
			Runtime.spawnIn(ctx, connection._fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._conns) do
		connection:Disconnect()
	end
end

Runtime.Signal = Signal
Runtime.Connection = Connection

function Runtime.isSignal(value)
	return type(value) == "table" and rawget(value, "_isSignal") == true
end

function Runtime.isConnection(value)
	return type(value) == "table" and rawget(value, "_isConnection") == true
end

return Runtime
