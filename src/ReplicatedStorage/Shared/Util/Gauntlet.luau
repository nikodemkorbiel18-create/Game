--!strict
-- Deterministic gauntlet hazard math shared by the server (hit detection) and clients
-- (rendering). Everything is a function of server time, so no per-frame messages are needed.

local Endgame = require(script.Parent.Parent.Config.Endgame)

local Gauntlet = {}

local boss = Endgame.Boss

-- Active shockwave radii at time `t` (seconds, server clock)
function Gauntlet.ShockwaveRadii(t: number): { number }
	local shock = boss.Shockwave
	local lifetime = shock.MaxRadius / shock.Speed
	local radii = {}
	local newest = math.floor(t / shock.Interval)
	for index = newest, newest - math.ceil(lifetime / shock.Interval), -1 do
		local age = t - index * shock.Interval
		if age >= 0 and age <= lifetime then
			table.insert(radii, age * shock.Speed)
		end
	end
	return radii
end

-- Staff angle in radians at time `t`
function Gauntlet.StaffAngle(t: number): number
	return math.rad((t * boss.Staff.DegreesPerSecond) % 360)
end

-- Distance (XZ) from a point to the staff's full bar through the pivot
function Gauntlet.StaffDistance(t: number, pivot: Vector3, point: Vector3): number
	local angle = Gauntlet.StaffAngle(t)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local offset = (point - pivot) * Vector3.new(1, 0, 1)
	local along = math.clamp(offset:Dot(direction), -boss.Staff.Length / 2, boss.Staff.Length / 2)
	local closest = direction * along
	return (offset - closest).Magnitude
end

return Gauntlet
