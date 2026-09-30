--!nocheck
-- Headless Roblox emulator for smoke-testing the game without Studio.
--
--   local Emu = require("./emu")
--   local world = Emu.new({ place = "StealAChibi.rbxl" })
--   world:StartServer()
--   local alice = world:AddPlayer("Alice", 101)
--   world:Run(5)
--
-- It runs the real server Script and client LocalScripts on a virtual clock, with fake
-- players whose characters walk at their WalkSpeed. It is not a physics engine: there are
-- no collisions and no gravity beyond following the ground under a character.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Runtime = require("@self/Runtime")
local I = require("@self/Instances")
local Classes = require("@self/Classes")
local Physics = require("@self/Physics")
local Services = require("@self/Services")
local S = require("@self/Shared")

local FixedCFrame = require("./lib/cframe")
local Vector3, CFrame, Enum = roblox.Vector3, FixedCFrame, roblox.Enum
local wrap, unwrap, states = I.wrap, I.unwrap, I.states

local Emu = {}
Emu.Runtime = Runtime
Emu.I = I
Emu.Physics = Physics
Emu.Services = Services
Emu.Classes = Classes
Emu.Shared = S

-- Deterministic Random ----------------------------------------------------------------

local RandomImpl = {}
RandomImpl.__index = RandomImpl
local randomSeeds = 0
local function newRandom(seed)
	if seed == nil then
		randomSeeds += 1
		seed = randomSeeds * 7919
	end
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	return setmetatable({ _state = s, _kind = "Random" }, RandomImpl)
end
function RandomImpl:_next()
	self._state = (self._state * 48271) % 2147483647
	return (self._state - 1) / 2147483646
end
function RandomImpl:NextNumber(min, max)
	local r = self:_next()
	if min ~= nil then
		max = max or 1
		return min + (max - min) * r
	end
	return r
end
function RandomImpl:NextInteger(min, max)
	if type(min) ~= "number" or type(max) ~= "number" then
		error("NextInteger expects two numbers", 2)
	end
	if max < min then
		error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
	end
	return math.floor(min + (max - min + 1) * self:_next())
end
function RandomImpl:NextUnitVector()
	local v = Vector3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1))
	if v.Magnitude < 1e-6 then
		return Vector3.xAxis
	end
	return v.Unit
end
function RandomImpl:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomImpl:Clone()
	return setmetatable({ _state = self._state, _kind = "Random" }, RandomImpl)
end

Emu.Random = { new = newRandom }

-- Environments ----------------------------------------------------------------------------

local function emuTypeof(value)
	if type(value) == "table" then
		if Runtime.isSignal(value) then
			return "RBXScriptSignal"
		elseif Runtime.isConnection(value) then
			return "RBXScriptConnection"
		end
		local kind = rawget(value, "_kind")
		if kind == "TweenInfo" or kind == "RaycastParams" or kind == "Random" then
			return kind
		elseif kind == "Tween" then
			return "Instance"
		end
	end
	return typeof(value)
end

local function joinArgs(...)
	local n = select("#", ...)
	local parts = table.create(n)
	for i = 1, n do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

local function vtime(t)
	if t ~= nil then
		return os.time(t)
	end
	return math.floor(Runtime.epoch + Runtime.now)
end

local World = {}
World.__index = World

