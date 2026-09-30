--!strict
-- Settings: music & SFX volume, low-graphics mode (no auras/particles/animations),
-- hide other players' trails, and the Roblox group reward check.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = require(ReplicatedStorage.Shared.Config.GameSettings)
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local Settings = {}

local content: Frame
local pending: { [string]: any } = {}
local saveQueued = false

local function current(): { [string]: any }
	local settings = State.Get("Settings") or {}
	local merged = table.clone(settings)
	for key, value in pending do
		merged[key] = value
	end
	return merged
end

local function save(key: string, value: any)
	pending[key] = value
	local settings = State.Get("Settings")
	if type(settings) == "table" then
		settings[key] = value
		State.Changed:Fire("Settings", settings)
	end
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(0.6, function()
		saveQueued = false
		Net.Event("SaveSettings"):FireServer(pending)
		pending = {}
	end)
end

local function render()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	local settings = current()
	local list = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, List = { Gap = 10 }, Parent = content })
	local function volumeRow(key: string, label: string, order: number)
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
		local value = settings[key] or 0.6
		UI.Text({ Text = string.format("%s  %d%%", label, math.floor(value * 100 + 0.5)), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 24, Parent = row })
		UI.Button({ Text = "-", Size = UDim2.fromOffset(60, 44), Position = UDim2.new(0.55, 0, 0, 3), BackgroundColor3 = Theme.Colors.PanelLight, OnActivated = function()
			save(key, math.clamp(math.floor(value * 10 + 0.5) / 10 - 0.1, 0, 1))
			render()
		end, Parent = row })
		UI.new("Frame", { Size = UDim2.new(0.22, 0, 0, 14), Position = UDim2.new(0.63, 0, 0, 18), BackgroundColor3 = Theme.Colors.Ink, Corner = UDim.new(1, 0), Parent = row, Children = {
			UI.new("Frame", { Size = UDim2.fromScale(value, 1), BackgroundColor3 = Theme.Colors.Pink, Corner = UDim.new(1, 0) }),
		} })
		UI.Button({ Text = "+", Size = UDim2.fromOffset(60, 44), Position = UDim2.new(0.87, 0, 0, 3), BackgroundColor3 = Theme.Colors.PanelLight, OnActivated = function()
			save(key, math.clamp(math.floor(value * 10 + 0.5) / 10 + 0.1, 0, 1))
			render()
		end, Parent = row })
	end
	local function toggleRow(key: string, label: string, order: number)
		local enabled = settings[key] == true
		UI.Button({
			Text = label .. ": " .. (if enabled then "ON" else "OFF"),
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = if enabled then Theme.Colors.Green else Theme.Colors.PanelLight,
			LayoutOrder = order,
			OnActivated = function()
				save(key, not enabled)
				render()
			end,
			Parent = list,
		})
	end
	volumeRow("Music", "MUSIC", 1)
	volumeRow("Sfx", "SOUND FX", 2)
	toggleRow("LowGraphics", "LOW GRAPHICS", 3)
	toggleRow("HideTrails", "HIDE OTHERS' TRAILS", 4)
	if GameSettings.GroupId ~= 0 then
		UI.Button({
			Text = "CLAIM GROUP REWARD (+" .. GameSettings.GroupSpeedReward .. " SPEED)",
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = Theme.Colors.Gold,
			LayoutOrder = 5,
			OnActivated = function()
				pcall(function()
					Net.Function("Shop"):InvokeServer("ClaimGroup")
				end)
			end,
			Parent = list,
		})
	end
end

function Settings.Init()
	local window = UI.Window("Settings", "SETTINGS", UDim2.fromOffset(620, 440), Theme.Colors.PanelLight)
	content = window.Content
	window.OnOpen = render
end

function Settings.Start()
	HUD.AddSidebarButton("Settings", "SETTINGS", Theme.Colors.PanelLight, function()
		UI.Open("Settings")
	end, 8)
end

return Settings
