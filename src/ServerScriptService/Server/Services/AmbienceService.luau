--!strict
-- Overhead name tags (rebirth title, gold VIP tag) and saving player settings.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local Remote = require(script.Parent.Parent.Lib.Remote)
local Guard = require(script.Parent.Parent.Lib.Guard)

local AmbienceService = {}

local function nameTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild("NameTag")
	if existing then
		existing:Destroy()
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local vip = PassService.Owns(player, "VIP")
	local title = player:GetAttribute("Title")
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Text = (if vip then "[VIP] " else "") .. player.DisplayName
	nameLabel.TextColor3 = if vip then Color3.fromRGB(255, 211, 77) else Color3.fromRGB(255, 255, 255)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = nameLabel
	nameLabel.Parent = gui
	if type(title) == "string" and title ~= "" then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.Size = UDim2.fromScale(1, 0.42)
		titleLabel.Position = UDim2.fromScale(0, 0.56)
		titleLabel.Font = Enum.Font.Bangers
		titleLabel.TextScaled = true
		titleLabel.Text = title
		titleLabel.TextColor3 = Color3.fromRGB(255, 158, 207)
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Thickness = 2
		titleStroke.Parent = titleLabel
		titleLabel.Parent = gui
	end
	gui.Parent = head
end

function AmbienceService.Init()
	Remote.OnEvent("SaveSettings", function(player, settings)
		local data = DataService.Get(player)
		if not data or type(settings) ~= "table" then
			return
		end
		local music = Guard.Number(settings.Music, 0, 1)
		local sfx = Guard.Number(settings.Sfx, 0, 1)
		local low = Guard.Boolean(settings.LowGraphics)
		local hide = Guard.Boolean(settings.HideTrails)
		if music then
			data.Settings.Music = music
		end
		if sfx then
			data.Settings.Sfx = sfx
		end
		if low ~= nil then
			data.Settings.LowGraphics = low
		end
		if hide ~= nil then
			data.Settings.HideTrails = hide
		end
		DataService.Changed(player, "Settings")
	end, 4)
end

function AmbienceService.Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			nameTag(player)
		end)
		player:GetAttributeChangedSignal("Title"):Connect(function()
			nameTag(player)
		end)
		if player.Character then
			nameTag(player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	PassService.Changed:Connect(function(player, key)
		if key == "VIP" then
			nameTag(player)
		end
	end)
end

return AmbienceService