function World:_baseEnv(ctx)
	local env = {
		game = wrap(self.game),
		workspace = wrap(self.workspace),
		Workspace = wrap(self.workspace),
		task = Runtime.task,
		wait = Runtime.legacyWait,
		delay = Runtime.legacyDelay,
		spawn = Runtime.legacySpawn,
		tick = function()
			return Runtime.epoch + Runtime.now
		end,
		time = function()
			return Runtime.now
		end,
		elapsedTime = function()
			return Runtime.now
		end,
		os = {
			time = vtime,
			clock = function()
				return Runtime.now
			end,
			date = function(format, t)
				return os.date(format, t or vtime())
			end,
			difftime = os.difftime,
		},
		typeof = emuTypeof,
		print = function(...)
			Runtime.print("", joinArgs(...))
		end,
		warn = function(...)
			Runtime.print("WARN", joinArgs(...))
		end,
		error = error,
		Instance = {
			new = I.new,
			fromExisting = function(inst)
				return I.new(unwrap(inst).ClassName)
			end,
		},
		Random = { new = newRandom },
		TweenInfo = Services.TweenInfo,
		RaycastParams = Physics.RaycastParams,
		OverlapParams = Physics.OverlapParams,
		settings = function()
			return { Rendering = { QualityLevel = Enum.QualityLevel.Automatic }, Physics = {}, Network = {} }
		end,
		UserSettings = function()
			return {
				GetService = function()
					return {
						SavedQualityLevel = Enum.SavedQualitySetting.Automatic,
						RotationType = Enum.RotationType.MovementRelative,
					}
				end,
			}
		end,
		version = function()
			return "0.650.0.0"
		end,
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		utf8 = utf8,
		bit32 = bit32,
		buffer = buffer,
		debug = debug,
		vector = vector,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		select = select,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		rawlen = rawlen,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		pcall = pcall,
		xpcall = xpcall,
		assert = assert,
		unpack = table.unpack,
		newproxy = newproxy,
		gcinfo = gcinfo,
		collectgarbage = function(option)
			if option == "count" then
				return gcinfo()
			end
			error("collectgarbage must be called with 'count'", 2)
		end,
		_G = ctx.G,
		shared = ctx.shared,
		_VERSION = "Luau",
	}
	env.CFrame = FixedCFrame
	for _, name in {
		"Vector3",
		"Vector2",
		"Vector3int16",
		"Vector2int16",
		"Color3",
		"UDim",
		"UDim2",
		"Rect",
		"NumberRange",
		"NumberSequence",
		"NumberSequenceKeypoint",
		"ColorSequence",
		"ColorSequenceKeypoint",
		"BrickColor",
		"Enum",
		"Font",
		"PhysicalProperties",
		"Ray",
		"Region3",
		"Region3int16",
		"Axes",
		"Faces",
	} do
		env[name] = roblox[name]
	end
	env.require = function(module)
		return self:_require(ctx, module)
	end
	return env
end

function World:_load(ctx, scriptReal)
	local env = table.clone(ctx.baseEnv)
	env.script = wrap(scriptReal)
	local ok, chunk = pcall(luau.load, scriptReal.Source, { debugName = I.fullName(scriptReal), environment = env })
	if not ok then
		error("Syntax error in " .. I.fullName(scriptReal) .. ": " .. tostring(chunk), 0)
	end
	return chunk
end

function World:_require(ctx, module)
	if type(module) == "number" then
		error("require(assetId) is not supported in the emulator", 2)
	end
	local real = unwrap(module)
	if typeof(real) ~= "Instance" or not real:IsA("ModuleScript") then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	if ctx.kind == "client" and I.isServerOnly(real) then
		error("Client required a server-only module " .. I.fullName(real), 2)
	end
	local cached = ctx.modules[real]
	if cached then
		if cached.failed then
			error("Requested module experienced an error while loading", 2)
		end
		return cached.value
	end
	if ctx.loading[real] then
		error("Requested module was required recursively: " .. I.fullName(real), 2)
	end
	ctx.loading[real] = true
	local chunk = self:_load(ctx, real)
	local results = table.pack(pcall(chunk))
	ctx.loading[real] = nil
	if not results[1] then
		ctx.modules[real] = { failed = true }
		error(results[2], 0)
	end
	if results.n ~= 2 then
		ctx.modules[real] = { failed = true }
		error("Module code did not return exactly one value: " .. I.fullName(real), 2)
	end
	ctx.modules[real] = { value = results[2] }
	return results[2]
end

function World:_runScript(ctx, scriptReal)
	local ok, err = pcall(function()
		local chunk = self:_load(ctx, scriptReal)
		Runtime.spawnIn(ctx, chunk)
	end)
	if not ok then
		Runtime.reportError(err)
	end
	Runtime.flushDeferred()
