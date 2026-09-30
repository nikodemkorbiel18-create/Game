--!strict
-- Durations: 45s, 3m 05s, 1h 02m, 2d 03h.

local TimeFormat = {}

function TimeFormat.Short(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	elseif seconds < 86400 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%dd %02dh", seconds // 86400, (seconds % 86400) // 3600)
end

-- Clock style for countdowns: 4:59, 1:02:03
function TimeFormat.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- "2027-12-31" -> unix time at the end of that UTC day
function TimeFormat.ParseDateEnd(date: string): number?
	local year, month, day = string.match(date, "^(%d+)-(%d+)-(%d+)$")
	if not year then
		return nil
	end
	local y, m, d = tonumber(year) :: number, tonumber(month) :: number, tonumber(day) :: number
	-- days from civil (Howard Hinnant's algorithm), UTC
	local yy = if m <= 2 then y - 1 else y
	local era = (if yy >= 0 then yy else yy - 399) // 400
	local yoe = yy - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	local days = era * 146097 + doe - 719468
	return days * 86400 + 86399
end

-- UTC day number (for login streaks)
function TimeFormat.Day(unix: number): number
	return unix // 86400
end

return TimeFormat
