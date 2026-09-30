--!strict
-- Placeholder props made of primitives. Each prop is a list of parts positioned relative
-- to an anchor on the character body (see CharacterBuilder for anchor positions).
-- Units are studs at scale 1 (a chibi is ~5 studs tall). The character faces -Z.
-- Color may be a palette key (Skin, Hair, Outfit, Outfit2, Accent, Eyes) or a hex string.

export type PropPart = {
	Anchor: string,
	Shape: string, -- Block | Ball | Cylinder | Wedge | Sphere (ellipsoid)
	Size: { number },
	Offset: { number },
	Rot: { number }?, -- degrees
	Color: string,
	Material: string?,
	Transparency: number?,
}

type Extra = { Rot: { number }?, Material: string?, Transparency: number? }

local function P(anchor: string, shape: string, size: { number }, offset: { number }, color: string, extra: Extra?): PropPart
	return {
		Anchor = anchor,
		Shape = shape,
		Size = size,
		Offset = offset,
		Color = color,
		Rot = extra and extra.Rot,
		Material = extra and extra.Material,
		Transparency = extra and extra.Transparency,
	}
end

local NEON = { Material = "Neon" }
local WHITE = "#FFFFFF"
local BLACK = "#1B1B1E"
local GOLD = "#FFD34D"
local WOOD = "#9C6B3E"
local METAL = "#ADB5BD"

local Props: { [string]: { PropPart } } = {}

-- Zone 1
Props.SchoolBag = {
	P("RightHand", "Block", { 1.0, 0.8, 0.35 }, { 0.15, -0.15, -0.15 }, "Accent"),
	P("RightHand", "Block", { 0.12, 0.5, 0.1 }, { 0.15, 0.4, -0.15 }, BLACK),
}
Props.Pillow = { P("LeftHand", "Sphere", { 1.7, 0.9, 0.8 }, { 0.3, 0.5, -0.35 }, WHITE) }
Props.DroolBubble = { P("Face", "Ball", { 0.45, 0.45, 0.45 }, { 0.35, -0.35, -0.15 }, "#BDE0FE", { Transparency = 0.35 }) }
Props.Armband = { P("LeftHand", "Block", { 0.55, 0.25, 0.6 }, { 0.05, 0.8, 0.15 }, "Accent") }
Props.GiantBento = {
	P("Root", "Block", { 1.9, 1.0, 1.4 }, { 0, 2.0, -0.95 }, "Accent"),
	P("Root", "Block", { 1.95, 0.15, 1.45 }, { 0, 2.35, -0.95 }, BLACK),
	P("Root", "Sphere", { 0.55, 0.5, 0.45 }, { 0.35, 2.65, -0.95 }, WHITE),
}
Props.RoundGlasses = {
	P("Face", "Cylinder", { 0.08, 0.6, 0.6 }, { 0.42, 0.05, -0.06 }, "Eyes", { Rot = { 0, 90, 0 }, Transparency = 0.55 }),
	P("Face", "Cylinder", { 0.08, 0.6, 0.6 }, { -0.42, 0.05, -0.06 }, "Eyes", { Rot = { 0, 90, 0 }, Transparency = 0.55 }),
}
Props.BookTower = {
	P("Root", "Block", { 1.1, 0.3, 0.8 }, { 0, 1.35, -0.85 }, "Accent"),
	P("Root", "Block", { 1.0, 0.3, 0.8 }, { 0.05, 1.65, -0.85 }, "Outfit2"),
	P("Root", "Block", { 1.1, 0.3, 0.8 }, { -0.05, 1.95, -0.85 }, "#E76F51"),
	P("Root", "Block", { 0.95, 0.3, 0.8 }, { 0, 2.25, -0.85 }, "#2A9D8F"),
	P("Root", "Block", { 1.05, 0.3, 0.8 }, { 0.05, 2.55, -0.85 }, "#E9C46A"),
}
Props.LongCoat = {
	P("Root", "Block", { 1.7, 2.0, 0.2 }, { 0, 1.3, 0.5 }, "Outfit"),
	P("Root", "Block", { 0.45, 2.0, 0.2 }, { 0.6, 1.3, -0.5 }, "Outfit"),
	P("Root", "Block", { 0.45, 2.0, 0.2 }, { -0.6, 1.3, -0.5 }, "Outfit"),
}
Props.CheekBandage = { P("Face", "Block", { 0.4, 0.18, 0.05 }, { 0.6, -0.25, 0.08 }, WHITE) }
Props.Clipboard = {
	P("LeftHand", "Block", { 0.8, 1.0, 0.1 }, { 0, 0.3, -0.3 }, WOOD),
	P("LeftHand", "Block", { 0.68, 0.8, 0.05 }, { 0, 0.25, -0.37 }, WHITE),
}

