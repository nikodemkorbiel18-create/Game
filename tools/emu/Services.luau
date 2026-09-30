--!nocheck
-- Service implementations: DataModel, Players, RunService, CollectionService, TweenService,
-- HttpService, DataStoreService (in memory, persists across emulated servers),
-- MessagingService, MarketplaceService, input services and assorted stubs.

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Runtime = require("./Runtime")
local I = require("./Instances")
local Classes = require("./Classes")
local Physics = require("./Physics")
local S = require("./Shared")

local Vector2, Vector3 = roblox.Vector2, roblox.Vector3
local Enum = roblox.Enum
local wrap, unwrap, selfReal, states = I.wrap, I.unwrap, I.selfReal, I.states
local method, event, prop = I.method, I.event, I.prop

local Services = {}

-- DataModel ----------------------------------------------------------------------------

local serviceAliases = { Workspace = "Workspace" }

method("DataModel", "GetService", function(self, name)
	local real = selfReal(self, "GetService")
	if type(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	local ok, service = pcall(real.GetService, real, serviceAliases[name] or name)
	if not ok or service == nil then
		error(string.format("'%s' is not a valid Service name", name), 2)
	end
	return wrap(service)
end)
method("DataModel", "FindService", function(self, name)
	local real = selfReal(self, "FindService")
	local ok, service = pcall(real.FindService, real, name)
	return if ok then wrap(service) else nil
end)
method("DataModel", "BindToClose", function(_self, fn)
	if type(fn) ~= "function" then
		error("BindToClose expects a function", 2)
	end
	table.insert(S.bindToClose, { fn = fn, ctx = Runtime.ctx })
end)
method("DataModel", "IsLoaded", function()
	return true
end)
event("DataModel", "Loaded")
event("DataModel", "Close")
for name, value in { PlaceId = 0, GameId = 0, CreatorId = 0, PlaceVersion = 1, PrivateServerOwnerId = 0 } do
	prop("DataModel", name, function()
		return value
	end)
end
prop("DataModel", "JobId", function()
	return "emulated-server"
end)
prop("DataModel", "PrivateServerId", function()
	return ""
end)
prop("DataModel", "CreatorType", function()
	return Enum.CreatorType.User
end)
prop("DataModel", "Workspace", function()
	return wrap(I.gameReal:GetService("Workspace"))
end)

-- Workspace ----------------------------------------------------------------------------------

method("Workspace", "GetServerTimeNow", function()
	return Runtime.epoch + Runtime.now
end)
method("Workspace", "GetRealPhysicsFPS", function()
	return 60
end)
prop("Workspace", "DistributedGameTime", function()
	return Runtime.now
end)
prop("Workspace", "CurrentCamera", function()
	local ctx = Runtime.ctx
	if ctx and ctx.camera then
		return wrap(ctx.camera)
	end
	return wrap(Services.serverCamera)
end, function(_real, _st, value)
	local ctx = Runtime.ctx
	if ctx then
		ctx.camera = unwrap(value)
	end
end)

-- Players -------------------------------------------------------------------------------------

local function players()
	local list = {}
	for _, child in I.gameReal:GetService("Players"):GetChildren() do
		if child:IsA("Player") then
			table.insert(list, child)
		end
	end
	return list
end
Services.players = players

method("Players", "GetPlayers", function(self)
	selfReal(self, "GetPlayers")
	return I.wrapList(players())
end)
method("Players", "GetPlayerByUserId", function(_self, userId)
	for _, p in players() do
		if p.UserId == userId then
			return wrap(p)
		end
	end
	return nil
end)
method("Players", "GetPlayerFromCharacter", function(_self, character)
	local real = unwrap(character)
	if real == nil then
		return nil
	end
	for _, p in players() do
		if p.Character == real then
			return wrap(p)
		end
	end
	return nil
end)
method("Players", "GetUserIdFromNameAsync", function(_self, name)
	for _, p in players() do
		if p.Name == name then
			return p.UserId
		end
	end
	error("Players:GetUserIdFromNameAsync() failed: Unknown user", 2)
end)
method("Players", "GetNameFromUserIdAsync", function(_self, userId)
	return "User" .. tostring(userId)
end)
method("Players", "GetUserThumbnailAsync", function()
	return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true
end)
method("Players", "GetHumanoidDescriptionFromUserId", function()
	return I.new("HumanoidDescription")
end)
method("Players", "CreateHumanoidModelFromDescription", function()
	return wrap(Physics.buildCharacter("Dummy", roblox.CFrame.new(0, 100, 0)))
end)
prop("Players", "LocalPlayer", function()
	local ctx = Runtime.ctx
	if ctx and ctx.kind == "client" then
		return wrap(ctx.player)
	end
	return nil
end)
event("Players", "PlayerAdded")
event("Players", "PlayerRemoving")
event("Players", "PlayerMembershipChanged")

event("Player", "CharacterAdded")
event("Player", "CharacterRemoving")
event("Player", "CharacterAppearanceLoaded")
event("Player", "Chatted")
event("Player", "Idled")
event("Player", "OnTeleport")
method("Player", "Kick", function(self, message)
	local real = selfReal(self, "Kick")
	Runtime.print("", string.format("KICK %s: %s", real.Name, tostring(message)))
	if Services.onKick then
		Services.onKick(real, message)
	end
end)
method("Player", "LoadCharacter", function(self)
	local real = selfReal(self, "LoadCharacter")
	local ctx = Runtime.ctx
	if ctx and ctx.kind == "client" then
		error("LoadCharacter can only be called by the backend server", 2)
	end
	Services.loadCharacter(real)
end)
for _, name in { "GetRankInGroup", "GetRankInGroupAsync" } do
	method("Player", name, function()
		return 0
	end)
end
for _, name in { "GetRoleInGroup", "GetRoleInGroupAsync" } do
	method("Player", name, function()
		return "Guest"
	end)
end
for _, name in { "IsInGroup", "IsInGroupAsync", "IsFriendsWith", "IsFriendsWithAsync", "HasAppearanceLoaded" } do
	method("Player", name, function()
		return name == "HasAppearanceLoaded"
	end)
end
method("Player", "GetFriendsOnline", function()
	return {}
end)
method("Player", "GetJoinData", function()
	return { SourcePlaceId = 0, Members = {} }
end)
method("Player", "GetNetworkPing", function()
	return S.latency
end)
method("Player", "DistanceFromCharacter", function(self, point)
	local real = selfReal(self, "DistanceFromCharacter")
	local character = real.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return 0
	end
	return (head.CFrame.Position - point).Magnitude
end)
method("Player", "GetMouse", function(self)
	local ctx = Runtime.ctx
	if not ctx or ctx.kind ~= "client" then
		error("GetMouse can only be called from the client", 2)
	end
	ctx.mouse = ctx.mouse
		or {
			Hit = roblox.CFrame.new(),
			Target = nil,
			X = 0,
			Y = 0,
			Icon = "",
			Button1Down = Runtime.newSignal("Button1Down"),
			Button1Up = Runtime.newSignal("Button1Up"),
			Move = Runtime.newSignal("Move"),
		}
	return ctx.mouse
end)
method("Player", "RequestStreamAroundAsync", function() end)
prop("Player", "AccountAge", function()
	return 365
end)
prop("Player", "MembershipType", function()
	return Enum.MembershipType.None
end)
prop("Player", "LocaleId", function()
	return "en-us"
end)
prop("Player", "FollowUserId", function()
	return 0
end)

-- RunService -----------------------------------------------------------------------------

method("RunService", "IsServer", function()
	local ctx = Runtime.ctx
	return ctx == nil or ctx.kind == "server"
end)
method("RunService", "IsClient", function()
	local ctx = Runtime.ctx
	return ctx ~= nil and ctx.kind == "client"
end)
method("RunService", "IsStudio", function()
	return S.isStudio
end)
method("RunService", "IsRunning", function()
	return true
end)
method("RunService", "IsRunMode", function()
	return false
end)
method("RunService", "IsEdit", function()
	return false
end)
local renderBindings = {} -- ctx -> { name -> { priority, fn } }
method("RunService", "BindToRenderStep", function(_self, name, priority, fn)
	local ctx = Runtime.ctx
	if not ctx or ctx.kind ~= "client" then
		error("BindToRenderStep can only be called from the client", 2)
	end
	renderBindings[ctx] = renderBindings[ctx] or {}
	renderBindings[ctx][name] = { priority = priority, fn = fn }
end)
method("RunService", "UnbindFromRenderStep", function(_self, name)
	local ctx = Runtime.ctx
	if renderBindings[ctx] then
		renderBindings[ctx][name] = nil
	end
end)
Services.renderBindings = renderBindings
for _, name in { "Heartbeat", "Stepped", "RenderStepped", "PreSimulation", "PostSimulation", "PreRender", "PreAnimation" } do
	event("RunService", name)
end

-- CollectionService -------------------------------------------------------------------------

method("CollectionService", "GetTagged", function(_self, tag)
	if type(tag) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	return I.getTagged(tag, Runtime.ctx)
end)
method("CollectionService", "GetAllTags", function()
	local out = {}
	for tag in I.tagIndex do
		table.insert(out, tag)
	end
	return out
end)
method("CollectionService", "HasTag", function(_self, inst, tag)
	return unwrap(inst):HasTag(tag)
end)
method("CollectionService", "GetTags", function(_self, inst)
	return unwrap(inst):GetTags()
end)
method("CollectionService", "AddTag", function(_self, inst, tag)
	inst:AddTag(tag)
end)
method("CollectionService", "RemoveTag", function(_self, inst, tag)
	inst:RemoveTag(tag)
end)
method("CollectionService", "GetInstanceAddedSignal", function(_self, tag)
	if type(tag) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	return I.tagSignal(tag, "added")
end)
method("CollectionService", "GetInstanceRemovedSignal", function(_self, tag)
	if type(tag) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	return I.tagSignal(tag, "removed")
end)
event("CollectionService", "TagAdded")
event("CollectionService", "TagRemoved")

-- TweenService -------------------------------------------------------------------------------

local TweenInfo = {}
TweenInfo.__index = TweenInfo
TweenInfo.__tostring = function(self)
	return string.format("TweenInfo(%s)", tostring(self.Time))
end
Services.TweenInfo = {
	new = function(time, style, direction, repeatCount, reverses, delayTime)
		return setmetatable({
			Time = time or 1,
			EasingStyle = style or Enum.EasingStyle.Quad,
			EasingDirection = direction or Enum.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
			_kind = "TweenInfo",
		}, TweenInfo)
	end,
}

local function lerp(a, b, t)
	local ta = typeof(a)
	if ta == "number" then
		return a + (b - a) * t
	elseif ta == "boolean" or ta == "EnumItem" or ta == "string" then
		return if t >= 1 then b else a
	elseif ta == "CFrame" or ta == "Vector3" or ta == "Vector2" or ta == "Color3" or ta == "UDim2" then
		return a:Lerp(b, t)
	elseif ta == "UDim" then
		return roblox.UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t)
	elseif ta == "NumberRange" then
		return roblox.NumberRange.new(a.Min + (b.Min - a.Min) * t, a.Max + (b.Max - a.Max) * t)
	end
	return if t >= 1 then b else a
