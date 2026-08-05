# Status

**Single source of truth for what is built and what comes next.** Update this file
in the same commit as the work it describes.

| | |
|---|---|
| Engine | Godot 4.7.1, GDScript, statically typed |
| Last completed milestone | **Milestone 2 — the first combat loop**, verified 2026-08-03 |
| Current work | Phase A balance pass landed (below); milestone 3 is not yet cut |
| Commit gates | 🔴 `smoke_run` exit 1 (see below) · 🟢 `behaviour_checks` exit 0 |
| Last verified run | 2026-08-04: portal reached in 112.7 s at Normal, cargo 44/100, 27 of 27 enemies killed — predates the long-range enemy going live |

---

## Phase A: dynamism tuning

A small balance pass ahead of milestone 3, closing two "free" actions the passive
smoke run exposed. Not new content — the plumbing and priority ordering were
already correct, so this only moved numbers that already existed.

- **Short-range enemy speed 82 to 100** (`data/enemies/enemy_short_range.tres`,
  §25.1). At 82 the enemy was slower than cargo Normal (90), so a rear enemy that
  fell behind could never catch back up — a free escape with no decision behind
  it. At 100 it out-paces Normal but still cannot catch Fast (130), so Fast stays
  a costly but real escape valve.
- **Cargo repair: Stop-only, not Stop-or-Slow** (`Defender.cargo_repair_available()`,
  §15.8). Repair while still rolling at Slow made healing free during ordinary
  driving. It is now a deliberate full halt, matching the docstring and the
  `behaviour_checks._check_repair()` assertions, which only ever exercised Stop
  and Fast.

Both gates stayed green with the changes in place — `behaviour_checks` was
unaffected (it never asserted Slow-speed repair), and `smoke_run`'s passive,
one-order, cast-at-whatever-is-nearest play survived with more of the intended
tension: lowest cargo health fell from 68/100 to 44/100 on the same held-Normal
run, with the same 112.7 s duration and 27 of 27 enemies still killed. No
fallback tuning (e.g. nudging speed down to 95) was needed.

**Spawn ahead 200–640 → 560–960** (`data/enemy_schedule.tres`). Trigger groups
used to appear almost on top of the cargo: at Normal against a short-range enemy
walking in, a 200 px gap closed in about a second, and the floor sat inside the
long-range maximum of 360 (§25.2). The new band clears that range and leaves
roughly three to five seconds of closing time so a group can be seen and answered.

---

## Roadmap

Milestones 1 and 2 are closed; their reports are below. The control-profile
experiment and its test apparatus are gone, and with them the milestones that only
existed to build and evaluate profiles P2 to P4 — the two milestones below are what
is left of build order once that scope is removed.

| Milestone | Scope |
|---|---|
| **M3 — combat completion** | Barriers with the Repair state, the long-range enemy, Mend and Ward |
| **M4 — feedback and threat** | §30.6 world feedback, the threat reinforcements, the second barrier, final balance values |

---

## Next: milestone 3

Everything here has its data resource, its ranking in the target priority list,
or its disabled-state flag already in place, so all three are behaviour only.

1. **Barriers with the Repair state.** **Done.** `MapRouteData.enable_barriers` is
   now true, `AutoPathMotor` clamps to the closed barrier's `route_offset` so the
   cargo stops short instead of driving through, and each barrier shows a
   `BarrierWorkBar` above it as the Repair state's work points fall. `smoke_run`
   overrides Attack/Defend with Repair while a closed barrier sits ahead and
   asserts every barrier opens by the run's end; `behaviour_checks._check_barriers()`
   drives the stop-short, the open, and the navigation rebake of §34 directly.
2. **The long-range enemy** (§25.2). **Done**, and wired into `main.tscn` before
   this session — `EnemySpawner.deferred_long_range()` reads 0 on every run now.
   `behaviour_checks._check_long_range()` drives one to its Fire state and checks
   the bolt lands. Nothing before this session ever actually took a long-range
   hit end to end, though: see the `smoke_run` finding below.
3. **Mend and Ward** (§14.6, §14.7). **Done.** `Wizard` now carries the `HEAL` and
   `AREA` branches: Mend heals the cargo unit or the defender under the pointer and
   revives a downed one, and Ward (`world/wizard/ward.gd`) drops a single protection
   area that slows the enemies inside it and soaks most of their bolts, leaving
   short-range melee untouched. Both `.tres` now carry `implemented = true`, so the
   number keys select them, and `behaviour_checks` casts each through the wizard and
   asserts the heal, the revive, the projectile-damage cut and the enemy slow.

Then re-measure the §7 run duration, which the barriers should move toward the
three minute floor for the first time.

### Play it before starting

Control feel is the entire point of the proof of concept and no assertion
substitutes for it. Two questions carried from milestone 1, two from milestone 2:

