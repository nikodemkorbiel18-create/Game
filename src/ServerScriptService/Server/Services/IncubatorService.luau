--!strict
-- Sacred Tree Incubator (top of Celestial Sakura Heights). Bring one of your unhatched eggs,
-- pay a fee scaled to its rarity and after a 60s ritual it gains Petal Bloom (97.5%) or
-- Kami Bloom (2.5%), replacing any existing mutation. Then carry it home.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Endgame = require(Shared.Config.Endgame)
local Mutations = require(Shared.Config.Mutations)
local Characters = require(Shared.Config.Characters)
local Tags = require(Shared.Config.Tags)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local CarryService = require(script.Parent.CarryService)
local InventoryService = require(script.Parent.InventoryService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)

local IncubatorService = {}

local function carriedEgg(player: Player): (any?, string?)
	local item, info = CarryService.Get(player)
	if not item or not info then
		return nil, "Bring one of your unhatched eggs here."
	end
	if item.Kind ~= "Egg" then
		return nil, "Only unhatched eggs can be incubated."
	end
	if info.Origin ~= "Own" then
		return nil, "Take the egg home first - it has to be yours."
	end
	return item, nil
end

local function fee(item: any): number
	return Endgame.Incubator.Fees[Formulas.DisplayRarity(item)] or 0
end

local function quote(player: Player): { [string]: any }
	local item, err = carriedEgg(player)
	if not item then
		return { Ok = false, Error = err }
	end
	local current = Mutations.Get(item.Mutation)
	local petal = Mutations.ById.PetalBloom
	return {
		Ok = true,
		CharacterId = item.CharacterId,
		Fee = fee(item),
		CurrentMutation = if current then current.DisplayName else nil,
		Warning = current ~= nil and current.Income > petal.Income,
		Duration = Endgame.Incubator.Duration,
	}
end

local function start(player: Player, confirmed: boolean): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	if not InventoryService.NearTagged(player, Tags.SacredIncubator, 20) then
		return false, "Stand at the Sacred Tree Incubator."
	end
	local item, err = carriedEgg(player)
	if not item then
		return false, err
	end
	local current = Mutations.Get(item.Mutation)
	if current and current.Income > Mutations.ById.PetalBloom.Income and not confirmed then
		return false, "Confirm to replace the stronger mutation."
	end
	local price = fee(item)
	if not IncomeService.Spend(player, price) then
		return false, "The ritual costs " .. NumberFormat.Cash(price)
	end
	CarryService.EndCarry(player)
	table.insert(data.Incubator, { EndsAt = os.time() + Endgame.Incubator.Duration, Item = item })
	DataService.Changed(player, "Incubator")
	local altar = CollectionService:GetTagged(Tags.SacredIncubator)[1]
	if altar and altar:IsA("BasePart") then
		Remote.FireAll("Effect", { Type = "Burst", Position = altar.Position + Vector3.new(0, 3, 0) })
	end
	AnnouncementService.Notify(player, "The Sacred Tree accepts your egg... " .. TimeFormat.Short(Endgame.Incubator.Duration), "Success")
	return true, nil
end

local function claim(player: Player, index: number): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local job = data.Incubator[index]
	if not job then
		return false, "Nothing here"
	end
	if job.EndsAt > os.time() then
		return false, "The ritual needs " .. TimeFormat.Short(job.EndsAt - os.time()) .. " more"
	end
	if not InventoryService.NearTagged(player, Tags.SacredIncubator, 20) then
		return false, "Stand at the Sacred Tree Incubator."
	end
	if CarryService.IsCarrying(player) then
		return false, "Your hands are full"
	end
	local item = job.Item
	-- the ritual result: 2.5% Kami Bloom, otherwise Petal Bloom (replaces any mutation)
	local roll = math.random() * 100
	item.Mutation = if roll < Mutations.ById.KamiBloom.Chance then "KamiBloom" else "PetalBloom"
	table.remove(data.Incubator, index)
	DataService.Changed(player, "Incubator")
	if not CarryService.StartCarry(player, item, { Origin = "Own", OwnerUserId = player.UserId }) then
		CarryService.GiveToPlayer(player, item, nil, true)
	end
	local mutation = Mutations.Get(item.Mutation)
	local name = Characters.Get(item.CharacterId).DisplayName
	if item.Mutation == "KamiBloom" then
		AnnouncementService.Announce(string.upper(player.DisplayName) .. " GOT A KAMI BLOOM " .. string.upper(name) .. "!", "#FFE08A")
	else
		AnnouncementService.Notify(player, name .. " blossomed: " .. (if mutation then mutation.DisplayName else "") .. "! Carry it home.", "Reward", 4)
	end
	return true, nil
end

function IncubatorService.Init()
	Remote.OnInvoke("Incubator", function(player, action, arg)
		local kind = Guard.OneOf(action, { "Quote", "Start", "Claim" })
		if kind == "Quote" then
			return quote(player)
		elseif kind == "Start" then
			local ok, err = start(player, arg == true)
			if not ok and err then
				AnnouncementService.Error(player, err)
			end
			return { Ok = ok, Error = err }
		elseif kind == "Claim" then
			local index = Guard.Integer(arg, 1, 10)
			if not index then
				return { Ok = false }
			end
			local ok, err = claim(player, index)
			if not ok and err then
				AnnouncementService.Error(player, err)
			end
			return { Ok = ok, Error = err }
		end
		return { Ok = false }
	end, 4)
end

function IncubatorService.Start() end

return IncubatorService
