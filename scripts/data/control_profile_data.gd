class_name ControlProfileData
extends Resource
## One fixed combination of cargo control and defender control.
## Specification section 5.4 and section 24.

## Cargo control methods of sections 19, 20 and 21.
enum CargoMode {
	## Method A: the cargo follows the road centre, the player sets a speed level.
	AUTO_PATH,
	## Method B: the player steers, static road walls keep the cargo on the road.
	ROAD_MANUAL,
	## Method C: the player steers, no road walls, off-road terrain applies.
	FREE_MANUAL,
}

## Defender control methods of sections 17 and 18.
enum DefenderMode {
	## Method A: the player presses a key to set a defender role.
	ROLE_ORDERS,
	## Method B: the player right-clicks an enemy to set a direct target.
	DIRECT_TARGET,
}

@export var id: String = "P1"
@export var display_name: String = ""
## Shown on the control profile selection screen. Section 8.1.
@export_multiline var description: String = ""
## Test purpose, from the table in section 24.
@export var test_purpose: String = ""

@export var cargo_mode: CargoMode = CargoMode.AUTO_PATH
@export var defender_mode: DefenderMode = DefenderMode.ROLE_ORDERS

## Method C removes the road walls so the cargo can leave the road. Section 21.
@export var use_road_walls: bool = false

## False until the milestone that adds this profile lands. The selection screen
## shows an unimplemented profile as disabled instead of silently running P1.
@export var implemented: bool = false
