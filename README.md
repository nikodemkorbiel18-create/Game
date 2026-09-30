# Steal a Chibi!

A multiplayer Roblox steal-and-hatch game: train on your treadmill, sprint into anime-themed
zones, grab a glowing egg from a guarded nest, race it home, hatch an original chibi and
earn cash, while everyone else tries to steal it.

## Quick start

1. Open **`StealAChibi.rbxl`** in Roblox Studio. It already contains the map and every script.
2. Press **Play**. Data saves to a mock store in Studio unless you enable
   *Game Settings > Security > Enable Studio Access to API Services*.

## Working on the code

The Luau source lives in `src/` and syncs into Studio with [Rojo](https://rojo.space):

```bash
rokit install                 # installs rojo, lune, luau-lsp, selene, stylua (see rokit.toml)
rojo serve                    # then connect from the Rojo Studio plugin
lune run tools/test           # unit tests for configs and formulas
lune run tools/simulate       # balancing simulator (time to reach each zone)
lune run tools/build-place    # rebuild StealAChibi.rbxl from assets/base-map.rbxl + src/
./tools/check.sh              # type-check everything with luau-lsp
```

| Path | What's inside |
|---|---|
| `src/ReplicatedStorage/Shared/Config` | Every character, zone, rarity, size, mutation, treadmill, trail, shop item, event and code |
| `src/ReplicatedStorage/Shared/Util` | Formulas, number formatting, weighted random, signals, event schedule |
| `src/ReplicatedStorage/Shared/Visual` | Placeholder character and egg builders (swap in real models without code changes) |
| `src/ServerScriptService/Server/Services` | Server-authoritative game services |
| `src/StarterPlayer/StarterPlayerScripts/Client` | HUD, windows, billboards, hatch reveal and input |
| `tools/` | Lune build, test, simulate and map-generation scripts |
| `assets/base-map.rbxl` | Your original map, used as the base for every build |
