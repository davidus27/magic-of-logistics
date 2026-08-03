# Fantasy Convoy MVP Proof of Concept Specification

**Document version:** 0.1
**Engine:** Godot 4.x
**Document type:** Game behavior and control test specification
**Language style:** ASD-STE100-based simplified technical English

> This document uses short sentences, active voice, defined technical terms, and one topic in each paragraph.
>
> This document does not claim formal ASD-STE100 certification.

## 1. Purpose

This proof of concept tests the main battlefield controls.

The test must show how one player controls three systems at the same time.

The three systems are the cargo unit, the defenders, and the wizard.

The proof of concept does not test contracts, salaries, upgrades, or campaign progression.

The proof of concept must use one fixed battlefield.

The project must support different control profiles on the same battlefield.

The test results must show which control profile is clear, difficult, and fun.

## 2. Main design decision

The game uses indirect control for the defenders.

The player does not move a defender with movement keys.

The player selects defenders and gives orders.

The defender artificial intelligence executes each order.

The player controls the wizard with the mouse.

The player controls the cargo unit with the keyboard.

These input groups stay active at the same time.

The player does not enter a separate wizard mode or defender mode.

## 3. MVP scope

The proof of concept contains these systems:

- One cargo unit
- One rider prop
- One wizard
- Four defenders
- One short-range enemy type
- One long-range enemy type
- One fixed map
- One road
- Two terrain types
- Two barriers
- One final portal
- Three wizard spells
- Two defender control methods
- Three cargo control methods
- Four test profiles
- One result screen
- One telemetry file

## 4. Items outside the MVP scope

The proof of concept does not contain these systems:

- Contracts
- Money
- Salaries
- Crew recruitment
- Permanent injuries
- Permanent upgrades
- Multiple dimensions
- Random map generation
- Inventory
- Equipment
- Dialogue
- Story content
- Boss combat
- Online functions
- Save-game progression

## 5. Technical terms

### 5.1 Cargo unit

The **cargo unit** is the wagon, the rider prop, and the wizard platform.

The cargo unit has one collision shape and one health value.

### 5.2 Defender

A **defender** is an autonomous crew unit near the cargo unit.

A defender can attack enemies, protect the cargo unit, and do repair work.

### 5.3 Order

An **order** is a player command for one or more selected defenders.

An order changes the active defender state.

### 5.4 Control profile

A **control profile** is one fixed combination of cargo control and defender control.

### 5.5 Engagement radius

The **engagement radius** is the maximum distance for an automatic defender attack.

The center of this radius is the cargo unit.

### 5.6 Leash radius

The **leash radius** is the maximum distance that a defender can move from the cargo unit.

### 5.7 Work point

A **work point** is a position for cargo repair or barrier removal.

### 5.8 Threat value

The **threat value** is a value that increases during a run.

A high threat value causes more enemy attacks.

## 6. Game objective

The player must move the cargo unit from the start area to the final portal.

The player must keep the cargo health above zero.

The player completes the run after the final portal cast.

The player fails the run when the cargo health becomes zero.

The player can continue after all defenders die.

The player cannot replace a defender during a run.

## 7. Run duration

One run must take between three minutes and six minutes.

A fast and successful run can finish in approximately three minutes.

A slow run must cause more enemy attacks.

A run must not continue for more than eight minutes.

The game must end the run after eight minutes.

This time limit prevents invalid test sessions.

## 8. Game states

The proof of concept has these game states:

1. Control profile selection
2. Instruction screen
3. Active run
4. Pause state
5. Portal cast
6. Success state
7. Failure state
8. Result screen

### 8.1 Control profile selection

The player selects one control profile before the run.

The screen shows a short description of each profile.

The player can also select a fixed test seed.

### 8.2 Instruction screen

The game starts in a paused state.

The screen shows the active keys and mouse controls.

The player presses `Enter` to start the run.

### 8.3 Active run

