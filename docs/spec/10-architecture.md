# Architecture — §32–35

Scene design, state machines, navigation and test seeds. Read this before adding a
new unit type or a new resource.

## 32. Godot scene design

The project must use these main scenes:

```text
Main.tscn
|- GameController
|- World
|  |- Map
|  |  |- PaperBackground
|  |  |- Road
|  |  |- RoadWalls
|  |  |- TerrainZones
|  |  |- BarrierContainer
|  |  `- FinalPortal
|  |- CargoUnit
|  |- DefenderContainer
|  |- EnemyContainer
|  |- ProjectileContainer
|  |- EffectContainer
|  `- Camera2D
|- UserInterface
`- TelemetryRecorder
```

Every scene reference goes through a `NodePath` export resolved by
[`NodeRef`](../../scripts/node_ref.gd) — a node-typed `@export` does not work in a
hand-authored `.tscn`. See [`../engine-notes.md`](../engine-notes.md).

### 32.1 Cargo scene

The cargo scene uses a `CharacterBody2D` root.

The cargo scene contains a collision shape, visual nodes, health, and a cargo motor.

The cargo motor uses the selected cargo control method.

### 32.2 Defender scene

The defender scene uses a `CharacterBody2D` root.

The scene contains a state machine, navigation agent, collision shape, visual nodes,
and statistics.

### 32.3 Enemy scene

Each enemy scene uses a `CharacterBody2D` root.

The scene contains a state machine, navigation agent, collision shape, visual nodes,
and statistics.

### 32.4 Spell scene

Each projectile or area spell uses a separate scene.

The wizard controller creates these scenes after a valid cast.

### 32.5 Data resources

The project must store balance values in Godot resources.

**The project must not store balance values only in unit scripts.**

Use these resource types:

| Resource | Script | Instances |
|---|---|---|
| `DefenderData` | `scripts/data/defender_data.gd` | `data/defenders/` ×4 |
| `EnemyData` | `scripts/data/enemy_data.gd` | `data/enemies/` ×2 |
| `SpellData` | `scripts/data/spell_data.gd` | `data/spells/` ×3 |
| `CargoData` | `scripts/data/cargo_data.gd` | `data/cargo_data.tres` |
| `ControlProfileData` | `scripts/data/control_profile_data.gd` | `data/profiles/` ×4 |
| `TestSeedData` | `scripts/data/test_seed_data.gd` | `data/seeds/` ×3 |

Two more exist beyond the required six: `MapRouteData`
(`data/map_route.tres`, the control points the whole map is generated from) and
`DefenderTuning` (`data/defender_tuning.tres`, the shared radii of §15).

**Every resource is already filled from the specification tables**, including the
ones for systems that have no behaviour yet. That is why milestones 2 to 6 are
behaviour only.

## 33. State machine design

Each defender and enemy uses an explicit finite state machine.

Each state has enter, update, and exit functions.

The state machine sends a signal after each state change.

The telemetry recorder stores each defender state change.

**The state logic must not depend on animation completion.** The simulation
controls the state logic.

Scaffolding: `scripts/fsm/state_machine.gd`, `scripts/fsm/unit_state.gd`.

## 34. Navigation rules

Defenders and enemies use `NavigationAgent2D`.

The cargo unit does not use local avoidance.

Defenders and enemies use local avoidance.

The navigation map must update after a barrier opens.

**A unit must not stay blocked for more than two seconds.**

A blocked unit must select a nearby fallback position.

The fallback position must stay inside the navigation area.

> **Build note.** The navigation bake currently reports 3 edge-merge warnings, down
> from 39. Owned by milestone 2 — see [`../engine-notes.md`](../engine-notes.md) for
> what caused them and [`../status.md`](../status.md) for the plan.

## 35. Test seed rules

A test seed controls enemy spawn positions.

The seed does not change enemy statistics.

The player can select seed 1, seed 2, or seed 3.

Each control profile must use the same seed sequence.

The result screen must show the selected seed.