end

-- Construction --------------------------------------------------------------------------------

function Emu.new(opts)
	opts = opts or {}
	Runtime.quiet = opts.quiet == true
	S.isStudio = opts.studio ~= false
	S.defaultViewport = opts.viewport or roblox.Vector2.new(1280, 720)
	math.randomseed(opts.seed or 1)
	local self = setmetatable({ clients = {}, dt = opts.dt or 1 / 30 }, World)
	local game = roblox.deserializePlace(fs.readFile(opts.place or "StealAChibi.rbxl"))
	self.game = game
	self.workspace = game:GetService("Workspace")
	-- make sure every service we implement exists
	for _, name in {
		"Players",
		"RunService",
		"ReplicatedStorage",
		"ServerStorage",
		"ServerScriptService",
		"StarterPlayer",
		"StarterGui",
		"Lighting",
		"SoundService",
		"CollectionService",
		"TweenService",
		"HttpService",
		"DataStoreService",
		"MessagingService",
		"MarketplaceService",
		"ProximityPromptService",
		"UserInputService",
		"ContextActionService",
		"GuiService",
		"PathfindingService",
		"PhysicsService",
		"Debris",
		"TextService",
		"BadgeService",
		"GroupService",
		"PolicyService",
		"LocalizationService",
		"TeleportService",
		"SocialService",
		"AnalyticsService",
	} do
		pcall(game.GetService, game, name)
	end
	Runtime.deferredSignals = self.workspace.SignalBehavior ~= Enum.SignalBehavior.Immediate
	for _, name in { "ServerStorage", "ServerScriptService" } do
		I.getState(game:GetService(name)).serverOnly = true
	end
	Physics.setWorkspace(self.workspace)
	I.buildIndex(game)
	I.booted = true
	-- server camera
	local camera = I.newRaw("Camera")
	camera.CFrame = CFrame.new(0, 20, 20)
	Services.serverCamera = camera
	S.server = Runtime.newContext("server", "server")
	S.server.baseEnv = self:_baseEnv(S.server)
	Physics.onDied = function(humanoid)
		self:_onDied(humanoid)
	end
	Services.loadCharacter = function(player)
		self:_loadCharacter(player)
	end
	Services.onKick = function(player)
		Runtime.delayIn(nil, 0, function()
			for _, client in self.clients do
				if client.real == player and not client.left then
					self:RemovePlayer(client)
				end
			end
		end)
	end
	return self
end

function World:StartServer()
	local sss = self.game:GetService("ServerScriptService")
	for _, d in sss:GetDescendants() do
		if d.ClassName == "Script" then
			local enabled = true
			pcall(function()
				enabled = not d.Disabled
			end)
			if enabled then
				self:_runScript(S.server, d)
			end
		end
	end
	for _, d in self.workspace:GetDescendants() do
		if d.ClassName == "Script" then
			Runtime.note("Script in Workspace not run: " .. I.fullName(d))
		end
	end
	self:Step()
end

-- Players ------------------------------------------------------------------------------------

local Client = {}
Client.__index = Client

local function privateChild(player, class, name, ctx, private)
	local inst = I.newRaw(class)
	inst.Name = name
	if private then
		I.getState(inst).privateTo = ctx
	end
	inst.Parent = player
	return inst
end