-- Zone 2
Props.Scooter = {
	P("Root", "Block", { 0.7, 0.2, 2.4 }, { 0, 0.15, 0 }, "Accent"),
	P("Root", "Block", { 0.15, 1.9, 0.15 }, { 0, 1.1, -1.1 }, METAL),
	P("Root", "Block", { 1.3, 0.12, 0.12 }, { 0, 2.05, -1.1 }, BLACK),
	P("Root", "Cylinder", { 0.25, 0.55, 0.55 }, { 0, 0.25, 1.1 }, BLACK),
	P("Root", "Cylinder", { 0.25, 0.55, 0.55 }, { 0, 0.25, -1.1 }, BLACK),
}
Props.RamenBox = {
	P("Back", "Block", { 1.2, 1.0, 0.9 }, { 0, 0.3, 0.35 }, "#E63946"),
	P("Back", "Block", { 1.0, 0.4, 0.05 }, { 0, 0.3, 0.82 }, WHITE),
}
Props.BigHeadset = {
	P("Head", "Block", { 2.7, 0.25, 0.35 }, { 0, 1.1, 0 }, "Accent"),
	P("Head", "Cylinder", { 0.45, 1.1, 1.1 }, { 1.25, 0, 0 }, "Outfit"),
	P("Head", "Cylinder", { 0.45, 1.1, 1.1 }, { -1.25, 0, 0 }, "Outfit"),
	P("Head", "Block", { 0.1, 0.1, 0.8 }, { -1.1, -0.45, -0.6 }, BLACK),
}
Props.Headband = { P("Head", "Cylinder", { 0.3, 2.42, 2.42 }, { 0, 0.45, 0 }, "Outfit2", { Rot = { 0, 0, 90 } }) }
Props.Wok = {
	P("RightHand", "Sphere", { 1.4, 0.5, 1.4 }, { 0.35, 0.2, -0.3 }, BLACK),
	P("RightHand", "Block", { 0.15, 0.15, 1.0 }, { 0.35, 0.25, 0.5 }, WOOD),
}
Props.HoloVisor = { P("Face", "Block", { 2.0, 0.45, 0.2 }, { 0, 0.15, -0.02 }, "Accent", { Material = "Neon", Transparency = 0.3 }) }
Props.StreamingScarf = {
	P("Root", "Cylinder", { 0.45, 1.65, 1.65 }, { 0, 2.3, 0 }, "Accent", { Rot = { 0, 0, 90 } }),
	P("Root", "Block", { 0.5, 0.18, 1.3 }, { 0.3, 2.35, 1.2 }, "Accent", { Rot = { 0, 10, 0 } }),
	P("Root", "Block", { 0.5, 0.18, 1.3 }, { 0.5, 2.5, 2.4 }, "Accent", { Rot = { 0, 20, 5 } }),
	P("Root", "Block", { 0.5, 0.18, 1.3 }, { 0.85, 2.7, 3.55 }, "Accent", { Rot = { 0, 30, 10 } }),
	P("Root", "Block", { 0.5, 0.18, 1.3 }, { 1.35, 2.95, 4.6 }, "Accent", { Rot = { 0, 40, 15 } }),
}
Props.Goggles = {
	P("Head", "Cylinder", { 0.22, 2.42, 2.42 }, { 0, 0.6, 0 }, BLACK, { Rot = { 0, 0, 90 } }),
	P("Head", "Cylinder", { 0.25, 0.6, 0.6 }, { 0.45, 0.6, -1.05 }, "#8ECAE6", { Rot = { 0, 90, 0 }, Material = "Glass" }),
	P("Head", "Cylinder", { 0.25, 0.6, 0.6 }, { -0.45, 0.6, -1.05 }, "#8ECAE6", { Rot = { 0, 90, 0 }, Material = "Glass" }),
}
Props.GiantChopsticks = {
	P("RightHand", "Block", { 0.15, 5.2, 0.15 }, { 0.1, 1.3, -0.1 }, "#DDB892", { Rot = { 0, 0, -6 } }),
	P("RightHand", "Block", { 0.15, 5.2, 0.15 }, { 0.35, 1.3, 0.05 }, "#DDB892", { Rot = { 0, 0, -10 } }),
}
Props.LongBeard = { P("Face", "Wedge", { 1.0, 1.3, 0.4 }, { 0, -0.95, 0.1 }, WHITE, { Rot = { 0, 180, 180 } }) }

-- Zone 3
Props.BambooBroom = {
	P("RightHand", "Block", { 0.15, 3.8, 0.15 }, { 0.1, 0.8, -0.1 }, "#A3B18A"),
	P("RightHand", "Block", { 0.85, 0.75, 0.35 }, { 0.1, -1.15, -0.1 }, "#DDB892"),
}
Props.PaperCharms = {
	P("RightHand", "Block", { 0.35, 0.7, 0.05 }, { 0.1, 0.35, -0.35 }, WHITE, { Rot = { 0, 0, -15 } }),
	P("RightHand", "Block", { 0.35, 0.7, 0.05 }, { 0.3, 0.4, -0.35 }, WHITE),
	P("RightHand", "Block", { 0.25, 0.1, 0.06 }, { 0.3, 0.45, -0.39 }, "Outfit2"),
	P("Root", "Block", { 0.35, 0.7, 0.05 }, { -1.4, 3.3, -0.6 }, WHITE, { Rot = { 0, 20, 10 } }),
	P("Root", "Block", { 0.35, 0.7, 0.05 }, { 1.5, 3.8, 0.2 }, WHITE, { Rot = { 0, -30, -10 } }),
	P("Root", "Block", { 0.35, 0.7, 0.05 }, { -1.2, 2.3, 0.9 }, WHITE, { Rot = { 0, 60, 5 } }),
}
Props.LeafOnHead = { P("HeadTop", "Sphere", { 1.1, 0.12, 0.65 }, { 0, 0.1, 0 }, "Accent", { Rot = { 0, 30, 15 } }) }
Props.TanukiTail = {
	P("Root", "Sphere", { 0.85, 0.85, 1.7 }, { 0, 1.0, 0.95 }, "Outfit"),
	P("Root", "Sphere", { 0.65, 0.65, 0.45 }, { 0, 1.05, 1.7 }, "Outfit2"),
}
Props.RoundEars = {
	P("Head", "Ball", { 0.75, 0.75, 0.75 }, { 0.8, 0.95, 0 }, "Hair"),
	P("Head", "Ball", { 0.75, 0.75, 0.75 }, { -0.8, 0.95, 0 }, "Hair"),
}
Props.UmbrellaTop = { P("HeadTop", "Cylinder", { 0.12, 0.55, 0.55 }, { 0, 0.5, 0 }, "Accent", { Rot = { 0, 90, 0 } }) }
Props.Tongue = { P("Face", "Sphere", { 0.45, 0.15, 0.7 }, { 0, -0.55, -0.1 }, "#FF6B8B", { Rot = { 30, 0, 0 } }) }
Props.FoxEars = {
	P("Head", "Wedge", { 0.25, 0.9, 0.7 }, { 0.65, 1.2, 0 }, "Hair", { Rot = { 0, 0, -15 } }),
	P("Head", "Wedge", { 0.25, 0.9, 0.7 }, { -0.65, 1.2, 0 }, "Hair", { Rot = { 0, 0, 15 } }),
	P("Head", "Wedge", { 0.1, 0.55, 0.45 }, { 0.65, 1.15, -0.08 }, "Accent", { Rot = { 0, 0, -15 } }),
	P("Head", "Wedge", { 0.1, 0.55, 0.45 }, { -0.65, 1.15, -0.08 }, "Accent", { Rot = { 0, 0, 15 } }),
}
Props.NineTails = {}
for index = 1, 9 do
	local angle = math.rad(-80 + (index - 1) * 20)
	table.insert(
		Props.NineTails,
		P("Root", "Sphere", { 0.6, 0.6, 2.0 }, { math.sin(angle) * 1.2, 1.3 + math.cos(angle) * 0.9, 1.3 }, "Accent", {
			Rot = { -35, math.deg(angle) * 0.5, 0 },
			Material = "Neon",
			Transparency = 0.15,
		})
	)
