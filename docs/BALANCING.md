# Balancing

`Shared/Balancing/Simulator.luau` plays a greedy, non-paying player second by second with
the real configs. Run it with `lune run tools/simulate [runs] [verbose]`, or in Studio's
command bar with `require(game.ReplicatedStorage.Shared.Balancing.Simulator).Run()`.

The simulated player:
- grabs the best egg they can outrun the Guardian with, from their top two zones
- loses 40% of each reset's eggs to other players, and sometimes gets caught
- sells the weakest pen chibi when a better egg comes along
- stands on the treadmill whenever there's nothing worth grabbing
- buys the cheapest useful upgrade (treadmill tier, pen level or trail) whenever they can
- claims discovery rewards

## Current results (8 runs)

| Zone | Target | Simulated |
|---|---|---|
| 2 Neon Ramen Alley | 3 min | 2 min |
| 3 Kitsune Shrine Forest | 10 min | 11 min |
| 4 Beach Episode Coast | 25 min | 25 min |
| 5 Hidden Ninja Village | 50 min | 46 min |
| 6 Idol Concert Dome | 90 min | 73 min |
| 7 Mecha Hangar | 150 min | 137 min |
| 8 Isekai Kingdom | 240 min | 245 min |
| 9 Demon Lord's Castle | 360 min | 379 min |
| 10 Spirit Realm | 540 min | 609 min |
| 11 Celestial Sakura Heights | 720 min | 770 min |
| First rebirth | 90-120 min | **34 min** |

Every zone lands within about 20% of its target. Treadmill and trail prices were tuned with
`tools/tune.luau`, then adjusted by hand.

## Known conflict: first rebirth

The brief fixes Rebirth 1 at **$1M + any Epic**. With the brief's income table a player
reaches $1M in about 35 minutes, well before the 90-120 minute target. To hit the target,
change `Config/Rebirths.luau`, e.g. `{ Cash = 25e6, Rarity = "Epic" }` for rebirth 1, then
scale the later tiers similarly and re-run the simulator.

## Other levers

- `Config/Index.luau` `DiscoverySpeedCapFraction` (0.04): first-discovery Speed rewards are
  capped at this fraction of the next zone's recommended Speed. Larger values let players skip
  treadmill tiers.
- `Config/Balancing.luau` `Sim.Competition`: how many eggs other players take first.
- Pen level prices follow the brief exactly (x6 per level from $500).