function World:AddPlayer(name, userId, opts)
	opts = opts or {}
	local players = self.game:GetService("Players")
	local player = I.newRaw("Player")
	player.Name = name
	player.DisplayName = opts.displayName or name
	player.UserId = userId
	local ctx = Runtime.newContext("client", name, player)
	ctx.viewport = opts.viewport
	ctx.input = opts.input
	ctx.baseEnv = self:_baseEnv(ctx)
	local camera = I.newRaw("Camera")
	camera.Name = "Camera"
	camera.CFrame = CFrame.new(0, 20, 20)
	I.getState(camera).owner = ctx
	ctx.camera = camera
	privateChild(player, "PlayerGui", "PlayerGui", ctx, true)
	privateChild(player, "PlayerScripts", "PlayerScripts", ctx, true)
	privateChild(player, "Backpack", "Backpack", ctx, false)
	privateChild(player, "StarterGear", "StarterGear", ctx, true)
	S.clients[player] = ctx
	local client = setmetatable({ world = self, real = player, player = wrap(player), ctx = ctx, name = name, userId = userId }, Client)
	table.insert(self.clients, client)
	local previous = Runtime.ctx
	Runtime.ctx = S.server
	I.setParent(player, players)
	Runtime.ctx = previous
	I.fireTo(players, "PlayerAdded", function(c)
		return c ~= ctx
	end, wrap(player))
	Runtime.flushDeferred()
	-- client scripts
	Runtime.ctx = ctx
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local starterScripts = self.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	local toRun = {}
	if starterScripts then
		for _, child in starterScripts:GetChildren() do
			local copy = I.clone(child)
			I.setParent(copy, playerScripts)
			for _, d in { copy, table.unpack(copy:GetDescendants()) } do
				if d.ClassName == "LocalScript" then
					table.insert(toRun, d)
				end
			end
		end
	end
	for _, child in self.game:GetService("StarterGui"):GetChildren() do
		I.setParent(I.clone(child), player:FindFirstChild("PlayerGui"))
	end
	Runtime.ctx = previous
	for _, scriptReal in toRun do
		self:_runScript(ctx, scriptReal)
	end
	if players.CharacterAutoLoads then
		Runtime.delayIn(S.server, 0.2, function()
			if player.Parent then
				self:_loadCharacter(player)
			end
		end)
	end
	self:Step()
	return client
end

function World:_spawnCFrame()
	local spawns = {}
	for _, d in self.workspace:GetDescendants() do
		if d.ClassName == "SpawnLocation" and d.Enabled then
			table.insert(spawns, d)
		end
	end
	if #spawns == 0 then
		return CFrame.new(0, 10, 0)
	end
	local spawn = spawns[1]
	return CFrame.new(spawn.CFrame.Position + Vector3.new(0, spawn.Size.Y / 2 + 3, 0))
end

function World:_loadCharacter(player)
	local previous = Runtime.ctx
	Runtime.ctx = S.server
	local old = player.Character
	local first = old == nil
	if old then
		I.fire(player, "CharacterRemoving", wrap(old))
		I.destroy(old, { force = true })
	end
	if not first then
		-- ScreenGuis with ResetOnSpawn are destroyed and StarterGui is copied again
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			for _, child in gui:GetChildren() do
				if child:IsA("LayerCollector") and child.ResetOnSpawn then
					Runtime.note("ScreenGui " .. child.Name .. " has ResetOnSpawn=true and was destroyed on respawn")
					I.destroy(child, { force = true })
				end
			end
		end
	end
	local character = Physics.buildCharacter(player.Name, self:_spawnCFrame())
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local starter = self.game:GetService("StarterPlayer")
	humanoid.WalkSpeed = starter.CharacterWalkSpeed
	pcall(function()
		humanoid.JumpPower = starter.CharacterJumpPower
	end)
	player.Character = character
	I.setParent(character, self.workspace)
	I.firePropChanged(player, states[player], "Character")
	Runtime.ctx = previous
	I.fire(player, "CharacterAdded", wrap(character))
	I.fire(player, "CharacterAppearanceLoaded", wrap(character))
	Runtime.flushDeferred()
end

function World:_onDied(humanoid)
	local model = humanoid.Parent
	for _, client in self.clients do
		if client.real.Character == model and not client.left then
			local players = self.game:GetService("Players")
			if players.CharacterAutoLoads then
				Runtime.delayIn(S.server, players.RespawnTime, function()
					if client.real.Parent and client.real.Character == model then
						self:_loadCharacter(client.real)
					end
				end)
			end
		end
	end
end

