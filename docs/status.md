# Status

**Single source of truth for what is built and what comes next.** Update this file
in the same commit as the work it describes.

| | |
|---|---|
| Engine | Godot 4.7.1, GDScript, statically typed |
| Last committed milestone | **Milestone 1 — World foundation**, verified 2026-07-31 |
| Current work | **Milestone 2 — first combat loop**, branch `first-combat`, **~2,550 lines uncommitted** |
| Smoke test | 🔴 **FAILING — 5 assertions.** See below. This is the commit gate. |
| Last verified run | 2026-08-03: cargo destroyed at 3,882 px of the 8,900 px route, 34.1 s |

---

## 🔴 The smoke test is failing

`tools/smoke_run.tscn` is the commit gate and it does not pass. Two separate
problems are tangled together in the output — sort them apart before touching
anything else.

**1. The harness is stale.** Its assertions were written for the milestone 1 build
and now contradict the game. Verbatim from the run:

```
FAIL: cargo lost health with no enemies in the build
FAIL: run took 34.1s, outside the 120 to 360 band this build should produce
FAIL: entered mud 1 times, expected 2
FAIL: travelled only 3882px of a 8900px route
FAIL: run failed, reason cargo_destroyed
```

Only the first is purely a stale assertion — there *are* enemies now. The middle
three are all downstream of the run ending early, not independent bugs. Rewrite the
harness so it drives and asserts a combat run: survive to the portal, or assert a
deliberate expected outcome.

**2. The combat loop is lethal.** With four defenders on the field the cargo dies
43 % of the way along the route, inside the first three enemy groups. That is a real
balance or defender-behaviour finding, not a test artefact. Decide which it is before
tuning numbers — a defender that never engages looks identical to an enemy that hits
too hard.

Also still open from milestone 1: the navigation bake logs **3 edge-merge errors**
on every run. Real agents now exist to validate a fix, which is why this milestone
owns it.

---

## Implementation order

The 18 steps of [`spec/12-profiles-and-testing.md`](spec/12-profiles-and-testing.md)
§41, which is the authority on build order.

| # | §41 step | Status | Milestone |
|---:|---|---|---|
| 1 | Build the map, road, cargo unit, and final portal | ✅ committed | M1 |
| 2 | Add automatic cargo movement | ✅ committed | M1 |
| 3 | Add one short-range enemy | 🟡 built, uncommitted — spawns in groups 1–3 | M2 |
| 4 | Add one defender with Defend and Attack states | 🟡 built, uncommitted — four on the field, not one | M2 |
| 5 | Add cargo health and run failure | 🟡 built, uncommitted — failure path fires, currently too easily | M2 |
| 6 | Add Arc Bolt | 🟡 built, uncommitted — **unverified**, the smoke test never casts | M2 |
| 7 | Add all four defenders | 🟡 arrived early with step 4 | M3 → M2 |
| 8 | Add Repair state and one barrier | ⬜ map reports `0 barriers` | M4 |
| 9 | Add the long-range enemy | ⬜ group 2 logs `2 long-range deferred` | M4 |
| 10 | Add Mend and Ward | ⬜ | not pinned |
| 11 | Add direct target orders | ⬜ | not pinned |
| 12 | Add road-limited cargo movement | ⬜ | M5 |
| 13 | Add free cargo movement | ⬜ | M5 |
| 14 | Add user interface feedback | 🟡 partial — portraits, spell buttons, mana bar and health bars exist | M6 |
| 15 | Add the threat system | ⬜ | |
| 16 | Add telemetry and the result screen | ✅ committed, now 34 keys | M1 |
| 17 | Add the second barrier and final balance values | ⬜ | |
| 18 | Run the four profile tests | ⬜ | |

Milestone anchors the documents state outright: M1 = steps 1–2, M2 = steps 3–6 plus
defender selection and role orders, M4 brings the barriers, M5 brings the manual
cargo motors, M6 brings the full §30 interface. **Steps 10–11 and the M3 boundary
are not pinned down anywhere** — and step 7 has already landed inside M2, so M3 as
originally sketched is now empty. Re-cut the remaining milestones before planning.

---

## Milestone 2 — what exists, uncommitted

~2,550 lines across these files. None of it is in git yet.

| Area | Files |
|---|---|
| Shared unit base | `world/units/unit_body.gd` (335), `unit_health_bar.gd` (39) |
| Defenders | `world/defenders/defender.gd` (407), `defender_states.gd` (244), `squad.gd` (225), `defender.tscn` |
| Enemies | `world/enemies/enemy.gd` (177), `enemy_states.gd` (86), `enemy_spawner.gd` (170), `enemy_short_range.tscn` |
| Wizard | `world/wizard/wizard.gd` (303), `arc_bolt.gd` (85), `arc_bolt.tscn` |
| State machine | `scripts/fsm/state_machine.gd` (71), `unit_state.gd` (29) |
| Targeting | `scripts/combat_target.gd` (82) |
| UI | `ui/defender_portrait.gd` (108), `ui/spell_button.gd` (97), `ui/mana_bar.gd` (49), plus 232 changed lines in `ui/hud.gd` |
| Data | `data/enemy_schedule.tres`, `scripts/data/enemy_schedule_data.gd` (28) |
| Modified | `main/game_controller.gd`, `world/cargo/cargo_unit.gd`, `autoload/telemetry.gd`, `data/enemies/enemy_short_range.tres`, `data/spells/*.tres`, `data/defender_tuning.tres` |

