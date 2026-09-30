--!strict
-- Character Index: discoveries, first-discovery rewards, zone completion bonuses and the
-- full-completion reward (Main Character trail + title).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Zones = require(Shared.Config.Zones)
local IndexConfig = require(Shared.Config.Index)
local Formulas = require(Shared.Util.Formulas)
local IndexUtil = require(Shared.Util.IndexUtil)
local NumberFormat = require(Shared.Util.NumberFormat)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local SpeedService = require(script.Parent.SpeedService)
local PlotService = require(script.Parent.PlotService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)

type Item = Types.Item

local IndexService = {}

local function publishBonus(player: Player, data: Types.ProfileData)
	DataService.SetDerived(player, "IndexBonus", IndexUtil.IncomeBonus(data.Index))
end

-- Record that the player now owns this character (hatch, steal, fusion). Returns true on
-- a first discovery.
function IndexService.Discover(player: Player, item: Item): boolean
	local data = DataService.Get(player)
	if not data or item.Kind ~= "Character" then
		return false
	end
	local character = Characters.Find(item.CharacterId)
	if not character then
		return false
	end
	local entry = data.Index[item.CharacterId]
	local isNew = entry == nil or not entry.Discovered
	if not entry then
		entry = { Discovered = true, Claimed = false, Variants = {} }
		data.Index[item.CharacterId] = entry
	end
	local completedBefore = if character.Zone > 0 then IndexUtil.ZoneComplete(data.Index, character.Zone) else true
	entry.Discovered = true
	entry.Variants[item.Mutation or "Normal"] = true
	if item.Awakened then
		entry.Awakened = true
	end
	DataService.Changed(player, "Index")
	if isNew then
		AnnouncementService.Notify(player, "NEW! " .. character.DisplayName .. " added to your Index. Claim the reward!", "Reward", 4)
	end
	if character.Zone > 0 and not completedBefore and IndexUtil.ZoneComplete(data.Index, character.Zone) then
		local zone = Zones.Get(character.Zone)
		AnnouncementService.Notify(player, zone.DisplayName .. " Index complete! Permanent +" .. math.floor(IndexConfig.ZoneCompletionBonus * 100) .. "% income", "Reward", 5)
		IncomeService.Recalculate(player)
		PlotService.RefreshIncomeLabels(player)
	end
	publishBonus(player, data)
	if IndexUtil.FullyComplete(data.Index) and not data.Titles[IndexConfig.FullCompletion.Title] then
		data.Titles[IndexConfig.FullCompletion.Title] = true
		data.OwnedTrails[IndexConfig.FullCompletion.Trail] = true
		DataService.Changed(player, "Titles", "OwnedTrails")
		AnnouncementService.Announce(string.upper(player.DisplayName) .. " COMPLETED THE CHIBI INDEX! All hail the Main Character!", "#FF9ECF")
	end
	return isNew
end

function IndexService.Claim(player: Player, characterId: string): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local entry = data.Index[characterId]
	if not entry or not entry.Discovered then
		return false, "Not discovered yet"
	end
	if entry.Claimed then
		return false, "Already claimed"
	end
	entry.Claimed = true
	local cash = Formulas.DiscoveryCash(characterId)
	local speed = Formulas.DiscoverySpeed(characterId)
	IncomeService.AddCash(player, cash)
	SpeedService.AddSpeed(player, speed)
	DataService.Changed(player, "Index")
	AnnouncementService.Notify(player, string.format("+%s  +%s Speed", NumberFormat.Cash(cash), NumberFormat.Short(speed)), "Reward")
	return true, nil
end

function IndexService.Init()
	Remote.OnInvoke("Index", function(player, action, characterId)
		if action == "Claim" then
			local id = Guard.String(characterId, 64)
			if not id or not Characters.Find(id) then
				return { Ok = false, Error = "Unknown character" }
			end
			local ok, err = IndexService.Claim(player, id)
			return { Ok = ok, Error = err }
		elseif action == "ClaimAll" then
			local data = DataService.Get(player)
			if not data then
				return { Ok = false }
			end
			local count = 0
			for id, entry in data.Index do
				if entry.Discovered and not entry.Claimed then
					if IndexService.Claim(player, id) then
						count += 1
					end
				end
			end
			return { Ok = count > 0, Count = count }
		end
		return { Ok = false, Error = "Unknown action" }
	end)
end

function IndexService.Start()
	DataService.Loaded:Connect(function(player, data)
		publishBonus(player, data)
	end)
end

return IndexService