end
Props.CrescentSpear = {
	P("RightHand", "Block", { 0.15, 4.6, 0.15 }, { 0.1, 1.2, -0.1 }, METAL),
	P("RightHand", "Cylinder", { 0.12, 1.2, 1.2 }, { 0.1, 3.7, -0.1 }, "Accent", { Rot = { 0, 90, 0 }, Material = "Neon" }),
	P("RightHand", "Cylinder", { 0.14, 1.0, 1.0 }, { 0.1, 3.85, -0.1 }, "Outfit", { Rot = { 0, 90, 0 } }),
}
Props.MoonCrest = { P("Face", "Cylinder", { 0.06, 0.45, 0.45 }, { 0, 0.85, 0.05 }, "Accent", { Rot = { 0, 90, 0 }, Material = "Neon" }) }

-- Zone 4
Props.Blindfold = { P("Head", "Cylinder", { 0.35, 2.42, 2.42 }, { 0, 0, 0 }, WHITE, { Rot = { 0, 0, 90 } }) }
Props.BambooStick = { P("RightHand", "Block", { 0.18, 3.4, 0.18 }, { 0.1, 1.2, -0.3 }, "#A3B18A", { Rot = { -20, 0, 0 } }) }
Props.Watermelon = {
	P("LeftHand", "Ball", { 1.3, 1.3, 1.3 }, { -0.1, 0.1, -0.4 }, "#2D6A4F"),
	P("LeftHand", "Cylinder", { 0.2, 1.32, 1.32 }, { -0.1, 0.1, -0.4 }, "#95D5B2", { Rot = { 0, 0, 90 } }),
}
Props.Surfboard = {
	P("Back", "Sphere", { 1.1, 3.6, 0.25 }, { 0.2, 0.6, 0.3 }, "Accent", { Rot = { 0, 0, 12 } }),
	P("Back", "Sphere", { 0.3, 3.0, 0.27 }, { 0.2, 0.6, 0.3 }, WHITE, { Rot = { 0, 0, 12 } }),
}
Props.BucketHelmet = {
	P("HeadTop", "Cylinder", { 1.2, 1.9, 1.9 }, { 0, 0.15, 0 }, "Outfit", { Rot = { 0, 0, 90 } }),
	P("HeadTop", "Cylinder", { 0.15, 2.05, 2.05 }, { 0, 0.75, 0 }, "Outfit2", { Rot = { 0, 0, 90 } }),
}
Props.Shovel = {
	P("RightHand", "Block", { 0.14, 1.6, 0.14 }, { 0.1, 0.3, -0.2 }, WOOD),
	P("RightHand", "Block", { 0.6, 0.6, 0.1 }, { 0.1, -0.7, -0.2 }, "Accent"),
}
Props.CrabHat = {
	P("HeadTop", "Sphere", { 2.0, 0.8, 1.6 }, { 0, 0.1, 0 }, "Accent"),
	P("HeadTop", "Ball", { 0.35, 0.35, 0.35 }, { 0.45, 0.55, -0.6 }, WHITE),
	P("HeadTop", "Ball", { 0.35, 0.35, 0.35 }, { -0.45, 0.55, -0.6 }, WHITE),
	P("HeadTop", "Ball", { 0.18, 0.18, 0.18 }, { 0.45, 0.58, -0.75 }, BLACK),
	P("HeadTop", "Ball", { 0.18, 0.18, 0.18 }, { -0.45, 0.58, -0.75 }, BLACK),
}
Props.ClawMittens = {
	P("RightHand", "Wedge", { 0.55, 0.7, 0.6 }, { 0.05, 0.1, -0.15 }, "Accent", { Rot = { 0, 0, 20 } }),
	P("RightHand", "Wedge", { 0.55, 0.7, 0.6 }, { 0.05, -0.35, -0.15 }, "Accent", { Rot = { 180, 0, -20 } }),
	P("LeftHand", "Wedge", { 0.55, 0.7, 0.6 }, { -0.05, 0.1, -0.15 }, "Accent", { Rot = { 0, 0, -20 } }),
	P("LeftHand", "Wedge", { 0.55, 0.7, 0.6 }, { -0.05, -0.35, -0.15 }, "Accent", { Rot = { 180, 0, 20 } }),
}
Props.Ukulele = {
	P("Root", "Sphere", { 0.8, 1.0, 0.3 }, { 0.2, 1.3, -0.6 }, WOOD, { Rot = { 0, 0, -40 } }),
	P("Root", "Block", { 0.16, 1.2, 0.12 }, { 0.75, 1.95, -0.6 }, "#6F4E37", { Rot = { 0, 0, -40 } }),
}
Props.FlowerHairpin = {
	P("Head", "Ball", { 0.55, 0.55, 0.55 }, { 0.95, 0.6, -0.3 }, "Accent"),
	P("Head", "Ball", { 0.22, 0.22, 0.22 }, { 1.05, 0.62, -0.5 }, GOLD),
}
Props.WaveMount = {
	P("Root", "Sphere", { 3.2, 1.2, 3.2 }, { 0, 0.3, 0.2 }, "Outfit2", { Material = "Glass", Transparency = 0.25 }),
	P("Root", "Sphere", { 1.2, 2.6, 1.0 }, { 0, 1.4, 1.5 }, "Outfit", { Rot = { -30, 0, 0 }, Material = "Glass", Transparency = 0.2 }),
	P("Root", "Sphere", { 1.0, 0.8, 1.6 }, { 0, 2.9, 1.2 }, WHITE, { Rot = { 20, 0, 0 } }),
}
Props.Tiara = {
	P("HeadTop", "Cylinder", { 0.15, 1.2, 1.2 }, { 0, -0.05, -0.2 }, "Accent", { Rot = { 0, 0, 90 }, Material = "Neon" }),
	P("HeadTop", "Ball", { 0.3, 0.3, 0.3 }, { 0, 0.15, -0.75 }, "#48CAE4", { Material = "Neon" }),
}

