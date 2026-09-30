--!strict
-- Client copy of the player's profile and derived values. The server pushes changes via
-- StateChanged; controllers subscribe with State.OnChange.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local State = {}

State.Data = {} :: { [string]: any }
State.Derived = {} :: { [string]: any }
State.Loaded = false
State.Changed = Signal.new() :: Signal.Signal<string, any>
State.Ready = Signal.new() :: Signal.Signal<>
State.ServerOffset = 0

function State.Get(key: string): any
	return State.Data[key]
end

function State.GetDerived(key: string): any
	return State.Derived[key]
end

-- Calls `callback(value)` now (if loaded) and whenever the key changes.
-- Derived keys are prefixed with "@": State.OnChange("@IncomePerSecond", fn)
function State.OnChange(key: string, callback: (any) -> ())
	local function read(): any
		if string.sub(key, 1, 1) == "@" then
			return State.Derived[string.sub(key, 2)]
		end
		return State.Data[key]
	end
	if State.Loaded then
		task.spawn(callback, read())
	end
	State.Changed:Connect(function(changedKey)
		if changedKey == key then
			callback(read())
		end
	end)
end

function State.WaitUntilLoaded()
	if not State.Loaded then
		State.Ready:Wait()
	end
end

local function apply(payload: { [string]: any })
	for key, value in payload do
		if key == "@Derived" then
			for name, derivedValue in value do
				State.Derived[name] = derivedValue
				State.Changed:Fire("@" .. name, derivedValue)
			end
		else
			State.Data[key] = value
			State.Changed:Fire(key, value)
		end
	end
end

function State.Init()
	Net.Event("StateChanged").OnClientEvent:Connect(function(payload)
		if State.Loaded then
			apply(payload)
		else
			-- queue until the snapshot lands
			task.spawn(function()
				State.WaitUntilLoaded()
				apply(payload)
			end)
		end
	end)
end

function State.Start()
	while true do
		local ok, result = pcall(function()
			return Net.Function("GetState"):InvokeServer()
		end)
		if ok and type(result) == "table" and result.Ok and result.State then
			State.Data = result.State.Data
			State.Derived = result.State.Derived or {}
			State.ServerOffset = (result.ServerTime or os.time()) - os.time()
			State.Loaded = true
			State.Ready:Fire()
			for key, value in State.Data do
				State.Changed:Fire(key, value)
			end
			for key, value in State.Derived do
				State.Changed:Fire("@" .. key, value)
			end
			return
		end
		task.wait(2)
	end
end

-- Income multipliers as the server computes them (for showing effective $/s)
function State.IncomeContext(): { Rebirths: number, IndexBonus: number, PassMultiplier: number }
	local passes = State.Derived.Passes or {}
	local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
	local mult = 1
	if passes.VIP then
		mult *= Monetization.VIPCash
	end
	if passes.DoubleCash then
		mult *= Monetization.DoubleCash
	end
	return {
		Rebirths = State.Data.Rebirths or 0,
		IndexBonus = State.Derived.IndexBonus or 0,
		PassMultiplier = mult,
	}
end

function State.IsDiscovered(characterId: string): boolean
	local index = State.Data.Index
	local entry = if type(index) == "table" then index[characterId] else nil
	return entry ~= nil and entry.Discovered == true
end

-- Server unix time (for countdowns)
function State.Now(): number
	return workspace:GetServerTimeNow()
end

return State
