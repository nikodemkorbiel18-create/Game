--!nonstrict
-- Tiny declarative UI toolkit + window manager. Every screen in the game is built from
-- these helpers so the look stays consistent and gamepad/touch behave the same everywhere.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local UI = {}

export type Props = { [string]: any }

local SPECIAL = {
	Children = true,
	Corner = true,
	Stroke = true,
	Padding = true,
	List = true,
	Grid = true,
	Aspect = true,
	Gradient = true,
	TextMax = true,
	Scale = true,
}

-- UI.new("Frame", { Size = ..., OnActivated = fn, Children = { ... } })
function UI.new(className: string, props: Props?): any
	local instance = Instance.new(className) :: any
	local p = props or {}
	for key, value in p do
		if SPECIAL[key] or key == "Parent" then
			continue
		end
		if string.sub(key, 1, 2) == "On" and type(value) == "function" then
			local eventName = string.sub(key, 3)
			instance[eventName]:Connect(value)
		else
			instance[key] = value
		end
	end
	if p.Corner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if typeof(p.Corner) == "UDim" then p.Corner else Theme.Corner
		corner.Parent = instance
	end
	if p.Stroke then
		local spec = if type(p.Stroke) == "table" then p.Stroke else {}
		local stroke = Instance.new("UIStroke")
		stroke.Color = spec.Color or Theme.Colors.Ink
		stroke.Thickness = spec.Thickness or Theme.Stroke
		stroke.Transparency = spec.Transparency or 0
		stroke.ApplyStrokeMode = spec.Border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = instance
	end
	if p.Padding then
		local padding = Instance.new("UIPadding")
		local value = if type(p.Padding) == "number" then UDim.new(0, p.Padding) else p.Padding
		padding.PaddingLeft = value
		padding.PaddingRight = value
		padding.PaddingTop = value
		padding.PaddingBottom = value
		padding.Parent = instance
	end
	if p.List then
		local spec = p.List
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = spec.Direction or Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, spec.Gap or 6)
		layout.HorizontalAlignment = spec.HAlign or Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = spec.VAlign or Enum.VerticalAlignment.Top
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Wraps = spec.Wraps == true
		layout.Parent = instance
	end
	if p.Grid then
		local spec = p.Grid
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = spec.Cell or UDim2.fromOffset(110, 140)
		layout.CellPadding = spec.Gap or UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = instance
	end
	if p.Aspect then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = p.Aspect
		aspect.Parent = instance
	end
	if p.Gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = p.Gradient
		gradient.Rotation = p.GradientRotation or 90
		gradient.Parent = instance
	end
	if p.TextMax then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = p.TextMax
		constraint.Parent = instance
	end
	for _, child in p.Children or {} do
		child.Parent = instance
	end
	if p.Parent then
		instance.Parent = p.Parent
	end
	return instance
end

-- Outlined text label
function UI.Text(props: Props): TextLabel
	local defaults: Props = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.White,
		TextScaled = true,
		Stroke = { Thickness = 2 },
		TextMax = 36,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextLabel", defaults)
end

local clickSound: ((string) -> ())? = nil
function UI.SetClickSound(callback: (string) -> ())
	clickSound = callback
end

-- Chunky button with a press bounce
function UI.Button(props: Props): TextButton
	local defaults: Props = {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Pink,
		Font = Theme.Fonts.Heading,
		TextColor3 = Theme.Colors.White,
		TextScaled = true,
		Corner = true,
		Stroke = { Thickness = 3, Border = true },
		TextMax = 32,
		Selectable = true,
	}
	for key, value in props do
		if key ~= "OnActivated" then
			defaults[key] = value
		end
	end
	local button = UI.new("TextButton", defaults) :: TextButton
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Theme.Colors.Ink
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local onActivated = props.OnActivated
	button.Activated:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
		task.delay(0.06, function()
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
		if clickSound then
			clickSound("Click")
		end
		if onActivated then
			onActivated()
		end
	end)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	return button
end

function UI.Tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- ScreenGui helper
function UI.Screen(name: string, displayOrder: number?, ignoreInset: boolean?): ScreenGui
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		IgnoreGuiInset = ignoreInset == true,
	}) :: ScreenGui
	local scale = Instance.new("UIScale")
	scale.Name = "AutoScale"
	scale.Parent = gui
	gui.Parent = playerGui
	return gui