-- Zone 5
Props.OversizedHeadband = {
	P("Head", "Cylinder", { 0.45, 2.45, 2.45 }, { 0, 0.5, 0 }, "Accent", { Rot = { 0, 0, 90 } }),
	P("Head", "Block", { 0.9, 0.45, 0.1 }, { 0, 0.5, -1.22 }, METAL),
	P("Head", "Block", { 0.35, 0.3, 2.2 }, { 0.3, 0.2, 2.0 }, "Accent", { Rot = { 20, 10, 0 } }),
	P("Head", "Block", { 0.35, 0.3, 2.2 }, { -0.3, 0.1, 2.0 }, "Accent", { Rot = { 25, -10, 0 } }),
}
Props.SmokePuffs = {
	P("Root", "Ball", { 1.2, 1.2, 1.2 }, { 1.6, 0.6, 0.4 }, "#CED4DA", { Transparency = 0.35 }),
	P("Root", "Ball", { 0.9, 0.9, 0.9 }, { -1.7, 0.5, 0.2 }, "#CED4DA", { Transparency = 0.35 }),
	P("Root", "Ball", { 0.7, 0.7, 0.7 }, { 0.2, 0.35, 1.3 }, "#CED4DA", { Transparency = 0.35 }),
}
Props.GiantScroll = {
	P("Back", "Cylinder", { 3.2, 1.0, 1.0 }, { 0, 0.6, 0.55 }, "Accent", { Rot = { 0, 0, 30 } }),
	P("Back", "Cylinder", { 0.25, 1.2, 1.2 }, { -1.4, -0.2, 0.55 }, "Outfit2", { Rot = { 0, 0, 30 } }),
	P("Back", "Cylinder", { 0.25, 1.2, 1.2 }, { 1.4, 1.4, 0.55 }, "Outfit2", { Rot = { 0, 0, 30 } }),
}
Props.RainCloak = {
	P("Root", "Wedge", { 2.0, 2.4, 1.4 }, { 0, 1.35, 0.25 }, "Outfit", { Rot = { 0, 180, 0 } }),
	P("Head", "Sphere", { 2.6, 1.6, 2.5 }, { 0, 0.45, 0.2 }, "Outfit"),
}
Props.SheathedBlade = {
	P("Back", "Block", { 0.22, 3.2, 0.25 }, { 0.2, 0.4, 0.2 }, BLACK, { Rot = { 0, 0, 35 } }),
	P("Back", "Block", { 0.6, 0.12, 0.3 }, { -0.6, 1.5, 0.2 }, GOLD, { Rot = { 0, 0, 35 } }),
}
Props.PaperKite = {
	P("Back", "Block", { 3.4, 3.4, 0.08 }, { 0, 2.2, 0.8 }, "Outfit", { Rot = { 0, 0, 45 } }),
	P("Back", "Block", { 2.2, 2.2, 0.1 }, { 0, 2.2, 0.85 }, "Outfit2", { Rot = { 0, 0, 45 } }),
	P("Back", "Ball", { 0.8, 0.8, 0.12 }, { 0, 2.2, 0.9 }, "Accent"),
}
Props.OniMask = {
	P("Face", "Sphere", { 1.9, 1.7, 0.4 }, { 0, 0.05, -0.05 }, "Accent"),
	P("Face", "Wedge", { 0.25, 0.6, 0.3 }, { 0.55, 0.95, 0 }, WHITE),
	P("Face", "Wedge", { 0.25, 0.6, 0.3 }, { -0.55, 0.95, 0 }, WHITE),
	P("Face", "Block", { 0.9, 0.12, 0.1 }, { 0, -0.45, -0.25 }, WHITE),
}
Props.ClanCape = { P("Back", "Block", { 2.0, 2.4, 0.15 }, { 0, -0.2, 0.15 }, "Outfit2", { Rot = { 8, 0, 0 } }) }

-- Zone 6
Props.SpinRibbons = {
	P("RightHand", "Block", { 0.1, 0.1, 2.5 }, { 0.3, 0.6, 0.6 }, "Outfit2", { Rot = { 30, 30, 0 }, Material = "Neon" }),
	P("LeftHand", "Block", { 0.1, 0.1, 2.5 }, { -0.3, 0.9, 0.6 }, "Accent", { Rot = { 50, -30, 0 }, Material = "Neon" }),
}
Props.Glowsticks = {
	P("RightHand", "Cylinder", { 1.4, 0.2, 0.2 }, { 0.1, 0.7, -0.1 }, "Outfit2", { Rot = { 0, 0, 90 }, Material = "Neon" }),
	P("LeftHand", "Cylinder", { 1.4, 0.2, 0.2 }, { -0.1, 0.7, -0.1 }, "Accent", { Rot = { 0, 0, 90 }, Material = "Neon" }),
}
Props.FestivalCoat = {
	P("Root", "Block", { 1.75, 1.5, 1.0 }, { 0, 1.55, 0 }, "Outfit"),
	P("Root", "Block", { 1.8, 0.3, 1.05 }, { 0, 0.85, 0 }, "Outfit2"),
}
Props.HeartMic = {
	P("RightHand", "Block", { 0.14, 0.9, 0.14 }, { 0.05, 0.2, -0.2 }, WHITE),
	P("RightHand", "Ball", { 0.55, 0.55, 0.55 }, { 0.05, 0.8, -0.2 }, "Accent", { Material = "Neon" }),
}
Props.HeartClips = {
	P("Head", "Ball", { 0.4, 0.4, 0.4 }, { 0.95, 0.55, -0.4 }, "Accent"),
	P("Head", "Ball", { 0.4, 0.4, 0.4 }, { -0.95, 0.55, -0.4 }, "Accent"),
}
Props.LightningSticks = {
	P("RightHand", "Block", { 0.14, 1.5, 0.14 }, { 0.05, 0.6, -0.2 }, "Outfit2", { Rot = { -30, 0, 0 }, Material = "Neon" }),
	P("LeftHand", "Block", { 0.14, 1.5, 0.14 }, { -0.05, 0.6, -0.2 }, "Accent", { Rot = { -30, 0, 0 }, Material = "Neon" }),
}
Props.HoloGlitch = {
	P("Root", "Block", { 0.5, 0.5, 0.05 }, { 1.4, 3.6, -0.3 }, "Accent", { Material = "Neon", Transparency = 0.3 }),
	P("Root", "Block", { 0.3, 0.3, 0.05 }, { -1.5, 2.8, -0.2 }, "Accent", { Material = "Neon", Transparency = 0.3 }),
	P("Root", "Block", { 0.4, 0.2, 0.05 }, { 1.2, 1.4, 0.4 }, "Outfit", { Material = "Neon", Transparency = 0.3 }),
}
Props.HoloRing = { P("Root", "Cylinder", { 0.1, 3.2, 3.2 }, { 0, 0.15, 0 }, "Accent", { Rot = { 0, 0, 90 }, Material = "Neon", Transparency = 0.4 }) }
Props.StarCape = {
	P("Back", "Wedge", { 2.2, 2.6, 0.5 }, { 0, -0.3, 0.3 }, "Outfit2", { Rot = { 0, 180, 0 } }),
	P("Back", "Ball", { 0.3, 0.3, 0.3 }, { 0.5, 0.2, 0.62 }, WHITE, NEON),
	P("Back", "Ball", { 0.25, 0.25, 0.25 }, { -0.4, -0.6, 0.7 }, WHITE, NEON),
	P("Back", "Ball", { 0.2, 0.2, 0.2 }, { 0.1, -1.1, 0.75 }, WHITE, NEON),
}
Props.Spotlight = { P("Root", "Cylinder", { 8, 3.2, 3.2 }, { 0, 4, 0 }, "#FFF3B0", { Rot = { 0, 0, 90 }, Material = "Neon", Transparency = 0.85 }) }
Props.StarCrown = {
	P("HeadTop", "Cylinder", { 0.3, 1.3, 1.3 }, { 0, 0.05, 0 }, GOLD, { Rot = { 0, 0, 90 } }),
	P("HeadTop", "Wedge", { 0.2, 0.55, 0.3 }, { 0, 0.45, -0.55 }, GOLD),
	P("HeadTop", "Ball", { 0.3, 0.3, 0.3 }, { 0, 0.4, -0.7 }, "Accent", NEON),
}

