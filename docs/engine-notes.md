# Engine notes

Godot behaviour that cost this project real time. Every item here looks like
working code when it is wrong, which is why it is written down.

## A node-typed `@export` never resolves in a hand-authored `.tscn`

Writing `map = NodePath("../World/Map")` into a text-authored scene leaves the
property **null**. The Godot editor stores extra state that a hand-written `.tscn`
does not have.

Every scene reference in this project therefore goes through a `NodePath` export
resolved by [`scripts/node_ref.gd`](../scripts/node_ref.gd), which reports which
node and which field held the bad path. The editor still offers a node picker, so
nothing is lost.

## `Control.set_anchors_preset()` does not size a control

It sets the anchors and then adjusts the offsets so the rectangle does not move —
and a fresh control has a zero-sized rectangle. Use `InkUi.fill_parent()`, which
calls `set_anchors_and_offsets_preset()`.

The failure mode is asymmetric, which is what makes it expensive:

- A `ScrollContainer` **clips**, so the screen goes blank and you notice at once. This is how it was caught, on the result screen.
- A plain `Control` **does not clip**, so it happily draws its contents while every anchor inside collapses onto the origin. The profile select screen looked correct while being wrong.

## `modulate` multiplies, so black art cannot be tinted lighter

This drives the whole art convention:

- **Pack art** (`assets/`) is drawn in final ink colours and takes **no tint**.
- **Hand-authored art** (`cargo_body`, `cargo_rider`, `barrier`) is drawn in **white** and tinted at runtime.

The white-plus-tint convention is what lets one file serve both the damage flash
of §13.2 and the light grey dead marks of §15.11. `InkSprite` supports both
conventions; [`assets/README.md`](../assets/README.md) records which file is which.

## `NavigationAgent2D` clamps the avoidance result to `max_speed`

With `avoidance_enabled`, you hand the agent a desired velocity and it hands back a
safe one — clamped to `max_speed`. So `max_speed` is not a statistic to set once at
setup; it is part of **this frame's** request, and it has to include any temporary
speed change.

`UnitBody` computes its desired velocity as `base_speed * terrain_factor *
move_scale` but set the cap from `base_speed * terrain_factor` alone. Every request
to move faster than the unit's own speed was therefore discarded by the solver,
while the code that asked for it read as correct. The symptom was defenders who
never caught up despite a catch-up multiplier that measurably existed.

If a unit moves at the wrong speed and the velocity you pass in looks right, print
what comes back from `velocity_computed` before looking anywhere else.

## `PROCESS_MODE_ALWAYS` is inherited by every child

A test harness that instances the game as its own child has to say so explicitly:

```gdscript
_main = (load(MAIN_SCENE) as PackedScene).instantiate()
_main.process_mode = Node.PROCESS_MODE_PAUSABLE   # or the game never pauses
add_child(_main)
```

`smoke_run`, `behaviour_checks` and `screenshot_run` all set
`PROCESS_MODE_ALWAYS` on themselves so they can drive the paused screens. A child
left on the default `PROCESS_MODE_INHERIT` follows its parent, so the whole game
inherited "always" and `get_tree().paused` did nothing under any of them. Pause
worked correctly in the real game the entire time; the harnesses were simply
testing a different one.

## Convex decomposition fails on a repeated vertex

Mud zone offsets in `data/map_route.tres` are round numbers, and a round number can
land exactly on a route sample offset. The polygon then carries a repeated vertex
and a zero-length edge, and decomposition fails. `Map._band_polygon` compares
strictly to avoid it. Expect the same trap for any future zone authored at a round
offset.

## The navigation bake is sensitive to outline density

Offsetting all 227 road samples by 570 px put many outline vertices inside a single
rasterisation cell, producing **39 edge-merge errors**. Offsetting a decimated
200 px spine instead, and snapping the outline to whole pixels, brought it down to
**3 warnings**.

Those 3 remain, and milestone 2 supplied the agents to judge them: 27 of 27 enemies
crossed that mesh to reach the cargo and the blocked-unit fallback of §34 fired
**zero** times in a full run. Cosmetic on current evidence — see
[`status.md`](status.md).

## Tooling limits

- `Godot --headless --check-only --script <file>` **does not register autoloads**, so every reference to `InkClock`, `Telemetry`, `RunContext` or `SoundBank` reports as undefined. Filter those out to use it as a lint. Note that this also cascades: a script that merely *depends* on one of those reports `Failed to compile depended scripts` with no clue why, so read the unfiltered output before believing it. Seven of the 53 scripts report the cascade and none of them is broken.
- `--write-movie` **crashes under `--headless`**; it needs a real rendering device. `tools/screenshot_run.tscn` runs windowed and saves the viewport instead.
- `tools/road_calc.py` reproduces Godot's curve baking, so the length and turn demand it prints are the ones the game actually gets. Re-run it after changing the route shape.
