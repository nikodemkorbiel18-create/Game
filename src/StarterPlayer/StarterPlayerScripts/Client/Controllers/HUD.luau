--!strict
-- Main HUD: cash + $/s, Speed + WalkSpeed, egg reset countdown, active events, uncollected
-- cash, and the left sidebar that opens every window.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Events = require(Shared.Config.Events)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Formulas = require(Shared.Util.Formulas)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local HUD = {}

local screen: ScreenGui
local sidebar: Frame
local cashLabel: TextLabel
local incomeLabel: TextLabel
local speedLabel: TextLabel
local walkLabel: TextLabel
local resetLabel: TextLabel
local registerPill: Frame
local registerLabel: TextLabel
local eventsRow: Frame
local badges: { [string]: Frame } = {}

local function pill(parent: Instance, name: string, size: UDim2, color: Color3): Frame
	return UI.new("Frame", {
		Name = name,
		Size = size,
		BackgroundColor3 = color,
		Corner = UDim.new(1, 0),
		Stroke = { Thickness = 3, Border = true },
		Parent = parent,
	})
end

-- Adds a sidebar button that toggles a window. Returns the button.
function HUD.AddSidebarButton(key: string, text: string, color: Color3, onActivated: () -> (), order: number?): TextButton
	local holder = UI.new("Frame", {
		Name = key,
		Size = UDim2.fromOffset(84, 70),
		BackgroundTransparency = 1,
		LayoutOrder = order or 50,
		Parent = sidebar,
	})
	local button = UI.Button({
		Name = "Button",
		Text = text,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		TextMax = 22,
		OnActivated = onActivated,
		Parent = holder,
	})
	local badge = UI.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -16, 0, -8),
		BackgroundColor3 = Theme.Colors.Red,
		Corner = UDim.new(1, 0),
		Stroke = { Thickness = 2, Border = true },
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	})
	UI.Text({ Name = "Count", Text = "!", Size = UDim2.fromScale(1, 1), TextMax = 18, ZIndex = 6, Parent = badge })
	badges[key] = badge
	return button
end

function HUD.SetBadge(key: string, count: number?)
	local badge = badges[key]
	if not badge then
		return
	end
	badge.Visible = count ~= nil and count > 0
	local label = badge:FindFirstChild("Count") :: TextLabel?
	if label and count then
		label.Text = if count > 9 then "9+" else tostring(count)
	end
end

function HUD.Screen(): ScreenGui
	return screen
end

local function buildTop()
	local top = UI.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(760, 70),
		BackgroundTransparency = 1,
		List = { Direction = Enum.FillDirection.Horizontal, Gap = 12 },
		Parent = screen,
	})
	local cash = pill(top, "Cash", UDim2.fromOffset(280, 66), Theme.Colors.Green)
	cash.LayoutOrder = 1
	cashLabel = UI.Text({ Text = "$0", Font = Theme.Fonts.Number, Size = UDim2.new(1, -24, 0.62, 0), Position = UDim2.fromOffset(12, 2), TextMax = 34, Parent = cash })
	incomeLabel = UI.Text({ Text = "+$0/s", Size = UDim2.new(1, -24, 0.36, 0), Position = UDim2.new(0, 12, 0.6, 0), TextColor3 = Color3.fromRGB(225, 255, 230), TextMax = 18, Parent = cash })

	local speed = pill(top, "Speed", UDim2.fromOffset(230, 66), Theme.Colors.Sky)
	speed.LayoutOrder = 2
	speedLabel = UI.Text({ Text = "Speed 0", Font = Theme.Fonts.Number, Size = UDim2.new(1, -24, 0.62, 0), Position = UDim2.fromOffset(12, 2), TextMax = 30, Parent = speed })
	walkLabel = UI.Text({ Text = "WalkSpeed 16", Size = UDim2.new(1, -24, 0.36, 0), Position = UDim2.new(0, 12, 0.6, 0), TextColor3 = Color3.fromRGB(225, 245, 255), TextMax = 18, Parent = speed })

	local reset = pill(top, "EggReset", UDim2.fromOffset(210, 66), Theme.Colors.Purple)
	reset.LayoutOrder = 3
	UI.Text({ Text = "EGGS RESET IN", Font = Theme.Fonts.Heading, Size = UDim2.new(1, -24, 0.4, 0), Position = UDim2.fromOffset(12, 4), TextMax = 18, Parent = reset })
	resetLabel = UI.Text({ Text = "5:00", Font = Theme.Fonts.Number, Size = UDim2.new(1, -24, 0.55, 0), Position = UDim2.new(0, 12, 0.42, 0), TextMax = 28, Parent = reset })

	registerPill = pill(screen, "Register", UDim2.fromOffset(300, 40), Theme.Colors.Gold)
	registerPill.AnchorPoint = Vector2.new(0.5, 0)
	registerPill.Position = UDim2.new(0.5, -230, 0, 82)
	registerPill.Visible = false
	registerLabel = UI.Text({ Text = "", Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), TextColor3 = Theme.Colors.Ink, Stroke = { Thickness = 0, Transparency = 1 }, TextMax = 18, Parent = registerPill })

	eventsRow = UI.new("Frame", {
		Name = "Events",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 120, 0, 82),
		Size = UDim2.fromOffset(520, 36),
		BackgroundTransparency = 1,
		List = { Direction = Enum.FillDirection.Horizontal, Gap = 8 },
		Parent = screen,
	})
