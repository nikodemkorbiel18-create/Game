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

## Guardians

The brief's rule: at a zone's recommended Speed, a player carrying a **Normal** egg barely
escapes the Guardian, and one carrying a **Huge** egg gets caught. Base speeds do this on
their own (Guardian = 0.8 x WalkSpeed, Normal carry = 0.85, Huge carry = 0.6), and the brief
says abilities are light flavour, so each ability use may gain a Guardian at most about 10
studs on that Normal carrier. `lune run tools/test` checks this for every zone ("Guardian
abilities stay light"); `lune run tools/guardian-lab` measures it with the real
GuardianService in the headless emulator.

The headless playtest showed the original ability numbers broke the rule: a Normal carrier
inside the Ramen Master's splash radius, or anywhere near the Royal Knight Captain's charge or
the Demon General's bats, could never escape. They were cut to:

| Zone | Ability | Was | Now | Gain on an at-speed Normal carrier |
|---|---|---|---|---|
| 2 | Noodle Splash | 60% speed for 2 s | 70% for 1.5 s | ~10 studs (was 19) |
| 3 | Komainu wake-up sprint | 1.5x for 5 s | 1.3x for 1.6 s (stays awake 5 s) | ~12 studs (was ~67) |
| 4 | Sprint burst | 1.5x for 1.5 s | 1.3x for 1.2 s | ~10 studs (was 23) |
| 7 | Mech on straights | 1.25x | 1.06x (still 0.85x when turning) | never faster than the carrier (was always) |
| 8 | Knight's charge | 2x for 1 s | 1.35x for 0.7 s | ~10 studs (was 47) |
| 9 | Bat swarm | 70% for 3 s | 80% for 1.2 s | ~10 studs (was 42) |
| 11 | Petal field | 80% within 25 studs | 90% within 15 studs | only bites at close range |

Other Guardian fixes from the same testing: a caught player is ignored for 4 s
(`GameSettings.Guardian.CatchGrace`) instead of being re-caught every tick; "blocked" now
means the Guardian isn't moving rather than the player outrunning it; and a chasing Guardian
aims a few studs past its target. It used to walk to where the target was a tick ago and
stop, so from zone 6 up (where players cover 3+ studs per tick) it hovered just behind even a
Huge carrier and never caught anyone.

`lune run tools/guardian-lab` result (the Guardian is already chasing, D studs behind, when
the player starts running home at exactly the zone's recommended Speed; `ok` = escaped,
`XX` = caught):

| Zone | Guardian | Normal egg: D = 12 / 20 / 30 / 45 / 70 | Huge egg: D = 12 / 20 / 30 / 45 / 70 |
|---|---|---|---|
| 1 | Hall Monitor Sensei | ok ok ok ok ok | XX XX XX ok ok |
| 2 | Ramen Master | ok ok ok ok ok | XX XX XX XX ok |
| 3 | Stone Komainu | ok ok ok ok ok | XX XX XX XX ok |
| 4 | Lifeguard Captain | ok ok ok ok ok | XX XX XX XX ok |
| 5 | Masked Sentinel | ok ok ok ok ok | XX XX XX XX ok |
| 6 | Stage Manager | ok ok ok ok ok | XX XX XX ok ok |
| 7 | Patrol Mech | ok ok ok ok ok | XX XX XX ok ok |
| 8 | Royal Knight Captain | ok ok ok ok ok | XX XX XX XX ok |
| 9 | Demon General | ok ok ok ok ok | XX XX XX XX ok |
| 10 | Mistveil Spirit | ok ok ok ok ok | XX XX XX ok ok |
| 11 | Celestial Warden | ok ok ok ok ok | XX XX XX ok ok |

The emulator has no walls, so real maps with obstacles will make both sides a little
slower; the rule to keep is the shape of this table.

## The Gatekeeper gauntlet

`lune run tools/gauntlet-bot` sends two bots through it eight times each at random start
times. The careful bot reads the same hazard math the client draws (shockwave rings,
telegraphed petals, the staff) and jumps them; the careless bot just runs.

| Version | Careful | Careless |
|---|---|---|
| Original tuning | 8/8 cleared | 8/8 cleared (players at zone 11 Speed crossed it in under 3 s) |
| Now | 8/8 cleared, 0.9 hits on average | 2/8 cleared |

Changes: WalkSpeed is capped at 26 during a run (`Endgame.Boss.WalkSpeedCap`) so Speed
doesn't trivialize it; shockwaves every 1.6 s (was 3); 5 petals every 0.9 s with one aimed
where each runner is heading (was 3 random every 1.2 s); the staff turns at 110 deg/s
(was 80). A run now also ends if you leave the corridor, so the speed cap can't follow you
home.

## Other levers

- `Config/Index.luau` `DiscoverySpeedCapFraction` (0.04): first-discovery Speed rewards are
  capped at this fraction of the next zone's recommended Speed. Larger values let players skip
  treadmill tiers.
- `Config/Balancing.luau` `Sim.Competition`: how many eggs other players take first.
- Pen level prices follow the brief exactly (x6 per level from $500).
