# Steal a Chibi!

A multiplayer Roblox steal-and-hatch game. Train on your treadmill, sprint into anime-themed
zones, grab a glowing egg from a guarded nest, race it home before the Guardian or another
player gets you, and hatch an original chibi that earns cash every second. Everyone else is
trying to steal it.

![Map overview](docs/map-overview.png)

## Play it

1. Open **`StealAChibi.rbxl`** in Roblox Studio. It contains your map, every script and all
   the generated gameplay parts.
2. Press **Play**, or use **Test > Clients and Servers** with 2-3 players to try stealing.
3. Everyone in Studio gets an **ADMIN** button (cash, Speed, egg spawns, events, pass test
   grants), so you can reach the late game quickly.

Before publishing, read [docs/STUDIO_SETUP.md](docs/STUDIO_SETUP.md): set Max Players to 5,
create gamepasses/products and paste their IDs into `Config/Monetization.luau`, and add
music IDs.

## Controls

| Action | PC | Controller | Mobile |
|---|---|---|---|
| Grab / steal / place / snatch | hold **E** on a prompt | hold **X** | hold the prompt button |
| Harisen slap | **F** | **R1** | SLAP button |
| Ofuda trap | **T** | **Y** | TRAP button |
| Smoke bomb | **G** | **D-pad up** | SMOKE button |
| Close a window | **Esc** | **B** | X button |

## What's in the game

- **11 zones** from Sakura Academy to Celestial Sakura Heights. Zones 1-3 use your meshes;
  zones 4-11 have placeholder architecture in each zone's palette.
- **75 original characters** (66 zone chibis plus festival, gacha and fusion exclusives), with
  sizes Tiny to Titan, exact kg, and natural and incubator mutations.
- **Guardians** with the full idle > patrol > alert > chase > catch/return state machine and
  a flavour ability each. Your Hall Monitor and Ramen Master models are the zone 1 and 2
  Guardians.
- **PvP**: snatching, the Harisen slap, base raids with alerts and a thief arrow, Barrier Lock,
  a 10-minute new-player shield.
- **Progression**: treadmill tiers, trails, pen levels, the Character Index with rewards and
  zone bonuses, the Fusion Pod, the Sell Counter, Equip Best, the Heavenly Gatekeeper
  gauntlet, the Sacred Tree Incubator and rebirths with titles.
- **Live ops**: idempotent Robux purchases, a gacha with odds shown first, codes, a 7-day
  login streak, global leaderboards, synced events (Matsuri Nights, Sakura Storm, Eclipse
  Hour, Double Growth) and an admin panel that can run events across all servers.
- **Polish**: an anime hatch reveal, tutorial with a guide beam, toasts and banners, settings,
  low-graphics mode, and layouts that scale from a 390px phone to a TV.

Zone 7 (Mecha Hangar) has finished voxel art: all six chibis, each hatching from its own
Armor-Core egg with the rarity ornament built in, on the same 3/16-stud grid as your Zone 3
egg. They were modelled in Blender and ship as parts in the place, with `.blend`, FBX and
`.rbxm` copies in [`assets/models/zone7`](assets/models/zone7) (see
[tools/blender/README.md](tools/blender/README.md)).

![Zone 7 voxel chibis and their eggs](docs/art/zone7/lineup.png)

The other characters, eggs and Guardians are still placeholders built from simple parts.
Drop real models into the asset folders to replace them without code changes (see
[docs/ART_SPEC.md](docs/ART_SPEC.md)).

## Working on the code

The Luau source in `src/` syncs into Studio with [Rojo](https://rojo.space). The project file
only manages the code folders, so syncing never touches the map.

```bash
rokit install                 # rojo, lune, luau-lsp, selene, stylua (see rokit.toml)
rojo serve                    # then Connect from the Rojo Studio plugin
./tools/check.sh              # type-check everything with luau-lsp
lune run tools/test           # unit tests for configs and formulas
lune run tools/simulate       # balancing: time to reach each zone
lune run tools/build-place    # rebuild StealAChibi.rbxl from assets/base-map.rbxl + src/
lune run tools/smoke          # headless playthrough: real scripts, fake players (see tools/emu)
lune run tools/soak           # five bots playing at once for 15 simulated minutes
lune run tools/guardian-lab   # escape/catch table for every zone's Guardian
lune run tools/gauntlet-bot   # can careful players clear the Gatekeeper, and do careless ones fail?
lune run tools/gen-art-spec   # regenerate docs/ART_SPEC.md from the configs
python3 tools/blender/build.py   # voxel art: Blender scene, FBX, renders (pip install bpy==5.0.1)
lune run tools/import-art     # put the voxel art and fresh code into StealAChibi.rbxl
lune run tools/art-check      # build every voxel egg and chibi through the real game code
```

`tools/emu` is a small headless stand-in for the Roblox engine: it runs the actual server
and client scripts on a virtual clock with fake players, so most gameplay bugs show up
without opening Studio. It has no collisions or rendering, so it doesn't replace a real
playtest (see [tools/emu/README.md](tools/emu/README.md)).

Everything designers tune lives in `src/ReplicatedStorage/Shared/Config/`.

## Docs

| Doc | Contents |
|---|---|
| [STUDIO_SETUP.md](docs/STUDIO_SETUP.md) | Publishing checklist, what the build changed, every CollectionService tag, swapping art, adding content |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | File tree, services, remotes, security model, saved data |
| [ART_SPEC.md](docs/ART_SPEC.md) | Every character, egg, mutation and Guardian, plus originality changes |
| [BALANCING.md](docs/BALANCING.md) | Pacing simulator results, the Guardian escape table, gauntlet difficulty |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | What the headless playtest covers, and the acceptance checklist for Studio |
| [GAME_DESCRIPTION.md](docs/GAME_DESCRIPTION.md) | Store description, 5 thumbnail concepts, icon concept |
| [MODELS.md](MODELS.md) | Where each model from your original map ended up, and the voxel models added since |
| [tools/blender/README.md](tools/blender/README.md) | The voxel art pipeline: style rules, outputs, switching to FBX meshes |

## Assumptions

- Servers hold **5 players**, one per existing base. The brief's 8-plot row was not built.
- Station Plaza sits in the courtyard between the bases and zone 1, so the zones didn't have
  to move.
- The Gatekeeper's staff sweeps low and you **jump** over it; Roblox has no built-in crouch
  to duck under it.
- Full Index completion counts every zone, festival and fusion character. Gacha exclusives
  are shown in the Index but not required, so completion never needs Robux.
- Gamepasses and products are hidden until their IDs are set; admins can test them with free
  grants.
- Guardian abilities follow the brief's "light" rule (see [BALANCING.md](docs/BALANCING.md)).
  That means the Komainu's wake-up sprint is 1.3x for 1.6 s rather than "very fast for 5 s":
  at 5 s nobody at the recommended Speed could escape it.
- Guardians go easy on a brand-new player until their first egg is home (slower chase,
  a warning instead of a catch), so the tutorial can't stall on the Hall Monitor.
- WalkSpeed is capped at 26 while running the Gatekeeper gauntlet; otherwise zone 11 Speed
  crosses it in under 3 seconds and the hazards never matter.
- ProfileStore by loleris (Apache 2.0) handles session-locked saves.
