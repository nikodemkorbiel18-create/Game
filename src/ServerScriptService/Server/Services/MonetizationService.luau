--!strict
-- Developer products. ProcessReceipt is idempotent: every PurchaseId is stored in the profile
-- together with the reward, and PurchaseGranted is only returned once a save containing that
-- PurchaseId has reached the DataStore. Retries after a crash or rejoin never double-grant.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local GameSettings = require(Shared.Config.GameSettings)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local NumberFormat = require(Shared.Util.NumberFormat)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local SpeedService = require(script.Parent.SpeedService)
local HatchService = require(script.Parent.HatchService)
local EventService = require(script.Parent.EventService)
local CarryService = require(script.Parent.CarryService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local World = require(script.Parent.Parent.Lib.World)

type ProfileData = Types.ProfileData

local MonetizationService = {}

local handlers: { [string]: (Player, ProfileData) -> () } = {}

local function speedPack(key: string)
	return function(player: Player, _data: ProfileData)
		local spec = (Monetization.SpeedPacks :: any)[key]
		local amount = math.max(spec.Minimum, SpeedService.Gain(player) * spec.Minutes * 60)
		SpeedService.AddSpeed(player, amount)
		AnnouncementService.Notify(player, "+" .. NumberFormat.Short(amount) .. " Speed!", "Reward")
	end
end

handlers.SpeedPackSmall = speedPack("SpeedPackSmall")
handlers.SpeedPackMedium = speedPack("SpeedPackMedium")
handlers.SpeedPackLarge = speedPack("SpeedPackLarge")

handlers.LuckBoost = function(player, data)
	data.Boosts.LuckEndsAt = math.max(os.time(), data.Boosts.LuckEndsAt) + Monetization.LuckBoostMinutes * 60
	DataService.Changed(player, "Boosts")
	AnnouncementService.Notify(player, "Luck Boost active!", "Reward")
end

handlers.ServerLuck = function(player, _data)
	EventService.StartServerLuck(player)
end

local function instantHatch(key: string)
	return function(player: Player, data: ProfileData)
		for _, tier in Monetization.InstantHatchTiers do
			if tier.Key == key then
				local slot = HatchService.LongestEgg(player, tier.MinRank, tier.MaxRank)
				if slot then
					HatchService.FinishNow(player, slot)
				else
					data.Credits[key] = (data.Credits[key] or 0) + 1
					DataService.Changed(player, "Credits")
					AnnouncementService.Notify(player, "No matching egg right now - your Instant Hatch is saved and will be used on the next one.", "Info", 5)
				end
			end
		end
	end
end

for _, tier in Monetization.InstantHatchTiers do
	handlers[tier.Key] = instantHatch(tier.Key)
end

handlers.GachaCapsule = function(player, _data)
	local pool = Characters.ForPool("Gacha")
	local character = WeightedRandom.PickList(pool, function(c)
		return c.SpawnWeight
	end) :: Characters.Character
	local roll = math.random() * 100
	local sizeTier = 3
	local acc = 0
	for _, size in Sizes.List do
		acc += size.Chance
		if roll < acc then
			sizeTier = size.Rank
			break
		end
	end
	local size = Sizes.Get(sizeTier)
	local item: Types.Item = {
		Uid = World.MakeUid(),
		Kind = "Egg",
		CharacterId = character.Id,
		SizeTier = sizeTier,
		Kg = math.floor((size.MinKg + (size.MaxKg - size.MinKg) * math.random()) * 10) / 10,
		EggModel = "Egg_Gacha",
		Color = math.random(1, 4),
		Source = "Gacha",
	}
	CarryService.GiveToPlayer(player, item, nil, true)
	local rarity = Rarities.Get(character.Rarity)
	AnnouncementService.Notify(player, "Gacha Capsule: a " .. rarity.DisplayName .. " egg! It's in your pen.", "Reward", 5)
	if rarity.Rank >= GameSettings.AnnounceRank then
		AnnouncementService.Announce(string.upper(player.DisplayName) .. " PULLED A " .. string.upper(rarity.DisplayName) .. " FROM THE GACHA CAPSULE!", rarity.Color2 or rarity.Color)
	end
end

local productByKey: { [number]: string } = {}
for _, product in Monetization.Products do
	if product.Id ~= 0 then
		productByKey[product.Id] = product.Key
	end
end

-- Admin testing: grant a product without Robux
function MonetizationService.GrantProduct(player: Player, key: string): boolean
	local data = DataService.Get(player)
	local handler = handlers[key]
	if not data or not handler then
		return false
	end
	handler(player, data)
	return true
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitFor(player, 20)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if not table.find(data.ProcessedPurchases, purchaseId) then
		local key = productByKey[receipt.ProductId]
		local handler = key and handlers[key]
		if not handler then
			warn("[Monetization] Unknown product " .. tostring(receipt.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(function(): nil
			handler(player, data)
			return nil
		end)
		if not ok then
			warn("[Monetization] Grant failed: " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(data.ProcessedPurchases, purchaseId)
		while #data.ProcessedPurchases > Monetization.ProcessedPurchaseCache do
			table.remove(data.ProcessedPurchases, 1)
		end
	end
	if DataService.SaveAndConfirm(player, purchaseId, 30) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Spend saved Instant Hatch credits on eggs that are incubating
local function useCredits()
	for _, player in DataService.LoadedPlayers() do
		local data = DataService.Get(player)
		if data and next(data.Credits) then
			for _, tier in Monetization.InstantHatchTiers do
				local credits = data.Credits[tier.Key]
				if credits and credits > 0 then
					local slot = HatchService.LongestEgg(player, tier.MinRank, tier.MaxRank)
					if slot and HatchService.FinishNow(player, slot) then
						(data.Credits :: any)[tier.Key] = if credits > 1 then credits - 1 else nil
						DataService.Changed(player, "Credits")
					end
				end
			end
		end
	end
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService.Start()
	task.spawn(function()
		while true do
			task.wait(5)
			useCredits()
		end
	end)
end

return MonetizationService
