--!strict
-- Input validation for anything arriving from a client. Every remote handler runs its
-- arguments through these before touching game state.

local Guard = {}

function Guard.String(value: unknown, maxLength: number?): string?
	if type(value) ~= "string" then
		return nil
	end
	if #value == 0 or #value > (maxLength or 64) then
		return nil
	end
	return value
end

function Guard.Number(value: unknown, min: number?, max: number?): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if min and value < min then
		return nil
	end
	if max and value > max then
		return nil
	end
	return value
end

function Guard.Integer(value: unknown, min: number?, max: number?): number?
	local number = Guard.Number(value, min, max)
	if number == nil or number % 1 ~= 0 then
		return nil
	end
	return number
end

function Guard.Boolean(value: unknown): boolean?
	if type(value) ~= "boolean" then
		return nil
	end
	return value
end

-- Array of short strings (e.g. item uids), bounded length
function Guard.StringList(value: unknown, maxCount: number, maxLength: number?): { string }?
	if type(value) ~= "table" then
		return nil
	end
	local list = value :: { [any]: any }
	local result = {}
	local count = 0
	for key, entry in list do
		count += 1
		if count > maxCount or type(key) ~= "number" then
			return nil
		end
		local text = Guard.String(entry, maxLength)
		if text == nil then
			return nil
		end
		table.insert(result, text)
	end
	return result
end

function Guard.OneOf(value: unknown, options: { string }): string?
	if type(value) == "string" and table.find(options, value) then
		return value
	end
	return nil
end

return Guard
