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

@export_group("Movement")
## A small separation force prevents exact visual overlap. Section 15.3.
@export var separation_radius: float = 26.0
@export var separation_strength: float = 40.0
## A unit blocked for longer than this picks a fallback position. Section 34.
@export var blocked_timeout: float = 2.0
