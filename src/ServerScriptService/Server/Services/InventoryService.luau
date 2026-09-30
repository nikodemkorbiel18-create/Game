--!strict
-- Inventory (50 unplaced eggs/characters), Equip Best, Protect, and the Sell Counter.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Tags = require(Shared.Config.Tags)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local IncomeService = require(script.Parent.IncomeService)
local HatchService = require(script.Parent.HatchService)
local CarryService = require(script.Parent.CarryService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)
local World = require(script.Parent.Parent.Lib.World)

type Item = Types.Item
type ProfileData = Types.ProfileData

local InventoryService = {}

export type Location = { Where: "Pen" | "Inventory", Key: string?, Index: number? }

-- Finds an owned item by uid in the pen or inventory
function InventoryService.Find(data: ProfileData, uid: string): (Item?, Location?)
	for key, item in data.Pen do
		if item.Uid == uid then
			return item, { Where = "Pen", Key = key }
		end
	end
	for index, item in data.Inventory do
		if item.Uid == uid then
			return item, { Where = "Inventory", Index = index }
		end
	end
	return nil, nil
end

-- Removes an item wherever it is. Returns true if removed.
function InventoryService.Remove(player: Player, uid: string): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local _, location = InventoryService.Find(data, uid)
	if not location then
		return false
	end
	if location.Where == "Pen" and location.Key then
		data.Pen[location.Key] = nil
		DataService.Changed(player, "Pen")
		PlotService.RenderSlot(player, tonumber(location.Key) :: number)
		IncomeService.Recalculate(player)
	elseif location.Index then
		table.remove(data.Inventory, location.Index)
		DataService.Changed(player, "Inventory")
	end
	return true
end

function InventoryService.AllCharacters(data: ProfileData): { Item }
	local list = {}
	for _, item in data.Pen do
		if item.Kind == "Character" then
			table.insert(list, item)
		end
	end
	for _, item in data.Inventory do
		if item.Kind == "Character" then
			table.insert(list, item)
		end
	end
	return list
end

local function place(player: Player, uid: string, slot: number?): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local item, location = InventoryService.Find(data, uid)
	if not item or not location or location.Where ~= "Inventory" or not location.Index then
		return false, "Item not in your inventory"
	end
	local target = slot or PlotService.FirstFreeSlot(player)
	if not target then
		return false, "Your pen is full"
	end
	if target > PlotService.ActiveSlots(player) or data.Pen[tostring(target)] then
		return false, "That slot isn't free"
	end
	table.remove(data.Inventory, location.Index)
	DataService.Changed(player, "Inventory")
	CarryService.PlaceInSlot(player, item, target)
	return true, nil
end

local function store(player: Player, slot: number): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local key = tostring(slot)
	local item = data.Pen[key]
	if not item then
		return false, "That slot is empty"
	end
	if #data.Inventory >= GameSettings.InventoryCapacity then
		return false, "Inventory full"
	end
	data.Pen[key] = nil
	HatchService.Pause(item)
	table.insert(data.Inventory, item)
	DataService.Changed(player, "Pen", "Inventory")
	PlotService.RenderSlot(player, slot)
	IncomeService.Recalculate(player)
	return true, nil
end

