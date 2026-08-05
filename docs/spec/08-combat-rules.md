# Combat rules — §29

Applies to defenders, enemies and wizard spells alike. `scripts/combat_target.gd`
holds the shared target contract.

## 29. Combat rules

All attacks use real-time simulation.

The game does not use turns.

The game does not use friendly fire.

A projectile cannot pass through a valid target.

A melee attack requires a valid target inside attack range.

A unit cannot attack during its attack cooldown.

Damage uses this formula:

```
final damage = maximum(1, attack damage - target defense)
```

The cargo unit has zero defense in the MVP.

A dead enemy changes to a light gray paper mark for two seconds.

The game then removes the enemy.

## Physics layers

Named in `project.godot` and mirrored in `scripts/layers.gd`. Use the constants,
never a raw bit index.

| # | Layer |
|---:|---|
| 1 | `cargo` |
| 2 | `defender` |
| 3 | `enemy` |
| 4 | `road_wall` |
| 5 | `map_wall` |
| 6 | `barrier` |
| 7 | `projectile_friendly` |
| 8 | `projectile_enemy` |
| 9 | `terrain` |
| 10 | `trigger` |

Collision facts that follow from §13.3 and §15.3:

- The cargo collides with map walls and barriers, **not** with defenders.
- Defenders pass through each other but **not** through barriers or map walls.
- No friendly fire, so `projectile_friendly` must not test against `defender` or `cargo`.