end

local Tween = {}
Tween.__index = Tween
local activeTweens = {}

function Tween:Play()
	if self.PlaybackState == Enum.PlaybackState.Playing then
		return
	end
	-- a new tween on the same property cancels the older one
	for other in activeTweens do
		if other ~= self and other.Instance == self.Instance then
			for key in self._goals do
				if other._goals[key] ~= nil then
					other:_finish(Enum.PlaybackState.Cancelled)
					break
				end
			end
		end
	end
	self.PlaybackState = Enum.PlaybackState.Playing
	self._start = Runtime.now + self.TweenInfo.DelayTime
	self._from = {}
	local ok, err = pcall(function()
		for key in self._goals do
			self._from[key] = self.Instance[key]
		end
	end)
	if not ok then
		error(err, 2)
	end
	activeTweens[self] = true
end
function Tween:Pause()
	self.PlaybackState = Enum.PlaybackState.Paused
	activeTweens[self] = nil
end
function Tween:Cancel()
	if activeTweens[self] then
		self:_finish(Enum.PlaybackState.Cancelled)
	end
end
function Tween:Destroy()
	activeTweens[self] = nil
end
function Tween:_finish(state)
	activeTweens[self] = nil
	self.PlaybackState = state
	self.Completed:Fire(state)
end

