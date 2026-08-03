class_name SpellData
extends Resource
## Wizard spell values. Specification sections 14.5, 14.6 and 14.7.

enum Kind {
	## Arc Bolt: a projectile toward the pointer. Section 14.5.
	PROJECTILE,
	## Mend: restores health to one clicked target. Section 14.6.
	HEAL,
	## Ward: a temporary protection area. Section 14.7.
	AREA,
}

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.PROJECTILE
## Number key that selects this spell. Section 14.3.
@export var hotkey_index: int = 1

@export var mana_cost: int = 5
@export var cooldown: float = 0.5
## Maximum distance from the wizard to a valid target. Sections 14.4 to 14.7.
@export var cast_range: float = 500.0
## The player can hold the left mouse button for repeated casts. Section 14.5.
@export var allow_hold_repeat: bool = false

## False until the milestone that adds this spell lands. The wizard shows an
## unimplemented spell as unavailable instead of accepting a cast that does
## nothing, in the same way the selection screen handles a control profile.
@export var implemented: bool = false

@export_group("Projectile")
@export var damage: int = 18
@export var projectile_speed: float = 700.0

@export_group("Heal")
@export var heal_defender: int = 20
@export var heal_cargo: int = 15
## Health given to a revived defender. Section 14.6.
@export var revive_health: int = 20
## The nearest valid target inside this radius of the pointer. Section 14.6.
@export var target_pick_radius: float = 35.0

@export_group("Area")
@export var effect_radius: float = 110.0
@export var duration: float = 4.0
## Fraction removed from enemy projectile damage. Section 14.7.
@export var projectile_damage_reduction: float = 0.80
## Fraction removed from enemy movement speed. Section 14.7.
@export var enemy_slow_factor: float = 0.20