All game systems use normal simulation.

The player can control the cargo unit, defenders, and wizard.

### 8.4 Pause state

The player presses `Escape` to pause the game.

The pause state stops all simulation.

The pause state does not add time to the run timer.

### 8.5 Portal cast

The portal cast starts when the cargo center enters the final portal.

The cargo unit stops during the cast.

The cast takes four seconds.

Enemies can attack during the cast.

Damage does not stop the cast.

### 8.6 Success state

The player succeeds when the portal cast reaches four seconds.

The game stops all simulation.

The game opens the result screen.

### 8.7 Failure state

The player fails when the cargo health becomes zero.

The game stops all simulation.

The game opens the result screen.

## 9. Camera

The game uses a top-down camera.

The camera follows the cargo unit.

The cargo unit stays 15 percent behind the screen center.

This position gives more screen space in front of the cargo unit.

The camera uses smooth movement with a response time of 0.20 seconds.

The player cannot move the camera separately.

The player cannot rotate the camera.

The player can use the mouse wheel to change the zoom.

The zoom range is 0.85 to 1.20.

The default zoom is 1.00.

## 10. Visual design

### 10.1 General style

The game uses a paper and ink style.

The game uses black, white, and gray colors only.

The background uses an off-white paper color.

The background color is `#F3EFE4`.

The primary ink color is `#1A1A1A`.

The light line color is `#B7B2A8`.

The medium gray color is `#77736C`.

The game does not use realistic textures.

The game uses simple lines, circles, rectangles, and symbols.

### 10.2 Paper effect

A static paper grain covers the full screen.

The paper grain opacity is 8 percent.

The paper grain does not move.

The game does not use a complex paper shader in the MVP.

### 10.3 Line effect

Important world objects use two slightly different line frames.

The game changes the line frame every 0.15 seconds.

This effect gives a simple hand-drawn result.

The line effect must not change collision shapes.

### 10.4 Entity symbols

The cargo unit is a large rectangle with two wheel circles.

The rider is a small circle at the front of the cargo unit.

The wizard is a triangle inside the cargo rectangle.

A defender is a circle with a shield mark.

A short-range enemy is a filled black circle.

A long-range enemy is a hollow triangle.

A barrier is a thick cross-line on the road.

The final portal is a double ink circle.

### 10.5 Selection symbols

A selected defender has a double circle around its body.

The circle uses the primary ink color.

A selected defender portrait also has a double border.

An ordered defender shows a small order symbol above its body.

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

Off-road terrain applies only to the free steering profile.

Off-road terrain uses a cargo speed factor of 0.45.

Off-road terrain uses a turn factor of 0.70.

Off-road terrain does not cause direct damage.

### 12.4 Terrain feedback

The speed display shows the active terrain factor.

A short text label appears when the cargo enters new terrain.

The label stays visible for one second.

## 13. Cargo unit

### 13.1 Cargo properties

The cargo unit has these initial properties:

| Property | Value |
|---|---:|
| Maximum health | 100 |
| Initial health | 100 |
| Slow speed | 50 pixels per second |
| Normal speed | 90 pixels per second |
| Fast speed | 130 pixels per second |
| Reverse speed | 15 pixels per second |
| Acceleration | 60 pixels per second squared |
| Brake rate | 100 pixels per second squared |
| Turn rate | 80 degrees per second |

### 13.2 Cargo health

Enemy attacks reduce the cargo health.

The cargo health cannot increase above 100.

The cargo unit flashes for 0.10 seconds after damage.

A black crack mark appears below 60 health.

A second crack mark appears below 30 health.

### 13.3 Cargo collision

The cargo unit collides with map walls and barriers.

The cargo unit does not collide with defenders.

The cargo unit pushes enemies away from its collision shape.

The cargo unit does not cause collision damage.

### 13.4 Rider behavior

The rider is a visual prop.

The rider has no health, state, or collision shape.

The rider faces the cargo movement direction.