Confirmed working from the run log: the squad forms (`[Squad] 4 defenders on the
field`), the spawner fires on schedule (`group 1 at offset 700: 4 spawned`), and
long-range enemies are cleanly deferred rather than faked.

### To finish milestone 2

1. **Fix the smoke test**, then use it to judge the balance problem above.
2. **Verify Arc Bolt.** 388 lines of wizard and projectile code that no automated run exercises. Either extend the harness to cast, or verify by hand and say so.
3. **Confirm the role orders and selection of §16–17** — `Z`/`X`/`C`, `F1`–`F4`, `Q`, `Shift`+key, portrait clicks. `squad.gd` looks like the owner; nothing tests it.
4. **Repair orders must not silently do nothing.** §15.8's last line says a defender with no repair work available uses Defend behaviour. Barriers arrive in M4, so `C` must fall through, not no-op.
5. **Close the 3 navigation edge-merge errors.**
6. **Commit.** 2,550 lines outside git is the largest risk on this list.

### Do this before calling milestone 2 done

**Play it.** Control feel is the entire point of the proof of concept and no
assertion substitutes for it. Two questions carried over from milestone 1 that are
still unanswered, plus two new ones:

1. Are Slow, Normal and Fast distinct enough to be a real decision?
2. Does the mud slowdown read as a threat, or as an annoyance?
3. Can you cast Arc Bolt without losing track of the cargo? (§42's central question)
4. When a defender picks its own target, can you tell why?

---

## Still absent

Not bugs. Do not "fix" these without checking the milestone that owns them.

| Missing | Owner |
|---|---|
| Long-range enemy — deferred explicitly by the spawner | M4 |
| Barriers — generated but collision disabled, map logs `0 barriers` | M4 |
| Repair defender state | M4, with the barriers |
| Mend and Ward | §41 step 10 |
| Threat reinforcement spawns | §41 step 15 |
| Manual cargo steering, profiles P3 and P4 | M5 |
| Direct target orders, profile P2 | §41 step 11 |
| §30.6 world feedback — target lines, leash circles, return arrows | M6 |

Profiles P2–P4 render as **disabled** on the selection screen rather than silently
running P1, driven by `ControlProfileData.implemented` in `data/profiles/`. Flip a
flag only when the profile works end to end.

---

## Open findings

**⚠️ Fast speed is stated as two different numbers.** §13.1 and
`data/cargo_data.tres` both say **130 px/s**. `README.md`, the milestone 1 report and
the header comment of `tools/smoke_run.gd` all say **"the 65 px/s Fast speed of
section 13.1"**, and measurement agrees with the lower figure. `AutoPathMotor` applies
`speed_for_level() * terrain_factor` with no visible halving. One of the two is
wrong, and the §7 run-duration maths depends on which. Fix all three comments and the
harness band in the same commit as whichever value wins.

**The three-minute floor of §7 is not reachable until the barriers exist.** 9,000 px
of driving happens before anything else does; the floor closes once two barriers at
100 work points each stop the cargo, worth roughly 35 s. §7 and §13.1 are consistent
— but only from M4 onward.

**Mud is visually heavy.** The tiled fill reads clearly, which is what §12.2 asks
for, but it dominates the paper-and-ink page more than the rest of the palette does.
One `modulate` value in `TerrainZone.setup_mud`.

**Telemetry grew from 31 keys to 34** with the combat fields. The key set must stay
stable across profile runs — if a field only exists for some profiles, record it as
zero rather than omitting it (§36).

---

## Milestone 1 verification, for reference

Full report: [`milestones/milestone-01-world-foundation.md`](milestones/milestone-01-world-foundation.md).

| Check | Result |
|---|---|
| Godot import | clean, no errors |
| Parse check, all 26 scripts | clean |
| `tools/smoke_run.tscn` | exit 0, all assertions pass |
| Baked route length | **9000 px** against a 9000 target |
| Fast run duration | **154.1 s** |
| Terrain events | `Mud, Road, Mud, Road` — both zones entered and exited |
| Time on mud | **34.0 s** at the ×0.60 factor of §12.2 |
| Distance travelled | 8852 px, portal triggered 70 px short of centre as specified |
| Telemetry file | 31 keys, named `run_<date>_P1_seed10111.json` |
| Camera lead, measured | **108 px** = 15 % of the 720 px viewport, §9 |
| Visual states | 9 captured and reviewed via `tools/screenshot_run.tscn` |

---

## MVP acceptance criteria

§40. The MVP is complete when every line is true.

- [ ] All four control profiles work on the same map
- [ ] The player can change the control profile before a run
- [ ] The cargo unit can reach the final portal — **regressed**: it did in M1, it dies at 3,882 px now
- [ ] Both enemy types can attack the cargo unit — short-range only
- [ ] Defenders can attack, defend, and repair — no Repair until M4
- [ ] The wizard can cast all three spells — Arc Bolt built but unverified
- [x] The final portal can complete a run
- [x] Cargo destruction can fail a run
- [x] The result screen shows test data
- [x] The telemetry file contains all required values
- [ ] No unit stays blocked for more than two seconds — untested, and 3 navmesh errors stand
- [x] The game keeps at least 60 frames per second on the test computer
- [ ] All important orders have visual and sound feedback