-- Zone 7
Props.Wrench = {
	P("RightHand", "Block", { 0.16, 1.4, 0.16 }, { 0.05, 0.3, -0.2 }, METAL),
	P("RightHand", "Block", { 0.5, 0.35, 0.16 }, { 0.05, 1.0, -0.2 }, METAL),
}
Props.OilSmudge = { P("Face", "Sphere", { 0.45, 0.25, 0.05 }, { -0.55, -0.3, 0.08 }, BLACK, { Transparency = 0.2 }) }
Props.FlightPatch = { P("Root", "Cylinder", { 0.05, 0.5, 0.5 }, { -0.45, 1.8, -0.47 }, "Accent", { Rot = { 0, 90, 0 } }) }
Props.PilotHeadset = {
	P("Head", "Cylinder", { 0.25, 2.42, 2.42 }, { 0, 0.75, 0 }, BLACK, { Rot = { 0, 0, 90 } }),
	P("Head", "Block", { 0.1, 0.1, 0.9 }, { 1.15, -0.35, -0.6 }, BLACK),
}
Props.OrbitDrones = {}
for index = 1, 4 do
	local angle = math.rad(index * 90)
	table.insert(Props.OrbitDrones, P("Root", "Block", { 0.6, 0.18, 0.6 }, { math.cos(angle) * 1.9, 3.8 + (index % 2) * 0.4, math.sin(angle) * 1.9 }, "Accent"))
	table.insert(Props.OrbitDrones, P("Root", "Ball", { 0.2, 0.2, 0.2 }, { math.cos(angle) * 1.9, 3.65 + (index % 2) * 0.4, math.sin(angle) * 1.9 }, "#FF0054", NEON))
end
Props.Controller = { P("RightHand", "Block", { 0.8, 0.3, 0.5 }, { -0.4, 0.2, -0.35 }, BLACK) }
Props.AceVisor = { P("Face", "Sphere", { 2.1, 0.55, 0.3 }, { 0, 0.2, -0.05 }, "#FFBA08", { Material = "Glass", Transparency = 0.2 }) }
Props.WingBadge = {
	P("Root", "Wedge", { 0.05, 0.25, 0.5 }, { -0.62, 1.95, -0.47 }, GOLD, { Rot = { 0, 90, 0 } }),
	P("Root", "Wedge", { 0.05, 0.25, 0.5 }, { -0.2, 1.95, -0.47 }, GOLD, { Rot = { 0, -90, 0 } }),
}
Props.Greatcoat = {
	P("Root", "Block", { 1.8, 2.2, 1.05 }, { 0, 1.2, 0 }, "Outfit"),
	P("Root", "Block", { 0.5, 0.2, 0.6 }, { 0.8, 2.3, 0 }, "Outfit2"),
	P("Root", "Block", { 0.5, 0.2, 0.6 }, { -0.8, 2.3, 0 }, "Outfit2"),
}
Props.MechArm = {
	P("RightHand", "Block", { 0.65, 1.4, 0.65 }, { 0, 0.5, 0 }, METAL, { Material = "DiamondPlate" }),
	P("RightHand", "Ball", { 0.7, 0.7, 0.7 }, { 0, -0.25, 0 }, "#4361EE", NEON),
}
Props.AdmiralCap = {
	P("HeadTop", "Cylinder", { 0.5, 2.0, 2.0 }, { 0, 0.05, 0 }, WHITE, { Rot = { 0, 0, 90 } }),
	P("HeadTop", "Block", { 1.2, 0.1, 0.5 }, { 0, -0.25, -0.95 }, BLACK),
	P("HeadTop", "Block", { 0.5, 0.3, 0.05 }, { 0, 0.05, -1.0 }, GOLD),
}
Props.MiniMechSuit = {}

-- Zone 8
Props.Necktie = { P("Root", "Wedge", { 0.3, 0.8, 0.1 }, { 0, 1.75, -0.5 }, "Accent", { Rot = { 0, 0, 180 } }) }
Props.FantasyArmor = {
	P("Root", "Block", { 1.55, 1.1, 1.0 }, { 0, 1.7, 0 }, "Outfit", { Material = "Metal" }),
	P("Root", "Ball", { 0.7, 0.7, 0.7 }, { 0.85, 2.15, 0 }, "Outfit2", { Material = "Metal" }),
	P("Root", "Ball", { 0.7, 0.7, 0.7 }, { -0.85, 2.15, 0 }, "Outfit2", { Material = "Metal" }),
}
Props.LeafSprout = {
	P("HeadTop", "Block", { 0.1, 0.5, 0.1 }, { 0, 0.2, 0 }, "#2D6A4F"),
	P("HeadTop", "Sphere", { 0.7, 0.1, 0.4 }, { 0.3, 0.45, 0 }, "#52B788", { Rot = { 0, 0, 20 } }),
	P("HeadTop", "Sphere", { 0.7, 0.1, 0.4 }, { -0.3, 0.45, 0 }, "#52B788", { Rot = { 0, 0, -20 } }),
}
Props.ElfEars = {
	P("Head", "Wedge", { 0.2, 0.45, 1.0 }, { 1.15, 0.1, 0 }, "Skin", { Rot = { 0, 90, 20 } }),
	P("Head", "Wedge", { 0.2, 0.45, 1.0 }, { -1.15, 0.1, 0 }, "Skin", { Rot = { 0, -90, -20 } }),
}
Props.VineBow = {
	P("LeftHand", "Cylinder", { 0.12, 2.6, 2.6 }, { -0.1, 0.4, -0.2 }, "Accent", { Rot = { 0, 0, 0 } }),
	P("LeftHand", "Block", { 0.05, 2.5, 0.05 }, { -0.1, 0.4, 0.3 }, WHITE),
}
Props.QuestBoard = {
	P("Root", "Block", { 1.8, 1.4, 0.15 }, { 0, 1.7, -0.75 }, WOOD),
	P("Root", "Block", { 0.5, 0.6, 0.05 }, { -0.45, 1.8, -0.84 }, "#FAF3DD"),
	P("Root", "Block", { 0.5, 0.5, 0.05 }, { 0.3, 1.6, -0.84 }, "#FAF3DD"),
	P("Root", "Block", { 0.4, 0.4, 0.05 }, { 0.5, 2.1, -0.84 }, "#FFD6A5"),
}
Props.Ribbon = {
	P("Head", "Wedge", { 0.2, 0.6, 0.6 }, { 0.35, 0.95, 0.6 }, "Outfit2", { Rot = { 0, 90, 0 } }),
	P("Head", "Wedge", { 0.2, 0.6, 0.6 }, { -0.35, 0.95, 0.6 }, "Outfit2", { Rot = { 0, -90, 0 } }),
}
Props.GlowSword = {
	P("RightHand", "Block", { 0.25, 3.0, 0.1 }, { 0.1, 1.6, -0.25 }, "#BDE0FE", { Material = "Neon" }),
	P("RightHand", "Block", { 0.9, 0.18, 0.25 }, { 0.1, 0.1, -0.25 }, GOLD),
}
Props.HeroCape = { P("Back", "Wedge", { 2.0, 2.6, 0.3 }, { 0, -0.35, 0.25 }, "Outfit2", { Rot = { 0, 180, 0 } }) }
Props.FoldingFan = {
	P("RightHand", "Wedge", { 0.08, 0.9, 1.0 }, { 0.2, 0.9, -0.4 }, "Accent", { Rot = { 0, 90, 0 } }),
	P("RightHand", "Wedge", { 0.08, 0.9, 1.0 }, { -0.2, 0.9, -0.4 }, "Accent", { Rot = { 0, -90, 0 } }),
}

