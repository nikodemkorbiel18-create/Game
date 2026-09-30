--!strict
-- Pacing targets and the assumptions used by Shared/Balancing/Simulator.
-- Run tools/simulate.luau (Lune) or require the Simulator in Studio's command bar.

local Balancing = {
	-- Target time (minutes) for a non-paying player to reach each zone.
	ZoneTargets = { [2] = 3, [3] = 10, [4] = 25, [5] = 50, [6] = 90, [7] = 150, [8] = 240, [9] = 360, [10] = 540, [11] = 720 },
	FirstRebirthTarget = { 90, 120 },

	-- Simulation assumptions
	Sim = {
		HoursToSimulate = 20,
		TickSeconds = 1,
		HomeToZone1Distance = 110, -- studs from a base to zone 1's nest
		ZoneSpacing = 112, -- studs between consecutive nests
		GrabOverhead = 6, -- seconds lost per trip (grab, placing, dodging)
		CatchChanceAtSpeed = 0.15, -- chance to lose the egg on a trip when barely fast enough
		Competition = 0.4, -- share of each reset's eggs taken by other players first
		Seed = 20260930,
	},
}

return Balancing
