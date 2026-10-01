# Architecture

Everything that matters (cash, Speed, rolls, rarity, size, mutation, hatch results,
ownership) is decided on the server. Clients render state and send requests; every request is
type-checked, rate-limited and re-validated.

## File tree

```
default.project.json            Rojo project (code only; never touches the map)
StealAChibi.rbxl                Ready-to-play place (map + all scripts)
assets/base-map.rbxl            Your original map, the input to every build
assets/models/zone7/            Voxel chibis and eggs: .blend, FBX, .rbxm, part layouts
docs/                           Setup, architecture, art spec, balancing, test plan, description
tools/
  build-place.luau              Builds StealAChibi.rbxl (Lune)
  import-art.luau               Puts the voxel art (and fresh code) into StealAChibi.rbxl
  art-check.luau                Builds every voxel egg/chibi through the real game code
  blender/                      Voxel art pipeline: models as Python, built with Blender
  map/{Common,Plots,Plaza,Zones,Gauntlet,Art}.luau   Map generators
  test.luau                     Unit tests for configs and formulas
  simulate.luau, tune.luau      Balancing simulator and price auto-tuner
  gen-art-spec.luau             Regenerates docs/ART_SPEC.md from configs
  verify-place.luau             Counts tags / checks a built place
  check.sh                      luau-lsp type check
  lib/rbx.luau                  Runs Roblox ModuleScripts inside Lune
src/ReplicatedStorage/Shared/
  Config/                       Characters, Zones, Rarities, Sizes, Mutations, Treadmills,
                                Trails, Rebirths, Items, Shop, Events, Codes, Monetization,
                                Fusion, Endgame, Index, LoginRewards, Sounds, Tags,
                                Balancing, GameSettings
  Util/                         Formulas, NumberFormat, TimeFormat, WeightedRandom, Signal,
                                Janitor, EventSchedule, IndexUtil, Gauntlet
  Visual/                       CharacterBuilder, EggBuilder, PropLibrary, Effects, ModelUtil
  Balancing/Simulator.luau      Time-to-zone simulator (also runs in Studio)
  Net.luau                      Every RemoteEvent / RemoteFunction name
  Types.luau                    Item and profile shapes
src/ServerScriptService/Server/
  Main.server.luau              Creates remotes, Init()s then Start()s every service
  Lib/                          ProfileStore (Apache 2.0), Remote, Guard, Prompts, World,
                                GuardianBuilder
  Services/                     see below
src/StarterPlayer/StarterPlayerScripts/Client/
  Main.client.luau              Loads controllers
  UI/                           Theme, UI toolkit + window manager, ItemCard
  Controllers/                  see below
```

## Server services

| Service | Responsibility |
|---|---|
| DataService | ProfileStore sessions (session-locked), autosave every 60s, data migrations, replication of profile keys to the owner, leaderstats |
| AnnouncementService | Toasts, server-wide and cross-server banners |
| PassService | Gamepass ownership cache and multipliers |
| PlotService | Plot assignment, pen slot rendering and prompts, owner sign, register display, Barrier Lock, new-player protection, respawn at base |
| EventService | Scheduled events from os.time, admin events via MessagingService, Server Luck |
| SpeedService | Speed stat, server-set WalkSpeed/JumpHeight with carry/slow/stun modifiers, treadmill, group reward |
| IncomeService | Per-second income into the register, Collect Plate, Auto-Collect, offline earnings, cash API |
| IndexService | Discoveries, first-discovery rewards, zone completion bonuses |
| HatchService | Incubation timers, growth boosts, Lucky Hatch, hatch reveals and announcements |
| EggSpawnService | Nest resets every 5 minutes, egg rolls, special rolls, festival eggs, grab prompts |
| CarryService | Carrying, snatching, dropping, delivery and ownership transfer, owner pen actions, leave safety |
| TrailService | Trail ownership, equip and rendering |
| GuardianService | Guardian AI state machine, abilities, catches |
| ItemService | Ofuda traps and smoke bombs |
| StealService | Harisen slap, base raids |
| AntiExploitService | Movement sanity checks with rubber-banding |
| InventoryService | Inventory, Equip Best, Protect, Sell Counter |
| ShopService | Cash purchases (treadmill, pen, barrier, trails, items) |
| FusionService | Awakening and recipe fusions |
| IncubatorService | Sacred Tree Incubator rituals |
| BossService | Heavenly Gatekeeper gauntlet and the zone 11 hard gate |
| RebirthService | Rebirth preview, resets and rewards |
| CodesService, LoginRewardService | Codes and the 7-day streak |
| LeaderboardService | Global OrderedDataStore boards |
| TutorialService | Event-driven tutorial |
| MonetizationService | Idempotent ProcessReceipt and product grants |
| AdminService | Admin commands |
| AmbienceService | Name tags, settings |