## 14. Wizard

### 14.1 Wizard position

The wizard stays at the center of the cargo unit.

The wizard does not move independently.

The wizard has no separate health value in the MVP.

Cargo health represents cargo and wizard survival.

### 14.2 Wizard resource

The wizard has 100 maximum mana.

The wizard starts with 100 mana.

Mana increases by 8 points each second.

Mana cannot increase above 100.

### 14.3 Spell selection

The player presses `1`, `2`, or `3` to select a spell.

The selected spell stays active until the player selects another spell.

The cursor shows the selected spell symbol.

The game shows the spell range around the cargo unit.

### 14.4 Spell cast control

The player uses the left mouse button to cast the selected spell.

The game does not cast a spell when the pointer is above the user interface.

The game rejects a target outside the spell range.

A short line shows the maximum permitted target point.

### 14.5 Spell 1: Arc Bolt

Arc Bolt is the basic attack spell.

Arc Bolt costs 5 mana.

Arc Bolt has a 0.50-second cooldown.

Arc Bolt has a 500-pixel range.

Arc Bolt causes 18 damage.

The spell creates one projectile from the wizard to the pointer position.

The projectile moves at 700 pixels per second.

The projectile hits the first enemy in its path.

The player can hold the left mouse button for repeated casts.

### 14.6 Spell 2: Mend

Mend restores health to one target.

Mend costs 25 mana.

Mend has a 5-second cooldown.

Mend has a 350-pixel range.

Mend restores 20 defender health.

Mend restores 15 cargo health.

Mend can revive a downed defender.

A revived defender receives 20 health.

The player must click the cargo unit or a defender.

The game selects the nearest valid target within 35 pixels of the pointer.

### 14.7 Spell 3: Ward

Ward creates a temporary protection area.

Ward costs 35 mana.

Ward has an 8-second cooldown.

Ward has a 400-pixel cast range.

Ward has a 110-pixel effect radius.

Ward stays active for four seconds.

Ward reduces enemy projectile damage by 80 percent.

Ward reduces enemy movement speed by 20 percent.

Ward does not reduce short-range attack damage.

Only one Ward can be active at one time.

## 15. Defenders

### 15.1 Defender count

The player starts with four defenders.

Each defender has different values.

### 15.2 Defender values

| Defender | Health | Attack damage | Defense | Repair rate | Speed |
|---|---:|---:|---:|---:|---:|
| Guard | 100 | 14 | 3 | 2 | 85 |
| Striker | 80 | 20 | 1 | 1 | 105 |
| Engineer | 90 | 9 | 2 | 6 | 80 |
| Warden | 120 | 11 | 5 | 3 | 70 |

Attack damage applies once each second.

Repair rate gives cargo health or barrier work each second.

Defense reduces each received damage value.

Final damage is not less than one.

### 15.3 Defender movement

Defenders use autonomous path movement.

Defenders can move through other defenders.

Defenders cannot move through barriers or map walls.

A small separation force prevents exact visual overlap.

A defender recalculates its path every 0.25 seconds.

### 15.4 Defender states

A defender can use these states:

- Follow
- Defend
- Attack
- Repair
- Return
- Downed
- Dead

### 15.5 Follow state

The Follow state moves the defender to its assigned cargo slot.

The defender uses this state after the start of the run.

The defender also uses this state when no other state applies.

### 15.6 Defend state

The Defend state keeps the defender near the cargo unit.

The defender has an assigned position around the cargo unit.

The assigned position is between 90 pixels and 130 pixels from the cargo center.

The defender intercepts the nearest enemy inside a 200-pixel defense radius.

The defender selects the enemy that is nearest to the cargo unit.

The defender stops pursuit outside a 260-pixel leash radius.

The defender then uses the Return state.

### 15.7 Attack state

The Attack state permits longer pursuit.

The Attack state uses a 420-pixel engagement radius.

