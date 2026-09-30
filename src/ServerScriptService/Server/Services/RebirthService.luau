--!strict
-- Rebirth: meet the cash + rarity requirement to reset for permanent bonuses.
--   Rewards per rebirth: +50% cash (additive), +10% Lucky Hatch, +25% treadmill gain,
--   +1 pen slot, +1 trap capacity, and a title.
--   Resets: cash, Speed, treadmill tier, pen level, pen, inventory (keep 1 Protected chibi per
--   2 rebirths), fusion/incubator queues and the boss clear.
--   Keeps: index, trails, gamepasses, Robux purchases, titles, redeemed codes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rebirths = require(Shared.Config.Rebirths)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Util.Formulas)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local IncomeService = require(script.Parent.IncomeService)
local CarryService = require(script.Parent.CarryService)
local TrailService = require(script.Parent.TrailService)
local InventoryService = require(script.Parent.InventoryService)
local ItemService = require(script.Parent.ItemService)
local BossService = require(script.Parent.BossService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Item = Types.Item

local RebirthService = {}

local function bestRarityRank(data: Types.ProfileData): number
	local best = 0
	for _, item in InventoryService.AllCharacters(data) do
		best = math.max(best, Rarities.Rank(Formulas.DisplayRarity(item)))
	end
	return best
end

function RebirthService.Preview(player: Player): { [string]: any }
	local data = DataService.Get(player)
	if not data then
		return { Ok = false }
	end
	local nextNumber = data.Rebirths + 1
	local requirement = Rebirths.Requirement(nextNumber)
	local hasRarity = bestRarityRank(data) >= Rarities.Rank(requirement.Rarity)
	local protected = {}
	for _, item in InventoryService.AllCharacters(data) do
		if item.Protected then
			table.insert(protected, item)
		end
	end
	local rewards = Rebirths.Rewards
	return {
		Ok = true,
		Next = nextNumber,
		Requirement = requirement,
		HasCash = data.Cash >= requirement.Cash,
		HasRarity = hasRarity,
		Eligible = data.Cash >= requirement.Cash and hasRarity,
		Title = Rebirths.Title(nextNumber),
		KeepCount = Rebirths.ProtectedKeepCount(nextNumber),
		Protected = protected,
		Before = {
			CashBonus = rewards.CashBonus * data.Rebirths,
			Luck = rewards.LuckBonus * data.Rebirths,
			TreadmillBonus = rewards.TreadmillBonus * data.Rebirths,
			PenSlots = math.min(data.Rebirths * rewards.PenSlots, Rebirths.MaxBonusPenSlots),
			TrapCapacity = data.Rebirths * rewards.TrapCapacity,
		},
		After = {
			CashBonus = rewards.CashBonus * nextNumber,
			Luck = rewards.LuckBonus * nextNumber,
			TreadmillBonus = rewards.TreadmillBonus * nextNumber,
			PenSlots = math.min(nextNumber * rewards.PenSlots, Rebirths.MaxBonusPenSlots),
			TrapCapacity = nextNumber * rewards.TrapCapacity,
		},
	}
end

function RebirthService.Rebirth(player: Player, keepUids: { string }): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	if CarryService.IsCarrying(player) then
		return false, "Put down what you're carrying first."
	end
	local preview = RebirthService.Preview(player)
	if not preview.Eligible then
		return false, "You don't meet the requirement yet."
	end
	local keepCount = preview.KeepCount :: number
	local kept: { Item } = {}
	for _, uid in keepUids do
		if #kept >= keepCount then
			break
		end
		local item = InventoryService.Find(data, uid)
		if item and item.Kind == "Character" and item.Protected then
			table.insert(kept, item)
		end
	end

	data.Rebirths += 1
	data.Cash = 0
	data.Register = 0
	data.Speed = 0
	data.TreadmillTier = 0
	data.PenLevel = 1
	data.Pen = {}
	data.Inventory = kept
	data.Fusion = {}
	data.Incubator = {}
	if Rebirths.BossClearResets then
		data.BossCleared = false
	end
	local title = Rebirths.Title(data.Rebirths)
	if title then
		data.Titles[title] = true
		data.EquippedTitle = title
		player:SetAttribute("Title", title)
	end
	DataService.Changed(player, "Rebirths", "Cash", "Register", "Speed", "TreadmillTier", "PenLevel", "Pen", "Inventory", "Fusion", "Incubator", "BossCleared", "Titles", "EquippedTitle")

	PlotService.RenderAll(player)
	PlotService.SetRegister(player, 0)
	IncomeService.Recalculate(player)
	PlotService.RefreshIncomeLabels(player)
	SpeedService.UpdateTreadmill(player)
	SpeedService.PublishDerived(player)
	SpeedService.Apply(player)
	TrailService.Render(player)
	BossService.ResetClear(player)
	DataService.SetDerived(player, "TrapCapacity", ItemService.TrapCapacity(player))
	DataService.SetDerived(player, "PenSlots", PlotService.ActiveSlots(player))
	AnnouncementService.Announce(string.format("%s REACHED REBIRTH %d%s!", string.upper(player.DisplayName), data.Rebirths, if title then ": " .. string.upper(title) else ""), "#FF9ECF")
	return true, nil
end

function RebirthService.Init()
	Remote.OnInvoke("Rebirth", function(player, action, keep)
		if action == "Preview" then
			return RebirthService.Preview(player)
		elseif action == "Confirm" then
			local list = if keep == nil then {} else Guard.StringList(keep, 20, 64)
			if not list then
				return { Ok = false, Error = "Bad request" }
			end
			local ok, err = RebirthService.Rebirth(player, list)
			if not ok and err then
				AnnouncementService.Error(player, err)
			end
			return { Ok = ok, Error = err }
		end
		return { Ok = false }
	end, 2)
end

function RebirthService.Start()
	DataService.Loaded:Connect(function(player, data)
		if data.EquippedTitle ~= "" then
			player:SetAttribute("Title", data.EquippedTitle)
		end
	end)
end

return RebirthService