function World:RemovePlayer(client)
	if client.left then
		return
	end
	client.left = true
	local player = client.real
	local players = self.game:GetService("Players")
	I.fire(players, "PlayerRemoving", wrap(player))
	Runtime.flushDeferred()
	client.ctx.dead = true
	local character = player.Character
	if character then
		I.fire(player, "CharacterRemoving", wrap(character))
		Runtime.flushDeferred()
		local previous = Runtime.ctx
		Runtime.ctx = S.server
		I.destroy(character, { force = true })
		Runtime.ctx = previous
	end
	local previous = Runtime.ctx
	Runtime.ctx = S.server
	I.setParent(player, nil, { force = true })
	Runtime.ctx = previous
	S.clients[player] = nil
	self:Step()
end

-- Shutdown: remove everyone, then run BindToClose callbacks (up to 30 s)
function World:Shutdown()
	for _, client in self.clients do
		self:RemovePlayer(client)
	end
	local pending = 0
	for _, entry in S.bindToClose do
		pending += 1
		Runtime.spawnIn(entry.ctx, function()
			entry.fn()
			pending -= 1
		end)
	end
	local start = Runtime.now
	while pending > 0 and Runtime.now - start < 30 do
		self:Step()
	end
	if pending > 0 then
		Runtime.note("BindToClose callbacks still running after 30 s")
	end
	return pending == 0
end

-- Time -----------------------------------------------------------------------------------------

function World:Step(dt)
	dt = dt or self.dt
	Runtime.now += dt
	Runtime.frame += 1
	local runService = self.game:GetService("RunService")
	I.fireTo(runService, "RenderStepped", nil, dt) -- deferred like the others is fine for tests
	local rst = states[runService]
	local signals = rst and rst.signals
	local function stepSignal(name, ...)
		local signal = signals and signals[name]
		if signal then
			signal:FireNow(nil, ...)
		end
	end
	for ctx, bindings in Services.renderBindings do
		if not ctx.dead then
			local list = {}
			for _, binding in bindings do
				table.insert(list, binding)
			end
			table.sort(list, function(a, b)
				return a.priority < b.priority
			end)
			for _, binding in list do
				Runtime.spawnIn(ctx, binding.fn, dt)
			end
		end
	end
	local profile = Emu.profile
	local t0 = os.clock()
	stepSignal("PreRender", dt)
	stepSignal("Stepped", Runtime.now, dt)
	stepSignal("PreSimulation", dt)
	local t1 = os.clock()
	Physics.stepHumanoids(dt)
	local t2 = os.clock()
	Physics.stepTouches()
	Services.stepTweens()
	local t3 = os.clock()
	stepSignal("PostSimulation", dt)
	stepSignal("Heartbeat", dt)
	Runtime.flushDeferred()
	local t4 = os.clock()
	Runtime.runDue()
	Runtime.flushDeferred()
	local t5 = os.clock()
	if profile then
		profile.render = (profile.render or 0) + (t1 - t0)
		profile.humanoids = (profile.humanoids or 0) + (t2 - t1)
		profile.touchTween = (profile.touchTween or 0) + (t3 - t2)
		profile.heartbeat = (profile.heartbeat or 0) + (t4 - t3)
		profile.threads = (profile.threads or 0) + (t5 - t4)
	end
end

function World:Run(seconds, dt)
	dt = dt or self.dt
	local target = Runtime.now + seconds
	while Runtime.now + 1e-9 < target do
		self:Step(dt)
	end
end

function World:RunUntil(predicate, timeout, dt)
	local deadline = Runtime.now + (timeout or 30)
	while Runtime.now < deadline do
		if predicate() then
			return true
		end
		self:Step(dt)
	end
	return predicate()
end

function World:Now()
	return Runtime.now
end

-- Run fn in a context as game code would; returns its results after stepping until done
function World:RunIn(ctx, fn, timeout)
	local done, results = false, nil
	Runtime.spawnIn(ctx, function()
		results = table.pack(pcall(fn))
		done = true
	end)
	Runtime.flushDeferred()
	if not done then
		self:RunUntil(function()
			return done
		end, timeout or 30)
	end
	if not done then
		error("RunIn timed out", 2)
	end
	if not results[1] then
		error(results[2], 2)
	end
	return table.unpack(results, 2, results.n)
