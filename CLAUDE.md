# Bike! — Claude Code guide

Solo 3D game in Godot by Wons (UI/UX + motion designer, knows Python, new to Godot).
Full plan (living doc): https://claude.ai/artifact/KfZtR4tXFxm8zc76SBkQwg

## The game
Stylized third-person BMX + downhill momentum roguelite. References: Haste (speed earned by clean landings) and Denshattack! (right-stick trick flicks, grinds, combos).
Loop: ride downhill and pump bumps for speed → bunny hop / launch → flick tricks in the air → land (angle sets grade and speed change) → grind or wall-ride to keep the combo → bank combo → escape the collapse. Between stages: pick 1 of 3 upgrades. Meta unlocks persist across runs.
Goal right now: a playable demo built from the vertical slice. No deadline. Gamepad only for now; keyboard after the demo.

## Tech
- Godot 4.7.2 stable, standard build, GDScript. Do not upgrade.
- Editor exe: `../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  - Headless check: `<exe> --headless --path . --quit` (reimports and surfaces script errors)
  - Script check: `<exe> --headless --path . --check-only --script res://path.gd`
- Forward+ (D3D12 on Windows), Jolt physics, 60 Hz physics ticks.
- Player = CharacterBody3D with hand-written velocity math. Never a RigidBody.
- Rails = Path3D/Curve3D, snap via closest-point lookup (~1.5 m radius).
- Levels = hand-built chunks stitched in random order per run.
- Art: Blender → .glb (triangulated, no Draco). Cel shader + inverted-hull outline later; greybox (CSG) until the vertical slice.

## Conventions
- Folders by feature: player/ (states/), rails/, tricks/, scoring/, chunks/, hazards/, ui/, vfx/, audio/, autoload/, debug/.
- Static typing everywhere (`var speed: float`). Untyped declarations should be errors.
- Call down, signal up. Game-wide signals go through the `Events` autoload.
- Only three autoloads: Events (autoload/events.gd), Save (autoload/save.gd), AudioBus (autoload/audio_bus.gd).
- All feel numbers live in `PlayerTuning` (player/player_tuning.gd → player_tuning.tres). Never hardcode tuning values in logic.
- Player state machine: one script per state in player/states/ with `enter()`, `exit()`, `physics_update(delta)`. States: Ride, Air, Land, Grind, WallRide, Bail.
- Input through InputMap actions only, never raw buttons.
- Prefer editing scenes/settings via the editor when Wons has Godot open. If editing project.godot or .tscn by hand, ask him to close Godot first or it will overwrite your changes.
- Explain Godot concepts briefly when introducing them; Wons is learning the engine.
- Git: small commits, tag every playtest build. LFS tracks .glb .blend .png .jpg .exr .wav .ogg.
- The folder name contains `!`: quote paths, and in bash use single quotes to avoid history expansion.

## Starting feel values (in PlayerTuning, tune live)
- Landing grade by angle between velocity and ground normal: perfect ≤10° (+12% speed), good ≤25° (0%), bad >25° (-30%, Bail).
- Perfect landing juice: 40 ms hit-stop, camera punch 0.12 s ease-out expo, bright SFX.
- FOV 75° → 95° with speed, ease-out over 0.25 s. Speed lines above 70% max speed.
- Coyote 0.10 s, jump buffer 0.12 s, hop full charge 0.25 s, pump +4% per clean pump.
- Trick gesture recognized within 150 ms; combo drops after 1.5 s of plain riding.
- Camera: spring arm, look-ahead on velocity, position damping 0.08 s, rotation 0.2 s; lower and further back than a runner cam.

## Input map (to set up)
steer_left/right: left stick X · lean_back/forward: left stick Y · pedal: RT · brake: LT · hop: South (hold to charge) · grind: West · trick_left/right/up/down: right stick · pause: Start

## Status (2026-10-31)
Done: Godot 4.7.2, Blender, Git + LFS installed. Project created (Forward+, Jolt, stretch canvas_items/expand). .gitattributes with LFS rules, .gitignore with /builds/, feature folders, autoload stubs, PlayerTuning script.

## Next tasks, in order
1. `git init`, `git lfs install`, first commit, tag v0.0.
2. Project settings: window 1920×1080, MSAA 3D 4×, GDScript warning "Untyped Declaration" = Error, register the three autoloads, disable Emulate Touch From Mouse.
3. Input map from the table above (deadzone 0.2 on sticks).
4. Create player/player_tuning.tres from PlayerTuning.
5. debug/test_track.tscn: WorldEnvironment, DirectionalLight3D, CSG slopes/ramps/bumps, one Path3D rail. Set as main scene.
6. Player scene: CharacterBody3D, capsule collider, placeholder mesh, ShapeCast3D ground probe, SpringArm3D + Camera3D.
7. State machine with Ride, Air, Land first; then landing grades; then debug overlay (speed, state, last landing angle + grade, combo timer).
8. Commit, tag v0.1. Gate for phase 2: does a perfect landing feel good with cubes only?
