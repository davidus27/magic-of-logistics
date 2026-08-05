# Milestone 2 — The first combat loop

**2026-08-03 · complete and verified**

Specification section 41 steps 3 to 7, plus cargo repair from step 8 and the
section 30 interface regions the new systems need. Profile P1 went from a route
you drive to a game you can lose.

## What works

Select P1 → `Enter` → drive the route while six enemy groups attack it → select
defenders with `F1` to `F4` or `Q` → order Attack, Defend or Repair with `Z`,
`X`, `C` → cast Arc Bolt with the left mouse button → reach the portal, or watch
the cargo health reach zero and fail.

Delivered:

- **Short-range enemy** (section 25.1) with its own state machine. It moves at
  the cargo, attacks a defender that blocks its route and the cargo when none
  does, retargets every 0.50 seconds, and leaves a grey paper mark for two
  seconds when it dies (section 29).
- **All six enemy trigger areas** (section 26), fired on route offset rather than
  on an overlap, and placed from the seeded generator of section 35. The
  short-range half of every group spawns; the long-range half is counted and
  logged as deferred rather than quietly dropped.
- **Four defenders** with all seven states of section 15.4 — Follow, Defend,
  Attack, Repair, Return, Downed, Dead — as explicit state objects with enter,
  update and exit and one signal per change, which is what section 33 asks for.
  The telemetry recorder counts every change.
- **Defender selection and role orders** (sections 16 and 17), by key and by
  portrait click. A world click never selects, so the left mouse button stays the
  wizard's, as section 16 requires.
- **Wizard** with the 100 mana and 8 per second of section 14.2, spell selection
  on `1` `2` `3`, the range circle of 14.3, the maximum-target line of 14.4, and
  Arc Bolt with hold-to-repeat.
- **Cargo repair** on the rear work points at Stop or Slow speed only, and the
  enemy push-out of section 13.3.
- **Head-up display**: four portraits with health, state, selection and the
  downed timer; three order controls whose labels follow the active defender
  method; three spell controls with cost and cooldown over a mana bar.
- **`tools/behaviour_checks.tscn`**, a second headless harness for the states a
  successful run never reaches.

## Verified

| Check | Result |
|---|---|
| Godot import | clean, no errors |
| Parse check, all 53 scripts | clean (7 report the known `--check-only` autoload cascade) |
| `tools/smoke_run.tscn` | exit 0, all assertions pass |
| `tools/behaviour_checks.tscn` | exit 0, all assertions pass |
| Run duration at Normal speed | **112.7s** |
| Enemy groups fired | **6 of 6**, 27 enemies spawned, peak 8 alive |
| Enemies killed | **27 of 27** |
| Damage to cargo / to defenders | **32 / 125** |
| Defenders inside the 480px attack leash | **100%** of the run, furthest 287px |
| Blocked-unit fallbacks, section 34 | **0** |
| Arc Bolt casts | **45**, 0 invalid, 225 mana |
| Downed timer | 15.0s, then Dead with no collision shape |
| Cargo repair | **+38 health** at Stop, **0** at Fast |
| Telemetry file | 35 keys |
| Visual states | 13 captured and reviewed via `tools/screenshot_run.tscn` |

## Not in this build

Long-range enemy (section 25.2), Heal and Shield, barriers, direct target orders
(P2), manual cargo steering (P3, P4), threat reinforcement spawns, the section
30.6 world feedback. Heal and Shield appear on the spell controls as **not in this
build**, driven by a new `SpellData.implemented` flag, and cannot be selected —
the same pattern the selection screen already uses for profiles P2 to P4.

## Where the specification needed a decision

Five places where the text does not decide the case, or decides it in a way that
does not survive four defenders. Each is a candidate to change in the
specification rather than in the code.

| Question | Choice | Why |
|---|---|---|
| What does Follow do when an enemy arrives? | Change to Defend | 15.5 says Follow applies "when no other state applies", and 15.6 gives Defend an automatic interception inside the defence radius. Once an enemy is that close, Defend applies. Without this a player who has not yet pressed `X` watches four defenders escort a wagon being eaten |
| Which enemy does each defender intercept? | The nearest to the cargo **that no other defender is on** | 15.6 is written for one defender. Four defenders reading it at once all intercept the same enemy while the rest of a group walks in |
| Defenders cannot keep up with the cargo | A catch-up speed, used only when walking to a slot | 15.2 gives defenders 70 to 105 px/s and 13.1 gives the cargo 90 at Normal and 130 at Fast. Only the Striker can hold the assigned position of 15.6 at Normal, and **nobody** can at Fast. Interception, pursuit and repair all still use the 15.2 speed, so the statistic still decides every fight |
| Defender attack range | 34px, in `DefenderTuning` | 25.1 gives the enemy 28px and the specification gives the defender none. A little longer, so a defender that closes strikes first |
| What counts as "blocks its route"? | Within 55px of the line to the cargo, or already in reach | 25.1 names the rule without giving a width. A defender standing in the way blocks; one running past does not |