The Attack state uses a 480-pixel leash radius.

The defender uses this target priority:

1. A direct target from the player
2. An enemy that attacks the cargo unit
3. The nearest long-range enemy
4. The nearest short-range enemy

The defender checks for a new target every 0.25 seconds.

The defender keeps its current target until a higher priority target appears.

The defender returns when the target leaves the leash radius.

### 15.8 Repair state

The Repair state gives priority to barrier work.

The defender selects a barrier within 180 pixels in front of the cargo unit.

The defender moves to the nearest free work point.

The defender applies its repair rate to the barrier work value.

The defender repairs the cargo unit when no barrier needs work.

Cargo repair works only at Stop or Slow speed.

The defender moves to a rear cargo work point.

The defender applies its repair rate to cargo health.

The defender waits at the rear slot during Normal or Fast speed.

The defender uses Defend behavior when no repair work is available.

### 15.9 Return state

The Return state moves the defender directly toward its assigned cargo slot.

The defender does not select a new target during this state.

The defender changes to its ordered state inside the defense radius.

### 15.10 Downed state

A defender enters the Downed state at zero health.

The defender cannot move, attack, or repair.

A 15-second downed timer starts.

The wizard can use Mend to revive the defender.

The defender enters the Dead state when the timer reaches zero.

### 15.11 Dead state

A dead defender stays as a light gray paper mark.

A dead defender has no collision shape.

A dead defender cannot return during the run.

## 16. Defender selection

The player can select one or more defenders.

The player presses `F1` through `F4` to select one defender.

The player presses `Q` to select all living defenders.

The player holds `Shift` and presses a function key to change a group selection.

The player can also click a defender portrait.

A click on a portrait does not cast a wizard spell.

The player cannot select a defender by a world click.

This rule prevents a conflict with wizard control.

## 17. Defender control method A: Role orders

This method tests simple state control.

The player selects defenders before an order.

The player presses `Z` for Attack.

The player presses `X` for Defend.

The player presses `C` for Repair.

The selected defenders change state immediately.

The defenders use automatic target selection.

The player cannot set a direct enemy target in this method.

The user interface shows one order button for each role.

## 18. Defender control method B: Direct target orders

This method tests a Dota-style target control.

The player selects defenders before an order.

The player right-clicks an enemy to give an Attack Target order.

The selected defenders attack that enemy.

The selected defenders return after the target dies or leaves the leash radius.

The player presses `X` to give a Defend Cargo order.

The player presses `C` to give a Repair Cargo order.

A right-click on empty ground has no effect.

A right-click on the cargo unit gives a Defend Cargo order.

This method does not permit direct movement orders.

## 19. Cargo control method A: Automatic path movement

The cargo unit follows the center of the road.

The player does not steer the cargo unit.

The player presses `W` to increase the speed level.

The player presses `S` to decrease the speed level.

The speed levels are Stop, Slow, Normal, and Fast.

The player presses `Space` to select Stop immediately.

The cargo unit cannot move backward.

The cargo unit stops when it touches a barrier.

The cargo unit continues after the barrier opens.

## 20. Cargo control method B: Road-limited manual movement

The player steers the cargo unit with wagon controls.

The player holds `W` to accelerate forward.

The player holds `S` to brake.

The player continues to hold `S` to move backward.

The player holds `A` or `D` to turn.

The player holds `Space` for a full brake.

Static road walls keep the cargo unit inside the road area.

The cargo unit slides along a road wall after contact.

Terrain changes the maximum speed and turn rate.

The cargo unit stops when it touches a barrier.

## 21. Cargo control method C: Free manual movement

This method uses the same keys as road-limited movement.

The map does not use road walls in this method.

The cargo unit can leave the road.

Off-road terrain reduces speed and turn rate.

Map border walls prevent movement outside the test map.

This method tests route choice and direct driving load.

## 22. Input priority rules

The keyboard movement input always controls the cargo unit.

