--!strict
-- Cash purchases: treadmill tiers, pen levels, barrier upgrades, trails and items.
-- One RemoteFunction ("Shop"), every request validated on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Shop = require(Shared.Config.Shop)
local Items = require(Shared.Config.Items)
local Trails = require(Shared.Config.Trails)
local NumberFormat = require(Shared.Util.NumberFormat)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local IncomeService = require(script.Parent.IncomeService)
local TrailService = require(script.Parent.TrailService)
local ItemService = require(script.Parent.ItemService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)

local ShopService = {}

local function buyPen(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local nextLevel = Shop.PenLevels[data.PenLevel + 1]
	if not nextLevel then
		return false, "Your pen is fully upgraded!"
	end
	if not IncomeService.Spend(player, nextLevel.Price) then
		return false, "You need " .. NumberFormat.Cash(nextLevel.Price)
	end
	data.PenLevel = nextLevel.Level
	DataService.Changed(player, "PenLevel")
	PlotService.RefreshSlots(player)
	DataService.SetDerived(player, "PenSlots", PlotService.ActiveSlots(player))
	AnnouncementService.Notify(player, "Pen upgraded to " .. nextLevel.Slots .. " slots!", "Success")
	return true, nil
end

local function buyBarrier(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local nextLevel = Shop.BarrierLevels[data.BarrierLevel + 1]
	if not nextLevel then
		return false, "Barrier is fully upgraded!"
	end
	if not IncomeService.Spend(player, nextLevel.Price) then
		return false, "You need " .. NumberFormat.Cash(nextLevel.Price)
	end
	data.BarrierLevel = nextLevel.Level
	DataService.Changed(player, "BarrierLevel")
	AnnouncementService.Notify(player, "Barrier Lock now lasts " .. nextLevel.Duration .. "s!", "Success")
	return true, nil
end

local function buyItem(player: Player, itemId: string, amount: number): (boolean, string?)
	local item = (Items :: any)[itemId]
	if not item or not item.BasePrice then
		return false, "Unknown item"
	end
	local room = ItemService.Capacity(player, itemId) - ItemService.Count(player, itemId)
	if room <= 0 then
		return false, "You can't carry any more " .. item.DisplayName .. "s"
	end
	local count = math.min(amount, room)
	local price = Items.Price(itemId, IncomeService.PerSecond(player)) * count
	if not IncomeService.Spend(player, price) then
		return false, "You need " .. NumberFormat.Cash(price)
	end
	ItemService.Add(player, itemId, count)
	AnnouncementService.Notify(player, string.format("Bought %d %s%s", count, item.DisplayName, if count > 1 then "s" else ""), "Success")
	return true, nil
end

function ShopService.Init()
	Remote.OnInvoke("Shop", function(player, category, id, amount)
		local kind = Guard.OneOf(category, { "Treadmill", "Pen", "Barrier", "Trail", "EquipTrail", "Item", "ItemPrices", "ClaimGroup" })
		if not kind then
			return { Ok = false, Error = "Unknown purchase" }
		end
		local ok, err = false, nil :: string?
		if kind == "Treadmill" then
			ok, err = SpeedService.BuyTreadmill(player, IncomeService.Spend)
		elseif kind == "Pen" then
			ok, err = buyPen(player)
		elseif kind == "Barrier" then
			ok, err = buyBarrier(player)
		elseif kind == "Trail" then
			local trailId = Guard.String(id, 32)
			if not trailId or not Trails.Get(trailId) then
				return { Ok = false, Error = "Unknown trail" }
			end
			ok, err = TrailService.Buy(player, trailId, IncomeService.Spend)
		elseif kind == "EquipTrail" then
			local trailId = if id == "" then "" else Guard.String(id, 32)
			if trailId == nil then
				return { Ok = false, Error = "Unknown trail" }
			end
			ok, err = TrailService.Equip(player, trailId)
		elseif kind == "Item" then
			local itemId = Guard.OneOf(id, { "OfudaTrap", "SmokeBomb" })
			local count = Guard.Integer(amount, 1, 10) or 1
			if not itemId then
				return { Ok = false, Error = "Unknown item" }
			end
			ok, err = buyItem(player, itemId, count)
		elseif kind == "ItemPrices" then
			local income = IncomeService.PerSecond(player)
			return {
				Ok = true,
				OfudaTrap = Items.Price("OfudaTrap", income),
				SmokeBomb = Items.Price("SmokeBomb", income),
				TrapCapacity = ItemService.TrapCapacity(player),
				SmokeCapacity = Items.SmokeBomb.Capacity,
			}
		elseif kind == "ClaimGroup" then
			SpeedService.CheckGroup(player)
			ok = true
		end
		if not ok and err then
			AnnouncementService.Error(player, err)
		end
		return { Ok = ok, Error = err }
	end, 6)
end

function ShopService.Start()
	DataService.Loaded:Connect(function(player)
		DataService.SetDerived(player, "PenSlots", PlotService.ActiveSlots(player))
	end)
end

return ShopService
