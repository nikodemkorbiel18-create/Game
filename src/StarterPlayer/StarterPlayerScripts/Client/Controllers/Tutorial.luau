--!strict
-- Tutorial guide: step card with a Skip button, a beam from you to the next goal and a
-- floating marker over it. Steps are advanced by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local Tutorial = {}

local card: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local marker: Part
local markerAttachment: Attachment
local beam: Beam

local function attachBeam()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = root:FindFirstChild("TutorialAttachment") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "TutorialAttachment"
		created.Parent = root
		attachment = created
	end
	beam.Attachment0 = attachment
end

local function show(payload: any)
	if payload.Done then
		card.Visible = false
		beam.Enabled = false
		marker.Parent = nil
		return
	end
	card.Visible = true
	stepLabel.Text = string.format("TUTORIAL  %d / %d", payload.Step or 1, payload.Total or 6)
	textLabel.Text = tostring(payload.Text or "")
	Sound.Play("Reveal")
	if typeof(payload.Target) == "Vector3" then
		marker.CFrame = CFrame.new(payload.Target + Vector3.new(0, 4, 0))
		marker.Parent = workspace
		attachBeam()
		beam.Enabled = true
	else
		marker.Parent = nil
		beam.Enabled = false
	end
end

function Tutorial.Init()
	local screen = UI.Screen("Tutorial", 9)
	card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(620, 96),
		BackgroundColor3 = Theme.Colors.Paper,
		Corner = UDim.new(0, 18),
		Stroke = { Thickness = 3, Border = true },
		Visible = false,
		Parent = screen,
	})
	stepLabel = UI.Text({ Text = "", Font = Theme.Fonts.Heading, TextColor3 = Theme.Colors.Pink, Size = UDim2.new(1, -130, 0, 28), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 24, Parent = card })
	textLabel = UI.Text({ Text = "", TextColor3 = Theme.Colors.Ink, Stroke = { Thickness = 0, Transparency = 1 }, Size = UDim2.new(1, -28, 0, 54), Position = UDim2.fromOffset(14, 36), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextMax = 20, Parent = card })
	UI.Button({
		Text = "SKIP",
		Size = UDim2.fromOffset(100, 34),
		Position = UDim2.new(1, -112, 0, 8),
		BackgroundColor3 = Theme.Colors.PanelLight,
		TextMax = 18,
		OnActivated = function()
			Net.Event("TutorialAction"):FireServer("Skip")
		end,
		Parent = card,
	})
	marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	markerAttachment = Instance.new("Attachment")
	markerAttachment.Parent = marker
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 80)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = marker
	UI.Text({ Text = "▼", Font = Theme.Fonts.Heading, TextColor3 = Theme.Colors.Pink, Size = UDim2.fromScale(1, 1), TextMax = 80, Stroke = { Thickness = 4 }, Parent = gui })
	beam = Instance.new("Beam")
	beam.Attachment1 = markerAttachment
	beam.Color = ColorSequence.new(Theme.Colors.Pink, Theme.Colors.Gold)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 4
	beam.TextureSpeed = 2
	beam.Enabled = false
	beam.Parent = marker
end

function Tutorial.Start()
	Net.Event("Tutorial").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			show(payload)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		attachBeam()
	end)
	task.delay(2, function()
		Net.Event("TutorialAction"):FireServer("Sync")
	end)
end

return Tutorial
