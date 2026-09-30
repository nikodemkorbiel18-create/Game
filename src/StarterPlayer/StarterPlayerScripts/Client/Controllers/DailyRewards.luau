--!strict
-- 7-day login streak popup: shows the week and claims today's reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoginRewards = require(ReplicatedStorage.Shared.Config.LoginRewards)
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local DailyRewards = {}

local content: Frame

local function today(): number
	return math.floor(workspace:GetServerTimeNow() / 86400)
end

local function claimedToday(): boolean
	local login = State.Get("Login")
	return type(login) == "table" and login.ClaimedDay == today()
end

local function render()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	local login = State.Get("Login") or { Streak = 1 }
	local streak = math.max(1, login.Streak or 1)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, List = { Direction = Enum.FillDirection.Horizontal, Gap = 8 }, Parent = content })
	for day, rewards in LoginRewards do
		local labels = {}
		for _, reward in rewards do
			table.insert(labels, reward.Label)
		end
		local isToday = day == streak
		local done = day < streak or (isToday and claimedToday())
		local card = UI.new("Frame", {
			Size = UDim2.fromOffset(112, 190),
			BackgroundColor3 = if isToday then Theme.Colors.Gold elseif done then Theme.Colors.PanelLight else Theme.Colors.Panel,
			LayoutOrder = day,
			Corner = true,
			Stroke = { Thickness = 3, Border = true },
			Parent = row,
		})
		UI.Text({ Text = "DAY " .. day, Font = Theme.Fonts.Heading, Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 6), TextMax = 26, Parent = card })
		UI.Text({ Text = table.concat(labels, "\n"), Size = UDim2.new(1, -10, 1, -80), Position = UDim2.fromOffset(5, 44), TextWrapped = true, TextMax = 16, Parent = card })
		UI.Text({ Text = if done then "CLAIMED" elseif isToday then "TODAY" else "", Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -30), TextColor3 = if done then Theme.Colors.Green else Theme.Colors.White, TextMax = 18, Parent = card })
	end
	UI.Button({
		Text = if claimedToday() then "COME BACK TOMORROW" else "CLAIM DAY " .. streak,
		Size = UDim2.new(0.6, 0, 0, 54),
		Position = UDim2.new(0.2, 0, 0, 220),
		BackgroundColor3 = if claimedToday() then Theme.Colors.Muted else Theme.Colors.Green,
		OnActivated = function()
			if not claimedToday() then
				pcall(function()
					Net.Function("LoginReward"):InvokeServer("Claim")
				end)
				task.wait(0.2)
				render()
			end
		end,
		Parent = content,
	})
end

function DailyRewards.Init()
	local window = UI.Window("Daily", "DAILY LOGIN", UDim2.fromOffset(880, 380), Theme.Colors.Gold)
	content = window.Content
	window.OnOpen = render
end

function DailyRewards.Start()
	HUD.AddSidebarButton("Daily", "DAILY", Theme.Colors.Gold, function()
		UI.Open("Daily")
	end, 7)
	State.WaitUntilLoaded()
	pcall(function()
		Net.Function("LoginReward"):InvokeServer("Status")
	end)
	State.OnChange("Login", function()
		HUD.SetBadge("Daily", if claimedToday() then 0 else 1)
	end)
	task.delay(6, function()
		if not claimedToday() and not UI.IsOpen("WelcomeBack") then
			UI.Open("Daily")
		end
	end)
end

return DailyRewards
