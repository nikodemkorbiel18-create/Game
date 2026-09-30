--!nocheck
-- Generates docs/ART_SPEC.md from the character, zone, rarity and mutation configs so the
-- art spec never drifts from the game data. Usage: lune run tools/gen-art-spec
local fs = require("@lune/fs")
local rbx = require("./lib/rbx")
local env = rbx.load()

local Characters = env.require("ReplicatedStorage/Shared/Config/Characters")
local Zones = env.require("ReplicatedStorage/Shared/Config/Zones")
local Rarities = env.require("ReplicatedStorage/Shared/Config/Rarities")
local Mutations = env.require("ReplicatedStorage/Shared/Config/Mutations")
local Sizes = env.require("ReplicatedStorage/Shared/Config/Sizes")
local NumberFormat = env.require("ReplicatedStorage/Shared/Util/NumberFormat")

local PROPS = {
	SchoolBag = "school bag clutched in the right hand",
	Pillow = "fluffy pillow hugged on the left side",
	DroolBubble = "small sleepy bubble at the mouth (cute, not gross)",
	Armband = "council armband on the left arm",
	GiantBento = "giant stacked bento box held in front with both hands",
	RoundGlasses = "big round glasses",
	BookTower = "tower of five colourful books carried in front",
	LongCoat = "long open coat reaching the knees",
	CheekBandage = "small bandage on the right cheek",
	Clipboard = "clipboard in the left hand",
	Scooter = "kick scooter under the feet",
	RamenBox = "red delivery box on the back",
	BigHeadset = "oversized gaming headset with mic",
	Headband = "cloth headband",
	Wok = "wok held out in the right hand",
	HoloVisor = "glowing holographic visor across the eyes",
	StreamingScarf = "scarf that streams far behind, even when standing still",
	Goggles = "goggles pushed up on the forehead",
	GiantChopsticks = "pair of giant chopsticks used as a walking staff",
	LongBeard = "long white beard",
	BambooBroom = "bamboo broom",
	PaperCharms = "paper charms in hand, more floating around",
	LeafOnHead = "single leaf balanced on the head",
	TanukiTail = "big striped tanuki tail",
	RoundEars = "round tanuki ears",
	UmbrellaTop = "umbrella handle loop on top",
	Tongue = "playful tongue sticking out",
	FoxEars = "tall fox ears with coloured inner ear",
	NineTails = "fan of nine softly glowing tails",
	CrescentSpear = "spear topped with a glowing crescent moon",
	MoonCrest = "small glowing moon crest on the forehead",
	Blindfold = "cloth blindfold",
	BambooStick = "bamboo stick raised for the melon smash",
	Watermelon = "whole watermelon under the arm",
	Surfboard = "painted surfboard slung on the back",
	BucketHelmet = "sand bucket worn as a helmet",
	Shovel = "toy shovel",
	CrabHat = "crab hat with googly eyes",
	ClawMittens = "red claw-shaped mittens",
	Ukulele = "ukulele held across the body",
	FlowerHairpin = "big hibiscus-style hairpin",
	WaveMount = "curling wave she rides on",
	Tiara = "small glowing sea tiara",
	OversizedHeadband = "comically oversized headband with long tails and a metal plate",
	SmokePuffs = "little smoke puffs around the feet",
	GiantScroll = "enormous rolled scroll carried diagonally on the back",
	RainCloak = "hooded rain-grey cloak",
	SheathedBlade = "sheathed blade worn on the back (never drawn)",
	PaperKite = "giant diamond paper kite behind them",
	OniMask = "red oni mask with small white horns",
	ClanCape = "short clan cape",
	SpinRibbons = "glowing ribbons trailing from the hands",
	Glowsticks = "a glowstick in each hand",
	FestivalCoat = "short festival happi-style coat",
	HeartMic = "heart-shaped microphone",
	HeartClips = "heart hair clips",
	LightningSticks = "lightning-bolt drumsticks",
	HoloGlitch = "floating pixel-glitch squares",
	HoloRing = "holographic ring at the feet",
	StarCape = "star-studded cape",
	Spotlight = "soft personal spotlight beam from above",
	StarCrown = "small star crown",
	Wrench = "large wrench",
	OilSmudge = "oil smudge on the cheek",
	FlightPatch = "round squadron patch on the chest",
	PilotHeadset = "pilot headset with boom mic",
	OrbitDrones = "four tiny drones orbiting overhead",
	Controller = "handheld controller",
	AceVisor = "tinted ace-pilot visor",
	WingBadge = "gold wing badge",
	Greatcoat = "heavy admiral greatcoat with epaulettes",
	MechArm = "mechanical right arm with glowing joint",
	AdmiralCap = "white admiral cap",
	MiniMechSuit = "chibi-sized mech suit with a glass cockpit",
	Necktie = "office necktie",
	FantasyArmor = "fantasy chestplate and pauldrons",
	LeafSprout = "leaf sprout on top",
	ElfEars = "long pointed ears",
	VineBow = "bow made of living vines",
	QuestBoard = "guild quest board with pinned notes",
	Ribbon = "big hair ribbon",
	GlowSword = "glowing sword",
	HeroCape = "flowing hero cape",
	FoldingFan = "folding fan held at the face",
	ImpHorns = "small imp horns",
	TeaTray = "silver tea tray with a teacup",
	ImpWings = "tiny bat wings",
	LaceParasol = "lace parasol",
	VampCollar = "tall popped vampire collar",
	JaggedArmor = "jagged obsidian armor with a glowing core",
	BigCrown = "crown two sizes too big",
	SmallHorns = "small black horns",
	TwoToneWings = "one black wing, one white wing",
	CrackedHalo = "tilted, slightly cracked halo",
	BigHorns = "large curved horns",
	ThroneCape = "cape shaped like a throne back",
	StarOar = "oar with a starlit blade",
	FerrymanHat = "wide conical ferryman hat",
	BigScythe = "oversized, clearly harmless foam scythe",
	DrumRing = "ring of floating drums",
	OniHorn = "single little oni horn",
	DragonCompanion = "small coiling dragon companion",
	DragonHorns = "small dragon horns",
	MoonDisc = "glowing moon-disc halo behind the head",
	FloatingBlades = "fan of seven floating light blades",
	GalaxyTrain = "long galaxy-print train with stars",
	PetalSwirl = "spiral of glowing petals around the body",
	Yukata = "yukata with obi sash",
	PaperFan = "round paper fan",
	GoldfishBag = "festival goldfish in a water bag",
	PoiNet = "paper goldfish scoop",
	HappiCoat = "happi coat with contrasting trim",
	FireworkTube = "firework launcher tube on the back",
	FireworkBursts = "little firework bursts overhead",
	CapsuleShell = "sitting inside a giant capsule-toy shell",
	CatEars = "cat ears",
	WindupKey = "big wind-up key in the back",
	JoystickScepter = "joystick scepter",
	ClawCrown = "crown shaped like a claw-machine claw",
	PaperCranes = "flock of paper cranes circling",
	CapsuleHelmet = "clear capsule space helmet",
	StarSparkles = "twinkling star sparkles",
	LuckyCatHood = "lucky-cat hood with ears and a bell",
	GoldenPaw = "raised golden paw",
	TwinStars = "twin glowing stars overhead",
	EclipseRing = "eclipse ring halo behind the head",
}

