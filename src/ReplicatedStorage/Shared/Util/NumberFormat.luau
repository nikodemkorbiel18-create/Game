--!strict
-- Big-number formatting: 1.25K, 3.4M, 7B, 1.2T, Qd, Qn, Sx, Sp, Oc, No, Dc.

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

local function trimZeros(text: string): string
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

-- Short form with up to `decimals` decimals (default 2).
function NumberFormat.Short(value: number, decimals: number?): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	local places = decimals or 2
	if value < 1000 then
		if value < 10 and value % 1 ~= 0 then
			return sign .. trimZeros(string.format("%.1f", math.floor(value * 10) / 10))
		end
		return sign .. tostring(math.floor(value))
	end
	local tier = math.floor(math.log10(value) / 3)
	if tier >= #SUFFIXES then
		return sign .. string.format("%.2e", value)
	end
	local scaled = value / (1000 ^ tier)
	-- floor instead of round so "999.999K" never shows as "1000K"
	local factor = 10 ^ places
	scaled = math.floor(scaled * factor) / factor
	return sign .. trimZeros(string.format("%." .. places .. "f", scaled)) .. SUFFIXES[tier + 1]
end

function NumberFormat.Cash(value: number): string
	return "$" .. NumberFormat.Short(value)
end

function NumberFormat.PerSecond(value: number): string
	return "$" .. NumberFormat.Short(value) .. "/s"
end

-- Thousands separators for exact values: 1234567 -> "1,234,567"
function NumberFormat.Commas(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	formatted = string.gsub(formatted, "^,", "")
	return (if value < 0 then "-" else "") .. formatted
end

function NumberFormat.Kg(value: number): string
	return string.format("%.1f kg", value)
end

function NumberFormat.Percent(fraction: number, decimals: number?): string
	local places = decimals or 1
	return trimZeros(string.format("%." .. places .. "f", fraction * 100)) .. "%"
end

return NumberFormat