-- Zone 9
Props.ImpHorns = {
	P("Head", "Wedge", { 0.25, 0.7, 0.35 }, { 0.5, 1.15, -0.2 }, "Accent"),
	P("Head", "Wedge", { 0.25, 0.7, 0.35 }, { -0.5, 1.15, -0.2 }, "Accent"),
}
Props.TeaTray = {
	P("RightHand", "Cylinder", { 0.1, 1.4, 1.4 }, { 0.2, 0.9, -0.3 }, METAL, { Rot = { 0, 0, 90 } }),
	P("RightHand", "Cylinder", { 0.4, 0.4, 0.4 }, { 0.2, 1.15, -0.3 }, WHITE, { Rot = { 0, 0, 90 } }),
}
Props.ImpWings = {
	P("Back", "Wedge", { 0.1, 0.8, 1.2 }, { 0.7, 0.4, 0.3 }, "Accent", { Rot = { 0, 70, 0 } }),
	P("Back", "Wedge", { 0.1, 0.8, 1.2 }, { -0.7, 0.4, 0.3 }, "Accent", { Rot = { 0, -70, 0 } }),
}
Props.LaceParasol = {
	P("LeftHand", "Block", { 0.1, 3.0, 0.1 }, { 0, 1.2, 0 }, BLACK),
	P("LeftHand", "Sphere", { 2.8, 0.6, 2.8 }, { 0, 2.7, 0 }, "Accent", { Transparency = 0.15 }),
}
Props.VampCollar = {
	P("Root", "Wedge", { 0.9, 0.9, 0.15 }, { 0.5, 2.55, 0.25 }, "Outfit2", { Rot = { 0, 180, -20 } }),
	P("Root", "Wedge", { 0.9, 0.9, 0.15 }, { -0.5, 2.55, 0.25 }, "Outfit2", { Rot = { 0, 180, 20 } }),
}
Props.JaggedArmor = {
	P("Root", "Block", { 1.6, 1.3, 1.05 }, { 0, 1.65, 0 }, "Outfit", { Material = "Slate" }),
	P("Root", "Wedge", { 0.5, 0.8, 0.6 }, { 0.95, 2.4, 0 }, "Outfit2", { Material = "Slate" }),
	P("Root", "Wedge", { 0.5, 0.8, 0.6 }, { -0.95, 2.4, 0 }, "Outfit2", { Material = "Slate" }),
	P("Root", "Ball", { 0.4, 0.4, 0.4 }, { 0, 1.8, -0.55 }, "Accent", NEON),
}
Props.BigCrown = {
	P("HeadTop", "Cylinder", { 0.9, 2.2, 2.2 }, { 0, 0.2, 0 }, GOLD, { Rot = { 0, 0, 90 } }),
	P("HeadTop", "Wedge", { 0.3, 0.7, 0.3 }, { 0, 0.95, -1.0 }, GOLD),
	P("HeadTop", "Wedge", { 0.3, 0.7, 0.3 }, { 0.8, 0.95, -0.55 }, GOLD),
	P("HeadTop", "Wedge", { 0.3, 0.7, 0.3 }, { -0.8, 0.95, -0.55 }, GOLD),
	P("HeadTop", "Ball", { 0.35, 0.35, 0.35 }, { 0, 0.3, -1.12 }, "#FF0054", NEON),
}
Props.SmallHorns = {
	P("Head", "Wedge", { 0.2, 0.5, 0.3 }, { 0.55, 1.05, 0 }, BLACK),
	P("Head", "Wedge", { 0.2, 0.5, 0.3 }, { -0.55, 1.05, 0 }, BLACK),
}
Props.TwoToneWings = {
	P("Back", "Wedge", { 0.15, 2.4, 2.2 }, { 1.4, 0.8, 0.4 }, BLACK, { Rot = { 0, 60, 0 } }),
	P("Back", "Wedge", { 0.15, 2.4, 2.2 }, { -1.4, 0.8, 0.4 }, WHITE, { Rot = { 0, -60, 0 } }),
}
Props.CrackedHalo = {
	P("HeadTop", "Cylinder", { 0.12, 1.5, 1.5 }, { 0.1, 0.55, 0 }, "Accent", { Rot = { 0, 0, 80 }, Material = "Neon" }),
}
Props.BigHorns = {
	P("Head", "Wedge", { 0.35, 1.3, 0.5 }, { 0.75, 1.35, 0 }, "#E9D8A6", { Rot = { 0, 0, -25 } }),
	P("Head", "Wedge", { 0.35, 1.3, 0.5 }, { -0.75, 1.35, 0 }, "#E9D8A6", { Rot = { 0, 0, 25 } }),
}
Props.ThroneCape = {
	P("Back", "Block", { 2.6, 3.4, 0.25 }, { 0, 0.8, 0.3 }, "Outfit2"),
	P("Back", "Wedge", { 0.5, 0.8, 0.25 }, { 1.05, 2.8, 0.3 }, "Accent"),
	P("Back", "Wedge", { 0.5, 0.8, 0.25 }, { -1.05, 2.8, 0.3 }, "Accent"),
}

