class_name RunSeedData
extends Resource
## The fixed run seed. Specification section 35.
##
## The seed controls enemy spawn positions only, and stays fixed so a run's
## behaviour is reproducible.

@export var id: int = 1
@export var display_name: String = "Run seed"
@export var seed_value: int = 1
