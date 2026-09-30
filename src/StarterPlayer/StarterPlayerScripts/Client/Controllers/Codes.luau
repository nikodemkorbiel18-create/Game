--!strict
-- Codes window (sidebar or the Codes Board in Station Plaza).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local HUD = require(script.Parent.HUD)

local Codes = {}

function Codes.Init()
	local window = UI.Window("Codes", "CODES", UDim2.fromOffset(560, 320), Theme.Colors.Green)
	local box = UI.new("TextBox", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 20),
		BackgroundColor3 = Theme.Colors.Paper,
		TextColor3 = Theme.Colors.Ink,
		PlaceholderText = "Enter a code",
		PlaceholderColor3 = Theme.Colors.Muted,
		Font = Theme.Fonts.Heading,
		TextScaled = true,
		ClearTextOnFocus = false,
		Text = "",
		Corner = true,
		Stroke = { Thickness = 3, Border = true },
		Parent = window.Content,
	}) :: TextBox
	local status = UI.Text({ Text = "Follow the game for new codes!", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 90), TextMax = 20, TextColor3 = Theme.Colors.Muted, Parent = window.Content })
	UI.Button({
		Text = "REDEEM",
		Size = UDim2.new(0.6, 0, 0, 54),
		Position = UDim2.new(0.2, 0, 0, 150),
		BackgroundColor3 = Theme.Colors.Green,
		OnActivated = function()
			local ok, result = pcall(function()
				return Net.Function("RedeemCode"):InvokeServer(box.Text)
			end)
			if ok and type(result) == "table" then
				status.Text = tostring(result.Message or "")
				status.TextColor3 = if result.Ok then Theme.Colors.Green else Theme.Colors.Red
				if result.Ok then
					box.Text = ""
				end
			end
		end,
		Parent = window.Content,
	})
end

function Codes.Start()
	HUD.AddSidebarButton("Codes", "CODES", Theme.Colors.Green, function()
		UI.Open("Codes")
	end, 6)
	local function add(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("KioskPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "KioskPrompt"
		prompt.ActionText = "Redeem Codes"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			UI.Open("Codes")
		end)
		prompt.Parent = part
	end
	for _, part in CollectionService:GetTagged("CodesBoard") do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("CodesBoard"):Connect(add)
end

return Codes
