--!strict
-- Cash: per-second pen income into the plot's Cash Register, the Collect Plate,
-- Auto-Collect, offline earnings and the central Add/Spend cash API.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Formulas = require(Shared.Util.Formulas)
local IndexUtil = require(Shared.Util.IndexUtil)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local SpeedService = require(script.Parent.SpeedService)
local Remote = require(script.Parent.Parent.Lib.Remote)

type Item = Types.Item

local IncomeService = {}

local incomeCache: { [Player]: number } = {}

function IncomeService.Context(player: Player): Formulas.IncomeContext
	local data = DataService.Get(player)
	return {
		Rebirths = if data then data.Rebirths else 0,
		IndexBonus = if data then IndexUtil.IncomeBonus(data.Index) else 0,
		PassMultiplier = PassService.CashMultiplier(player),
	}
end

function IncomeService.ItemIncome(player: Player, item: Item): number
	return Formulas.EffectiveIncome(item, IncomeService.Context(player))
end

-- Sum of hatched characters in the pen
function IncomeService.Recalculate(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local context = IncomeService.Context(player)
	local total = 0
	for _, item in data.Pen do
		if item.Kind == "Character" then
			total += Formulas.EffectiveIncome(item, context)
		end
	end
	incomeCache[player] = total
	if total > data.Stats.HighestIncome then
		data.Stats.HighestIncome = total
	end
	DataService.SetDerived(player, "IncomePerSecond", total)
	PlotService.UpdateSign(player, total)
	return total
end

function IncomeService.PerSecond(player: Player): number
	return incomeCache[player] or IncomeService.Recalculate(player)
end

function IncomeService.AddCash(player: Player, amount: number, countAsEarned: boolean?)
	local data = DataService.Get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Cash += amount
	if countAsEarned ~= false then
		data.TotalEarned += amount
	end
	DataService.Changed(player, "Cash", "TotalEarned")
end

function IncomeService.CanAfford(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Cash >= amount
end

function IncomeService.Spend(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or amount < 0 or amount ~= amount or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	DataService.Changed(player, "Cash")
	return true
end

function IncomeService.Collect(player: Player)
	local data = DataService.Get(player)
	if not data or data.Register <= 0 then
		return
	end
	local amount = data.Register
	data.Register = 0
	data.Cash += amount
	DataService.Changed(player, "Cash", "Register")
	PlotService.SetRegister(player, 0)
	Remote.Fire("Effect", player, { Type = "Collect", Amount = amount })
end

local function tick()
	for _, player in DataService.LoadedPlayers() do
		local data = DataService.Get(player)
		if data then
			local income = IncomeService.Recalculate(player)
			if income > 0 then
				data.TotalEarned += income
				if PassService.Owns(player, "AutoCollect") then
					data.Cash += income
					DataService.Changed(player, "Cash", "TotalEarned")
				else
					data.Register += income
					DataService.Changed(player, "Register", "TotalEarned")
					PlotService.SetRegister(player, data.Register)
				end
			end
		end
	end
end

local function offlineEarnings(player: Player, data: Types.ProfileData, lastOnline: number)
	if lastOnline <= 0 then
		return
	end
	local away = os.time() - lastOnline
	if away < GameSettings.Offline.MinSecondsForPopup then
		return
	end
	local vip = PassService.Owns(player, "VIP")
	local rate = if vip then GameSettings.Offline.VipRate else GameSettings.Offline.Rate
	local cap = (if vip then GameSettings.Offline.VipCapHours else GameSettings.Offline.CapHours) * 3600
	local counted = math.min(away, cap)
	local income = IncomeService.Recalculate(player)
	local earned = math.floor(income * rate * counted)
	if earned <= 0 then
		return
	end
	data.Cash += earned
	data.TotalEarned += earned
	DataService.Changed(player, "Cash", "TotalEarned")
	Remote.Fire("OfflineEarnings", player, {
		Amount = earned,
		Away = away,
		Counted = counted,
		Rate = rate,
		Vip = vip,
		Text = string.format("While you were away for %s your chibis earned %s!", TimeFormat.Short(away), NumberFormat.Cash(earned)),
	})
end

function IncomeService.Init()
	PlotService.IncomeResolver = IncomeService.ItemIncome
	SpeedService.Spend = IncomeService.Spend
end

function IncomeService.Start()
	DataService.Loaded:Connect(function(player, data, lastOnline)
		task.delay(3, function()
			if player.Parent then
				offlineEarnings(player, data, lastOnline)
			end
		end)
		IncomeService.Recalculate(player)
		PlotService.SetRegister(player, data.Register)
	end)
	PassService.Changed:Connect(function(player)
		IncomeService.Recalculate(player)
		PlotService.RefreshIncomeLabels(player)
	end)
	for _, plot in PlotService.All() do
		local plate = plot.CollectPlate
		if plate then
			plate.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = if character then Players:GetPlayerFromCharacter(character) else nil
				if player and plot.Owner == player then
					IncomeService.Collect(player)
				end
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		incomeCache[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return IncomeService
