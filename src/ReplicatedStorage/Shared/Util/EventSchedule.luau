--!strict
-- Deterministic event schedule from os.time() (UTC). Server and client compute the same
-- answer, so every server runs the same events at the same moment.

local Events = require(script.Parent.Parent.Config.Events)

export type Window = { Id: string, StartsAt: number, EndsAt: number }

local EventSchedule = {}

-- Small deterministic hash -> [0, 1)
local function hash01(a: number, b: number): number
	local x = (a * 374761393 + b * 668265263) % 2147483647
	x = (x * 1103515245 + 12345) % 2147483647
	x = (x * 1103515245 + 12345) % 2147483647
	return x / 2147483647
end

local function saltFor(id: string): number
	local salt = 0
	for i = 1, #id do
		salt = (salt * 31 + string.byte(id, i)) % 1000003
	end
	return salt
end

local WEEK = 7 * 86400
-- 1970-01-01 was a Thursday; os.date wday: 1 = Sunday
local function weekdayOf(unix: number): number
	local days = unix // 86400
	return ((days + 4) % 7) + 1
end

-- The weekly window that contains or most recently preceded `now`
local function weeklyWindow(def: Events.EventDef, now: number): Window
	local dayStart = now - (now % 86400)
	local offsetDays = ((weekdayOf(now) - (def.Weekday :: number)) % 7)
	local start = dayStart - offsetDays * 86400 + (def.Hour :: number) * 3600 + (def.Minute :: number) * 60
	if start > now then
		start -= WEEK
	end
	return { Id = def.Id, StartsAt = start, EndsAt = start + def.Duration }
end

local function hourlyWindow(def: Events.EventDef, hourIndex: number): Window?
	local salt = saltFor(def.Id)
	if hash01(hourIndex, salt) >= (def.Chance :: number) then
		return nil
	end
	local maxOffset = math.max(0, 3600 - def.Duration)
	local offset = math.floor(hash01(hourIndex, salt + 7919) * maxOffset)
	local start = hourIndex * 3600 + offset
	return { Id = def.Id, StartsAt = start, EndsAt = start + def.Duration }
end

-- Scheduled events active at `now`
function EventSchedule.Active(now: number): { Window }
	local active = {}
	for _, def in Events.List do
		if def.Kind == "Weekly" then
			local window = weeklyWindow(def, now)
			if now >= window.StartsAt and now < window.EndsAt then
				table.insert(active, window)
			end
		elseif def.Kind == "Hourly" then
			local window = hourlyWindow(def, now // 3600)
			if window and now >= window.StartsAt and now < window.EndsAt then
				table.insert(active, window)
			end
		end
	end
	return active
end

-- Next start time of each scheduled event after `now` (for the HUD)
function EventSchedule.Upcoming(now: number): { Window }
	local upcoming = {}
	for _, def in Events.List do
		if def.Kind == "Weekly" then
			local window = weeklyWindow(def, now)
			if window.StartsAt <= now then
				window = { Id = def.Id, StartsAt = window.StartsAt + WEEK, EndsAt = window.EndsAt + WEEK }
			end
			table.insert(upcoming, window)
		elseif def.Kind == "Hourly" then
			for hour = now // 3600, now // 3600 + 24 do
				local window = hourlyWindow(def, hour)
				if window and window.StartsAt > now then
					table.insert(upcoming, window)
					break
				end
			end
		end
	end
	table.sort(upcoming, function(a, b)
		return a.StartsAt < b.StartsAt
	end)
	return upcoming
end

EventSchedule._weekdayOf = weekdayOf

return EventSchedule
