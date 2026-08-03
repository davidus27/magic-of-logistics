class_name DefenderTuning
extends Resource
## Behaviour values shared by every defender. Specification sections 15.3
## to 15.10.
##
## These are one set of values for all four defenders, so they are kept apart
## from the per-defender statistics in [DefenderData].

@export_group("Follow and Defend", "defend_")
## Assigned position range around the cargo centre. Section 15.6.
@export var defend_slot_min: float = 90.0
@export var defend_slot_max: float = 130.0
## The defender intercepts the nearest enemy inside this radius. Section 15.6.
@export var defend_radius: float = 200.0
## The defender stops pursuit outside this radius. Section 15.6.
@export var defend_leash: float = 260.0

@export_group("Attack", "attack_")
## Engagement radius of the Attack state. Section 15.7.
@export var attack_radius: float = 420.0
## Leash radius of the Attack state. Section 15.7.
@export var attack_leash: float = 480.0
## Melee reach, measured from the defender body to the target surface.
##
## The specification gives an attack range for the short-range enemy in section
## 25.1 but none for a defender. This is a little longer than that 28 pixels, so
## a defender that closes on an enemy strikes first.
@export var attack_range: float = 34.0

@export_group("Timing")
## Attack damage applies once each second. Section 15.2.
@export var attack_interval: float = 1.0
## Target and path recalculation period. Sections 15.3 and 15.7.
@export var retarget_interval: float = 0.25
@export var path_interval: float = 0.25
## A downed defender dies when this timer ends. Section 15.10.
@export var downed_seconds: float = 15.0

@export_group("Repair")
## The defender looks for a barrier this far in front of the cargo. Section 15.8.
@export var barrier_search_distance: float = 180.0
## Distance behind the cargo centre of the rear cargo work points. Section 15.8.
@export var repair_work_distance: float = 96.0
## Sideways spacing between neighbouring rear work points.
@export var repair_work_spacing: float = 30.0

@export_group("Movement")
## How much faster than the cargo unit a defender may travel to reach its slot.
##
## The two specification tables do not agree. Section 15.2 gives defender speeds
## of 70 to 105 pixels per second and section 13.1 gives the cargo unit 90 at
## Normal and 130 at Fast, so only the Striker can hold the assigned position of
## section 15.6 at Normal and nobody can at Fast. Left alone, three of the four
## defenders trail out of formation for the whole run at any useful speed.
##
## A defender walking back to its slot is therefore allowed the cargo speed plus
## this margin. It applies to catching up and to nothing else: an interception,
## a pursuit and a walk to a work point all use the section 15.2 speed, so the
## statistic still decides every fight.
@export var catch_up_margin: float = 25.0

## A small separation force prevents exact visual overlap. Section 15.3.
@export var separation_radius: float = 26.0
@export var separation_strength: float = 40.0
## A unit blocked for longer than this picks a fallback position. Section 34.
@export var blocked_timeout: float = 2.0