The first three are worth a decision before the profile tests run. The catch-up
in particular changed the shape of the game: with it, cargo damage over a full
run halved and defender damage tripled, because the escort finally screens the
wagon instead of trailing it.

## Bugs found and fixed during verification

1. **`NavigationAgent2D.max_speed` silently discarded every speed scale.** The
   avoidance solver clamps the velocity it returns to `max_speed`, and that cap
   was computed from the unit's own speed without the current request's scale, so
   the catch-up above did nothing at all while reading as correct in the code.
   Measured before and after: defenders inside the attack leash **81% against
   100%**, furthest **1008px against 287px**, cargo damage **64 against 32**.
2. **The test harnesses stopped the game from pausing.** `smoke_run` and
   `screenshot_run` set `PROCESS_MODE_ALWAYS` on themselves so they can drive the
   paused screens, and the whole instanced game is their child, so it inherited
   that and never paused. Both now set the game to `PROCESS_MODE_PAUSABLE`
   explicitly. Nothing was wrong in the game — the harnesses were testing a
   different one.
3. **`EnemySpawner` indexed its arming record before `build()` sized it**, once
   per physics frame for the whole profile selection screen.
4. **The three bottom interface regions overlapped.** The fourth defender
   portrait sat on top of the Attack order control. The three widths are now
   fixed and documented against the 1280 pixel canvas rather than fitted.
5. **The spell range circle was invisible.** Drawn in the light line colour at
   1.5px, a 500 pixel circle whose visible part is two thin arcs disappeared into
   the paper. Confirmed by scanning the captured screenshot for the colour before
   changing anything — the circle was there, at exactly the right radius. Now
   medium grey at 2px.

## Findings worth acting on

**The smoke test was already failing before this milestone started.** On the
initial commit it reported 79.9s against a 120 to 360 second band. See the Fast
speed entry in [`../status.md`](../status.md) for why.

**Section 7 is still out of reach, and now it is measurable.** A full
Normal-speed run with all six enemy groups is 112.7 seconds against a three to
six minute target. Reaching the floor needs Slow, which is 180 seconds of driving
by itself, or the two barriers, which add roughly 35 seconds.

**A passive player survives.** The smoke run gives one order at the start, holds
one speed and casts at whatever is nearest, and still finishes with the cargo at
68 health and three or four defenders alive. That is the right side of the line
for a first-time tester, but it leaves little room for the long-range enemy, the
reinforcements of section 27 and the two barriers still to come. Expect to
revisit it once those land rather than tuning now.

**Combat outcomes are not bit-reproducible between runs of the same seed.**
Section 35 requires the seed to fix enemy *spawn positions*, and it does — the
spawner draws only from `RunContext.rng`. But the navigation server resolves
avoidance across threads, so two runs of seed 1 ended with 0 and 1 defender
deaths. Testers comparing profiles should treat a single run as a sample.

## Notes on tooling

- `tools/behaviour_checks.tscn` is new and joins `smoke_run` as a commit gate. It
  drives Downed, Dead, revive, repair at each speed, the three cast rejections
  and the failure state through the same public calls the game uses.
- `tools/screenshot_run.tscn` grew from 9 shots to 13 and now drives the cargo to
  the first fight instead of teleporting it. A teleport leaves the defenders
  behind, and the catch-up closes that gap at only 25 px/s, so the combat shots
  used to show a strung-out squad that no real run produces.
- The `--check-only` autoload limitation from milestone 1 now also produces
  "Failed to compile depended scripts" cascades, because more scripts depend on
  the ones that reference an autoload. Seven of the 53 report it. Read the
  unfiltered output before believing any of them.

## Known residual

The navigation bake still reports **3 edge merge warnings**, unchanged from
milestone 1 and deliberately not addressed here. Real agents now navigate that
mesh, and they navigate it correctly: 27 of 27 enemies crossed it to reach the
cargo, and the blocked-unit fallback of section 34 fired **zero** times in a full
run. The warnings are cosmetic on current evidence.