1. Are Slow, Normal and Fast distinct enough to be a real decision?
2. Does the mud slowdown read as a threat, or as an annoyance?
3. Can you cast Arc Bolt without losing track of the cargo? (§42's central question)
4. Is Defend against Attack a real choice, or does one of them dominate?

---

## Still absent

Not bugs. Do not "fix" these without checking the milestone that owns them.

| Missing | Owner |
|---|---|
| §30.6 world feedback — target lines, leash circles, return arrows | M4 |
| Final combat balance — a passive `smoke_run` now fails to the long-range enemy and the barriers together | M3/M4 |

`SpellData.implemented` still decides whether a spell shows live or disabled; Arc
Bolt, Mend and Ward now all carry it true. `EnemySpawner` uses the same
disable-visibly pattern for anything it cannot yet create — it logs what it deferred
instead of quietly spawning a smaller group. Flip a flag only when the thing works
end to end.

---

## Where the specification needed a decision

Milestone 2 hit five cases the text does not decide, or decides in a way that does
not survive four defenders. Each is a candidate to change in the **specification**
rather than in the code. Full reasoning in
[`milestones/milestone-02-first-combat-loop.md`](milestones/milestone-02-first-combat-loop.md).

| Question | Choice |
|---|---|
| What does Follow do when an enemy arrives? | Change to Defend, per §15.5's "when no other state applies" |
| Which enemy does each defender intercept? | The nearest to the cargo that no other defender is on |
| Defenders cannot keep up with the cargo | A catch-up speed, used only when walking to a slot |
| Defender attack range, which §15 never gives | 34px, in `DefenderTuning` |
| What counts as "blocks its route" in §25.1 | Within 55px of the line to the cargo, or already in reach |

The third is the one to decide first, because the two tables genuinely contradict.

---

## Open findings

**⚠️ Resolved: Fast speed is 130 px/s.** §13.1 and `data/cargo_data.tres` both say
130, and measurement agrees with them, not with the "65 px/s" that the milestone 1
report and the old smoke test header both quoted. A Fast-held run on the untouched
repository covered 8,914 px in 79.9 s with 16.7 s of that in mud; 130 px/s predicts
9,506 px for those times and 65 px/s predicts 4,753 px. The 65 figure appears
nowhere the game reads and produced a **failing smoke test on the initial commit**
— 79.9 s against a 120 to 360 second band derived from the wrong number. The band
is now based on a measured Normal-speed run. The milestone 1 report is left as
written, because it is a historical record.

**🔴 `smoke_run` fails now that the long-range enemy is live, independent of
barriers.** The scripted run dies to `cargo_destroyed` around 71 to 85 s, well
short of the portal. Reproduced with `MapRouteData.enable_barriers` forced back to
`false`, which still fails at 80.5 s with the same reason — so this is not a
barrier or a `smoke_run` order-priority problem, it is the long-range enemy's real
damage landing on a passive play style for the first time (`EnemySpawner`
previously deferred every long-range enemy, so no run before this session ever
actually took a long-range hit). One real improvement is already in
`smoke_run._manage_orders()`: it no longer abandons a fight for Repair while
enemies are still alive, since the barrier's stop is enforced by the cargo motor
regardless of the squad's order and fighting on costs nothing. That was not enough
by itself. A passive player surviving all six groups plus the long-range enemy and
the barriers is a milestone 3 balance question — not something to force green by
guessing at numbers. Needs a play session before landing a fix.

**The three minute floor of §7 is not reachable yet.** The last completed run
(112.7 s) predates the long-range enemy; re-measure once the finding above is
resolved. Slow is 180 s of driving by itself; the two barriers at 100 work points
each add roughly 35 s on top of whatever the balanced combat duration turns out
to be.

**A passive player survives — up to milestone 2's combat.** The smoke run plays
badly on purpose — one order, one speed, cast at whatever is nearest — and used to
finish, with the cargo at 44 health after the Phase A speed and repair changes
above (was 68 before them). Long-range and barriers were both still deferred at
that point; see the finding above for where passive play now fails.

**Mud is visually heavy.** The tiled fill reads clearly, which is what §12.2 asks
for, but it dominates the paper-and-ink page more than the rest of the palette does.
One `modulate` value in `TerrainZone.setup_mud`.

---

## Known residual

The navigation bake reports **3 edge merge warnings**, unchanged since milestone 1.
Real agents now navigate that mesh and they navigate it correctly: 27 of 27 enemies
crossed it to reach the cargo, and the blocked-unit fallback of §34 fired **zero**
times in a full run. Cosmetic on current evidence; revisit only if a unit is
observed sticking.

---

## Closed milestone reports

| Milestone | Report |
|---|---|
| M1 — World foundation | [`milestones/milestone-01-world-foundation.md`](milestones/milestone-01-world-foundation.md) |
| M2 — The first combat loop | [`milestones/milestone-02-first-combat-loop.md`](milestones/milestone-02-first-combat-loop.md) |

---

## MVP acceptance criteria

§40. The MVP is complete when every line is true.

- [x] The cargo unit can reach the final portal — under attack, verified each run
- [x] Both enemy types can attack the cargo unit — the long-range enemy's damage is real, per the `smoke_run` finding below
- [x] Defenders can attack, defend, and repair — all three work; both barriers give repair a target
- [x] The wizard can cast all three spells — Arc Bolt, Mend and Ward, each cast through the wizard in `behaviour_checks`
- [x] The final portal can complete a run
- [x] Cargo destruction can fail a run
- [x] No unit stays blocked for more than two seconds — 0 fallbacks in a full run, and every enemy reached the cargo
- [x] The game keeps at least 60 frames per second on the test computer
- [ ] All important orders have visual and sound feedback — orders, casts and damage have both; §30.6 world feedback is missing
