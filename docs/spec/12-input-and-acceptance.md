# Input priority and acceptance criteria — §22, §40

Read §22 before touching any input handling.

## 22. Input priority rules

The keyboard movement input always controls the cargo unit.

The number keys always select wizard spells.

The left mouse button always casts the selected spell.

The function keys always select defenders.

The role keys always give defender orders.

The user interface consumes pointer input above its controls.

**A user interface click cannot cast a spell.**

The game accepts simultaneous input from different input groups.

The player can steer, cast, and give an order during one simulation frame.

## 40. MVP acceptance criteria

The MVP is complete when all these conditions are true:

- The cargo unit can reach the final portal.
- Both enemy types can attack the cargo unit.
- Defenders can attack, defend, and repair.
- The wizard can cast all three spells.
- The final portal can complete a run.
- Cargo destruction can fail a run.
- No unit stays blocked for more than two seconds.
- The game keeps at least 60 frames per second on the test computer.
- All important orders have visual and sound feedback.

Tracked as a live checklist in [`../status.md`](../status.md).
