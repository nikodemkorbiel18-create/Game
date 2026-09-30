--!strict
-- Consumable items bought in the Item Shop. Prices scale with your income so they stay
-- meaningful: price = max(BasePrice, IncomeSeconds * your effective $/s).

local Items = {
	OfudaTrap = {
		Id = "OfudaTrap",
		DisplayName = "Sticky Ofuda Trap",
		Description = "Place on the ground. A Guardian that touches it is frozen.",
		BasePrice = 750,
		IncomeSeconds = 20,
		Freeze = 3,
		TrapMasterFreeze = 4.5,
		StartCount = 3,
		Capacity = 10,
		TrapMasterCapacity = 5,
		Lifetime = 120,
		TriggerRadius = 4,
		MaxPlacedPerPlayer = 3,
		Cooldown = 1,
	},
	SmokeBomb = {
		Id = "SmokeBomb",
		DisplayName = "Smoke Bomb",
		Description = "Breaks every nearby Guardian's line of sight.",
		BasePrice = 5000,
		IncomeSeconds = 90,
		Duration = 2,
		Radius = 40,
		Capacity = 5,
		Cooldown = 3,
	},
}

function Items.Price(itemId: string, incomePerSecond: number): number
	local item = (Items :: any)[itemId]
	assert(item and item.BasePrice, "Unknown item " .. itemId)
	return math.floor(math.max(item.BasePrice, item.IncomeSeconds * incomePerSecond))
end

return Items
