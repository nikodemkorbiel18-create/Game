--!strict
-- 7-day login streak. Missing a UTC day resets to day 1; day 7 loops back to day 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local LoginRewards = require(Shared.Config.LoginRewards)
local TimeFormat = require(Shared.Util.TimeFormat)
local NumberFormat = require(Shared.Util.NumberFormat)

local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local SpeedService = require(script.Parent.SpeedService)
local ItemService = require(script.Parent.ItemService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Lib.Remote)

local LoginRewardService = {}

local function today(): number
	return TimeFormat.Day(os.time())
end

local function updateStreak(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local day = today()
	local login = data.Login
	if login.LastDay == day then
		return
	end
	if login.LastDay == day - 1 then
		login.Streak = (login.Streak % #LoginRewards) + 1
	else
		login.Streak = 1
	end
	login.LastDay = day
	DataService.Changed(player, "Login")
end

local function grant(player: Player, reward: LoginRewards.Reward): string
	local data = DataService.Get(player)
	if not data then
		return ""
	end
	if reward.Kind == "IncomeMinutes" then
		local amount = math.max(reward.Minimum or 0, IncomeService.PerSecond(player) * reward.Amount * 60)
		IncomeService.AddCash(player, amount, false)
		return NumberFormat.Cash(amount)
	elseif reward.Kind == "SpeedMinutes" then
		local amount = math.max(reward.Minimum or 0, SpeedService.Gain(player) * reward.Amount * 60)
		SpeedService.AddSpeed(player, amount)
		return NumberFormat.Short(amount) .. " Speed"
	elseif reward.Kind == "Traps" then
		ItemService.Add(player, "OfudaTrap", reward.Amount, true)
		return reward.Amount .. " Ofuda Traps"
	elseif reward.Kind == "SmokeBombs" then
		ItemService.Add(player, "SmokeBomb", reward.Amount, true)
		return reward.Amount .. " Smoke Bombs"
	elseif reward.Kind == "LuckBoost" then
		data.Boosts.LuckEndsAt = math.max(os.time(), data.Boosts.LuckEndsAt) + reward.Amount * 60
		DataService.Changed(player, "Boosts")
		return reward.Amount .. " min Luck Boost"
	end
	return ""
end

function LoginRewardService.Init()
	Remote.OnInvoke("LoginReward", function(player, action)
		local data = DataService.Get(player)
		if not data then
			return { Ok = false }
		end
		updateStreak(player)
		if action == "Claim" then
			local day = today()
			if data.Login.ClaimedDay == day then
				return { Ok = false, Error = "Already claimed today" }
			end
			data.Login.ClaimedDay = day
			DataService.Changed(player, "Login")
			local parts = {}
			local rewards: { LoginRewards.Reward } = LoginRewards[data.Login.Streak] or {}
			for _, reward in rewards do
				table.insert(parts, grant(player, reward))
			end
			AnnouncementService.Notify(player, "Day " .. data.Login.Streak .. " reward: " .. table.concat(parts, ", "), "Reward", 5)
			return { Ok = true }
		end
		return { Ok = true, Streak = data.Login.Streak, Claimed = data.Login.ClaimedDay == today() }
	end, 2)
end

function LoginRewardService.Start()
	DataService.Loaded:Connect(function(player)
		updateStreak(player)
	end)
end

return LoginRewardService
