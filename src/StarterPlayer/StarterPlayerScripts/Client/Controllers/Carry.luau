--!strict
-- The carry card: what you're holding (rarity, name or ???, size, kg, mutation, speed
-- penalty) plus a Store button when you carry your own item inside your base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local Net = require(Shared.Net)
local UI = require(script.Parent.Parent.UI.UI)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local Carry = {}

local card: Frame
local rarityBar: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local detailLabel: TextLabel
local penaltyLabel: TextLabel
local storeButton: TextButton

local function discovered(characterId: string): boolean
	local index = State.Get("Index")
	local entry = if type(index) == "table" then index[characterId] else nil
	return entry ~= nil and entry.Discovered == true
end

local function refresh()
	local carrying = player:GetAttribute("Carrying") == true
	card.Visible = carrying
	if not carrying then
		return
	end
	local characterId = player:GetAttribute("CarryCharacterId")
	if type(characterId) ~= "string" or not Characters.Find(characterId) then
		return
	end
	local character = Characters.Get(characterId)
	local rarityId = player:GetAttribute("CarryRarity")
	local rarity = Rarities.ById[if type(rarityId) == "string" then rarityId else character.Rarity] or Rarities.Get(character.Rarity)
	local sizeTier = player:GetAttribute("CarrySizeTier")
	local size = Sizes.Get(if type(sizeTier) == "number" then sizeTier else 3)
	local kg = player:GetAttribute("CarryKg")
	local mutation = Mutations.Get(player:GetAttribute("CarryMutation"))
	local kind = player:GetAttribute("CarryKind")
	rarityBar.BackgroundColor3 = Theme.Rarity(rarity.Id)
	local gradient = rarityBar:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = Theme.RarityGradient(rarity.Id)
	end
	rarityLabel.Text = string.upper(rarity.DisplayName) .. (if player:GetAttribute("CarryAwakened") then " ★" else "") .. (if kind == "Egg" then " EGG" else "")
	rarityLabel.TextColor3 = Theme.RarityText(rarity.Id)
	local known = discovered(characterId) or kind == "Character"
	nameLabel.Text = if known then character.DisplayName else "???"
	local details = string.format("%s · %s", size.DisplayName, NumberFormat.Kg(if type(kg) == "number" then kg else 0))
	if mutation then
		details ..= " · " .. mutation.DisplayName
	end
	local remaining = player:GetAttribute("CarryHatchRemaining")
	if kind == "Egg" and type(remaining) == "number" then
		details ..= " · " .. TimeFormat.Short(remaining) .. " to hatch"
	end
	detailLabel.Text = details
	local penalty = math.floor((1 - size.Carry) * 100 + 0.5)
	penaltyLabel.Text = string.format("SPEED -%d%%%s", penalty, if size.Jump == 0 then " · NO JUMP" elseif size.Jump < 1 then " · LOW JUMP" else "")
	local origin = player:GetAttribute("CarryOrigin")
	storeButton.Visible = origin == "Own"
end

function Carry.Init()
	local screen = UI.Screen("CarryCard", 6)
	card = UI.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(380, 118),
		BackgroundColor3 = Theme.Colors.Panel,
		Corner = UDim.new(0, 16),
		Stroke = { Thickness = 3, Border = true },
		Visible = false,
		Parent = screen,
	})
	rarityBar = UI.new("Frame", {
		Name = "RarityBar",
		Size = UDim2.new(0, 14, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Colors.White,
		Corner = UDim.new(1, 0),
		Gradient = ColorSequence.new(Theme.Colors.White),
		Parent = card,
	})
	rarityLabel = UI.Text({ Text = "", Font = Theme.Fonts.Heading, Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(32, 6), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 24, Parent = card })
	nameLabel = UI.Text({ Text = "", Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(32, 32), TextXAlignment = Enum.TextXAlignment.Left, TextMax = 26, Parent = card })
	detailLabel = UI.Text({ Text = "", Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(32, 62), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Muted, TextMax = 18, Parent = card })
	penaltyLabel = UI.Text({ Text = "", Font = Theme.Fonts.Heading, Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.fromOffset(32, 86), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Red, TextMax = 22, Parent = card })
	storeButton = UI.Button({
		Text = "STORE",
		Size = UDim2.fromOffset(110, 36),
		Position = UDim2.new(1, -120, 1, -44),
		BackgroundColor3 = Theme.Colors.Sky,
		Visible = false,
		OnActivated = function()
			Net.Event("StoreCarried"):FireServer()
		end,
		Parent = card,
	})
end

function Carry.Start()
	for _, attribute in { "Carrying", "CarryCharacterId", "CarryRarity", "CarrySizeTier", "CarryKg", "CarryMutation", "CarryOrigin", "CarryHatchRemaining" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if player:GetAttribute("Carrying") then
			Sound.Play("Grab")
		end
	end)
	State.OnChange("Index", refresh)
	refresh()
end

return Carry
