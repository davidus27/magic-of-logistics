# Progress log

Milestone log for the Fantasy Convoy MVP. Newest milestone first. Section numbers
refer to [`fantasy_convoy_mvp_specification.md`](fantasy_convoy_mvp_specification.md).

---

## Milestone 1 — World foundation

**2026-07-31 · complete and verified**

Specification section 41 steps 1 and 2, plus the systems every later milestone
depends on. The project went from a bare Godot 4.7.1 template (no main scene, no
input map, one placeholder `node_2d.tscn`) to a playable route.

### What works

Select P1 and a seed → read the controls → `Enter` → drive the 9,000 pixel route
with `W`/`S`/`Space` → cross two mud areas → reach the portal → four second cast →
result screen with the five questions of section 37 → telemetry JSON.

Delivered:

- Project configuration: main scene, 1280x720 base viewport, paper clear colour,
  ten named physics layers, the full MVP input map, five autoloads.
- Balance data as resources (section 32.5). All six required types plus
  `MapRouteData` and `DefenderTuning`, filled from the specification tables —
  including defenders, both enemy types and all three spells, which do not exist
  yet as behaviour.
- Paper-and-ink art pipeline: `InkClock` drives the 0.15 second two-frame line
  effect of section 10.3 through one signal; `InkSprite` is its only
  implementation and touches nothing but the texture, so it cannot affect a
  collision shape.
- Procedural map: road lines, road walls, border walls, navigation region, mud
  zones, barriers and portal all generated from one curve.
- Cargo unit with health, damage flash, crack marks, terrain sensing, and
  `AutoPathMotor` for control method A (section 19).
- Camera with the 15 percent lead and 0.20 second response of section 9, wheel
  zoom clamped 0.85 to 1.20.
- Game state machine for the eight states of section 8, including the 480 second
  hard stop of section 7.
- Minimal HUD covering the section 30 regions that have data, with the three
  bottom regions reserved as empty containers so later milestones drop in without
  moving a layout testers have already learned.
- Telemetry recording every field of section 36, and the result screen.

### Verified

| Check | Result |
|---|---|
| Godot import | clean, no errors |
| Parse check, all 26 scripts | clean |
| `tools/smoke_run.tscn` | exit 0, all assertions pass |
| Baked route length | **9000px** against a 9000 target |
| Fast run duration | **154.1s** |
| Terrain events | `Mud, Road, Mud, Road` — both zones entered and exited |
| Time on mud | **34.0s** at the ×0.60 factor of section 12.2 |
| Distance travelled | 8852px, portal triggered 70px short of centre as specified |
| Telemetry file | 31 keys, named `run_<date>_P1_seed10111.json` |
| Camera lead, measured | **108px** = 15% of the 720px viewport, section 9 |
| Visual states | 9 captured and reviewed via `tools/screenshot_run.tscn` |

### Not in this build

Enemies, defenders, wizard spells, barriers, threat reinforcement spawns, manual
cargo steering (P3, P4), direct target orders (P2), the full section 30 interface.
The selection screen shows P2 to P4 as **disabled** rather than silently running
P1, driven by `ControlProfileData.implemented`.

### Decisions

| Decision | Choice | Why |
|---|---|---|
| Language | GDScript, statically typed | No C# setup; MVP speed |
| Road authoring | Generated from a `Curve2D` in a resource | 9,000px of walls and navmesh by hand is not maintainable |
| Road shape | Gently winding, 4 sweeping bends | Minimum turn radius 421px asks 8.8 deg/s of the 80 deg/s in section 13.1, so P3 and P4 keep wide margin |
| Cargo movement | Owned by the motor, not the cargo | Method A writes the transform directly; B and C will steer and use `move_and_slide()`. `CargoUnit` never branches on the profile |
| UI screens | Built in code, not authored scenes | One builder keeps five screens consistent, and they will churn while profiles are compared. The full section 30 interface arrives with milestone 6 |
| Art | The `assets/` pack, except cargo, rider and barrier | See below |

### The assets/ pack

`assets/` appeared partway through the session, after the initial scan showed it
absent; 12 SVGs had already been authored by then. Resolution: take the pack for
everything rotation-agnostic, keep the three hand-authored objects the pack draws
for a side-on view, delete the 6 superseded files.

- **From the pack:** portal, crack marks, dead mark, wizard marker, terrain tiles,
  paper grain, five placeholder WAVs, plus defenders, both enemies, spell effects,
  defender feedback and HUD icons ready for milestones 2 to 6.