-- Zone 10
Props.StarOar = {
	P("RightHand", "Block", { 0.15, 4.4, 0.15 }, { 0.1, 1.1, -0.1 }, WOOD),
	P("RightHand", "Sphere", { 0.7, 1.4, 0.15 }, { 0.1, -1.4, -0.1 }, "Accent", { Material = "Neon" }),
}
Props.FerrymanHat = { P("HeadTop", "Cylinder", { 0.6, 3.2, 3.2 }, { 0, 0.0, 0 }, "#D6CCC2", { Rot = { 0, 0, 90 } }) }
Props.BigScythe = {
	P("RightHand", "Block", { 0.16, 4.6, 0.16 }, { 0.1, 1.3, -0.1 }, "#6C584C"),
	P("RightHand", "Wedge", { 0.1, 0.9, 2.2 }, { 0.1, 3.3, -1.1 }, "Accent", { Rot = { 0, 0, 0 } }),
}
Props.DrumRing = {}
for index = 1, 6 do
	local angle = math.rad(index * 60)
	table.insert(
		Props.DrumRing,
		P("Root", "Cylinder", { 0.5, 0.9, 0.9 }, { math.cos(angle) * 1.9, 3.1, math.sin(angle) * 1.9 }, "Accent", { Rot = { 0, -index * 60, 0 } })
	)
end
table.insert(Props.DrumRing, P("Root", "Cylinder", { 0.15, 4.2, 4.2 }, { 0, 3.1, 0 }, "#E9D8A6", { Rot = { 0, 0, 90 }, Transparency = 0.6 }))
Props.OniHorn = { P("HeadTop", "Wedge", { 0.3, 0.8, 0.35 }, { 0, 0.2, -0.3 }, "#FFFFFF") }
Props.DragonCompanion = {}
for index = 1, 6 do
	local t = index / 6
	table.insert(
		Props.DragonCompanion,
		P("Root", "Ball", { 0.8 - t * 0.35, 0.8 - t * 0.35, 0.8 - t * 0.35 }, { math.cos(t * 5) * 2.0, 1.2 + t * 3.0, math.sin(t * 5) * 2.0 }, "Outfit2")
	)
end
table.insert(Props.DragonCompanion, P("Root", "Ball", { 0.2, 0.2, 0.2 }, { math.cos(5 / 6) * 2.0 - 0.2, 1.8, math.sin(5 / 6) * 2.0 - 0.35 }, "Accent", NEON))
Props.DragonHorns = {
	P("Head", "Wedge", { 0.15, 0.7, 0.3 }, { 0.5, 1.15, 0.2 }, "Accent", { Rot = { -25, 0, 0 } }),
	P("Head", "Wedge", { 0.15, 0.7, 0.3 }, { -0.5, 1.15, 0.2 }, "Accent", { Rot = { -25, 0, 0 } }),
}
Props.MoonDisc = {
	P("Head", "Cylinder", { 0.1, 3.2, 3.2 }, { 0, 0.3, 0.9 }, "Accent", { Rot = { 0, 90, 0 }, Material = "Neon", Transparency = 0.2 }),
	P("Head", "Cylinder", { 0.12, 2.6, 2.6 }, { 0.35, 0.4, 0.88 }, "#E0E1DD", { Rot = { 0, 90, 0 } }),
}

-- Zone 11
Props.FloatingBlades = {}
for index = 1, 7 do
	local angle = math.rad(-90 + (index - 1) * 30)
	table.insert(
		Props.FloatingBlades,
		P("Root", "Block", { 0.18, 2.0, 0.08 }, { math.sin(angle) * 2.2, 3.2 + math.cos(angle) * 1.4, 0.8 }, "#E0FBFC", {
			Rot = { 0, 0, -math.deg(angle) },
			Material = "Neon",
		})
	)
end
Props.GalaxyTrain = {
	P("Back", "Wedge", { 2.6, 0.2, 4.2 }, { 0, -1.55, 1.8 }, "Outfit", { Rot = { 0, 0, 0 } }),
	P("Back", "Ball", { 0.25, 0.25, 0.25 }, { 0.6, -1.4, 2.4 }, WHITE, NEON),
	P("Back", "Ball", { 0.2, 0.2, 0.2 }, { -0.5, -1.45, 3.0 }, "#8FE3FF", NEON),
	P("Back", "Ball", { 0.2, 0.2, 0.2 }, { 0.2, -1.45, 3.6 }, GOLD, NEON),
}
Props.PetalSwirl = {}
for index = 1, 10 do
	local angle = math.rad(index * 36)
	table.insert(
		Props.PetalSwirl,
		P("Root", "Sphere", { 0.45, 0.08, 0.3 }, { math.cos(angle) * 1.8, 0.8 + index * 0.35, math.sin(angle) * 1.8 }, "#FFB7C5", {
			Rot = { 20, index * 36, 30 },
			Material = "Neon",
		})
	)
end