function Services.stepTweens()
	for tween in table.clone(activeTweens) do
		if activeTweens[tween] then
			local info = tween.TweenInfo
			local elapsed = Runtime.now - tween._start
			if elapsed >= 0 then
				local instReal = unwrap(tween.Instance)
				local ist = states[instReal]
				if ist and ist.destroyed then
					tween:_finish(Enum.PlaybackState.Cancelled)
				else
					local duration = math.max(info.Time, 1e-6)
					local cycles = info.RepeatCount
					local total = if cycles < 0 then math.huge else duration * (cycles + 1) * (if info.Reverses then 2 else 1)
					local t
					if elapsed >= total then
						t = if info.Reverses then 0 else 1
					else
						local period = duration * (if info.Reverses then 2 else 1)
						local phase = elapsed % period
						t = if phase <= duration then phase / duration else 2 - phase / duration
					end
					local previous = Runtime.ctx
					Runtime.ctx = tween._ctx
					local ok, err = pcall(function()
						for key, goal in tween._goals do
							tween.Instance[key] = lerp(tween._from[key], goal, t)
						end
					end)
					Runtime.ctx = previous
					if not ok then
						Runtime.print("ERROR", "tween failed: " .. tostring(err))
						tween:_finish(Enum.PlaybackState.Cancelled)
					elseif elapsed >= total then
						tween:_finish(Enum.PlaybackState.Completed)
					end
				end
			end
		end
	end
