# Profiles, input priority, testing and build order — §22–24, §38–43

The reason the project exists: comparing control profiles. Read §22 before touching
any input handling.

## 22. Input priority rules

The keyboard movement input always controls the cargo unit.

The number keys always select wizard spells.

The left mouse button always casts the selected spell.

The right mouse button gives defender target orders only in method B.

The function keys always select defenders.

The role keys always give defender orders.

The user interface consumes pointer input above its controls.

**A user interface click cannot cast a spell.**

The game accepts simultaneous input from different input groups.

The player can steer, cast, and give an order during one simulation frame.

## 23. Recommended first control profile

The first build must use automatic cargo movement and role orders.

This profile gives the lowest control load.

This profile is the baseline for all other tests.

The player controls cargo speed, defender roles, spell selection, and spell targets.

## 24. Test profiles

The build must contain these four profiles:

| Profile | Cargo control | Defender control | Test purpose | Status |
|---|---|---|---|---|
| P1 | Automatic path | Role orders | Baseline control load | in progress, M2 |
| P2 | Automatic path | Direct target orders | Defender target load | disabled |
| P3 | Road-limited manual | Role orders | Cargo steering load | disabled |
| P4 | Free manual | Role orders | Maximum cargo control load | disabled |

The test must change one main control factor at a time.

The test does not need all six possible combinations.

The same map and enemy seed must apply to each profile.

P2 to P4 render as **disabled** on the selection screen rather than silently running
P1. That is driven by `ControlProfileData.implemented` in `data/profiles/`.

## 38. Test procedure

Use the same map and seed for a profile comparison.

Do not explain hidden artificial intelligence rules during the first run.

Explain only the input controls and the objective.

Run each profile at least three times.

Change the profile order between players.

This change reduces the effect of player practice.

After each run, complete the five result questions.

After three runs, record one short spoken comment answering:

> Which task caused the most control problems?

## 39. Control profile evaluation

A good control profile must meet these conditions:

- The player completes at least two of three runs.
- The player gives control clarity a value of four or five.
- The player gives wizard use a value of four or five.
- The player does not pause more than three times in one run.
- The player does not give more than 40 defender orders in one run.
- The player can explain each defender death.
- The player reports useful control over defenders.
- The player reports enough time for wizard spells.

A profile fails when the player reports loss of control without a clear recovery
action.

## 40. MVP acceptance criteria

The MVP is complete when all these conditions are true:

- All four control profiles work on the same map.
- The player can change the control profile before a run.
- The cargo unit can reach the final portal.
- Both enemy types can attack the cargo unit.
- Defenders can attack, defend, and repair.
- The wizard can cast all three spells.
- The final portal can complete a run.
- Cargo destruction can fail a run.
- The result screen shows test data.
- The telemetry file contains all required values.
- No unit stays blocked for more than two seconds.
- The game keeps at least 60 frames per second on the test computer.
- All important orders have visual and sound feedback.

Tracked as a live checklist in [`../status.md`](../status.md).

## 41. Implementation order

Build the MVP in this order:

1. Build the map, road, cargo unit, and final portal.
2. Add automatic cargo movement.
3. Add one short-range enemy.
4. Add one defender with Defend and Attack states.
5. Add cargo health and run failure.
6. Add Arc Bolt.
7. Add all four defenders.
8. Add Repair state and one barrier.
9. Add the long-range enemy.
10. Add Mend and Ward.
11. Add direct target orders.
12. Add road-limited cargo movement.
13. Add free cargo movement.
14. Add user interface feedback.
15. Add the threat system.
16. Add telemetry and the result screen.
17. Add the second barrier and final balance values.
18. Run the four profile tests.

**Current position in this list is tracked in [`../status.md`](../status.md)** — that
table, not this one, is the source of truth for what is done.

## 42. Decisions after the MVP test

The test must answer these questions:

- Does direct cargo steering add useful decisions?
- Does direct cargo steering prevent wizard use?
- Does automatic cargo movement feel too passive?
- Do role orders give enough defender control?
- Do direct target orders require too many actions?
- Can the player understand automatic defender targets?
- Can the player use spells without loss of cargo control?
- Does the player need a slow-motion command?
- Does the player need one command for all defenders?
- Does repair create a useful stop or speed decision?

**Do not add campaign systems before these questions have clear answers.**

## 43. Initial design recommendation

Use profile P1 as the first public prototype.

Profile P1 uses automatic cargo movement and role orders.

This profile keeps the focus on speed choice, defender policy, and wizard spells.

Use profile P2 to test the need for exact enemy targets.

Use profile P3 to test the cost of cargo steering.

Use profile P4 only after the player understands the other systems.

Free movement can add route choice, but it can also remove the convoy defense focus.
