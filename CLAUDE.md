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
- Levels = chunk scenes (chunks/chunk_*.tscn) stitched in random order per stage by StageBuilder; main scene is game.tscn (run flow), debug/test_track.tscn stays the feel sandbox.
- Transition surfaces include the gully's halfpipe (chunks/parts/halfpipe.tscn, group "transitions").
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

## Prefer editor-visible setup
Prefer editor-visible setup: scenes, nodes, .tres, @export, @tool previews; code for behaviour only (Wons's standing preference, from v0.6).
- Chunks are .tscn files with visible nodes (TrackLine Path3D + CSG Ribbon, Entry/Exit/Spawn Marker3D, instanced kicker/rail/halfpipe/finish-gate scenes). StageBuilder only instances and places them.
- One .tres per data item (tricks/data/, scoring/upgrades/). HUD, menus and the collapse are scenes laid out with nodes and a Theme (ui/bike_theme.tres).
- Expose tuning with @export (+ @export_range, groups, doc comments). Use @tool where a live editor preview or a button helps (Chunk "Rebuild TrackLine from keys", Rail "Rebuild posts").

## Design decisions
- No manual balance (v0.6, Wons: "prob just remove the balance"): the left stick Y does nothing in the air. The bike's nose follows the flight path and settles onto the predicted landing surface in the last `air_land_blend_time`. Landing grade (angle you meet the ground at) stays. Difficulty comes from line choice, hop timing and trick greed. Left-stick-forward pump on the ground stays (timing, not balance).

## Starting feel values (in PlayerTuning, tune live)
- Landing grade by angle between velocity and ground plane: perfect ≤12° (+12% speed, juice), good ≤30° (0%), sketchy ≤55° (-15%, camera shake, combo kept), bail >55° (-50%, Bail). Steep touchdowns slower than 14 m/s into the ground (≈4 m drop) are sketchy, never bail.
- Landing mid-trick: ≥70% done → trick auto-completes, landing is sketchy at best; <70% → Bail.
- Bail: 0.6 s, keeps 50% speed, then 1.0 s immunity (the next landing in that window is sketchy instead of a bail).
- Perfect landing juice: 40 ms hit-stop, camera punch 0.12 s ease-out expo, bright SFX.
- FOV 75° → 105° with speed (v0.5), ease-out over 0.25 s. Speed lines above 70% max speed.
- Coyote 0.10 s, jump buffer 0.12 s, hop full charge 0.25 s, pump +4% per clean pump.
- Trick gesture recognized within 150 ms; combo drops after 1.5 s of plain riding.
- Camera: spring arm, look-ahead on velocity, position damping 0.08 s, rotation 0.2 s; lower and further back than a runner cam.

## Input map (to set up)
steer_left/right: left stick X · lean_forward: left stick up = pump (ground only; lean_back unused since v0.6) · pedal: RT · brake: LT · hop: South (hold to charge) · grind: West · trick_left/right/up/down: right stick · pause: Start

## Status (2026-10-31, v0.6)
Done (v0.1): project settings, input map (+ debug_reset on Back/R), test track, Player with Ride/Air/Land/Bail, landing grades, debug overlay, physics interpolation. Feel gate approved by Wons.
Done (v0.2, phase 2 batch A):
- tricks/: TrickData resource + 4 starter tricks in tricks/data (up Frontloop, down Pocket, left/right Whirl). TrickRunner (child of Player) reads right-stick flicks (neutral -> >0.7 within 0.15 s), plays them on the Visual around the hips, chains a new flick in the last 30%.
- player/states/grind.gd + rails/rail_snap.gd: press grind within 1.5 m of a Path3D in group "rails" (Ride or Air). Rides the curve, slope gravity + grind_drag, hop or rail end -> Air.
- scoring/combo_tracker.gd (child of Player): points x multiplier (action count, capped). Tricks, grinds (+ points/s), perfect landings. Banks after combo_drop_time of plain riding (Events.combo_banked), bail drops it. Debug overlay shows trick, combo, run total.
- vfx/speed_lines.tscn (child of Player): radial streak shader, fades in from 70% to 90% of max_speed.
- debug/demo_driver.gd (node in test_track.tscn): input timeline, only with `-- --demo`. `--demo-trace` prints state, `--demo-shots=<dir>` saves stills. Timeline is tuned for --fixed-fps 30; retune if track or tuning changes.
- Test track fixes: bumps are now wide rollers (r 12 m, 0.7 m tall) so they can be pumped (the old ones launched you into the next bump at any speed above ~8 m/s); tabletop ramp/deck/landing made flush (old lip fired you up at 45 deg).
- Landing check: `<exe> --headless --path . --fixed-fps 60 --quit-after 12000 res://debug/test_track.tscn -- --landing-test` (since v0.6 the main scene is game.tscn, so name the test track) runs debug/landing_test.gd (42 scenarios in v0.5: hops, kickers, berms, tabletop, drops, nose-dive bails, halfpipe), prints grade + angle per landing, exit 1 on failure. Run it after any landing/tuning/track change.
- Record the test-track demo: `<exe> --path . --write-movie <abs path>/v0.x.avi --fixed-fps 30 --quit-after 930 res://debug/test_track.tscn -- --demo --demo-shots=<abs dir>` (the v0.5 run is ~31 s)

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

Done (v0.5 "extreme pass", after Wons's v0.4 playtest "looks pretty good, only thing I think we need is a bit more 'extreme' feeling, in terms of angle downwards, speed"):
- Track: the downhill is one CSGPolygon3D (Track/Ribbon) extruded along the Path3D `TrackLine` (Godot note: move TrackLine's curve points in the editor and the ribbon follows). Profile: 16 m flat + curved side walls (r 5 m, up to 40°), 4 m thick. Start deck at y 176 → convex drop-in to 35° (r 20) → 16 m at 35° → concave (r 50) → 385 m main descent at 23° → concave (r 100) → flat runout at y 0, z -128. On the descent: 3 rollers (24 m long, 1.5 m tall) built into the ribbon from u 10 m; Kicker1 / Kicker2 (CSG, 12° lip, r 36, 0.8 m tall) at u 100 / 285 so landing on the slope is the natural perfect (~10° from 30 m/s up; slower, the 0.8 m drop makes it good); banked S-turn (berms) u 155-275, 7 m sideways, apex radius 52 m, bank up to 14° via curve tilt. Runout features (tabletop, rail, halfpipe) shifted 60 m down (-Z), runout box z -120..-480. `Markers` (Marker3D) name the key spots; landing test and demo use them. `Scenery`: far ground at y -35 and two rows of tall pillars every 25 m (visual only): without a horizon or vertical references the downhill read like a ramp rising into the fog.
- Speed: max_speed 60, air_drag 0.0028 + rolling_drag 0.015 (terminal ~55 m/s on the 23° descent, less drag at halfpipe speeds than v0.4), pedal cap stays 18. steer_rate_high 40, lean_speed_extra_deg 14 (more bank at speed).
- Only bodies in group "transitions" count as transitions (camera mode, carving, transition pump); the steep drop-in and berm walls are plain ground.
- Edge release flies off along the surface before the edge (kicker face, deck), not the direction already tipped over it.
- Camera (all in PlayerTuning "Camera"): FOV 75 → 105 (`fov_speed_curve` 1.2); lower and closer at speed (`cam_*_fast` from 40% speed); pitch follows the slope (`cam_slope_follow` 0.55, smoothed 0.3 s; in the air it probes the ground under you; off in the halfpipe, which stays upright as before); smooth noise rumble on the ground above 70% speed (`cam_speed_shake_*`). Speed lines get denser toward max (`speed_lines_density_*`), max alpha 0.7.
- Halfpipe fairness: `lip_air_perfect_bonus` 0 (no speed gain coming back from a lip air; test "wall to wall" checks speed never grows). Lip airs, their landings and carving add points but not combo actions (ComboTracker.add_points; multiplier min 1); carve 25 pts/s, lip air 100. Demo: pipe combo 1750 vs best downhill combo 1000.
- Demo driver: steps hang off position cues (fire `dt` s after the rider passes a z) instead of absolute times; helpers `autosteer` (follows TrackLine, `aim_x` offset), `brake_to`. Run: drop-in, pump line, Whirl Right off kicker 1 (perfect), hop + Frontloop + Whirl Left off kicker 2, berms on autosteer, runout kicker, hop + Pocket off the tabletop, rail, halfpipe (3 lip airs, Whirl Left, Frontloop). Top speed 60 (cap, after kicker 2), ~55 through the berms.
- Landing test: 42 scenarios, scenarios can start at a marker + offset; starts in Air with the velocity along the ground (a flat start velocity launched you off a slope, and the body kept the previous scenario's floor contact for a tick); waits for CSG collision before the first one. New: drop-in, 52 m/s slope hops, rollers at 45/50 m/s, kickers at 22-56 m/s (+ tricks, + full hop), berms at 50 m/s, bottom transition at 56 m/s, tabletop at 45 m/s, halfpipe speed-growth check.

Done (v0.6 "core loop", after Wons's v0.5 playtest "the first half is really great. At the bottom you get really slow because of the flat field"):
- Chunks (chunks/): `Chunk` (chunk.gd, @tool) scenes: TrackLine (Path3D, points 1 m apart) + Track/Ribbon (CSGPolygon3D, v0.5 profile) + Entry/Exit Marker3D (+ Spawn on the start chunk). Every join is at 23°, heading 0, no bank, so chunks only ever turn around up. "Rebuild TrackLine from keys" (inspector button) rewrites the line from pitch/heading keys + rollers and moves Entry/Exit; features don't follow, move them after. 7 chunks: start (deck, drop-in), rollers (5 × 24 m × 1.5 m), kickers (v0.5 kicker + a 1.4× one), berms (S-turn ±18°, auto-bank ≤14°), rail (two 70-80 m rails on the slope, x ∓5), gully (slope eases to 15°, 150 m halfpipe = v0.4 recipe tilted to the slope), finish (gate at u 60, then a 4° runout). Plus chunk_template.tscn (100 m straight) to duplicate for new chunks. chunks/tools/author_chunks.gd wrote the first versions (re-running it overwrites hand edits).
- Parts: chunks/parts/kicker.tscn, halfpipe.tscn, finish_gate.tscn (Area3D, `FinishGate.crossed`), rails/rail.tscn (Rail is @tool now; posts are saved nodes under Posts, "Rebuild posts" button; a rail without Posts builds them at runtime, e.g. the test track).
- chunks/stage_builder.gd: start + N random middle chunks (no immediate repeats) + finish from a seed; keeps the stage centerline for `progress_at()` / `transform_at_distance()`; frees chunks 300 m behind you; chunks the collapse passed drop away. CSG collision needs ~2 physics frames after build (the game and smoke test wait).
- hazards/collapse.tscn: wall (shader quad), debris, glow light. Follows the centerline; speed 28 → 50 m/s (+1.2 m/s²) with +2 m/s per stage, times `collapse_speed_scale`; leash: never more than 180 m behind (−20 m per stage, min 90), so clean riding keeps it at bay and bails/slow lines bring it close. Catching you = run over.
- ui/run_hud.tscn: stage, time, run score, COLLAPSE distance, progress bar (you, finish, collapse), red edge vignette under 120 m, "COLLAPSE!" under 50 m. ui/menus/: stage summary (time, best combo, stage score, run score), upgrade picker (3 cards), run over. Gamepad: D-pad/left stick moves focus, A confirms; buttons ignore input for 0.5-0.8 s after opening.
- scoring/: UpgradeData (.tres per upgrade in scoring/upgrades/: stat on PlayerTuning, add or multiply); 8 upgrades (Clean Landings, Long Fuse, Pump Legs, Air Control, Spring Hop, Slick Pegs, Shaky Ground, Showboat). New tuning fields `grind_accel`, `trick_score_scale`, `collapse_speed_scale`. StageStats tracks time / best combo / stage score.
- game.tscn + game.gd (main scene): run = stage → summary → upgrade → next stage (one more chunk, harder collapse) until caught → run over → new run. Upgrades apply to a duplicate of player_tuning.tres. Falling off respawns you on the track 10 m back (combo lost). `--seed=<n>` fixes the run.
- Player: no manual air balance (see Design decisions; `air_pitch`/`air_pitch_rate` removed, new `air_land_blend_time`, `Player.predict_landing()`); `kill_y` + `fell` signal (`auto_respawn` off in the game); `place()` snaps the camera and clears hop input (a hop now needs a fresh press, so the menu's A doesn't hop you).
- debug/autopilot.gd (`-- --autopilot`): rides game.tscn (steers the centerline, aims at rails, pumps, coyote hops off lips, tricks when the predicted airtime allows), clicks through menus. `--autopilot-lose` brakes in stage 2+ so the collapse catches it, `--autopilot-trace`, `--autopilot-shots=<dir>`.
- Stage smoke test: `<exe> --headless --path . res://debug/stage_smoke_test.tscn` builds 20 stages and checks every join (markers within 5 cm / 0.5°, raycast surface step < 5 cm across the width, upward normals), chunks upright, always descending after the start deck, start/finish order, no repeats. Exit 1 on failure.
- Record: `<exe> --path . --write-movie <abs>/v0.6.avi --fixed-fps 30 --quit-after 1760 res://game.tscn -- --autopilot --autopilot-lose --seed=7` (stage 1, upgrade, stage 2 caught, run over).

## Next tasks, in order
1. Playtest v0.6 (game.tscn) with gamepad: collapse pressure (leash 180 m, speeds), stage length (~1.5-2 km, ~25 s), the gully at 50+ m/s (camera, carving at speed), the auto-orient in the air, upgrade picks.
2. More chunks and variety (the pool is 5 middle chunks); bigger kickers (airs are short at 55 m/s, the autopilot rarely gets time for a trick); a chunk with a tabletop or a gap.
3. The collapse is only visible looking back; consider a rear-view glance / rumble audio / debris flying past when it's close.
4. Stalling straight up a wall rolls you back down backwards and the bike visual flips 180° (no fakie / turn-around yet).
5. Camera: rider sits off-centre and small during lip airs; at the halfpipe exit the spring arm can dip into the transition wall.
6. Lip-air pose: bike side-on with wheels to the ramp reads like "lying on the deck" from the chase cam; add a proper vert pose / rotate the rider upright.
7. Bail recovery: proper bail animation/ragdoll-lite and a quicker way back into flow.
8. Real combo HUD in ui/ (the stacked flashes still live in the debug overlay).
9. Riding into a wall on the ground at an angle kills nearly all speed (pre-existing ground_move clamp); make it a glancing slide.