The number keys always select wizard spells.

The left mouse button always casts the selected spell.

The right mouse button gives defender target orders only in method B.

The function keys always select defenders.

The role keys always give defender orders.

The user interface consumes pointer input above its controls.

A user interface click cannot cast a spell.

The game accepts simultaneous input from different input groups.

The player can steer, cast, and give an order during one simulation frame.

## 23. Recommended first control profile

The first build must use automatic cargo movement and role orders.

This profile gives the lowest control load.

This profile is the baseline for all other tests.

The player controls cargo speed, defender roles, spell selection, and spell targets.

## 24. Test profiles

The build must contain these four profiles:

| Profile | Cargo control | Defender control | Test purpose |
|---|---|---|---|
| P1 | Automatic path | Role orders | Baseline control load |
| P2 | Automatic path | Direct target orders | Defender target load |
| P3 | Road-limited manual | Role orders | Cargo steering load |
| P4 | Free manual | Role orders | Maximum cargo control load |

The test must change one main control factor at a time.

The test does not need all six possible combinations.

The same map and enemy seed must apply to each profile.

## 25. Enemies

### 25.1 Short-range enemy

The short-range enemy has these values:

| Property | Value |
|---|---:|
| Health | 32 |
| Speed | 82 pixels per second |
| Attack damage | 8 |
| Attack interval | 1.00 second |
| Attack range | 28 pixels |
| Defense | 0 |

The short-range enemy moves toward the cargo unit.

The enemy attacks a defender that blocks its route.

The enemy attacks the cargo unit when no defender blocks its route.

The enemy changes target every 0.50 seconds.

### 25.2 Long-range enemy

The long-range enemy has these values:

| Property | Value |
|---|---:|
| Health | 22 |
| Speed | 48 pixels per second |
| Projectile damage | 9 |
| Attack interval | 2.00 seconds |
| Preferred range | 280 pixels |
| Maximum range | 360 pixels |
| Defense | 0 |

The long-range enemy moves to its preferred range from the cargo unit.

The enemy stops and fires at the cargo unit.

The enemy targets a defender within 100 pixels of its position.

The enemy projectile moves at 350 pixels per second.

The projectile hits the first cargo or defender collision shape.

## 26. Enemy attack schedule

The battlefield has six fixed trigger areas.

The cargo unit activates a trigger area when it enters that area.

Each trigger area creates one fixed enemy group.

The groups use the selected test seed for spawn positions.

The first group contains four short-range enemies.

The second group contains two short-range enemies and two long-range enemies.

The third group contains six short-range enemies.

The fourth group contains four short-range enemies and three long-range enemies.

The fifth group contains three short-range enemies and five long-range enemies.

The sixth group contains eight short-range enemies and four long-range enemies.

## 27. Threat system

The threat value starts at zero.

The threat value increases by one each second.

The threat value stops during the pause state.

The game creates a reinforcement group each time the value passes 45 points.

A reinforcement group contains two short-range enemies and one long-range enemy.

The game creates the group behind or beside the cargo unit.

The spawn point must stay outside the visible screen.

The threat system makes slow movement more dangerous.

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

## 29. Combat rules

All attacks use real-time simulation.

The game does not use turns.

The game does not use friendly fire.

A projectile cannot pass through a valid target.

A melee attack requires a valid target inside attack range.

A unit cannot attack during its attack cooldown.

Damage uses this formula:

`final damage = maximum(1, attack damage - target defense)`

The cargo unit has zero defense in the MVP.

A dead enemy changes to a light gray paper mark for two seconds.

The game then removes the enemy.

## 30. User interface

### 30.1 Top-left area

The top-left area shows cargo health.

The area also shows cargo speed and terrain factor.

### 30.2 Top-center area

The top-center area shows distance to the final portal.

The area also shows the threat value and run timer.

### 30.3 Bottom-left area

The bottom-left area shows four defender portraits.