local BODIES = {
	Chibi = "Standard chibi (head ~2.3 studs, body ~2.7 studs; 2.5 heads tall).",
	Slime = "Round jelly body, no limbs, face on the front, slightly translucent.",
	Umbrella = "Umbrella canopy body with one big eye, a tongue and a single hopping leg on a geta sandal.",
	Lantern = "Paper-lantern body with ribs and black caps; face drawn on the paper; warm inner glow.",
	Twins = "Two small chibis side by side in one slot; the second twin's hair uses the secondary colour.",
	Petals = "Chibi body made of translucent glowing petals and light.",
	Mech = "Chibi head poking out of a boxy chibi mech suit with big fists and a thruster.",
}

local HAIR = {
	Short = "short neat hair",
	Spiky = "spiky hair",
	Long = "long hair past the shoulders",
	TwinTails = "twin tails",
	Bun = "top bun",
	Bob = "bob cut",
	Ponytail = "high ponytail",
	Messy = "messy tufts",
	Ringlets = "ringlet curls",
	Hood = "hood up",
	Helmet = "full helmet with a glowing visor slit",
	None = "no hair",
}

local IDLE = {
	Bob = "gentle up-and-down bob",
	Sway = "side-to-side sway",
	Bounce = "springy hops in place",
	Float = "floats and drifts",
	Sleepy = "slow nodding doze",
	Tap = "fidgety foot tap",
	Hover = "hovers with a slow turn",
}
local EMOTE = {
	Jump = "happy jump",
	Spin = "360 spin",
	Wave = "big wave",
	Flip = "front flip",
	Shake = "nervous shake",
	Nod = "firm nod",
	Pose = "signature pose",
	Twirl = "twirl",
	Salute = "salute",
	Flex = "arm flex",
	Bow = "polite bow",
}
local HATCH = {
	Victory = "both arms thrown up in victory",
	Peace = "peace sign and a wink",
	Bow = "polite bow",
	Flex = "arm flex with a grin",
	Twirl = "twirls into a curtsy",
	Point = "points straight at the camera",
	Salute = "crisp salute",
}

