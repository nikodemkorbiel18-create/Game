--!strict
-- Action buttons for every platform through ContextActionService:
--   Harisen slap  F / R1 / touch button
--   Ofuda trap    T / Y  / touch button
--   Smoke bomb    G / DPadUp / touch button
-- Interact is handled by ProximityPrompts (E / X / tap). Counts show on a small action bar.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameSettings = require(Shared.Config.GameSettings)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local Input = {}

local lastSlap = 0
local bar: Frame
local labels: { [string]: TextLabel } = {}

local function stunned(): boolean
	local untilTime = player:GetAttribute("StunnedUntil")
	return type(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

local function swingFan()
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local fan = Instance.new("Part")
	fan.Name = "Harisen"
	fan.Size = Vector3.new(0.2, 2.2, 1.6)
	fan.Color = Color3.fromHex("#F2E8CF")
	fan.CanCollide = false
	fan.CanQuery = false
	fan.Massless = true
	fan.CFrame = hand.CFrame * CFrame.new(0, -1.2, -0.6)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = fan
	weld.Parent = fan
	fan.Parent = character
	task.delay(0.35, function()
		fan:Destroy()
	end)
end

local function slap(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastSlap < GameSettings.Slap.Cooldown or stunned() then
		return Enum.ContextActionResult.Sink
	end
	lastSlap = now
	swingFan()
	Sound.Play("Slap")
	Net.Event("Slap"):FireServer()
	return Enum.ContextActionResult.Sink
end

local function trap(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and not stunned() then
		Net.Event("PlaceTrap"):FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function smoke(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		Net.Event("UseSmoke"):FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function barButton(key: string, text: string, hint: string, color: Color3, order: number, callback: () -> ())
	local button = UI.Button({
		Name = key,
		Text = "",
		Size = UDim2.fromOffset(92, 92),
		BackgroundColor3 = color,
		LayoutOrder = order,
		OnActivated = callback,
		Parent = bar,
	})
	UI.Text({ Text = text, Font = Theme.Fonts.Heading, Size = UDim2.new(1, -8, 0.45, 0), Position = UDim2.fromOffset(4, 8), TextMax = 24, Parent = button })
	labels[key] = UI.Text({ Text = "", Size = UDim2.new(1, -8, 0.28, 0), Position = UDim2.new(0, 4, 0.5, 0), TextMax = 20, Parent = button })
	if not UserInputService.TouchEnabled then
		UI.Text({ Text = hint, Size = UDim2.new(1, -8, 0.2, 0), Position = UDim2.new(0, 4, 0.78, 0), TextColor3 = Theme.Colors.Paper, TextMax = 14, Parent = button })
	end
end

function Input.Init()
	local screen = UI.Screen("ActionBar", 4)
	bar = UI.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(310, 96),
		BackgroundTransparency = 1,
		List = { Direction = Enum.FillDirection.Horizontal, Gap = 10, HAlign = Enum.HorizontalAlignment.Right },
		Parent = screen,
	})
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		-- keep clear of the default jump button on phones
		bar.Position = UDim2.new(1, -200, 1, -20)
	end
	barButton("Slap", "SLAP", "[F]", Theme.Colors.Pink, 1, function()
		slap("Slap", Enum.UserInputState.Begin)
	end)
	barButton("Trap", "TRAP", "[T]", Theme.Colors.Gold, 2, function()
		trap("Trap", Enum.UserInputState.Begin)
	end)
	barButton("Smoke", "SMOKE", "[G]", Theme.Colors.PanelLight, 3, function()
		smoke("Smoke", Enum.UserInputState.Begin)
	end)
end

function Input.Start()
	ContextActionService:BindAction("Slap", slap, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("PlaceTrap", trap, false, Enum.KeyCode.T, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("SmokeBomb", smoke, false, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	State.OnChange("Traps", function(count)
		labels.Trap.Text = "x" .. tostring(count or 0)
	end)
	State.OnChange("SmokeBombs", function(count)
		labels.Smoke.Text = "x" .. tostring(count or 0)
	end)
	task.spawn(function()
		while true do
			local left = GameSettings.Slap.Cooldown - (os.clock() - lastSlap)
			labels.Slap.Text = if left > 0 then string.format("%.1fs", left) else "READY"
			task.wait(0.1)
		end
	end)
end

return Input
