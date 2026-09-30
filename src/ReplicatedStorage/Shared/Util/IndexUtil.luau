--!strict
-- Pure helpers for the Character Index (shared by server income math and the client UI).

local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Zones = require(Config.Zones)
local IndexConfig = require(Config.Index)
local Types = require(script.Parent.Parent.Types)

local IndexUtil = {}

function IndexUtil.IsDiscovered(index: { [string]: Types.IndexEntry }, characterId: string): boolean
	local entry = index[characterId]
	return entry ~= nil and entry.Discovered == true
end

function IndexUtil.ZoneComplete(index: { [string]: Types.IndexEntry }, zoneId: number): boolean
	for _, character in Characters.ForZone(zoneId) do
		if not IndexUtil.IsDiscovered(index, character.Id) then
			return false
		end
	end
	return true
end

function IndexUtil.CompletedZones(index: { [string]: Types.IndexEntry }): number
	local count = 0
	for _, zone in Zones.List do
		if IndexUtil.ZoneComplete(index, zone.Id) then
			count += 1
		end
	end
	return count
end

function IndexUtil.IncomeBonus(index: { [string]: Types.IndexEntry }): number
	return IndexUtil.CompletedZones(index) * IndexConfig.ZoneCompletionBonus
end

-- Full completion counts every free-to-obtain character (zones, festival and fusions).
-- Gacha exclusives are shown in the index but are not required.
function IndexUtil.FullyComplete(index: { [string]: Types.IndexEntry }): boolean
	for _, character in Characters.List do
		if character.Pool ~= "Gacha" and not IndexUtil.IsDiscovered(index, character.Id) then
			return false
		end
	end
	return true
end

function IndexUtil.Counts(index: { [string]: Types.IndexEntry }): (number, number)
	local found, total = 0, 0
	for _, character in Characters.List do
		total += 1
		if IndexUtil.IsDiscovered(index, character.Id) then
			found += 1
		end
	end
	return found, total
end

return IndexUtil
