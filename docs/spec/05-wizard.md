# Wizard and spells — §14

**Built.** `world/wizard/wizard.gd` implements mana and all three spells: Arc Bolt
(§14.5) with `arc_bolt.gd`, Heal (§14.6), and Shield (§14.7) with `shield.gd`.
`behaviour_checks` casts Heal and Shield through the wizard and asserts the heal, the
revive, the projectile-damage cut and the enemy slow, so the behaviour is verified —
see [`../status.md`](../status.md).

Balance values live in `data/spells/spell_arc_bolt.tres`, `spell_heal.tres` and
`spell_shield.tres`; all three carry `implemented = true`.

## 14. Wizard

### 14.1 Wizard position

The wizard stays at the center of the cargo unit.

The wizard does not move independently.

The wizard has no separate health value in the MVP.

Cargo health represents cargo and wizard survival.

### 14.2 Wizard resource

The wizard has 100 maximum mana.

The wizard starts with 100 mana.

Mana increases by 8 points each second.

Mana cannot increase above 100.

### 14.3 Spell selection

The player presses `1`, `2`, or `3` to select a spell.

The selected spell stays active until the player selects another spell.

The cursor shows the selected spell symbol.

The game shows the spell range around the cargo unit.

### 14.4 Spell cast control

The player uses the left mouse button to cast the selected spell.

The game does not cast a spell when the pointer is above the user interface.

The game rejects a target outside the spell range.

A short line shows the maximum permitted target point.

## Spell summary

| | Arc Bolt | Heal | Shield |
|---|---:|---:|---:|
| Key | `1` | `2` | `3` |
| Mana cost | 5 | 25 | 35 |
| Cooldown | 0.50 s | 5 s | 8 s |
| Range | 500 px | 350 px | 400 px |

### 14.5 Spell 1: Arc Bolt

Arc Bolt is the basic attack spell.

Arc Bolt costs 5 mana.

Arc Bolt has a 0.50-second cooldown.

Arc Bolt has a 500-pixel range.

Arc Bolt causes 18 damage.

The spell creates one projectile from the wizard to the pointer position.

The projectile moves at 700 pixels per second.

The projectile hits the first enemy in its path.

The player can hold the left mouse button for repeated casts.

### 14.6 Spell 2: Heal

Heal restores health to one target.

Heal costs 25 mana.

Heal has a 5-second cooldown.

Heal has a 350-pixel range.

Heal restores 20 defender health.

Heal restores 15 cargo health.

Heal can revive a downed defender.

A revived defender receives 20 health.

The player must click the cargo unit or a defender.

The game selects the nearest valid target within 35 pixels of the pointer.

### 14.7 Spell 3: Shield

Shield creates a temporary protection area.

Shield costs 35 mana.

Shield has an 8-second cooldown.

Shield has a 400-pixel cast range.

Shield has a 110-pixel effect radius.

Shield stays active for four seconds.

Shield reduces enemy projectile damage by 80 percent.

Shield reduces enemy movement speed by 20 percent.

Shield does not reduce short-range attack damage.

Only one Shield can be active at one time.
