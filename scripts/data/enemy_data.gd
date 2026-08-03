class_name EnemyData
extends Resource
## Enemy statistics. Specification sections 25.1 and 25.2.

enum Kind {
	## Moves to the cargo and attacks in melee range. Section 25.1.
	SHORT_RANGE,
	## Stops at its preferred range and fires projectiles. Section 25.2.
	LONG_RANGE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.SHORT_RANGE

@export var max_health: int = 32
## Pixels per second.
@export var speed: float = 82.0
@export var attack_damage: int = 8
## Seconds between attacks.
@export var attack_interval: float = 1.0
@export var defense: int = 0
## Body radius, used for the collision shape and the authored art size.
@export var body_radius: float = 11.0

@export_group("Short range")
## Melee reach in pixels. Section 25.1.
@export var attack_range: float = 28.0
## The short-range enemy changes target on this period. Section 25.1.
@export var retarget_interval: float = 0.5
## How near the line from this enemy to the cargo a defender must be to count as
## blocking its route. Section 25.1.
##
## The specification says the enemy attacks a defender that blocks its route
## without giving a width for that route. This is a little wider than a defender
## body, so a defender standing in the way blocks and one walking past does not.
@export var block_corridor: float = 55.0

@export_group("Long range")
## The enemy moves to this distance from the cargo. Section 25.2.
@export var preferred_range: float = 280.0
## The enemy cannot fire beyond this distance. Section 25.2.
@export var maximum_range: float = 360.0
## Pixels per second.
@export var projectile_speed: float = 350.0
## The enemy prefers a defender inside this radius of itself. Section 25.2.
@export var defender_aggro_radius: float = 100.0
