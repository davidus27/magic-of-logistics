# Status

**Single source of truth for what is built and what comes next.** Update this file
in the same commit as the work it describes.

| | |
|---|---|
| Engine | Godot 4.7.1, GDScript, statically typed |
| Last completed milestone | **Milestone 2 — the first combat loop**, verified 2026-08-03 |
| Current work | none in progress; milestone 3 is not yet cut |
| Commit gates | 🟢 `smoke_run` exit 0 · 🟢 `behaviour_checks` exit 0 |
| Last verified run | 2026-08-03: portal reached in 112.7 s at Normal, cargo 68/100, 27 of 27 enemies killed |

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

1. **Barriers with the Repair state.** `Barrier` already carries 100 work points,
   removes its collision shape at zero and rebakes navigation; `Squad`
   already allocates a work point per defender along the road width; the Repair
   state already gives barrier work priority over cargo repair. What is missing is
   flipping `MapRouteData.enable_barriers` and confirming a barrier can actually be
   opened, that the cargo stops short of a closed one, and that the navigation
   rebake of §34 leaves nothing stranded.
2. **The long-range enemy** (§25.2). Needs a scene and a projectile.
   `EnemySpawner` already counts one in four of the six groups and reports it as
   deferred, `Defender.priority_target` already ranks it above short-range as
   §15.7 requires, and `EnemyData` already holds every value.
3. **Mend and Ward** (§14.6, §14.7). `Wizard` dispatches on `SpellData.kind` and
   pushes an error on a kind it cannot cast; add the `HEAL` and `AREA` branches
   and set `implemented = true`. `Defender.revive()` is written and asserted by
   `behaviour_checks` already, so Mend has a target to call.

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
| Long-range enemy — deferred explicitly by the spawner, and logged | M3 |
| Barriers — generated but disabled by `MapRouteData.enable_barriers` | M3 |
| Mend and Ward — `SpellData.implemented = false`, cannot be selected | M3 |
| §30.6 world feedback — target lines, leash circles, return arrows | M4 |
| Threat reinforcement spawns | M4 |
| Second barrier and final balance values | M4 |

Mend and Ward render as **disabled** rather than silently substituting Arc Bolt,
driven by `SpellData.implemented`. `EnemySpawner` uses the same disable-visibly
pattern for the long-range enemy it cannot yet create — it logs what it deferred
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

**The three minute floor of §7 is not reachable yet.** A full Normal-speed run
with all six enemy groups is 112.7 s. Slow is 180 s of driving by itself; the two
barriers at 100 work points each add roughly 35 s. Re-measure at M3 and then decide
whether the route should be longer or the floor lower.

**A passive player survives.** The smoke run plays badly on purpose — one order, one
speed, cast at whatever is nearest — and still finishes with the cargo at 68 health.
Right for a first-time tester, but it leaves little room for the long-range enemy,
the reinforcements of §27 and the barriers. Revisit after M3 rather than tuning now.

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
- [ ] Both enemy types can attack the cargo unit — short-range only, M3
- [ ] Defenders can attack, defend, and repair — all three work; repair has no barrier to work on until M3
- [ ] The wizard can cast all three spells — Arc Bolt only, M3
- [x] The final portal can complete a run
- [x] Cargo destruction can fail a run
- [x] No unit stays blocked for more than two seconds — 0 fallbacks in a full run, and every enemy reached the cargo
- [x] The game keeps at least 60 frames per second on the test computer
- [ ] All important orders have visual and sound feedback — orders, casts and damage have both; §30.6 world feedback is missing
