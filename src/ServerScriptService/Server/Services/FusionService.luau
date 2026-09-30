--!strict
-- Fusion Pod (Station Plaza):
--   * 3 copies of the same character -> after 2 minutes, 1 Awakened version (shown one
--     rarity higher, base income x4, size = largest of the three). Mutation is kept only if
--     all three share it; otherwise a 10% chance to keep the best one.
--   * Recipe fusions cost cash and produce a Fusion Egg (Duet, Rival, Eclipse).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Fusion = require(Shared.Config.Fusion)
local Characters = require(Shared.Config.Characters)
local Mutations = require(Shared.Config.Mutations)
local Tags = require(Shared.Config.Tags)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local CarryService = require(script.Parent.CarryService)
local InventoryService = require(script.Parent.InventoryService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)
local World = require(script.Parent.Parent.Lib.World)

type Item = Types.Item

local FusionService = {}

local MAX_JOBS = 3

local function atPod(player: Player): (boolean, string?)
	if CarryService.IsCarrying(player) then
		return false, "You can't enter the Fusion Pod while carrying something."
	end
	if not InventoryService.NearTagged(player, Tags.FusionPod, 25) then
		return false, "Visit the Fusion Pod in Station Plaza."
	end
	return true, nil
end

local function collect(player: Player, uids: { string }): ({ Item }?, string?)
	local data = DataService.Get(player)
	if not data then
		return nil, "Not loaded"
	end
	local items = {}
	local seen = {}
	for _, uid in uids do
		if seen[uid] then
			return nil, "Pick different chibis"
		end
		seen[uid] = true
		local item = InventoryService.Find(data, uid)
		if not item then
			return nil, "You don't own that chibi"
		end
		if item.Kind ~= "Character" then
			return nil, "Only hatched chibis can be fused"
		end
		if item.Protected then
			return nil, "Unprotect a chibi before fusing it"
		end
		table.insert(items, item)
	end
	return items, nil
end

local function awaken(player: Player, uids: { string }): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local ok, err = atPod(player)
	if not ok then
		return false, err
	end
	if #data.Fusion >= MAX_JOBS then
		return false, "The pod is busy. Claim a finished fusion first."
	end
	if #uids ~= Fusion.Copies then
		return false, "Pick exactly " .. Fusion.Copies .. " copies"
	end
	local items, collectError = collect(player, uids)
	if not items then
		return false, collectError
	end
	local characterId = items[1].CharacterId
	local largest = items[1]
	local sameMutation = true
	local bestMutation: string? = nil
	for _, item in items do
		if item.CharacterId ~= characterId then
			return false, "All three must be the same character"
		end
		if item.Awakened then
			return false, "Awakened chibis can't be awakened again"
		end
		if item.SizeTier > largest.SizeTier or (item.SizeTier == largest.SizeTier and item.Kg > largest.Kg) then
			largest = item
		end
		if item.Mutation ~= items[1].Mutation then
			sameMutation = false
		end
		if Mutations.IncomeMult(item.Mutation) > Mutations.IncomeMult(bestMutation) then
			bestMutation = item.Mutation
		end
	end
	local mutation: string? = nil
	if sameMutation then
		mutation = items[1].Mutation
	elseif math.random() < Fusion.KeepMutationChance then
		mutation = bestMutation
	end
	for _, item in items do
		InventoryService.Remove(player, item.Uid)
	end
	local result: Item = {
		Uid = World.MakeUid(),
		Kind = "Character",
		CharacterId = characterId,
		SizeTier = largest.SizeTier,
		Kg = largest.Kg,
		Mutation = mutation,
		Awakened = true,
		Source = "Fusion",
	}
	table.insert(data.Fusion, { EndsAt = os.time() + Fusion.Duration, Result = result, Kind = "Awaken" })
	DataService.Changed(player, "Fusion")
	AnnouncementService.Notify(player, "Fusion started! Back in " .. TimeFormat.Short(Fusion.Duration), "Success")
	return true, nil
