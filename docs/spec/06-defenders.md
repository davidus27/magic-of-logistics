# Defenders — §15–17

**Built, uncommitted.** `world/defenders/defender.gd`, `defender_states.gd` and
`squad.gd` put **all four** defenders on the field — step 7 arrived early with step
4. Repair still waits for the barriers in milestone 4, so a `C` order must fall
through to Defend behaviour per §15.8's last line rather than no-op.

Not yet verified: selection (§16) and role orders (§17) have no automated coverage,
and the cargo currently dies 43 % along the route with all four defenders active —
which is either a balance problem or a defender that is not engaging. See
[`../status.md`](../status.md).

Balance values already exist in `data/defenders/{guard,striker,engineer,warden}.tres`
and `data/defender_tuning.tres`, so this is behaviour only. The state machine is in
`scripts/fsm/state_machine.gd` and `scripts/fsm/unit_state.gd` — see
[`10-architecture.md`](10-architecture.md) §33 for the contract it must honour.

## 15. Defenders

### 15.1 Defender count

The player starts with four defenders.

Each defender has different values.

### 15.2 Defender values

| Defender | Health | Attack damage | Defense | Repair rate | Speed |
|---|---:|---:|---:|---:|---:|
| Guard | 100 | 14 | 3 | 2 | 85 |
| Striker | 80 | 20 | 1 | 1 | 105 |
| Engineer | 90 | 9 | 2 | 6 | 80 |
| Warden | 120 | 11 | 5 | 3 | 70 |

Attack damage applies once each second.

Repair rate gives cargo health or barrier work each second.

Defense reduces each received damage value.

Final damage is not less than one.

### 15.3 Defender movement

Defenders use autonomous path movement.

Defenders can move through other defenders.

Defenders cannot move through barriers or map walls.

A small separation force prevents exact visual overlap.

A defender recalculates its path every 0.25 seconds.

### 15.4 Defender states

A defender can use these states:

- Follow
- Defend
- Attack
- Repair
- Return
- Downed
- Dead

### Radius reference

| State | Engagement / defense radius | Leash radius |
|---|---:|---:|
| Defend | 200 px | 260 px |
| Attack | 420 px | 480 px |

Assigned slot distance from the cargo centre: 90–130 px.

### 15.5 Follow state

The Follow state moves the defender to its assigned cargo slot.

The defender uses this state after the start of the run.

The defender also uses this state when no other state applies.

### 15.6 Defend state

The Defend state keeps the defender near the cargo unit.

The defender has an assigned position around the cargo unit.

The assigned position is between 90 pixels and 130 pixels from the cargo center.

The defender intercepts the nearest enemy inside a 200-pixel defense radius.

The defender selects the enemy that is nearest to the cargo unit.

The defender stops pursuit outside a 260-pixel leash radius.

The defender then uses the Return state.

### 15.7 Attack state

The Attack state permits longer pursuit.

The Attack state uses a 420-pixel engagement radius.

The Attack state uses a 480-pixel leash radius.

The defender uses this target priority:

1. An enemy that attacks the cargo unit
2. The nearest long-range enemy
3. The nearest short-range enemy

The defender checks for a new target every 0.25 seconds.

The defender keeps its current target until a higher priority target appears.

The defender returns when the target leaves the leash radius.

### 15.8 Repair state

The Repair state gives priority to barrier work.

The defender selects a barrier within 180 pixels in front of the cargo unit.

The defender moves to the nearest free work point.

The defender applies its repair rate to the barrier work value.

The defender repairs the cargo unit when no barrier needs work.

Cargo repair works only at Stop speed.

The defender moves to a rear cargo work point.

The defender applies its repair rate to cargo health.

The defender waits at the rear slot during Slow, Normal or Fast speed.

The defender uses Defend behavior when no repair work is available.

### 15.9 Return state

The Return state moves the defender directly toward its assigned cargo slot.

The defender does not select a new target during this state.

The defender changes to its ordered state inside the defense radius.

### 15.10 Downed state

A defender enters the Downed state at zero health.

The defender cannot move, attack, or repair.

A 15-second downed timer starts.

The wizard can use Mend to revive the defender.

The defender enters the Dead state when the timer reaches zero.

### 15.11 Dead state

A dead defender stays as a light gray paper mark.

A dead defender has no collision shape.

A dead defender cannot return during the run.

## 16. Defender selection

The player can select one or more defenders.

The player presses `F1` through `F4` to select one defender.

The player presses `Q` to select all living defenders.

The player holds `Shift` and presses a function key to change a group selection.

The player can also click a defender portrait.

A click on a portrait does not cast a wizard spell.

**The player cannot select a defender by a world click.** This rule prevents a
conflict with wizard control.

## 17. Defender control method A: Role orders

**Milestone 2.**

This method tests simple state control.

The player selects defenders before an order.

The player presses `Z` for Attack.

The player presses `X` for Defend.

The player presses `C` for Repair.

The selected defenders change state immediately.

The defenders use automatic target selection.

The player cannot set a direct enemy target in this method.

The user interface shows one order button for each role.
