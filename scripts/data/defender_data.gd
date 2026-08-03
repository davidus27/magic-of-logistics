class_name DefenderData
extends Resource
## Per-defender statistics. Specification section 15.2.
##
## Values shared by every defender, such as the defend and attack radii, live in
## [DefenderTuning] so that they exist once instead of four times.

@export var id: String = ""
@export var display_name: String = ""
## Single letter shown on the defender portrait.
@export var portrait_mark: String = ""

@export var max_health: int = 100
@export var attack_damage: int = 14
## Reduces each received damage value. Final damage is never below 1. Section 15.2.
@export var defense: int = 3
## Cargo health or barrier work each second. Section 15.2.
@export var repair_rate: float = 2.0
## Pixels per second.
@export var speed: float = 85.0
