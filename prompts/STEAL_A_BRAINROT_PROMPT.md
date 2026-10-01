# Steal A Brainrot! — Full Build Prompt

> **How to use this file.** Everything below the line `=== PROMPT START ===` is the prompt.
> Paste it whole into an AI coding agent (Claude Code or similar) running in an empty
> repository with Roblox Studio available. It is written to be built in milestones (section 22),
> so you can also paste it once and then say "do milestone M3" in later sessions.
>
> Things to know before you paste it:
> - **Name.** "Steal a Brainrot" is already one of the biggest games on Roblox. Using the exact
>   same title makes yours hard to find in search and risks impersonation reports. The name
>   lives in one config value (`GameSettings.GameName`) so you can change it in seconds.
> - **Classic meme characters.** The well-known Italian brainrots (Tralalero Tralala, Tung Tung
>   Tung Sahur, etc.) are included as you asked, but in a separate **Classic Memes pack** with
>   one on/off switch. Who owns these characters is unclear, and some have had trademark
>   claims. The 80 original characters complete the whole game on their own, so turning the
>   pack off never breaks anything.
> - **The map.** It follows the Steal an Egg format: fenced plots in a row, a plaza with
>   shops/leaderboard/gift box, a "safe zone line", and themed biomes stretching out in bands,
>   each with a sleeping guardian on a nest. Public guides don't document Steal an Egg's exact
>   plot arrangement or spawn point, so those parts are the closest faithful version. If you
>   have screenshots, give them to the agent and tell it to match them.
> - **Server size.** 7 players per server, as in Steal an Egg.

=== PROMPT START ===

# 0. Your role and how to work

You are a senior Roblox gameplay engineer, technical designer and level builder. You will build
**Steal A Brainrot!**, a complete, launch-ready multiplayer Roblox experience, from an empty
repository. You write all code in **Luau** with `--!strict`, sync it with **Rojo**, and generate
the map, the characters, the eggs and the UI yourself from code and Roblox parts. There are no
external art assets: you create everything.

Working rules:

1. **Build in the milestones in section 22, in order.** At the end of every milestone the game
   must open in Studio, run without errors in the Output window, and be playable up to that
   milestone. Commit after each milestone with a clear message.
2. **Every designer-facing number lives in a config module** under
   `src/ReplicatedStorage/Shared/Config/`. Never hard-code a price, speed, timer, chance or
   reward in a service. If this prompt gives a number, put it in config with a comment.
3. **The server is the authority** on everything that matters: cash, speed, positions of
   carried items, who owns what, timers, rolls, purchases. Clients only send intents
   ("I want to steal from pedestal 3") and the server validates them (section 19).
4. **When this prompt is ambiguous, pick the option that is most fun for a 9–14-year-old player
   and simplest to build, write it down in `docs/ASSUMPTIONS.md`, and keep going.** Do not stop
   to ask about small things. Stop and ask only if something blocks a whole milestone.
5. **Test as you go** (section 21). Pure logic (formulas, rolls, configs, data migrations) gets
   unit tests. Balance gets a simulator. The full loop gets a Studio playtest checklist.
6. **Kid-safe and Roblox-policy compliant at all times** (section 17). Random paid rewards
   always show odds, respect `PolicyService`, and never use fake countdowns or pressure tactics.
7. **Write docs as you build**: `README.md`, `docs/ARCHITECTURE.md`, `docs/BALANCING.md`,
   `docs/CONTENT.md` (every character, egg, mutation, guardian), `docs/STUDIO_SETUP.md`
   (publishing checklist, product IDs to fill in), `docs/LIVE_OPS.md` (how to run events,
   codes, seasons).

# 1. The game in one paragraph

Each of up to **7 players** owns a fenced plot at the south end of a long, narrow world. North
of the plots is a busy **piazza** (shops, leaderboards, spin wheel, quest board, free gift box),
and beyond the piazza's **Safe Line** stretches a runway of **10 absurd biomes**, from Pizza
Piazza to the Cosmic Brain Core. In the middle of each biome a giant, ridiculous **Guardian**
sleeps on a nest of glowing **eggs**. You run out, steal an egg, and the Guardian wakes up and
chases you. Get caught and you drop it; cross the Safe Line and it's yours. Back home the egg
sits on a podium and grows until it **hatches into a brainrot**: a chaotic, original
creature-object mash-up with a sing-song fake-Italian name and a chant. Each brainrot earns
cash every second. Cash buys faster treadmills, so you get faster, so you can outrun scarier
Guardians in further biomes for rarer eggs. Every other player can walk into your plot and steal
your eggs and brainrots, and you can bat them, trap them and lock your base. Rebirth for
permanent multipliers, fill the Index, spin the wheel, finish quests, climb the Brainrot Pass
and show up for Admin Abuse every Saturday.

## 1.1 Design pillars

1. **The run home is the game.** Every steal is a short chase with real tension: a Guardian
   behind, players ahead, a heavy egg slowing you down.
2. **Always one more thing.** At any moment the player can see their next upgrade, the next
   gift timer, the next quest and the next egg they want, and roughly how far away each one is.
3. **Chaos, but fair.** Stealing from players is core, but new players are protected, you can
   never lose your last brainrots, and every loss is recoverable in minutes.
4. **Absurd and loud.** Every brainrot has a name you want to say out loud, a silly idle
   animation and a chant. Hatches, steals and rare spawns are celebrated with big text,
   sounds and particles.
5. **Readable at a glance on a phone.** Every number, timer and prompt is big, high contrast
   and works at 390 px wide.

## 1.2 Glossary

| Term | Meaning |
|---|---|
| **Plot** | A player's fenced base with podiums, treadmill, lock button and collect plate. |
| **Podium** | One slot in a plot. Holds one egg (growing) or one brainrot (earning). |
| **Active slots** | How many podiums are unlocked. Starts at 7, upgradable to 18, plus upper-floor slots from rebirths. |
| **Storage** | Inventory for eggs and brainrots that are not on a podium. They earn nothing and cannot be stolen. |
| **Speed** | The main progression stat. Gained on the treadmill. Converts to WalkSpeed with a log curve. |
| **Recommended Speed** | The Speed at which a player carrying a Normal-size egg from that biome escapes its Guardian. |
| **Biome** | One of 10 themed zones along the runway. Each has one nest, one Guardian and 8 brainrot species. |
| **Nest** | The egg pile in a biome: 8 egg pedestals in a ring around the sleeping Guardian. |
| **Reset / Night** | Every 5 minutes (synced across servers) nests refill. The last 10 seconds before a refill are "Night": no stealing from nests. |
| **Safe Line** | The glowing line between the piazza and biome 1. Once a carried egg crosses it, Guardians can no longer take it. Players still can. |
| **Carry** | Holding an egg or brainrot. Slows you depending on size. You can't use tools while carrying. |
| **Snatch** | Taking an egg or brainrot from another player's plot. |
| **Rebirth** | Prestige reset that trades progress for permanent multipliers and slots. |
| **Index** | The collection book. First discovery of each species/mutation pays a reward. |
| **Gettoni** | Secondary soft currency from quests, gifts and events, spent in the Gettoni Shop. |

# 2. Technology and repository

## 2.1 Toolchain

- **Rojo 7** for syncing. The Rojo project manages only code folders and the `Assets` folders
  you generate. It must never overwrite the map when syncing.
- **Rokit** (`rokit.toml`) pins: `rojo`, `lune`, `luau-lsp`, `selene`, `stylua`.
- **Lune** for tooling: unit tests, the balance simulator, the map/place builder, content docs
  generation.
- **ProfileStore** (by loleris, Apache-2.0) for session-locked player saves. Vendor it under
  `src/ServerScriptService/Server/Vendor/` with its license.
- `selene` (lint) and `stylua` (format, tabs, 110 columns) with configs committed.
- `tools/check.sh` runs `luau-lsp analyze` over all source with Roblox type definitions.

## 2.2 Folder layout

```
default.project.json
rokit.toml  selene.toml  stylua.toml  .luaurc
src/
  ReplicatedStorage/Shared/
    Config/            -- ALL tunable data (one module per topic, listed in 2.3)
    Types.luau         -- shared exported types (ProfileData, BrainrotInstance, ...)
    Util/              -- Format (big numbers), Signal, Maid/Trove, Random helpers, Time (UTC day keys)
    Net/               -- Remotes.luau: single definition of every RemoteEvent/Function, typed wrappers
    Formulas/          -- Income, WalkSpeed, SizeRoll, HatchTime, SellValue, RebirthMult (pure, tested)
    Visual/            -- BrainrotBuilder, EggBuilder, Recipes (character recipes), Effects
  ServerScriptService/Server/
    Main.server.luau   -- boots services in dependency order
    Services/          -- one module per service (see 19.1)
    Vendor/ProfileStore.luau
  StarterPlayer/StarterPlayerScripts/Client/
    Main.client.luau
    Controllers/       -- one per feature (HUD, Carry, Tools, Hatch, Spin, Gifts, Quests, Pass, ...)
    UI/                -- UI components built in code (no hand-made ScreenGuis)
tools/
  build-place.luau     -- generates the map + assets into game.rbxl (section 3.10)
  test.luau            -- unit tests
  simulate.luau        -- pacing simulator (section 20)
  gen-content-doc.luau -- writes docs/CONTENT.md from configs
  check.sh
docs/
```

## 2.3 Config modules (create all of them)

`GameSettings`, `Biomes`, `Guardians`, `Brainrots`, `ClassicMemes`, `Exclusives`, `Rarities`,
`Sizes`, `Mutations`, `Treadmills`, `Trails`, `BaseUpgrades`, `Rebirths`, `Tools`, `Index`,
`Fusion`, `LoginRewards`, `PlaytimeGifts`, `SpinWheel`, `Quests`, `BrainrotPass`, `Events`,
`Shop` (Gettoni + cash shop), `Merchant`, `Monetization`, `Codes`, `Badges`, `Sounds`,
`Theme` (UI colors and fonts), `Tutorial`.

Each config exports typed data plus `ById` lookup tables, and validates itself in a unit test
(no duplicate ids, every reference resolves, weights sum > 0, prices increase monotonically).

# 3. The map (exact layout)

Build the entire map from code in `tools/build-place.luau` (and an equivalent `MapBuilder`
module you can run from the Studio command bar). Use Parts, WedgeParts, CornerWedges,
Cylinders, Balls, `SpecialMesh`-free unions only where cheap, and Terrain only for the
biome ground textures. Group everything under `Workspace.Map` with the exact names below so
code can find things by name and by CollectionService tag.

**Coordinate system for this document:** +X is east, **+Z is north**, +Y is up. 1 unit = 1 stud.
The ground plane is Y = 0. The plots are in the south, the biomes stretch north.

## 3.1 Overview (top-down, not to scale)

```
 Z
4440 ┌──────────────────────────────┐  Biome 10  Cosmic Brain Core      (Divine)
     │              ◎               │   ◎ = nest + sleeping Guardian
3820 └───────────┐ bridge ┌─────────┘
     ┌───────────┘        └─────────┐  Biome 9   Glitch Mall
     │              ◎               │
       ...  (biomes 2–8, each longer and wider than the last)  ...
 360 ┌───────────┐ bridge ┌─────────┐
     │              ◎               │  Biome 1   Pizza Piazza            (Common)
 110 ╞══════════ SAFE LINE ═════════╡  "ZONA SICURA" arch
     │ Spin   Sell  Trails Quest Tools Fuse   Leaderboards  GIFT │  PIAZZA
 -10 ├────┬────┬────┬────┬────┬────┬────┤
     │ P1 │ P2 │ P3 │ P4 │ P5 │ P6 │ P7 │  7 plots, entrances face north
-130 └────┴────┴────┴────┴────┴────┴────┘
     -350                             +350  X
```

## 3.2 Plot row

- **7 plots**, named `Plot1`…`Plot7` from west to east, under `Workspace.Map.Plots`, each tagged
  `Plot` with attribute `PlotIndex`.
- Each plot is **88 × 120 studs** (X × Z). Plots are separated by **14-stud alleys**.
  Plot *i* center: `X = -306 + (i - 1) * 102`, `Z = -70`. The row spans X −350…+350, Z −130…−10.
- The alleys are open walkways from the piazza into the gaps between plots (thieves use them to
  flank). The south edge of the row is a tall decorative hedge wall (height 30) with an invisible
  barrier to 200 studs.
- Players **spawn inside their own plot** (at local `(0, 3, -40)`, facing north). Unassigned
  plots show a "Vuoto" (empty) sign and an open gate.

### 3.2.1 Inside a plot (local coordinates, origin = plot center, local +Z = north/entrance)

| Element | Local position | Size | Notes |
|---|---|---|---|
| Floor | (0, 0.5, 0) | 88 × 1 × 120 | Bright grass with a checker of slightly different greens. Owner's color stripe around the border. |
| Fence | perimeter | height 6 | Gap of 20 studs centered on the north edge = the entrance. Low enough to see over, too high to jump without a jump boost. |
| **Laser Gate** | entrance | 20 × 10 | Invisible when unlocked. When locked: red neon laser bars + a force field that pushes non-owners out (owners and friends of the owner may pass). |
| **Lock Button** | (-34, 0, 52) | pillar 4 × 6 × 4 + big round button | Red when ready, grey with countdown when cooling down. Shows "LOCK 60s". |
| **Plot sign** | arch over the entrance | 20 wide | Owner name, avatar headshot, rebirth title, total $/s. Shows "LOCKED 0:42" while locked. |
| **Podium grid** | 3 rows × 6 columns | each podium 8 × 2 × 8, 14-stud spacing | Row z = +22, +6, −10; columns x = −35, −21, −7, 7, 21, 35. Numbered 1–18 left-to-right, front-to-back. 7 start active (the front row of 6 + podium 7). Locked podiums are grey with a small price sign. |
| **Collect pad** (per podium) | podium front edge | 4 × 0.4 × 3 | Glows green and shows a floating cash pile when it has cash. Step on it to collect that podium. |
| **Collect All Plate** | (32, 0, 52) | 10 × 0.4 × 10 | Collects every podium at once. |
| **Treadmill** | (-30, 0, -46) | 10 × 2 × 24, running north–south | Visual tier changes the model (section 9.1). Stepping on it starts running in place; the belt texture scrolls. |
| **Storage chest** | (30, 0, -48) | 8 × 6 × 6 | Opens the Storage UI. |
| **Upgrade terminal** | (16, 0, -50) | 4 × 7 × 2 screen | Opens Base Upgrades (slots). |
| **Upper floor** | rear half, Y = 18 | 88 × 1 × 50 | Appears at Rebirth 1. Stairs on the east side. Holds up to 12 extra podiums in 2 rows of 6 (z = −30, −46). Each rebirth unlocks one (section 9.4). |
| **Spawn point** | (0, 3, -40) | — | Not a SpawnLocation; the server pivots the character there on spawn. |

Each podium is tagged `Podium` with attributes `PlotIndex`, `Slot`, `Floor`. Above an occupied
podium a BillboardGui shows (top to bottom): mutation tag (if any, colored), **name**,
rarity label in rarity color, size + kg (`Huge · 412.8 kg`), and `$1.24M/s`. A growing egg shows
the egg name and a big countdown `Hatching in 2:41` with a progress ring.