Services never require each other in a cycle. Where a lower-level service needs to react to a
higher-level one it exposes a Signal (for example `PlotService.SlotTriggered`,
`CarryService.Delivered`, `HatchService.Hatched`) or a hook set during `Init`.

## Client controllers

State (profile mirror) · Sound · Notifications · Effects (pen animations, catchphrases,
knockback, FX) · WorldLabels · Billboards (per-player egg/slot info) · Prompts (per-player
prompt text) · HUD · Carry card · HatchReveal · Input (slap/trap/smoke on every platform) ·
Theft (alerts, highlight, arrow) · Inventory · Shop · Index · Rebirth · Fusion · Sell · Codes
· DailyRewards · Settings · Incubator · Gauntlet (hazard rendering) · Ambience (music,
lighting, weather) · Tutorial · Admin.

## Remotes

Created by the server under `ReplicatedStorage.Remotes` (see `Shared/Net.luau`).

- **Server to client:** StateChanged, Notify, Announce, HatchReveal, TheftAlert, Knockback,
  OfflineEarnings, Effect, Tutorial
- **Client to server events:** Slap, PlaceTrap, UseSmoke, StoreCarried, SaveSettings,
  TutorialAction
- **Functions:** GetState, Shop, Inventory, Sell, Fusion, Incubator, Rebirth, Index,
  RedeemCode, LoginReward, Admin

Every handler is wrapped by `Lib/Remote.luau` (token-bucket rate limit per player per remote,
errors isolated). Arguments go through `Lib/Guard.luau`. Proximity prompts go through
`Lib/Prompts.luau`, which measures how long each player really held the button on the server
and checks distance, so a modified client can't skip hold times or interact from afar.

## Saved profile

See `Shared/Types.luau`. Top-level keys: Cash, TotalEarned, Speed, TreadmillTier, PenLevel,
BarrierLevel, Rebirths, EquippedTrail, OwnedTrails, Traps, SmokeBombs, Register, Pen (slot ->
item), Inventory, Index, BossCleared, ProcessedPurchases, RedeemedCodes, Login, LastOnline,
FirstJoin, Playtime, Tutorial, Settings, Fusion, Incubator, Boosts, Titles, EquippedTitle,
GroupRewardClaimed, SeenReveals, Stats, FirstEggPlaced, Credits, DataVersion.

An item is `{ Uid, Kind = "Egg" | "Character", CharacterId, SizeTier, Kg, Mutation?,
Awakened?, Color?, EggModel?, HatchRemaining?, HatchEndsAt?, Lucky?, Protected? }`.

Bump `GameSettings.DataVersion` and add a function to `MIGRATIONS` in DataService whenever the
saved shape changes.

## Key rules in code

- **Income/s** = `BaseIncome x Size x KgScale x Mutation x Awakened(4) x (1 + 0.5 x Rebirths + IndexBonus) x Passes` (`Formulas.EffectiveIncome`).
- **WalkSpeed** = `min(100, 16 + 7 x log10(1 + Speed))`; Guardians run at 80% of the WalkSpeed for their zone's recommended Speed.
- **Stolen items** belong to the victim until the thief crosses into their own base. If either player leaves mid-theft, the item goes home and is saved with its owner.
- **Purchases:** the PurchaseId is stored with the grant and `PurchaseGranted` is only returned once a save containing it has landed.