- **Kept hand-authored:** `cargo_body`, `cargo_rider`, `barrier`. The pack draws a
  side-view wagon with both wheels below the body and a rider on a stalk, which
  rotates like a spinning logo under a top-down camera; and its barrier is a single
  cross symbol where section 28 needs the full 420px road width.

`SoundBank` now plays real placeholder sounds instead of stubs.

The integration forced one non-obvious rule: `modulate` multiplies, so black art
cannot be tinted lighter. Pack art is drawn in final ink colours and takes no
tint; the hand-authored art is drawn in **white** and tinted at runtime, which is
what allows the damage flash of section 13.2 and the light grey dead marks of
section 15.11 from a single file. `InkSprite` supports both conventions;
[`assets/README.md`](assets/README.md) records why.

### Findings worth acting on

**The three minute floor of section 7 is not reachable in this build, and the
specification is not wrong.** 9,000 pixels at the 65 px/s Fast speed of section
13.1 is 138 seconds of driving before anything else happens, so a fast run is
2:34. The floor works out once the two barriers are in the route: 100 work points
each with the cargo stopped adds roughly 35 seconds. So section 7 and section 13.1
are consistent — but only from milestone 4 onward. The smoke test asserts the band
this build can actually produce, and says so.

**Mud is visually heavy.** The tiled mud fill reads clearly, which is what section
12.2 asks for, but it dominates the paper-and-ink page more than the rest of the
palette does. Worth a look when playing; it is one modulate value in
`TerrainZone.setup_mud`.

### Bugs found and fixed during verification

Two were engine traps that look like working code when wrong. Both are recorded in
[`README.md`](README.md) because they will recur.

1. **A node-typed `@export` never resolves in a hand-authored `.tscn`.** Writing
   `map = NodePath("../World/Map")` leaves the property null: the Godot editor
   stores extra state a text-authored scene does not have. Every scene reference
   now goes through `NodePath` exports and
   [`scripts/node_ref.gd`](scripts/node_ref.gd), which reports which node and
   which field on a bad path.
2. **`Control.set_anchors_preset()` does not size a control.** It sets the anchors
   and then adjusts the offsets so the rectangle does not move, and a new control
   has a zero sized rectangle. This blanked the result screen, because a
   `ScrollContainer` clips, while the profile select screen *looked* correct,
   because a plain `Control` does not clip: it drew its contents with every anchor
   inside collapsed onto the origin. Fixed with `InkUi.fill_parent()`.
3. **Mud collision polygons failed convex decomposition.** Mud zone offsets in the
   route data are round numbers that land exactly on a route sample offset, so the
   polygon carried a repeated vertex and a zero length edge. `_band_polygon` now
   compares strictly.
4. **Navigation bake reported 39 edge merge errors.** Offsetting all 227 road
   samples by 570 pixels put many outline vertices inside one rasterisation cell.
   Reduced to 3 by offsetting a 200 pixel spine instead and snapping the outline
   to whole pixels.
5. A parse error in `profile_select.gd` (`get_meta()` returns Variant, so the type
   could not be inferred) had cascaded into every exported node reference reading
   as `Nil`.

### Known residual

The navigation bake still reports **3 edge merge warnings**, down from 39. They
are warnings, not errors, and nothing navigates yet. Deliberately left for
milestone 2, when real agents can validate a fix instead of guessing at geometry.

### Notes on tooling

- `Godot --headless --check-only --script <file>` does not register autoloads, so
  every reference to `InkClock`, `Telemetry`, `RunContext` or `SoundBank` reports
  as undefined. Filter those to use it as a lint.
- `--write-movie` crashes under `--headless`; it needs a real rendering device.
  `tools/screenshot_run.tscn` runs windowed and saves the viewport instead.
- `tools/road_calc.py` reproduces Godot's curve baking, so the length and turn
  demand it prints are the ones the game gets.

### Next: milestone 2, the first combat loop

Section 41 steps 3 to 6: one short-range enemy, one defender with Defend, Attack,
Return and Downed, trigger area 1, cargo damage and the failure state, the wizard
controller with mana and Arc Bolt, defender selection (`F1` to `F4`, `Q`) and role
orders (`Z`, `X`, `C`). The balance data for all of it is already in `data/`, so
this is behaviour only.

**Before starting it:** play milestone 1. Control feel is the entire point of the
proof of concept and no assertion substitutes for it. Two questions in particular:
are Slow, Normal and Fast distinct enough to be a real decision, and does the mud
slowdown read as a threat or as an annoyance?