## 3.3 The Piazza (Z −10 to +110)

A sunny Italian-style square, cobblestone floor, terracotta buildings as the backdrop on the
far west and east edges, string lights overhead, scooters and café tables as props. Everything
is tagged and named under `Workspace.Map.Piazza`.

| Feature | Position (X, Z) | Description |
|---|---|---|
| **Spaghetti Fountain** | (0, 50) | Centerpiece. A fountain pouring spaghetti, with a giant meatball on top. Players can sit on the rim. Also the **Codes** kiosk (a mailbox on the rim). |
| **Spin Wheel** | (−260, 60) | A 30-stud-tall carnival wheel facing south, "RUOTA DELLA FORTUNA". Physically spins when any player spins it (everyone sees the result). Prompt opens the Spin UI. |
| **Daily Rewards board** | (−300, 25) | A big calendar board with today's stamp; prompt opens Daily Rewards. |
| **Sell Counter** | (−140, 40) | A pawn shop stall "BANCO DEI PEGNI" with a shopkeeper NPC. Sell brainrots or eggs. |
| **Trails Shop** | (−60, 85) | Stall with trail samples floating on poles. |
| **Quest Board** | (0, 95) | A cork board with pinned papers; also the Brainrot Pass terminal next to it. |
| **Tool Shop** | (60, 85) | Bats and traps for cash. |
| **Fuse Machine** | (140, 40) | "FRULLATORE FUSIONE", a giant blender with 3 input trays and a glass jar output. |
| **Leaderboards** | (230 to 330, 95) | Four 20 × 14 boards in a curved row facing south-west: Most Money, Most Stolen, Highest Speed, Most Rebirths (global, top 10). |
| **Free Gift box** | (300, 60) | A big yellow gift box with a bow, right of the leaderboards. Group reward (section 14.8). Bounces and has a "!" when unclaimed. |
| **Event Portal** | (−200, 100) | Inactive stone ring; swirls purple when the Rift boss event is about to start (section 15.3). |
| **Merchant spot** | (200, 100) | Empty cart that becomes the Traveling Merchant's stall when he is in town (section 15.5). |
| **Event Stage** | (0, 20) | Low stage between fountain and plots, used by Admin Abuse and event banners. |

## 3.4 The Safe Line (Z = 110)

- A 700-stud glowing white-and-green stripe across the whole map at Z = 110, with an arch
  "ZONA SICURA" over the runway entrance (X −70…+70). It is tagged `SafeLine`.
- When a carried nest egg crosses it going south, the server marks the egg **Secured**: Guardians
  stop chasing that player, and the egg's billboard changes from "STOLEN!" to the player's name.
  Players can still bat or trap the carrier until it's placed.
- North of the Safe Line, the walls narrow to the runway width. There is no other way north.

## 3.5 The runway and biomes (Z = 110 to 4440)

The runway is a single long path north. Each biome is a rectangle centered on X = 0, joined to
the next by a **bridge** 30 studs long and only **24 studs wide** (the PvP chokepoints).
Biomes are walled with themed scenery (cliffs, buildings, shelves) at least 40 studs tall with
invisible barriers to Y = 300. Falling off a bridge drops you into a soft void that respawns
you at your plot after 1.5 s (and returns any carried nest egg to its nest).

| # | Biome | Z start → end | Length | Width | Nest center (X, Z) |
|---|---|---|---|---|---|
| 1 | Pizza Piazza | 110 → 330 | 220 | 140 | (0, 260) |
| 2 | Espresso Docks | 360 → 620 | 260 | 150 | (0, 540) |
| 3 | Spaghetti Jungle | 650 → 950 | 300 | 160 | (0, 860) |
| 4 | Gelato Glacier | 980 → 1320 | 340 | 170 | (0, 1220) |
| 5 | Sneaker Swamp | 1350 → 1730 | 380 | 180 | (0, 1620) |
| 6 | Microwave Desert | 1760 → 2180 | 420 | 190 | (0, 2060) |
| 7 | Lasagna Volcano | 2210 → 2670 | 460 | 200 | (0, 2540) |
| 8 | Disco Moon | 2700 → 3200 | 500 | 210 | (0, 3060) |
| 9 | Glitch Mall | 3230 → 3790 | 560 | 220 | (0, 3640) |
| 10 | Cosmic Brain Core | 3820 → 4440 | 620 | 230 | (0, 4280) |

Every biome entrance has a gate arch with a sign: biome name, **"Recommended Speed: 900"**, and
the biome's rarity range as colored pips. Gates are soft (anyone may enter); the Guardian is the
real speed check. When a player enters a biome, a banner slides in with the biome name and the
music and lighting crossfade (section 18).

### 3.5.1 Nest layout (same in every biome, scaled per biome)

- A raised round platform (radius 22, height 2) in the biome's theme, tagged `Nest`, attribute
  `Biome`.
- **8 egg pedestals** evenly spaced on a circle of radius 14, each tagged `EggPedestal` with
  attributes `Biome`, `Index`.
- The **Guardian** sleeps at the center (snoring "Z z z" particles and a sound).
- Two or three pieces of cover (crates, rocks, giant food) between the nest and the biome
  exit, so players can break line of sight. The Guardian path-finds around them.
- The nest faces south: the shortest escape is always straight south toward home.

### 3.5.2 Biome art direction

Each biome needs: ground material + color, 2 wall/backdrop themes, 6–10 signature props built
from parts (listed in section 4.5), a lighting preset (Ambient, OutdoorAmbient, fog color/end,
Atmosphere density/color, ColorCorrection tint), a skybox choice from Roblox defaults or a
color-tinted Atmosphere, a music track slot, and an ambient sound loop slot. Make each biome
instantly recognizable in a thumbnail.

## 3.6 Secret and side areas

| Area | Where | How to find it | What's there |
|---|---|---|---|
| **Grotta della Nonna** | Behind the tomato-sauce waterfall on the west wall of biome 3 | Walk through the waterfall | Quest NPC "Nonna Segreta" for the Lost Recipe questline (section 14.4.4) and a badge. |
| **Rooftop Café** | On top of the west piazza buildings | Parkour route from the café tables | A free hidden gift (once per day: 5 minutes of income) and a badge. |
| **Freezer Room** | Inside an ice cave in biome 4 | Squeeze behind the giant cone | Hidden chest with Gettoni once per day and a badge. |
| **Dev Room** | Under the bridge between biomes 9 and 10 | Fall onto a hidden ledge | Signed wall from the "devs", badge, a funny NPC who says random brainrot chants. |

## 3.7 The Rift Arena

A circular floating arena (radius 70) far west of the piazza at (−900, 60, 50), only reachable
through the Event Portal while the Rift event is active (section 15.3). Purple void sky, broken
pizza-tower pillars, 4 crystal spawners around the edge.

## 3.8 Map-wide rules

- `Workspace.StreamingEnabled = true`, `StreamingMinRadius = 256`, `StreamingTargetRadius = 1024`.
  Plots, the piazza, the Safe Line and all nests are `ModelStreamingMode = Persistent` (the
  server and all clients must always see them).
- Every gameplay part has `Anchored = true` and the right `CanCollide`/`CanQuery`/`CanTouch`
  (decor: `CanQuery = false`, `CanTouch = false`).
- Keep total part count under **25,000**. Prefer big simple shapes with bright colors and
  `SmoothPlastic` or Roblox materials over many small parts.
- `Workspace.Gravity = 196.2` default; the Disco Moon biome overrides gravity for players inside
  it (section 4.5, biome 8) via a client-side `VectorForce`, not the global value.

## 3.9 Night (the reset)

Every 300 seconds, synced to `os.time() % 300` so all servers reset together:

1. At **t = 290** "Night" begins: lighting dims to blue over 1 s, a bell rings, nest pedestals
   stop offering steal prompts, a banner says `🌙 NEW EGGS IN 10…`.
2. At **t = 300**, every nest pedestal is cleared (eggs left on pedestals vanish) and rerolled
   (section 6.3). Guardians teleport back to sleep. Lighting returns over 2 s. Banner:
   `🥚 NEW EGGS!`, plus a server-wide announcement for any egg of the announce rarity or above.
3. A player already **carrying** a nest egg when Night or the reset hits keeps it.

A countdown to the next reset is always visible in the HUD (top center, small).

## 3.10 Building the place

`tools/build-place.luau` (Lune, using `@lune/roblox`) must:
1. Create a new place in memory (or open `assets/base.rbxl` if it exists).
2. Run the same `MapBuilder` code as Studio to generate `Workspace.Map`.
3. Generate `ReplicatedStorage.Assets.Brainrots` (one model per species from recipes, section
   5.3), `ReplicatedStorage.Assets.Eggs` (one per biome + specials), `ServerStorage.Assets.Guardians`.
4. Set Lighting, StreamingEnabled, `Players.MaxPlayers` can't be set from a file, so note it in
   `docs/STUDIO_SETUP.md` (set Max Players = 7 in Game Settings).
5. Write `game.rbxl`. Code is synced afterwards by Rojo (or also embedded by the builder so the
   file is playable without Rojo).

# 4. Biomes and Guardians

## 4.1 Biome table

Speed → WalkSpeed conversion is in section 8.1. "Rec. Speed" is the Speed stat (not WalkSpeed).

| # | Biome | Rec. Speed | WalkSpeed at rec. | Rarities found | Guardian | Guardian ability (light, see 4.3) |
|---|---|---|---|---|---|---|
| 1 | Pizza Piazza | 0 | 16.0 | Common → Epic | **Nonna Mestolina**, a giant grandma in a rocking chair with a wooden spoon | none (tutorial biome) |
| 2 | Espresso Docks | 900 | 38.2 | Common → Legendary | **Capitano Squalo Barista**, a shark in a barista apron asleep on a coffee crate | *Steam Puff*: every 6 s, a steam cloud (radius 10) at her position; players inside are slowed to 80% for 1 s |
| 3 | Spaghetti Jungle | 10K | 46.0 | Uncommon → Legendary | **Gorilla Colapasta**, a gorilla in a colander helmet | *Noodle Snare*: every 7 s, drops a noodle patch on the path ahead of the target (telegraphed 0.8 s); stepping in it = 75% speed for 1 s |
| 4 | Gelato Glacier | 40K | 50.5 | Rare → Mythic | **Yeti Cono**, a yeti with an ice-cream-cone hat | *Brain Freeze Roar*: every 8 s, roar ring radius 18; players inside are slowed to 80% for 1.2 s |
| 5 | Sneaker Swamp | 170K | 55.2 | Epic → Cosmic | **Alligatore Ciabattino**, an alligator cobbler with a shoe-horn | *Mud Fling*: every 7 s, lobs a mud ball at the target's predicted position (shadow telegraph 1 s); hit = 80% for 1.2 s |
| 6 | Microwave Desert | 700K | 59.8 | Legendary → Secret | **Scorpione Tostapane**, a scorpion whose body is a chrome toaster | *Ding!*: every 6 s, a ground shockwave ring expands from it (visible); jump to avoid; hit = 80% for 1 s |
| 7 | Lasagna Volcano | 2.5M | 63.9 | Mythic → Eternal | **Drago Besciamella**, a lava dragon in a chef hat | *Sauce Splash*: every 8 s, 3 telegraphed lava puddles near the target; standing in one = 75% for 1 s |
| 8 | Disco Moon | 18M | 70.4 | Cosmic → Divine | **Astronauta Discotecaro**, an astronaut with a disco-ball helmet | *Spotlight*: a slow sweeping spotlight; players in it are revealed (Guardian aims perfectly) and slowed to 90% |
| 9 | Glitch Mall | 700M | 82.3 | Secret → Divine | **Buttafuori Bug**, a bouncer robot made of error windows | *Lag Blink*: every 9 s, blinks 12 studs toward the target (with a 0.6 s glitch telegraph) |
| 10 | Cosmic Brain Core | 2.5B | 86.4 | Eternal → Divine | **Il Grande Cervellone**, a giant floating brain on tiny legs | *Thought Wave*: every 6 s, a ring from it (jump to avoid); hit = 80% for 1.2 s |

## 4.2 Guardian state machine (server-side, one `GuardianService`)

```
SLEEP ──(egg stolen from its nest, or player carrying its egg within 10 studs)──► WAKE
WAKE  (0.5 s: stands up, "!" icon, roar sound, turns red tint) ──► CHASE (target = the carrier)
CHASE ──(within CatchRadius 4.5 of target)──► CATCH
CHASE ──(target crossed the Safe Line, or left the biome by > 40 studs,
         or 25 s elapsed, or target dropped the egg)──► RETURN
CATCH: target ragdolls 1.5 s, drops the egg (egg flies back to its pedestal), knockback 60,
       target gets CatchGrace 4 s (ignored by all Guardians) ──► RETURN
RETURN: walks back to the nest at 1.2× speed ──► SLEEP (if new carrier: CHASE)
```

Rules from experience (these fixed real bugs in a previous build of this genre, implement them
from the start):
- **Aim ahead.** A chasing Guardian moves toward `target.Position + target.Velocity * 0.25`,
  not the last known position, or a fast player is never caught.
- **Tick at 10 Hz** on the server, use `Humanoid:MoveTo` with re-issue every tick, and use
  `PathfindingService` only when the straight line is blocked (raycast), recomputed at most
  every 0.5 s.
- **"Blocked" means the Guardian isn't moving** (< 1 stud in 0.5 s), not that the player is
  out-running it.
