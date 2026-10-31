# Bike! — Claude Code guide

Solo 3D game in Godot by Wons (UI/UX + motion designer, knows Python, new to Godot).
Full plan (living doc): https://claude.ai/artifact/KfZtR4tXFxm8zc76SBkQwg

## The game
Stylized third-person BMX + downhill momentum roguelite. References: Haste (speed earned by clean landings) and Denshattack! (right-stick trick flicks, grinds, combos).
Loop: ride downhill and pump bumps for speed → bunny hop / launch → flick tricks in the air → land (angle sets grade and speed change) → grind or carve transitions to keep the combo → bank combo → escape the collapse. Between stages: pick 1 of 3 upgrades. Meta unlocks persist across runs.
Goal right now: a playable demo built from the vertical slice. No deadline. Gamepad only for now; keyboard after the demo.

## Tech
- Godot 4.7.2 stable, standard build, GDScript. Do not upgrade.
- Editor exe: `../Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  - Headless check: `<exe> --headless --path . --quit` (reimports and surfaces script errors)
  - Script check: `<exe> --headless --path . --check-only --script res://path.gd`
  - After adding a new class_name file run `<exe> --headless --path . --import` once before checking. Use `--quit` / `--quit-after N` for checks; `--check-only --script` gives false 'Identifier not found: Events' errors because autoloads aren't loaded.
- Forward+ (D3D12 on Windows), Jolt physics, 60 Hz physics ticks.
- Player = CharacterBody3D with hand-written velocity math. Never a RigidBody. Sphere collider (works on any surface angle); on the ground motion is `ground_dir` (tangent to the surface) × `speed`, and `up_direction` follows the smoothed ground normal (world up in Air/Grind).
- Transition surfaces (quarter pipes) are CSG bodies in group "transitions": Air lands on their steep faces even though they count as walls relative to world up.
- Rails = Path3D/Curve3D, snap via closest-point lookup (~1.5 m radius).
- Levels = hand-built chunks stitched in random order per run.
- Art: Blender → .glb (triangulated, no Draco). Cel shader + inverted-hull outline later; greybox (CSG) until the vertical slice.

## Conventions
- Folders by feature: player/ (states/), rails/, tricks/, scoring/, chunks/, hazards/, ui/, vfx/, audio/, autoload/, debug/.
- Static typing everywhere (`var speed: float`). Untyped declarations should be errors.
- Call down, signal up. Game-wide signals go through the `Events` autoload.
- Only three autoloads: Events (autoload/events.gd), Save (autoload/save.gd), AudioBus (autoload/audio_bus.gd).
- All feel numbers live in `PlayerTuning` (player/player_tuning.gd → player_tuning.tres). Never hardcode tuning values in logic.
- Player state machine: one script per state in player/states/ with `enter()`, `exit()`, `physics_update(delta)`. States: Ride, Air, Land, Grind, Bail.
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
- Record: `<exe> --path . --write-movie <abs path>/v0.x.avi --fixed-fps 30 --quit-after 750 -- --demo --demo-shots=<abs dir>` (the v0.4 timeline runs ~24 s)

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

Done (v0.4, after Wons's v0.3 playtest "Wall feels clunky, maybe more halfpipe?"):
- Surface-tangent controller: ground motion is a 3D direction on the surface; steering rotates it around the ground normal; gravity along the surface slows you going up, gives speed back coming down and curves carves back down a bank. `up_direction` = smoothed ground normal while grounded (`ground_normal_smoothing`), so floor detection/snap work up to vertical. Capsule -> sphere collider (r 0.35, same bottom); the Visual is shifted to the sphere's contact point. `heading` is derived from velocity. `Player.place()` resets position/heading/speed/normals (respawn, landing test).
- Lips: going up a face steeper than `lip_min_angle_deg` (80) and losing the floor = lip air (straight up, push into the wall dropped, one combo action + `lip_air_score`). Vert assist in Air steers the speed across the lip line back to just inside it (`vert_assist_*`), and the bike's nose follows the velocity with the wheels toward the ramp. Lip-air landings are always graded (they're soft); coming back in on the curve lands PERFECT/GOOD.
- Edge release: floor snap no longer lets the sphere roll over sharp edges: more than `convex_release_deg` (45) of convex roll lets go (`lip_release_deg` 20 at the coping). Sharp inside corners (steep face into the floor) take the floor as the new ground. (Found when a slow rider rolled over the coping, off the deck, down its back and got stuck.)
- Pump also counts once per descent on the way down a transition (`pump_transition_min_deg`).
- WallRide state, its tuning group, `find_wall_ride`, `Events.wall_ride_started` deleted. New: `Events.carve_started`, `Events.lip_air`; ComboTracker `add_carve_time` (`carve_score_per_second` above `carve_min_angle_deg` 45; carving starts a combo if none). HUD flashes CARVE / LIP AIR (never over a trick name still showing).
- Camera: on transitions (and `cam_transition_hold` after) it stays upright, faces along the ramp instead of swinging with each carve, pulls back/up and moves out over the pipe (`cam_transition_*`).
- Track: Wall + WallKicker removed. Halfpipe (CSGCombiner3D "Halfpipe", group "transitions") on the runout, z -282..-352: two quarter pipes along the track, r 4 m, 0.4 m vertical, flat bottom x -4..4, 2 m decks at 4.4 m, 12 m entry/exit ramps cut at 20° so riding in off-line goes up onto the deck smoothly; full height z -294..-340. Visual-only metal coping. Runout extended to z -420.
- Landing test: 25 scenarios (wall cases replaced by 9 halfpipe cases: straight-up and carved lip airs, slow carve, lip air + Whirl, transition pump, stall at the lip, shallow carve over the lip, runout entry, off-line entry ramp). New options `--landing-trace`, `--landing-only=<text>`.
- Demo: after the rail, line up, drop in: right wall lip air (perfect), left wall lip air + Whirl Left (perfect), right wall lip air + Frontloop (perfect), pumps on the descents, turn down the pipe, exit, brake. Banks ~10.6k.

## Next tasks, in order
1. Playtest v0.4 with gamepad: carving feel (steering on the walls, gravity curving you back down), lip air height, vert assist strength (`vert_assist_*`), camera framing in the pipe.
2. Halfpipe is a speed farm: PERFECT lip landings (+12%) + transition pumps grow speed every wall. Consider no perfect speed bonus on lip landings, or a cap.
3. Stalling straight up a wall rolls you back down backwards and the bike visual flips 180° (no fakie / turn-around yet).
4. Camera: rider sits off-centre and small during lip airs; at the halfpipe exit the spring arm can dip into the transition wall.
5. Lip-air pose: bike side-on with wheels to the ramp reads like "lying on the deck" from the chase cam; add a proper vert pose / rotate the rider upright.
6. Bail recovery: proper bail animation/ragdoll-lite and a quicker way back into flow.
7. Real combo HUD in ui/ (the stacked flashes still live in the debug overlay). Carve points with the multiplier make halfpipe combos very large (~10k vs ~2k elsewhere); rebalance scores.
8. Riding into a wall on the ground at an angle kills nearly all speed (pre-existing ground_move clamp); make it a glancing slide.