end

function World:Server(fn, timeout)
	return self:RunIn(S.server, fn, timeout)
end

-- Server-side module access (same instances the server uses)
function World:ServerRequire(path)
	return self:Server(function()
		local node = wrap(self.game)
		for segment in string.gmatch(path, "[^%.]+") do
			node = node:FindFirstChild(segment) or node:GetService(segment)
		end
		return S.server.baseEnv.require(node)
	end)
end

function World:Find(path)
	local node = self.game
	for segment in string.gmatch(path, "[^%.]+") do
		local nextNode = node:FindFirstChild(segment)
		if not nextNode and node == self.game then
			nextNode = self.game:GetService(segment)
		end
		if not nextNode then
			return nil
		end
		node = nextNode
	end
	return node
end

function World:Tagged(tag)
	return I.getTagged(tag, nil)
end

-- Client driver ------------------------------------------------------------------------------

function Client:Character()
	return self.real.Character
end

function Client:Root()
	local character = self.real.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Client:Humanoid()
	local character = self.real.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Client:Position()
	local root = self:Root()
	return root and root.CFrame.Position
end

-- Instant move (like a client-side teleport)
function Client:Teleport(position)
	local root = self:Root()
	assert(root, self.name .. " has no character")
	local previous = Runtime.ctx
	Runtime.ctx = self.ctx
	Classes.setPartCFrame(root, CFrame.new(position))
	Classes.partMoved(root)
	Runtime.ctx = previous
end

-- Walk to a point at the humanoid's WalkSpeed; returns true if it arrived
function Client:WalkTo(position, timeout)
	local humanoid = self:Humanoid()
	assert(humanoid, self.name .. " has no humanoid")
	local h = Physics.hstate(humanoid)
	h.moveTarget = position
	h.movePart = nil
	local deadline = Runtime.now + (timeout or 60)
	while Runtime.now < deadline do
		local root = self:Root()
		if not root then
			return false
		end
		local p = root.CFrame.Position
		if Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude < 1 then
			return true
		end
		local current = self:Humanoid()
		if current ~= humanoid then
			return false -- respawned
		end
		h.moveTarget = position
		h.moveStart = Runtime.now
		self.world:Step()
	end
	return false
end

function Client:StopWalking()
	local humanoid = self:Humanoid()
	if humanoid then
		Physics.hstate(humanoid).moveTarget = nil
	end
end

function Client:Gui()
	return self.real:FindFirstChild("PlayerGui")
end

-- Everything this client can see under its PlayerGui
function Client:GuiDescendants()
	return I.descendants(self:Gui(), self.ctx)
end

local function isShown(real, ctx)
	local node = real
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			if not node.Enabled then
				return false
			end
			return true
		end
		node = node.Parent
	end
	return true
end
Client.isShown = isShown

function Client:FindText(pattern, onlyVisible)
	local found = {}
	for _, d in self:GuiDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			local text = d.Text
			if string.find(text, pattern) and (not onlyVisible or isShown(d, self.ctx)) then
				table.insert(found, d)
			end
		end
	end
	return found
end

function Client:Click(button)
	local real = unwrap(button)
	assert(real:IsA("GuiButton"), "not a button")
	I.fireTo(real, "Activated", function(c)
		return c == self.ctx
	end, nil, 1)
	I.fireTo(real, "MouseButton1Click", function(c)
		return c == self.ctx
	end)
	self.world:Step()
end

function Client:ClickText(pattern)
	for _, d in self:FindText(pattern, true) do
		local node = d
		while node and not node:IsA("GuiButton") do
			node = node.Parent
		end
		if node then
			self:Click(node)
			return true
		end
	end
	return false
end

-- Run code as this client (e.g. to fire a remote the way the client would)
function Client:Do(fn, timeout)
	return self.world:RunIn(self.ctx, fn, timeout)
end

function Client:Require(path)
	return self:Do(function()
		local node = wrap(self.world.game)
		for segment in string.gmatch(path, "[^%.]+") do
			node = node:FindFirstChild(segment) or node:GetService(segment)
		end
		return self.ctx.baseEnv.require(node)
	end)
