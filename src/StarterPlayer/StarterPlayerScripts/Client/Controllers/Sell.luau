--!strict
-- Sell Counter (Station Plaza): pick chibis from your pen or inventory and sell them for
-- 30x their effective $/s. Protected chibis are skipped; Legendary+ asks to confirm.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local ItemCard = require(script.Parent.Parent.UI.ItemCard)
local State = require(script.Parent.State)

local Sell = {}

local selected: { [string]: boolean? } = {}
local listFrame: Frame
local totalLabel: TextLabel

local function allCharacters(): { any }
	local list = {}
	for _, item in State.Get("Pen") or {} do
		if item.Kind == "Character" then
			table.insert(list, item)
		end
	end
	for _, item in State.Get("Inventory") or {} do
		if item.Kind == "Character" then
			table.insert(list, item)
		end
	end
	return list
end

local function render()
	for _, child in listFrame:GetChildren() do
		child:Destroy()
	end
	local scroller = UI.Scroller({
		Size = UDim2.fromScale(1, 1),
		Grid = { Cell = UDim2.fromOffset(170, 200), Gap = UDim2.fromOffset(8, 8) },
		Padding = 6,
		Parent = listFrame,
	})
	local context = State.IncomeContext()
	local items = allCharacters()
	table.sort(items, function(a, b)
		return Formulas.EffectiveIncome(a, context) < Formulas.EffectiveIncome(b, context)
	end)
	local total = 0
	local present: { [string]: boolean } = {}
	for order, item in items do
		present[item.Uid] = true
		local price = math.floor(Formulas.EffectiveIncome(item, context) * GameSettings.SellMultiplier)
		if selected[item.Uid] then
			total += price
		end
		ItemCard.Build(item, {
			Parent = scroller,
			LayoutOrder = order,
			Selected = selected[item.Uid] == true,
			Subtitle = if item.Protected then "PROTECTED" else "Sell " .. NumberFormat.Cash(price),
			OnSelect = function()
				if item.Protected then
					return
				end
				selected[item.Uid] = not selected[item.Uid] or nil
				render()
			end,
		})
	end
	for uid in selected do
		if not present[uid] then
			selected[uid] = nil
		end
	end
	totalLabel.Text = "Selected: " .. NumberFormat.Cash(total)
end

local function sell()
	local uids = {}
	local needsConfirm = false
	local context = State.IncomeContext()
	for _, item in allCharacters() do
		if selected[item.Uid] then
			table.insert(uids, item.Uid)
			if Rarities.Rank(Formulas.DisplayRarity(item)) >= GameSettings.SellConfirmRank then
				needsConfirm = true
			end
		end
	end
	local _ = context
	if #uids == 0 then
		return
	end
	local function send(confirmed: boolean)
		local ok, result = pcall(function()
			return Net.Function("Sell"):InvokeServer(uids, confirmed)
		end)
		if ok and type(result) == "table" and result.Ok then
			table.clear(selected)
		end
		UI.Open("Sell")
		render()
	end
	if needsConfirm then
		UI.Confirm("Sell rare chibis?", "You're selling Legendary or rarer chibis. This can't be undone.", "Sell", function(confirmed)
			if confirmed then
				send(true)
			else
				UI.Open("Sell")
			end
		end)
	else
		send(false)
	end
end

function Sell.Init()
	local window = UI.Window("Sell", "SELL COUNTER", UDim2.fromOffset(960, 600), Theme.Colors.Green)
	local header = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = window.Content })
	totalLabel = UI.Text({ Text = "", Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 24, Parent = header })
	UI.Button({ Text = "SELL SELECTED", Size = UDim2.fromOffset(220, 40), Position = UDim2.new(1, -220, 0, 0), BackgroundColor3 = Theme.Colors.Red, OnActivated = sell, Parent = header })
	UI.Text({ Text = "Tap chibis to select. Protected chibis can't be sold.", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 46), TextColor3 = Theme.Colors.Muted, TextMax = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = window.Content })
	listFrame = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -76), Position = UDim2.fromOffset(0, 76), BackgroundTransparency = 1, Parent = window.Content })
	window.OnOpen = render
end

function Sell.Start()
	local function add(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("KioskPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "KioskPrompt"
		prompt.ActionText = "Sell Chibis"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			UI.Open("Sell")
		end)
		prompt.Parent = part
	end
	for _, part in CollectionService:GetTagged("SellCounter") do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("SellCounter"):Connect(add)
end

return Sell
