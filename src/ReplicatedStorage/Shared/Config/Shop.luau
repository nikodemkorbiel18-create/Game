--!strict
-- Cash shop prices: pen levels and barrier upgrades. Treadmills, trails and items
-- have their own config modules.

local Shop = {
	-- Pen levels 1..10. Level 1 is free.
	PenLevels = {
		{ Level = 1, Slots = 4, Price = 0 },
		{ Level = 2, Slots = 6, Price = 500 },
		{ Level = 3, Slots = 8, Price = 3000 },
		{ Level = 4, Slots = 10, Price = 18000 },
		{ Level = 5, Slots = 12, Price = 108000 },
		{ Level = 6, Slots = 14, Price = 648000 },
		{ Level = 7, Slots = 16, Price = 3900000 },
		{ Level = 8, Slots = 18, Price = 23000000 },
		{ Level = 9, Slots = 20, Price = 140000000 },
		{ Level = 10, Slots = 24, Price = 840000000 },
	},
	-- Barrier Lock duration upgrades (seconds). Level 1 is the default.
	BarrierLevels = {
		{ Level = 1, Duration = 60, Price = 0 },
		{ Level = 2, Duration = 90, Price = 25000 },
		{ Level = 3, Duration = 120, Price = 1500000 },
		{ Level = 4, Duration = 150, Price = 90000000 },
		{ Level = 5, Duration = 180, Price = 5000000000 },
	},
}

function Shop.PenSlots(level: number): number
	local entry = Shop.PenLevels[math.clamp(level, 1, #Shop.PenLevels)]
	return entry.Slots
end

function Shop.BarrierDuration(level: number): number
	local entry = Shop.BarrierLevels[math.clamp(level, 1, #Shop.BarrierLevels)]
	return entry.Duration
end

return Shop
