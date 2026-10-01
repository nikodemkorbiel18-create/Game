# Voxel art pipeline (Blender)

The zone 7 characters and eggs are voxel models on the same 3/16-stud grid as the Zone 3
egg (`Egg_Zone3_Blocky`). They're written as code in Python, built in Blender, and come out as
both Roblox parts (in `StealAChibi.rbxl`) and FBX meshes.

![Zone 7 lineup](../../docs/art/zone7/lineup.png)

## Commands

```bash
pip install bpy==5.0.1                    # Blender 5.0.1 as a Python module (needs Python 3.11)
python3 tools/blender/build.py            # build everything, ~10 min with renders
python3 tools/blender/build.py --no-render    # same without the Cycles renders, ~5 s
lune run tools/import-art                 # part layouts -> .rbxm files + StealAChibi.rbxl
lune run tools/art-check                  # builds every egg and chibi through the real game code
```

`build.py` writes:

| Output | What it is |
|---|---|
| `assets/models/zone7/Zone7.blend` | All 12 models in a lineup, one collection each. Open it in Blender to look around or edit. |
| `assets/models/zone7/fbx/*.fbx` | One file per model: vertex-coloured meshes, one per limb group and special material |
| `assets/models/zone7/ImportFBX.lua` | Studio command-bar helper that finishes an FBX import (see below) |
| `assets/models/zone7/parts/*.json` | Each model as Roblox parts, for `tools/import-art` |
| `assets/models/zone7/manifest.json` | Sizes, bounds, part counts and limb pivots |
| `docs/art/zone7/` | Renders: lineup, every model, and the egg colour sheet |

`tools/import-art` then saves each model as `assets/models/zone7/rbxm/<Model>.rbxm` (drag
into Studio) and puts them in `StealAChibi.rbxl` under `ReplicatedStorage.Assets`, together
with freshly built code from `src/`. It leaves the map alone. `tools/build-place` adds them
too when it rebuilds the place from scratch.

## Files

| File | Contents |
|---|---|
| `voxel.py` | Voxel modelling (boxes, rounded boxes, discs, pixel drawings, mirroring, limb groups), greedy box merging for parts, greedy face meshing for Blender. No Blender needed. |
| `chibi.py` | The shared chibi body: proportions, big anime eyes, mouths, hair that hugs the head |
| `zone7.py` | The six characters and their six eggs |
| `blend.py` | Blender meshes, materials, renders and FBX export |
| `build.py` | Runs it all |
| `studio_import.luau` | Template for `ImportFBX.lua` |

## Style rules

- **Grid:** 1 voxel = 0.1875 studs. Eggs are 11 x 16 x 11 voxels like the Zone 3 egg;
  chibis are about 2.5 heads tall (head 13 x 12 x 11, body 12 voxels).
- **Faces:** big anime eyes, 2 x 3 voxels with a white sparkle on the same side of both
  eyes, a lighter lower half and a lash line; blush below; a small mouth per character.
- **Colours:** flat, from the character's palette in `Config/Characters.luau`. A darker
  shade on the bottom edge of the hair gives it definition.
- **Eggs:** every zone 7 egg shares the Armor-Core shell (tinted shell, two riveted armor
  bands, a framed glowing core) and adds its character's details. The rarity ornament is
  built in: Legendary crown, Mythic horns, Cosmic orbiting stars.
- **Limbs:** each character is split into `Head`, `Torso`, `ArmR`, `ArmL`, `LegR` and
  `LegL`, each pivoting at its joint (neck, hips, shoulders), ready for rigging.

## How models reach the game

Parts version (in the place now): every visible voxel is covered by as few boxes as
possible. A box can run through the hidden inside of the model, and same-colour boxes can
overlap, so there are no seams and no z-fighting. Characters come to 89-138 parts and eggs
to 77-101.

Conventions the game reads:

| Where | Name | Meaning |
|---|---|---|
| Character model | `Root` part (PrimaryPart) | feet centre, model faces -Z |
| Character model | sub-models `Head`, `Torso`, `ArmR`, ... | limb groups, pivot at the joint |
| Egg model | pivot | centre of the shell |
| Egg model | attribute `ShellHeight` | height of the shell alone; EggBuilder scales it to 3 studs x size |
| Egg model | attribute `Ornament` | rarity ornament that's built in (`Crown`, `Horns`, `Stars`) |
| Part | attribute `Tint` | shell part: recoloured with the egg's cosmetic colour x factor |
| Part | attribute `OrnamentPart` | removed if the egg's rarity changes (Awakened) |
| Part | attribute `Orbit` | spins around the model (Cosmic stars, Hive's drones) |

### Switching to the FBX meshes

The meshes are a handful of MeshParts per model instead of ~100 parts, so they're lighter
on phones:

1. In Studio: **Model > Import 3D**, pick a file from `assets/models/zone7/fbx`. Keep
   "Ignore Vertex Colors" off and keep the meshes separate. Repeat per model.
2. Select the imported models in the Explorer.
3. Open **View > Command Bar**, paste all of `assets/models/zone7/ImportFBX.lua` and press
   Enter.

The helper stands each model up and turns it to face -Z, using the `TopMarker` and
`FrontMarker` cubes in the file. It scales the model, sets colours and materials from the
piece names (`Head__Neon_4CC9F0`, `Egg__Tint_080`, ...), builds the limb groups, and
replaces the parts version. The old version is kept in `ServerStorage.Unsorted`.
`tools/art-check` tests the helper on a deliberately mangled import of every model.

## Adding a model

1. Write a function in `zone7.py` (or a new file for another zone) that returns a `Model`,
   and add it to `CHARACTERS` or `EGGS`.
2. Name characters `Char_<Id>` and eggs `Egg_<Id>`. For a per-character egg, also set the
   character's `EggModel` in `Config/Characters.luau`.
3. Run the commands above.
