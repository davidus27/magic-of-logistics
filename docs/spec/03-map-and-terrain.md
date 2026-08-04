# Map, terrain and barriers — §11–12, §28

Implemented by `world/map/map.gd`, `world/map/terrain_zone.gd`,
`world/map/barrier.gd` and `world/map/final_portal.gd`.

**The map is generated, never placed.** `Map.build()` derives the road lines, road
walls, border walls, navigation region, mud zones, barriers and portal from the
control points in `data/map_route.tres`. Move a control point and everything
follows. Hand-placing 9,000 px of geometry is not maintainable.

`tools/road_calc.py` reproduces Godot's curve baking, so the length and turn demand
it prints are the ones the game gets. Re-run it after changing the route shape:

```sh
python3 tools/road_calc.py --target 9000 --wavelength 2800
```

## 11. Battlefield layout

The map is approximately 9,000 pixels long.

The visible road width is 420 pixels.

The map uses one main route without branches.

The map contains six enemy trigger areas.

The map contains two mud areas.

The map contains two barriers.

The final portal is at the end of the route.

The first enemy trigger starts after 15 seconds of normal cargo movement.

The first 15 seconds form a control practice area.

> **Build note.** The route is gently winding with four sweeping bends. The minimum
> turn radius of 421 px asks 8.8 deg/s of the 80 deg/s available in §13.1, so a
> future manual cargo motor keeps a wide margin.

## 12. Terrain

### 12.1 Road terrain

Road terrain uses a speed factor of 1.00.

Road terrain does not change unit health.

### 12.2 Mud terrain

Mud terrain uses a cargo speed factor of 0.60.

Mud terrain uses a defender speed factor of 0.75.

Mud terrain uses an enemy speed factor of 0.80.

A clear gray fill shows the mud area.

### 12.3 Off-road terrain

Off-road terrain applies only when the active cargo motor allows the cargo unit
to leave the road.

Off-road terrain uses a cargo speed factor of 0.45.

Off-road terrain uses a turn factor of 0.70.

Off-road terrain does not cause direct damage.

### 12.4 Terrain feedback

The speed display shows the active terrain factor.

A short text label appears when the cargo enters new terrain.

The label stays visible for one second.

## 28. Barriers

The map contains two barriers.

Each barrier blocks the full road width.

Each barrier has 100 work points.

Repair defenders reduce the work points.

The barrier opens at zero work points.

The barrier then removes its collision shape.

The cargo unit stops when it touches a closed barrier.

Enemies can attack during barrier work.

Attack defenders cannot reduce barrier work points.

The user interface shows barrier work progress above the barrier.

> **Build note.** Barriers are generated but their collision is disabled until the
> Repair state can open them, which lands with milestone 4. The full road width
> matters: the `assets/` pack draws a single cross symbol, so the barrier art here
> is hand-authored to cover all 420 px.
