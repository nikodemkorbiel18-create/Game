--!strict
-- Character roster. Every character is an original chibi (~2.5 heads tall).
-- Pool: "Zone" (spawns in that zone's nest), "Festival" (Matsuri event egg),
-- "Gacha" (Gacha Capsule Egg), "Fusion" (recipe fusion eggs).
-- Look drives the placeholder model (Visual/CharacterBuilder). Drop a real model named
-- ModelName into ReplicatedStorage.Assets.Characters to replace the placeholder.

export type Look = {
	Skin: string,
	Hair: string,
	HairStyle: string,
	Outfit: string,
	Outfit2: string,
	Accent: string,
	Eyes: string,
	Body: string?, -- "Chibi" (default), "Slime", "Umbrella", "Lantern", "Twins", "Petals", "Mech"
	Props: { string },
}

export type Character = {
	Id: string,
	DisplayName: string,
	Zone: number, -- 0 for non-zone pools
	Pool: string,
	Rarity: string,
	BaseIncome: number,
	SpawnWeight: number,
	Limited: boolean,
	ModelName: string,
	EggModel: string,
	Description: string,
	Catchphrases: { string },
	Idle: string,
	Emote: string,
	HatchPose: string,
	Look: Look,
}

local list: { Character } = {}
local byId: { [string]: Character } = {}

local function add(def: {
	Id: string,
	DisplayName: string,
	Zone: number,
	Pool: string?,
	Rarity: string,
	BaseIncome: number,
	SpawnWeight: number?,
	Description: string,
	Catchphrases: { string },
	Idle: string,
	Emote: string,
	HatchPose: string,
	Look: Look,
	EggModel: string?,
})
	assert(byId[def.Id] == nil, "Duplicate character id " .. def.Id)
	local pool = def.Pool or "Zone"
	local character: Character = {
		Id = def.Id,
		DisplayName = def.DisplayName,
		Zone = def.Zone,
		Pool = pool,
		Rarity = def.Rarity,
		BaseIncome = def.BaseIncome,
		SpawnWeight = def.SpawnWeight or 1,
		Limited = pool ~= "Zone",
		ModelName = "Char_" .. def.Id,
		EggModel = def.EggModel or ("Egg_Zone" .. def.Zone),
		Description = def.Description,
		Catchphrases = def.Catchphrases,
		Idle = def.Idle,
		Emote = def.Emote,
		HatchPose = def.HatchPose,
		Look = def.Look,
	}
	table.insert(list, character)
	byId[character.Id] = character
end

local function look(
	skin: string,
	hair: string,
	hairStyle: string,
	outfit: string,
	outfit2: string,
	accent: string,
	eyes: string,
	props: { string },
	body: string?
): Look
	return {
		Skin = skin,
		Hair = hair,
		HairStyle = hairStyle,
		Outfit = outfit,
		Outfit2 = outfit2,
		Accent = accent,
		Eyes = eyes,
		Props = props,
		Body = body,
	}
end

-- ZONE 1 — SAKURA ACADEMY -------------------------------------------------------
add({
	Id = "MochiKun", DisplayName = "Mochi-kun", Zone = 1, Rarity = "Common", BaseIncome = 1,
	Description = "Nervous transfer student clutching a school bag",
	Catchphrases = { "U-um, is this the right classroom?", "I-I'll do my best!" },
	Idle = "Sway", Emote = "Shake", HatchPose = "Bow",
	Look = look("#FFE0CC", "#5B4636", "Short", "#2E3A59", "#FFFFFF", "#8D6E63", "#3B2F2F", { "SchoolBag" }),
})
add({
	Id = "Nemuko", DisplayName = "Nemuko", Zone = 1, Rarity = "Common", BaseIncome = 3,
	Description = "Sleepy class rep with a pillow and a drool bubble",
	Catchphrases = { "Five more minutes... zzz", "Class rep... reporting... zzz" },
	Idle = "Sleepy", Emote = "Nod", HatchPose = "Peace",
	Look = look("#F9D9C3", "#B388EB", "Bob", "#2E3A59", "#FFFFFF", "#FFC8DD", "#6D597A", { "Pillow", "DroolBubble", "Armband" }),
})
add({
	Id = "OnigiriOto", DisplayName = "Onigiri Oto", Zone = 1, Rarity = "Uncommon", BaseIncome = 8,
	Description = "Hungry kid carrying a giant bento box",
	Catchphrases = { "Lunch break already? Yes!", "Rice ball power!" },
	Idle = "Bounce", Emote = "Jump", HatchPose = "Victory",
	Look = look("#F1C27D", "#2B2B2B", "Spiky", "#2E3A59", "#FFFFFF", "#E63946", "#2B2B2B", { "GiantBento" }),
})
add({
	Id = "Shiori", DisplayName = "Shiori", Zone = 1, Rarity = "Uncommon", BaseIncome = 14,
	Description = "Bookworm with round glasses and a tower of books",
	Catchphrases = { "Chapter twelve is the best part!", "Shh, I'm at the twist!" },
	Idle = "Tap", Emote = "Nod", HatchPose = "Point",
	Look = look("#FFE0CC", "#1D3557", "Long", "#2E3A59", "#FFFFFF", "#F4A261", "#1D3557", { "RoundGlasses", "BookTower" }),
})
add({
	Id = "BanchoRen", DisplayName = "Banchō Ren", Zone = 1, Rarity = "Rare", BaseIncome = 40,
	Description = "Tough delinquent senpai in a long coat with a cheek bandage — secretly kind",
	Catchphrases = { "Tch. I only fed the stray cat once.", "Nobody messes with my kouhai." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Flex",
	Look = look("#E0AC69", "#C1121F", "Messy", "#14213D", "#FCA311", "#E5E5E5", "#14213D", { "LongCoat", "CheekBandage" }),
})
add({
	Id = "PresidentReika", DisplayName = "Council President Reika", Zone = 1, Rarity = "Epic", BaseIncome = 180,
	Description = "Student council president with an armband and a clipboard",
	Catchphrases = { "Running in the halls? Noted.", "The council has approved your fun." },
	Idle = "Tap", Emote = "Salute", HatchPose = "Point",
	Look = look("#FFE0CC", "#F2E8CF", "Ponytail", "#1B263B", "#FFFFFF", "#D62828", "#415A77", { "Armband", "Clipboard" }),
})

-- ZONE 2 — NEON RAMEN ALLEY ----------------------------------------------------
add({
	Id = "ZoomChan", DisplayName = "Zoom-chan", Zone = 2, Rarity = "Common", BaseIncome = 5,
	Description = "Speedy delivery girl on a scooter with a ramen box",
	Catchphrases = { "Delivery in thirty seconds or less!", "Hot noodles coming through!" },
	Idle = "Bounce", Emote = "Spin", HatchPose = "Peace",
	Look = look("#F9D9C3", "#FF006E", "TwinTails", "#FB5607", "#FFBE0B", "#3A86FF", "#3A0CA3", { "Scooter", "RamenBox" }),
})
add({
	Id = "PixelPip", DisplayName = "Pixel Pip", Zone = 2, Rarity = "Uncommon", BaseIncome = 20,
	Description = "Arcade gamer with an oversized headset",
	Catchphrases = { "New high score!", "One more credit, please!" },
	Idle = "Tap", Emote = "Jump", HatchPose = "Victory",
	Look = look("#C68642", "#80FFDB", "Messy", "#5E60CE", "#48BFE3", "#F72585", "#2B2D42", { "BigHeadset" }),
})
add({
	Id = "TonkotsuTaro", DisplayName = "Tonkotsu Taro", Zone = 2, Rarity = "Uncommon", BaseIncome = 25,
	Description = "Street-food chef with a headband and a wok",
	Catchphrases = { "Twelve-hour broth, zero shortcuts!", "Order up!" },
	Idle = "Sway", Emote = "Flip", HatchPose = "Flex",
	Look = look("#E0AC69", "#2B2B2B", "Short", "#FFFFFF", "#E63946", "#FF9F1C", "#2B2B2B", { "Headband", "Wok" }),
})
add({
	Id = "Glitch", DisplayName = "Glitch", Zone = 2, Rarity = "Rare", BaseIncome = 90,
	Description = "Neon hacker with a holographic visor",
	Catchphrases = { "Your firewall is adorable.", "Rerouting the neon signs... done." },
	Idle = "Hover", Emote = "Shake", HatchPose = "Point",
	Look = look("#FFE0CC", "#7CFF4F", "Bob", "#10002B", "#3C096C", "#7CFF4F", "#7CFF4F", { "HoloVisor" }),
})
add({
	Id = "Kaze", DisplayName = "Kaze", Zone = 2, Rarity = "Epic", BaseIncome = 600,
	Description = "Motorbike rebel whose scarf streams forever behind them",
	Catchphrases = { "Wind's calling. Gotta go.", "Scarf? It's always this long." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Point",
	Look = look("#F1C27D", "#264653", "Spiky", "#2B2D42", "#8D99AE", "#E63946", "#264653", { "StreamingScarf", "Goggles" }),
})
add({
	Id = "GrandmasterChashu", DisplayName = "Grandmaster Chāshū", Zone = 2, Rarity = "Legendary", BaseIncome = 2000,
	Description = "Ancient noodle sage who uses giant chopsticks as a staff",
	Catchphrases = { "The broth remembers everything.", "Patience, young slurper." },
	Idle = "Float", Emote = "Nod", HatchPose = "Bow",
	Look = look("#E0AC69", "#F1F1F1", "Bun", "#7F5539", "#DDB892", "#FFB703", "#3D2B1F", { "GiantChopsticks", "LongBeard" }),
})

-- ZONE 3 — KITSUNE SHRINE FOREST -----------------------------------------------
add({
	Id = "Hoki", DisplayName = "Hōki", Zone = 3, Rarity = "Uncommon", BaseIncome = 30,
	Description = "Diligent shrine sweeper with a bamboo broom",
	Catchphrases = { "Every leaf has its place.", "Sweep, sweep, sweep~" },
	Idle = "Sway", Emote = "Spin", HatchPose = "Bow",
	Look = look("#F9D9C3", "#6F4E37", "Short", "#FFFFFF", "#588157", "#A3B18A", "#344E41", { "BambooBroom" }),
})
add({
	Id = "OfudaMiko", DisplayName = "Ofuda Miko", Zone = 3, Rarity = "Rare", BaseIncome = 110,
	Description = "Shrine maiden who flicks paper charms",
	Catchphrases = { "Charm! Charm! Double charm!", "Bad luck, begone!" },
	Idle = "Tap", Emote = "Flip", HatchPose = "Peace",
	Look = look("#FFE0CC", "#1B1B1E", "Long", "#FFFFFF", "#D00000", "#F2E8CF", "#1B1B1E", { "PaperCharms" }),
})
add({
	Id = "Pon", DisplayName = "Pon", Zone = 3, Rarity = "Rare", BaseIncome = 150,
	Description = "Tanuki trickster with a leaf on his head",
	Catchphrases = { "Poof! Did I fool you?", "Leaf magic never fails!" },
	Idle = "Bounce", Emote = "Flip", HatchPose = "Peace",
	Look = look("#C8A27A", "#6B4F3A", "Messy", "#8D6E63", "#3E2723", "#8BC34A", "#2B2B2B", { "LeafOnHead", "TanukiTail", "RoundEars" }),
})
add({
	Id = "Kasa", DisplayName = "Kasa", Zone = 3, Rarity = "Epic", BaseIncome = 800,
	Description = "One-eyed hopping umbrella spirit",
	Catchphrases = { "Hop! Hop! Rainy day play!", "One eye, twice the fun!" },
	Idle = "Bounce", Emote = "Jump", HatchPose = "Twirl",
	Look = look("#FFFFFF", "#E63946", "None", "#E63946", "#FFFFFF", "#F4A261", "#1B1B1E", { "UmbrellaTop", "Tongue" }, "Umbrella"),
})
add({
	Id = "KohanaNineTail", DisplayName = "Kohana, Nine-Tail Priestess", Zone = 3, Rarity = "Legendary", BaseIncome = 4500,
	Description = "Fox-eared priestess with nine glowing tails",
	Catchphrases = { "The foxes say you're lucky today!", "Nine tails, zero worries~" },
	Idle = "Float", Emote = "Twirl", HatchPose = "Twirl",
	Look = look("#FFE0CC", "#FFFFFF", "Long", "#FFFFFF", "#C1121F", "#FF9E00", "#C1121F", { "FoxEars", "NineTails" }),
})
add({
	Id = "Tsukimori", DisplayName = "Tsukimori", Zone = 3, Rarity = "Mythic", BaseIncome = 16000,
	Description = "Moon-shrine guardian with a crescent spear",
	Catchphrases = { "The moon keeps watch. So do I.", "Crescent guard, stand firm." },
	Idle = "Hover", Emote = "Salute", HatchPose = "Point",
	Look = look("#F1C27D", "#1D3557", "Ponytail", "#1D3557", "#E0E1DD", "#FFE66D", "#FFE66D", { "CrescentSpear", "MoonCrest" }),
})

-- ZONE 4 — BEACH EPISODE COAST -------------------------------------------------
add({
	Id = "MelonSmasherKai", DisplayName = "Melon Smasher Kai", Zone = 4, Rarity = "Uncommon", BaseIncome = 45,
	Description = "Blindfolded kid with a bamboo stick and a watermelon",
	Catchphrases = { "Left? Right? SMASH!", "I can smell the watermelon!" },
	Idle = "Sway", Emote = "Spin", HatchPose = "Victory",
	Look = look("#E0AC69", "#2B2B2B", "Spiky", "#48CAE4", "#FFFFFF", "#FFFFFF", "#2B2B2B", { "Blindfold", "BambooStick", "Watermelon" }),
})
add({
	Id = "Kaiyo", DisplayName = "Kaiyo", Zone = 4, Rarity = "Rare", BaseIncome = 200,
	Description = "Surf prodigy with a hand-painted board",
	Catchphrases = { "Catch you on the next wave!", "The ocean's my best friend." },
	Idle = "Sway", Emote = "Flip", HatchPose = "Peace",
	Look = look("#C68642", "#FFD166", "Messy", "#06D6A0", "#118AB2", "#EF476F", "#073B4C", { "Surfboard" }),
})
add({
	Id = "Koji", DisplayName = "Kōji", Zone = 4, Rarity = "Epic", BaseIncome = 1200,
	Description = "Sandcastle architect wearing a bucket as a helmet",
	Catchphrases = { "Load-bearing sand. Trust me.", "Moat first, towers second!" },
	Idle = "Tap", Emote = "Nod", HatchPose = "Point",
	Look = look("#F1C27D", "#8D5524", "Short", "#FFD166", "#EF476F", "#118AB2", "#2B2B2B", { "BucketHelmet", "Shovel" }),
})
add({
	Id = "Kani", DisplayName = "Kani", Zone = 4, Rarity = "Epic", BaseIncome = 1500,
	Description = "Kid in a crab hat with clacking claw mittens",
	Catchphrases = { "Clack clack! Pinch attack!", "Sideways is the fast way!" },
	Idle = "Bounce", Emote = "Shake", HatchPose = "Flex",
	Look = look("#FFE0CC", "#FF6B6B", "Short", "#FF6B6B", "#FFFFFF", "#FF3B3B", "#2B2B2B", { "CrabHat", "ClawMittens" }),
})
add({
	Id = "Coral", DisplayName = "Coral", Zone = 4, Rarity = "Legendary", BaseIncome = 7000,
	Description = "Sunset songstress with a ukulele",
	Catchphrases = { "This one's for the sunset~", "Strum along with me!" },
	Idle = "Sway", Emote = "Twirl", HatchPose = "Twirl",
	Look = look("#C68642", "#FF7F50", "Long", "#FFB4A2", "#FFCDB2", "#E5989B", "#6D2E46", { "Ukulele", "FlowerHairpin" }),
})
add({
	Id = "Umihime", DisplayName = "Umihime", Zone = 4, Rarity = "Mythic", BaseIncome = 25000,
	Description = "Tidal princess riding a curling wave",
	Catchphrases = { "The tide answers to me!", "Splash of royalty, coming through." },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#FFE0CC", "#48CAE4", "Long", "#0077B6", "#90E0EF", "#FFFFFF", "#03045E", { "WaveMount", "Tiara" }),
})

-- ZONE 5 — HIDDEN NINJA VILLAGE ------------------------------------------------
add({
	Id = "Kenta", DisplayName = "Kenta", Zone = 5, Rarity = "Rare", BaseIncome = 350,
	Description = "Rookie shinobi whose headband is way too big for him",
	Catchphrases = { "I'll be a master ninja by Tuesday!", "Stealth mode... engaged!" },
	Idle = "Bounce", Emote = "Jump", HatchPose = "Salute",
	Look = look("#E0AC69", "#3E2723", "Short", "#2F3E46", "#52796F", "#A3B18A", "#2B2B2B", { "OversizedHeadband" }),
})
add({
	Id = "KemuAndMori", DisplayName = "Kemu & Mori", Zone = 5, Rarity = "Epic", BaseIncome = 2000,
	Description = "Smoke-bomb twins who share one pen slot",
	Catchphrases = { "Now you see us—", "—now you don't!" },
	Idle = "Bounce", Emote = "Spin", HatchPose = "Peace",
	Look = look("#F1C27D", "#4A4E69", "Short", "#22223B", "#9A8C98", "#C9ADA7", "#22223B", { "SmokePuffs" }, "Twins"),
})
add({
	Id = "Makimono", DisplayName = "Makimono", Zone = 5, Rarity = "Epic", BaseIncome = 2800,
	Description = "Scroll keeper hauling an enormous scroll",
	Catchphrases = { "Every secret, filed and rolled.", "Careful, this scroll is heavier than me." },
	Idle = "Sway", Emote = "Nod", HatchPose = "Bow",
	Look = look("#FFE0CC", "#8D5524", "Bun", "#6B705C", "#CB997E", "#FFE8D6", "#3D2B1F", { "GiantScroll" }),
})
add({
	Id = "Hisame", DisplayName = "Hisame", Zone = 5, Rarity = "Legendary", BaseIncome = 9000,
	Description = "Silent blade in a rain-grey cloak",
	Catchphrases = { "...", "The rain hides my footsteps." },
	Idle = "Hover", Emote = "Pose", HatchPose = "Point",
	Look = look("#F9D9C3", "#5C677D", "Long", "#5C677D", "#33415C", "#CAF0F8", "#33415C", { "RainCloak", "SheathedBlade" }),
})
add({
	Id = "Tako", DisplayName = "Tako", Zone = 5, Rarity = "Legendary", BaseIncome = 12000,
	Description = "Kite rider soaring on a giant paper kite",
	Catchphrases = { "The wind is my road!", "Look ma, no rooftops!" },
	Idle = "Float", Emote = "Flip", HatchPose = "Victory",
	Look = look("#C68642", "#1B1B1E", "Spiky", "#E63946", "#F1FAEE", "#1D3557", "#1B1B1E", { "PaperKite" }),
})
add({
	Id = "Jinpachi", DisplayName = "Jinpachi", Zone = 5, Rarity = "Mythic", BaseIncome = 40000,
	Description = "Oni-masked clan head",
	Catchphrases = { "The clan protects its own.", "Behind the mask? Just a big softie." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Flex",
	Look = look("#E0AC69", "#F1F1F1", "Messy", "#1B1B1E", "#6A040F", "#E63946", "#E63946", { "OniMask", "ClanCape" }),
})

-- ZONE 6 — IDOL CONCERT DOME ---------------------------------------------------
add({
	Id = "Step", DisplayName = "Step", Zone = 6, Rarity = "Epic", BaseIncome = 3500,
	Description = "Backup dancer caught mid-spin",
	Catchphrases = { "Five, six, seven, eight!", "Never miss a beat!" },
	Idle = "Bounce", Emote = "Spin", HatchPose = "Twirl",
	Look = look("#C68642", "#FF70A6", "Ponytail", "#1A1423", "#FF70A6", "#70D6FF", "#1A1423", { "SpinRibbons" }),
})
add({
	Id = "Oda", DisplayName = "Oda", Zone = 6, Rarity = "Epic", BaseIncome = 4200,
	Description = "Glowstick superfan in a festival coat",
	Catchphrases = { "ENCORE! ENCORE!", "Front row or bust!" },
	Idle = "Bounce", Emote = "Jump", HatchPose = "Victory",
	Look = look("#FFE0CC", "#2B2B2B", "Messy", "#3A86FF", "#FFBE0B", "#FF006E", "#2B2B2B", { "Glowsticks", "FestivalCoat" }),
})
add({
	Id = "KiraKiraMimi", DisplayName = "Kira Kira Mimi", Zone = 6, Rarity = "Legendary", BaseIncome = 15000,
	Description = "Rookie idol with a heart-shaped microphone",
	Catchphrases = { "Sparkle, sparkle, it's showtime!", "Thanks for cheering for me!" },
	Idle = "Sway", Emote = "Twirl", HatchPose = "Peace",
	Look = look("#FFE0CC", "#FFAFCC", "TwinTails", "#FFC8DD", "#FFFFFF", "#FF4D6D", "#C9184A", { "HeartMic", "HeartClips" }),
})
add({
	Id = "ThunderBeatRin", DisplayName = "Thunder Beat Rin", Zone = 6, Rarity = "Legendary", BaseIncome = 20000,
	Description = "Rock drummer with lightning drumsticks",
	Catchphrases = { "Feel the thunder!", "One-two-three-FOUR!" },
	Idle = "Tap", Emote = "Shake", HatchPose = "Flex",
	Look = look("#F1C27D", "#FFD60A", "Spiky", "#1B1B1E", "#FFD60A", "#00B4D8", "#1B1B1E", { "LightningSticks" }),
})
add({
	Id = "Lumi", DisplayName = "Lumi", Zone = 6, Rarity = "Mythic", BaseIncome = 60000,
	Description = "Holographic virtual idol with pixel-glitch sparkles",
	Catchphrases = { "Buffering... cuteness loaded!", "Live from the data stream~" },
	Idle = "Hover", Emote = "Twirl", HatchPose = "Peace",
	Look = look("#E0F7FF", "#C8B6FF", "Bob", "#B8C0FF", "#FFFFFF", "#72EFDD", "#5E60CE", { "HoloGlitch", "HoloRing" }),
})
add({
	Id = "StarlightSeira", DisplayName = "Starlight Seira", Zone = 6, Rarity = "Cosmic", BaseIncome = 400000,
	Description = "Top idol in a star cape; a personal spotlight follows her",
	Catchphrases = { "The stage is my sky!", "Shine with me, everyone!" },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#FFE0CC", "#FFD670", "Long", "#3C096C", "#FFD670", "#FFFFFF", "#7B2CBF", { "StarCape", "Spotlight", "StarCrown" }),
})

-- ZONE 7 — MECHA HANGAR --------------------------------------------------------
add({
	Id = "Bolt", DisplayName = "Bolt", Zone = 7, Rarity = "Legendary", BaseIncome = 25000,
	Description = "Mechanic with goggles, a wrench and an oil smudge",
	Catchphrases = { "Hand me the 10mm. No, the OTHER 10mm.", "If it's broke, I'll fix it!" },
	Idle = "Tap", Emote = "Nod", HatchPose = "Flex",
	Look = look("#E0AC69", "#FF9F1C", "Messy", "#577590", "#F9C74F", "#ADB5BD", "#2B2B2B", { "Goggles", "Wrench", "OilSmudge" }),
})
add({
	Id = "Haruto", DisplayName = "Haruto", Zone = 7, Rarity = "Legendary", BaseIncome = 32000,
	Description = "Rookie pilot in a flight suit",
	Catchphrases = { "Launch checklist complete!", "My first sortie... let's go!" },
	Idle = "Sway", Emote = "Salute", HatchPose = "Salute",
	Look = look("#F9D9C3", "#3E2723", "Short", "#F77F00", "#FFFFFF", "#003049", "#003049", { "FlightPatch", "PilotHeadset" }),
})
add({
	Id = "Hive", DisplayName = "Hive", Zone = 7, Rarity = "Mythic", BaseIncome = 75000,
	Description = "Drone operator orbited by tiny drones",
	Catchphrases = { "Swarm formation B!", "My drones say hi." },
	Idle = "Hover", Emote = "Spin", HatchPose = "Point",
	Look = look("#C68642", "#80ED99", "Bob", "#22577A", "#38A3A5", "#57CC99", "#22577A", { "OrbitDrones", "Controller" }),
})
add({
	Id = "Hikari", DisplayName = "Hikari", Zone = 7, Rarity = "Mythic", BaseIncome = 110000,
	Description = "Ace pilot with a sleek visor and a wing badge",
	Catchphrases = { "Top of the leaderboard. Again.", "Wingmen, keep up!" },
	Idle = "Sway", Emote = "Salute", HatchPose = "Point",
	Look = look("#FFE0CC", "#E9ECEF", "Ponytail", "#FFFFFF", "#4361EE", "#FFBA08", "#4361EE", { "AceVisor", "WingBadge" }),
})
add({
	Id = "AdmiralGotetsu", DisplayName = "Admiral Gōtetsu", Zone = 7, Rarity = "Cosmic", BaseIncome = 550000,
	Description = "Iron admiral with a greatcoat and a mechanical arm",
	Catchphrases = { "Steel the nerves, steady the course.", "All hands, full throttle!" },
	Idle = "Sway", Emote = "Salute", HatchPose = "Salute",
	Look = look("#E0AC69", "#ADB5BD", "Short", "#14213D", "#FCA311", "#ADB5BD", "#14213D", { "Greatcoat", "MechArm", "AdmiralCap" }),
})
add({
	Id = "Daichi", DisplayName = "Daichi", Zone = 7, Rarity = "Cosmic", BaseIncome = 700000,
	Description = "Colossus pilot squeezed into a tiny chibi mech suit",
	Catchphrases = { "Small suit, BIG heart!", "Colossus mode... mini edition!" },
	Idle = "Bounce", Emote = "Flex", HatchPose = "Flex",
	Look = look("#F1C27D", "#2B2B2B", "Spiky", "#E5383B", "#F8F9FA", "#FFBA08", "#2B2B2B", { "MiniMechSuit" }, "Mech"),
})

-- ZONE 8 — ISEKAI KINGDOM ------------------------------------------------------
add({
	Id = "Taka", DisplayName = "Taka", Zone = 8, Rarity = "Legendary", BaseIncome = 45000,
	Description = "Reincarnated office worker wearing a necktie over fantasy armor",
	Catchphrases = { "Per my last quest log...", "Overtime? In THIS economy?" },
	Idle = "Sway", Emote = "Bow", HatchPose = "Bow",
	Look = look("#F9D9C3", "#3E2723", "Short", "#ADB5BD", "#6C757D", "#1D3557", "#2B2B2B", { "Necktie", "FantasyArmor" }),
})
add({
	Id = "Puru", DisplayName = "Puru", Zone = 8, Rarity = "Mythic", BaseIncome = 90000,
	Description = "Friendly green jelly slime with a leaf sprout",
	Catchphrases = { "Puru puru~!", "Squish hug incoming!" },
	Idle = "Bounce", Emote = "Jump", HatchPose = "Twirl",
	Look = look("#8AE38A", "#8AE38A", "None", "#8AE38A", "#B9F6B9", "#2D6A4F", "#1B4332", { "LeafSprout" }, "Slime"),
})
add({
	Id = "Sylwen", DisplayName = "Sylwen", Zone = 8, Rarity = "Mythic", BaseIncome = 130000,
	Description = "Elf archer with a bow woven from living vines",
	Catchphrases = { "The forest guides my arrows.", "Bullseye, naturally." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Point",
	Look = look("#FFE0CC", "#E9F5DB", "Long", "#52B788", "#2D6A4F", "#95D5B2", "#1B4332", { "ElfEars", "VineBow" }),
})
add({
	Id = "Mina", DisplayName = "Mina", Zone = 8, Rarity = "Mythic", BaseIncome = 150000,
	Description = "Adventurer-guild receptionist holding a quest board",
	Catchphrases = { "New quest posted! Sign here, please~", "Remember to report your loot!" },
	Idle = "Tap", Emote = "Bow", HatchPose = "Bow",
	Look = look("#FFE0CC", "#9C6644", "Ponytail", "#FFFFFF", "#6F1D1B", "#BB9457", "#432818", { "QuestBoard", "Ribbon" }),
})
add({
	Id = "BraveHeroYuki", DisplayName = "Brave Hero Yūki", Zone = 8, Rarity = "Cosmic", BaseIncome = 800000,
	Description = "Chosen hero with a glowing sword and a flowing cape",
	Catchphrases = { "For the kingdom!", "A hero never runs—okay, sometimes." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Victory",
	Look = look("#F1C27D", "#F4D35E", "Spiky", "#FFFFFF", "#0D3B66", "#EE964B", "#0D3B66", { "GlowSword", "HeroCape" }),
})
add({
	Id = "LadyRosalind", DisplayName = "Lady Rosalind", Zone = 8, Rarity = "Cosmic", BaseIncome = 950000,
	Description = "Villainess duchess with a folding fan and ringlet curls",
	Catchphrases = { "Ohoho! How quaint.", "I'll rewrite this story myself." },
	Idle = "Sway", Emote = "Twirl", HatchPose = "Twirl",
	Look = look("#FFE0CC", "#F2C94C", "Ringlets", "#6A0572", "#AB83A1", "#F2C94C", "#6A0572", { "FoldingFan" }),
})

-- ZONE 9 — DEMON LORD'S CASTLE -------------------------------------------------
add({
	Id = "Grimsby", DisplayName = "Grimsby", Zone = 9, Rarity = "Mythic", BaseIncome = 200000,
	Description = "Imp butler balancing a tea tray",
	Catchphrases = { "Tea is served, my liege.", "Another spilled cup... how dreadful." },
	Idle = "Tap", Emote = "Bow", HatchPose = "Bow",
	Look = look("#B56576", "#2B2B2B", "Short", "#1B1B1E", "#FFFFFF", "#6A040F", "#FFBA08", { "ImpHorns", "TeaTray", "ImpWings" }),
})
add({
	Id = "CountessVelvetine", DisplayName = "Countess Velvetine", Zone = 9, Rarity = "Cosmic", BaseIncome = 1000000,
	Description = "Vampire heiress with a lace parasol",
	Catchphrases = { "Sunlight? Simply unfashionable.", "Tomato juice, anyone?" },
	Idle = "Sway", Emote = "Twirl", HatchPose = "Bow",
	Look = look("#F8EDEB", "#3C1642", "Ringlets", "#6A040F", "#1B1B1E", "#F8EDEB", "#9D0208", { "LaceParasol", "VampCollar" }),
})
add({
	Id = "ObsidianGale", DisplayName = "Obsidian Gale", Zone = 9, Rarity = "Cosmic", BaseIncome = 1200000,
	Description = "Dark knight in jagged obsidian armor",
	Catchphrases = { "My armor fears nothing. Neither do I.", "Stand aside." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Flex",
	Look = look("#D8C3A5", "#1B1B1E", "Helmet", "#1B1B1E", "#3C1642", "#9D4EDD", "#9D4EDD", { "JaggedArmor" }),
})
add({
	Id = "MaoChan", DisplayName = "Maō-chan", Zone = 9, Rarity = "Cosmic", BaseIncome = 1500000,
	Description = "Chibi heir to the demon throne; the crown is far too big",
	Catchphrases = { "Kneel! ...Please?", "When I grow up, the crown will fit!" },
	Idle = "Bounce", Emote = "Pose", HatchPose = "Victory",
	Look = look("#FFE0CC", "#7209B7", "Messy", "#1B1B1E", "#7209B7", "#FFD60A", "#FF0054", { "BigCrown", "SmallHorns" }),
})
add({
	Id = "Azrielle", DisplayName = "Azrielle", Zone = 9, Rarity = "Secret", BaseIncome = 6000000,
	Description = "Fallen angel with one black wing and one white wing",
	Catchphrases = { "Between light and shadow, I choose me.", "Even fallen stars still shine." },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#F8EDEB", "#F2F2F2", "Long", "#1B1B1E", "#FFFFFF", "#FFD60A", "#9D4EDD", { "TwoToneWings", "CrackedHalo" }),
})
add({
	Id = "DemonLordVorthax", DisplayName = "Demon Lord Vorthax", Zone = 9, Rarity = "Secret", BaseIncome = 9000000,
	Description = "Horned demon lord whose cape is shaped like a throne",
	Catchphrases = { "My castle, my rules, my snacks.", "Tremble! ...Then have some cake." },
	Idle = "Hover", Emote = "Pose", HatchPose = "Flex",
	Look = look("#7D4E57", "#1B1B1E", "Messy", "#1B1B1E", "#9D0208", "#FFBA08", "#FF4800", { "BigHorns", "ThroneCape" }),
})

-- ZONE 10 — SPIRIT REALM -------------------------------------------------------
add({
	Id = "Chochin", DisplayName = "Chōchin", Zone = 10, Rarity = "Cosmic", BaseIncome = 1800000,
	Description = "Paper-lantern spirit with a lolling tongue",
	Catchphrases = { "Bleh! Did I scare you? No?", "I light the way home!" },
	Idle = "Float", Emote = "Shake", HatchPose = "Twirl",
	Look = look("#FFE8C2", "#E63946", "None", "#FFE8C2", "#E63946", "#FFB703", "#1B1B1E", { "Tongue" }, "Lantern"),
})
add({
	Id = "Sanzu", DisplayName = "Sanzu", Zone = 10, Rarity = "Cosmic", BaseIncome = 2200000,
	Description = "Soul ferryman with a starlit oar",
	Catchphrases = { "Fare's paid in memories.", "The river of stars is calm tonight." },
	Idle = "Sway", Emote = "Nod", HatchPose = "Bow",
	Look = look("#E0E1DD", "#415A77", "Hood", "#1B263B", "#415A77", "#E0E1DD", "#E0E1DD", { "StarOar", "FerrymanHat" }),
})
add({
	Id = "Kuro", DisplayName = "Kuro", Zone = 10, Rarity = "Secret", BaseIncome = 12000000,
	Description = "Reaper apprentice with an oversized (totally harmless) scythe",
	Catchphrases = { "It's foam! It's foam, I promise!", "Apprentice reaper, reporting for duty!" },
	Idle = "Bounce", Emote = "Spin", HatchPose = "Salute",
	Look = look("#F8EDEB", "#1B1B1E", "Hood", "#1B1B1E", "#3C096C", "#C0C0C0", "#9D4EDD", { "BigScythe" }),
})
add({
	Id = "Goro", DisplayName = "Goro", Zone = 10, Rarity = "Secret", BaseIncome = 15000000,
	Description = "Thunder-oni kid surrounded by a ring of drums",
	Catchphrases = { "Goro-goro-BOOM!", "Wanna hear my thunder solo?" },
	Idle = "Bounce", Emote = "Shake", HatchPose = "Flex",
	Look = look("#8ECAE6", "#FFD60A", "Spiky", "#FFD60A", "#1B1B1E", "#FB8500", "#023047", { "DrumRing", "OniHorn" }),
})
add({
	Id = "Ryujin", DisplayName = "Ryūjin", Zone = 10, Rarity = "Secret", BaseIncome = 18000000,
	Description = "Dragon-god child with a coiling dragon companion",
	Catchphrases = { "My dragon says you're cool.", "Tides and storms, at my command!" },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#FFE0CC", "#2EC4B6", "Long", "#FFFFFF", "#2EC4B6", "#FF9F1C", "#011627", { "DragonCompanion", "DragonHorns" }),
})
add({
	Id = "Getsurei", DisplayName = "Getsurei", Zone = 10, Rarity = "Divine", BaseIncome = 60000000,
	Description = "Lunar goddess crowned with a moon-disc halo",
	Catchphrases = { "Moonlight remembers every wish.", "Rest now. The night is kind." },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#F8F9FA", "#DEE2E6", "Long", "#E0E1DD", "#ADB5BD", "#FFF3B0", "#5E60CE", { "MoonDisc" }),
})

-- ZONE 11 — CELESTIAL SAKURA HEIGHTS -------------------------------------------
add({
	Id = "Amatsu", DisplayName = "Amatsu", Zone = 11, Rarity = "Divine", BaseIncome = 100000000,
	Description = "Celestial sword-saint surrounded by floating blades",
	Catchphrases = { "Seven blades, one calm heart.", "The heavens favor the patient." },
	Idle = "Hover", Emote = "Pose", HatchPose = "Point",
	Look = look("#FFE0CC", "#FFFFFF", "Ponytail", "#FFFFFF", "#FFD86B", "#8FE3FF", "#FFD86B", { "FloatingBlades" }),
})
add({
	Id = "Hoshikage", DisplayName = "Hoshikage", Zone = 11, Rarity = "Divine", BaseIncome = 150000000,
	Description = "Starborn empress trailing a galaxy train",
	Catchphrases = { "Every star bows. Politely.", "The cosmos is my wardrobe." },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#F8EDEB", "#3C096C", "Long", "#240046", "#FFD86B", "#8FE3FF", "#FFD86B", { "GalaxyTrain", "StarCrown" }),
})
add({
	Id = "Eien", DisplayName = "Eien", Zone = 11, Rarity = "Eternal", BaseIncome = 500000000,
	Description = "Eternal sakura spirit made of petals and light",
	Catchphrases = { "Every spring, I return.", "Petals fall; I never do." },
	Idle = "Float", Emote = "Twirl", HatchPose = "Twirl",
	Look = look("#FFE5EC", "#FFB7C5", "Long", "#FFE5EC", "#FFFFFF", "#FFD86B", "#FF4D8D", { "PetalSwirl" }, "Petals"),
})

-- MATSURI FESTIVAL EGG (event only) --------------------------------------------
add({
	Id = "YukataDancer", DisplayName = "Yukata Dancer", Zone = 0, Pool = "Festival", Rarity = "Legendary", BaseIncome = 10000,
	SpawnWeight = 80, EggModel = "Egg_Festival",
	Description = "Bon-odori dancer in a flowing yukata",
	Catchphrases = { "Dance with me under the lanterns!", "Clap, step, twirl~" },
	Idle = "Sway", Emote = "Twirl", HatchPose = "Twirl",
	Look = look("#FFE0CC", "#1B1B1E", "Bun", "#4361EE", "#FFFFFF", "#F72585", "#1B1B1E", { "Yukata", "PaperFan" }),
})
add({
	Id = "GoldfishScooper", DisplayName = "Goldfish Scooper", Zone = 0, Pool = "Festival", Rarity = "Mythic", BaseIncome = 50000,
	SpawnWeight = 17, EggModel = "Egg_Festival",
	Description = "Festival champion with a paper scoop and a bag of goldfish",
	Catchphrases = { "Twelve fish, one paper scoop!", "Gently... gently... GOT IT!" },
	Idle = "Tap", Emote = "Jump", HatchPose = "Victory",
	Look = look("#F1C27D", "#8D5524", "Short", "#E63946", "#FFFFFF", "#FF9F1C", "#2B2B2B", { "GoldfishBag", "PoiNet" }),
})
add({
	Id = "FireworksMaster", DisplayName = "Fireworks Master", Zone = 0, Pool = "Festival", Rarity = "Cosmic", BaseIncome = 600000,
	SpawnWeight = 3, EggModel = "Egg_Festival",
	Description = "Pyrotechnic artist in a happi coat with a firework launcher",
	Catchphrases = { "Tamaya~! Look up!", "Every burst is a love letter to the sky." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Victory",
	Look = look("#E0AC69", "#FF4800", "Spiky", "#1D3557", "#E63946", "#FFD60A", "#1D3557", { "HappiCoat", "FireworkTube", "FireworkBursts" }),
})

-- GACHA CAPSULE EGG (Robux, odds shown before purchase) -------------------------
add({
	Id = "CapsuleKidKoro", DisplayName = "Capsule Kid Koro", Zone = 0, Pool = "Gacha", Rarity = "Epic", BaseIncome = 4000,
	SpawnWeight = 55, EggModel = "Egg_Gacha",
	Description = "Kid peeking out of a giant capsule-toy shell",
	Catchphrases = { "Clunk-clunk... it's me!", "Twist the knob again!" },
	Idle = "Bounce", Emote = "Jump", HatchPose = "Peace",
	Look = look("#FFE0CC", "#FF8FAB", "Short", "#8ECAE6", "#FFFFFF", "#FFB703", "#023047", { "CapsuleShell" }),
})
add({
	Id = "TinCatTomo", DisplayName = "Tin Cat Tomo", Zone = 0, Pool = "Gacha", Rarity = "Legendary", BaseIncome = 20000,
	SpawnWeight = 13, EggModel = "Egg_Gacha",
	Description = "Wind-up tin cat kid with a big key in his back",
	Catchphrases = { "Wind me up, I'll run all day!", "Tick-tock, meow!" },
	Idle = "Tap", Emote = "Spin", HatchPose = "Flex",
	Look = look("#CED4DA", "#ADB5BD", "Short", "#ADB5BD", "#E63946", "#FFD60A", "#1B1B1E", { "CatEars", "WindupKey" }),
})
add({
	Id = "ClawQueenKuriko", DisplayName = "Claw Queen Kuriko", Zone = 0, Pool = "Gacha", Rarity = "Legendary", BaseIncome = 30000,
	SpawnWeight = 12, EggModel = "Egg_Gacha",
	Description = "Claw-machine champion with a joystick scepter",
	Catchphrases = { "First try, every try.", "The claw chooses ME." },
	Idle = "Sway", Emote = "Pose", HatchPose = "Victory",
	Look = look("#F1C27D", "#F72585", "TwinTails", "#7209B7", "#F72585", "#4CC9F0", "#3A0CA3", { "JoystickScepter", "ClawCrown" }),
})
add({
	Id = "OrigamiSageSenba", DisplayName = "Origami Sage Senba", Zone = 0, Pool = "Gacha", Rarity = "Mythic", BaseIncome = 120000,
	SpawnWeight = 13, EggModel = "Egg_Gacha",
	Description = "Paper-folding sage circled by a flock of paper cranes",
	Catchphrases = { "One thousand cranes, one wish.", "Fold, crease, fly." },
	Idle = "Float", Emote = "Nod", HatchPose = "Bow",
	Look = look("#FFE0CC", "#F8F9FA", "Bun", "#F8F9FA", "#E63946", "#FFD6A5", "#2B2B2B", { "PaperCranes" }),
})
add({
	Id = "NovaCapsuleNana", DisplayName = "Nova Capsule Nana", Zone = 0, Pool = "Gacha", Rarity = "Cosmic", BaseIncome = 900000,
	SpawnWeight = 6, EggModel = "Egg_Gacha",
	Description = "Star-studded capsule astronaut",
	Catchphrases = { "Next stop: the gachapon galaxy!", "Stars are just shiny capsules." },
	Idle = "Float", Emote = "Flip", HatchPose = "Victory",
	Look = look("#FFE0CC", "#90E0EF", "Bob", "#FFFFFF", "#4361EE", "#FFD60A", "#3A0CA3", { "CapsuleHelmet", "StarSparkles" }),
})
add({
	Id = "LuckyManekiMei", DisplayName = "Lucky Maneki Mei", Zone = 0, Pool = "Gacha", Rarity = "Secret", BaseIncome = 8000000,
	SpawnWeight = 1, EggModel = "Egg_Gacha",
	Description = "Fortune girl in a lucky-cat hood waving a golden paw",
	Catchphrases = { "Fortune's knocking—open up!", "Wave, wave, lucky wave~" },
	Idle = "Tap", Emote = "Wave", HatchPose = "Peace",
	Look = look("#FFE0CC", "#FFFFFF", "Hood", "#FFFFFF", "#E63946", "#FFD60A", "#E63946", { "LuckyCatHood", "GoldenPaw" }),
})

-- FUSION RECIPE RESULTS ----------------------------------------------------------
add({
	Id = "TwinStarUnit", DisplayName = "Twin Star Unit", Zone = 0, Pool = "Fusion", Rarity = "Secret", BaseIncome = 10000000,
	EggModel = "Egg_Duet",
	Description = "Starlight Seira and Lumi performing as a two-idol unit",
	Catchphrases = { "Two stars, one stage!", "Harmony level: MAX!" },
	Idle = "Float", Emote = "Twirl", HatchPose = "Victory",
	Look = look("#FFE0CC", "#FFD670", "Long", "#3C096C", "#C8B6FF", "#72EFDD", "#7B2CBF", { "StarCape", "HoloRing", "TwinStars" }),
})
add({
	Id = "HeroAndHeir", DisplayName = "Hero & Heir", Zone = 0, Pool = "Fusion", Rarity = "Secret", BaseIncome = 11000000,
	EggModel = "Egg_Rival",
	Description = "The hero and the demon heir, rivals turned best friends",
	Catchphrases = { "Rivals by day, snack buddies by night!", "Together we're unbeatable!" },
	Idle = "Bounce", Emote = "Pose", HatchPose = "Victory",
	Look = look("#F1C27D", "#F4D35E", "Spiky", "#FFFFFF", "#7209B7", "#FFD60A", "#0D3B66", { "GlowSword", "BigCrown", "HeroCape" }),
})
add({
	Id = "EclipseSovereign", DisplayName = "Eclipse Sovereign", Zone = 0, Pool = "Fusion", Rarity = "Divine", BaseIncome = 120000000,
	EggModel = "Egg_Eclipse",
	Description = "Ruler of dusk crowned by an eclipse ring",
	Catchphrases = { "Light and dark, bowing as one.", "The eclipse answers to me." },
	Idle = "Hover", Emote = "Pose", HatchPose = "Victory",
	Look = look("#F8EDEB", "#1B1B1E", "Long", "#1B1B1E", "#FFD60A", "#FF4800", "#FFD60A", { "EclipseRing", "TwoToneWings", "BigHorns" }),
})

local Characters = {
	List = list,
	ById = byId,
}

function Characters.Get(id: string): Character
	local character = byId[id]
	assert(character, "Unknown character " .. tostring(id))
	return character
end

function Characters.Find(id: string?): Character?
	if id == nil then
		return nil
	end
	return byId[id]
end

-- Zone characters of a given rarity, used by the egg roll.
function Characters.ForZoneRarity(zoneId: number, rarity: string): { Character }
	local result = {}
	for _, character in list do
		if character.Pool == "Zone" and character.Zone == zoneId and character.Rarity == rarity then
			table.insert(result, character)
		end
	end
	return result
end

function Characters.ForPool(pool: string): { Character }
	local result = {}
	for _, character in list do
		if character.Pool == pool then
			table.insert(result, character)
		end
	end
	return result
end

function Characters.ForZone(zoneId: number): { Character }
	local result = {}
	for _, character in list do
		if character.Pool == "Zone" and character.Zone == zoneId then
			table.insert(result, character)
		end
	end
	return result
end

return Characters
