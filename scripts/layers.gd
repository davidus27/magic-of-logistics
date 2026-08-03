class_name Layers
extends RefCounted
## Physics layer bits. Keep this in step with the layer_names section of
## project.godot.
##
## There are two separate wall layers on purpose. Road walls keep the cargo on
## the road in control method B, but defenders pursue up to a 480 pixel leash and
## long-range enemies stand off at 360 pixels, so neither may collide with them.
## Only the map border walls stop every unit. Sections 15.7, 20, 21 and 25.2.

const CARGO := 1 << 0
const DEFENDER := 1 << 1
const ENEMY := 1 << 2
## Confines the cargo to the road. Cargo only.
const ROAD_WALL := 1 << 3
## Outer edge of the test map. Stops every unit.
const MAP_WALL := 1 << 4
const BARRIER := 1 << 5
const PROJECTILE_FRIENDLY := 1 << 6
const PROJECTILE_ENEMY := 1 << 7
const TERRAIN := 1 << 8
const TRIGGER := 1 << 9

## What the cargo unit collides with. Section 13.3.
const CARGO_MASK := ROAD_WALL | MAP_WALL | BARRIER
## What defenders and enemies collide with. Sections 15.3 and 21.
const UNIT_MASK := MAP_WALL | BARRIER
