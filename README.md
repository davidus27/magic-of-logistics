# Fantasy Convoy MVP

A proof of concept that tests whether one player can control three systems at
once: the cargo unit, the defenders, and the wizard. Built to
[`fantasy_convoy_mvp_specification.md`](fantasy_convoy_mvp_specification.md);
section numbers in code comments refer to it.

Godot 4.7. GDScript, statically typed.

## Milestone 1 is done: the world foundation

Specification section 41 steps 1 and 2, plus the systems the later milestones
need. You can select profile P1 and a seed, read the controls, and drive the cargo
the length of the 9,000 pixel route to the final portal, through two mud areas,
and complete the four second portal cast into a result screen that writes a
telemetry file.

A fast run takes about 2 minutes 34 seconds. That is short of the three minute
floor in section 7, which assumes the two barriers are in the route: 9,000 pixels
at the 65 px/s Fast speed of section 13.1 is 138 seconds of driving whatever else
happens. The barriers are disabled until the Repair state can open them, so the
floor arrives with milestone 4.

**Not in this build:** enemies, defenders, wizard spells, barriers, the threat
reinforcement spawns, manual cargo steering (profiles P3 and P4), direct target
orders (P2), the full section 30 interface. The selection screen shows P2 to P4
as disabled rather than silently running P1.

## Controls

| Key | Action |
|---|---|
| `W` / `S` | Raise or lower the speed level: Stop, Slow, Normal, Fast |
| `Space` | Stop at once |
| Mouse wheel | Zoom, 0.85 to 1.20 |
| `Escape` | Pause |
| `Enter` | Start the run, or leave the pause screen |
| `F9` | Developer readout |

The remaining keys of sections 14, 16 and 17 are already in the input map, so
later milestones add no configuration.

## Running it

```sh
# Play.
Godot --path . 

# End to end check: drives a whole run and asserts the result. Exits non-zero on
# failure, so it can gate a commit.
Godot --headless --fixed-fps 60 --path . res://tools/smoke_run.tscn

# Screenshots of nine game states, into user://screenshots. Must run windowed:
# saving a viewport image needs a real rendering device.
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tools/screenshot_run.tscn

# Regenerate the route control points after changing its shape.
python3 tools/road_calc.py --target 9000 --wavelength 2800
```

Telemetry lands in `user://telemetry`, which on macOS is
`~/Library/Application Support/Godot/app_userdata/MagicLogisticsInit`.

## How it fits together

```text
main/main.tscn            the scene tree of section 32
  GameController          the state machine of section 8, runs while paused
  World/Map               generates the whole battlefield from one resource
  World/CargoUnit         health and terrain; movement belongs to its motor
  World/CameraRig         follows a point ahead of the cargo, per section 9
  UserInterface           screens, built in code
  TelemetryRecorder       samples the per frame values of section 36
autoload/                 InkClock, SoundBank, Telemetry, RunContext
data/                     every balance value from the specification tables
```

Three decisions worth knowing before you change anything:

**The map is generated, never placed.** `Map.build()` derives the road lines, road
walls, border walls, navigation region, mud zones, barriers and portal from the
control points in `data/map_route.tres`. The route is 9,000 pixels long; hand
placing that much geometry is not maintainable. Move a control point and
everything follows. `tools/road_calc.py` reproduces Godot's curve baking, so the
length and turn demand it prints are the ones the game gets.

**Cargo movement belongs to the motor, not the cargo.** `AutoPathMotor` rides the
route centre line and writes the transform directly; the manual motors of
milestone 5 will steer and use `move_and_slide()`. Keeping that inside the motor is
why `CargoUnit` never branches on the control profile.

**Balance values live in resources.** Section 32.5 requires it. All six resource
types exist already, filled from the specification tables, including the ones for
systems that do not exist yet, so milestone 2 is behaviour only.

## Two engine details that cost time

Both are load-bearing, and both look like working code when wrong.

**A node-typed `@export` does not resolve in a hand-authored `.tscn`.** Writing
`map = NodePath("../World/Map")` leaves the property null, because the Godot editor
stores extra state that a text-authored scene does not have. Scenes here use
`NodePath` exports resolved through [`NodeRef`](scripts/node_ref.gd). The editor
still offers a node picker.

**`Control.set_anchors_preset()` does not size a control.** It sets the anchors and
then adjusts the offsets so the rectangle does not move, and a new control has a
zero sized rectangle. Use `InkUi.fill_parent()`, which calls
`set_anchors_and_offsets_preset()`. A plain `Control` does not clip, so a zero
sized screen still draws its contents and looks like it works while every anchor
inside collapses onto the origin; a `ScrollContainer` does clip and shows nothing.

## Known residual

The navigation bake reports 3 edge merge warnings, down from 39 after decimating
the spine and snapping the outline. They are warnings, not errors, and nothing
navigates yet. Worth finishing in milestone 2, when real agents can validate a fix.
