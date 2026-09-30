--!strict
-- Admin panel (only shown to admins; everyone is an admin while testing in Studio).
-- Every command is re-checked on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Admin = {}

local added = false
local zoneId = 1
local rarityIndex = 0
local mutationIndex = 0
local globalEvents = false

local function command(name: string, ...: any)
	local args = { ... }
	task.spawn(function()
		pcall(function()
			Net.Function("Admin"):InvokeServer(name, args)
		end)
	end)
end

local function section(parent: Instance, title: string, order: number): Frame
	local frame = UI.new("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.PanelLight,
		LayoutOrder = order,
		Corner = true,
		Padding = 8,
		List = { Direction = Enum.FillDirection.Horizontal, Gap = 6, HAlign = Enum.HorizontalAlignment.Left, Wraps = true },
		Parent = parent,
	})
	UI.Text({ Text = title, Font = Theme.Fonts.Heading, Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 22, TextColor3 = Theme.Colors.Gold, LayoutOrder = 0, Parent = frame })
	return frame
end

local function button(parent: Instance, text: string, order: number, callback: () -> (), color: Color3?): TextButton
	return UI.Button({
		Text = text,
		Size = UDim2.fromOffset(math.max(96, #text * 11 + 24), 38),
		BackgroundColor3 = color or Theme.Colors.Sky,
		TextMax = 18,
		LayoutOrder = order,
		OnActivated = callback,
		Parent = parent,
	})
end

local function build()
	local window = UI.Window("Admin", "ADMIN PANEL", UDim2.fromOffset(900, 620), Theme.Colors.Red)
	local list = UI.Scroller({ Size = UDim2.fromScale(1, 1), List = { Gap = 8 }, Padding = 4, Parent = window.Content })

	local economy = section(list, "ECONOMY", 1)
	for index, amount in { 1e3, 1e6, 1e9, 1e12, 1e15 } do
		button(economy, "+$" .. (({ "1K", "1M", "1B", "1T", "1Qd" }) :: { string })[index], index, function()
			command("GiveCash", amount)
		end, Theme.Colors.Green)
	end
	for index, amount in { 1e3, 1e6, 1e9 } do
		button(economy, "+" .. (({ "1K", "1M", "1B" }) :: { string })[index] .. " Speed", 10 + index, function()
			command("GiveSpeed", amount)
		end)
	end

	local eggs = section(list, "EGGS", 2)
	local zoneButton: TextButton
	local rarityButton: TextButton
	local mutationButton: TextButton
	local function refreshLabels()
		zoneButton.Text = "Zone " .. zoneId
		rarityButton.Text = if rarityIndex == 0 then "Rarity: roll" else "Rarity: " .. Rarities.List[rarityIndex].Id
		mutationButton.Text = if mutationIndex == 0 then "Mutation: roll" else "Mutation: " .. Mutations.List[mutationIndex].Id
	end
	zoneButton = button(eggs, "Zone 1", 1, function()
		zoneId = zoneId % Zones.Count + 1
		refreshLabels()
	end, Theme.Colors.Purple)
	rarityButton = button(eggs, "Rarity: roll", 2, function()
		rarityIndex = (rarityIndex + 1) % (#Rarities.List + 1)
		refreshLabels()
	end, Theme.Colors.Purple)
	mutationButton = button(eggs, "Mutation: roll", 3, function()
		mutationIndex = (mutationIndex + 1) % (#Mutations.List + 1)
		refreshLabels()
	end, Theme.Colors.Purple)
	button(eggs, "SPAWN EGG", 4, function()
		command("SpawnEgg", zoneId, if rarityIndex > 0 then Rarities.List[rarityIndex].Id else nil, if mutationIndex > 0 then Mutations.List[mutationIndex].Id else nil)
	end, Theme.Colors.Green)
	button(eggs, "RESET EGGS", 5, function()
		command("ResetEggs")
	end)
	button(eggs, "HATCH ALL MINE", 6, function()
		command("HatchAll")
	end)
	button(eggs, "GO TO ZONE", 7, function()
		command("TeleportZone", zoneId)
	end)

	local give = section(list, "GIVE CHARACTER", 3)
	local idBox = UI.new("TextBox", {
		Size = UDim2.fromOffset(260, 38),
		BackgroundColor3 = Theme.Colors.Paper,
		TextColor3 = Theme.Colors.Ink,
		PlaceholderText = "CharacterId e.g. KohanaNineTail",
		Text = "",
		Font = Theme.Fonts.Body,
		TextScaled = true,
		ClearTextOnFocus = false,
		Corner = true,
		LayoutOrder = 1,
		Parent = give,
	}) :: TextBox
	button(give, "GIVE (Normal)", 2, function()
		command("GiveCharacter", idBox.Text, 3, if mutationIndex > 0 then Mutations.List[mutationIndex].Id else nil, false)
	end, Theme.Colors.Green)
	button(give, "GIVE TITAN", 3, function()
		command("GiveCharacter", idBox.Text, 6, if mutationIndex > 0 then Mutations.List[mutationIndex].Id else nil, false)
	end, Theme.Colors.Green)
	button(give, "GIVE AS EGG", 4, function()
		command("GiveCharacter", idBox.Text, 3, if mutationIndex > 0 then Mutations.List[mutationIndex].Id else nil, true)
	end)

	local events = section(list, "EVENTS", 4)
	local globalButton: TextButton
	globalButton = button(events, "Scope: this server", 0, function()
		globalEvents = not globalEvents
		globalButton.Text = if globalEvents then "Scope: ALL servers" else "Scope: this server"
	end, Theme.Colors.Purple)
	for index, event in Events.List do
		button(events, "Start " .. event.DisplayName, index, function()
			command("StartEvent", event.Id, 10, globalEvents)
		end, Color3.fromHex(event.Color))
		button(events, "Stop " .. event.DisplayName, 20 + index, function()
			command("StopEvent", event.Id)
		end, Theme.Colors.PanelLight)
	end
	button(events, "Server Luck", 40, function()
		command("ServerLuck")
	end, Theme.Colors.Green)

	local passes = section(list, "PASSES & PRODUCTS (test grants)", 5)
	for index, pass in Monetization.Passes do
		button(passes, pass.DisplayName, index, function()
			command("GrantPass", pass.Key)
		end, Theme.Colors.Gold)
	end
	for index, product in Monetization.Products do
		button(passes, product.DisplayName, 50 + index, function()
			command("GrantProduct", product.Key)
		end, Theme.Colors.Sky)
	end

	local boss = section(list, "GATEKEEPER & MISC", 6)
	button(boss, "Clear Gatekeeper", 1, function()
		command("ClearBoss")
	end, Theme.Colors.Green)
	button(boss, "Reset Gatekeeper", 2, function()
		command("ResetBoss")
	end, Theme.Colors.Red)
	button(boss, "End my new-player shield", 3, function()
		command("EndShield")
	end, Theme.Colors.PanelLight)
	local announceBox = UI.new("TextBox", {
		Size = UDim2.fromOffset(360, 38),
		BackgroundColor3 = Theme.Colors.Paper,
		TextColor3 = Theme.Colors.Ink,
		PlaceholderText = "Announcement text",
		Text = "",
		Font = Theme.Fonts.Body,
		TextScaled = true,
		ClearTextOnFocus = false,
		Corner = true,
		LayoutOrder = 4,
		Parent = boss,
	}) :: TextBox
	button(boss, "ANNOUNCE (all servers)", 5, function()
		command("Announce", announceBox.Text)
	end, Theme.Colors.Pink)
	refreshLabels()
end

local function update()
	if player:GetAttribute("IsAdmin") and not added then
		added = true
		build()
		HUD.AddSidebarButton("Admin", "ADMIN", Theme.Colors.Red, function()
			UI.Toggle("Admin")
		end, 99)
	end
end

function Admin.Init() end

function Admin.Start()
	player:GetAttributeChangedSignal("IsAdmin"):Connect(update)
	update()
end

return Admin
