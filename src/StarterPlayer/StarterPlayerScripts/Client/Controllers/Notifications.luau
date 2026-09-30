--!strict
-- Speech-bubble toasts, the announcement banner lane, and the welcome-back popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local Sound = require(script.Parent.Sound)

local Notifications = {}

local toastHolder: Frame
local bannerHolder: Frame
local bannerQueue: { { Text: string, Color: Color3 } } = {}
local bannerBusy = false

local KIND_COLORS: { [string]: Color3 } = {
	Info = Theme.Colors.Paper,
	Success = Color3.fromRGB(200, 255, 210),
	Error = Color3.fromRGB(255, 205, 210),
	Warning = Color3.fromRGB(255, 240, 190),
	Theft = Color3.fromRGB(255, 120, 130),
	Reward = Color3.fromRGB(255, 236, 160),
}

function Notifications.Toast(text: string, kind: string?, duration: number?)
	local color = KIND_COLORS[kind or "Info"] or Theme.Colors.Paper
	local bubble = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = color,
		Corner = UDim.new(0, 18),
		Stroke = { Thickness = 3, Border = true },
		Parent = toastHolder,
	})
	UI.Text({
		Text = text,
		Size = UDim2.new(1, -24, 1, -10),
		Position = UDim2.fromOffset(12, 5),
		TextColor3 = Theme.Colors.Ink,
		Stroke = { Thickness = 0, Transparency = 1 },
		TextWrapped = true,
		TextMax = 22,
		Parent = bubble,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = bubble
	UI.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "Error" then
		Sound.Play("Error")
	elseif kind == "Theft" then
		Sound.Play("Alert")
	elseif kind == "Reward" or kind == "Success" then
		Sound.Play("Purchase")
	end
	task.delay(duration or 3, function()
		UI.Tween(scale, 0.15, { Scale = 0 })
		task.wait(0.16)
		bubble:Destroy()
	end)
	local children = toastHolder:GetChildren()
	local frames = 0
	for _, child in children do
		if child:IsA("Frame") then
			frames += 1
		end
	end
	if frames > 5 then
		for _, child in children do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
end

local function nextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local entry = table.remove(bannerQueue, 1) :: { Text: string, Color: Color3 }
	local banner = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Colors.Ink,
		Corner = UDim.new(0, 12),
		Stroke = { Color = entry.Color, Thickness = 4, Border = true },
		Parent = bannerHolder,
	})
	UI.Text({
		Text = entry.Text,
		Font = Theme.Fonts.Heading,
		TextColor3 = entry.Color,
		Size = UDim2.new(1, -24, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		TextMax = 34,
		Parent = banner,
	})
	Sound.Play("Reveal")
	UI.Tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		UI.Tween(banner, 0.3, { Position = UDim2.new(0.5, 0, 0, -90) })
		task.wait(0.35)
		banner:Destroy()
		bannerBusy = false
		nextBanner()
	end)
end

function Notifications.Banner(text: string, color: Color3?)
	table.insert(bannerQueue, { Text = text, Color = color or Theme.Colors.Gold })
	if #bannerQueue > 6 then
		table.remove(bannerQueue, 1)
	end
	nextBanner()
end

local function welcomeBack(data: { [string]: any })
	local window = UI.GetWindow("WelcomeBack") or UI.Window("WelcomeBack", "Welcome back!", UDim2.fromOffset(560, 320), Theme.Colors.Gold)
	for _, child in window.Content:GetChildren() do
		child:Destroy()
	end
	UI.Text({
		Text = tostring(data.Text),
		Size = UDim2.new(1, 0, 0.55, 0),
		TextWrapped = true,
		TextMax = 26,
		Parent = window.Content,
	})
	UI.Text({
		Text = string.format("(%d%% of your income%s)", math.floor((data.Rate or 0.25) * 100), if data.Vip then " - VIP bonus!" else ""),
		Size = UDim2.new(1, 0, 0.15, 0),
		Position = UDim2.fromScale(0, 0.55),
		TextColor3 = Theme.Colors.Muted,
		TextMax = 18,
		Parent = window.Content,
	})
	UI.Button({
		Text = "Nice!",
		Size = UDim2.new(0.5, 0, 0.25, 0),
		Position = UDim2.fromScale(0.25, 0.74),
		BackgroundColor3 = Theme.Colors.Green,
		OnActivated = function()
			UI.Close("WelcomeBack")
		end,
		Parent = window.Content,
	})
	UI.Open("WelcomeBack")
end

function Notifications.Init()
	local screen = UI.Screen("Notifications", 30)
	toastHolder = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.55, 0),
		Size = UDim2.fromOffset(360, 360),
		BackgroundTransparency = 1,
		List = { Gap = 8, VAlign = Enum.VerticalAlignment.Bottom, HAlign = Enum.HorizontalAlignment.Right },
		Parent = screen,
	})
	bannerHolder = UI.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(820, 80),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = screen,
	})
end

function Notifications.Start()
	Net.Event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Text) == "string" then
			Notifications.Toast(payload.Text, payload.Kind, payload.Duration)
		end
	end)
	Net.Event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Text) == "string" then
			local ok, color = pcall(Color3.fromHex, payload.Color or "#FFD34D")
			Notifications.Banner(payload.Text, if ok then color else nil)
		end
	end)
	Net.Event("OfflineEarnings").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			welcomeBack(payload)
		end
	end)
end

return Notifications
