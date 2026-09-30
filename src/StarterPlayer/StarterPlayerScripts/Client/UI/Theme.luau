--!strict
-- Visual language: bold outlined manga type, ink outlines, paper panels, halftone accents.

local Rarities = require(game:GetService("ReplicatedStorage").Shared.Config.Rarities)

local Theme = {
	Fonts = {
		Heading = Enum.Font.Bangers,
		Body = Enum.Font.FredokaOne,
		Number = Enum.Font.LuckiestGuy,
	},
	Colors = {
		Ink = Color3.fromRGB(27, 27, 47),
		Paper = Color3.fromRGB(255, 248, 240),
		PaperDark = Color3.fromRGB(240, 228, 214),
		Panel = Color3.fromRGB(46, 42, 72),
		PanelLight = Color3.fromRGB(66, 60, 102),
		Pink = Color3.fromRGB(255, 92, 138),
		Sky = Color3.fromRGB(90, 200, 250),
		Gold = Color3.fromRGB(255, 211, 77),
		Green = Color3.fromRGB(76, 217, 100),
		Red = Color3.fromRGB(255, 71, 87),
		Purple = Color3.fromRGB(162, 89, 255),
		White = Color3.fromRGB(255, 255, 255),
		Muted = Color3.fromRGB(170, 164, 196),
		Shadow = Color3.fromRGB(0, 0, 0),
	},
	Corner = UDim.new(0, 14),
	Stroke = 3,
}

function Theme.Rarity(id: string): Color3
	local rarity = Rarities.ById[id]
	return if rarity then Color3.fromHex(rarity.Color) else Theme.Colors.White
end

function Theme.RarityGradient(id: string): ColorSequence
	local rarity = Rarities.ById[id]
	if not rarity then
		return ColorSequence.new(Theme.Colors.White)
	end
	local first = Color3.fromHex(rarity.Color)
	if rarity.Id == "Eternal" then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#FF9ECF")),
			ColorSequenceKeypoint.new(0.33, Color3.fromHex("#FFE08A")),
			ColorSequenceKeypoint.new(0.66, Color3.fromHex("#8FE3FF")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#C8B6FF")),
		})
	end
	return ColorSequence.new(first, if rarity.Color2 then Color3.fromHex(rarity.Color2) else first)
end

-- Text readable on top of a rarity color (Secret is black)
function Theme.RarityText(id: string): Color3
	if id == "Secret" then
		return Color3.fromHex("#7CFF4F")
	end
	return Theme.Rarity(id)
end

return Theme
