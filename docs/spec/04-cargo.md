# Cargo unit and cargo control — §13, §19–21

Implemented by `world/cargo/cargo_unit.gd`, with movement in
`world/cargo/cargo_motor.gd` and `world/cargo/auto_path_motor.gd`.
Balance values in `data/cargo_data.tres`.

**Cargo movement belongs to the motor, not the cargo.** `AutoPathMotor` rides the
route centre line and writes the transform directly; the manual motors of milestone
5 will steer and use `move_and_slide()`. Keeping that split inside the motor is why
`CargoUnit` never branches on the control profile — do not add such a branch.

## 13. Cargo unit

### 13.1 Cargo properties

The cargo unit has these initial properties:

| Property | Value |
|---|---:|
| Maximum health | 100 |
| Initial health | 100 |
| Slow speed | 50 pixels per second |
| Normal speed | 90 pixels per second |
| Fast speed | 130 pixels per second |
| Reverse speed | 15 pixels per second |
| Acceleration | 60 pixels per second squared |
| Brake rate | 100 pixels per second squared |
| Turn rate | 80 degrees per second |

> ⚠️ **Open discrepancy — Fast speed.** This table and `data/cargo_data.tres` both
> say **130 px/s**. But `README.md`, the milestone 1 report and the header comment of
> `tools/smoke_run.gd` all cite **"the 65 px/s Fast speed of section 13.1"**, and the
> measured fast run backs the lower number: 8852 px in 154.1 s is about 57 px/s
> average, which is consistent with a 65 px/s base and 34 s of ×0.60 mud, not with
> 130. `AutoPathMotor` reads `speed_for_level() * terrain_factor` with no visible
> halving. **Resolve this in milestone 2** — either the authored value or the three
> comments are wrong, and the §7 run-duration maths depends on which.

### 13.2 Cargo health

Enemy attacks reduce the cargo health.

The cargo health cannot increase above 100.

The cargo unit flashes for 0.10 seconds after damage.

A black crack mark appears below 60 health.

A second crack mark appears below 30 health.

### 13.3 Cargo collision

The cargo unit collides with map walls and barriers.

The cargo unit does not collide with defenders.

The cargo unit pushes enemies away from its collision shape.

The cargo unit does not cause collision damage.

### 13.4 Rider behavior

The rider is a visual prop.

The rider has no health, state, or collision shape.

The rider faces the cargo movement direction.

## 19. Cargo control method A: Automatic path movement

Used by profiles P1 and P2. **Implemented** — `AutoPathMotor`.

The cargo unit follows the center of the road.

The player does not steer the cargo unit.

The player presses `W` to increase the speed level.

The player presses `S` to decrease the speed level.

The speed levels are Stop, Slow, Normal, and Fast.

The player presses `Space` to select Stop immediately.

The cargo unit cannot move backward.

The cargo unit stops when it touches a barrier.

The cargo unit continues after the barrier opens.

## 20. Cargo control method B: Road-limited manual movement

Used by profile P3. **Not implemented** — milestone 5.

The player steers the cargo unit with wagon controls.

The player holds `W` to accelerate forward.

The player holds `S` to brake.

The player continues to hold `S` to move backward.

The player holds `A` or `D` to turn.

The player holds `Space` for a full brake.

Static road walls keep the cargo unit inside the road area.

The cargo unit slides along a road wall after contact.

Terrain changes the maximum speed and turn rate.

The cargo unit stops when it touches a barrier.

## 21. Cargo control method C: Free manual movement

Used by profile P4. **Not implemented** — milestone 5.

This method uses the same keys as road-limited movement.

The map does not use road walls in this method.

The cargo unit can leave the road.

Off-road terrain reduces speed and turn rate.

Map border walls prevent movement outside the test map.

This method tests route choice and direct driving load.
