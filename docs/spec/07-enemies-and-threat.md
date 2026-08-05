# Enemies and threat — §25–27

**Short-range enemy built, uncommitted.** `world/enemies/enemy.gd`,
`enemy_states.gd` and `enemy_spawner.gd` spawn groups on schedule from
`data/enemy_schedule.tres` — the last verified run reached group 3. The spawner
defers long-range enemies explicitly rather than faking them:
`group 2 at offset 2100: 2 spawned, 2 long-range deferred`.

The long-range enemy lands in milestone 4; the threat system is §41 step 15.

Balance values already exist in `data/enemies/enemy_short_range.tres` and
`enemy_long_range.tres`. The map already generates all six trigger areas.

## 25. Enemies

### 25.1 Short-range enemy

The short-range enemy has these values:

| Property | Value |
|---|---:|
| Health | 32 |
| Speed | 100 pixels per second |
| Attack damage | 8 |
| Attack interval | 1.00 second |
| Attack range | 28 pixels |
| Defense | 0 |

The short-range enemy moves toward the cargo unit.

The enemy attacks a defender that blocks its route.

The enemy attacks the cargo unit when no defender blocks its route.

The enemy changes target every 0.50 seconds.

### 25.2 Long-range enemy

The long-range enemy has these values:

| Property | Value |
|---|---:|
| Health | 22 |
| Speed | 48 pixels per second |
| Projectile damage | 9 |
| Attack interval | 2.00 seconds |
| Preferred range | 280 pixels |
| Maximum range | 360 pixels |
| Defense | 0 |

The long-range enemy moves to its preferred range from the cargo unit.

The enemy stops and fires at the cargo unit.

The enemy targets a defender within 100 pixels of its position.

The enemy projectile moves at 350 pixels per second.

The projectile hits the first cargo or defender collision shape.

## 26. Enemy attack schedule

The battlefield has six fixed trigger areas.

The cargo unit activates a trigger area when it enters that area.

Each trigger area creates one fixed enemy group.

The groups use the selected test seed for spawn positions.

| Group | Short-range | Long-range |
|---:|---:|---:|
| 1 | 4 | 0 |
| 2 | 2 | 2 |
| 3 | 6 | 0 |
| 4 | 4 | 3 |
| 5 | 3 | 5 |
| 6 | 8 | 4 |

The first enemy trigger starts after 15 seconds of normal cargo movement; the first
15 seconds form a control practice area (§11).

## 27. Threat system

The threat value starts at zero.

The threat value increases by one each second.

The threat value stops during the pause state.

The game creates a reinforcement group each time the value passes 45 points.

A reinforcement group contains two short-range enemies and one long-range enemy.

The game creates the group behind or beside the cargo unit.

The spawn point must stay outside the visible screen.

The threat system makes slow movement more dangerous.