local lines = {}
local function add(text)
	table.insert(lines, text or "")
end

add("# Steal a Chibi! - Art spec sheet")
add()
add("Generated from the config files by `lune run tools/gen-art-spec`. Edit the configs, then regenerate.")
add()
add("## Global rules")
add()
add("- **Original IP only.** Archetypes are fine; no existing characters, outfits, hair-and-colour combos, logos or catchphrases.")
add("- **All ages.** Chibi proportions (about 2.5 heads tall), modest outfits, no romance or fanservice, no gore. Demons, reapers and ghosts are cute-cool, never scary.")
add("- **Look.** Bright cel-shaded, flat materials, strong outlines (inverted-hull meshes preferred; Highlights are reserved for mutations because Roblox caps them at 31 on screen), saturated palettes, soft bloom.")
add("- **Swapping placeholders.** Put a Model named after the asset slot (for example `Char_KohanaNineTail`) in `ReplicatedStorage.Assets.Characters`. Feet at the model's bottom, facing -Z. The game scales it for size tiers and adds auras and mutation effects automatically.")
add("- **Animations.** Idle, emote and hatch-pose names below map to keys in the config (`Idle`, `Emote`, `HatchPose`). The placeholder system fakes them with tweens; real animations can replace them later.")
add()
add("## Rarity auras")
add()
add("| Rarity | UI colour | Egg ornament | Aura |")
add("|---|---|---|---|")
for _, rarity in Rarities.List do
	add(string.format("| %s | %s%s | %s | %s |", rarity.DisplayName, rarity.Color, if rarity.Color2 then " -> " .. rarity.Color2 else "", rarity.Ornament, if rarity.AuraSize > 0 then "sparkles, size " .. rarity.AuraSize .. (if rarity.Rank >= 7 then " + point light" else "") else "none"))
end
add()
add("## Eggs")
add()
add("Readability rule: **shape/ornament = rarity, colour = cosmetic only, overlay = zone.** Size is shown as physical scale; mutations are visible on the shell before pickup. The base shell is a 2.2 x 3.0 x 2.2 stud oval scaled by size tier.")
add()
add("### Shell ornament by rarity")
add()
add("| Rarity | Ornament |")
add("|---|---|")
local ORNAMENTS = {
	Plain = "plain oval",
	Banded = "one coloured band",
	Gem = "glowing gem stud on the front",
	Wings = "two small white wings with rarity-coloured tips",
	Crown = "small crown on top",
	Horns = "horns and a spike on top",
	Stars = "three mini-stars orbiting the egg",
	Glitch = "black shell with glowing green glitch cracks",
	Halo = "floating halo above the egg",
	SakuraCrystal = "translucent sakura-crystal outer shell with orbiting petals",
}
for _, rarity in Rarities.List do
	add(string.format("| %s | %s |", rarity.DisplayName, ORNAMENTS[rarity.Ornament] or rarity.Ornament))
end
add()
add("### Zone overlays")
add()
add("| Zone | Egg | Overlay | Cosmetic palette |")
add("|---|---|---|---|")
for _, zone in Zones.List do
	add(string.format("| %d %s | %s (`%s`) | %s | %s |", zone.Id, zone.DisplayName, zone.EggTheme.Name, zone.EggTheme.Model, zone.EggTheme.Overlay, table.concat(zone.EggTheme.Palette, ", ")))
end
add("| Festival | Matsuri Festival Egg (`Egg_Festival`) | obi sash + glowing lantern | #FF9F1C, #FFD60A, #F72585, #4361EE |")
add("| Gacha | Gacha Capsule Egg (`Egg_Gacha`) | clear capsule top + seam | #FF8FAB, #8ECAE6, #FFB703, #80ED99 |")
add("| Fusion | Duet / Rival / Eclipse Eggs | glitter stars / half-and-half with sword / eclipse corona | per recipe |")
add()
add("`Egg_Zone3` already uses your mesh egg (rope, paper charms, seal, shine). Drop more meshes named `Egg_ZoneN` into `ReplicatedStorage.Assets.Eggs` to replace the others.")
add()
add("### Mutation overlays")
add()
add("| Mutation | Income | Visual |")
add("|---|---|---|")
local MUTATION_VISUALS = {
	Chrome = "chrome outline shimmer (reflective surfaces + silver outline)",
	Gold = "gold cel-shading (colours pulled toward gold) + sparkles + gold outline",
	Rainbow = "hue-cycling outline + rainbow sparkle aura",
	Petals = "floating sakura petals",
	KamiHalo = "golden halo + petal storm",
}
for _, mutation in Mutations.List do
	add(string.format("| %s | x%s | %s |", mutation.DisplayName, tostring(mutation.Income), MUTATION_VISUALS[mutation.Visual] or mutation.Visual))
