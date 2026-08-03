# Fantasy Convoy MVP

A proof of concept that tests whether one player can control three systems at
once: the cargo unit, the defenders, and the wizard.

Godot 4.7. GDScript, statically typed.

**Milestone 1 (world foundation) is committed.** Select profile P1 and a seed, read
the controls, drive the cargo the length of the 9,000 pixel route through two mud
areas to the final portal, and complete the four second portal cast into a result
screen that writes a telemetry file.

**Milestone 2 (the first combat loop) is in progress and uncommitted** — roughly
2,550 lines of defenders, enemies, wizard and squad selection sit in the working
tree. The smoke test currently **fails**: its assertions predate the combat build,
and the cargo dies partway along the route. Neither is a mystery; both are written
up with next actions in **[`docs/status.md`](docs/status.md)**, which is the file to
read before doing anything here.

## Controls

| Key | Action |
|---|---|
| `W` / `S` | Raise or lower the speed level: Stop, Slow, Normal, Fast |
| `Space` | Stop at once |
| Mouse wheel | Zoom, 0.85 to 1.20 |
| `Escape` | Pause |
| `Enter` | Start the run, or leave the pause screen |
| `F9` | Developer readout |

The remaining keys of spec sections 14, 16 and 17 are already in the input map, so
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
docs/                     the specification, split by system, plus status
tools/                    smoke_run, screenshot_run, road_calc.py
```

Three decisions worth knowing before you change anything:

**The map is generated, never placed.** `Map.build()` derives the road lines, road
walls, border walls, navigation region, mud zones, barriers and portal from the
control points in `data/map_route.tres`. Move a control point and everything
follows. `tools/road_calc.py` reproduces Godot's curve baking, so the length and
turn demand it prints are the ones the game gets.

**Cargo movement belongs to the motor, not the cargo.** `AutoPathMotor` rides the
route centre line and writes the transform directly; the manual motors of milestone
5 will steer and use `move_and_slide()`. Keeping that inside the motor is why
`CargoUnit` never branches on the control profile.

**Balance values live in resources.** Section 32.5 requires it. All eight resource
types exist already, filled from the specification tables, including the ones for
systems that do not exist yet, so the remaining milestones are behaviour only.

## Documentation

The specification used to be one 32 KB file. It is now split by system under
[`docs/`](docs/), so you load only the part you are working on. Section numbers are
preserved in every heading, so a code comment reading "section 15.7" still resolves.

| Start here | For |
|---|---|
| [`docs/status.md`](docs/status.md) | What is built, what is next, open findings |
| [`docs/README.md`](docs/README.md) | Index mapping every spec section to its file |
| [`docs/engine-notes.md`](docs/engine-notes.md) | Godot behaviours that look like working code when wrong |
| [`docs/spec/`](docs/spec/) | The behaviour specification, one file per system |
| [`docs/milestones/`](docs/milestones/) | Closed milestone reports |

## Editor setup

This repo is configured for Cursor. `.cursor/rules/` carries the project context and
conventions, `.cursor/mcp.json` wires up the Godot MCP server, `.cursor/cli.json`
scopes agent permissions to this folder, and `.cursorignore` keeps the 8 MB of
generated import cache and binary art out of agent context.
