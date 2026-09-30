--!strict
-- Gamepass ownership (cached) and the multipliers passes grant. Passes with Id = 0 are
-- disabled. Admins can grant passes for the current session to test them.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

local PassService = {}

local owned: { [Player]: { [string]: boolean } } = {}

PassService.Changed = Signal.new() :: Signal.Signal<Player, string>

local function publish(player: Player)
	DataService.SetDerived(player, "Passes", table.clone(owned[player] or {}))
end

local function check(player: Player)
	local set = owned[player] or {}
	owned[player] = set
	for _, pass in Monetization.Passes do
		if pass.Id ~= 0 and not set[pass.Key] then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and result then
				set[pass.Key] = true
				PassService.Changed:Fire(player, pass.Key)
			end
		end
	end
	publish(player)
	player:SetAttribute("VIP", set.VIP == true)
end

function PassService.Owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

-- Session-only grant (admin testing, or right after a purchase)
function PassService.Grant(player: Player, key: string)
	local set = owned[player] or {}
	owned[player] = set
	if not set[key] then
		set[key] = true
		publish(player)
		player:SetAttribute("VIP", set.VIP == true)
		PassService.Changed:Fire(player, key)
	end
end

function PassService.CashMultiplier(player: Player): number
	local mult = 1
	if PassService.Owns(player, "VIP") then
		mult *= Monetization.VIPCash
	end
	if PassService.Owns(player, "DoubleCash") then
		mult *= Monetization.DoubleCash
	end
	return mult
end

function PassService.HatchSpeed(player: Player): number
	return if PassService.Owns(player, "FasterHatch") then Monetization.FasterHatch else 1
end

function PassService.ExtraPenSlots(player: Player): number
	return if PassService.Owns(player, "ExtraPenSlots") then Monetization.ExtraPenSlots else 0
end

function PassService.TrapFreeze(player: Player): number
	return if PassService.Owns(player, "TrapMaster") then Items.OfudaTrap.TrapMasterFreeze else Items.OfudaTrap.Freeze
end

function PassService.TrapCapacityBonus(player: Player): number
	return if PassService.Owns(player, "TrapMaster") then Items.OfudaTrap.TrapMasterCapacity else 0
end

function PassService.BarrierBonus(player: Player): number
	return if PassService.Owns(player, "LongBarrier") then Monetization.LongBarrierBonus else 0
end

function PassService.Init() end

function PassService.Start()
	DataService.Loaded:Connect(function(player)
		check(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Monetization.Passes do
			if pass.Id == passId and pass.Id ~= 0 then
				PassService.Grant(player, pass.Key)
			end
		end
	end)
end

return PassService