end
add()
add("### Size tiers")
add()
add("| Size | kg | Visual scale |")
add("|---|---|---|")
for _, size in Sizes.List do
	add(string.format("| %s | %s-%s | x%s |", size.DisplayName, tostring(size.MinKg), tostring(size.MaxKg), tostring(size.Scale)))
end
add()
add("## Guardians")
add()
add("| Zone | Guardian | Asset slot | Notes |")
add("|---|---|---|---|")
local GUARDIAN_NOTES = {
	HallMonitor = "Uses your HallMonitor mesh. Strict but goofy teacher energy; whistle on a lanyard.",
	RamenMaster = "Uses your RamenMaster mesh (giant ladle, neon trims).",
	StoneKomainu = "Guardian lion-dog statue with glowing orange eyes; sits perfectly still until an egg is taken.",
	LifeguardCaptain = "Red shirt, visor, whistle, rescue flag.",
	MaskedSentinel = "Dark wrap with a red mask band and trailing scarf; never shows a face.",
	StageManager = "Headset, clipboard and a head-mounted spotlight lamp.",
	PatrolMech = "Boxy grey mech with a yellow visor strip; heavy footsteps.",
	KnightCaptain = "Silver helmet with red plume, sword and blue shield.",
	DemonGeneral = "Curved horns and a purple cape; cute-cool, not scary.",
	MistveilSpirit = "Drifting spirit wrapped in layered star-mist veils with a glowing lantern core. No mask or face.",
	CelestialWarden = "White-gold armor, halo and a golden spear.",
}
for _, zone in Zones.List do
	add(string.format("| %d | %s | `ServerStorage.Assets.Guardians.%s` | %s |", zone.Id, zone.Guardian.DisplayName, zone.Guardian.Template, GUARDIAN_NOTES[zone.Guardian.Id] or ""))
end
add()
add("## Characters")
add()
local sections = {}
for _, zone in Zones.List do
	table.insert(sections, { Title = string.format("Zone %d - %s", zone.Id, zone.DisplayName), List = Characters.ForZone(zone.Id) })
end
table.insert(sections, { Title = "Matsuri Festival Egg (event)", List = Characters.ForPool("Festival") })
table.insert(sections, { Title = "Gacha Capsule Egg (Robux)", List = Characters.ForPool("Gacha") })
table.insert(sections, { Title = "Fusion recipe results", List = Characters.ForPool("Fusion") })
for _, section in sections do
	add("### " .. section.Title)
	add()
	for _, character in section.List do
		local look = character.Look
		local props = {}
		for _, prop in look.Props do
			table.insert(props, PROPS[prop] or prop)
		end
		add(string.format("#### %s (%s, %s base)", character.DisplayName, character.Rarity, NumberFormat.PerSecond(character.BaseIncome)))
		add()
		add("- **Asset slot:** `" .. character.ModelName .. "`")
		add("- **Concept:** " .. character.Description)
		add(string.format("- **Silhouette:** %s %s%s", BODIES[look.Body or "Chibi"], HAIR[look.HairStyle] or look.HairStyle, if #props > 0 then "; " .. table.concat(props, "; ") else ""))
		add(string.format("- **Palette:** skin %s, hair %s, outfit %s / %s, accent %s, eyes %s", look.Skin, look.Hair, look.Outfit, look.Outfit2, look.Accent, look.Eyes))
		add(string.format("- **Idle:** %s. **Emote:** %s. **Hatch pose:** %s.", IDLE[character.Idle] or character.Idle, EMOTE[character.Emote] or character.Emote, HATCH[character.HatchPose] or character.HatchPose))
		add("- **Catchphrases:** " .. table.concat(character.Catchphrases, " / "))
		add()
	end
end
add("## Originality changes made to the brief")
add()
add("- **Raiko -> Goro.** A thunder-drum kid named Raiko with a ring of drums was too close to an existing drum-spirit character. Renamed to Goro (from the Japanese thunder onomatopoeia *goro-goro*); design unchanged otherwise.")
add("- **Faceless Spirit -> Mistveil Spirit.** A faceless masked spirit in a spirit-realm bathhouse town reads as a well-known film character. The guardian is now a spirit wrapped in star-mist veils with a lantern core and no mask.")
add("- **Lumi** keeps a lavender bob instead of long teal twin tails, to stay clear of existing virtual idols.")
add("- **Kenta** (rookie shinobi) avoids orange jumpsuits, whisker marks and blond spiky hair.")
add("- **Puru** is green with a leaf sprout rather than blue, to stay clear of existing slime heroes.")

fs.writeDir("docs")
fs.writeFile("docs/ART_SPEC.md", table.concat(lines, "\n") .. "\n")
print("Wrote docs/ART_SPEC.md (" .. #lines .. " lines)")
