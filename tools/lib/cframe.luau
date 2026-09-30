--!nocheck
-- Lune's CFrame.lookAt (and the two-point CFrame.new) flip the Z component of the look
-- direction compared to Roblox. This wraps roblox.CFrame with Roblox-correct versions for
-- every tool (map builders, test harnesses, the emulator).

local roblox = require("@lune/roblox")

local RealCFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local function lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = target - at
	if look.Magnitude < 1e-9 then
		return RealCFrame.new(at)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.zAxis)
		if right.Magnitude < 1e-6 then
			right = look:Cross(Vector3.xAxis)
		end
	end
	right = right.Unit
	local upVector = right:Cross(look).Unit
	return RealCFrame.fromMatrix(at, right, upVector, -look)
end

local CFrame = setmetatable({
	lookAt = lookAt,
	new = function(...)
		local a, b = ...
		if select("#", ...) == 2 and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			return lookAt(a, b)
		end
		return RealCFrame.new(...)
	end,
}, { __index = RealCFrame })

return CFrame
