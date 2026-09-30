# Headless emulator

Runs the game's real scripts (server `Main` plus one client `Main` per fake player) on a
virtual clock inside [Lune](https://lune-org.github.io/docs), so gameplay can be tested
without Roblox Studio.

```bash
lune run tools/build-place            # rebuild StealAChibi.rbxl from src/ first
lune run tools/smoke                  # scripted playthrough of every major feature
lune run tools/smoke --only=raid      # just the steps whose name contains "raid"
lune run tools/soak --minutes=15      # five bots playing at once
lune run tools/guardian-lab           # escape/catch table for every zone's Guardian
```

## What it emulates

- **Scheduling**: `task.*`, `wait`/`delay`/`spawn`, `os.clock`/`os.time`/`tick` on a
  virtual clock, deferred signals (the place uses `SignalBehavior.Deferred`).
- **Instances**: every instance is a proxy over a Lune (rbx-dom) instance, with events,
  `WaitForChild` (including the infinite-yield warning), `Destroy` semantics, attributes,
  tags and `CollectionService` signals, pivots, welded assemblies and GUI geometry.
- **Client/server split**: instances a client creates are invisible to the server and
  other clients; property and attribute writes a client makes to replicated instances
  stay local to that client; clients can't see `ServerStorage`/`ServerScriptService`.
- **Networking**: remotes copy arguments the way Roblox serializes them and flag the
  classic mistakes (arrays with nil gaps, numeric dictionary keys, functions, metatables).
  Events fired before a listener connects are queued.
- **Services**: Players (characters, respawn, `ResetOnSpawn`), RunService,
  DataStoreService (in memory, with JSON-style serialization checks), MessagingService,
  MarketplaceService, TweenService, PathfindingService (straight paths) and input stubs.
- **Physics (lite)**: Humanoid `MoveTo` at `WalkSpeed`, ground following, knockback
  sliding, `Touched` for character parts, raycasts against part boxes.

## What it doesn't

No collisions, gravity only as "stand on the ground below you", no rendering, no
streaming, no real network latency beyond one frame. Passing here means the scripts run
and the rules work; it doesn't replace a playtest for feel, visuals or performance.
