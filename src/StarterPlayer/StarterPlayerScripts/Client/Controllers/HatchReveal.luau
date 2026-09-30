--!strict
-- The anime hatch reveal (~3s): egg shakes -> cracks with light seams -> white flash ->
-- diagonal manga cut-in with speed lines and the character portrait -> name banner slams in
-- with rarity, size, kg and mutation -> catchphrase. Cosmic+ adds screen-edge sparkles.
-- Skippable after the first time you hatch a character. Reveals queue while you're out
-- on a run and play when you're back home.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local Net = require(Shared.Net)
local EggBuilder = require(Shared.Visual.EggBuilder)
local CharacterBuilder = require(Shared.Visual.CharacterBuilder)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local Sound = require(script.Parent.Sound)
local Notifications = require(script.Parent.Notifications)

local player = Players.LocalPlayer

local HatchReveal = {}

local queue: { any } = {}
local playing = false
local screen: ScreenGui

local function inZone(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, part in CollectionService:GetTagged("Zone") do
		if part:IsA("BasePart") then
			local localPoint = part.CFrame:PointToObjectSpace(root.Position)
			local half = part.Size / 2
			if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function canPlay(): boolean
	return player:GetAttribute("Carrying") ~= true and not inZone() and not UI.IsOpen("Shop")
end

local function speedLines(parent: Instance, color: Color3)
	for index = 1, 26 do
		local angle = (index / 26) * 360 + math.random(-6, 6)
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9, 0, 0, math.random(3, 9)),
			Rotation = angle,
			BackgroundColor3 = if index % 3 == 0 then color else Theme.Colors.White,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = parent,
		})
	end
end

local function sparkles(parent: Instance, color: Color3)
	for _ = 1, 24 do
		local edge = math.random(1, 4)
		local x = if edge == 1 then 0.02 elseif edge == 2 then 0.98 else math.random()
		local y = if edge == 3 then 0.03 elseif edge == 4 then 0.97 else math.random()
		local star = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(18, 18),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = parent,
		})
		task.spawn(function()
			for _ = 1, 3 do
				UI.Tween(star, 0.4, { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0 })
				task.wait(0.4)
				UI.Tween(star, 0.4, { Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 0.6 })
				task.wait(0.4)
			end
		end)
	end
end