end

local function buildSidebar()
	sidebar = UI.new("Frame", {
		Name = "Sidebar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.52, 0),
		Size = UDim2.fromOffset(84, 640),
		BackgroundTransparency = 1,
		List = { Gap = 8, VAlign = Enum.VerticalAlignment.Center },
		Parent = screen,
	})
end

local function renderEvents()
	for _, child in eventsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local now = workspace:GetServerTimeNow()
	local raw = ReplicatedStorage:GetAttribute("ActiveEvents")
	local ok, list = pcall(function()
		return HttpService:JSONDecode(if type(raw) == "string" then raw else "[]")
	end)
	local entries: { { Text: string, Color: Color3 } } = {}
	if ok and type(list) == "table" then
		for _, entry in list do
			local def = Events.ById[entry.Id]
			if def and entry.EndsAt > now then
				table.insert(entries, { Text = def.DisplayName .. " " .. TimeFormat.Clock(entry.EndsAt - now), Color = Color3.fromHex(def.Color) })
			end
		end
	end
	local luckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil")
	if type(luckUntil) == "number" and luckUntil > now then
		table.insert(entries, { Text = "Server Luck x2 " .. TimeFormat.Clock(luckUntil - now), Color = Color3.fromHex("#7CFF4F") })
	end
	local boosts = State.Get("Boosts")
	if type(boosts) == "table" and type(boosts.LuckEndsAt) == "number" and boosts.LuckEndsAt > now then
		table.insert(entries, { Text = "Luck Boost " .. TimeFormat.Clock(boosts.LuckEndsAt - now), Color = Theme.Colors.Gold })
	end
	for index, entry in entries do
		local chip = UI.new("Frame", {
			Size = UDim2.fromOffset(200, 34),
			BackgroundColor3 = entry.Color,
			Corner = UDim.new(1, 0),
			Stroke = { Thickness = 2, Border = true },
			LayoutOrder = index,
			Parent = eventsRow,
		})
		UI.Text({ Text = entry.Text, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), TextColor3 = Theme.Colors.Ink, Stroke = { Thickness = 0, Transparency = 1 }, TextMax = 16, Parent = chip })
	end
end

function HUD.Init()
	screen = UI.Screen("HUD", 5)
	buildTop()
	buildSidebar()
end

function HUD.Start()
	State.OnChange("Cash", function(cash)
		cashLabel.Text = NumberFormat.Cash(cash or 0)
	end)
	State.OnChange("@IncomePerSecond", function(income)
		incomeLabel.Text = "+" .. NumberFormat.PerSecond(income or 0)
	end)
	State.OnChange("Speed", function(speed)
		speedLabel.Text = "Speed " .. NumberFormat.Short(speed or 0)
		walkLabel.Text = string.format("WalkSpeed %.1f", Formulas.WalkSpeed(speed or 0))
	end)
	State.OnChange("Register", function(amount)
		registerPill.Visible = (amount or 0) > 0
		registerLabel.Text = "Uncollected " .. NumberFormat.Cash(amount or 0) .. " - step on COLLECT"
	end)
	State.OnChange("@Passes", function(passes)
		if type(passes) == "table" and passes.AutoCollect then
			registerPill.Visible = false
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local resetAt = ReplicatedStorage:GetAttribute("EggResetAt")
		if type(resetAt) == "number" then
			resetLabel.Text = TimeFormat.Clock(resetAt - workspace:GetServerTimeNow())
		end
		local walk = player:GetAttribute("WalkSpeed")
		if type(walk) == "number" and player:GetAttribute("Carrying") then
			walkLabel.Text = string.format("WalkSpeed %.1f (carrying)", walk)
		end
		renderEvents()
	end)
end

return HUD
