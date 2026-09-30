--!strict
-- Server-side remote wrappers: per-player, per-remote rate limiting and error isolation.
-- Handlers for RemoteFunctions return a result table; errors become { Ok = false }.

local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local GameSettings = require(game:GetService("ReplicatedStorage").Shared.Config.GameSettings)

local Remote = {}

type Bucket = { Tokens: number, Last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

local function allow(player: Player, name: string, perSecond: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { Tokens = perSecond, Last = now }
		playerBuckets[name] = bucket
	end
	bucket.Tokens = math.min(perSecond, bucket.Tokens + (now - bucket.Last) * perSecond)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

function Remote.OnEvent(name: string, handler: (Player, ...any) -> (), perSecond: number?)
	local limit = perSecond or GameSettings.AntiExploit.RemoteRateLimit
	Net.Event(name).OnServerEvent:Connect(function(player: Player, ...)
		if not allow(player, name, limit) then
			return
		end
		local args = table.pack(...)
		local ok, err = pcall(function(): nil
			handler(player, table.unpack(args, 1, args.n))
			return nil
		end)
		if not ok then
			warn(string.format("[Remote] %s from %s failed: %s", name, player.Name, tostring(err)))
		end
	end)
end

export type Result = { [string]: any }

function Remote.OnInvoke(name: string, handler: (Player, ...any) -> Result, perSecond: number?)
	local limit = perSecond or GameSettings.AntiExploit.RemoteRateLimit
	Net.Function(name).OnServerInvoke = function(player: Player, ...)
		if not allow(player, name, limit) then
			return { Ok = false, Error = "Slow down!" }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Remote] %s from %s failed: %s", name, player.Name, tostring(result)))
			return { Ok = false, Error = "Something went wrong." }
		end
		return result
	end
end

function Remote.Fire(name: string, player: Player, ...: any)
	Net.Event(name):FireClient(player, ...)
end

function Remote.FireAll(name: string, ...: any)
	Net.Event(name):FireAllClients(...)
end

return Remote
