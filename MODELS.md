# Models in `stealachibi_prototype1.rbxl`

The place has **275 Model instances**. All of them are in `Workspace`; ReplicatedStorage and ServerStorage are empty, and there are no scripts yet.

## Player bases (renamed)

Five fenced 90×90 plots form a U around the spawn at (-9, 0, 753). Each base's entrance faces the middle. They were all called `Model`, so they were renamed:

| New name | Position (X, Z) | Entrance faces |
|---|---|---|
| `Base1` | (-101, 733) | +X (toward spawn) |
| `Base2` | (-101, 873) | -Z (toward spawn) |
| `Base3` | (-1, 873) | -Z (toward spawn) |
| `Base4` | (99, 873) | -Z (toward spawn) |
| `Base5` | (98, 735) | -X (toward spawn) |

Each base holds a 90×90 floor `Part`, 19 loose `Fence` models (the front with the entrance, and one side), and two fence groups that were also called `Model`:

- `BackFence`: 7 fences along the wall opposite the entrance, plus `BackFence_Extra` (6 fences, the rest of that wall)
- `SideFence`: 7 fences along one side wall, plus `SideFence_Extra` (6 fences, the rest of that wall)

That is 45 `Fence` models per base, 225 in total.

## Other models (already named, unchanged)

**Zones**

| Model | Position (X, Y, Z) | What it is |
|---|---|---|
| `KitsuneShrine_AllInOne` | (-2, 0, 404) | Shrine zone: floor, bamboo and shrine walls, torii gates, foxfire neon, spirits |
| `RamenStreet_AllInOne` | (-1, 0, 517) | Ramen street zone: floor, walls, overhead signs, neon trims |
| `LeftWall_Classrooms` | (-32, 14, 623) | School hallway left wall |
| `RightWall_Windows` | (30, 14, 623) | School hallway right wall |
| `RightWall_Glass_Optional` | (70, 14, 623) | Optional glass wall for the school hallway |
| `RightWall_Glass_Optional` | (33, 14, 122) | A second copy, far from the hallway (looks like a stray duplicate) |
| `Egg_Zone3_Blocky` → `Egg_Zone3` | (-20, 0, 609) | Zone 3 egg (shell, paper, rope, seal, ink, shine) |

**Characters / NPCs**

| Model | Position (X, Y, Z) | What it is |
|---|---|---|
| `HallMonitor` | (-36, 0, 622) | Rigged NPC with a Humanoid, Motor6D joints and HumanoidRootPart |
| `RamenMaster` → `RamenMaster` | (-34, -123, -2) | Chibi with a ladle and bowl/grip markers. It sits **123 studs below the map**, so it is probably a template that belongs in ReplicatedStorage or ServerStorage |

**Prop set** (`Workspace.Models` folder, lined up around Z ≈ 110)

`Fence`, `YellowFlower`, `PinkFlower`, `RedMushroom`, `PurpleMushroom`, `Bench`, `Rock` ×3, `Grass`, `Crate`, `Lamp`, `Tree` ×2
