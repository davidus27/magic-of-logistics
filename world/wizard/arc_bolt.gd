class_name ArcBolt
extends Area2D
## The Arc Bolt projectile. Specification section 14.5.
##
## The bolt travels from the wizard to the pointer position and hits the first
## enemy in its path. It is an [Area2D] and not a body: section 29 says a
## projectile cannot pass through a valid target, and an area that stops on its
## first overlap does exactly that without pushing anything.
##
## On impact the node stays for a moment with the impact drawing instead of
## creating a second scene. One scene means one place to look when a hit reads
## wrongly.

const IMPACT := preload("res://assets/spells/arc_bolt_impact.svg")
## How long the impact mark stays. Short enough to read as a strike, not a mark.
const IMPACT_SECONDS := 0.12
## Distance past the pointer the bolt may travel before it expires. Without it a
## bolt aimed at empty ground would fly to the edge of the cast range.
const OVERSHOOT := 24.0

var damage: int = 18
var speed: float = 700.0

var _direction := Vector2.RIGHT
var _travelled: float = 0.0
var _range: float = 0.0
var _spent: bool = false
var _impact_left: float = 0.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _ink: InkSprite = $Ink


func _ready() -> void:
	collision_layer = Layers.PROJECTILE_FRIENDLY
	# The game does not use friendly fire. Section 29.
	collision_mask = Layers.ENEMY
	monitorable = false
	body_entered.connect(_on_body_entered)


## Send the bolt from the wizard toward a world point. Section 14.5.
func launch(spell: SpellData, from: Vector2, to: Vector2) -> void:
	damage = spell.damage
	speed = spell.projectile_speed
	global_position = from
	var offset := to - from
	_direction = offset.normalized() if offset.length_squared() > 0.01 else Vector2.RIGHT
	_range = minf(offset.length() + OVERSHOOT, spell.cast_range)
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
	var enemy := body as Enemy
	if enemy == null or not enemy.is_alive():
		return
	enemy.apply_damage(damage)
	_show_impact()


func _show_impact() -> void:
	_spent = true
	_impact_left = IMPACT_SECONDS
	_collision.set_deferred("disabled", true)
	var frames: Array[Texture2D] = [IMPACT]
	_ink.extra_scale = 0.13
	_ink.set_frames(frames)
	# The impact drawing is not aimed, so an inherited rotation would tilt it.
	rotation = 0.0
