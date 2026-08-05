class_name Ward
extends Node2D
## The Ward protection area. Specification section 14.7.
##
## Ward is a temporary circle around a cast point that weakens the enemies inside
## it: an enemy projectile that lands in the area does far less damage, and an
## enemy standing in it moves slower. It never softens a short-range melee blow,
## which the enemy side keeps out of the two queries below by only routing bolt
## damage and movement through them.
##
## Only one Ward can be active at one time (section 14.7), so the live instance
## is held on a static reference that the enemy body and the enemy bolt read.
## A second cast dismisses the first, so this is a single value and never a list.

## The Ward now on the field, or null. Section 14.7 allows only one at a time.
static var active: Ward = null

## Seconds of fade at the end, so the ring thins out rather than blinking away.
const FADE_SECONDS := 0.6
## The dashed ring is drawn as this many segments, every other one skipped.
const RING_SEGMENTS := 40

var effect_radius: float = 110.0
## Fraction removed from an enemy bolt that lands inside the area. Section 14.7.
var projectile_damage_reduction: float = 0.80
## Fraction removed from the movement speed of an enemy inside the area.
var enemy_slow_factor: float = 0.20

## Seconds of protection left. Section 14.7 gives four.
var _life: float = 4.0


## Place the Ward and take over as the single active one. Section 14.7.
func setup(spell: SpellData, at: Vector2) -> void:
	global_position = at
	effect_radius = spell.effect_radius
	projectile_damage_reduction = spell.projectile_damage_reduction
	enemy_slow_factor = spell.enemy_slow_factor
	_life = spell.duration
	# The newest cast is always the active one. A Ward it replaced frees itself a
	# frame later, and its [method _exit_tree] leaves this reference alone.
	active = self


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		dismiss()
		return
	queue_redraw()


func _exit_tree() -> void:
	# Clear the shared reference only when it still points here, so a Ward that
	# replaced this one keeps the field. See [method Wizard._cast_ward].
	if active == self:
		active = null


## Remove this Ward now, used when a second Ward replaces it or a run ends.
func dismiss() -> void:
	if active == self:
		active = null
	queue_free()


## True when a world point is inside the protected area.
func contains_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= effect_radius


# --- Queries the enemy side asks, section 14.7 -------------------------------


## Damage an enemy bolt landing at a world point should deal after any active
## Ward. Section 14.7 reduces enemy projectile damage; final damage is never
## below 1, matching section 29.
static func reduced_damage(point: Vector2, amount: int) -> int:
	if active == null or not is_instance_valid(active) or not active.contains_point(point):
		return amount
	return maxi(1, roundi(float(amount) * (1.0 - active.projectile_damage_reduction)))


## Movement speed scale for an enemy at a world point after any active Ward.
## Section 14.7 reduces enemy movement speed. One where no Ward touches it.
static func speed_scale(point: Vector2) -> float:
	if active == null or not is_instance_valid(active) or not active.contains_point(point):
		return 1.0
	return 1.0 - active.enemy_slow_factor


# --- Presentation -------------------------------------------------------------


func _draw() -> void:
	# Thin the whole mark out over its last moments so it reads as fading rather
	# than snapping off the page. Section 30.6 asks for readable world feedback.
	var alpha := clampf(_life / FADE_SECONDS, 0.0, 1.0)
	draw_circle(Vector2.ZERO, effect_radius, Color(InkPalette.GRAY_MEDIUM, 0.08 * alpha))

	# A dashed ink ring reads as a drawn guide, not a solid world object, in the
	# paper-and-ink style of section 10.
	var ring := Color(InkPalette.INK, alpha)
	var step := TAU / float(RING_SEGMENTS)
	for i in range(0, RING_SEGMENTS, 2):
		var from := Vector2.RIGHT.rotated(i * step) * effect_radius
		var to := Vector2.RIGHT.rotated((i + 1) * step) * effect_radius
		draw_line(from, to, ring, 2.0, true)
