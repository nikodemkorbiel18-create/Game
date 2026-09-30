--!strict
-- Redeemable codes (Codes Board). Case-insensitive, one use per player, expiry in config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Codes = require(Shared.Config.Codes)
local TimeFormat = require(Shared.Util.TimeFormat)
local NumberFormat = require(Shared.Util.NumberFormat)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local SpeedService = require(script.Parent.SpeedService)
local ItemService = require(script.Parent.ItemService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)

local CodesService = {}

local function redeem(player: Player, input: string): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	local code = string.upper((string.gsub(input, "%s", "")))
	for _, def in Codes do
		if string.upper(def.Code) == code then
			local expires = TimeFormat.ParseDateEnd(def.Expires)
			if expires and os.time() > expires then
				return false, "That code has expired."
			end
			if data.RedeemedCodes[def.Code] then
				return false, "You already used that code."
			end
			data.RedeemedCodes[def.Code] = true
			DataService.Changed(player, "RedeemedCodes")
			local rewards = def.Rewards
			local parts = {}
			if rewards.Cash then
				IncomeService.AddCash(player, rewards.Cash, false)
				table.insert(parts, NumberFormat.Cash(rewards.Cash))
			end
			if rewards.Speed then
				SpeedService.AddSpeed(player, rewards.Speed)
				table.insert(parts, NumberFormat.Short(rewards.Speed) .. " Speed")
			end
			if rewards.Traps then
				ItemService.Add(player, "OfudaTrap", rewards.Traps, true)
				table.insert(parts, rewards.Traps .. " Ofuda Traps")
			end
			if rewards.SmokeBombs then
				ItemService.Add(player, "SmokeBomb", rewards.SmokeBombs, true)
				table.insert(parts, rewards.SmokeBombs .. " Smoke Bombs")
			end
			if rewards.LuckMinutes then
				data.Boosts.LuckEndsAt = math.max(os.time(), data.Boosts.LuckEndsAt) + rewards.LuckMinutes * 60
				DataService.Changed(player, "Boosts")
				table.insert(parts, rewards.LuckMinutes .. " min Luck Boost")
			end
			return true, "Code redeemed: " .. table.concat(parts, ", ")
		end
	end
	return false, "That code doesn't exist."
end

function CodesService.Init()
	Remote.OnInvoke("RedeemCode", function(player, input)
		local text = Guard.String(input, 32)
		if not text then
			return { Ok = false, Message = "Type a code first." }
		end
		local ok, message = redeem(player, text)
		AnnouncementService.Notify(player, message, if ok then "Reward" else "Error")
		return { Ok = ok, Message = message }
	end, 1)
end

function CodesService.Start() end

return CodesService