end

method("TweenService", "Create", function(_self, instance, info, goals)
	if not I.isProxy(instance) then
		error("TweenService:Create expects an Instance", 2)
	end
	if type(info) ~= "table" or info._kind ~= "TweenInfo" then
		error("Unable to cast to TweenInfo", 2)
	end
	if type(goals) ~= "table" then
		error("Unable to cast to Dictionary", 2)
	end
	for key, value in goals do
		local ok, current = pcall(function()
			return instance[key]
		end)
		if not ok then
			error(string.format("TweenService:Create no property named '%s' for object '%s' (%s)", key, tostring(instance), tostring(current)), 2)
		end
		if typeof(current) ~= typeof(value) then
			error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')", key, typeof(current), typeof(value)), 2)
		end
	end
	return setmetatable({
		Instance = instance,
		TweenInfo = info,
		PlaybackState = Enum.PlaybackState.Begin,
		Completed = Runtime.newSignal("Completed"),
		_goals = table.clone(goals),
		_ctx = Runtime.ctx,
		_kind = "Tween",
	}, Tween)
end)
method("TweenService", "GetValue", function(_self, alpha)
	return alpha
end)

-- HttpService ---------------------------------------------------------------------------------

local function jsonCheck(value, path, seen)
	local t = typeof(value)
	if t == "table" then
		seen = seen or {}
		if seen[value] then
			error("Can't convert to JSON: cyclic table at " .. path, 0)
		end
		seen[value] = true
		local hasIndex = value[1] ~= nil
		local out = {}
		if hasIndex then
			for i, v in ipairs(value) do
				out[i] = jsonCheck(v, path .. "[" .. i .. "]", seen)
			end
			for k in value do
				if type(k) ~= "number" or k > #value or k < 1 or k % 1 ~= 0 then
					Runtime.note("JSON: mixed table at " .. path .. " (key " .. tostring(k) .. " is dropped)")
				end
			end
		else
			for k, v in value do
				local key = k
				if type(k) == "number" then
					Runtime.note("JSON: numeric key " .. tostring(k) .. " at " .. path .. " becomes a string")
					key = tostring(k)
				elseif type(k) ~= "string" then
					error("Can't convert to JSON: key of type " .. typeof(k) .. " at " .. path, 0)
				end
				out[key] = jsonCheck(v, path .. "." .. tostring(key), seen)
			end
		end
		seen[value] = nil
		return out
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			Runtime.note("JSON: non-finite number at " .. path)
		end
		return value
	elseif t == "string" or t == "boolean" or t == "nil" then
		return value
	end
	error("Can't convert to JSON: " .. t .. " at " .. path, 0)
end
Services.jsonCheck = jsonCheck

local function jsonEncode(value)
	local clean = jsonCheck(value, "value")
	if type(clean) == "table" and next(clean) == nil then
		return "[]"
	end
	return serde.encode("json", clean)
end
local function jsonDecode(text)
	if text == "[]" then
		return {}
	end
	return serde.decode("json", text)
end
Services.jsonEncode = jsonEncode
Services.jsonDecode = jsonDecode

