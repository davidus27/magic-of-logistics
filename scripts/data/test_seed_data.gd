class_name TestSeedData
extends Resource
## A fixed test seed. Specification section 35.
##
## The seed controls enemy spawn positions only. It does not change enemy
## statistics, and every control profile must be tested with the same seeds.

@export var id: int = 1
@export var display_name: String = "Seed 1"
@export var seed_value: int = 1
