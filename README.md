# Fantasy Convoy MVP

A proof of concept that tests whether one player can control three systems at
once: the cargo unit, the defenders, and the wizard.

Godot 4.7. GDScript, statically typed.

**Milestone 2 (the first combat loop) is done.** Press Start and drive the 9,000
pixel route while six enemy groups attack it, command four defenders, cast Arc
Bolt, and either reach the portal or watch the cargo health reach zero.

**Not in this build:** the long-range enemy, Mend and Ward, and barriers. Each is
disabled visibly rather than silently.
**[`docs/status.md`](docs/status.md)** is the file to read before doing anything
here — what is built, what is next, and the five places the specification needed a
decision.

## Controls

| Key | Action |
|---|---|
| `W` / `S` | Raise or lower the speed level: Stop, Slow, Normal, Fast |
| `Space` | Stop at once |
| `F1` to `F4` | Select one defender. Hold `Shift` to add to the selection |
| `Q` | Select all living defenders |
| `Z` / `X` / `C` | Order the selection to Attack, Defend or Repair |
| `1` `2` `3` | Choose a spell. Only Arc Bolt is in this build |
| Left mouse | Cast the chosen spell. Hold to repeat Arc Bolt |
| Mouse wheel | Zoom, 0.85 to 1.20 |
| `Escape` | Pause |
| `Enter` | Start the run, or leave the pause screen |
| `F9` | Developer readout |

A click on a defender portrait also selects it. A click on empty ground never
does — that would take the left mouse button away from the wizard (spec §16).

## Running it

```sh
# Play.
Godot --path .

# Commit gate 1. Plays a whole run badly on purpose and asserts the result.
Godot --headless --fixed-fps 60 --path . res://tools/smoke_run.tscn

# Commit gate 2. Drives the states a successful run never reaches: downed, dead,
# revive, repair at each speed, rejected casts, and the failure path.
Godot --headless --fixed-fps 60 --path . res://tools/behaviour_checks.tscn

# Screenshots of 13 game states, into user://screenshots. Must run windowed:
# saving a viewport image needs a real rendering device.
Godot --fixed-fps 60 --resolution 1280x720 --path . res://tools/screenshot_run.tscn

# Regenerate the route control points after changing its shape.
python3 tools/road_calc.py --target 9000 --wavelength 2800
```

## How it fits together

```text
main/main.tscn            the scene tree of section 32
  GameController          the state machine of section 8, runs while paused
  World/Map               generates the whole battlefield from one resource
  World/CargoUnit         health and terrain; movement belongs to its motor
  World/Squad             the four defenders, their formation, selection, orders
  World/EnemySpawner      the six trigger areas of section 26, seeded
  World/Wizard            mana, spell choice, casting, and the range aids
  World/CameraRig         follows a point ahead of the cargo, per section 9
  UserInterface           screens and the head-up display, built in code
autoload/                 InkClock, SoundBank, RunContext
data/                     every balance value from the specification tables
docs/                     the specification, split by system, plus status
tools/                    smoke_run, behaviour_checks, screenshot_run, road_calc.py
```

Five decisions worth knowing before you change anything:

**The map is generated, never placed.** `Map.build()` derives the road lines, road
walls, border walls, navigation region, mud zones, barriers and portal from the
control points in `data/map_route.tres`. Move a control point and everything
follows. `tools/road_calc.py` reproduces Godot's curve baking, so the length and
turn demand it prints are the ones the game gets.

**Cargo movement belongs to the motor, not the cargo.** `AutoPathMotor` rides the
route centre line and writes the transform directly. Keeping movement inside the
motor is why `CargoUnit` never branches on which motor is active — it asks the
motor's `can_leave_road()` instead.

**Balance values live in resources.** Section 32.5 requires it. All seven resource
types exist already, filled from the specification tables, including the ones for
systems that do not exist yet, so the remaining milestones are behaviour only.

**A unit asks to move; it does not move itself.** A defender or enemy state calls
`move_toward()` or `hold_still()` once per physics step and `UnitBody` decides what
that means after terrain, avoidance and separation. A state that asks for nothing
gets a unit that stands still, so a forgotten branch stops a unit rather than
letting it drift on last frame's velocity.

**Anything not in the build is disabled, never hidden and never faked.**
`SpellData.implemented` greys out Mend and Ward, and `EnemySpawner` logs the
long-range enemies it could not create instead of quietly spawning a smaller
group. A tester should always be able to see the shape of the finished game.

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
