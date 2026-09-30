--!strict
-- Character Index: a grid per zone (plus Festival, Gacha and Fusion). Undiscovered
-- characters show as a black silhouette with "???". First-discovery rewards are claimed
-- here (the sidebar button pulses while any are waiting). Zone completion = +5% income.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Zones = require(Shared.Config.Zones)
local Mutations = require(Shared.Config.Mutations)
local IndexConfig = require(Shared.Config.Index)
local Formulas = require(Shared.Util.Formulas)
local IndexUtil = require(Shared.Util.IndexUtil)
local NumberFormat = require(Shared.Util.NumberFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local ItemCard = require(script.Parent.Parent.UI.ItemCard)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local Index = {}

local pages: { [string]: Frame } = {}
local selectTab: (string) -> () = function() end
local currentTab = "Z1"
local summary: TextLabel

local function unclaimedCount(): number
	local index = State.Get("Index") or {}
	local count = 0
	for _, entry in index do
		if entry.Discovered and not entry.Claimed then
			count += 1
		end
	end
	return count
end

local function charactersFor(tab: string): { Characters.Character }
	if string.sub(tab, 1, 1) == "Z" then
		return Characters.ForZone(tonumber(string.sub(tab, 2)) :: number)
	end
	return Characters.ForPool(tab)
end

local function render(tab: string)
	currentTab = tab
	local page = pages[tab]
	if not page then
		return
	end
	for _, child in page:GetChildren() do
		child:Destroy()
	end
	local index = State.Get("Index") or {}
	local list = UI.Scroller({
		Size = UDim2.new(1, 0, 1, -40),
		Position = UDim2.fromOffset(0, 40),
		Grid = { Cell = UDim2.fromOffset(170, 272), Gap = UDim2.fromOffset(8, 8) },
		Padding = 6,
		Parent = page,
	})
	local roster = charactersFor(tab)
	local found = 0
	for order, character in roster do
		local entry = index[character.Id]
		local discovered = entry ~= nil and entry.Discovered == true
		if discovered then
			found += 1
		end
		local variants = {}
		if entry then
			for variant in entry.Variants do
				if variant ~= "Normal" then
					local mutation = Mutations.Get(variant)
					if mutation then
						table.insert(variants, mutation.DisplayName)
					end
				end
			end
		end
		local buttons = {}
		if discovered and not entry.Claimed then
			table.insert(buttons, {
				Text = "CLAIM",
				Color = Theme.Colors.Gold,
				OnActivated = function()
					pcall(function()
						Net.Function("Index"):InvokeServer("Claim", character.Id)
					end)
				end,
			})
		end
		local subtitle: string
		if discovered then
			subtitle = NumberFormat.PerSecond(character.BaseIncome) .. " base"
		else
			subtitle = string.format("Reward %s", NumberFormat.Cash(Formulas.DiscoveryCash(character.Id)))
		end
		local card = ItemCard.Build({
			CharacterId = character.Id,
			Kind = "Character",
			SizeTier = 3,
			Kg = 7,
		}, {
			Parent = list,
			LayoutOrder = order,
			Known = discovered,
			Silhouette = not discovered,
			Subtitle = subtitle,
			Buttons = buttons,
		})
		if #variants > 0 then
			UI.Text({ Text = table.concat(variants, " · "), Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 180), TextColor3 = Theme.Colors.Pink, TextMax = 13, Parent = card })
		end
		if entry and entry.Awakened then
			UI.Text({ Text = "★", Font = Theme.Fonts.Heading, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -32, 0, 4), TextColor3 = Theme.Colors.Gold, TextMax = 26, Parent = card })
		end
	end
	local completeText = ""
	if string.sub(tab, 1, 1) == "Z" then
		local zoneId = tonumber(string.sub(tab, 2)) :: number
		local zone = Zones.Get(zoneId)
		local complete = IndexUtil.ZoneComplete(index, zoneId)
		completeText = string.format("%s: %d / %d found%s", zone.DisplayName, found, #roster, if complete then string.format("  ·  COMPLETE (+%d%% income)", math.floor(IndexConfig.ZoneCompletionBonus * 100)) else "")
	else
		completeText = string.format("%s: %d / %d found%s", tab, found, #roster, if tab == "Gacha" then "  (not required for full completion)" else "")
	end
	UI.Text({ Text = completeText, Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 22, Parent = page })
	local total, all = IndexUtil.Counts(index)
	summary.Text = string.format("Index %d / %d  ·  Income bonus +%d%%", total, all, math.floor(IndexUtil.IncomeBonus(index) * 100 + 0.5))
end

function Index.Init()
	local window = UI.Window("Index", "CHIBI INDEX", UDim2.fromOffset(1000, 640), Theme.Colors.Purple)
	local header = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = window.Content })
	summary = UI.Text({ Text = "", Size = UDim2.new(0.62, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 22, Parent = header })
	UI.Button({
		Text = "CLAIM ALL",
		Size = UDim2.fromOffset(180, 40),
		Position = UDim2.new(1, -180, 0, 0),
		BackgroundColor3 = Theme.Colors.Gold,
		OnActivated = function()
			pcall(function()
				Net.Function("Index"):InvokeServer("ClaimAll")
			end)
		end,
		Parent = header,
	})
	local body = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, Parent = window.Content })
	local tabs = {}
	for _, zone in Zones.List do
		table.insert(tabs, { Key = "Z" .. zone.Id, Text = tostring(zone.Id), Color = Color3.fromHex(zone.Theme.Accent) })
	end
	table.insert(tabs, { Key = "Festival", Text = "FEST", Color = Theme.Colors.Gold })
	table.insert(tabs, { Key = "Gacha", Text = "GACHA", Color = Theme.Colors.Sky })
	table.insert(tabs, { Key = "Fusion", Text = "FUSION", Color = Theme.Colors.Purple })
	pages, selectTab = UI.Tabs(body, tabs, render)
	local tabBar = body:FindFirstChild("TabBar")
	if tabBar then
		for _, button in tabBar:GetChildren() do
			if button:IsA("TextButton") then
				button.Size = UDim2.fromOffset(if tonumber(button.Name) or string.sub(button.Name, 1, 1) == "Z" then 52 else 96, 40)
			end
		end
	end
	window.OnOpen = function()
		render(currentTab)
	end
end

function Index.Start()
	HUD.AddSidebarButton("Index", "INDEX", Theme.Colors.Purple, function()
		UI.Open("Index")
		selectTab(currentTab)
	end, 3)
	State.OnChange("Index", function()
		HUD.SetBadge("Index", unclaimedCount())
		if UI.IsOpen("Index") then
			render(currentTab)
		end
	end)
	-- pulse the button while rewards wait
	task.spawn(function()
		while true do
			task.wait(0.6)
			local count = unclaimedCount()
			local screen = HUD.Screen()
			local holder = screen:FindFirstChild("Index", true)
			local button = holder and holder:FindFirstChild("Button")
			if button and button:IsA("TextButton") then
				local scale = button:FindFirstChildOfClass("UIScale")
				if scale and count > 0 then
					UI.Tween(scale, 0.3, { Scale = 1.12 })
					task.wait(0.3)
					UI.Tween(scale, 0.3, { Scale = 1 })
				end
			end
		end
	end)
end

return Index