- **Tutorial mercy.** Until a player has brought their first egg home, Guardians chase them at
  70% speed, use no ability, and on catch give a warning ("Nonna caught you! Run faster next
  time!") and let them keep the egg once.
- Guardians never enter the piazza or plots. They can't be hurt. Players can't push them
  (`Massless` collisions off between players and Guardians; use a CollisionGroup).
- Multiple carriers: the Guardian chases the most recent thief; the others are safe from it.

## 4.3 Guardian speed rule (the core balance contract)

- Guardian chase speed starts at **0.80 ×** `WalkSpeed(RecSpeed)` and ramps linearly to
  **0.90 ×** over the first 120 studs of the chase (in Steal an Egg the Guardian "speeds up the
  further you run").
- Carry multipliers by size are in section 6.2 (Normal = 0.92, Huge = 0.75).
- **Contract:** at exactly the biome's Recommended Speed, a player carrying a **Normal** egg
  who starts running with the Guardian 15+ studs behind **escapes**; a player carrying a
  **Huge** egg from the same start is **caught** unless they started 60+ studs ahead.
- Each ability use may gain the Guardian at most ~10 studs on that Normal carrier. Write a test
  tool (`tools/guardian-lab.luau`) that simulates every Guardian against Normal and Huge carriers
  starting 12/20/30/45/70 studs ahead and prints an escape/caught table; put it in
  `docs/BALANCING.md`.

## 4.4 Guardian models

Build each Guardian as an R15-compatible rig from parts (so `Humanoid:MoveTo` works) scaled to
about 2.5× player height, with the props described in 4.1. Animations: sleep (slow breathing,
head bob), wake (stand up), run, catch (swipe), ability (unique pose), return (grumpy walk).
Store in `ServerStorage.Assets.Guardians/<Id>`.

## 4.5 Biome scenery, props and light hazards

Hazards are light flavour (never more than a 1-second slow or a short knockback) and never
inside 30 studs of the Safe Line.

| # | Ground / walls | Signature props (build from parts) | Light hazard | Lighting mood |
|---|---|---|---|---|
| 1 | Cobblestone, terracotta houses | Giant pizza slices as ramps, wood-fired ovens, café umbrellas, a leaning pizza tower, Vespa-like scooters (unbranded), basil pots | Oven puffs: smoke clouds that block sight (no slow) | Warm noon sun |
| 2 | Wooden docks over teal water, warehouse walls | Espresso-cup boats, sugar-cube crates, cranes made of spoons, a lighthouse that is a moka pot, foam waves | Steam vents that push you 6 studs sideways | Morning haze, light fog |
| 3 | Jungle floor, noodle-vine walls | Spaghetti vines, meatball boulders, a tomato-sauce waterfall (hides the secret cave), giant basil leaves, colander huts | Sauce puddles (90% speed while inside) | Green, dappled light, humid fog |
| 4 | Snow and ice, ice-cream cliffs | Giant cones stuck in snow, wafer bridges, sprinkle trees, an igloo made of scoops, frozen lake | Slippery ice patches (reduced friction, no slow) | Cold blue, bright snow glare |
| 5 | Mud and lily pads, sneaker-box walls | Sneakers as lily pads, shoelace bridges, giant socks hanging on lines, a boot house, frogs on shoe boxes | Mud (90% speed), bouncy sneaker pads that launch you forward | Overcast, green-grey fog |
| 6 | Popcorn sand dunes, microwave mesas | Microwave mesas with glowing windows, toaster rocks, fork cacti, a timer sundial, butter pools | Microwave "ding" pulses from mesas (jump them, knockback only) | Hot orange, heat-haze ColorCorrection |
| 7 | Black rock, lasagna-layer cliffs | Lava rivers of tomato sauce, cheese-crust bridges, volcano with a chef-hat top, meatball boulders rolling on a track | Lava splash tiles that flash before erupting (knockback) | Red-orange glow, dark sky, ember particles |
| 8 | Grey moon dust, neon walls | Disco balls, dance floor tiles that light up, moon rocks, a rocket with speakers, star signs | **Low gravity** for players inside (client VectorForce, 60% gravity): longer jumps | Purple night, colored spotlights |
| 9 | Shiny mall tiles, store fronts | Escalators, shopping carts, broken arcade machines, a fountain of coins, error-window billboards | Glitch pads: step on one and you blink 10 studs in a random safe direction | Fluorescent white with flicker |
| 10 | Pink brain-fold ground, starfield walls | Floating thought bubbles, neuron trees with pulsing lights, orbiting planets, a giant brain dome over the nest | Thought-wave rings from the Guardian only | Deep space, pink and blue nebula |

# 5. Brainrots (characters)

## 5.1 Rarities

| Rank | Rarity | Color | Announce? | Hatch base time |
|---|---|---|---|---|
| 1 | Common | #B8B8B8 | – | 10 s |
| 2 | Uncommon | #5BD16B | – | 30 s |
| 3 | Rare | #3FA2FF | – | 1 min |
| 4 | Epic | #A55BFF | – | 3 min |
| 5 | Legendary | #FFB321 | – | 8 min |
| 6 | Mythic | #FF4D6D | – | 20 min |
| 7 | Cosmic | #3DE0E0 (animated gradient) | server | 45 min |
| 8 | Secret | #111111 with white outline, glitch text | server | 1.5 h |
| 9 | Eternal | gold → white gradient, shimmer | **global** | 3 h |
| 10 | Divine | rainbow gradient, sparkles | **global** | 6 h |
| — | Exclusive | hot pink + star icon | server | per item |

"Server" = a banner for everyone in the server; "global" = cross-server announcement via
MessagingService (rate-limited: max 1 per 30 s per server, queued).

## 5.2 The original roster (80 species)

Every species has: `Id`, `DisplayName`, `Biome`, `Rarity`, `BaseIncome` ($/s at Normal size, 1.0
kg ratio, no mutation), `BaseKg`, a **look** (the recipe brief for the builder), a **chant** (the
line shown in a speech bubble and spoken on hatch, see 18.2), and an **idle** animation idea.
Spawn weights inside each biome's nest (slot order 1→8) are **30, 22, 16, 12, 9, 6, 3.5, 1.5**.
Income multipliers inside a biome (slot order) are **1, 1.4, 1.9, 2.6, 3.5, 4.8, 6.5, 9** ×
the biome base: 1, 30, 500, 6K, 60K, 600K, 6M, 60M, 600M, 6B.

All names are original pseudo-Italian. Keep the sing-song rhythm when you write chants.

### Biome 1 — Pizza Piazza (base $1/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 1 | Pomodorino Pedalino | Common | 1 | A round tomato riding a tiny tricycle, leaf hat | "Pedala pedala, pomodoro!" | Pedals in place, wobbling |
| 2 | Forchetta Furbetta | Common | 1.4 | A silver fork with cat ears and sneaky eyes | "Furba furbetta, prendo la polpetta!" | Tiptoes left-right |
| 3 | Bruschetta Bassotto | Common | 1.9 | A dachshund whose long body is a toasted bruschetta with tomato chunks | "Basso basso, bruschettone!" | Wags, crumbs fall |
| 4 | Mozzarello Mollusco | Uncommon | 2.6 | A snail with a mozzarella-ball shell | "Mollo mollo, mozzarello!" | Shell squishes |
| 5 | Calzone Camaleonte | Uncommon | 3.5 | A chameleon shaped like a folded calzone, changing colors | "Cambio cambio, calzoncino!" | Color cycles |
| 6 | Signor Salamino | Rare | 4.8 | A salami with a big mustache and top hat on chicken legs | "Buongiorno, sono Salamino!" | Tips hat |
| 7 | Pepperoncino Pirata | Rare | 6.5 | A red chili pepper pirate with a peg leg and eyepatch | "Arr-rabbiata, pepperoncin!" | Hops on peg leg |
| 8 | Gran Formaggio Volante | Epic | 9 | A cheese wheel with eagle wings and goggles | "Volo volo, formaggione!" | Hovers, flaps |

### Biome 2 — Espresso Docks (base $30/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 9 | Tazzina Tartaruga | Common | 30 | A turtle whose shell is an espresso cup, steam rising | "Piano piano, tazzinella!" | Slow head bob |
| 10 | Biscotto Balenottero | Uncommon | 42 | A tiny whale made of biscotti, spouting crumbs | "Splash splash, biscottone!" | Spouts crumbs |
| 11 | Moka Pinguino | Uncommon | 57 | A penguin shaped like a moka pot, lid flaps | "Blub blub, moka moka!" | Lid pops open |
| 12 | Schiumetta Medusa | Rare | 78 | A jellyfish of milk foam with latte-art face | "Schiuma schiuma, medusina!" | Floats up/down |
| 13 | Zuccherino Granchio | Rare | 105 | A crab made of sugar cubes, claws are tongs | "Clic clac, zuccherino!" | Claws snap |
| 14 | Latte Lontra Lenta | Epic | 144 | An otter floating on its back in a latte bowl | "Lenta lenta, lontrella!" | Spins slowly |
| 15 | Doppio Delfino Diesel | Epic | 195 | A dolphin with two espresso-machine engines on its back | "Doppio! Doppio! Delfino!" | Engines puff |
| 16 | Ammiraglio Cornetto | Legendary | 270 | A croissant admiral with a captain's hat and telescope | "Avanti tutta, cornetto!" | Looks through telescope |

### Biome 3 — Spaghetti Jungle (base $500/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 17 | Fusillo Furetto | Uncommon | 500 | A ferret twisted like a fusillo | "Gira gira, fusillino!" | Spins like a corkscrew |
| 18 | Raviolo Rana | Uncommon | 700 | A frog that is a square raviolo with crimped edges | "Cra cra, ravioloso!" | Hops |
| 19 | Tucano Tortellino | Rare | 950 | A toucan whose huge beak is a tortellino | "Tuc tuc, tortellin!" | Beak clacks |
| 20 | Bradipo Bucatino | Rare | 1.3K | A sloth hanging from a giant bucatino noodle | "Zzz… bucatino…" | Sways asleep |
| 21 | Pappagallo Pesto | Epic | 1.75K | A parrot made of basil leaves with a pine-nut beak | "Pesto! Pesto! Pappagallo!" | Repeats squawk |
| 22 | Scimmietta Scolapasta | Epic | 2.4K | A monkey wearing a colander, drumming on it | "Bum bum, scolapasta!" | Drums |
| 23 | Anaconda Al Dente | Legendary | 3.25K | A very long spaghetti snake with meatball eyes | "Sssss… al dente…" | Coils/uncoils |
| 24 | Re Lasagnone | Legendary | 4.5K | A lion whose mane is layered lasagna sheets, a crown on top | "Ruggisco a strati!" | Roars, layers ripple |

### Biome 4 — Gelato Glacier (base $6K/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 25 | Pinguino Pistacchio | Rare | 6K | A round pistachio-green penguin scoop in a cone | "Pista pista, pinguino!" | Slides on belly |
| 26 | Foca Fragolina | Rare | 8.4K | A seal made of strawberry gelato balancing a wafer | "Fragola fragola, focaccina!" | Claps flippers |
| 27 | Volpe Vaniglia | Epic | 11.4K | An arctic fox with a vanilla-scoop tail | "Vaniglia, la volpe brilla!" | Tail flicks |
| 28 | Orso Affogato | Epic | 15.6K | A polar bear with espresso being poured on its head | "Affogato… ma contento!" | Shivers |
| 29 | Tricheco Tiramisù | Legendary | 21K | A walrus built of tiramisù layers with ladyfinger tusks | "Tirami su, tricheco blu!" | Lifts itself up |
| 30 | Mammut Spumone | Legendary | 28.8K | A woolly mammoth striped in spumoni colors | "Spumone, mammuttone!" | Trunk sways |
| 31 | Narvalo Granita | Mythic | 39K | A narwhal with a lemon-granita horn | "Gratta gratta, granita!" | Horn sparkles |
| 32 | Gelatissimo Glaciale | Mythic | 54K | An ice dragon built of stacked gelato scoops | "Gelatissimooo!" | Breathes snowflakes |

### Biome 5 — Sneaker Swamp (base $60K/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 33 | Ciabatta Cicogna | Epic | 60K | A stork in fuzzy slippers carrying a bread loaf | "Ciabatta, ciabattina!" | Stands on one leg |
| 34 | Stivaletto Ranocchio | Epic | 84K | A frog wearing yellow rain boots | "Splish splash, stivaletto!" | Stomps puddles |
| 35 | Zanzarone Zoccolo | Legendary | 114K | A mosquito wearing wooden clogs | "Zzz-zoccolo! Clop clop!" | Buzzes, clogs clop |
| 36 | Lumacone Lacci | Legendary | 156K | A slug tied up in its own shoelaces | "Lacci lacci, lumacone!" | Untangles, fails |
| 37 | Airone Saltatore | Legendary | 210K | A heron with spring-loaded sneakers | "Boing! Boing! Airone!" | Bounces |
| 38 | Castoro Calzino | Mythic | 288K | A beaver building a dam out of socks | "Calzino, calzetto, castoro perfetto!" | Stacks socks |
| 39 | Ippopotamo Infradito | Mythic | 390K | A hippo in flip-flops, sunglasses | "Flip flop, ippopotop!" | Flip-flops slap |
| 40 | Tacchino Tacco Imperiale | Cosmic | 540K | A turkey strutting in sparkly high heels with a cape | "Imperiale, sui tacchi reali!" | Struts and poses |

### Biome 6 — Microwave Desert (base $600K/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 41 | Suricato Popcornello | Legendary | 600K | A meerkat standing guard as popcorn pops from its head | "Pop! Pop! Suricato!" | Popcorn pops |
| 42 | Fennec Frullatore | Legendary | 840K | A fennec fox whose ears are blender blades | "Frulla frulla, fennecù!" | Ears spin |
| 43 | Cactus Cannolo | Mythic | 1.14M | A cactus made of cannoli with ricotta spines | "Pungo dolce, cannolone!" | Wiggles |
| 44 | Avvoltoio Arrosto | Mythic | 1.56M | A vulture turning on its own rotisserie spit | "Gira l'arrosto, avvoltoio!" | Rotates |
| 45 | Lucertola Lampadina | Mythic | 2.1M | A lizard with a lightbulb head that flickers | "Accendi! Spegni! Lucertola!" | Head flickers |
| 46 | Dromedario Timer | Cosmic | 2.88M | A dromedary whose hump is a ticking kitchen timer | "Tic tac… DRIIIN!" | Rings every 10 s |
| 47 | Serpente Spatola | Cosmic | 3.9M | A rattlesnake whose rattle is a spatula | "Sbatti sbatti, spatola!" | Flips imaginary pancakes |
| 48 | Faraone Forno Fantasma | Secret | 5.4M | A ghost pharaoh that is a glowing microwave oven | "Bip… bip… faraone!" | Door opens, ghost peeks |

### Biome 7 — Lasagna Volcano (base $6M/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 49 | Salamandra Sugo | Mythic | 6M | A salamander dripping hot tomato sauce | "Sugo sugo, salamandra!" | Drips |
| 50 | Polpettone Golem | Mythic | 8.4M | A golem made of stacked meatballs | "Polpetta… potente!" | Stomps |
| 51 | Fenice Focaccia | Cosmic | 11.4M | A phoenix of focaccia with rosemary feathers and fire | "Rinasco al forno!" | Flames flicker |
| 52 | Tartarugone Tegame | Cosmic | 15.6M | A big turtle whose shell is a sizzling pan | "Sfrigola sfrigola!" | Shell sizzles |
| 53 | Lupo Parmigiano | Cosmic | 21M | A wolf with a cheese-grater body, snow of parmesan | "Grattugia, lupo, grattugia!" | Grates cheese |
| 54 | Ciclope Cotoletta | Secret | 28.8M | A one-eyed breaded cutlet giant with a lemon wedge | "Un occhio, una cotoletta!" | Blinks |
| 55 | Calabrone Cannellone | Secret | 39M | A hornet whose body is a stuffed cannellone | "Bzz-bzz, cannellone!" | Buzzes in circles |
| 56 | Imperatore Lavalasagna | Eternal | 54M | An emperor made of a molten lasagna tower with a lava crown | "Inchinatevi agli strati!" | Lava bubbles |

### Biome 8 — Disco Moon (base $60M/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 57 | Polpo Paillettes | Cosmic | 60M | A sequin octopus with eight disco shoes | "Otto piedi, tutti in pista!" | Dances |
| 58 | Lunicorno Lucido | Cosmic | 84M | A crescent-moon unicorn with a mirror-ball horn | "Brilla, brilla, lunicorno!" | Horn reflects lights |
| 59 | Gattonauta Groove | Secret | 114M | A cat in an astronaut suit with headphones | "Miao-miao, nello spazio!" | Bobs head |
| 60 | Satellito Sassofono | Secret | 156M | A satellite whose antenna is a saxophone | "Bip-bop, sassofono!" | Plays sax (notes) |
| 61 | Meteorino Mambo | Secret | 210M | A small flaming meteor doing the mambo | "Mambo! Meteorino!" | Mambo steps |
| 62 | Alieno Ananas | Eternal | 288M | A three-eyed alien living inside a pineapple | "Ananas… dallo spazio!" | Peeks out |
| 63 | Cometa Cappelluta | Eternal | 390M | A comet wearing a top hat with a starry tail | "Cappello in testa, coda in festa!" | Tail swirls |
| 64 | Re Discobolo Galattico | Divine | 540M | A king made of a giant disco ball with a cape of stars | "Balla, galassia, balla!" | Spins, light beams |

### Biome 9 — Glitch Mall (base $600M/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 65 | Porcospino Pixelotto | Secret | 600M | A hedgehog made of pixels with loading-bar spines | "Pixel pixel, porcospino!" | Flickers |
| 66 | Gufo Wi-Fino | Secret | 840M | An owl that is a Wi-Fi router, signal bars as feathers | "Una tacca… due tacche…" | Bars blink |
| 67 | Scoiattolo Scaffale | Secret | 1.14B | A squirrel who is a stack of shop shelves | "Tutto in offerta!" | Stacks nuts |
| 68 | Coniglio Carrello | Eternal | 1.56B | A rabbit that is a shopping cart with one bad wheel | "Cigola cigola, carrello!" | Wobbles |
| 69 | Giraffa Joystick | Eternal | 2.1B | A giraffe whose neck is a joystick | "Su, giù, sinistra, destra!" | Neck tilts |
| 70 | Orso Errore 404 | Eternal | 2.88B | A bear assembled from error pop-ups | "Orso… non trovato!" | Pop-ups appear |
| 71 | Serpentone Scontrino | Divine | 3.9B | An endless receipt-paper snake | "Totale: infinito!" | Receipt prints |
| 72 | Glitchone Supremo | Divine | 5.4B | A corrupted giant with a shifting face of chaotic textures | "S-s-supremo-o-o!" | Glitches position |

### Biome 10 — Cosmic Brain Core (base $6B/s)

| # | Name | Rarity | $/s | Look | Chant | Idle |
|---|---|---|---|---|---|---|
| 73 | Neuronella Nebulosa | Eternal | 6B | A neuron-shaped jellyfish in a pink nebula | "Pensa, pensa, nebulosa!" | Sparks travel along it |
| 74 | Serafino Sinapsi | Eternal | 8.4B | An angel made of glowing synapses with a halo | "Alleluia, sinapsi!" | Wings pulse |
| 75 | Gallina Galassietta | Eternal | 11.4B | A hen made of a spiral galaxy that lays tiny stars | "Coccodè… cosmico!" | Lays a star |
| 76 | Quokka Quasar | Divine | 15.6B | A smiling quokka with a quasar beam from its head | "Sorridi all'universo!" | Beam pulses |
| 77 | Pecorella Pianeta | Divine | 21B | A sheep whose wool is a ringed planet | "Beee-eh, Saturnella!" | Rings rotate |
| 78 | Barboncino Buco Nero | Divine | 28.8B | A poodle with a black-hole pom-pom that pulls in sparkles | "Tutto dentro, barboncino!" | Particles sucked in |
| 79 | Calamaro Celeste | Divine | 39B | A cosmic squid with constellation tentacles | "Stelle, stelle, calamaro!" | Tentacles draw constellations |
| 80 | Omnirotto Supremo | Divine | 54B | A giant brain wearing a crown, with a slice of pizza, a coffee cup and a sneaker orbiting it (the whole world in one brainrot) | "Io sono… il brainrot!" | Objects orbit; brain pulses |

## 5.3 Building brainrots from recipes (art pipeline, no external art)

Every species is generated from a **recipe**: a small declarative table in
`Shared/Visual/Recipes/<Biome>.luau`. `BrainrotBuilder` turns a recipe into a `Model` with a
`PrimaryPart` ("Root"), welds, an `AnimationController`-free procedural idle (tweens/CFrame
loops on the client only), and attachments for name tags and effects. Recipe schema:

```lua
export type Part = {
	Name: string,
	Shape: "Block" | "Ball" | "Cylinder" | "Wedge" | "CornerWedge",
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material?,  -- default SmoothPlastic
	Offset: CFrame,            -- relative to Root
	Neon: boolean?,
	Transparency: number?,
	Tags: { string }?,         -- "Eye", "Wing", "Spin", "Bob", "Flicker" drive procedural idles
}
export type Recipe = {
	Id: string,
	Scale: number,             -- overall size at Normal (1 = about player-sized)
	Parts: { Part },
	Face: { Style: "Cute" | "Angry" | "Sleepy" | "Derp" | "Cool", Offset: CFrame }?,
	Idle: { Type: "Bob" | "Spin" | "Wobble" | "Hop" | "Sway" | "Custom", Speed: number, Amount: number },
	Particles: { { Kind: "Steam" | "Crumbs" | "Sparkles" | "Flames" | "Notes" | "Snow" | "Glitch", Offset: CFrame } }?,
}
```

Rules for recipes:
- 6–30 parts per species. Big readable silhouettes. Every brainrot has **eyes** (two white balls
  with black pupils, or the face decal style) so it reads as a character.
- Use the shared `Face` builder for consistent googly eyes/mouths across the roster.
- Higher rarities get more parts, Neon accents, and particles.
- Write **3 full example recipes** first (Pomodorino Pedalino, Re Lasagnone, Omnirotto
  Supremo), check them in Studio with a screenshot, then write the rest in the same style.
- Generate inventory/Index icons at runtime with `ViewportFrame` + camera framing the model
  (cache the frames). No uploaded images are needed.
- Write `docs/CONTENT.md` with every species, its recipe description, and a "replace with a
  mesh" note: models dropped into `ReplicatedStorage.Assets.BrainrotOverrides/<Id>` replace the
  generated one without code changes.

## 5.4 Classic Memes pack (toggleable)

`Config/ClassicMemes.luau` with `Enabled = true` at the top and this comment:
`-- Legal: ownership of these characters is unclear and some have trademark claims. Set to false to remove them everywhere. Nothing else depends on them.`

When enabled, these species are added to the nests listed (as extra spawn entries with the
weight given, on top of the 8 originals), appear in the Index in a separate "Classics" tab, and
can be fused and sold like any other. When disabled they never spawn, are hidden from the
Index, and **existing owned copies are converted** on load into a "Mystery Brainrot" of equal
income (a gray question-mark recipe) so no one loses value.

| Name | Biome | Rarity | $/s (pick within that biome's range) | Weight |
|---|---|---|---|---|
| Lirili Larila | 1 | Rare | 5 | 4 |
| Tim Cheese | 1 | Epic | 8 | 1.5 |
| Ballerina Cappuccina | 2 | Epic | 160 | 2 |
| Cappuccino Assassino | 2 | Legendary | 260 | 1.5 |
| Chimpanzini Bananini | 3 | Epic | 2K | 2 |
| Trippi Troppi | 3 | Legendary | 4K | 1.5 |
| Brr Brr Patapim | 3 | Legendary | 4.2K | 1.5 |
| Frigo Camelo | 4 | Legendary | 25K | 1.5 |
| Bobritto Bandito | 5 | Legendary | 200K | 1.5 |
| Boneca Ambalabu | 5 | Mythic | 350K | 1 |
| Trulimero Trulicina | 6 | Mythic | 1.8M | 1.2 |
| Bombombini Gusini | 6 | Cosmic | 3.5M | 0.8 |
| Bombardiro Crocodilo | 7 | Secret | 35M | 0.6 |
| Tung Tung Tung Sahur | 7 | Secret | 40M | 0.6 |
| La Vaca Saturno Saturnita | 8 | Eternal | 350M | 0.5 |
| Glorbo Fruttodrillo | 8 | Secret | 180M | 0.6 |
| Tric Trac Baraboom | 9 | Eternal | 2.5B | 0.4 |
| Udin Din Din Dun | 9 | Eternal | 2B | 0.4 |
| Tralalero Tralala | 10 | Divine | 30B | 0.25 |
| Burbaloni Luliloli | 10 | Eternal | 9B | 0.4 |

Build these as recipes too, as recognizable "in the spirit of" part-built versions. Do not use
any uploaded images, audio or meshes copied from the internet. **Only these 20 names**; never add
crude or adult-humor memes.

## 5.5 Exclusive brainrots (not from nests)

| Id | Name | Rarity | Source | $/s | Look |
|---|---|---|---|---|---|
| X1 | Ruotino Fortunato | Exclusive (Mythic-tier) | Spin Wheel jackpot | 3M | A four-leaf-clover hamster running inside a mini spin wheel |
| X2 | Dollarino Dorato | Exclusive (Secret-tier) | Golden Egg gacha (Robux) | 60M | A golden piggy bank with a crown and wings |
| X3 | Spaghettino Smeraldo | Exclusive (Cosmic-tier) | Golden Egg gacha | 12M | An emerald spaghetti snail |
| X4 | Nonno Cronometro | Exclusive (Legendary-tier) | Playtime gift 12 (rare roll 5%) | 300K | A grandpa clock with a walking stick |
| X5 | Calendarino Mensile | Exclusive (scales) | Monthly stamp card (28 stamps); new look every month | best-biome slot 6 income | A calendar page creature, theme changes monthly |
| X6 | Riftone Corrotto | Exclusive (Eternal-tier) | Rift Boss drop (2%) / Rift egg | 1B | A purple-cracked pizza tower golem |
| X7 | Adminello Abusivo | Exclusive (Divine-tier) | Only during Admin Abuse (egg rain) | 20B | A tiny admin with a ban hammer and a crown, "ADMIN" hoodie |
| X8 | Passaporto Pinguino | Exclusive (season) | Brainrot Pass free tier 25 | best-biome slot 5 | A penguin wearing a passport as a cape |
| X9 | Premium Pavone | Exclusive (season) | Brainrot Pass premium tier 40 | best-biome slot 8 × 1.5 | A peacock with tail feathers made of golden tickets |
| X10 | Fusione Frankenstein | Exclusive (Secret-tier) | Fuse Machine: 3 Secrets of different species (1%) | 150M | Three brainrots stitched together, bolts in the neck |
| X11 | Codino Coraggioso | Exclusive (Rare-tier) | Launch code reward | 50 | A pigtail-haired tiny knight carrot |
| X12 | Mercante Misterioso | Exclusive (Mythic-tier) | Traveling Merchant rare stock | 4M | A hooded merchant cat with a lantern |

"Scales" / "best-biome slot N" means the income is set when obtained, equal to slot N of the
highest biome the player has unlocked at that moment, so seasonal rewards stay relevant to
everyone.

# 6. Eggs

## 6.1 Egg look

Each biome has its own egg built by `EggBuilder` (an ellipsoid: a Ball part scaled 1 × 1.3 × 1
with patterned bands):

| Biome | Egg name | Look |
|---|---|---|
| 1 | Pizza Egg | Crust-colored with pepperoni spots |
| 2 | Crema Egg | Coffee-brown with a foam cap and a latte-art heart |
| 3 | Pasta Egg | Yellow with wrapped spaghetti strands |
| 4 | Gelato Egg | Three pastel scoop bands, sprinkles |
| 5 | Sneaker Egg | White with laces across it and a sole band |
| 6 | Popcorn Egg | Chrome with popcorn bumps |
| 7 | Lava Egg | Black rock with glowing orange cracks |
| 8 | Disco Egg | Mirror tiles, rotating light sparkles |
| 9 | Glitch Egg | Pixelated, random color blocks flicker |
| 10 | Brain Egg | Pink brain folds, faint neon pulses |
| — | Golden Egg | Gold with a ribbon (gacha) |
| — | Rift Egg | Purple-cracked with void particles |

The egg's **rarity is visible**: a ring of colored light under the pedestal and a billboard
`??? · Legendary · Huge` (species stays hidden until it hatches, rarity and size are shown).
Eggs of rarity ≥ Cosmic have a beam of light into the sky that is visible from the piazza.

## 6.2 Size and weight (kg)

Every egg rolls a **weight ratio** `r` relative to its species' `BaseKg` (BaseKg = 2 × 1.6^(biome−1)
× (1 + 0.1 × slot) kg, rounded to 0.1). The displayed kg is `BaseKg × r`. The size label comes from r:

| Size | r range | Spawn chance | Carry speed | Jump | Model scale | Hatch time × |
|---|---|---|---|---|---|---|
| Tiny | 0.40–0.69 | 12% | 1.00 | 1.0 | 0.7 | 0.6 |
| Small | 0.70–0.94 | 25% | 0.97 | 1.0 | 0.85 | 0.8 |
| Normal | 0.95–1.49 | 40% | 0.92 | 1.0 | 1.0 | 1.0 |
| Big | 1.5–2.99 | 15% | 0.85 | 0.9 | 1.25 | 1.4 |
| Huge | 3–9.99 | 6% | 0.75 | 0.8 | 1.6 | 2.0 |
| Giant | 10–49.99 | 1.8% | 0.62 | 0.6 | 2.1 | 3.0 |
| Titan | 50–1000 | 0.2% | 0.50 | 0 (can't jump) | 2.8 | 4.0 |

Within a size bracket, `r` is uniform; for Titan use `r = 50 × 20^(u^3)` (u uniform 0..1) so
1000× is extremely rare.

**Income multiplier from weight** (from the genre: big eggs matter a lot, but with diminishing
returns): `SizeMult(r) = r^0.6167` for r ≤ 125, and `125^0.6167 × (r/125)^0.3` above.
(r = 1 → 1×, r = 3 → 1.97×, r = 10 → 4.1×, r = 100 → 17.1×, r = 1000 → 36.7×.) Put it in
`Formulas/Income.luau` with tests for those exact points.

## 6.3 Nest reroll

At each reset, for each of the 8 pedestals in each biome:
1. Pick a species by the biome weights (section 5.2, plus Classic Memes if enabled), with the
   current luck multipliers applied to every non-slot-1 weight (`weight × luck` for slots ≥ 4).
2. Roll size (6.2) and natural mutation (6.4).
3. **Server luck guarantee:** if a server-luck product is active, pedestal 8 of every biome
   rerolls once and keeps the better result.
4. **Event overrides** (section 15) can add mutations or force a rarity on some pedestals.

All rolls use a server-side `Random.new()` seeded per server; no client knowledge of the roll
before the egg appears.

## 6.4 Mutations

One mutation per egg/brainrot. Multiplies income and adds a visual.

| Mutation | × Income | Source | Chance | Visual |
|---|---|---|---|---|
| Silver | 1.2 | Natural on nest eggs | 6% | Chrome material + white sparkle |
| Gold | 2.0 | Natural | 2.5% | Gold material, gold particles |
| Diamond | 3.0 | Natural | 0.8% | Glass/ice blue, refracting sparkles |
| Rainbow | 5.0 | Natural | 0.25% | Cycling hue over all parts |
| Saucy | 2.5 | Pasta Rain weather event | 20% during event | Red sauce drips |
| Cosmic Dust | 3.5 | Meteor Shower event | 15% during event | Star particles, purple tint |
| Glitched | 4.0 | Glitch Storm event | 10% during event | Parts jitter, RGB split |
| Frozen | 2.0 | Brain Freeze event | 25% during event | Ice shell |
| Disco | 3.0 | Disco Fever event | 15% during event | Mirror tiles, beams |
| Brain Bloom | 1.5 | Bloom Machine in biome 10 (cash) | 100% (replaces current if better) | Pink petals |
| Mega Bloom | 6.0 | Bloom Machine (2% roll) | 2% | Neon pink aura |
| Corrupted | 7.0 | Rift Boss reward potion | – | Purple cracks, void particles |
| Admin | 10.0 | Admin Abuse only | – | Rainbow + crown icon |

The **Bloom Machine** stands next to biome 10's nest. Place a brainrot from Storage into it
(UI), pay `5 × that brainrot's income × 60` cash, and it rolls Brain Bloom (98%) or Mega Bloom (2%).
It only replaces an existing mutation if the new one is better.

## 6.5 Hatching

- Hatch time = `RarityBaseTime × SizeHatchMult × MutationHatchMult (1.0–1.5) × (1 / GrowthBoosts)`.
- Cap any single hatch time at **12 hours**.
- Growth is based on `os.time()`: it continues while offline. Store `PlacedAt` and `HatchAt`.
- The very first egg a new player places hatches in **at most 10 s** (tutorial).
- When it hatches (owner present): the egg shakes 3 times, cracks, bursts with confetti and the
  brainrot pops out with its chant (section 18.3 reveal). If the owner isn't looking at the
  plot, a toast says "🐣 Pepperoncino Pirata hatched!" with a "Go see" button (camera tweens).
- **Grow All** (Robux product) instantly finishes every growing egg.
- An unhatched egg on a podium **can be stolen**, keeping its remaining time.

# 7. Economy and income

## 7.1 Income formula (`Formulas/Income.luau`)

```
IncomePerSecond(brainrot) =
    BaseIncome(species)
  × SizeMult(r)                       -- 6.2
  × MutationMult                      -- 6.4
  × RebirthMult                       -- 1 + 0.5 × rebirths (section 9.4)
  × IndexBonus                        -- 1 + 0.02 per completed biome page, max +0.2 (section 10)
  × PassMult                          -- ×2 with 2x Money pass, ×1.5 VIP (stack multiplicatively)
  × FriendBoost                       -- 1 + 0.1 per friend in server, max +0.4
  × EventMult                         -- e.g. 2 during Double Cash event
```

Cash accumulates per podium (server tick every 1 s, add income; send one batched update to
the owner every second, not one remote per podium). Collect by stepping on the podium's
collect pad or the Collect All Plate (or Auto-Collect pass).

## 7.2 Offline earnings

On join, award `min(OfflineSeconds, 8h) × TotalIncome × 0.25` (VIP: 12h × 0.5). Show the
"Welcome back!" popup with the amount, and a "x2 for 25 R$" button (dev product
`OfflineDouble`) next to the free "Collect" button. Never auto-open a purchase prompt.

## 7.3 Selling

At the Sell Counter: sell value = `IncomePerSecond (without temporary boosts) × 30`. Eggs sell
for 30% of the hatched value estimate. Confirm dialog for Legendary and above. "Sell all below
rarity X" button with a confirmation listing exactly what will be sold. Locked/favorited items
(a heart toggle in Storage) are never sold in bulk.

## 7.4 Number format

`Util/Format.luau`: 1,234 → `1.23K`, then M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc. Always 3
significant digits. Cash shows a `$` prefix. Speed has no prefix and a ⚡ icon. All values are
Lua numbers (doubles); never store as strings.

# 8. Core mechanics

## 8.1 Speed and movement

- **Speed** is a number stat (can reach the quadrillions). `WalkSpeed = min(95, 16 + 7.5 × log10(1 + Speed))`.
  Speed 0 → 16, 900 → 38.2, 10K → 46, 2.5M → 64, 2.5B → 86.4.
- `JumpHeight` stays at 7.2 (Roblox default) except for carry multipliers (6.2).
- The server sets WalkSpeed (never the client) and recalculates on Speed change, carry start/end,
  slow effects and boosts. Slows multiply and the strongest one wins when the same type repeats
  (never stack two Guardian slows).
- **Temporary Speed boosts** (Spin Wheel, products, events) multiply WalkSpeed by up to 1.25,
  shown as a ⚡ icon with a timer in the HUD.

## 8.2 The treadmill

- Step onto your own treadmill: the character is held in place (`AlignPosition` on the belt
  center), plays a run animation, the belt scrolls, and you gain **Speed per second =
  TreadmillGain × TrailMult × RebirthSpeedMult × PassMult × EventMult**, ticked by the server
  every 0.5 s.
- Jump or press the "Stop" button to get off. Floating `+12 ⚡` numbers pop above the head.
- Other players can't use your treadmill.

## 8.3 Stealing from nests

1. Walk up to a nest pedestal with an egg. A **ProximityPrompt** "Steal 🥚" appears (hold
   **0.6 s**, `MaxActivationDistance` 9, `RequiresLineOfSight = false`). Not available during
   Night, while carrying, or during your own catch-grace stun.
2. On success the egg is welded above the player's head (both arms up). The pedestal is empty.
   The Guardian wakes (4.2). The egg's billboard says `STOLEN!` with the thief's name, and a
   red beam rises from the carrier so everyone can see the run.
3. While carrying: WalkSpeed × size carry multiplier (6.2), no tools, can jump unless Titan.
   Press **Backspace / ButtonX / the DROP button** to drop it on purpose (a nest egg flies back
   to its pedestal).
4. Cross the **Safe Line** → egg Secured (3.4). Enter **your own plot** → the egg auto-places on
   the first free active podium (lowest slot number) with a "plop" sound. If none are free it
   goes to Storage with a toast `Base full! Sent to Storage (12/60)`; if Storage is also full, a
   dialog offers "Sell it for $X" or "Swap with your weakest".
5. If a carrier is caught, batted, trapped, falls, dies, or leaves the game, the item drops
   (8.6).

## 8.4 Stealing from other players' plots

- Any podium item (growing egg or brainrot) in another player's unlocked plot shows a
  ProximityPrompt **"Snatch"**: hold **1.0 s** for eggs, **1.5 s** for brainrots.
- On success the item is lifted from the podium and carried like a nest egg, with an extra
  **× 0.9 thief slow**. The owner's podium shows a dashed outline and "STOLEN by X".
- The owner gets: a siren sound, a pulsing red screen border, a toast `🚨 Leo123 is stealing
  your Re Lasagnone!`, and a red 3D arrow over the thief that is visible through walls
  (`AlwaysOnTop` billboard), until the steal ends.
- The thief must carry it into **their own plot** to complete the steal. On completion the item
  (with its kg, mutation and remaining hatch time) belongs to the thief and auto-places.
  Everyone in the server sees a kill-feed line `Leo123 stole Re Lasagnone from Mia!`.
- If the thief is batted, trapped, falls, dies or leaves, the item **teleports straight back
  to the owner's podium** (no dropped item for plot steals).
- Rules that keep it fair:
  - **New-player shield:** a player with less than 10 minutes of total playtime can't be
    snatched from and can't snatch (shield icon on their plot sign).
  - **Last-two rule:** the player's two lowest-income podium items are never stealable when
    they have 3 or fewer items placed. (Tiny shield icon on those podiums.)
  - **Revenge-free cooldown:** after X steals from Y, X can't snatch from Y again for 60 s.
  - **One at a time:** a player can only carry one item.
  - **Spawn safety:** 3 s of immunity to bats after spawning.

## 8.5 Base Lock

- Press your Lock Button (in your plot) or the 🔒 HUD button: the Laser Gate turns on for
  **60 s + 10 s per rebirth (max +100) + 30 s with the Longer Lock pass**.
- While locked: non-owners can't enter (a force pushes them out at 50 studs/s; anyone inside
  is pushed out over 1 s), and no podium in the plot can be snatched. Friends of the owner can
  enter if the owner turned on "Let friends in" in settings (they still can't snatch).
- After the lock ends: **60 s cooldown** before it can be used again. HUD shows `🔒 0:42` while
  locked and `🔓 Ready in 0:31` during cooldown.
- **Auto-lock on join** for 30 s.
- Leaving the game does not lock your plot; your podiums vanish with you (they're saved).

## 8.6 Dropped items

A dropped nest egg falls to the ground with a bounce, glows, and shows `Pick up (6)` for
**8 s**. Anyone can pick it up (hold 0.5 s); for a nest egg this counts as a steal (the
Guardian, if still chasing, retargets the new carrier). After 8 s it flies back to its pedestal
(or vanishes if a reset happened since).

## 8.7 Tools (PvP)

Tools are custom (not Roblox `Tool` objects, to avoid exploit-prone default behavior): a hotbar
UI with keybinds, server-validated actions.

| Tool | Key (PC / Console / Mobile) | Behavior |
|---|---|---|
| **Mazza (Bat)** | F / R1 / BAT button | Swing in a 7-stud, 100° cone. Hit player: ragdoll 1.2 s, knockback 55, drops whatever they carry. Cooldown 3 s. Can't be used while carrying. Can hit players anywhere, including in plots. |
| **Buccia di Banana (Banana Peel)** | T / Y / PEEL button | Place a peel on the ground at your feet. Up to 3 active per player, 60 s lifetime, visible to all. A player who steps on it slips (ragdoll 2 s) and drops what they carry. A Guardian that steps on it slips for 2 s. The owner can't trip on their own peels. Starts with 3 charges; regain 1 per 30 s; more charges can be bought for cash in the Tool Shop. Can't be placed inside plots or within 20 studs of a nest. |

Bat upgrades in the Tool Shop (cash, permanent, cosmetic + small stat bumps):

| Bat | Cost | Cooldown | Knockback | Look |
|---|---|---|---|---|
| Mazza di Legno | free | 3.0 s | 55 | Wooden bat |
| Mattarello | $50K | 2.8 s | 60 | Rolling pin |
| Baguette Rinforzata | $25M | 2.6 s | 65 | Steel baguette |
| Padella Potente | $5B | 2.4 s | 70 | Frying pan (BONG sound) |
| Salame Spaziale | $1T | 2.2 s | 75 | Glowing space salami |
| Mazza Dorata (pass) | 249 R$ | 2.4 s | 75 | Gold bat with sparkles (never better than the best cash bat combined) |

## 8.8 Ragdoll

Use a lightweight server-triggered ragdoll (BallSocketConstraints replacing Motor6Ds for the
duration, `Humanoid.PlatformStand`), restored afterwards. Never kill the player. Players can't
be ragdolled more than once every 2 s (prevents stun-lock).

## 8.9 Storage and Equip Best

- Storage UI: grid of cards (ViewportFrame icon, name, rarity color, size, kg, mutation,
  $/s), sort (income / rarity / newest / biome), filter (eggs / brainrots / mutations),
  search. Capacity 60 (+40 with VIP).
- Actions per item: Place (choose podium), Favorite ❤️ (protects from bulk sell), Sell, Fuse.
- **Equip Best** button: fills active podiums with the highest-income brainrots (growing eggs
  stay where they are).
- Clicking a podium item in your plot opens a small card: Move to Storage, Swap, Sell.

# 9. Progression

## 9.1 Treadmill tiers

Starting values. Tune them with the simulator (section 20) to hit the time targets; keep the
shape (each tier roughly 3× the gain for 15–40× the price).

| Tier | Name | Look | Speed / s | Cost |
|---|---|---|---|---|
| 1 | Ruota del Criceto | Hamster wheel belt, wooden | 5 | free |
| 2 | Nastro Pizzeria | Pizza-box conveyor | 15 | $2K |
| 3 | Espresso Express | Chrome café belt with steam | 45 | $60K |
| 4 | Neon Notte | Black belt with neon edges | 140 | $1.5M |
| 5 | Dorato | Gold belt, sparkles | 450 | $40M |
| 6 | Gelato Turbo | Ice belt with frost fog | 1.4K | $1B |
| 7 | Quadrifoglio | Clover-green, lucky coins pop out | 4.5K | $30B |
| 8 | Hacker Glitch | Pixel belt, RGB flicker | 15K | $1T |
| 9 | Vulcano | Lava belt, embers | 50K | $40T |
| 10 | Cervello Cosmico | Pink brain belt, galaxy particles | 160K | $1.5Qa |

Buying a tier replaces your treadmill model (plays a build animation). Shown in the upgrade
terminal and at the treadmill itself ("Upgrade: $60K → +45/s").

## 9.2 Trails

Bought in the Trails Shop with cash. Equipped trail multiplies treadmill gain and shows a
`Trail` behind the player. All owned trails are kept on rebirth.

| Trail | Mult | Cost | Visual |
|---|---|---|---|
| Scia di Farina | ×1.1 | $5K | White flour puff |
| Briciole | ×1.25 | $100K | Bread crumbs |
| Sugo | ×1.5 | $2M | Red sauce swirl |
| Gelato | ×1.8 | $50M | Pastel drips |
| Glitter | ×2.2 | $1B | Gold glitter |
| Lava | ×2.7 | $25B | Orange embers |
| Disco | ×3.3 | $800B | Rainbow light dots |
| Glitch | ×4 | $25T | Pixel squares |
| Galassia | ×5 | $1Qa | Stars |
| Arcobaleno Divino | ×6.5 | $50Qa | Rainbow beam with sparkles |

## 9.3 Base upgrades (active podium slots)

| Active slots | Cost |
|---|---|
| 7 (start) | – |
| 8 | $500 |
| 9 | $25K |
| 10 | $500K |
| 11 | $10M |
| 12 | $250M |
| 13 | $5B |
| 14 | $100B |
| 15 | $2T |
| 16 | $50T |
| 17 | $1Qa |
| 18 | $25Qa |

Upper-floor podiums come from rebirths (+1 each, max 12) and the **+3 Slots** pass (uses
upper-floor podiums 10–12; the upper floor appears if the player has either).

## 9.4 Rebirth

Rebirth resets: cash, Speed, treadmill tier, base upgrade level, all brainrots and eggs
(placed and in Storage, except **favorited Exclusives**, which are kept), active boosts.
Rebirth keeps: trails, bat upgrades, Index, Gettoni, codes, quests and Pass progress, daily
streaks, gamepasses, settings, badges.

| # | Requirement | Income mult (total) | Start Speed | Rewards | Title |
|---|---|---|---|---|---|
| 1 | $100M + own Anaconda Al Dente + Re Lasagnone | ×1.5 | 1K | +1 upper slot, +10 s lock, upper floor appears | Brainrottino |
| 2 | $5B + Mammut Spumone + Gelatissimo Glaciale | ×2.0 | 12K | +1 slot, +10 s lock, +1 peel capacity | Brainrottone |
| 3 | $250B + Castoro Calzino + Tacchino Tacco Imperiale | ×2.5 | 50K | +1 slot, +10 s lock, +5% luck | Pazzo Totale |
| 4 | $10T + Dromedario Timer + Faraone Forno Fantasma | ×3.0 | 200K | +1 slot, +10 s lock | Re del Caos |
| 5 | $500T + Ciclope Cotoletta + Imperatore Lavalasagna | ×3.5 | 800K | +1 slot, +10 s lock, +5% luck | Cervello Fritto |
| 6 | $20Qa + Gattonauta Groove + Re Discobolo Galattico | ×4.0 | 3M | +1 slot, +10 s lock | Maestro Meme |
| 7 | $1Qi + Orso Errore 404 + Glitchone Supremo | ×4.5 | 20M | +1 slot, +10 s lock, +5% luck | Glitch Lord |
| 8 | $50Qi + Quokka Quasar + Pecorella Pianeta | ×5.0 | 800M | +1 slot, +10 s lock | Cosmico |
| 9 | $2Sx + Calamaro Celeste + Omnirotto Supremo | ×5.5 | 3B | +1 slot, +10 s lock, +5% luck | Supremo |
| 10 | $100Sx + Omnirotto Supremo (Huge or bigger) + any brainrot with Mega Bloom | ×6.0 | 3B | +1 slot, +10 s lock, rainbow name tag | Leggenda Brainrot |
| 11+ | previous cash × 20, any 2 Divines | +0.5 each | 3B | +1 slot until 12 total | Leggenda +N |

- Rebirth speed multiplier for the treadmill: `1 + 0.25 × rebirths`.
- The Rebirth UI shows each requirement with a ✅/❌, the exact rewards, a big list of what you
  will **lose** and **keep**, and a two-step confirm ("Rebirth" → "Yes, I'm sure"). A
  celebratory cutscene plays (screen flash, confetti, title reveal) and is announced to the
  server.
- Requirement brainrots are matched by species and must be in your plot or Storage.

# 10. Index (collection book)

- Tabs per biome (8 silhouettes each, filled in when discovered), plus Classics (if enabled),
  Exclusives and Mutations.
- **Discovery** = hatching a species for the first time (or receiving it). Reward: Speed equal
  to `30 s × rarity rank × your current per-second treadmill gain`, plus `rarity rank × 5`
  Gettoni. A big "NEW!" stamp animation.
- **Biome page complete** (all 8 originals): permanent +2% income (max +20%), a badge, and that
  biome's colored name glow cosmetic.
- **Mutation index:** first time you own any brainrot with each mutation → 25 Gettoni.
- **Full original roster (80):** "Index Master" title, crown cosmetic, permanent +5% luck.
- The Index shows undiscovered species as black silhouettes with "Found in: Gelato Glacier ·
  Mythic" so players know what to hunt.

# 11. Fuse Machine

- Put **3 brainrots of the same species** into the trays (any sizes/mutations), pay
  `60 × the best one's income` cash, press the big FUSE lever: the blender shakes, lights flash,
  and outputs an egg into the glass jar.
- Result: **70%** an egg of a random species **one rarity higher**, from the same biome if that
  biome has it, otherwise the next biome; **30%** a **Giant**-size egg (r rolled in the Giant
  bracket) of the same species. The output egg keeps the best mutation of the inputs.
- Special recipe: 3 **Secret** brainrots of **different** species → 1% Fusione Frankenstein
  (X10), otherwise an Eternal egg from the highest biome among the inputs.
- Fusion can't take favorited items unless the player un-favorites them first.
- Show the possible outcomes and odds in the Fuse UI before confirming.

# 12. First-time user experience (tutorial)

The first 5 minutes decide retention. Script it exactly. A **guide beam** (Beam from the player
to the target) and a single short instruction line at the top center drive each step. Each
step completes on the real action, never on a "Next" button.

| Step | Instruction | Completes when | Reward / note |
|---|---|---|---|
| 1 | "Steal an egg from Nonna's nest! 🥚" (beam to biome 1 nest) | player picks up a nest egg | Nonna wakes but uses tutorial mercy |
| 2 | "RUN home! Cross the Safe Line!" (beam to the Safe Line, then plot) | egg auto-placed on a podium | Confetti, "Your first egg!" |
| 3 | "It's growing… 🐣" (camera gently frames the podium) | egg hatches (≤ 10 s) | Full reveal sequence + chant |
| 4 | "Step on the green pad to collect cash" | first collect | Welcome gift: +$1,500 |
| 5 | "Run on your treadmill to get faster ⚡" | 15 s on the treadmill | +300 Speed bonus |
| 6 | "Buy a faster treadmill!" | treadmill tier 2 bought | – |
| 7 | "Spin the wheel for a free prize! 🎡" | first spin | First spin is rigged to a good result: "2× Speed Boost 10 min" (disclosed odds still apply to all later spins; this first spin is a tutorial gift, labelled as such) |
| 8 | "Free gifts appear while you play! 🎁" (points at the gift button) | first playtime gift claimed | – |
| — | Contextual: the first time another player approaches your plot | – | Tip: "Someone's coming! Press 🔒 to lock your base!" |
| — | Contextual: the first time the player is near the biome-2 gate below recommended speed | – | Tip: "Too slow for the Squalo! Get faster first." |

Tutorial state is saved per step; rejoining resumes it. A "Skip tutorial" option appears in
Settings after step 3.

# 13. Retention design (why players stay and come back)

Build every system below. First, understand the loops they serve, so you make good calls on
details:

| Loop | Time scale | What pulls the player | Systems |
|---|---|---|---|
| **Moment** | 10–60 s | A chase, a steal, a hatch reveal, a rare egg beam in the sky | Guardians, PvP, hatch reveal, announcements |
| **Session** | 5–60 min | The next treadmill/trail/slot upgrade; the next playtime gift; the next egg reset (every 5 min); quests | Upgrades, playtime gifts, resets, daily quests, free hourly spin |
| **Daily** | 1 day | Login streak reward, monthly stamp, daily quests, daily free spin, daily hidden gifts | Daily rewards, stamp card, quests, spin wheel |
| **Weekly** | 1 week | Weekly quests, Admin Abuse on Saturday, weekly leaderboards | Weekly quests, events, leaderboards |
| **Season** | 4 weeks | Brainrot Pass tiers and its exclusive brainrots; monthly calendar exclusive; new update | Pass, stamp card, live updates |
| **Long term** | months | Rebirths, Index completion, Divine hunting, titles | Rebirth, Index, mutations, Fuse |

Principles:
1. **A visible timer for everything.** Next reset, next gift, next free spin, next Admin Abuse,
   pass season end. Players plan around timers.
2. **Red-dot badges** on every HUD button that has something claimable. Nothing claimable is
   ever hidden more than one tap away.
3. **Rewards scale to progress.** Never give flat "$1,000" to a player earning $1B/s. Cash rewards
   are expressed as "N minutes of your current income" (with a floor), Speed rewards as "N
   seconds of your treadmill gain" (with a floor), eggs as "an egg from your best unlocked biome".
4. **Generous early, steady later.** The first 10 minutes give something every minute.
5. **Losing is never the end of the session.** After a big steal against you, show a "Get it
   back!" tip (the thief's plot arrow) and a small consolation ("Insurance: +5 min income").
6. **No dark patterns.** No fake countdowns, no "only 2 left!", no purchase popups that open by
   themselves (except one welcome Starter Pack offer per player lifetime, closable, see 16.3),
   no punishments for not paying, no loot boxes in regions where they're restricted.

# 14. Retention systems

## 14.1 Daily login streak (7-day cycle)

- A "day" is a UTC day (`os.date("!*t")`). Claim from the Daily Rewards board or the 📅 HUD
  button; the popup opens automatically **once** on the first join of a new day.
- Logging in on consecutive days advances the streak. Missing a day resets to Day 1, unless the
  player has a **Streak Freeze** (one is granted free every Monday, max 2 stored; more from the
  Pass), which is used automatically. A lost streak can be restored within 48 h with the
  **Streak Restore** product (49 R$), offered as a button, never as a popup.
- The cycle repeats after Day 7; each completed cycle increases rewards by 10% (cap +100%).

| Day | Reward |
|---|---|
| 1 | 10 min of income (min $500) |
| 2 | 1 Spin + 3 banana peels |
| 3 | 20 min of income + 25 Gettoni |
| 4 | 2× Speed Boost (15 min) + 2× Luck (15 min) |
| 5 | An egg from your best unlocked biome (guaranteed Rare or better within that biome's range) |
| 6 | 2 Spins + 50 Gettoni |
| 7 | **Big Chest**: an egg from your best biome rolled with 3× luck + 60 min of income + 3 Spins |

## 14.2 Monthly stamp card

- Each calendar month (UTC) has a 28-stamp card. Every day you log in = 1 stamp (not
  consecutive, so missing days never resets it).
- Milestones: 7 stamps → 100 Gettoni; 14 → 3 Spins + Gold Mutation Potion; 21 → an egg from
  your best biome with 5× luck; **28 → Calendarino Mensile** (X5, the month's exclusive look).
- The card shows the month's exclusive at the end so players see what they're collecting.

## 14.3 Playtime gifts (timed gifts)

- 12 gifts that unlock by **minutes played today** at **1, 3, 5, 8, 11, 15, 20, 25, 30, 40, 50,
  60** minutes. Progress continues across rejoins on the same UTC day (stored in the profile).
  After all 12 are claimed a new cycle starts; **max 3 cycles per day**, then the button shows
  "Come back tomorrow! 🎁".
- The 🎁 HUD button shows the countdown to the next gift and pulses when one is ready. The gifts
  window shows all 12 as boxes with their timers; ready ones bounce.
- Gifts must be claimed by clicking; unclaimed ready gifts stay claimable all day.

| # | Unlocks at | Reward |
|---|---|---|
| 1 | 1 min | 3 min of income (min $300) |
| 2 | 3 min | 60 s of treadmill gain as Speed (min 200) |
| 3 | 5 min | 3 banana peels + 10 Gettoni |
| 4 | 8 min | 5 min of income |
| 5 | 11 min | 2× Speed Boost (5 min) |
| 6 | 15 min | **1 Spin** |
| 7 | 20 min | 10 min of income |
| 8 | 25 min | 2× Luck (10 min) |
| 9 | 30 min | An egg from your best biome |
| 10 | 40 min | 120 s of treadmill gain as Speed + 25 Gettoni |
| 11 | 50 min | 20 min of income |
| 12 | 60 min | **Mega Gift**: 2 Spins + an egg from your best biome with 3× luck + 5% chance of Nonno Cronometro (X4) |

## 14.4 Quests

### 14.4.1 Daily quests
- 3 quests per UTC day, drawn from a pool weighted to the player's progress (no "steal from
  biome 7" for someone who can't reach it). 1 free reroll per day per quest. A 4th "bonus" quest
  unlocks when the 3 are done.
- Each quest gives: Pass XP (150), Gettoni (15–30) and a scaled cash or Speed reward.
- Pool (each with tiered targets by progress): Steal N eggs from nests; Steal an egg from biome
  ≥ X; Hatch N eggs; Hatch a Rare+/Epic+/… brainrot; Collect $N; Run N seconds on the
  treadmill; Bat N thieves while they carry your items; Successfully snatch from a player;
  Defend your base (bat someone inside your plot); Spin the wheel; Fuse once; Sell a brainrot;
  Play N minutes; Catch a dropped egg; Escape a Guardian with a Big or larger egg.

### 14.4.2 Weekly quests
- 5 harder quests per week (resets Monday 00:00 UTC), e.g. "Hatch 3 Mythic or better",
  "Steal 50 eggs", "Complete 15 daily quests", "Win 3 Rift Boss fights", "Reach a new biome".
- Rewards: Pass XP (600 each), 100 Gettoni, Spins; finishing all 5 gives a **Weekly Chest**
  (egg from your best biome with 5× luck).

### 14.4.3 Milestone achievements
Permanent achievements with badges: first steal, first snatch, first Mythic, first Divine,
10/100/1000 nest steals, each biome reached, each rebirth, Index pages, 7-day streak, 30
stamps, defend 100 times, etc. Achievements pay Gettoni once.

### 14.4.4 The Lost Recipe questline (one-time story)
Nonna Segreta (secret cave, 3.6) asks you to find 5 lost recipe pages hidden in biomes 1, 3,
5, 7 and 9 (glowing scrolls at fixed spots, visible only after accepting). Returning all 5 gives
the **Mestolo d'Oro** (golden spoon) bat skin and 500 Gettoni. A template for future story
quests: write it data-driven (`Quests.Story`).

## 14.5 Spin Wheel (Ruota della Fortuna)

- 10 segments, sizes drawn proportional to odds, with odds printed in the UI under the wheel.
- **Free spins:** 1 every UTC day + 1 for every **60 minutes played** (stockpile max 3), plus
  spins from gifts, streaks, quests and the Pass.
- **Paid spins** (dev products): 1 for 49 R$, 5 (+1 bonus) for 199 R$, 15 (+5 bonus) for
  499 R$. **Pity:** the 100th paid spin since the last jackpot is guaranteed Jackpot; the
  counter is shown ("Jackpot guaranteed in 63 paid spins").
- Every spin plays on the physical wheel in the piazza too, and a Jackpot is announced to the
  server.

| Segment | Reward | Chance |
|---|---|---|
| Cash S | 5 min of income | 24% |
| Cash L | 20 min of income | 14% |
| Speed | 90 s of treadmill gain | 14% |
| Speed Boost | 2× Speed 10 min | 10% |
| Luck Boost | 2× Luck 15 min | 10% |
| Peels | 5 banana peels + 20 Gettoni | 9% |
| Egg | Egg from your best biome | 11% |
| Gold Potion | Applies Gold mutation to a chosen brainrot (only if better) | 5% |
| Respin | Spin again | 2.8% |
| **JACKPOT** | Ruotino Fortunato (X1) or, if owned, a Mythic+ egg from your best biome + 3 Spins | 0.2% |

- **Policy:** before showing paid spin buttons, call
  `PolicyService:GetPolicyInfoForPlayerAsync(player)`; if `ArePaidRandomItemsRestricted` is
  true, hide all paid spins (free spins remain). The odds table is always visible before any
  purchase.

## 14.6 Brainrot Pass (season pass)

- Seasons last **28 days** and have a theme (Season 1: "Pizza Party"). 40 tiers, **1,000 XP**
  per tier. Countdown to season end always visible in the Pass UI.
- XP sources: daily quests (150 each, bonus quest 300), weekly quests (600 each), playtime
  (10 XP per minute, max 600/day), Rift Boss participation (100), first egg each reset that you
  bring home from your best biome (25, max 20/day).
- **Free track** reward every tier (cash, Speed, Spins, Gettoni, peels, eggs; tier 25 =
  Passaporto Pinguino X8). **Premium track** (399 R$, game pass-like product bought per season)
  adds a second reward at every tier: more spins, potions, boosts, a pass-only trail at tier 15,
  a name color at tier 30, and **Premium Pavone (X9) at tier 40**.
- Tier skips: 1 tier 49 R$, 10 tiers 349 R$ (only premium owners can buy skips, and skips can't
  exceed the tier you could reach with the days left × 600 XP + quests, so it never looks
  pointless to play).
- Unclaimed rewards at season end are auto-delivered. Season config is data-driven:
  `BrainrotPass.Seasons[n] = { Id, Name, StartUtc, EndUtc, Tiers = {...} }`.

## 14.7 Gettoni Shop

A rotating shop (refreshes every 6 hours, synced across servers by the time slot) selling, for
Gettoni: eggs from your best biome (with luck), Gold/Diamond mutation potions, boosts, banana
peel packs, Streak Freezes, trail colors, name tag colors, emotes. Some items have a purchase
limit per rotation. The shop always shows when it refreshes.

## 14.8 Group, social and invite rewards

- **Free Gift box** (piazza, 3.3): joining the game's Roblox group gives **+10,000 Speed** and a
  "Fan" chat tag once (`player:IsInGroupAsync(GroupId)`, checked on claim). Do **not** give
  rewards for likes or favorites (not verifiable and against the spirit of Roblox rules); you
  may *ask* players to like the game in the gift popup text.
- **Friend boost:** +10% income per friend in the same server (max +40%), shown in the HUD
  (👥 +20%).
- **Invites:** an "Invite Friends" button using `SocialService:PromptGameInvite`. When an invited
  friend joins for the first time (detected through the join data / `GetJoinData` referral),
  both get 2 Spins.
- **Follow-the-game prompts:** none forced; one "Turn on notifications" button in Settings if
  Roblox Experience Notifications are configured (`docs/LIVE_OPS.md`).

## 14.9 Welcome-back gift

If a player returns after **3 or more days** away, give a "We missed you!" gift: an egg from
their best biome with 3× luck, 2 Spins and 30 minutes of income, plus the normal offline
earnings popup.

## 14.10 Hidden daily gifts

The Rooftop Café gift and the Freezer Room chest (3.6) reset daily. Finding them the first time
gives a badge. Good for curiosity and for YouTube "secret" videos.

## 14.11 Leaderboards

- **Global** (OrderedDataStore, refreshed every 120 s, top 10): Most Money (all-time cash
  earned), Most Stolen (nest + snatches), Highest Speed, Most Rebirths. Physical boards in the
  piazza (3.3) with avatar headshots; #1 gets a gold crown over their head in game.
- **Weekly** versions (key per week) shown as a second page on each board.
- **In-server** `leaderstats`: 💰 Cash (formatted), ⚡ Speed, 🔄 Rebirths.

## 14.12 Codes

Codes kiosk on the fountain. Codes are case-insensitive, one use per player, with optional
expiry (`Codes.luau`: `{ Code, Rewards, ExpiresUtc? }`). Launch codes: `BRAINROT` (2 Spins),
`PIZZA` (X11 Codino Coraggioso), `RELEASE` (30 min income + 2× Luck 15 min). Admins can add
codes live through the admin panel (stored in a DataStore and broadcast).

## 14.13 Notifications in game

A single toast/banner system (top center for banners, right side for toasts, max 3 visible,
queue the rest). Categories with their own color and sound: reward, steal alert, rare spawn,
event, system. Settings let players mute categories (except steal alerts).

# 15. Events and live ops

All scheduled events are computed from UTC time, so every server agrees without
communication. Admin-triggered events use `MessagingService` to reach every server, with a
`MemoryStoreService` sorted map storing the active event so servers that start later can join it.

## 15.1 Weather events (random, per server)

Every **20–40 minutes** (random per server) one weather event runs for **4 minutes**. A
banner announces it 30 s early, with sky/lighting changes, particles and music sting.

| Event | Effect | Visual |
|---|---|---|
| **Pasta Rain** | Nest eggs that spawn during it get Saucy (20%) | Noodles and sauce drops fall from the sky |
| **Meteor Shower** | Cosmic Dust mutation (15%); meteors crash into the piazza and leave 3 free eggs from random biomes ≤ the server's average best biome (first come, first served) | Purple sky, streaking meteors |
| **Glitch Storm** | Glitched mutation (10%); Guardians glitch-freeze for 1 s every 10 s | Screen chromatic flicker (respects reduced-motion setting) |
| **Brain Freeze** | Frozen mutation (25%); everything outside plots is slippery | Snow, blue tint |
| **Disco Fever** | Disco mutation (15%); treadmill gain ×2 | Disco lights, music change |
| **Golden Hour** | Natural Gold chance ×3; cash income ×1.5 | Warm golden light |

## 15.2 Admin Abuse (weekly, cross-server)

- **Every Saturday 17:00–18:00 UTC** (weekend afternoon in Europe, morning in the US). A
  countdown appears in the HUD 24 h before, and a big banner 10 min before.
- During the hour an "admin" NPC (Adminello) stands on the Event Stage and the server runs a
  scripted show (the same in all servers, keyed to minutes after start):
  - Minutes 0–10: **Egg Rain** — eggs from all biomes fall across the piazza every 20 s;
    rare chance of Adminello Abusivo (X7) eggs.
  - 10–20: Every weather event active at once (all event mutations possible).
  - 20–30: **3× Luck**, 2× Cash for everyone.
  - 30–40: **Admin Mutation** chance (1%) on all nest eggs; announced on hit.
  - 40–50: Guardians asleep and can't wake ("Nonna is on holiday"); treadmill ×3.
  - 50–60: **Finale**: a giant egg piñata on the stage; hitting it with bats drops eggs for
    everyone who hit it.
- Admins (owner or `AdminUserIds`) can also start an Admin Abuse at any time from the admin
  panel for all servers.
- Every Admin Abuse ends with a short "Next update…" teaser banner if `Events.NextUpdateTeaser`
  is set.

## 15.3 Rift Boss (every 45 minutes, per server)

- 60 s warning: the Event Portal swirls, banner "🌀 THE RIFT IS OPENING". Players in the
  piazza walk in to join (max 7, everyone can).
- Boss: **Il Re Corrotto**, a giant corrupted pizza-tower king in the Rift Arena (3.7).
  - **Phase 1 (crystals):** 4 shield crystals; players hit them with bats (each 20 hits,
    scaled by players present). The boss throws telegraphed pizza-slice shockwaves (jump them).
  - **Phase 2 (core):** the boss kneels; hit its glowing crown (100 hits scaled) while dodging
    falling meatballs (shadows show where).
  - 4-minute time limit. Players who get hit are knocked back, not killed.
- Rewards for everyone who dealt ≥ 5% of hits: Rift Egg (Corrupted mutation 5%, Riftone
  Corrotto X6 2%), 200 Gettoni, 100 Pass XP, and the "Rift Breaker" badge on first win.
- Failure: a consolation of 50 Gettoni.

## 15.4 Seasonal events (limited time)

Data-driven event framework in `Config/Events.luau`:

```lua
{
	Id = "Halloween2026",
	StartUtc = ..., EndUtc = ...,
	Currency = "Candy",              -- event currency earned from event eggs, quests, gifts
	ShopItems = { ... },             -- spend Candy: exclusive eggs, mutation potions, trail
	NestOverrides = { ... },         -- extra species / mutation in nests
	MapDecor = "Halloween",          -- decor module that adds pumpkins, cobwebs, fog
	Quests = { ... },                -- event quest chain
	Mutation = "Spooky",             -- event mutation
}
```

Ship two complete events in the launch build, disabled by default, so the live team only flips
dates:
1. **Halloween "Brainrot da Brivido"**: Spooky mutation (×3), pumpkin decor, Candy currency,
   3 event brainrots (Zucca Zombino, Fantasmino Fettuccine, Pipistrello Pignolo), an event
   egg in the shop.
2. **Winter "Natale Brainrot"**: Frosty mutation (×3), snow decor, Cookie currency, 3 event
   brainrots (Panettone Pinguone, Renna Ravioli, Babbo Biscotto), advent calendar of 12
   daily gifts.

## 15.5 Traveling Merchant

Every **2 hours** (UTC aligned) the merchant (Mercante Misterioso, X12 look) arrives at the
piazza for **10 minutes**. He sells 4 items for cash at fair prices (eggs from biomes the player
can reach with 2–5× luck, mutation potions), and with 5% chance a 5th "rare stock" slot with his
own egg (X12). Purchase limit 1 per item per visit.

## 15.6 Server Luck

A dev product that doubles/quadruples/octuples rare-egg weights for **everyone in the server**
for 15 minutes. Announced with the buyer's name ("Leo123 activated 4× Server Luck! 🍀"),
stacks in duration not in multiplier. Great for social buzz.

## 15.7 Live ops tools

- **Admin panel** (owner and `AdminUserIds` only, verified on the server for every action): give
  cash/Speed/items to self (Studio only for others), spawn eggs, start/stop any event in this
  server or all servers, start Admin Abuse globally, add/remove codes, broadcast a message,
  kick/ban exploiters (ban list in a DataStore, use `Players:BanAsync` where available).
- **Config hot values:** a small `LiveConfig` DataStore key read every 5 minutes for values the
  team may want to change without a release (event multipliers, announcement text, code list).
- **Analytics:** `AnalyticsService` custom events and funnels: tutorial steps (funnel),
  first biome reached times, rebirths, purchases (economy events for cash/Gettoni
  sources/sinks), quest completion, retention-relevant events (gift claims, spins).

# 16. Monetization

Fair, standard for the genre, nothing that makes stealing un-counterable. Every ID lives in
`Config/Monetization.luau`; items with `Id = 0` are hidden so the game works before products
exist. Prices are suggestions.

## 16.1 Game passes

| Pass | Price | Effect |
|---|---|---|
| VIP | 399 R$ | ×1.5 income, VIP chat tag + gold name, 12 h × 50% offline earnings, +40 Storage, +10 s lock |
| 2× Money | 449 R$ | ×2 income |
| 2× Growth | 349 R$ | Eggs hatch 2× faster |
| 2× Speed Gain | 299 R$ | Treadmill gain ×2 |
| Auto Collect | 199 R$ | Cash goes straight to your wallet |
| +3 Slots | 299 R$ | 3 extra upper-floor podiums |
| Longer Lock | 149 R$ | +30 s Base Lock |
| Mazza Dorata | 249 R$ | Golden bat (8.7) |
| Extra Peels | 99 R$ | +3 banana peel capacity, faster recharge (20 s) |

## 16.2 Developer products

| Product | Price | Effect |
|---|---|---|
| Speed Pack S / M / L / XL | 29 / 99 / 299 / 899 R$ | Speed = 10 / 40 / 150 / 500 minutes of your best treadmill gain (shown as a number before buying) |
| Cash Pack S / M / L | 49 / 149 / 449 R$ | 30 / 120 / 480 minutes of income |
| Grow All | 99 R$ | Instantly hatch every growing egg in your plot (shows how many) |
| Instant Hatch (per egg) | 9–199 R$ by rarity | Button on a growing egg's card |
| Server Luck 2× / 4× / 8× | 199 / 599 / 1799 R$ | 15 min, whole server (15.6) |
| Personal Luck 2× | 79 R$ | 15 min |
| Spins 1 / 5+1 / 15+5 | 49 / 199 / 499 R$ | Spin Wheel (14.5) |
| Golden Egg | 99 R$ | Gacha egg: odds shown (Spaghettino Smeraldo 10%, Dollarino Dorato 2%, else a best-biome egg rolled with 5× luck) |
| Brainrot Pass Premium | 399 R$ | Current season (14.6) |
| Tier Skip 1 / 10 | 49 / 349 R$ | (14.6) |
| Streak Restore | 49 R$ | (14.1) |
| Offline ×2 | 25 R$ | (7.2) |
| Starter Pack | 99 R$ | One-time: $ + Speed worth ~1 h, 3 Spins, 1 Golden Egg, exclusive "Starter" name tag |

## 16.3 Offer presentation

- The **Shop** (🛒 HUD button) has tabs: Featured, Passes, Speed, Cash, Luck, Spins, Pass.
- The **Starter Pack** is shown once as a closable popup after the tutorial finishes (never during
  it), then lives in Featured for 72 h of that player's playtime with an honest countdown.
- Contextual "Get it now" buttons appear where useful (Grow All on a long hatch, Speed Pack
  next to a biome gate the player is too slow for) — buttons only, never auto-prompts.
- Each pass card shows exactly what it does with numbers.

## 16.4 Purchase processing

- `MarketplaceService.ProcessReceipt` must be **idempotent**: store processed `PurchaseId`s in
  the profile (keep the last 200), grant, save, then return `PurchaseGranted`. If the profile
  isn't loaded, return `NotProcessedYet`.
- Game passes: check `UserOwnsGamePassAsync` on join (cached) and on
  `PromptGamePassPurchaseFinished`.
- Never trust the client about what was bought.

# 17. Safety, fairness and policy

1. **Paid random items:** odds visible before purchase for Spins, Golden Egg, and anything else
   random; gate them with `PolicyService` (`ArePaidRandomItemsRestricted`).
2. **Chat and text:** every player-written text (none planned besides chat) goes through
   `TextService:FilterStringAsync`. Plot signs show only display names.
3. **No pay-to-win beyond conveniences:** passes speed up progress but can't bypass the lock,
   shield or last-two rule. The paid bat is never stronger than the best cash bat.
4. **Anti-griefing:** new-player shield, last-two rule, snatch cooldown, ragdoll cooldown,
   spawn safety, peel limits (8.4, 8.7, 8.8).
5. **Anti-exploit** (19.4).
6. **Comfort settings:** reduce motion (no screen shake/flash/chromatic), mute music/SFX
   separately, hide others' trails, low-graphics mode (no particles, simpler lighting),
   colorblind-friendly rarity icons (each rarity also has a shape icon, not only a color).
7. **Age-appropriate content:** cartoon humor only. No crude memes, no violence beyond cartoon
   bonks, no gambling language like "bet" or "casino".

# 18. UI, audio and game feel

## 18.1 HUD layout (all built in code, scaled with `UIScale` by viewport size)

```
┌──────────────────────────────────────────────────────────────────┐
│ [💰 $1.24M  +$3.2K/s]  [⚡ 12.4K]     🥚 New eggs in 2:41      [⚙]│
│                        [banner area: events, biome names]         │
│ [🛒 Shop]                                              [toasts]  │
│ [🎁 Gifts 0:42]                                        [toasts]  │
│ [🎡 Spin ●3]                                                      │
│ [📅 Daily ●]                                                      │
│ [📜 Quests ●]                                                     │
│ [🎟 Pass]                                                         │
│ [📖 Index ●]                                                      │
│ [🔄 Rebirth]                                                      │
│ [📦 Storage]                                                      │
│                                                                  │
│  [boost timers ⚡2× 4:10 🍀2× 8:20 👥+20%]                        │
│          [ 1 Bat ] [ 2 Peel ●3 ]        [🔒 LOCK]  [DROP]        │
└──────────────────────────────────────────────────────────────────┘
```

- Left column of round icon buttons (64 px on desktop, 56 on phones), each with a red-dot badge
  when something is claimable and a tiny timer under it when relevant.
- Top-left: cash (big, bold) with income per second under it, Speed beside it.
- Top-center: reset countdown; banners slide down below it.
- Right: toasts.
- Bottom: hotbar, Lock button, Drop button (only while carrying). On mobile, the Bat/Peel
  buttons sit above the jump button in Roblox's thumb zone.
- Console: every window is navigable with the gamepad (`GuiService.SelectedObject`, a visible
  selection ring), B closes, shoulder buttons switch tabs.
- Windows: one at a time, centered, rounded (UICorner 16), chunky outline (UIStroke 3, dark),
  big close button, open/close tween (scale 0.9→1, 0.15 s, Back easing).

## 18.2 Visual style

- Bright, saturated, cartoony. Font: `Enum.Font.FredokaOne` for headers and numbers,
  `Enum.Font.GothamBold` for body. Text always has a dark UIStroke for readability.
- Theme colors in `Config/Theme.luau` (tokens: Primary, Accent, Good, Bad, Warning, Panel,
  PanelDark, Text, TextDim, plus rarity colors).
- Every brainrot speaks its **chant** in a speech bubble on hatch and every ~45 s when the owner
  is nearby. Use `AudioTextToSpeech` if available in your Roblox version to voice the chant
  with an Italian-sounding voice; otherwise play a per-rarity jingle and show the bubble. Keep
  a `Sounds.Chants[Id]` override slot for uploaded voice lines later.

## 18.3 The hatch reveal (most important 4 seconds in the game)

1. Egg wobbles three times, faster each time (0.3 s, 0.25 s, 0.2 s), small cracks appear.
2. Camera nudges toward the podium (only if the player is within 60 studs; respects reduce
   motion).
3. Egg bursts: confetti in the rarity color, a radial light flash, a "POP" sound + rarity
   jingle (longer and bigger for higher rarities).
4. The brainrot scales up from 0 with an overshoot, says its chant.
5. A banner card drops: species name, rarity (animated gradient for Cosmic+), size and kg,
   mutation, `$/s`, and "NEW!" if it's an Index discovery.
6. Secret and above: screen-wide darkening for 0.5 s, a dramatic sting, and a server/global
   announcement.

## 18.4 Other feel details

- Cash pile on collect pads grows in 4 visual stages. Collecting flies coin particles to the
  cash counter, which ticks up.
- Speed gains pop `+45 ⚡` numbers. Upgrades play a build/sparkle effect.
- Steals: a "SWOOSH" when you grab, a heartbeat sound while chased, a triumphant sting when you
  cross the Safe Line.
- Guardian waking: a big "!" above it, a roar and a short camera shake (respects reduce motion).
- Footstep and ambience sounds per biome; music crossfades per biome and in the piazza.
- Every sound ID lives in `Config/Sounds.luau`. Use Roblox's free audio library; leave
  placeholder IDs (0) where you can't find one and list them in `docs/STUDIO_SETUP.md`.

# 19. Architecture

## 19.1 Services (server, `Services/`)

Boot order is explicit in `Main.server.luau`; each service has `Init()` (no yields, wire
dependencies) and `Start()`.

| Service | Responsibility |
|---|---|
| `DataService` | ProfileStore sessions, schema defaults, migrations by `DataVersion`, autosave every 60 s, release on leave, `BindToClose` flush |
| `PlotService` | Plot assignment on join (first free), podium state, auto-place, collect pads, Collect All, base upgrades, upper floor, plot sign |
| `SpeedService` | Speed stat, WalkSpeed calc, treadmill ticking, boosts, slows |
| `NestService` | Reset clock, rolling eggs, pedestals, steal prompts, Night |
| `GuardianService` | State machines, chase, abilities, catches |
| `CarryService` | Carry state, welds, safe line, delivery, drops, dropped items |
| `SnatchService` | Plot steals, alerts, return-on-fail, shields, cooldowns |
| `LockService` | Base lock, laser gates, push-out |
| `ToolService` | Bat, peels, hit validation, ragdoll |
| `HatchService` | Growth timers, hatch, reveal events, Index discovery |
| `IncomeService` | Per-second income, pending cash per podium, offline earnings |
| `InventoryService` | Storage, favorite, sell, equip best |
| `FuseService`, `BloomService` | Fuse Machine, Bloom Machine |
| `RebirthService` | Requirements, reset, rewards |
| `IndexService` | Discoveries, page rewards |
| `RewardService` | Single place that grants any reward table (cash/speed scaled, eggs, spins, boosts, items) — every other system calls it |
| `DailyService` | Streak, stamps, welcome back |
| `GiftService` | Playtime gifts |
| `SpinService` | Spin wheel rolls, pity, physical wheel |
| `QuestService` | Daily/weekly/achievements/story; progress events via a shared signal bus |
| `PassService` | Season, XP, tiers, claims |
| `ShopService` | Cash shop (treadmills, trails, bats, peels), Gettoni shop rotation |
| `EventService` | Weather, Admin Abuse, Rift Boss, seasonal, merchant, server luck |
| `MonetizationService` | Passes, products, receipts |
| `LeaderboardService` | OrderedDataStores, boards, crowns, leaderstats |
| `CodeService`, `AdminService`, `AnalyticsService` (wrapper), `AntiExploitService`, `TutorialService`, `NotifyService` |

Client controllers mirror these (HUD, Windows, Carry FX, Guardian FX, Tools input, Hatch
reveal, Spin, Gifts, Quests, Pass, Index, Storage, Shop, Settings, Tutorial, Biome ambience).

## 19.2 Networking

- One module, `Shared/Net/Remotes.luau`, declares every remote by name with typed send/receive
  wrappers, so a typo is a type error. Use `RemoteEvent` for actions, `RemoteFunction` only for
  window data requests (with server timeouts), `UnreliableRemoteEvent` for cosmetic FX.
- **State replication:** the server keeps each player's replicated state (cash, speed,
  boosts, timers, claimables) and sends diffs at most 4 times per second. Plot podium
  displays use attributes on the podium parts so every client sees them without remotes.
- All remotes are rate-limited per player (default 10/s) and validate argument types.

## 19.3 Saved data (profile schema, version 1)

```lua
{
	DataVersion = 1,
	Cash = 0, TotalEarned = 0, Speed = 0, Gettoni = 0,
	TreadmillTier = 1, OwnedTrails = {}, EquippedTrail = nil, BatTier = 1, Peels = 3,
	ActiveSlots = 7, Rebirths = 0,
	Items = { -- keyed by a GUID
		[uid] = { Kind = "Egg" | "Brainrot", Species = "PomodorinoPedalino", Ratio = 1.23,
		          Mutation = nil, Location = "Podium" | "Storage", Slot = 3, Floor = 0,
		          PlacedAt = 0, HatchAt = 0, Favorite = false, Source = "Nest" },
	},
	Index = { Species = {}, Mutations = {}, PagesClaimed = {} },
	Tutorial = { Step = 1, Done = false },
	Daily = { Streak = 0, LastDay = "", Freezes = 1, LastFreezeWeek = "", Cycle = 0,
	          StampMonth = "", Stamps = 0, StampClaims = {}, LastSeen = 0 },
	Gifts = { Day = "", SecondsToday = 0, Cycle = 0, Claimed = {} },
	Spins = { Free = 1, LastDailyFree = "", PlaySecondsBank = 0, PaidSinceJackpot = 0 },
	Quests = { Day = "", Daily = {}, Rerolls = {}, Week = "", Weekly = {}, Achievements = {}, Story = {} },
	Pass = { Season = 1, XP = 0, Premium = false, ClaimedFree = {}, ClaimedPremium = {}, PlayXPToday = 0, PlayXPDay = "" },
	Boosts = { [name] = expiresAtUnix },
	Codes = {}, Badges = {}, Purchases = {}, -- last 200 PurchaseIds
	Stats = { NestSteals = 0, Snatches = 0, Defends = 0, Hatches = 0, PlaySeconds = 0, FirstJoin = 0 },
	Settings = { Music = 0.6, Sfx = 0.8, ReduceMotion = false, LowGraphics = false, FriendsInBase = true, HideTrails = false },
	EventCurrencies = {},
	GroupRewardClaimed = false, StarterPackSeen = false,
}
```

- Migrations: `DataService.Migrate(profile)` upgrades step by step from any older version;
  unit-test every migration.
- Never store Instances or Vector3s. Keep the profile under 100 KB (cap Items at Storage +
  podiums).

## 19.4 Security and anti-exploit

- Server validates every action: distance (with 4-stud latency tolerance), state (not carrying,
  not stunned, not Night), ownership, cooldowns, prices, plot lock.
- **Movement check** every 0.5 s: displacement vs. allowed WalkSpeed × 1.6 + 12 studs (for
  knockbacks); two strikes → rubber-band to last valid position; repeated → kick and log.
- Carried items are welded server-side. A client can't claim to have crossed the Safe Line; the
  server checks the character's position.
- Purchases only via receipts. Rewards only via `RewardService`.
- Rate-limit remotes; log anomalies to `AnalyticsService` custom events.

## 19.5 Performance

- Server tick budget: GuardianService 10 Hz, Income 1 Hz, Speed 2 Hz, anti-exploit 2 Hz.
  Never a `while true do wait()` per object; one scheduler loop per service.
- Client: procedural idles only for brainrots within 120 studs; billboards with
  `MaxDistance` 120; particles disabled in low-graphics mode.
- Target: 60 FPS on a mid-range phone in the piazza with 7 players and full plots.

# 20. Balancing and pacing

Write `Shared/Balancing/Simulator.luau` (runs under Lune and in Studio's command bar): a greedy,
non-paying simulated player using the real configs, second by second:
- Grabs the best egg it can carry home without being caught (using the 4.3 contract), from its
  two highest reachable biomes, delivering roughly every 40–90 s depending on distance.
- Loses ~30% of its eggs to other players and gets caught sometimes (configurable).
- Spends idle time on the treadmill; buys the best value upgrade when affordable; places the
  best brainrots; sells the weakest when full; claims playtime gifts at their times; rebirths
  when possible.

**Targets** (non-paying, active play, first time through):

| Milestone | Target |
|---|---|
| Biome 2 | 3 min |
| Biome 3 | 10 min |
| Biome 4 | 25 min |
| Biome 5 | 50 min |
| Rebirth 1 | 75–90 min |
| Biome 6 | 1.5 h |
| Biome 7 | 2.5 h |
| Biome 8 | 4 h |
| Biome 9 | 7 h |
| Biome 10 | 11 h |
| Rebirth 5 | ~25 h |
| First Divine | ~15 h |

Tune treadmill gains/prices, trail prices, rebirth cash, and slot prices until every target is
within ±20%. Record results and any conflicts between this prompt's numbers and the targets in
`docs/BALANCING.md`. **When a number in this prompt conflicts with the targets, the targets
win**; note what you changed.

# 21. Testing

1. **Unit tests** (`lune run tools/test`): formulas (income, size mult points from 6.2,
   WalkSpeed points from 8.1, hatch time cap), roll distributions (100k rolls within 1% of
   configured odds), config validation, data migrations, reward scaling, UTC day/week/month
   keys, quest pool filtering, spin pity, receipt idempotency (same PurchaseId twice grants once).
2. **Guardian lab** (4.3) and **simulator** (20).
3. **Studio checklist** in `docs/TEST_PLAN.md`, run with **Test → Clients and Servers, 3
   players**, covering: tutorial start to finish; steal and escape in biomes 1–3; get caught;
   carry a Huge egg; snatch from a player, get batted, item returns; lock base and get pushed
   out; new-player shield; last-two rule; peel trips player and Guardian; hatch reveal on all
   rarities (admin spawn); offline earnings (fake by editing LastSeen); every gift claim; spin
   wheel free/paid (test purchases in Studio); daily streak across a fake day change; quest
   progress; pass claim; rebirth; Index rewards; fuse; bloom; each weather event; Admin Abuse
   via panel; Rift boss; merchant; codes; leaderboards; settings; phone, tablet, console layouts
   with the Device Emulator.
4. **Soak test:** 7 players for 15 minutes in Studio with the admin panel granting late-game
   items: no errors in Output, server heartbeat stable, memory stable.

# 22. Milestones (build in this order)

Each milestone ends with: no Output errors, unit tests passing, a commit, and a short note in
`docs/PROGRESS.md` of what works and what's next.

| # | Milestone | Done when |
|---|---|---|
| **M0** | Repo, toolchain, configs skeleton, Remotes, DataService (ProfileStore), Format util, unit test runner | Project builds; a player's profile loads/saves; tests run |
| **M1** | Map v1: plots, piazza (blockout), Safe Line, runway, all 10 biomes blocked out with nests, lighting per biome; build-place tool | You can walk from plot to biome 10; names/tags match section 3 |
| **M2** | Core loop: nest reset + Night, steal prompt, carry, Safe Line, auto-place, hatch, income, collect pads, treadmill + Speed, WalkSpeed, Storage basic, HUD basics | A player can steal, hatch, earn, get faster |
| **M3** | Guardians: all 10 with state machine, abilities, tutorial mercy; guardian-lab passes the contract | Escape/caught table matches 4.3 |
| **M4** | Content: all 80 recipes + 12 exclusives + Classic pack, eggs, sizes/kg, mutations, billboards, hatch reveal | Admin can spawn and see every species and mutation |
| **M5** | PvP: snatch, alerts, bat, peels, ragdoll, base lock, shields, rules | Clients-and-servers test passes the PvP checklist |
| **M6** | Progression: treadmill tiers, trails, base upgrades, upper floor, sell, equip best, fuse, bloom, rebirth, Index; simulator hits targets | Balancing doc written; targets within ±20% |
| **M7** | Retention: tutorial, daily streak, stamp card, playtime gifts, spin wheel, quests (daily/weekly/achievements/story), Gettoni shop, welcome back, codes, group gift, friend boost, invites, leaderboards, notifications | Every retention checklist item works |
| **M8** | Monetization + Pass: passes, products, receipts, shop UI, Starter Pack, Brainrot Pass season 1 | Test purchases grant correctly, once |
| **M9** | Events: weather, Admin Abuse (global), Rift Boss, merchant, server luck, Halloween + Winter event packages, admin panel, LiveConfig, analytics | Admin can run every event in all servers |
| **M10** | Polish: final map art pass on every biome and the piazza, secret areas, sounds, music, settings, accessibility, mobile/console pass, performance pass, badges, docs (README, STUDIO_SETUP, CONTENT, LIVE_OPS, GAME_DESCRIPTION with store text, 5 thumbnail ideas and icon idea) | Full test plan passes; ready to publish |

# 23. Lessons from a previous build of this genre (apply them)

1. Guardians that walk to the target's *last* position never catch fast players; aim ahead (4.2).
2. A caught player must be ignored for a few seconds or they get caught every tick (CatchGrace).
3. Brand-new players got caught by the first Guardian on their very first egg and quit; tutorial
   mercy fixes it (4.2).
4. Guardian abilities written as "strong" (e.g. 1.5× sprint for 5 s) made biomes impossible at
   the recommended speed. Keep abilities light and measure them (4.3).
5. At high Speed, timed hazards stop mattering because players cross them in under a second.
   For any skill section (Rift Arena), cap WalkSpeed inside it (e.g. 28).
6. The first rebirth was reachable far too early with a fixed cash requirement; run the simulator
   before trusting any number.
7. A headless test harness that runs the real server scripts with fake players found most
   gameplay bugs without Studio. If time allows in M2–M3, build a minimal one under
   `tools/emu` (virtual clock, fake Players/Workspace, no physics).
8. Keep the map out of Rojo's managed tree so syncing never wipes level edits.

# 24. Deliverables checklist

- [ ] `game.rbxl` that is fully playable when opened in Studio.
- [ ] All source in `src/`, Rojo project, toolchain files, passing `tools/check.sh`, selene and stylua.
- [ ] Unit tests, guardian lab, simulator, all passing.
- [ ] Docs: README, ARCHITECTURE, BALANCING, CONTENT, STUDIO_SETUP (with every product/pass to
  create, group ID, sound IDs to fill, Max Players = 7), LIVE_OPS, TEST_PLAN, ASSUMPTIONS,
  PROGRESS, GAME_DESCRIPTION.
- [ ] Every number from this prompt is in a config module, and every intentional change is
  written down in BALANCING.md or ASSUMPTIONS.md.

=== PROMPT END ===