local function play(payload: any)
	playing = true
	local item = payload.Item
	local character = Characters.Get(item.CharacterId)
	local rarity = Rarities.Get(Formulas.DisplayRarity(item))
	local size = Sizes.Get(item.SizeTier)
	local mutation = Mutations.Get(item.Mutation)
	local color = Theme.Rarity(rarity.Id)
	local skippable = payload.FirstTime ~= true
	local skipped = false

	local root = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UI.Tween(root, 0.25, { BackgroundTransparency = 0.35 })

	local skipConnection: RBXScriptConnection? = nil
	if skippable then
		UI.Text({ Text = "Click / tap to skip", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -40), TextMax = 18, TextColor3 = Theme.Colors.Muted, ZIndex = 30, Parent = root })
		skipConnection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
				skipped = true
			end
		end)
	end
	local function wait(seconds: number): boolean
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			if skipped then
				return false
			end
			task.wait()
		end
		return not skipped
	end

	-- 1. egg shakes and cracks
	local eggModel = EggBuilder.Build({ CharacterId = item.CharacterId, SizeTier = 3, Mutation = item.Mutation, Color = item.Color, EggModel = item.EggModel, Awakened = item.Awakened }, 1)
	local eggView = UI.Viewport(eggModel, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.5),
		ZIndex = 3,
		Parent = root,
	})
	Sound.Play("EggCrack", 0.8)
	local shakeStart = os.clock()
	local crackCount = 0
	while os.clock() - shakeStart < 1.1 and not skipped do
		local t = os.clock() - shakeStart
		eggView.Rotation = math.sin(t * (20 + t * 30)) * (4 + t * 14)
		if t > 0.35 * (crackCount + 1) and crackCount < 3 then
			crackCount += 1
			Sound.Play("EggCrack", 1 + crackCount * 0.15)
			UI.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.08, 0.5 + (math.random() - 0.5) * 0.15),
				Size = UDim2.fromOffset(6, 90),
				Rotation = math.random(-50, 50),
				BackgroundColor3 = Theme.Colors.White,
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = root,
			})
		end
		task.wait()
	end

	-- 2. flash
	local flash = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Colors.White, BackgroundTransparency = 1, ZIndex = 10, Parent = root })
	UI.Tween(flash, 0.12, { BackgroundTransparency = 0 })
	Sound.Play("Whoosh")
	wait(0.14)
	eggView:Destroy()
	for _, child in root:GetChildren() do
		if child:IsA("Frame") and child ~= flash and child.ZIndex == 4 then
			child:Destroy()
		end
	end
	UI.Tween(flash, 0.35, { BackgroundTransparency = 1 })

	-- 3. manga cut-in
	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.6, 0.45),
		Size = UDim2.fromScale(1.3, 0.5),
		Rotation = -8,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
		Gradient = Theme.RarityGradient(rarity.Id),
		GradientRotation = 0,
		Stroke = { Thickness = 6, Border = true },
		Parent = root,
	})
	speedLines(panel, color)
	local portrait = CharacterBuilder.Build(item.CharacterId, { Scale = 1, Mutation = item.Mutation, Awakened = item.Awakened })
	UI.Viewport(portrait, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 1.2),
		Rotation = 8,
		ZIndex = 5,
		Parent = panel,
	})
	UI.Tween(panel, 0.3, { Position = UDim2.fromScale(0.5, 0.45) }, Enum.EasingStyle.Back)
	if rarity.Rank >= 7 then
		sparkles(root, color)
	end
	wait(0.35)

	-- 4. name banner slam
	local banner = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromScale(0.6, 0.16),
		BackgroundColor3 = Theme.Colors.Ink,
		Corner = UDim.new(0, 14),
		Stroke = { Color = color, Thickness = 5, Border = true },
		ZIndex = 12,
		Parent = root,
	})
	local bannerScale = Instance.new("UIScale")
	bannerScale.Scale = 2.2
	bannerScale.Parent = banner
	UI.Text({ Text = string.upper(rarity.DisplayName) .. (if item.Awakened then " ★ AWAKENED" else ""), Font = Theme.Fonts.Heading, TextColor3 = Theme.RarityText(rarity.Id), Size = UDim2.new(1, -20, 0.34, 0), Position = UDim2.fromScale(0, 0.02), TextMax = 30, ZIndex = 13, Parent = banner })
	UI.Text({ Text = character.DisplayName, Font = Theme.Fonts.Heading, Size = UDim2.new(1, -20, 0.4, 0), Position = UDim2.fromScale(0, 0.32), TextMax = 52, ZIndex = 13, Parent = banner })
	UI.Text({
		Text = string.format("%s · %s%s · %s", size.DisplayName, NumberFormat.Kg(item.Kg), if mutation then " · " .. mutation.DisplayName else "", NumberFormat.PerSecond(Formulas.ItemIncome(item))),
		Size = UDim2.new(1, -20, 0.24, 0),
		Position = UDim2.fromScale(0, 0.74),
		TextColor3 = Theme.Colors.Muted,
		TextMax = 22,
		ZIndex = 13,
		Parent = banner,
	})
	UI.Tween(bannerScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	Sound.Play("Reveal")
	if item.Lucky then
		local stamp = UI.Text({
			Text = "LUCKY!",
			Font = Theme.Fonts.Heading,
			TextColor3 = Theme.Colors.Gold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.78, 0.22),
			Size = UDim2.fromScale(0.22, 0.12),
			Rotation = 14,
			TextMax = 80,
			ZIndex = 25,
			Stroke = { Thickness = 5 },
			Parent = root,
		})
		local stampScale = Instance.new("UIScale")
		stampScale.Scale = 3
		stampScale.Parent = stamp
		UI.Tween(stampScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	wait(1.0)

	-- 5. catchphrase
	if #character.Catchphrases > 0 then
		local bubble = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.72, 0.28),
			Size = UDim2.fromScale(0.26, 0.1),
			BackgroundColor3 = Theme.Colors.Paper,
			Corner = UDim.new(0, 20),
			Stroke = { Thickness = 3, Border = true },
			ZIndex = 15,
			Parent = root,
		})
		UI.Text({ Text = character.Catchphrases[1], Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), TextColor3 = Theme.Colors.Ink, Stroke = { Thickness = 0, Transparency = 1 }, TextWrapped = true, TextMax = 24, ZIndex = 16, Parent = bubble })
	end
	wait(1.6)

	if skipConnection then
		skipConnection:Disconnect()
	end
	UI.Tween(root, 0.25, { BackgroundTransparency = 1 })
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			UI.Tween(descendant, 0.25, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.28)
	root:Destroy()
	playing = false
end

local function pump()
	if playing or #queue == 0 then
		return
	end
	if not canPlay() then
		return
	end
	local payload = table.remove(queue, 1)
	task.spawn(function()
		local ok, err = pcall(function(): nil
			play(payload)
			return nil
		end)
		if not ok then
			warn("[HatchReveal] " .. tostring(err))
			playing = false
		end
		task.wait(0.3)
		pump()
	end)
end

function HatchReveal.Init()
	screen = UI.Screen("HatchReveal", 50, true)
end

function HatchReveal.Start()
	Net.Event("HatchReveal").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Item) ~= "table" then
			return
		end
		local character = Characters.Find(payload.Item.CharacterId)
		if not character then
			return
		end
		table.insert(queue, payload)
		if #queue > 8 then
			table.remove(queue, 1)
		end
		if not canPlay() then
			Notifications.Toast(character.DisplayName .. " hatched! Head home to see the reveal.", "Reward")
		end
		pump()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pump()
		end
	end)
end

return HatchReveal
