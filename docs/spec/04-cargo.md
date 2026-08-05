# Cargo unit and cargo control — §13, §19

Implemented by `world/cargo/cargo_unit.gd`, with movement in
`world/cargo/cargo_motor.gd` and `world/cargo/auto_path_motor.gd`.
Balance values in `data/cargo_data.tres`.

**Cargo movement belongs to the motor, not the cargo.** `AutoPathMotor` rides the
route centre line and writes the transform directly. Keeping movement inside the
motor is why `CargoUnit` never branches on which motor is active — it asks the
motor's `can_leave_road()` instead. Do not add such a branch.

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

**Implemented** — `AutoPathMotor`.

The cargo unit follows the center of the road.

The player does not steer the cargo unit.

The player presses `W` to increase the speed level.

The player presses `S` to decrease the speed level.

The speed levels are Stop, Slow, Normal, and Fast.

The player presses `Space` to select Stop immediately.

The cargo unit cannot move backward.

The cargo unit stops when it touches a barrier.

The cargo unit continues after the barrier opens.
