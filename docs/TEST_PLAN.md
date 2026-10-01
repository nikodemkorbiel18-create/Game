# Test plan

## Already verified (no Studio needed)

| Check | How | Result |
|---|---|---|
| Every script type-checks against the Roblox API | `./tools/check.sh` (luau-lsp, strict mode in most files) | passes |
| Configs are consistent (every zone rarity has characters, weights sum to 100, props exist, incomes inside the brief's ranges, gacha odds sum to 100) | `lune run tools/test` | 19/19 pass |
| Formulas (WalkSpeed, Guardian speed, kg scaling, rebirth requirements, number formatting, event schedule) | `lune run tools/test` | pass |
| An at-speed player with a Normal egg outruns the zone's Guardian; with a Huge egg they don't | unit test on all 11 zones | pass |
| Pacing | `lune run tools/simulate` | within about 20% of every zone target (see BALANCING.md) |
| Built place contains every tagged part | `lune run tools/verify-place` | 5 plots x 40 slots, 11 nests x 8 pedestals, 18 Guardian spawns, gauntlet, incubator |
| Zone 7 voxel art works with the game code: every egg at every size sits on the ground with a 3-stud shell, all 5 cosmetic colours tint the shell, built-in ornaments aren't doubled, Awakened eggs swap to the right ornament, Cosmic stars and Hive's drones orbit, chibis have limb groups, scale, keep eye colours under Golden and go black as Index silhouettes; the Studio FBX import helper rebuilds every model exactly from a mangled import | `lune run tools/art-check` | 3627/3627 pass |

## Headless playtest (no Studio needed)

`lune run tools/smoke` runs the real server and client scripts in `tools/emu` (a headless
stand-in for the Roblox engine) with fake players who walk, hold prompts, click buttons and
fire remotes. It covers:

| Step | What it checks |
|---|---|
| Join | data loads, a plot is assigned, 88 eggs spawn, HUD and tutorial appear |
| Core loop | grab a zone 1 egg, carry it home (slowed), it lands in the pen and hatches within the tutorial cap, income accrues, the COLLECT plate pays, treadmill unlock and training, tutorial completes |
| Guardians | an at-speed Normal carrier escapes the Ramen Master; a Huge carrier is caught |
| PvP | snatching a carried egg, the Harisen slap drops it (and it can be picked up), a base raid with the theft alert and ownership change on delivery, Barrier Lock pushing raiders out |
| Anti-exploit | instant prompt triggers, slap spam and malformed arguments to every remote are rejected without errors |
| Economy | pen upgrade, items, trails, index rewards, login reward, codes, Equip Best, fusion (2 min timer), selling |
| Persistence | leave and rejoin keeps everything; a thief leaving mid-raid returns the chibi; the owner leaving mid-raid keeps it; dying while carrying drops the egg and the HUD survives respawn; shutdown saves every profile |
| Endgame | events start and stop, the gauntlet gate blocks uncleared players, the Sacred Tree incubator, rebirth resets and keeps the right things |
| UI | every sidebar window opens and closes; the HUD fits an 844x390 phone screen |

`lune run tools/soak` runs five bots for 15 simulated minutes (grabbing, delivering,
raiding, slapping, buying, leaving and rejoining) and fails on any script error. Last runs:
0 errors over 15 minutes (~120 grabs, 100 deliveries, 36 raids, 39 slaps, 26 rejoins) and
0 errors over 10 minutes with another seed.

`lune run tools/guardian-lab` and `lune run tools/gauntlet-bot` check balance rather than
bugs; their current results are in [BALANCING.md](BALANCING.md).

What the emulator can't tell you: collisions, animation, visuals, performance, real
network latency, streaming. Those still need Studio.

## In Roblox Studio

Use **Test > Clients and Servers** with 2-3 players, and the ADMIN panel to skip grinding.

### Zone 7 voxel art
1. Admin: spawn eggs in zone 7 (Mecha Hangar). Each character has its own Armor-Core egg (goggles for Bolt, headset for Haruto, drones for Hive, visor for Hikari, admiral cap for Gōtetsu, cockpit and fists for Daichi) in one of the five zone colours, with a crown, horns or orbiting stars for its rarity.
2. Carry a Cosmic egg (Gōtetsu or Daichi): the stars stop spinning while it's carried and the carrier isn't pulled around; they spin again once it's in a pen.
3. Hatch one of each and check the pen: feet on the pedestal, facing out of the pen, Hive's drones circling overhead.
4. Open the Index before discovering them: silhouettes are solid black.

## Acceptance checklist (brief section 27)

### 1. A new player finishes the tutorial and hatches their first character within 2 minutes
1. Join with a fresh profile (in Studio, just press Play; the mock store is empty).
2. Follow the beam to Sakura Academy, hold to grab an egg and run home.
3. The first egg ever placed hatches in at most 12 seconds (`GameSettings.TutorialHatchCap`).
4. Step on COLLECT: the $1,000 welcome gift arrives. Unlock the treadmill, stand on it for 5 seconds, and the tutorial completes.
- **Pass:** hatch reveal plays before the 2-minute mark.

### 2. Guardians catch an under-speed player with a Huge egg; an at-speed player with a Normal egg barely escapes
1. Admin: give Speed so you're exactly at zone 2's recommendation (250).
2. Admin: spawn eggs in zone 2 until you have a Normal and a Huge one.
3. Grab the Normal egg and run straight home: the Ramen Master should chase and fall slightly behind.
4. Repeat with the Huge egg: you should be caught, the egg should teleport back to its pedestal, you ragdoll for 1.5s and see "CAUGHT!".

### 3. Eggs reset every 5 minutes, in sync across servers; Secret+ spawns announce server-wide
1. Watch the HUD countdown hit 0:00: every unclaimed egg is replaced. Carried eggs and pen eggs are untouched.
2. In two published servers, confirm the countdowns match (resets happen at os.time() multiples of 300).
3. Admin: spawn a Secret egg in zone 9 and confirm the banner "A SECRET EGG APPEARED IN DEMON LORD'S CASTLE!".

### 4. Snatching, slapping, raiding and Barrier Lock work and can't be exploited
1. Player A carries an egg; player B holds E on it for 1s within 8 studs: B now carries it.
2. B presses F facing A while A carries something: the item drops (10s pickup window) and A is stunned. Slapping someone inside their own base does nothing.
3. A presses ADMIN > "End my new-player shield" (or waits 10 minutes) and has chibis in the pen. B walks in and holds 1.5s on a slot: B carries it, A gets a red banner, sees B highlighted and an arrow. Ownership changes only when B enters B's base.
4. A presses the Barrier Lock button: B is pushed out for 60s, then there's a 90s cooldown.
5. Exploit attempts to try: firing `Slap` rapidly (server cooldown), triggering prompts instantly (server measures hold time), raising WalkSpeed locally (rubber-banded), invoking `Shop` or `Sell` with bad arguments (rejected by Guard).

### 5. Data survives rejoin, shutdown and teleport; no duplication when two servers race
1. With API access on, earn cash, place eggs, leave and rejoin: everything is back, including incubation progress.
2. Start stealing A's chibi, then have A leave: the item returns to A's saved pen. Have B leave mid-theft: same result.
3. Join the same account in two servers: the second session waits for the first to release its lock (ProfileStore session locking), so nothing is duplicated.

### 6. Every purchase is granted exactly once; gacha odds are visible before buying
1. Add product IDs, publish, and buy a Speed Pack. Speed rises once.
2. Kill the server during a purchase; on rejoin the receipt is retried and the PurchaseId check prevents a second grant.
3. Open Shop > Robux > Gacha Capsule: the exact odds per character are shown in the card and again in the confirmation before the Robux prompt.

### 7. Rebirth resets and keeps exactly what the brief says
1. Admin: give $1M and an Epic character. Open REBIRTH: the checklist is green and the before/after preview is shown.
2. After rebirth, cash, Speed, treadmill, pen level, pen, inventory and the Gatekeeper clear are reset; the index, trails, titles, codes and passes remain. On the second rebirth, one Protected chibi can be kept.

### 8. Mobile is usable at 390px; console works with a controller only
1. Studio Device Emulator: iPhone SE / a 390x844 phone in landscape. The HUD, sidebar, action buttons (SLAP / TRAP / SMOKE) and every window fit and scale.
2. Gamepad: prompts use ButtonX, slap is R1, trap Y, smoke D-pad up, windows close with B, and window buttons are selectable.

## Also worth checking
- Fusion Pod: three copies become an Awakened chibi after 2 minutes; mismatched mutations show the 10% warning.
- Sacred Tree: with the Gatekeeper cleared, carry an egg up, pay the fee and claim a Petal or Kami Bloom after 60s.
- Events: start Sakura Storm (petal weather, x2 mutations) and Eclipse Hour (red-violet tint) from the admin panel.
- Offline earnings popup after being away for more than a minute.
- Low-graphics mode removes auras and particle effects.
