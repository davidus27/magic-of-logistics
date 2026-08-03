# Game flow and camera — §8–9

Implemented by `main/game_controller.gd` (states) and `world/camera_rig.gd` (camera).
The game controller runs while the game is paused.

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
