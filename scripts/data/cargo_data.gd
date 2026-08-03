class_name CargoData
extends Resource
## Cargo unit balance values. Specification section 13.1.

## Discrete speed levels of cargo control method A. Specification section 19.
enum SpeedLevel { STOP, SLOW, NORMAL, FAST }

@export var max_health: int = 100
@export var initial_health: int = 100

@export_group("Speeds", "speed_")
## Pixels per second at each speed level.
@export var speed_slow: float = 50.0
@export var speed_normal: float = 90.0
@export var speed_fast: float = 130.0
## Only cargo control methods B and C can move backward. Section 20.
@export var speed_reverse: float = 15.0

@export_group("Handling")
## Pixels per second squared.
@export var acceleration: float = 60.0
## Pixels per second squared.
@export var brake_rate: float = 100.0
## Degrees per second.
@export var turn_rate: float = 80.0

@export_group("Body")
## Collision and visual footprint. Also the size the cargo art is authored at.
@export var body_size: Vector2 = Vector2(120.0, 64.0)
## Seconds the cargo flashes after damage. Section 13.2.
@export var damage_flash_seconds: float = 0.10
## A crack mark appears below each of these health values. Section 13.2.
@export var first_crack_health: int = 60
@export var second_crack_health: int = 30


## Pixels per second for a speed level.
func speed_for_level(level: SpeedLevel) -> float:
	match level:
		SpeedLevel.SLOW:
			return speed_slow
		SpeedLevel.NORMAL:
			return speed_normal
		SpeedLevel.FAST:
			return speed_fast
		_:
			return 0.0


## Player-facing name of a speed level, for the user interface.
func name_for_level(level: SpeedLevel) -> String:
	match level:
		SpeedLevel.SLOW:
			return "Slow"
		SpeedLevel.NORMAL:
			return "Normal"
		SpeedLevel.FAST:
			return "Fast"
		_:
			return "Stop"
