--!strict
-- Live events: scheduled (from os.time, identical in every server) plus admin-started
-- events broadcast through MessagingService and remembered in a DataStore so servers that
-- start later pick them up. Also tracks the Server Luck product.
-- State is published on ReplicatedStorage attributes for clients:
--   ActiveEvents (JSON list of { Id, EndsAt }), ServerLuckUntil, ServerLuckBuyer

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local EventSchedule = require(Shared.Util.EventSchedule)
local TimeFormat = require(Shared.Util.TimeFormat)
local Signal = require(Shared.Util.Signal)
local AnnouncementService = require(script.Parent.AnnouncementService)

local EventService = {}

local TOPIC = "StealAChibi_AdminEvents"
local STORE_KEY = "AdminEvents"

local manual: { [string]: number } = {} -- event id -> ends at
local active: { [string]: number } = {} -- currently active (id -> ends at)
local serverLuckUntil = 0

EventService.Started = Signal.new() :: Signal.Signal<string>
EventService.Ended = Signal.new() :: Signal.Signal<string>

function EventService.IsActive(id: string): boolean
	local endsAt = active[id]
	return endsAt ~= nil and endsAt > os.time()
end

function EventService.Effect(effect: string): number
	local value = 1
	for id in active do
		local def = Events.ById[id]
		if def and def.Effects[effect] then
			value *= def.Effects[effect]
		end
	end
	return value
end

function EventService.MutationChanceMultiplier(): number
	return EventService.Effect("MutationChance")
end

function EventService.SecretChanceMultiplier(zoneId: number): number
	if table.find(Events.EclipseZones, zoneId) then
		return EventService.Effect("SecretChance")
	end
	return 1
end

function EventService.HatchSpeed(): number
	return EventService.Effect("HatchSpeed")
end

function EventService.FestivalActive(): boolean
	return EventService.IsActive("Matsuri")
end

function EventService.ServerLuck(): number
	return if serverLuckUntil > os.time() then Monetization.ServerLuckMultiplier else 1
end

function EventService.StartServerLuck(buyer: Player)
	local now = os.time()
	serverLuckUntil = math.max(serverLuckUntil, now) + Monetization.ServerLuckMinutes * 60
	ReplicatedStorage:SetAttribute("ServerLuckUntil", serverLuckUntil)
	ReplicatedStorage:SetAttribute("ServerLuckBuyer", buyer.DisplayName)
	AnnouncementService.Announce(
		string.format("%s activated SERVER LUCK! Rare eggs x2 for %d minutes!", string.upper(buyer.DisplayName), Monetization.ServerLuckMinutes),
		"#7CFF4F"
	)
end

local function publish()
	local list = {}
	for id, endsAt in active do
		table.insert(list, { Id = id, EndsAt = endsAt })
	end
	ReplicatedStorage:SetAttribute("ActiveEvents", HttpService:JSONEncode(list))
end

local function refresh()
	local now = os.time()
	local current: { [string]: number } = {}
	for _, window in EventSchedule.Active(now) do
		current[window.Id] = window.EndsAt
	end
	for id, endsAt in manual do
		if endsAt > now then
			current[id] = math.max(current[id] or 0, endsAt)
		else
			manual[id] = nil
		end
	end
	local changed = false
	for id, endsAt in current do
		if active[id] == nil then
			changed = true
			local def = Events.ById[id]
			if def then
				AnnouncementService.Announce(
					string.format("%s! %s (%s)", string.upper(def.DisplayName), def.Description, TimeFormat.Short(endsAt - now)),
					def.Color,
					"Event"
				)
			end
			active[id] = endsAt
			EventService.Started:Fire(id)
		elseif active[id] ~= endsAt then
			active[id] = endsAt
			changed = true
		end
	end
	for id in active do
		if current[id] == nil then
			active[id] = nil
			changed = true
			EventService.Ended:Fire(id)
		end
	end
	if changed then
		publish()
	end
end

local function persist()
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		pcall(function()
			local store = DataStoreService:GetDataStore("StealAChibi_Global")
			store:SetAsync(STORE_KEY, manual)
		end)
	end)
end

-- Starts an event in this server (and every server when global = true).
function EventService.StartManual(id: string, durationSeconds: number, global: boolean?)
	if not Events.ById[id] then
		return false
	end
	manual[id] = os.time() + durationSeconds
	refresh()
	if global and not RunService:IsStudio() then
		persist()
		task.spawn(function()
			pcall(function()
				MessagingService:PublishAsync(TOPIC, { Id = id, EndsAt = manual[id], Server = game.JobId })
			end)
		end)
	end
	return true
end

function EventService.StopManual(id: string)
	manual[id] = nil
	refresh()
end

function EventService.ActiveList(): { [string]: number }
	return table.clone(active)
end

function EventService.Init()
	ReplicatedStorage:SetAttribute("ActiveEvents", "[]")
	ReplicatedStorage:SetAttribute("ServerLuckUntil", 0)
end

function EventService.Start()
	if not RunService:IsStudio() then
		task.spawn(function()
			pcall(function()
				local store = DataStoreService:GetDataStore("StealAChibi_Global")
				local saved = store:GetAsync(STORE_KEY)
				if type(saved) == "table" then
					for id, endsAt in saved do
						if type(id) == "string" and type(endsAt) == "number" and endsAt > os.time() then
							manual[id] = endsAt
						end
					end
				end
			end)
			pcall(function()
				MessagingService:SubscribeAsync(TOPIC, function(message)
					local data = message.Data
					if type(data) == "table" and data.Server ~= game.JobId and type(data.Id) == "string" and type(data.EndsAt) == "number" then
						manual[data.Id] = data.EndsAt
					end
				end)
			end)
		end)
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)
end

return EventService