end

-- Scale every screen with the viewport so phones (390px tall) and 4K screens both work.
local function updateScales()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.25)
	for _, gui in playerGui:GetChildren() do
		local autoScale = gui:FindFirstChild("AutoScale")
		if autoScale and autoScale:IsA("UIScale") then
			autoScale.Scale = scale
		end
	end
end

function UI.ViewportScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	return math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.25)
end

task.defer(function()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end
	playerGui.ChildAdded:Connect(function()
		task.defer(updateScales)
	end)
	updateScales()
end)

-- Model preview inside a ViewportFrame
function UI.Viewport(model: Model, props: Props?): ViewportFrame
	local defaults: Props = {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	}
	if props then
		for key, value in props do
			defaults[key] = value
		end
	end
	local viewport = UI.new("ViewportFrame", defaults) :: ViewportFrame
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	model.Parent = worldModel
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.25
	local center = cf.Position
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * 0.15, -distance), center)
	return viewport
end

-- Window manager ---------------------------------------------------------------

type Window = {
	Name: string,
	Frame: Frame,
	Content: Frame,
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
}

local windows: { [string]: Window } = {}
local openName: string? = nil
local windowScreen: ScreenGui? = nil

local function screen(): ScreenGui
	if not windowScreen then
		windowScreen = UI.Screen("Windows", 20)
	end
	return windowScreen :: ScreenGui
end

function UI.Window(name: string, title: string, size: UDim2?, color: Color3?): Window
	local frame = UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size or UDim2.fromOffset(760, 520),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Corner = UDim.new(0, 20),
		Stroke = { Thickness = 4, Border = true },
		Parent = screen(),
	}) :: Frame
	local titleBar = UI.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color or Theme.Colors.Pink,
		Corner = UDim.new(0, 20),
		Parent = frame,
	})
	UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = color or Theme.Colors.Pink,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	UI.Text({
		Name = "Title",
		Text = title,
		Font = Theme.Fonts.Heading,
		Size = UDim2.new(1, -140, 1, -10),
		Position = UDim2.fromOffset(20, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextMax = 44,
		Stroke = { Thickness = 3 },
		Parent = titleBar,
	})
	UI.Button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -54, 0, 6),
		BackgroundColor3 = Theme.Colors.Red,
		OnActivated = function()
			UI.Close(name)
		end,
		Parent = titleBar,
	})
	local content = UI.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -24, 1, -76),
		Position = UDim2.fromOffset(12, 66),
		BackgroundTransparency = 1,
		Parent = frame,
	}) :: Frame
	local window: Window = { Name = name, Frame = frame, Content = content }
	windows[name] = window
	return window
end

function UI.GetWindow(name: string): Window?
	return windows[name]
end

function UI.IsOpen(name: string): boolean
	return openName == name
end

function UI.Close(name: string?)
	local target = name or openName
	if not target then
		return
	end
	local window = windows[target]
	if window and window.Frame.Visible then
		window.Frame.Visible = false
		if window.OnClose then
			window.OnClose()
		end
	end
	if openName == target then
		openName = nil
		ContextActionService:UnbindAction("CloseWindow")
		GuiService.SelectedObject = nil
	end
end

function UI.Open(name: string)
	local window = windows[name]
	if not window then
		return
	end
	if openName and openName ~= name then
		UI.Close(openName)
	end
	openName = name
	local frame = window.Frame
	frame.Visible = true
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	scale.Scale = 0.85
	UI.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	if window.OnOpen then
		window.OnOpen()
	end
	ContextActionService:BindActionAtPriority("CloseWindow", function(_, state)
		if state == Enum.UserInputState.Begin then
			UI.Close(name)
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)
	task.defer(function()
		local first = frame:FindFirstChildWhichIsA("GuiButton", true)
		if first and GuiService:IsTenFootInterface() then
			GuiService.SelectedObject = first
		end
	end)
end

function UI.Toggle(name: string)
	if openName == name then
		UI.Close(name)
	else
		UI.Open(name)
	end
end

-- Scrolling list/grid container
function UI.Scroller(props: Props): ScrollingFrame
	local defaults: Props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Pink,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("ScrollingFrame", defaults)
end