end

function Client:Fire(remoteName, ...)
	local args = table.pack(...)
	return self:Do(function()
		local remote = wrap(self.world.game:GetService("ReplicatedStorage")):WaitForChild("Remotes"):WaitForChild(remoteName)
		remote:FireServer(table.unpack(args, 1, args.n))
	end)
end

function Client:Invoke(remoteName, ...)
	local args = table.pack(...)
	return self:Do(function()
		local remote = wrap(self.world.game:GetService("ReplicatedStorage")):WaitForChild("Remotes"):WaitForChild(remoteName)
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
end

-- Hold a ProximityPrompt like a player would; returns false if it isn't usable
function Client:HoldPrompt(prompt, seconds)
	local real = unwrap(prompt)
	prompt = wrap(real)
	local previous = Runtime.ctx
	Runtime.ctx = self.ctx
	local enabled = wrap(real).Enabled
	local hold = wrap(real).HoldDuration
	Runtime.ctx = previous
	if not enabled then
		return false, "disabled"
	end
	local parent = real.Parent
	local position = if parent:IsA("BasePart") then parent.CFrame.Position elseif parent:IsA("Attachment") then (parent.Parent.CFrame * parent.CFrame).Position else nil
	local root = self:Root()
	if position and root then
		local distance = (root.CFrame.Position - position).Magnitude
		if distance > real.MaxActivationDistance + 0.5 then
			return false, string.format("too far (%.1f > %.1f)", distance, real.MaxActivationDistance)
		end
	end
	seconds = seconds or hold
	local ppsReal = self.world.game:GetService("ProximityPromptService")
	local mine = function(c)
		return c == S.server or c == self.ctx
	end
	I.fireTo(ppsReal, "PromptButtonHoldBegan", mine, prompt, self.player)
	I.fireTo(real, "PromptButtonHoldBegan", mine, self.player)
	self.world:Run(math.max(seconds, self.world.dt))
	I.fireTo(ppsReal, "PromptButtonHoldEnded", mine, prompt, self.player)
	I.fireTo(real, "PromptButtonHoldEnded", mine, self.player)
	I.fireTo(ppsReal, "PromptTriggered", mine, prompt, self.player)
	I.fireTo(real, "Triggered", mine, self.player)
	self.world:Step()
	I.fireTo(ppsReal, "PromptTriggerEnded", mine, prompt, self.player)
	I.fireTo(real, "TriggerEnded", mine, self.player)
	self.world:Step()
	return true
end

-- Press a ContextActionService action (e.g. "Slap")
function Client:Action(name)
	local bound = Services.actions[self.ctx]
	local action = bound and bound[name]
	if not action then
		return false
	end
	local input = { KeyCode = action.keys[1], UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin, Position = Vector3.zero, Delta = Vector3.zero }
	Runtime.spawnIn(self.ctx, action.fn, name, Enum.UserInputState.Begin, input)
	self.world:Step()
	input.UserInputState = Enum.UserInputState.End
	Runtime.spawnIn(self.ctx, action.fn, name, Enum.UserInputState.End, input)
	self.world:Step()
	return true
end

function Client:BoundActions()
	local out = {}
	for name in Services.actions[self.ctx] or {} do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- Press a key through UserInputService.InputBegan/Ended
function Client:Key(keyCode)
	local uis = self.world.game:GetService("UserInputService")
	local input = { KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard, UserInputState = Enum.UserInputState.Begin, Position = Vector3.zero, Delta = Vector3.zero }
	local only = function(c)
		return c == self.ctx
	end
	I.fireTo(uis, "InputBegan", only, input, false)
	self.world:Step()
	input.UserInputState = Enum.UserInputState.End
	I.fireTo(uis, "InputEnded", only, input, false)
	self.world:Step()
end

-- Report ----------------------------------------------------------------------------------------

function Emu.errors()
	return Runtime.errors
end

function Emu.warnings()
	return Runtime.warnings
end

return Emu
