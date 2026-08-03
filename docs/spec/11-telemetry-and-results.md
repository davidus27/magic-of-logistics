# Telemetry and result screen — §36–37

**Implemented.** `autoload/telemetry.gd`, `main/telemetry_recorder.gd`,
`ui/result_screen.gd`. All 31 fields are recorded and the smoke test asserts the
key set, so adding a field means updating `tools/smoke_run.gd` too.

## 36. Telemetry

The game writes one JSON file after each run.

The game stores the file in the Godot `user://` directory.

The file name contains the date, profile, and seed — for example
`run_<date>_P1_seed10111.json`.

On macOS `user://telemetry` resolves to
`~/Library/Application Support/Godot/app_userdata/MagicLogisticsInit`.

The telemetry file contains these values:

- Control profile
- Test seed
- Success or failure
- Run duration
- Cargo health at the end
- Maximum threat value
- Distance traveled
- Time at each cargo speed
- Time on each terrain type
- Number of cargo direction changes
- Number of defender selections
- Number of defender orders
- Number of direct target orders
- Number of spell selections
- Number of spell casts
- Number of invalid spell casts
- Mana spent
- Damage to the cargo unit
- Damage to defenders
- Defender deaths
- Cargo repair amount
- Barrier work amount
- Defender idle time
- Defender time outside the defense radius
- Pause count
- Total pause time

Fields for systems that do not exist yet are recorded as zero, not omitted — the
key set must stay stable so profile runs stay comparable.

## 37. Result screen

The result screen shows objective results first.

The screen shows these values:

- Success or failure
- Run time
- Cargo health
- Defender survivors
- Defender orders
- Spell casts
- Pause count
- Maximum threat value

The screen then asks five test questions.

The player gives a value from one to five for each question.

The questions are:

1. I understood the active controls.
2. I could control the cargo unit.
3. I could control the defenders.
4. I could use wizard spells during other actions.
5. I want to play this control profile again.

The result screen stores these answers in the telemetry file.
