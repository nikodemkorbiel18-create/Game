--!strict
-- Size tiers. Size is visible as physical scale; weight (kg) nudges income inside a tier.

export type Size = {
	Id: string,
	Rank: number,
	DisplayName: string,
	MinKg: number,
	MaxKg: number,
	Income: number,
	HatchTime: number,
	Carry: number, -- WalkSpeed multiplier while carrying
	Jump: number, -- JumpHeight multiplier while carrying (0 = cannot jump)
	Chance: number, -- spawn weight (percent)
	Scale: number, -- visual scale of eggs and characters
}

local list: { Size } = {
	{ Id = "Tiny", Rank = 1, DisplayName = "Tiny", MinKg = 0.5, MaxKg = 1.9, Income = 0.5, HatchTime = 0.5, Carry = 0.95, Jump = 1, Chance = 15, Scale = 0.7 },
	{ Id = "Small", Rank = 2, DisplayName = "Small", MinKg = 2, MaxKg = 4.9, Income = 0.8, HatchTime = 0.8, Carry = 0.90, Jump = 1, Chance = 25, Scale = 0.85 },
	{ Id = "Normal", Rank = 3, DisplayName = "Normal", MinKg = 5, MaxKg = 9.9, Income = 1.0, HatchTime = 1.0, Carry = 0.85, Jump = 1, Chance = 38, Scale = 1 },
	{ Id = "Large", Rank = 4, DisplayName = "Large", MinKg = 10, MaxKg = 24.9, Income = 1.5, HatchTime = 1.5, Carry = 0.75, Jump = 0.8, Chance = 15, Scale = 1.25 },
	{ Id = "Huge", Rank = 5, DisplayName = "Huge", MinKg = 25, MaxKg = 59.9, Income = 2.5, HatchTime = 2.5, Carry = 0.60, Jump = 0.8, Chance = 6, Scale = 1.6 },
	{ Id = "Titan", Rank = 6, DisplayName = "Titan", MinKg = 60, MaxKg = 150, Income = 5.0, HatchTime = 4.0, Carry = 0.45, Jump = 0, Chance = 1, Scale = 2.1 },
}

local byId: { [string]: Size } = {}
for _, size in list do
	byId[size.Id] = size
end

local Sizes = {
	List = list,
	ById = byId,
	-- Within a tier, income scales linearly with exact kg across +/- this fraction.
	KgSpread = 0.2,
}

function Sizes.Get(rank: number): Size
	local size = list[rank]
	assert(size, "Unknown size tier " .. tostring(rank))
	return size
end

-- 0.8 at the lightest kg of the tier, 1.2 at the heaviest.
function Sizes.KgScale(rank: number, kg: number): number
	local size = Sizes.Get(rank)
	local span = size.MaxKg - size.MinKg
	if span <= 0 then
		return 1
	end
	local t = math.clamp((kg - size.MinKg) / span, 0, 1)
	return (1 - Sizes.KgSpread) + t * 2 * Sizes.KgSpread
end

return Sizes
