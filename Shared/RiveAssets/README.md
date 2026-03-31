# Rive Assets

Place `.riv` files here. Each file must contain a state machine named `emotions` with the following inputs:

## Required State Machine Inputs

| Input Name     | Type    | Description                           |
|----------------|---------|---------------------------------------|
| `emotionState` | Number  | 0=idle, 1=thinking, 2=focused, 3=responding, 4=error, 5=success, 6=listening, 7=sleeping |
| `intensity`    | Number  | 0.0 to 1.0                           |
| `triggerBlink` | Trigger | (Optional) One-shot blink animation   |

## File Naming

Use snake_case for file names (e.g., `robot_face.riv`). The file name (without extension) is used as the identifier in the Bonjour protocol.

## Creating Avatars

1. Design your avatar at [rive.app](https://rive.app)
2. Add a state machine named `emotions`
3. Create states for each emotion (idle, thinking, focused, responding, error, success, listening, sleeping)
4. Use the `emotionState` number input to drive transitions between states
5. Use the `intensity` number input to control animation intensity
6. Export as `.riv` and place in this directory
7. Add a new case to `RiveAvatarType` in `Shared/Models/RiveAvatarConfig.swift`