-- Tab bar + one content page per tab. Returns pages by key and a select function.
function UI.Tabs(parent: Instance, tabs: { { Key: string, Text: string, Color: Color3? } }, onSelect: ((string) -> ())?): ({ [string]: Frame }, (string) -> ())
	local bar = UI.new("Frame", {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		List = { Direction = Enum.FillDirection.Horizontal, Gap = 8, HAlign = Enum.HorizontalAlignment.Left },
		Parent = parent,
	})
	local pages: { [string]: Frame } = {}
	local buttons: { [string]: TextButton } = {}
	local function select(key: string)
		for tabKey, page in pages do
			page.Visible = tabKey == key
			local button = buttons[tabKey]
			if button then
				button.BackgroundTransparency = if tabKey == key then 0 else 0.45
			end
		end
		if onSelect then
			onSelect(key)
		end
	end
	for index, tab in tabs do
		buttons[tab.Key] = UI.Button({
			Name = tab.Key,
			Text = tab.Text,
			Size = UDim2.fromOffset(math.max(110, #tab.Text * 16 + 30), 40),
			BackgroundColor3 = tab.Color or Theme.Colors.Sky,
			LayoutOrder = index,
			TextMax = 22,
			OnActivated = function()
				select(tab.Key)
			end,
			Parent = bar,
		})
		pages[tab.Key] = UI.new("Frame", {
			Name = tab.Key .. "Page",
			Size = UDim2.new(1, 0, 1, -52),
			Position = UDim2.fromOffset(0, 52),
			BackgroundTransparency = 1,
			Visible = index == 1,
			Parent = parent,
		})
	end
	return pages, select
end

-- Card with a title, body text and an action button (used across shops)
function UI.Card(props: Props): (Frame, TextButton)
	local card = UI.new("Frame", {
		Name = props.Name or "Card",
		Size = props.Size or UDim2.fromOffset(220, 230),
		BackgroundColor3 = props.Color or Theme.Colors.PanelLight,
		Corner = true,
		Stroke = { Thickness = 3, Border = true },
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UI.Text({ Name = "Title", Text = props.Title or "", Font = Theme.Fonts.Heading, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 6), TextMax = 26, TextColor3 = props.TitleColor or Theme.Colors.White, Parent = card })
	UI.Text({ Name = "Body", Text = props.Body or "", Size = UDim2.new(1, -16, 1, -100), Position = UDim2.fromOffset(8, 42), TextMax = 18, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	local button = UI.Button({
		Name = "Action",
		Text = props.ButtonText or "BUY",
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.new(0, 8, 1, -52),
		BackgroundColor3 = props.ButtonColor or Theme.Colors.Green,
		TextMax = 24,
		OnActivated = props.OnActivated,
		Parent = card,
	})
	return card, button
end

-- Simple confirm dialog; calls back with true/false
function UI.Confirm(title: string, body: string, confirmText: string?, callback: (boolean) -> ())
	local window = windows["Confirm"] or UI.Window("Confirm", title, UDim2.fromOffset(520, 300), Theme.Colors.Purple)
	local content = window.Content
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	local titleLabel = window.Frame:FindFirstChild("TitleBar") and (window.Frame :: any).TitleBar:FindFirstChild("Title")
	if titleLabel then
		titleLabel.Text = title
	end
	UI.Text({
		Text = body,
		Size = UDim2.new(1, 0, 0.6, 0),
		TextWrapped = true,
		TextMax = 24,
		Parent = content,
	})
	local done = false
	local function finish(result: boolean)
		if done then
			return
		end
		done = true
		UI.Close("Confirm")
		callback(result)
	end
	window.OnClose = function()
		finish(false)
	end
	UI.Button({
		Text = confirmText or "Confirm",
		Size = UDim2.new(0.45, 0, 0.3, 0),
		Position = UDim2.fromScale(0.03, 0.68),
		BackgroundColor3 = Theme.Colors.Green,
		OnActivated = function()
			finish(true)
		end,
		Parent = content,
	})
	UI.Button({
		Text = "Cancel",
		Size = UDim2.new(0.45, 0, 0.3, 0),
		Position = UDim2.fromScale(0.52, 0.68),
		BackgroundColor3 = Theme.Colors.PanelLight,
		OnActivated = function()
			finish(false)
		end,
		Parent = content,
	})
	UI.Open("Confirm")
end

return UI