-- Fill every non-egg slot with the highest earning characters from pen + inventory.
function InventoryService.EquipBest(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local active = PlotService.ActiveSlots(player)
	local pool: { Item } = {}
	local freeSlots: { number } = {}
	for index = 1, active do
		local key = tostring(index)
		local item = data.Pen[key]
		if item and item.Kind == "Character" then
			table.insert(pool, item)
			data.Pen[key] = nil
			table.insert(freeSlots, index)
		elseif not item then
			table.insert(freeSlots, index)
		end
	end
	local remaining: { Item } = {}
	for _, item in data.Inventory do
		if item.Kind == "Character" then
			table.insert(pool, item)
		else
			table.insert(remaining, item)
		end
	end
	local context = IncomeService.Context(player)
	table.sort(pool, function(a, b)
		return Formulas.EffectiveIncome(a, context) > Formulas.EffectiveIncome(b, context)
	end)
	for index, item in pool do
		local slot = freeSlots[index]
		if slot then
			data.Pen[tostring(slot)] = item
		else
			table.insert(remaining, item)
		end
	end
	data.Inventory = remaining
	DataService.Changed(player, "Pen", "Inventory")
	PlotService.RenderAll(player)
	IncomeService.Recalculate(player)
	AnnouncementService.Notify(player, "Equipped your best chibis!", "Success")
	return true, nil
end

local function protect(player: Player, uid: string, value: boolean): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local item, location = InventoryService.Find(data, uid)
	if not item or not location then
		return false, "Item not found"
	end
	item.Protected = if value then true else nil
	DataService.Changed(player, if location.Where == "Pen" then "Pen" else "Inventory")
	return true, nil
end

local function carryOut(player: Player, uid: string): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	if CarryService.IsCarrying(player) then
		return false, "Your hands are full"
	end
	if not PlotService.IsInOwnPlot(player) then
		return false, "Go to your base first"
	end
	local item, location = InventoryService.Find(data, uid)
	if not item or not location or location.Where ~= "Inventory" or not location.Index then
		return false, "Item not in your inventory"
	end
	table.remove(data.Inventory, location.Index)
	DataService.Changed(player, "Inventory")
	if not CarryService.StartCarry(player, item, { Origin = "Own", OwnerUserId = player.UserId }) then
		table.insert(data.Inventory, item)
		DataService.Changed(player, "Inventory")
		return false, "Couldn't pick that up"
	end
	return true, nil
end

local function nearTagged(player: Player, tag: string, range: number): boolean
	local position = World.Position(player)
	if not position then
		return false
	end
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and World.DistanceToBox(position, instance) <= range then
			return true
		end
	end
	return false
end
InventoryService.NearTagged = nearTagged

local function sell(player: Player, uids: { string }, confirmed: boolean): { [string]: any }
	local data = DataService.Get(player)
	if not data then
		return { Ok = false, Error = "Not loaded" }
	end
	if not nearTagged(player, Tags.SellCounter, 25) then
		return { Ok = false, Error = "Visit the Sell Counter in Station Plaza." }
	end
	local context = IncomeService.Context(player)
	local total = 0
	local sold = 0
	local needsConfirm = false
	local toSell: { Item } = {}
	for _, uid in uids do
		local item = InventoryService.Find(data, uid)
		if item and item.Kind == "Character" and not item.Protected then
			if Rarities.Rank(Formulas.DisplayRarity(item)) >= GameSettings.SellConfirmRank then
				needsConfirm = true
			end
			table.insert(toSell, item)
		end
	end
	if needsConfirm and not confirmed then
		return { Ok = false, NeedsConfirm = true }
	end
	for _, item in toSell do
		if InventoryService.Remove(player, item.Uid) then
			total += Formulas.SellPrice(item, context)
			sold += 1
		end
	end
	if sold == 0 then
		return { Ok = false, Error = "Nothing to sell (protected chibis are skipped)." }
	end
	IncomeService.AddCash(player, total)
	AnnouncementService.Notify(player, string.format("Sold %d chibi%s for %s", sold, if sold > 1 then "s" else "", NumberFormat.Cash(total)), "Success")
	return { Ok = true, Total = total, Count = sold }
end

function InventoryService.Init()
	Remote.OnInvoke("Inventory", function(player, action, arg1, arg2)
		local kind = Guard.OneOf(action, { "Place", "Store", "EquipBest", "Protect", "Carry" })
		if not kind then
			return { Ok = false, Error = "Unknown action" }
		end
		local ok, err = false, nil :: string?
		if kind == "Place" then
			local uid = Guard.String(arg1, 64)
			local slot = if arg2 == nil then nil else Guard.Integer(arg2, 1, GameSettings.PhysicalPenSlots)
			if not uid then
				return { Ok = false, Error = "Bad item" }
			end
			ok, err = place(player, uid, slot)
		elseif kind == "Store" then
			local slot = Guard.Integer(arg1, 1, GameSettings.PhysicalPenSlots)
			if not slot then
				return { Ok = false, Error = "Bad slot" }
			end
			ok, err = store(player, slot)
		elseif kind == "EquipBest" then
			ok, err = InventoryService.EquipBest(player)
		elseif kind == "Protect" then
			local uid = Guard.String(arg1, 64)
			local value = Guard.Boolean(arg2)
			if not uid or value == nil then
				return { Ok = false, Error = "Bad request" }
			end
			ok, err = protect(player, uid, value)
		elseif kind == "Carry" then
			local uid = Guard.String(arg1, 64)
			if not uid then
				return { Ok = false, Error = "Bad item" }
			end
			ok, err = carryOut(player, uid)
		end
		if not ok and err then
			AnnouncementService.Error(player, err)
		end
		return { Ok = ok, Error = err }
	end, 8)
	Remote.OnInvoke("Sell", function(player, uids, confirmed)
		local list = Guard.StringList(uids, 60, 64)
		if not list then
			return { Ok = false, Error = "Bad request" }
		end
		local result = sell(player, list, confirmed == true)
		if not result.Ok and result.Error then
			AnnouncementService.Error(player, result.Error)
		end
		return result
	end, 4)
end

function InventoryService.Start()
	local _ = Characters
end

return InventoryService