-- Festival
Props.Yukata = {
	P("Root", "Block", { 1.6, 2.0, 1.05 }, { 0, 1.2, 0 }, "Outfit"),
	P("Root", "Block", { 1.65, 0.35, 1.1 }, { 0, 1.35, 0 }, "Accent"),
	P("Root", "Block", { 0.9, 0.7, 0.3 }, { 0, 1.35, 0.6 }, "Accent"),
}
Props.PaperFan = {
	P("RightHand", "Cylinder", { 0.06, 1.3, 1.3 }, { 0.1, 0.7, -0.3 }, "Outfit2", { Rot = { 0, 90, 0 } }),
	P("RightHand", "Block", { 0.1, 0.6, 0.1 }, { 0.1, 0.1, -0.3 }, WOOD),
}
Props.GoldfishBag = {
	P("LeftHand", "Sphere", { 0.9, 1.1, 0.9 }, { 0, -0.2, -0.2 }, "#BDE0FE", { Material = "Glass", Transparency = 0.4 }),
	P("LeftHand", "Sphere", { 0.35, 0.25, 0.15 }, { 0.05, -0.2, -0.2 }, "#FF9F1C"),
}
Props.PoiNet = {
	P("RightHand", "Cylinder", { 0.08, 0.9, 0.9 }, { 0.1, 0.4, -0.4 }, WHITE, { Rot = { 0, 0, 90 } }),
	P("RightHand", "Block", { 0.1, 0.6, 0.1 }, { 0.1, -0.1, -0.1 }, "Accent"),
}
Props.HappiCoat = {
	P("Root", "Block", { 1.7, 1.5, 1.0 }, { 0, 1.55, 0 }, "Outfit"),
	P("Root", "Block", { 0.3, 1.4, 1.05 }, { 0.55, 1.55, 0 }, "Outfit2"),
	P("Root", "Block", { 0.3, 1.4, 1.05 }, { -0.55, 1.55, 0 }, "Outfit2"),
}
Props.FireworkTube = {
	P("Back", "Cylinder", { 2.2, 0.7, 0.7 }, { 0.3, 0.7, 0.2 }, "Accent", { Rot = { 0, 0, 70 } }),
	P("Back", "Cylinder", { 0.3, 0.72, 0.72 }, { 0.65, 1.7, 0.2 }, "Outfit2", { Rot = { 0, 0, 70 } }),
}
Props.FireworkBursts = {
	P("Root", "Ball", { 0.5, 0.5, 0.5 }, { 1.5, 4.8, 0.5 }, "Accent", NEON),
	P("Root", "Ball", { 0.35, 0.35, 0.35 }, { -1.3, 5.2, 0.2 }, "Outfit2", NEON),
	P("Root", "Ball", { 0.3, 0.3, 0.3 }, { 0.2, 5.6, 0.8 }, "#FFFFFF", NEON),
}

-- Gacha
Props.CapsuleShell = {
	P("Root", "Sphere", { 3.0, 2.0, 3.0 }, { 0, 0.8, 0 }, "Outfit", { Transparency = 0.1 }),
	P("Root", "Cylinder", { 0.25, 3.05, 3.05 }, { 0, 1.2, 0 }, "Accent", { Rot = { 0, 0, 90 } }),
}
Props.CatEars = {
	P("Head", "Wedge", { 0.25, 0.65, 0.5 }, { 0.6, 1.1, 0 }, "Hair", { Rot = { 0, 0, -10 } }),
	P("Head", "Wedge", { 0.25, 0.65, 0.5 }, { -0.6, 1.1, 0 }, "Hair", { Rot = { 0, 0, 10 } }),
}
Props.WindupKey = {
	P("Back", "Block", { 0.15, 0.15, 0.7 }, { 0, 0.2, 0.45 }, GOLD),
	P("Back", "Cylinder", { 0.12, 0.7, 0.7 }, { 0.35, 0.2, 0.85 }, GOLD, { Rot = { 0, 0, 0 } }),
	P("Back", "Cylinder", { 0.12, 0.7, 0.7 }, { -0.35, 0.2, 0.85 }, GOLD, { Rot = { 0, 0, 0 } }),
}
Props.JoystickScepter = {
	P("RightHand", "Block", { 0.14, 2.6, 0.14 }, { 0.1, 0.8, -0.1 }, BLACK),
	P("RightHand", "Ball", { 0.6, 0.6, 0.6 }, { 0.1, 2.2, -0.1 }, "Outfit2", NEON),
}
Props.ClawCrown = {
	P("HeadTop", "Cylinder", { 0.3, 1.4, 1.4 }, { 0, 0.05, 0 }, METAL, { Rot = { 0, 0, 90 } }),
	P("HeadTop", "Wedge", { 0.15, 0.6, 0.2 }, { 0.5, 0.45, 0 }, METAL, { Rot = { 0, 0, -20 } }),
	P("HeadTop", "Wedge", { 0.15, 0.6, 0.2 }, { -0.5, 0.45, 0 }, METAL, { Rot = { 0, 0, 20 } }),
	P("HeadTop", "Wedge", { 0.15, 0.6, 0.2 }, { 0, 0.45, 0.5 }, METAL, { Rot = { 20, 0, 0 } }),
}
Props.PaperCranes = {}
for index = 1, 6 do
	local angle = math.rad(index * 60)
	table.insert(
		Props.PaperCranes,
		P("Root", "Wedge", { 0.5, 0.35, 0.7 }, { math.cos(angle) * 2.1, 2.6 + (index % 3) * 0.6, math.sin(angle) * 2.1 }, if index % 2 == 0 then "Outfit2" else "#FFFFFF", {
			Rot = { 0, -index * 60, 0 },
		})
	)
end
Props.CapsuleHelmet = { P("Head", "Ball", { 2.8, 2.8, 2.8 }, { 0, 0.05, 0 }, "#BDE0FE", { Material = "Glass", Transparency = 0.6 }) }
Props.StarSparkles = {
	P("Root", "Ball", { 0.3, 0.3, 0.3 }, { 1.6, 3.9, -0.4 }, GOLD, NEON),
	P("Root", "Ball", { 0.25, 0.25, 0.25 }, { -1.5, 4.3, 0.3 }, WHITE, NEON),
	P("Root", "Ball", { 0.2, 0.2, 0.2 }, { 1.2, 1.4, 0.9 }, "#8FE3FF", NEON),
}
Props.LuckyCatHood = {
	P("Head", "Sphere", { 2.6, 2.5, 2.5 }, { 0, 0.15, 0.15 }, "Outfit"),
	P("Head", "Wedge", { 0.3, 0.7, 0.55 }, { 0.65, 1.3, 0.1 }, "Outfit", { Rot = { 0, 0, -12 } }),
	P("Head", "Wedge", { 0.3, 0.7, 0.55 }, { -0.65, 1.3, 0.1 }, "Outfit", { Rot = { 0, 0, 12 } }),
	P("Head", "Ball", { 0.35, 0.35, 0.35 }, { 0, -0.85, -0.9 }, GOLD),
}
Props.GoldenPaw = { P("RightHand", "Ball", { 0.75, 0.75, 0.75 }, { 0, 0.9, -0.2 }, GOLD, { Material = "Neon" }) }

-- Fusion
Props.TwinStars = {
	P("Root", "Ball", { 0.6, 0.6, 0.6 }, { 1.6, 4.5, 0 }, "#FFD670", NEON),
	P("Root", "Ball", { 0.6, 0.6, 0.6 }, { -1.6, 4.5, 0 }, "#72EFDD", NEON),
}
Props.EclipseRing = {
	P("Head", "Cylinder", { 0.15, 3.4, 3.4 }, { 0, 0.4, 1.0 }, "Accent", { Rot = { 0, 90, 0 }, Material = "Neon" }),
	P("Head", "Cylinder", { 0.18, 2.9, 2.9 }, { 0, 0.4, 0.98 }, BLACK, { Rot = { 0, 90, 0 } }),
}

return Props
