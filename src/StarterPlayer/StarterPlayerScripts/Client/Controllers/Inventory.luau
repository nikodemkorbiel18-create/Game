--!strict
-- Inventory window: unplaced eggs/characters (50 max) and your pen. Place, store, carry,
-- protect, and Equip Best (auto-fills slots with your highest $/s chibis).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Formulas = require(Shared.Util.Formulas)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local ItemCard = require(script.Parent.Parent.UI.ItemCard)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local Inventory = {}

local pages: { [string]: Frame } = {}
local selectTab: (string) -> () = function() end
local currentTab = "Inventory"
local countLabel: TextLabel

local function request(action: string, a: any?, b: any?)
	pcall(function()
		Net.Function("Inventory"):InvokeServer(action, a, b)
	end)
end

local function grid(page: Frame): ScrollingFrame
	for _, child in page:GetChildren() do
		child:Destroy()
	end
	return UI.Scroller({
		Size = UDim2.fromScale(1, 1),
		Grid = { Cell = UDim2.fromOffset(170, 312), Gap = UDim2.fromOffset(8, 8) },
		Padding = 6,
		Parent = page,
	})
end

local function renderInventory()
	local list = grid(pages.Inventory)
	local items = State.Get("Inventory") or {}
	local context = State.IncomeContext()
	countLabel.Text = string.format("Inventory %d / %d", #items, GameSettings.InventoryCapacity)
	local sorted = table.clone(items)
	table.sort(sorted, function(a, b)
		local av = if a.Kind == "Character" then Formulas.EffectiveIncome(a, context) else -1
		local bv = if b.Kind == "Character" then Formulas.EffectiveIncome(b, context) else -1
		return av > bv
	end)
	for index, item in sorted do
		ItemCard.Build(item, {
			Parent = list,
			LayoutOrder = index,
			Known = State.IsDiscovered(item.CharacterId),
			Income = if item.Kind == "Character" then Formulas.EffectiveIncome(item, context) else nil,
			Buttons = {
				{ Text = "PLACE", Color = Theme.Colors.Green, OnActivated = function()
					request("Place", item.Uid)
				end },
				{ Text = "CARRY", Color = Theme.Colors.Sky, OnActivated = function()
					request("Carry", item.Uid)
					UI.Close("Inventory")
				end },
				{ Text = if item.Protected then "UNPROTECT" else "PROTECT", Color = Theme.Colors.Gold, OnActivated = function()
					request("Protect", item.Uid, not item.Protected)
				end },
			},
		})
	end
	if #items == 0 then
		UI.Text({ Text = "Your inventory is empty. Eggs you bring home go straight into your pen.", Size = UDim2.new(1, -20, 0, 60), TextWrapped = true, TextMax = 20, Parent = list })
	end
end

local function renderPen()
	local list = grid(pages.Pen)
	local pen = State.Get("Pen") or {}
	local context = State.IncomeContext()
	local keys = {}
	for key in pen do
		table.insert(keys, tonumber(key) :: number)
	end
	table.sort(keys)
	for order, slot in keys do
		local item = pen[tostring(slot)]
		ItemCard.Build(item, {
			Parent = list,
			LayoutOrder = order,
			Known = true,
			Income = if item.Kind == "Character" then Formulas.EffectiveIncome(item, context) else nil,
			Buttons = {
				{ Text = "STORE", Color = Theme.Colors.Sky, OnActivated = function()
					request("Store", slot)
				end },
				{ Text = if item.Protected then "UNPROTECT" else "PROTECT", Color = Theme.Colors.Gold, OnActivated = function()
					request("Protect", item.Uid, not item.Protected)
				end },
			},
		})
	end
end

local function render(tab: string)
	currentTab = tab
	if tab == "Inventory" then
		renderInventory()
	else
		renderPen()
	end
end

function Inventory.Open()
	UI.Open("Inventory")
	selectTab(currentTab)
end

function Inventory.Init()
	local window = UI.Window("Inventory", "INVENTORY", UDim2.fromOffset(980, 620), Theme.Colors.Sky)
	local header = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = window.Content,
	})
	countLabel = UI.Text({ Text = "", Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 24, Parent = header })
	UI.Button({
		Text = "EQUIP BEST",
		Size = UDim2.fromOffset(200, 40),
		Position = UDim2.new(1, -200, 0, 0),
		BackgroundColor3 = Theme.Colors.Green,
		OnActivated = function()
			request("EquipBest")
		end,
		Parent = header,
	})
	local body = UI.new("Frame", {
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.fromOffset(0, 50),
		BackgroundTransparency = 1,
		Parent = window.Content,
	})
	pages, selectTab = UI.Tabs(body, {
		{ Key = "Inventory", Text = "INVENTORY", Color = Theme.Colors.Sky },
		{ Key = "Pen", Text = "MY PEN", Color = Theme.Colors.Pink },
	}, render)
	window.OnOpen = function()
		render(currentTab)
	end
end

function Inventory.Start()
	HUD.AddSidebarButton("Inventory", "ITEMS", Theme.Colors.Sky, Inventory.Open, 5)
	State.OnChange("Inventory", function()
		if UI.IsOpen("Inventory") then
			render(currentTab)
		end
	end)
	State.OnChange("Pen", function()
		if UI.IsOpen("Inventory") and currentTab == "Pen" then
			render(currentTab)
		end
	end)
end

return Inventory
