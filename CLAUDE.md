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
  - After adding a new class_name file run `<exe> --headless --path . --import` once before checking. Use `--quit` / `--quit-after N` for checks; `--check-only --script` gives false 'Identifier not found: Events' errors because autoloads aren't loaded.
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
- Landing grade by angle between velocity and ground plane: perfect ≤12° (+12% speed, juice), good ≤30° (0%), sketchy ≤55° (-15%, camera shake, combo kept), bail >55° (-50%, Bail). Steep touchdowns slower than 14 m/s into the ground (≈4 m drop) are sketchy, never bail.
- Landing mid-trick: ≥70% done → trick auto-completes, landing is sketchy at best; <70% → Bail.
- Bail: 0.6 s, keeps 50% speed, then 1.0 s immunity (the next landing in that window is sketchy instead of a bail).
- Perfect landing juice: 40 ms hit-stop, camera punch 0.12 s ease-out expo, bright SFX.
- FOV 75° → 95° with speed, ease-out over 0.25 s. Speed lines above 70% max speed.
- Coyote 0.10 s, jump buffer 0.12 s, hop full charge 0.25 s, pump +4% per clean pump.
- Trick gesture recognized within 150 ms; combo drops after 1.5 s of plain riding.
- Camera: spring arm, look-ahead on velocity, position damping 0.08 s, rotation 0.2 s; lower and further back than a runner cam.

## Input map (to set up)
steer_left/right: left stick X · lean_back/forward: left stick Y · pedal: RT · brake: LT · hop: South (hold to charge) · grind: West · trick_left/right/up/down: right stick · pause: Start

## Status (2026-10-31)
Done (v0.1): project settings, input map (+ debug_reset on Back/R), test track, Player with Ride/Air/Land/Bail, landing grades, debug overlay, physics interpolation. Feel gate approved by Wons.
Done (v0.2, phase 2 batch A):
- tricks/: TrickData resource + 4 starter tricks in tricks/data (up Frontloop, down Pocket, left/right Whirl). TrickRunner (child of Player) reads right-stick flicks (neutral -> >0.7 within 0.15 s), plays them on the Visual around the hips, chains a new flick in the last 30%.
- player/states/grind.gd + rails/rail_snap.gd: press grind within 1.5 m of a Path3D in group "rails" (Ride or Air). Rides the curve, slope gravity + grind_drag, hop or rail end -> Air.
- scoring/combo_tracker.gd (child of Player): points x multiplier (action count, capped). Tricks, grinds (+ points/s), perfect landings. Banks after combo_drop_time of plain riding (Events.combo_banked), bail drops it. Debug overlay shows trick, combo, run total.
- vfx/speed_lines.tscn (child of Player): radial streak shader, fades in from 70% to 90% of max_speed.
- debug/demo_driver.gd (node in test_track.tscn): input timeline, only with `-- --demo`. `--demo-trace` prints state, `--demo-shots=<dir>` saves stills. Timeline is tuned for --fixed-fps 30; retune if track or tuning changes.
- Test track fixes: bumps are now wide rollers (r 12 m, 0.7 m tall) so they can be pumped (the old ones launched you into the next bump at any speed above ~8 m/s); tabletop ramp/deck/landing made flush (old lip fired you up at 45 deg).
- Landing check: `<exe> --headless --path . --fixed-fps 60 --quit-after 6000 -- --landing-test` runs debug/landing_test.gd (16 scenarios: hops, kickers, tabletop, drops, nose-dive bails), prints grade + angle per landing, exit 1 on failure. Run it after any landing/tuning/track change.
- Record: `<exe> --path . --write-movie <abs path>/v0.x.avi --fixed-fps 30 --quit-after 600 -- --demo --demo-shots=<abs dir>`

Done (v0.2.1, forgiving landings, after Wons's v0.2 playtest "kept getting bail"): sketchy grade (orange flash), trick land tolerance, shorter bail + immunity, bail_min_impact, landing test harness. Debug overlay shows the last bail reason (angle or unfinished trick %).

Done (v0.3, after Wons's v0.2.1 playtest "although very primitive, it felt fun to use"):
- Hop fix: hop pops along a blend of ground normal and up (`hop_normal_blend` 0.7), and a hop turns floor snapping off until the next ground tick (the snap was what ate small hops on the slope). Min hop on the 12° slope at 25 m/s now lands PERFECT.
- player/states/wall_ride.gd: from Air when hitting a wall (|normal.y| <= 0.3) with >= 8 m/s along it, or from Ride when steering into a wall at speed. Reduced gravity, speed bleeds, bike tilts to the wall, max 1.6 s. Hop = wall jump (away + up), else time/speed/lost wall -> Air, touching the floor -> Land. One combo action + 150 pts/s. All numbers in PlayerTuning "Wall ride" group.
- Test track: Wall moved to z -265..-305 and made 5 m tall; WallKicker (angled 30° toward the wall) at x 6.8 z -272; runout extended to z -340.
- rails/rail.gd (class Rail, on every rail Path3D): 0.12 m cyan emissive bar, posts every 5 m, glows brighter while within snap radius (Player._update_rail_highlight).
- HUD (debug overlay): three stacked flash lines with their own timers (0.6 s hold + 0.3 s fade): trick / GRIND / WALL RIDE on top, landing grade in the middle, BANKED at the bottom.
- Landing test: 20 scenarios (added 4 wall-ride cases: kicker -> wall ride -> hop off at 18 and 24 m/s, ride until it ends, steer into wall from the ground; plus `expect_landing` on the slope min hop).
- Demo timeline: after the rail, swing right onto the WallKicker, wall ride ~0.9 s, hop off, brake. Grind + wall ride bank as one combo.
- Fix: hitting a wall during a hit-stop tick (delta 0) gave NaN speed; ground_move skips the wall speed clamp then.

## Next tasks, in order
1. Playtest v0.3 with gamepad: wall ride entry (min speed, steer threshold), height/duration on the wall, wall-jump feel, rail glow readability, stacked HUD timing.
2. Tune PlayerTuning (and trick .tres durations/scores) from playtest notes. Wall rides currently stay low (~1-1.5 m) and end by touching the floor before wall_ride_max_time; consider more entry lift or less wall gravity.
3. Camera on walls: the spring arm hugs the wall during a wall ride; offset the camera away from the wall.
4. Bail recovery: proper bail animation/ragdoll-lite and a quicker way back into flow.
5. Real combo HUD in ui/ (the stacked flashes still live in the debug overlay).
6. Riding into a wall on the ground at an angle kills nearly all speed (pre-existing ground_move clamp); make it a glancing slide.
