--!strict
-- Pure game formulas shared by server, client and the balancing simulator.

local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Rarities = require(Config.Rarities)
local Sizes = require(Config.Sizes)
local Mutations = require(Config.Mutations)
local GameSettings = require(Config.GameSettings)
local Treadmills = require(Config.Treadmills)
local Trails = require(Config.Trails)
local Rebirths = require(Config.Rebirths)
local Zones = require(Config.Zones)
local Fusion = require(Config.Fusion)
local IndexConfig = require(Config.Index)
local Types = require(script.Parent.Parent.Types)

type Item = Types.Item

local Formulas = {}

-- Speed stat -> Humanoid WalkSpeed
function Formulas.WalkSpeed(speed: number): number
	local settings = GameSettings.WalkSpeed
	return math.min(settings.Max, settings.Base + settings.PerLog * math.log10(1 + math.max(0, speed)))
end

function Formulas.GuardianWalkSpeed(zoneId: number): number
	local zone = Zones.Get(zoneId)
	local guardian = GameSettings.Guardian
	return math.max(guardian.MinWalkSpeed, Formulas.WalkSpeed(zone.RecSpeed) * guardian.SpeedFactor)
end

-- Speed needed so that WalkSpeed * carry multiplier beats a zone's Guardian
function Formulas.SpeedNeededToOutrun(zoneId: number, sizeTier: number): number
	local target = Formulas.GuardianWalkSpeed(zoneId) / Sizes.Get(sizeTier).Carry
	local settings = GameSettings.WalkSpeed
	if target > settings.Max then
		return math.huge
	end
	return 10 ^ ((target - settings.Base) / settings.PerLog) - 1
end

-- Displayed rarity (Awakened characters show one tier higher)
function Formulas.DisplayRarity(item: Item): string
	local character = Characters.Get(item.CharacterId)
	if item.Awakened then
		return Rarities.Next(character.Rarity).Id
	end
	return character.Rarity
end

-- Base income of an item before player-wide multipliers
function Formulas.ItemIncome(item: Item): number
	local character = Characters.Get(item.CharacterId)
	local size = Sizes.Get(item.SizeTier)
	local income = character.BaseIncome * size.Income * Sizes.KgScale(item.SizeTier, item.Kg) * Mutations.IncomeMult(item.Mutation)
	if item.Awakened then
		income *= Fusion.AwakenedIncome
	end
	return income
end

export type IncomeContext = {
	Rebirths: number,
	IndexBonus: number, -- e.g. 0.15 for three completed zones
	PassMultiplier: number, -- VIP and x2 Cash combined
}

function Formulas.IncomeMultiplier(context: IncomeContext): number
	return (1 + Rebirths.Rewards.CashBonus * context.Rebirths + context.IndexBonus) * context.PassMultiplier
end

function Formulas.EffectiveIncome(item: Item, context: IncomeContext): number
	return Formulas.ItemIncome(item) * Formulas.IncomeMultiplier(context)
end

-- Seconds to hatch before growth boosts
function Formulas.HatchTime(item: Item): number
	local character = Characters.Get(item.CharacterId)
	local rarity = Rarities.Get(character.Rarity)
	return rarity.HatchTime * Sizes.Get(item.SizeTier).HatchTime * Mutations.HatchMult(item.Mutation)
end

export type SpeedContext = {
	TreadmillTier: number,
	Trail: string?,
	Rebirths: number,
	DoubleSpeed: boolean,
}

function Formulas.TreadmillGain(context: SpeedContext): number
	local treadmill = Treadmills.Get(context.TreadmillTier)
	if not treadmill then
		return 0
	end
	local gain = treadmill.Gain * Trails.Multiplier(context.Trail) * (1 + Rebirths.Rewards.TreadmillBonus * context.Rebirths)
	if context.DoubleSpeed then
		gain *= 2
	end
	return gain
end

function Formulas.SellPrice(item: Item, context: IncomeContext): number
	return math.floor(Formulas.EffectiveIncome(item, context) * GameSettings.SellMultiplier)
end

function Formulas.DiscoveryCash(characterId: string): number
	return Characters.Get(characterId).BaseIncome * IndexConfig.DiscoveryCashMult
end

function Formulas.DiscoverySpeed(characterId: string): number
	local character = Characters.Get(characterId)
	local raw = character.BaseIncome * IndexConfig.DiscoverySpeedMult
	local capZone = if character.Zone > 0 then math.min(character.Zone + 1, Zones.Count) else nil
	local cap: number
	if capZone then
		cap = Zones.Get(capZone).RecSpeed * IndexConfig.DiscoverySpeedCapFraction
	else
		-- limited characters: cap by the zone whose top rarity matches theirs
		local rank = Rarities.Rank(character.Rarity)
		local zoneForRank = math.clamp(rank + 1, 2, Zones.Count)
		cap = Zones.Get(zoneForRank).RecSpeed * IndexConfig.DiscoverySpeedCapFraction
	end
	return math.floor(math.min(raw, math.max(IndexConfig.DiscoverySpeedCapMin, cap)))
end

-- Is `rarity` at or above `required`?
function Formulas.RarityAtLeast(rarity: string, required: string): boolean
	return Rarities.Rank(rarity) >= Rarities.Rank(required)
end

return Formulas
