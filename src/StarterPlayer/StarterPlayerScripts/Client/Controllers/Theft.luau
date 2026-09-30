--!strict
-- Theft alerts: a red banner when someone raids your pen, a red highlight on anyone
-- carrying one of your chibis, and an on-screen arrow pointing at them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local Notifications = require(script.Parent.Notifications)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local Theft = {}

local screen: ScreenGui
local arrows: { [Player]: Frame } = {}
local highlights: { [Player]: Highlight } = {}

local function thieves(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Carrying") and other:GetAttribute("CarryOrigin") == "Stolen" and other:GetAttribute("CarryOwner") == player.UserId then
			table.insert(list, other)
		end
	end
	return list
end

local function makeArrow(thief: Player): Frame
	local holder = UI.new("Frame", {
		Name = "ThiefArrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(120, 90),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local arrow = UI.new("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Theme.Colors.Red,
		Rotation = 45,
		Stroke = { Thickness = 3, Border = true },
		Parent = holder,
	})
	local _ = arrow
	UI.Text({ Name = "Label", Text = thief.DisplayName, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromScale(0, 0.62), TextColor3 = Theme.Colors.Red, TextMax = 18, Parent = holder })
	return holder
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local active: { [Player]: boolean } = {}
	for _, thief in thieves() do
		active[thief] = true
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not root then
			continue
		end
		if not highlights[thief] then
			local highlight = Instance.new("Highlight")
			highlight.Name = "ThiefHighlight"
			highlight.FillColor = Theme.Colors.Red
			highlight.FillTransparency = 0.6
			highlight.OutlineColor = Theme.Colors.Red
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = character
			highlights[thief] = highlight
		end
		local arrow = arrows[thief] or makeArrow(thief)
		arrows[thief] = arrow
		local viewport = camera.ViewportSize
		local center = viewport / 2
		local screenPoint, onScreen = camera:WorldToViewportPoint(root.Position)
		local direction = Vector2.new(screenPoint.X, screenPoint.Y) - center
		if screenPoint.Z < 0 then
			direction = -direction
		end
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, -1)
		end
		local margin = 90
		local position: Vector2
		if onScreen and screenPoint.Z > 0 then
			position = Vector2.new(screenPoint.X, screenPoint.Y - 60)
		else
			local unit = direction.Unit
			local scaleX = (center.X - margin) / math.max(math.abs(unit.X), 0.001)
			local scaleY = (center.Y - margin) / math.max(math.abs(unit.Y), 0.001)
			position = center + unit * math.min(scaleX, scaleY)
		end
		local uiScale = UI.ViewportScale()
		arrow.Position = UDim2.fromOffset(position.X / uiScale, position.Y / uiScale)
		local pointer = arrow:FindFirstChild("Arrow") :: Frame?
		if pointer then
			pointer.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 45
		end
		local label = arrow:FindFirstChild("Label") :: TextLabel?
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if label and myRoot then
			label.Text = string.format("%s  %dm", thief.DisplayName, math.floor((root.Position - myRoot.Position).Magnitude))
		end
	end
	for thief, arrow in arrows do
		if not active[thief] then
			arrow:Destroy()
			arrows[thief] = nil
		end
	end
	for thief, highlight in highlights do
		if not active[thief] then
			highlight:Destroy()
			highlights[thief] = nil
		end
	end
end

function Theft.Init()
	screen = UI.Screen("TheftArrows", 8, true)
end

function Theft.Start()
	Net.Event("TheftAlert").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		Notifications.Banner(tostring(payload.Text or "SOMEONE IS STEALING FROM YOU!"), Theme.Colors.Red)
		Sound.Play("Alert", 1.3)
	end)
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then
			return
		end
		elapsed = 0
		update()
	end)
end

return Theft
