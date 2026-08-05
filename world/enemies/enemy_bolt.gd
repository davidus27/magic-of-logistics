class_name EnemyBolt
extends Area2D
## The long-range enemy projectile. Specification section 25.2.
##
## The bolt travels from the enemy toward the point it fired at and hits the
## first cargo or defender collision shape in its path. Like [ArcBolt] it is an
## [Area2D] and not a body, so it stops on its first overlap without pushing the
## thing it hits. One scene draws the flight and the impact mark, so a hit that
## reads wrongly has one place to look.

const IMPACT := preload("res://assets/world/enemy_bolt_impact.svg")
## How long the impact mark stays. Short enough to read as a strike, not a mark.
const IMPACT_SECONDS := 0.12
## Distance past the target the bolt may travel before it expires. Without it a
## bolt fired at a target that then moved would stop in mid air.
const OVERSHOOT := 40.0

var damage: int = 9
var speed: float = 350.0

var _direction := Vector2.RIGHT
var _travelled: float = 0.0
var _range: float = 0.0
var _spent: bool = false
var _impact_left: float = 0.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _ink: InkSprite = $Ink


func _ready() -> void:
	collision_layer = Layers.PROJECTILE_ENEMY
	# The bolt hits the cargo unit or a defender, whichever it reaches first.
	# The game does not use friendly fire, so it never hits another enemy.
	# Section 25.2 and 29.
	collision_mask = Layers.CARGO | Layers.DEFENDER
	monitorable = false
	body_entered.connect(_on_body_entered)


## Send the bolt from the enemy toward a world point. Section 25.2.
func launch(from: Vector2, to: Vector2, bolt_speed: float, bolt_damage: float, max_range: float) -> void:
	speed = bolt_speed
	damage = int(bolt_damage)
	global_position = from
	var offset := to - from
	_direction = offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT
	_range = minf(offset.length() + OVERSHOOT, max_range)
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	if _spent:
		_impact_left -= delta
		if _impact_left <= 0.0:
			queue_free()
		return

	var step := speed * delta
	global_position += _direction * step
	_travelled += step
	if _travelled >= _range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if not CombatTarget.is_valid(body):
		return
	# A Ward covering the point of impact soaks most of a bolt. Melee never comes
	# through here, so Ward leaves short-range attacks untouched. Section 14.7.
	CombatTarget.damage(body, Ward.reduced_damage(global_position, damage))
	_show_impact()


func _show_impact() -> void:
	_spent = true
	_impact_left = IMPACT_SECONDS
	_collision.set_deferred("disabled", true)
	var frames: Array[Texture2D] = [IMPACT]
	_ink.extra_scale = 0.14
	_ink.set_frames(frames)
	# The impact drawing is not aimed, so an inherited rotation would tilt it.
	rotation = 0.0
