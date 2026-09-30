--!strict
-- A card showing one egg or character: 3D preview, name (or ??? if undiscovered),
-- rarity, size/kg/mutation, income or hatch time, a Protected lock and action buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local NumberFormat = require(Shared.Util.NumberFormat)
local TimeFormat = require(Shared.Util.TimeFormat)
local EggBuilder = require(Shared.Visual.EggBuilder)
local CharacterBuilder = require(Shared.Visual.CharacterBuilder)
local UI = require(script.Parent.UI)
local Theme = require(script.Parent.Theme)

local ItemCard = {}

export type Button = { Text: string, Color: Color3?, OnActivated: () -> () }

export type Options = {
	Parent: Instance,
	LayoutOrder: number?,
	Known: boolean?,
	Income: number?, -- effective $/s to show
	Subtitle: string?, -- overrides the income line
	Buttons: { Button }?,
	Selected: boolean?,
	OnSelect: (() -> ())?,
	Silhouette: boolean?,
}

function ItemCard.Preview(item: any, silhouette: boolean?): Model
	if item.Kind == "Egg" then
		return EggBuilder.Build({
			CharacterId = item.CharacterId,
			SizeTier = 3,
			Mutation = item.Mutation,
			Color = item.Color,
			EggModel = item.EggModel,
			Awakened = item.Awakened,
		}, 1)
	end
	return CharacterBuilder.Build(item.CharacterId, {
		Scale = 1,
		Mutation = if silhouette then nil else item.Mutation,
		Awakened = item.Awakened,
		Silhouette = silhouette,
		NoEffects = true,
	})
end

function ItemCard.Build(item: any, options: Options): GuiObject
	local character = Characters.Get(item.CharacterId)
	local rarityId = Formulas.DisplayRarity(item)
	local rarity = Rarities.Get(rarityId)
	local size = Sizes.Get(item.SizeTier or 3)
	local mutation = Mutations.Get(item.Mutation)
	local known = options.Known ~= false or item.Kind == "Character"
	local buttons: { Button } = if options.Buttons then options.Buttons else {}
	local height = 196 + #buttons * 40
	local card = UI.new("TextButton", {
		Name = "Card",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(170, height),
		BackgroundColor3 = if options.Selected then Theme.Colors.Gold else Theme.Colors.PanelLight,
		LayoutOrder = options.LayoutOrder or 0,
		Corner = true,
		Stroke = { Color = Theme.Rarity(rarityId), Thickness = 3, Border = true },
		Selectable = options.OnSelect ~= nil,
		Parent = options.Parent,
	}) :: TextButton
	if options.OnSelect then
		local onSelect = options.OnSelect
		card.Activated:Connect(function()
			onSelect()
		end)
	end
	UI.Viewport(ItemCard.Preview(item, options.Silhouette), {
		Size = UDim2.new(1, -12, 0, 96),
		Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		Parent = card,
	})
	UI.Text({
		Text = string.upper(rarity.DisplayName) .. (if item.Awakened then " ★" else "") .. (if item.Kind == "Egg" then " EGG" else ""),
		Font = Theme.Fonts.Heading,
		TextColor3 = Theme.RarityText(rarityId),
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(5, 102),
		TextMax = 18,
		Parent = card,
	})
	UI.Text({
		Text = if known then character.DisplayName else "???",
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(5, 122),
		TextMax = 17,
		Parent = card,
	})
	UI.Text({
		Text = string.format("%s · %s%s", size.DisplayName, NumberFormat.Kg(item.Kg or 0), if mutation then " · " .. mutation.DisplayName else ""),
		Size = UDim2.new(1, -10, 0, 16),
		Position = UDim2.fromOffset(5, 144),
		TextColor3 = if mutation then Color3.fromHex(mutation.Color) else Theme.Colors.Muted,
		TextMax = 14,
		Parent = card,
	})
	local subtitle = options.Subtitle
	if not subtitle then
		if item.Kind == "Egg" then
			local remaining = if item.HatchEndsAt then item.HatchEndsAt - workspace:GetServerTimeNow() elseif item.HatchRemaining then item.HatchRemaining else Formulas.HatchTime(item)
			subtitle = "Hatch: " .. TimeFormat.Short(remaining)
		else
			subtitle = NumberFormat.PerSecond(options.Income or Formulas.ItemIncome(item))
		end
	end
	UI.Text({
		Text = subtitle,
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(5, 162),
		TextColor3 = if item.Kind == "Egg" then Theme.Colors.Gold else Theme.Colors.Green,
		TextMax = 17,
		Parent = card,
	})
	if item.Protected then
		UI.Text({ Text = "LOCK", Font = Theme.Fonts.Heading, Size = UDim2.fromOffset(44, 20), Position = UDim2.fromOffset(6, 6), TextColor3 = Theme.Colors.Gold, TextMax = 16, Parent = card })
	end
	if item.Lucky then
		UI.Text({ Text = "LUCKY", Font = Theme.Fonts.Heading, Size = UDim2.fromOffset(54, 20), Position = UDim2.new(1, -60, 0, 6), TextColor3 = Theme.Colors.Gold, TextMax = 16, Parent = card })
	end
	for index, button in buttons do
		UI.Button({
			Text = button.Text,
			Size = UDim2.new(1, -12, 0, 34),
			Position = UDim2.fromOffset(6, 190 + (index - 1) * 40),
			BackgroundColor3 = button.Color or Theme.Colors.Sky,
			TextMax = 18,
			OnActivated = button.OnActivated,
			Parent = card,
		})
	end
	return card
end

return ItemCard