Each portrait shows health, state, and selection.

A downed portrait shows the remaining downed time.

### 30.4 Bottom-center area

The bottom-center area shows defender order controls.

The control labels change for the active defender method.

### 30.5 Bottom-right area

The bottom-right area shows three spell controls.

Each control shows mana cost and cooldown.

A mana bar appears above the spell controls.

### 30.6 World feedback

A line connects a defender to its direct target.

The line appears only for a direct target order.

A dashed circle shows the active defender leash radius after an order.

A short arrow shows a defender return action.

Damage values do not appear as floating numbers.

Health bars appear only after damage.

## 31. Sound design

The MVP can use simple placeholder sounds.

Each player action must have one clear sound.

The cargo speed change uses one short click.

A defender order uses one paper tap.

A spell cast uses one ink stroke sound.

Cargo damage uses one paper tear sound.

The portal cast uses a continuous low tone.

The MVP does not require music.

## 32. Godot scene design

The project must use these main scenes:

```text
Main.tscn
|- GameController
|- World
|  |- Map
|  |  |- PaperBackground
|  |  |- Road
|  |  |- RoadWalls
|  |  |- TerrainZones
|  |  |- BarrierContainer
|  |  `- FinalPortal
|  |- CargoUnit
|  |- DefenderContainer
|  |- EnemyContainer
|  |- ProjectileContainer
|  |- EffectContainer
|  `- Camera2D
|- UserInterface
`- TelemetryRecorder
```

### 32.1 Cargo scene

The cargo scene uses a `CharacterBody2D` root.

The cargo scene contains a collision shape, visual nodes, health, and a cargo motor.

The cargo motor uses the selected cargo control method.

### 32.2 Defender scene

The defender scene uses a `CharacterBody2D` root.

The scene contains a state machine, navigation agent, collision shape, visual nodes, and statistics.

### 32.3 Enemy scene

Each enemy scene uses a `CharacterBody2D` root.

The scene contains a state machine, navigation agent, collision shape, visual nodes, and statistics.

### 32.4 Spell scene

Each projectile or area spell uses a separate scene.

The wizard controller creates these scenes after a valid cast.

### 32.5 Data resources

The project must store balance values in Godot resources.

The project must not store balance values only in unit scripts.

Use these resource types:

- `DefenderData`
- `EnemyData`
- `SpellData`
- `CargoData`
- `ControlProfileData`
- `TestSeedData`

## 33. State machine design

Each defender and enemy uses an explicit finite state machine.

Each state has enter, update, and exit functions.

The state machine sends a signal after each state change.

The telemetry recorder stores each defender state change.

The state logic must not depend on animation completion.

The simulation controls the state logic.

## 34. Navigation rules

Defenders and enemies use `NavigationAgent2D`.

The cargo unit does not use local avoidance.

Defenders and enemies use local avoidance.

The navigation map must update after a barrier opens.

A unit must not stay blocked for more than two seconds.

A blocked unit must select a nearby fallback position.

The fallback position must stay inside the navigation area.

## 35. Test seed rules

A test seed controls enemy spawn positions.

The seed does not change enemy statistics.

The player can select seed 1, seed 2, or seed 3.

Each control profile must use the same seed sequence.

The result screen must show the selected seed.

## 36. Telemetry

The game writes one JSON file after each run.

The game stores the file in the Godot `user://` directory.

The file name contains the date, profile, and seed.

The telemetry file contains these values:

- Control profile
- Test seed
- Success or failure
- Run duration
- Cargo health at the end
- Maximum threat value
- Distance traveled
- Time at each cargo speed
- Time on each terrain type
- Number of cargo direction changes
- Number of defender selections
- Number of defender orders
- Number of direct target orders
- Number of spell selections
- Number of spell casts
- Number of invalid spell casts
- Mana spent
- Damage to the cargo unit
- Damage to defenders
- Defender deaths
- Cargo repair amount
- Barrier work amount
- Defender idle time
- Defender time outside the defense radius
- Pause count
- Total pause time