method("HttpService", "JSONEncode", function(_self, value)
	local ok, result = pcall(jsonEncode, value)
	if not ok then
		error(result, 2)
	end
	return result
end)
method("HttpService", "JSONDecode", function(_self, text)
	local ok, result = pcall(jsonDecode, text)
	if not ok then
		error("Can't parse JSON", 2)
	end
	return result
end)
local guidCounter = 0
method("HttpService", "GenerateGUID", function(_self, braces)
	guidCounter += 1
	local hex = string.format("%08x-0000-4000-8000-%012x", guidCounter, guidCounter * 7919)
	return if braces == false then hex else "{" .. string.upper(hex) .. "}"
end)
method("HttpService", "UrlEncode", function(_self, text)
	return (string.gsub(text, "[^%w%-_%.~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end)
prop("HttpService", "HttpEnabled", function()
	return false
end)

-- DataStoreService ------------------------------------------------------------------------------

S.dataStores = S.dataStores or {}
Services.dataStoreCalls = 0

local function storeFor(name, scope, ordered)
	local key = (if ordered then "ordered:" else "") .. name .. "/" .. (scope or "global")
	local store = S.dataStores[key]
	if not store then
		store = { entries = {}, ordered = ordered }
		S.dataStores[key] = store
	end
	return store
end

local function keyInfo(entry)
	local metadata = entry and entry.metadata or {}
	local userIds = entry and entry.userIds or {}
	return {
		Version = entry and tostring(entry.version) or "0",
		CreatedTime = entry and entry.created or 0,
		UpdatedTime = entry and entry.updated or 0,
		GetMetadata = function()
			return table.clone(metadata)
		end,
		GetUserIds = function()
			return table.clone(userIds)
		end,
	}
end

local function dsYield()
	Services.dataStoreCalls += 1
	Runtime.task.wait(0.05)
end

local function encodeStored(value, key)
	local ok, text = pcall(jsonEncode, value)
	if not ok then
		error("104: Cannot store value in data store (" .. tostring(key) .. "): " .. tostring(text), 0)
	end
	if #text > 4194304 then
		error("105: Serialized value exceeds 4MB limit.", 0)
	end
	return text
end

local DataStore = {}
DataStore.__index = DataStore

function DataStore:GetAsync(key)
	dsYield()
	local entry = self._store.entries[key]
	if not entry then
		return nil, nil
	end
	return jsonDecode(entry.text), keyInfo(entry)
end
function DataStore:SetAsync(key, value, userIds, options)
	if type(key) ~= "string" or #key == 0 or #key > 50 then
		error("101: Key name can't be empty or longer than 50 characters", 2)
	end
	dsYield()
	local text = encodeStored(value, key)
	local entry = self._store.entries[key]
	local now = (Runtime.epoch + Runtime.now) * 1000
	if not entry then
		entry = { version = 0, created = now }
		self._store.entries[key] = entry
	end
	entry.text = text
	entry.version += 1
	entry.updated = now
	entry.userIds = userIds or {}
	entry.metadata = options and options._metadata or entry.metadata or {}
	return tostring(entry.version)
end
function DataStore:UpdateAsync(key, transform)
	if type(transform) ~= "function" then
		error("UpdateAsync expects a function", 2)
	end
	dsYield()
	local entry = self._store.entries[key]
	local current = if entry then jsonDecode(entry.text) else nil
	local newValue, userIds, metadata = transform(current, if entry then keyInfo(entry) else nil)
	if newValue == nil then
		return nil, nil
	end
	local text = encodeStored(newValue, key)
	local now = (Runtime.epoch + Runtime.now) * 1000
	if not entry then
		entry = { version = 0, created = now }
		self._store.entries[key] = entry
	end
	entry.text = text
	entry.version += 1
	entry.updated = now
	entry.userIds = userIds or entry.userIds or {}
	entry.metadata = metadata or entry.metadata or {}
	return jsonDecode(text), keyInfo(entry)
end
function DataStore:RemoveAsync(key)
	dsYield()
	local entry = self._store.entries[key]
	self._store.entries[key] = nil
	if entry then
		return jsonDecode(entry.text), keyInfo(entry)
	end
	return nil
end
function DataStore:IncrementAsync(key, delta)
	dsYield()
	local entry = self._store.entries[key]
	local value = (if entry then jsonDecode(entry.text) else 0) + (delta or 1)
	self:SetAsync(key, value)
	return value
end
function DataStore:GetVersionAsync(key)
	return self:GetAsync(key)
end
function DataStore:ListVersionsAsync()
	dsYield()
	return {
		GetCurrentPage = function()
			return {}
		end,
		IsFinished = true,
		AdvanceToNextPageAsync = function() end,
	}
end
function DataStore:ListKeysAsync()
	dsYield()
	local keys = {}
	for key in self._store.entries do
		table.insert(keys, { KeyName = key })
	end
	return {
		GetCurrentPage = function()
			return keys
		end,
		IsFinished = true,
		AdvanceToNextPageAsync = function() end,
	}
end
function DataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue)
	if not self._store.ordered then
		error("GetSortedAsync is only valid on OrderedDataStores", 2)
	end
	if type(pageSize) ~= "number" or pageSize < 1 or pageSize > 100 then
		error("Page size must be within 1 and 100", 2)
	end
	dsYield()
	local rows = {}
	for key, entry in self._store.entries do
		local value = jsonDecode(entry.text)
		if type(value) ~= "number" or value % 1 ~= 0 then
			error("OrderedDataStore values must be integers", 2)
		end
		if (minValue == nil or value >= minValue) and (maxValue == nil or value <= maxValue) then
			table.insert(rows, { key = key, value = value })
		end
	end
	table.sort(rows, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	local page = 1
	local pages = {}
	pages.IsFinished = #rows <= pageSize
	function pages:GetCurrentPage()
		local out = {}
		for i = (page - 1) * pageSize + 1, math.min(#rows, page * pageSize) do
			table.insert(out, rows[i])
		end
		return out
	end
	function pages:AdvanceToNextPageAsync()
		dsYield()
		page += 1
		pages.IsFinished = page * pageSize >= #rows
	end
	return pages
end

local function makeStore(name, scope, ordered)
	if type(name) ~= "string" or #name == 0 or #name > 50 then
		error("DataStore name can't be empty or longer than 50 characters", 3)
	end
	return setmetatable({ Name = name, _store = storeFor(name, scope, ordered) }, DataStore)
end

method("DataStoreService", "GetDataStore", function(_self, name, scope)
	return makeStore(name, if type(scope) == "string" then scope else nil, false)
end)
method("DataStoreService", "GetOrderedDataStore", function(_self, name, scope)
	local ctx = Runtime.ctx
	if ctx and ctx.kind == "client" then
		error("DataStoreService can only be used by the server", 2)
	end
	return makeStore(name, scope, true)
end)
method("DataStoreService", "GetGlobalDataStore", function()
	return makeStore("GlobalDataStore", nil, false)
end)
method("DataStoreService", "GetRequestBudgetForRequestType", function()
	return 100
end)

-- MessagingService -------------------------------------------------------------------------------

local topics = {}
method("MessagingService", "SubscribeAsync", function(_self, topic, callback)
	if type(callback) ~= "function" then
		error("SubscribeAsync expects a callback", 2)
	end
	local ctx = Runtime.ctx
	topics[topic] = topics[topic] or {}
	local entry = { fn = callback, ctx = ctx, connected = true }
	table.insert(topics[topic], entry)
	Runtime.task.wait(0.05)
	return {
		Connected = true,
		Disconnect = function(self)
			self.Connected = false
			entry.connected = false
		end,
	}
end)
method("MessagingService", "PublishAsync", function(_self, topic, message)
	local ok, text = pcall(jsonEncode, { m = message })
	if not ok then
		error("PublishAsync: " .. tostring(text), 2)
	end
	if #text > 1024 then
		error("PublishAsync: message exceeds 1kB", 2)
	end
	Runtime.task.wait(0.05)
	local decoded = jsonDecode(text).m
	for _, entry in topics[topic] or {} do
		if entry.connected then
			Runtime.delayIn(entry.ctx, 0.1, entry.fn, { Data = decoded, Sent = Runtime.epoch + Runtime.now })
		end
	end
end)

-- MarketplaceService -----------------------------------------------------------------------------

prop("MarketplaceService", "ProcessReceipt", function()
	error("ProcessReceipt is a callback member of MarketplaceService; you can only set the callback value, get is not available", 3)
end, function(_real, st, value)
	st.processReceipt = value
end)
local function ownsPass(userId, passId)
	local owned = S.userOwnsPass[userId]
	return owned ~= nil and owned[passId] == true
end
method("MarketplaceService", "UserOwnsGamePassAsync", function(_self, userId, passId)
	if type(passId) ~= "number" or passId <= 0 then
		error("UserOwnsGamePassAsync: invalid gamepass id " .. tostring(passId), 2)
	end
	Runtime.task.wait(0.05)
	return ownsPass(userId, passId)
end)
method("MarketplaceService", "PlayerOwnsAsset", function()
	return false
end)
method("MarketplaceService", "GetProductInfo", function(_self, id)
	Runtime.task.wait(0.05)
	return { Name = "Product " .. tostring(id), PriceInRobux = 99, IsForSale = true, Description = "" }
end)
method("MarketplaceService", "GetDeveloperProductsAsync", function()
	return {
		GetCurrentPage = function()
			return {}
		end,
		IsFinished = true,
	}
end)
local prompts = {}
Services.purchasePrompts = prompts
for _, name in { "PromptProductPurchase", "PromptGamePassPurchase", "PromptPurchase", "PromptPremiumPurchase", "PromptBundlePurchase" } do
	method("MarketplaceService", name, function(_self, player, id)
		local playerReal = unwrap(player)
		if typeof(playerReal) ~= "Instance" or not playerReal:IsA("Player") then
			error(name .. ": player argument must be a Player", 2)
		end
		if name ~= "PromptPremiumPurchase" and (type(id) ~= "number" or id <= 0) then
			Runtime.note(name .. " called with invalid id " .. tostring(id))
		end
		table.insert(prompts, { kind = name, player = playerReal, id = id, time = Runtime.now })
	end)
end
for _, name in {
	"PromptGamePassPurchaseFinished",
	"PromptProductPurchaseFinished",
	"PromptPurchaseFinished",
	"PromptPremiumPurchaseFinished",
	"PromptBundlePurchaseFinished",
} do
	event("MarketplaceService", name)
end

-- Other services ---------------------------------------------------------------------------------

event("ProximityPromptService", "PromptButtonHoldBegan")
event("ProximityPromptService", "PromptButtonHoldEnded")
event("ProximityPromptService", "PromptTriggered")
event("ProximityPromptService", "PromptTriggerEnded")
event("ProximityPromptService", "PromptShown")
event("ProximityPromptService", "PromptHidden")

-- Input (clients)
local function clientSetting(name, default)
	return function()
		local ctx = Runtime.ctx
		local settings = ctx and ctx.input
		if settings and settings[name] ~= nil then
			return settings[name]
		end
		return default
	end
end
prop("UserInputService", "TouchEnabled", clientSetting("TouchEnabled", false))
prop("UserInputService", "KeyboardEnabled", clientSetting("KeyboardEnabled", true))
prop("UserInputService", "MouseEnabled", clientSetting("MouseEnabled", true))
prop("UserInputService", "GamepadEnabled", clientSetting("GamepadEnabled", false))
prop("UserInputService", "VREnabled", function()
	return false
end)
prop("UserInputService", "AccelerometerEnabled", function()
	return false
end)
prop("UserInputService", "GyroscopeEnabled", function()
	return false
end)
prop("UserInputService", "PreferredInput", function()
	return Enum.PreferredInput and Enum.PreferredInput.KeyboardAndMouse or nil
end)
method("UserInputService", "GetLastInputType", function()
	local ctx = Runtime.ctx
	return ctx and ctx.input and ctx.input.LastInputType or Enum.UserInputType.Keyboard
end)
method("UserInputService", "IsKeyDown", function()
	return false
end)
method("UserInputService", "IsMouseButtonPressed", function()
	return false
end)
method("UserInputService", "GetConnectedGamepads", function()
	return {}
end)
method("UserInputService", "GetGamepadConnected", function()
	return false
end)
method("UserInputService", "GetNavigationGamepads", function()
	return {}
end)
method("UserInputService", "GetMouseLocation", function()
	return Vector2.zero
end)
method("UserInputService", "GetMouseDelta", function()
	return Vector2.zero
end)
method("UserInputService", "GetFocusedTextBox", function()
	return nil
end)
method("UserInputService", "GetKeysPressed", function()
	return {}
end)
method("UserInputService", "GetStringForKeyCode", function(_self, keyCode)
	return keyCode.Name
end)
method("UserInputService", "GetImageForKeyCode", function()
	return ""
end)
for _, name in {
	"InputBegan",
	"InputEnded",
	"InputChanged",
	"LastInputTypeChanged",
	"GamepadConnected",
	"GamepadDisconnected",
	"TouchStarted",
	"TouchEnded",
	"TouchMoved",
	"TouchTap",
	"JumpRequest",
	"WindowFocused",
	"WindowFocusReleased",
	"TextBoxFocused",
	"TextBoxFocusReleased",
} do
	event("UserInputService", name)
end

local actions = {} -- ctx -> { name -> { fn, keys } }
Services.actions = actions
local function bindAction(_self, name, fn, createButton, ...)
	local ctx = Runtime.ctx
	if not ctx or ctx.kind ~= "client" then
		error("ContextActionService is client-only", 3)
	end
	if type(fn) ~= "function" then
		error("BindAction expects a function", 3)
	end
	actions[ctx] = actions[ctx] or {}
	actions[ctx][name] = { fn = fn, keys = { ... }, button = createButton }
end
method("ContextActionService", "BindAction", bindAction)
method("ContextActionService", "BindActionAtPriority", function(self, name, fn, createButton, _priority, ...)
	bindAction(self, name, fn, createButton, ...)
end)
method("ContextActionService", "UnbindAction", function(_self, name)
	local ctx = Runtime.ctx
	if actions[ctx] then
		actions[ctx][name] = nil
	end
end)
method("ContextActionService", "UnbindAllActions", function()
	actions[Runtime.ctx] = {}
end)
for _, name in { "SetTitle", "SetImage", "SetDescription", "SetPosition" } do
	method("ContextActionService", name, function() end)
end
method("ContextActionService", "GetButton", function()
	return nil
end)
method("ContextActionService", "GetAllBoundActionInfo", function()
	return {}
end)
event("ContextActionService", "LocalToolEquipped")
event("ContextActionService", "LocalToolUnequipped")

method("GuiService", "IsTenFootInterface", function()
	local ctx = Runtime.ctx
	return ctx ~= nil and ctx.input ~= nil and ctx.input.TenFoot == true
end)
method("GuiService", "GetGuiInset", function()
	return Vector2.new(0, 58), Vector2.zero
end)
method("GuiService", "AddSelectionParent", function() end)
method("GuiService", "RemoveSelectionGroup", function() end)
method("GuiService", "CloseInspectMenu", function() end)
method("GuiService", "Select", function() end)
prop("GuiService", "TopbarInset", function()
	return roblox.Rect.new(0, 0, 1280, 58)
end)
event("GuiService", "MenuOpened")
event("GuiService", "MenuClosed")

method("StarterGui", "SetCoreGuiEnabled", function() end)
method("StarterGui", "GetCoreGuiEnabled", function()
	return true
end)
method("StarterGui", "SetCore", function() end)
method("StarterGui", "GetCore", function()
	return nil
end)

method("SoundService", "PlayLocalSound", function() end)
method("SoundService", "SetListener", function() end)

method("Debris", "AddItem", function(_self, item, lifetime)
	local real = unwrap(item)
	Runtime.delayIn(Runtime.ctx, lifetime or 10, function()
		local st = states[real]
		if not (st and st.destroyed) then
			I.destroy(real, { force = true })
		end
	end)
end)

method("PathfindingService", "CreatePath", function(_self, params)
	local path = { Status = Enum.PathStatus.NoPath, _waypoints = {}, Blocked = Runtime.newSignal("Blocked"), Unblocked = Runtime.newSignal("Unblocked") }
	function path:ComputeAsync(from, to)
		Runtime.task.wait(0.05)
		self.Status = Enum.PathStatus.Success
		self._waypoints = {
			{ Position = from, Action = Enum.PathWaypointAction.Walk, Label = "" },
			{ Position = to, Action = Enum.PathWaypointAction.Walk, Label = "" },
		}
	end
	function path:GetWaypoints()
		return table.clone(self._waypoints)
	end
	function path:CheckOcclusionAsync()
		return -1
	end
	function path:Destroy() end
	return path
end)

method("PhysicsService", "RegisterCollisionGroup", function() end)
method("PhysicsService", "UnregisterCollisionGroup", function() end)
method("PhysicsService", "CollisionGroupSetCollidable", function() end)
method("PhysicsService", "CollisionGroupsAreCollidable", function()
	return true
end)
method("PhysicsService", "IsCollisionGroupRegistered", function()
	return true
end)
method("PhysicsService", "GetRegisteredCollisionGroups", function()
	return {}
end)
method("PhysicsService", "GetMaxCollisionGroups", function()
	return 32
end)

method("Lighting", "GetMinutesAfterMidnight", function(self)
	return selfReal(self, "GetMinutesAfterMidnight").ClockTime * 60
end)
method("Lighting", "SetMinutesAfterMidnight", function(self, minutes)
	selfReal(self, "SetMinutesAfterMidnight").ClockTime = minutes / 60
end)
method("Lighting", "GetSunDirection", function()
	return Vector3.new(0.3, 0.8, 0.2).Unit
end)
event("Lighting", "LightingChanged")

method("TextService", "GetTextSize", function(_self, text, size)
	return Vector2.new(#text * size * 0.55, size)
end)
method("TextService", "FilterStringAsync", function(_self, text)
	return {
		GetNonChatStringForBroadcastAsync = function()
			return text
		end,
		GetNonChatStringForUserAsync = function()
			return text
		end,
		GetChatForUserAsync = function()
			return text
		end,
	}
end)

method("BadgeService", "AwardBadge", function()
	return true
end)
method("BadgeService", "UserHasBadgeAsync", function()
	return false
end)
method("BadgeService", "GetBadgeInfoAsync", function()
	return { IsEnabled = true, Name = "Badge" }
end)
method("GroupService", "GetGroupInfoAsync", function()
	return { Name = "Group", Id = 0 }
end)
method("PolicyService", "GetPolicyInfoForPlayerAsync", function()
	return { ArePaidRandomItemsRestricted = false, AllowedExternalLinkReferences = {}, IsSubjectToChinaPolicies = false, IsPaidItemTradingAllowed = true }
end)
method("LocalizationService", "GetCountryRegionForPlayerAsync", function()
	return "US"
end)
method("TeleportService", "TeleportAsync", function()
	error("Teleport is not available in the emulator", 2)
end)
method("SocialService", "CanSendGameInviteAsync", function()
	return false
end)
method("SocialService", "PromptGameInvite", function() end)
method("AnalyticsService", "LogEconomyEvent", function() end)
method("AnalyticsService", "LogCustomEvent", function() end)
method("AnalyticsService", "LogOnboardingFunnelStepEvent", function() end)
method("AnalyticsService", "LogProgressionEvent", function() end)

return Services
