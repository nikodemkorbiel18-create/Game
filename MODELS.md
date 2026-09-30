# Models in the original map

This lists what was in the map you uploaded (`assets/base-map.rbxl`) and where each piece
lives in the built game (`StealAChibi.rbxl`). See `docs/STUDIO_SETUP.md` for everything the
build added.

| Original model | What it is | Where it is now |
|---|---|---|
| `Base1`..`Base5` | Five fenced 90x90 player bases in a U around the spawn (renamed from `Model`) | Same place, tagged `Plot` with gameplay fixtures added |
| `BackFence`, `SideFence` (+ `_Extra`) | Fence groups inside each base | Unchanged |
| `KitsuneShrine_AllInOne` | Zone 3 art (shrine, bamboo, torii path, foxfire) | `Workspace.Map.Zones.Zone03_KitsuneShrineForest.Art` |
| `RamenStreet_AllInOne` | Zone 2 art (ramen street, neon signs) | `Workspace.Map.Zones.Zone02_NeonRamenAlley.Art` |
| `LeftWall_Classrooms`, `RightWall_Windows`, `RightWall_Glass_Optional` + school floor | Zone 1 art (school hallway) | `Workspace.Map.Zones.Zone01_SakuraAcademy.Art` |
| `HallMonitor` | Rigged NPC | `ServerStorage.Assets.Guardians` - spawned as the zone 1 Guardian |
| `RamenMaster` | Chibi with a ladle (was 123 studs below the map) | `ServerStorage.Assets.Guardians` - rigged at runtime as the zone 2 Guardian |
| `Egg_Zone3_Blocky` / `Egg_Zone3` | Mesh egg with rope and paper charms | `ReplicatedStorage.Assets.Eggs.Egg_Zone3` - shell for zone 3 eggs |
| `Models` folder (Fence, flowers, mushrooms, bench, rocks, grass, crate, lamp, trees) | Prop set | `ServerStorage.Assets.Props` |
| Second `RightWall_Glass_Optional` far from the school | Stray duplicate | `ServerStorage.Unsorted` |