end

local function recipe(player: Player, recipeId: string, uids: { string }): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local ok, err = atPod(player)
	if not ok then
		return false, err
	end
	local def = Fusion.GetRecipe(recipeId)
	if not def then
		return false, "Unknown recipe"
	end
	if #data.Fusion >= MAX_JOBS then
		return false, "The pod is busy. Claim a finished fusion first."
	end
	if #uids ~= #def.Inputs then
		return false, "Pick one of each ingredient"
	end
	local items, collectError = collect(player, uids)
	if not items then
		return false, collectError
	end
	local needed = table.clone(def.Inputs)
	local largest = items[1]
	for _, item in items do
		local index = table.find(needed, item.CharacterId)
		if not index then
			return false, "Wrong ingredients"
		end
		table.remove(needed, index)
		if item.SizeTier > largest.SizeTier then
			largest = item
		end
	end
	if not IncomeService.Spend(player, def.Price) then
		return false, "You need " .. NumberFormat.Cash(def.Price)
	end
	for _, item in items do
		InventoryService.Remove(player, item.Uid)
	end
	local result: Item = {
		Uid = World.MakeUid(),
		Kind = "Egg",
		CharacterId = def.Result,
		SizeTier = largest.SizeTier,
		Kg = largest.Kg,
		Mutation = if items[1].Mutation == items[2].Mutation then items[1].Mutation else nil,
		EggModel = def.EggModel,
		Color = 1,
		Source = "Fusion",
	}
	table.insert(data.Fusion, { EndsAt = os.time() + Fusion.Duration, Result = result, Kind = def.Id })
	DataService.Changed(player, "Fusion")
	AnnouncementService.Notify(player, def.DisplayName .. " is forming! Back in " .. TimeFormat.Short(Fusion.Duration), "Success")
	return true, nil
end

local function claim(player: Player, index: number): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local job = data.Fusion[index]
	if not job then
		return false, "Nothing to claim"
	end
	if job.EndsAt > os.time() then
		return false, "Not ready yet (" .. TimeFormat.Short(job.EndsAt - os.time()) .. ")"
	end
	table.remove(data.Fusion, index)
	DataService.Changed(player, "Fusion")
	local ok = CarryService.GiveToPlayer(player, job.Result, nil, true)
	if ok then
		local name = Characters.Get(job.Result.CharacterId).DisplayName
		AnnouncementService.Notify(player, if job.Result.Kind == "Egg" then "Got a Fusion Egg! It hatches into " .. name .. "!" else "Awakened " .. name .. " joined you!", "Reward")
	end
	return ok, nil
end

function FusionService.Init()
	Remote.OnInvoke("Fusion", function(player, action, arg1, arg2)
		local kind = Guard.OneOf(action, { "Awaken", "Recipe", "Claim" })
		if not kind then
			return { Ok = false, Error = "Unknown action" }
		end
		local ok, err = false, nil :: string?
		if kind == "Awaken" then
			local uids = Guard.StringList(arg1, 3, 64)
			if not uids then
				return { Ok = false, Error = "Bad request" }
			end
			ok, err = awaken(player, uids)
		elseif kind == "Recipe" then
			local recipeId = Guard.String(arg1, 32)
			local uids = Guard.StringList(arg2, 3, 64)
			if not recipeId or not uids then
				return { Ok = false, Error = "Bad request" }
			end
			ok, err = recipe(player, recipeId, uids)
		elseif kind == "Claim" then
			local index = Guard.Integer(arg1, 1, MAX_JOBS)
			if not index then
				return { Ok = false, Error = "Bad request" }
			end
			ok, err = claim(player, index)
		end
		if not ok and err then
			AnnouncementService.Error(player, err)
		end
		return { Ok = ok, Error = err }
	end, 4)
end

function FusionService.Start() end

return FusionService