## 37. Result screen

The result screen shows objective results first.

The screen shows these values:

- Success or failure
- Run time
- Cargo health
- Defender survivors
- Defender orders
- Spell casts
- Pause count
- Maximum threat value

The screen then asks five test questions.

The player gives a value from one to five for each question.

The questions are:

1. I understood the active controls.
2. I could control the cargo unit.
3. I could control the defenders.
4. I could use wizard spells during other actions.
5. I want to play this control profile again.

The result screen stores these answers in the telemetry file.

## 38. Test procedure

Use the same map and seed for a profile comparison.

Do not explain hidden artificial intelligence rules during the first run.

Explain only the input controls and the objective.

Run each profile at least three times.

Change the profile order between players.

This change reduces the effect of player practice.

After each run, complete the five result questions.

After three runs, record one short spoken comment.

The comment must answer this question:

> Which task caused the most control problems?

## 39. Control profile evaluation

A good control profile must meet these conditions:

- The player completes at least two of three runs.
- The player gives control clarity a value of four or five.
- The player gives wizard use a value of four or five.
- The player does not pause more than three times in one run.
- The player does not give more than 40 defender orders in one run.
- The player can explain each defender death.
- The player reports useful control over defenders.
- The player reports enough time for wizard spells.

A profile fails when the player reports loss of control without a clear recovery action.

## 40. MVP acceptance criteria

The MVP is complete when all these conditions are true:

- All four control profiles work on the same map.
- The player can change the control profile before a run.
- The cargo unit can reach the final portal.
- Both enemy types can attack the cargo unit.
- Defenders can attack, defend, and repair.
- The wizard can cast all three spells.
- The final portal can complete a run.
- Cargo destruction can fail a run.
- The result screen shows test data.
- The telemetry file contains all required values.
- No unit stays blocked for more than two seconds.
- The game keeps at least 60 frames per second on the test computer.
- All important orders have visual and sound feedback.

## 41. Implementation order

Build the MVP in this order:

1. Build the map, road, cargo unit, and final portal.
2. Add automatic cargo movement.
3. Add one short-range enemy.
4. Add one defender with Defend and Attack states.
5. Add cargo health and run failure.
6. Add Arc Bolt.
7. Add all four defenders.
8. Add Repair state and one barrier.
9. Add the long-range enemy.
10. Add Mend and Ward.
11. Add direct target orders.
12. Add road-limited cargo movement.
13. Add free cargo movement.
14. Add user interface feedback.
15. Add the threat system.
16. Add telemetry and the result screen.
17. Add the second barrier and final balance values.
18. Run the four profile tests.

## 42. Decisions after the MVP test

The test must answer these questions:

- Does direct cargo steering add useful decisions?
- Does direct cargo steering prevent wizard use?
- Does automatic cargo movement feel too passive?
- Do role orders give enough defender control?
- Do direct target orders require too many actions?
- Can the player understand automatic defender targets?
- Can the player use spells without loss of cargo control?
- Does the player need a slow-motion command?
- Does the player need one command for all defenders?
- Does repair create a useful stop or speed decision?

Do not add campaign systems before these questions have clear answers.

## 43. Initial design recommendation

Use profile P1 as the first public prototype.

Profile P1 uses automatic cargo movement and role orders.

This profile keeps the focus on speed choice, defender policy, and wizard spells.

Use profile P2 to test the need for exact enemy targets.

Use profile P3 to test the cost of cargo steering.

Use profile P4 only after the player understands the other systems.

Free movement can add route choice, but it can also remove the convoy defense focus.

## 44. Language note

This specification uses necessary game terms as technical nouns.

Examples include cargo unit, control profile, engagement radius, state machine, and telemetry.

The text uses short descriptive sentences and direct procedural instructions.

A formal ASD-STE100 checker did not verify this document.
