extends SceneTree
## Authoring helper for the landscape chunks: writes chunks/landscape/*.tscn
## from the specs below. Each chunk is an open valley (TerrainPatch
## "Terrain") that can bend left/right (heading curve) and narrow (width
## profile). There are no lanes: kickers, rails, gullies, ridges and rollers
## are standalone features spread across the valley, and obstacles come in
## clusters (tree clumps, rock groups, fence runs, barrier rows, logs). The
## clusters are kept off a few invisible, wandering corridors (RideLines
## under "Lines": data only, for respawn / the autopilot / tests), so there
## is always open ground to thread through, but the rider picks their own way.
##
## SAFE BY DEFAULT: it only writes chunks whose .tscn doesn't exist yet, so
## hand edits made in the editor are never overwritten. To regenerate:
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd               (missing chunks only)
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd -- --only=land_gorge --overwrite
##   <exe> --headless --path . -s res://chunks/tools/author_landscape.gd -- --overwrite (ALL, loses hand edits)

const KICKER: PackedScene = preload("res://chunks/parts/kicker.tscn")
const RAIL: PackedScene = preload("res://rails/rail.tscn")
const FINISH: PackedScene = preload("res://chunks/parts/finish_gate.tscn")
const TREE: PackedScene = preload("res://chunks/parts/props/tree.tscn")
const ROCK: PackedScene = preload("res://chunks/parts/props/rock.tscn")
const LOG: PackedScene = preload("res://chunks/parts/props/log.tscn")
const FENCE: PackedScene = preload("res://chunks/parts/props/fence.tscn")
const BARRIER: PackedScene = preload("res://chunks/parts/props/barrier.tscn")
const BOULDER: PackedScene = preload("res://hazards/rolling_boulder.tscn")
const TIGHT: PackedScene = preload("res://chunks/parts/tight_zone.tscn")
const GATE: PackedScene = preload("res://chunks/parts/boost_gate.tscn")

const SLOPE: float = 23.0
const WIDTH: float = 150.0
## Every chunk shares these edges, so any two join.
const OUTSIDE_WIDTH: float = 35.0
const OUTSIDE_DROP: float = 25.0
## No obstacles or features this close to the entry / exit (open seams).
const END_CLEAR: float = 32.0
## Rails sit this high on a ledge you have to hop onto (v0.9.1).
const RAIL_HEIGHT: float = 0.75
## Obstacle footprint radius by kind (m), for spacing and corridor clearance.
const RADIUS: Dictionary = {"tree": 0.6, "rock": 1.8, "log": 5.0, "fence": 3.2, "barrier": 1.6}
## Per tier (index = difficulty): corridor clear half-width, clusters per
## 10 000 m2, kicker scale, wander strength.
const CLEAR: Array[float] = [9.0, 9.0, 7.0, 5.5]
const CLUSTERS: Array[float] = [5.0, 5.0, 8.0, 10.0]
const KICK_SCALE: Array[float] = [1.0, 1.0, 1.15, 1.15]
const WANDER: Array[float] = [0.5, 0.5, 0.75, 1.0]


static func specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"file": "land_start", "length": 240.0, "difficulty": 1, "seed": 3, "noise": 1.5,
		"profile": [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.33, 1.75), Vector2(0.55, 1.75), Vector2(0.8, 1.0), Vector2(1.0, 1.0)],
		"pad": Vector4(0, 24, 44, 52), "spawn": 6.0, "drop_in": 50.0,
		"corridors": 1, "wander": 0.0, "clusters": 1.5})
	# Speed contrast (v0.9): every chunk mixes fast drops (profile 1.3-1.45 =
	# 30-33 deg) with slow technical stretches (0.55-0.65 = 13-15 deg) where
	# the obstacles are densest ("dense": Vector3(d0, d1, extra weight)).
	# Tier 1: open, gentle bends.
	out.append({"file": "land_meadow", "length": 340.0, "difficulty": 1, "seed": 11, "noise": 2.0,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.45, 15), Vector2(0.8, -10), Vector2(1, 0)],
		"profile": [Vector2(0, 1), Vector2(0.18, 1), Vector2(0.32, 1.35), Vector2(0.48, 1.35), Vector2(0.6, 0.6), Vector2(0.82, 0.6), Vector2(0.94, 1), Vector2(1, 1)],
		"dense": [Vector3(205, 280, 3.0)],
		"corridors": 4, "kickers": 3, "rails": 3, "rollers": 2, "gullies": 0, "ridges": 1, "gap_gates": 1,
		"mix": {"tree": 5, "rock": 2, "log": 1, "fence": 1}})
	out.append({"file": "land_ridge", "length": 360.0, "difficulty": 1, "seed": 23, "noise": 2.2,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.85, 25), Vector2(1, 25)],
		"profile": [Vector2(0, 1), Vector2(0.22, 1), Vector2(0.36, 0.6), Vector2(0.58, 0.6), Vector2(0.7, 1.4), Vector2(0.88, 1.4), Vector2(1, 1)],
		"dense": [Vector3(130, 210, 3.0)],
		"corridors": 4, "kickers": 2, "rails": 2, "rollers": 1, "gullies": 1, "ridges": 3, "gap_gates": 1, "chokes": 1,
		"mix": {"tree": 4, "rock": 3, "log": 1}})
	# Tier 2: busier, a boulder or two.
	out.append({"file": "land_forest", "length": 360.0, "difficulty": 2, "seed": 37, "noise": 2.4,
		"heading": [Vector2(0, 0), Vector2(0.12, 0), Vector2(0.42, -20), Vector2(0.78, 15), Vector2(1, 0)],
		"profile": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.28, 0.55), Vector2(0.7, 0.55), Vector2(0.84, 1.3), Vector2(0.95, 1), Vector2(1, 1)],
		"dense": [Vector3(100, 250, 3.0)],
		"corridors": 4, "kickers": 2, "rails": 2, "rollers": 2, "gullies": 1, "ridges": 1, "boulders": 1, "gap_gates": 2, "chokes": 2,
		"mix": {"tree": 8, "log": 2, "fence": 1}, "tight": true})
	out.append({"file": "land_boulders", "length": 360.0, "difficulty": 2, "seed": 41, "noise": 2.8,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.85, -25), Vector2(1, -25)],
		"profile": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.28, 1.45), Vector2(0.44, 1.45), Vector2(0.56, 0.6), Vector2(0.8, 0.6), Vector2(0.92, 1), Vector2(1, 1)],
		"dense": [Vector3(200, 290, 3.0)],
		"corridors": 4, "kickers": 3, "rails": 2, "rollers": 1, "gullies": 2, "ridges": 1, "boulders": 2, "gap_gates": 2, "chokes": 2,
		"mix": {"rock": 6, "tree": 2}})
	out.append({"file": "land_gorge", "length": 380.0, "difficulty": 2, "seed": 53, "noise": 2.6,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.45, 28), Vector2(0.8, -8), Vector2(1, 0)],
		"width": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.35, 0.62), Vector2(0.75, 0.62), Vector2(0.92, 1), Vector2(1, 1)],
		"profile": [Vector2(0, 1), Vector2(0.2, 1), Vector2(0.34, 1.35), Vector2(0.74, 1.35), Vector2(0.9, 1), Vector2(1, 1)],
		"corridors": 3, "kickers": 2, "rails": 2, "rollers": 2, "gullies": 1, "ridges": 0, "gap_gates": 1, "chokes": 1,
		"mix": {"rock": 4, "tree": 4, "log": 1}, "tight": true})
	# Tier 3: dense obstacles and sharp bends.
	out.append({"file": "land_slalom", "length": 360.0, "difficulty": 3, "seed": 67, "noise": 2.4,
		"heading": [Vector2(0, 0), Vector2(0.15, 0), Vector2(0.5, 18), Vector2(0.85, 0), Vector2(1, 0)],
		"profile": [Vector2(0, 1), Vector2(0.12, 1), Vector2(0.25, 0.6), Vector2(0.8, 0.6), Vector2(0.92, 1), Vector2(1, 1)],
		"dense": [Vector3(90, 290, 2.0)],
		"corridors": 4, "kickers": 2, "rails": 2, "rollers": 1, "gullies": 0, "ridges": 1, "boulders": 1, "gap_gates": 3, "chokes": 3,
		"mix": {"tree": 9, "fence": 2}, "tight": true})
	out.append({"file": "land_fast_s", "length": 360.0, "difficulty": 3, "seed": 71, "noise": 2.2,
		"heading": [Vector2(0, 0), Vector2(0.1, 0), Vector2(0.38, 36), Vector2(0.7, -12), Vector2(0.9, 0), Vector2(1, 0)],
		"width": [Vector2(0, 1), Vector2(0.1, 1), Vector2(0.3, 0.66), Vector2(0.78, 0.66), Vector2(0.92, 1), Vector2(1, 1)],
		"profile": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.3, 1.3), Vector2(0.84, 1.3), Vector2(1, 1)],
		"corridors": 3, "kickers": 1, "rails": 2, "rollers": 2, "gullies": 1, "ridges": 0, "gap_gates": 1, "chokes": 1,
		"mix": {"tree": 5, "rock": 3}, "tight": true})
	for side: float in [1.0, -1.0]:
		out.append({"file": "land_switchback_left" if side > 0.0 else "land_switchback_right", "length": 380.0,
			"difficulty": 3, "seed": 79 if side > 0.0 else 83, "noise": 2.2,
			"heading": [Vector2(0, 0), Vector2(0.18, 0), Vector2(0.78, 80 * side), Vector2(1, 80 * side)],
			"width": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.32, 0.58), Vector2(0.72, 0.58), Vector2(0.9, 1), Vector2(1, 1)],
			"profile": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.3, 0.65), Vector2(0.78, 0.65), Vector2(0.9, 1), Vector2(1, 1)],
			"dense": [Vector3(110, 300, 2.0)],
			"corridors": 3, "kickers": 1, "rails": 2, "rollers": 1, "gullies": 1, "ridges": 0, "boulders": 1, "gap_gates": 2, "chokes": 2,
			"mix": {"rock": 4, "tree": 5}, "tight": true})
	out.append({"file": "land_finish", "length": 300.0, "difficulty": 1, "seed": 7, "noise": 1.5,
		"profile": [Vector2(0.0, 1.0), Vector2(0.3, 1.0), Vector2(0.6, 0.3), Vector2(1.0, 0.25)],
		"finish": 150.0, "corridors": 1, "wander": 0.0, "clusters": 1.0})
	out.append_array(set_pieces())
	return out


## Set pieces (v0.9): one big moment each, laid out by hand (fixed key
## points, no random features; only filler obstacles are scattered). The
## StageBuilder puts 1-2 of them in every stage.
static func set_pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# The cliff: an 8 deg run-up to the lip, a 60 deg face, a long 41 deg
	# landing that eases back to 23. ~2-3 s of air at speed. Gate high in the
	# air for a fast, straight launch.
	out.append({"file": "set_cliff", "length": 420.0, "difficulty": 2, "seed": 101, "noise": 1.6,
		"profile": [Vector2(0, 1), Vector2(0.14, 1), Vector2(0.26, 0.35), Vector2(0.325, 0.35), Vector2(0.336, 2.6),
			Vector2(0.36, 2.6), Vector2(0.376, 1.8), Vector2(0.66, 1.8), Vector2(0.82, 1), Vector2(1, 1)],
		"paths": [[Vector2(-30, 0), Vector2(-30, 420)], [Vector2(0, 0), Vector2(0, 420)], [Vector2(30, 0), Vector2(30, 420)]],
		"clear": [Vector2(95, 300)], "gates_at": [Vector3(0, 172, 24)],
		"clusters": 4.0, "mix": {"tree": 5, "rock": 3}})
	# The ravine: a 10 m deep gully across most of the valley. Jump it off
	# the steep kicker on the left (lip ~18 deg) or take the slower way round
	# through the trees on the right. Falling in is rideable, just slow.
	out.append({"file": "set_ravine", "length": 400.0, "difficulty": 2, "seed": 103, "noise": 1.8,
		"gullies_at": [{"name": "Ravine", "points": [Vector2(-82, 215), Vector2(30, 215)], "width": 44.0, "depth": 10.0, "flat": 0.2}],
		"kickers_at": [{"name": "RavineKickerPad", "at": Vector2(-24, 168), "aim": Vector2(-24, 260), "scale": Vector3(1.2, 1.9, 1.0), "gate_ahead": 44.0, "gate_up": 13.0}],
		"paths": [[Vector2(0, 0), Vector2(-20, 80), Vector2(-24, 130), Vector2(-24, 320), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(10, 60), Vector2(55, 170), Vector2(57, 262), Vector2(20, 335), Vector2(0, 400)]],
		"keep_out": [Vector3(-60, 215, 26), Vector3(-25, 215, 26), Vector3(10, 215, 26)],
		"clusters_at": [{"kind": "tree", "at": Vector2(44, 190), "n": 8, "spread": 8.0}, {"kind": "tree", "at": Vector2(66, 220), "n": 8, "spread": 7.0},
			{"kind": "tree", "at": Vector2(45, 248), "n": 8, "spread": 8.0}, {"kind": "rock", "at": Vector2(30, 160), "n": 4, "spread": 6.0}],
		"gap_gates": 1, "clusters": 3.0, "mix": {"tree": 5, "rock": 2}})
	# The bend kicker: the valley swings 55 deg left; a big kicker on the
	# outside throws you across the inside of the bend, or ride around it.
	out.append({"file": "set_bend_kicker", "length": 400.0, "difficulty": 3, "seed": 107, "noise": 1.8,
		"heading": [Vector2(0, 0), Vector2(0.2, 0), Vector2(0.78, 55), Vector2(1, 55)],
		"width": [Vector2(0, 1), Vector2(0.18, 1), Vector2(0.35, 0.78), Vector2(0.72, 0.78), Vector2(0.9, 1), Vector2(1, 1)],
		"kickers_at": [{"name": "BendKickerPad", "at": Vector2(24, 122), "aim": Vector2(-10, 205), "scale": Vector3(1.5, 1.7, 1.0), "gate_ahead": 32.0, "gate_up": 6.0}],
		"paths": [[Vector2(0, 0), Vector2(18, 60), Vector2(36, 92), Vector2(24, 122), Vector2(-10, 205), Vector2(-6, 290), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(-15, 90), Vector2(-28, 180), Vector2(-20, 280), Vector2(0, 400)]],
		"clusters_at": [{"kind": "rock", "at": Vector2(-44, 150), "n": 5, "spread": 8.0}, {"kind": "tree", "at": Vector2(40, 210), "n": 8, "spread": 9.0}],
		"gap_gates": 1, "clusters": 5.0, "mix": {"tree": 5, "rock": 3}, "tight": true})
	# v0.9.1 set pieces.
	# The rail gap: a rail on the left whose last 16 m kicks up to 3 m high,
	# launching you over a gully (through a gate); or go round on the right.
	out.append({"file": "set_rail_gap", "length": 400.0, "difficulty": 2, "seed": 109, "noise": 1.6,
		"rails_at": [{"name": "LaunchRail", "points": [Vector3(-22, 150, 0.75), Vector3(-22, 196, 0.75), Vector3(-22, 212, 3.0)]}],
		"gullies_at": [{"name": "Gap", "points": [Vector2(-82, 236), Vector2(18, 236)], "width": 30.0, "depth": 8.0, "flat": 0.2}],
		"gates_at": [Vector3(-22, 234, 12.0)],
		"keep_out": [Vector3(-60, 236, 18), Vector3(-30, 236, 18), Vector3(0, 236, 18)],
		"paths": [[Vector2(0, 0), Vector2(-15, 80), Vector2(-22, 130), Vector2(-22, 320), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(20, 90), Vector2(45, 180), Vector2(48, 280), Vector2(15, 350), Vector2(0, 400)]],
		"clusters_at": [{"kind": "tree", "at": Vector2(52, 215), "n": 8, "spread": 9.0}, {"kind": "tree", "at": Vector2(38, 260), "n": 7, "spread": 8.0}],
		"gap_gates": 1, "clusters": 3.5, "mix": {"tree": 5, "rock": 2}})
	# The canyon slot: the valley pinches to a 50 m slot (a ~19 m floor
	# between the banks) that kinks left and right, rocks at its edges.
	out.append({"file": "set_canyon_slot", "length": 380.0, "difficulty": 3, "seed": 113, "noise": 1.4,
		"heading": [Vector2(0, 0), Vector2(0.3, 0), Vector2(0.48, 22), Vector2(0.66, -10), Vector2(0.85, 0), Vector2(1, 0)],
		"width": [Vector2(0, 1), Vector2(0.18, 1), Vector2(0.34, 0.34), Vector2(0.72, 0.34), Vector2(0.88, 1), Vector2(1, 1)],
		"paths": [[Vector2(0, 0), Vector2(0, 380)]],
		"clusters_at": [{"kind": "rock", "at": Vector2(-9, 150), "n": 2, "spread": 3.0}, {"kind": "rock", "at": Vector2(9, 185), "n": 2, "spread": 3.0},
			{"kind": "rock", "at": Vector2(-9, 220), "n": 2, "spread": 3.0}, {"kind": "rock", "at": Vector2(9, 250), "n": 2, "spread": 3.0}],
		"gates_at": [Vector3(0, 200, 2.4)],
		"clusters": 3.0, "mix": {"tree": 4, "rock": 4}, "tight": true})
	# The fork: a raised causeway on the left (6 m up, steep sides, gates on
	# top: fall off and you lose the line) or the low sunken line on the right
	# through the rock walls.
	out.append({"file": "set_fork", "length": 400.0, "difficulty": 2, "seed": 127, "noise": 1.6,
		"lines_at": [{"name": "Causeway", "points": [Vector3(-28, 70, 0), Vector3(-28, 125, 6), Vector3(-28, 280, 6), Vector3(-28, 325, 0)], "width": 16.0, "flat": 0.45}],
		"gullies_at": [{"name": "LowLine", "points": [Vector2(30, 80), Vector2(30, 320)], "width": 18.0, "depth": 3.0, "flat": 0.4}],
		"gates_at": [Vector3(-28, 165, 2.2), Vector3(-28, 225, 2.2), Vector3(-28, 270, 2.2)],
		"paths": [[Vector2(0, 0), Vector2(-15, 45), Vector2(-28, 90), Vector2(-28, 305), Vector2(-10, 350), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(20, 55), Vector2(30, 100), Vector2(30, 300), Vector2(10, 355), Vector2(0, 400)]],
		"chokes": 2, "dense": [Vector3(130, 290, 3.0)], "clusters": 4.0, "mix": {"tree": 5, "rock": 3}})
	# v0.16: one set piece per biome (featured in its stages, Biome set_pieces).
	# Meadow: the river crossing. A shallow river right across the valley
	# (ride through it, slowly) or jump it off one of two kickers.
	out.append({"file": "set_river_logs", "length": 400.0, "difficulty": 2, "seed": 131, "noise": 1.4,
		"gullies_at": [{"name": "River", "points": [Vector2(-72, 222), Vector2(72, 222)], "width": 22.0, "depth": 3.0, "flat": 0.5}],
		"kickers_at": [{"name": "WestKickerPad", "at": Vector2(-30, 178), "aim": Vector2(-30, 262), "scale": Vector3(1.0, 1.4, 1.0), "gate_ahead": 30.0, "gate_up": 7.0},
			{"name": "EastKickerPad", "at": Vector2(30, 182), "aim": Vector2(30, 262), "scale": Vector3(1.0, 1.4, 1.0), "gate_ahead": 30.0, "gate_up": 7.0}],
		"paths": [[Vector2(0, 0), Vector2(-20, 80), Vector2(-30, 140), Vector2(-30, 300), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(20, 80), Vector2(30, 140), Vector2(30, 300), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(0, 400)]],
		"keep_out": [Vector3(-45, 222, 16), Vector3(0, 222, 16), Vector3(45, 222, 16)],
		"clusters_at": [{"kind": "log", "at": Vector2(-12, 120), "n": 2, "spread": 4.0}, {"kind": "log", "at": Vector2(14, 135), "n": 2, "spread": 4.0},
			{"kind": "tree", "at": Vector2(-56, 240), "n": 6, "spread": 7.0}, {"kind": "tree", "at": Vector2(55, 205), "n": 6, "spread": 7.0}],
		"gap_gates": 1, "clusters": 3.0, "mix": {"tree": 5, "log": 3}})
	# Canyon: the mesa launch. A raised mesa on the left ends in a big kicker
	# over a dry wash; the low way round on the right weaves through rocks.
	out.append({"file": "set_mesa_launch", "length": 400.0, "difficulty": 2, "seed": 137, "noise": 1.6,
		"lines_at": [{"name": "Mesa", "points": [Vector3(-26, 60, 0), Vector3(-26, 110, 5), Vector3(-26, 186, 5)], "width": 18.0, "flat": 0.45}],
		"kickers_at": [{"name": "MesaKickerPad", "at": Vector2(-26, 190), "aim": Vector2(-26, 280), "scale": Vector3(1.3, 1.6, 1.0), "gate_ahead": 40.0, "gate_up": 11.0}],
		"gullies_at": [{"name": "Wash", "points": [Vector2(-72, 242), Vector2(8, 242)], "width": 30.0, "depth": 7.0, "flat": 0.25}],
		"keep_out": [Vector3(-50, 242, 20), Vector3(-22, 242, 20), Vector3(4, 242, 18)],
		"paths": [[Vector2(0, 0), Vector2(-18, 50), Vector2(-26, 100), Vector2(-26, 320), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(25, 80), Vector2(40, 200), Vector2(42, 290), Vector2(10, 360), Vector2(0, 400)]],
		"clusters_at": [{"kind": "rock", "at": Vector2(52, 250), "n": 5, "spread": 6.0}, {"kind": "rock", "at": Vector2(30, 150), "n": 4, "spread": 6.0}],
		"gap_gates": 1, "clusters": 3.0, "mix": {"rock": 5, "tree": 2}})
	# Snowline: the cornice. A short run-up to a lip, a 66 deg face, a long
	# steep landing, then a fast chute with a rock choke.
	out.append({"file": "set_cornice", "length": 400.0, "difficulty": 3, "seed": 139, "noise": 1.4,
		"profile": [Vector2(0, 1), Vector2(0.12, 1), Vector2(0.22, 0.3), Vector2(0.28, 0.3), Vector2(0.29, 2.9),
			Vector2(0.31, 2.9), Vector2(0.33, 1.9), Vector2(0.6, 1.9), Vector2(0.8, 1.45), Vector2(1, 1)],
		"paths": [[Vector2(-30, 0), Vector2(-30, 400)], [Vector2(0, 0), Vector2(0, 400)], [Vector2(30, 0), Vector2(30, 400)]],
		"clear": [Vector2(70, 260)], "gates_at": [Vector3(0, 150, 22)],
		"dense": [Vector3(270, 380, 2.5)], "chokes": 1, "clusters": 4.0, "mix": {"tree": 5, "rock": 3}})
	# Ash Quarry: the ramp yard. Three staggered kickers and two rails on a
	# gentle stretch: chain them for gates, or thread between.
	out.append({"file": "set_ramp_yard", "length": 400.0, "difficulty": 2, "seed": 149, "noise": 1.2,
		"kickers_at": [{"name": "YardKicker1Pad", "at": Vector2(-30, 90), "aim": Vector2(-30, 170), "scale": Vector3(1.1, 1.3, 1.0), "gate_ahead": 28.0, "gate_up": 6.0},
			{"name": "YardKicker2Pad", "at": Vector2(25, 150), "aim": Vector2(25, 230), "scale": Vector3(1.1, 1.3, 1.0), "gate_ahead": 28.0, "gate_up": 6.0},
			{"name": "YardKicker3Pad", "at": Vector2(-20, 255), "aim": Vector2(-20, 335), "scale": Vector3(1.2, 1.5, 1.0), "gate_ahead": 34.0, "gate_up": 8.0}],
		"rails_at": [{"name": "YardRail1", "points": [Vector3(-8, 95, 0.75), Vector3(-8, 150, 0.75)]},
			{"name": "YardRail2", "points": [Vector3(40, 262, 0.75), Vector3(40, 312, 0.75)]}],
		"paths": [[Vector2(0, 0), Vector2(-28, 50), Vector2(-30, 85), Vector2(-30, 200), Vector2(-20, 240), Vector2(-20, 330), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(22, 60), Vector2(25, 140), Vector2(25, 225), Vector2(40, 255), Vector2(40, 330), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(8, 60), Vector2(10, 340), Vector2(0, 400)]],
		"clusters": 3.0, "mix": {"rock": 4, "tree": 2, "fence": 1}})
	# v0.23: a second set piece per biome (later stages see more variety).
	# Meadow: the log rhythm. Low log piles every ~45 m, alternating sides,
	# on a long roller section: weave the gaps or hop the rhythm for gates.
	out.append({"file": "set_log_rhythm", "length": 400.0, "difficulty": 2, "seed": 151, "noise": 1.2,
		"rollers": 3,
		"paths": [[Vector2(0, 0), Vector2(-25, 60), Vector2(-25, 340), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(25, 60), Vector2(25, 340), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(0, 400)]],
		"clusters_at": [{"kind": "log", "at": Vector2(-12, 100), "n": 2, "spread": 3.0}, {"kind": "log", "at": Vector2(12, 145), "n": 2, "spread": 3.0},
			{"kind": "log", "at": Vector2(-12, 190), "n": 2, "spread": 3.0}, {"kind": "log", "at": Vector2(12, 235), "n": 2, "spread": 3.0},
			{"kind": "log", "at": Vector2(-12, 280), "n": 2, "spread": 3.0},
			{"kind": "tree", "at": Vector2(-50, 170), "n": 6, "spread": 7.0}, {"kind": "tree", "at": Vector2(50, 260), "n": 6, "spread": 7.0}],
		"gap_gates": 2, "clusters": 2.5, "mix": {"tree": 5, "log": 3}})
	# Canyon: the narrows. The valley pinches twice (to 45% and 40%) with a
	# kink between; a kicker in the first pinch hops a shallow wash.
	out.append({"file": "set_narrows", "length": 400.0, "difficulty": 3, "seed": 157, "noise": 1.4,
		"heading": [Vector2(0, 0), Vector2(0.25, 0), Vector2(0.5, 18), Vector2(0.75, -6), Vector2(1, 0)],
		"width": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.3, 0.45), Vector2(0.42, 0.45), Vector2(0.55, 0.8),
			Vector2(0.68, 0.4), Vector2(0.8, 0.4), Vector2(0.92, 1), Vector2(1, 1)],
		"gullies_at": [{"name": "Wash", "points": [Vector2(-30, 160), Vector2(30, 160)], "width": 12.0, "depth": 2.5, "flat": 0.4}],
		"kickers_at": [{"name": "NarrowsKickerPad", "at": Vector2(-8, 132), "aim": Vector2(-8, 200), "scale": Vector3(0.9, 1.2, 1.0), "gate_ahead": 22.0, "gate_up": 5.0}],
		"paths": [[Vector2(0, 0), Vector2(-8, 100), Vector2(-8, 200), Vector2(0, 300), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(8, 100), Vector2(10, 200), Vector2(4, 300), Vector2(0, 400)]],
		"clusters_at": [{"kind": "rock", "at": Vector2(14, 280), "n": 2, "spread": 3.0}, {"kind": "rock", "at": Vector2(-14, 300), "n": 2, "spread": 3.0}],
		"clusters": 3.0, "mix": {"rock": 5, "tree": 2}, "tight": true})
	# Snowline: the ice chute. A long steep fast drop over rollers with two
	# rock chokes: pick a gap at full speed.
	out.append({"file": "set_ice_chute", "length": 420.0, "difficulty": 3, "seed": 163, "noise": 1.0,
		"profile": [Vector2(0, 1), Vector2(0.15, 1), Vector2(0.25, 1.5), Vector2(0.8, 1.5), Vector2(0.9, 1), Vector2(1, 1)],
		"rollers": 3,
		"paths": [[Vector2(-30, 0), Vector2(-30, 420)], [Vector2(0, 0), Vector2(0, 420)], [Vector2(30, 0), Vector2(30, 420)]],
		"dense": [Vector3(150, 330, 3.0)], "chokes": 2, "gap_gates": 2, "clusters": 3.5, "mix": {"tree": 5, "rock": 3}})
	# Ash Quarry: the bridge gap. Two raised ramps on the left with a gap
	# between them (jump it for the gate) over a cut; or the low road. The cut
	# is wide with gentle sides (5 m deep over ~13 m): come up short and you
	# ride out of it, slower.
	out.append({"file": "set_bridge_gap", "length": 400.0, "difficulty": 2, "seed": 167, "noise": 1.2,
		"lines_at": [{"name": "BridgeIn", "points": [Vector3(-26, 70, 0), Vector3(-26, 140, 5), Vector3(-26, 196, 6)], "width": 14.0, "flat": 0.45},
			{"name": "BridgeOut", "points": [Vector3(-26, 236, 3), Vector3(-26, 290, 2), Vector3(-26, 330, 0)], "width": 14.0, "flat": 0.45}],
		"gullies_at": [{"name": "Cut", "points": [Vector2(-70, 216), Vector2(0, 216)], "width": 38.0, "depth": 5.0, "flat": 0.3}],
		"gates_at": [Vector3(-26, 216, 9.0)],
		"keep_out": [Vector3(-50, 216, 18), Vector3(-22, 216, 18)],
		"paths": [[Vector2(0, 0), Vector2(-18, 50), Vector2(-26, 100), Vector2(-26, 320), Vector2(0, 400)],
			[Vector2(0, 0), Vector2(25, 80), Vector2(35, 200), Vector2(35, 290), Vector2(10, 360), Vector2(0, 400)]],
		"clusters_at": [{"kind": "rock", "at": Vector2(45, 150), "n": 4, "spread": 5.0}, {"kind": "rock", "at": Vector2(50, 260), "n": 4, "spread": 5.0}],
		"clusters": 3.0, "mix": {"rock": 4, "tree": 2, "fence": 1}})
	return out

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var overwrite: bool = args.has("--overwrite")
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute("res://chunks/landscape")
	for spec: Dictionary in specs():
		var file: String = String(spec["file"])
		if not only.is_empty() and file != only:
			continue
		var path: String = "res://chunks/landscape/%s.tscn" % file
		if FileAccess.file_exists(path) and not overwrite:
			print("%s: exists, skipped (pass -- --overwrite to regenerate; that loses hand edits)" % file)
			continue
		await _author(spec, path)
	quit()


func _author(spec: Dictionary, path: String) -> void:
	_rng.seed = int(spec["seed"])
	var length: float = spec["length"]
	var tier: int = spec["difficulty"]

	var root: Chunk = Chunk.new()
	root.name = String(spec["file"]).to_pascal_case()
	root.length = length
	root.difficulty = tier
	var terrain: TerrainPatch = TerrainPatch.new()
	terrain.name = "Terrain"
	terrain.width = WIDTH
	terrain.length = length
	terrain.outside_width = OUTSIDE_WIDTH
	terrain.outside_drop = OUTSIDE_DROP
	terrain.noise_seed = int(spec["seed"])
	terrain.noise_amplitude = spec.get("noise", 2.0)
	terrain.slope_profile = _curve(spec.get("profile", []), 0.0, 3.5)
	terrain.heading_curve = _curve(spec.get("heading", []), -120.0, 120.0)
	terrain.width_profile = _curve(spec.get("width", []), 0.0, 1.5)
	_add(root, root, terrain)
	var props: Node3D = Node3D.new()
	props.name = "Props"
	_add(root, terrain, props)
	var track: Path3D = Path3D.new()
	track.name = "TrackLine"
	track.curve = Curve3D.new()
	track.curve.add_point(Vector3.ZERO)
	track.curve.add_point(Vector3(0, 0, -1))
	_add(root, root, track)
	for marker: String in ["Entry", "Exit"]:
		var m: Marker3D = Marker3D.new()
		m.name = marker
		_add(root, root, m)
	get_root().add_child(root)
	await process_frame

	# --- Invisible corridors (valley x at each d), kept clear of obstacles.
	var clear: float = CLEAR[tier]
	var corridors: Array[PackedVector2Array] = []
	var count: int = spec.get("corridors", 3)
	var wander: float = spec.get("wander", WANDER[tier])
	if spec.has("paths"):
		# Set pieces: the open ways through are drawn by hand (key points).
		for keys: Array in spec["paths"]:
			corridors.append(_path_from_keys(keys, length))
	else:
		for i: int in count:
			corridors.append(_make_corridor(terrain, i, count, wander, length))

	# --- Features: (valley x, d, radius) footprints, so they don't overlap.
	var taken: Array[Vector3] = []
	for k3: Vector3 in spec.get("keep_out", []):
		taken.append(k3)
	var shapes: Node3D = terrain
	for i: int in int(spec.get("gullies", 0)):
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var d0: float = _rng.randf_range(END_CLEAR + 10.0, length - END_CLEAR - 130.0)
		var gully: TerrainShape = _shape_along(terrain, c, d0, d0 + _rng.randf_range(80.0, 130.0), TerrainShape.Mode.GULLY, 14.0, _rng.randf_range(2.5, 3.5), 0.3, 0.0)
		gully.name = "Gully%d" % (i + 1)
		_add(root, shapes, gully)
	for i: int in int(spec.get("ridges", 0)):
		# A rideable hump somewhere between the corridors.
		var x: float = _rng.randf_range(-45.0, 45.0)
		var d0: float = _rng.randf_range(END_CLEAR + 10.0, length - END_CLEAR - 110.0)
		var line: PackedVector2Array = PackedVector2Array()
		for k: int in 6:
			var d: float = d0 + k * 18.0
			line.append(Vector2(_scale_x(terrain, x, d) + _rng.randf_range(-4.0, 4.0), d))
		var ridge: TerrainShape = _shape_from(terrain, line, TerrainShape.Mode.RIDGE, _rng.randf_range(24.0, 32.0), _rng.randf_range(2.5, 3.5), 0.15)
		ridge.name = "Ridge%d" % (i + 1)
		_add(root, shapes, ridge)
	var roller_index: int = 0
	for i: int in int(spec.get("rollers", 0)):
		# Two or three rollers across a corridor, 24 m apart.
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var d0: float = _free_d(c, taken, 70.0, length)
		if d0 < 0.0:
			continue
		for k: int in _rng.randi_range(2, 3):
			var d: float = d0 + k * 24.0
			var x: float = _corridor_x(c, d)
			var tan: Vector2 = _corridor_tangent(c, d)
			var across: Vector2 = Vector2(tan.y, -tan.x)
			var line: PackedVector2Array = PackedVector2Array([Vector2(x, d) - across * 10.0, Vector2(x, d) + across * 10.0])
			var roller: TerrainShape = _shape_from(terrain, line, TerrainShape.Mode.RIDGE, 12.0, 1.3, 0.0)
			roller_index += 1
			roller.name = "Roller%d" % roller_index
			_add(root, shapes, roller)
		taken.append(Vector3(_corridor_x(c, d0 + 30.0), d0 + 30.0, 40.0))
	var rails: Array[Dictionary] = []
	for i: int in int(spec.get("rails", 0)):
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var span: float = _rng.randf_range(50.0, 70.0)
		# Straight ground under it and 40 m past its end: off the end you fly
		# straight on, so the valley mustn't bend away there.
		var d0: float = _free_d(c, taken, span + 25.0, length, terrain, 10.0)
		if d0 < 0.0:
			continue
		# Smooth ground under the rail (LINE on the plain slope), rail on top later.
		var bed: TerrainShape = _shape_along(terrain, c, d0 - 6.0, d0 + span + 6.0, TerrainShape.Mode.LINE, 9.0, 0.0, 0.45, 0.0)
		bed.name = "RailBed%d" % (i + 1)
		_add(root, shapes, bed)
		rails.append({"corridor": c, "d0": d0, "d1": d0 + span})
		taken.append(Vector3(_corridor_x(c, d0 + span * 0.5), d0 + span * 0.5, span * 0.5 + 6.0))
		# Keep the straight run-out past the end clear: you fly off it.
		var end2: Vector2 = Vector2(_corridor_x(c, d0 + span), d0 + span)
		var out_dir: Vector2 = _corridor_tangent(c, d0 + span)
		for k2: int in range(1, 6):
			var q: Vector2 = end2 + out_dir * 10.0 * k2
			taken.append(Vector3(q.x, q.y, 9.0))
	var pads: Array[TerrainFlatten] = []
	## Kicker spots for the air gates: valley point, direction, gate distance / height.
	var kicks: Array[Dictionary] = []
	var hand_rails: Array[Dictionary] = []
	for i: int in int(spec.get("kickers", 0)):
		var c: PackedVector2Array = corridors[_rng.randi() % corridors.size()]
		var d: float = _free_d(c, taken, 40.0, length, terrain, 5.0)
		if d < 0.0:
			continue
		d += 20.0
		var pad: TerrainFlatten = TerrainFlatten.new()
		pad.name = "KickerPad%d" % (i + 1)
		pad.size = Vector2(12.0, 36.0)
		pad.blend = 6.0
		pad.transform = _pad_transform(terrain, Vector2(_corridor_x(c, d), d), _corridor_tangent(c, d))
		_add(root, shapes, pad)
		var kicker: Node3D = KICKER.instantiate() as Node3D
		kicker.name = "Kicker"
		kicker.scale = Vector3.ONE * KICK_SCALE[tier]
		_add(root, pad, kicker)
		pads.append(pad)
		taken.append(Vector3(_corridor_x(c, d), d, 22.0))
		kicks.append({"p": Vector2(_corridor_x(c, d), d), "dir": _corridor_tangent(c, d), "ahead": 16.0, "up": 2.8})
	# Set pieces: explicit gullies (e.g. a ravine across the valley) and
	# kickers aimed at a point (e.g. across a bend or over the ravine).
	for g: Dictionary in spec.get("gullies_at", []):
		var gully2: TerrainShape = _shape_from(terrain, PackedVector2Array(g["points"]), TerrainShape.Mode.GULLY, g["width"], g["depth"], g.get("flat", 0.3))
		gully2.name = String(g.get("name", "Gully"))
		_add(root, shapes, gully2)
	for l2: Dictionary in spec.get("lines_at", []):
		var pts4: Array = l2["points"]
		var line4: PackedVector2Array = PackedVector2Array()
		var d4: float = (pts4[0] as Vector3).y
		var dend: float = (pts4[-1] as Vector3).y
		var shape4: TerrainShape = TerrainShape.new()
		shape4.name = String(l2.get("name", "Line"))
		shape4.mode = TerrainShape.Mode.LINE
		shape4.width = l2.get("width", 12.0)
		shape4.flat = l2.get("flat", 0.45)
		shape4.curve = Curve3D.new()
		while d4 <= dend + 0.01:
			# Height above the plain slope, eased between the key points.
			var h4: float = 0.0
			var x4: float = (pts4[0] as Vector3).x
			for i4: int in range(1, pts4.size()):
				var a4: Vector3 = pts4[i4 - 1]
				var b4: Vector3 = pts4[i4]
				if d4 <= b4.y:
					var f4: float = clampf((d4 - a4.y) / maxf(b4.y - a4.y, 0.001), 0.0, 1.0)
					f4 = f4 * f4 * (3.0 - 2.0 * f4)
					h4 = lerpf(a4.z, b4.z, f4)
					x4 = lerpf(a4.x, b4.x, f4)
					break
			shape4.curve.add_point(terrain.valley_to_local(x4, terrain.base_height(x4, -d4) + h4, d4))
			d4 += 2.5
		_add(root, shapes, shape4)
	for r2: Dictionary in spec.get("ridges_at", []):
		var ridge2: TerrainShape = _shape_from(terrain, PackedVector2Array(r2["points"]), TerrainShape.Mode.RIDGE, r2["width"], r2["depth"], r2.get("flat", 0.3))
		ridge2.name = String(r2.get("name", "Ridge"))
		_add(root, shapes, ridge2)
	# Hand-placed rails: Vector3(x, d, height above the ground) key points,
	# smoothed ground under them, a gate after the end if asked.
	for rr: Dictionary in spec.get("rails_at", []):
		var keys: Array = rr["points"]
		var line2: PackedVector2Array = PackedVector2Array()
		for kp: Vector3 in keys:
			line2.append(Vector2(kp.x, kp.y))
		var bed2: TerrainShape = _shape_from(terrain, line2, TerrainShape.Mode.LINE, 9.0, 0.0, 0.45)
		bed2.name = String(rr.get("name", "Rail")) + "Bed"
		_add(root, shapes, bed2)
		hand_rails.append(rr)
		for kp: Vector3 in keys:
			taken.append(Vector3(kp.x, kp.y, 8.0))
	for k: Dictionary in spec.get("kickers_at", []):
		var p: Vector2 = k["at"]
		var dir: Vector2 = ((k["aim"] as Vector2) - p).normalized()
		var pad2: TerrainFlatten = TerrainFlatten.new()
		pad2.name = String(k.get("name", "BigKickerPad"))
		pad2.size = Vector2(16.0, 44.0)
		pad2.blend = 8.0
		pad2.transform = _pad_transform(terrain, p, dir)
		_add(root, shapes, pad2)
		var big: Node3D = KICKER.instantiate() as Node3D
		big.name = "Kicker"
		big.scale = k.get("scale", Vector3.ONE)
		_add(root, pad2, big)
		taken.append(Vector3(p.x, p.y, 26.0))
		kicks.append({"p": p, "dir": dir, "ahead": float(k.get("gate_ahead", 22.0)), "up": float(k.get("gate_up", 4.0))})
	if spec.has("pad"):
		var p4: Vector4 = spec["pad"]
		var start_pad: TerrainFlatten = TerrainFlatten.new()
		start_pad.name = "StartPad"
		start_pad.size = Vector2(p4.z, p4.w)
		start_pad.blend = 10.0
		start_pad.position = Vector3(p4.x, 0.0, -p4.y)
		_add(root, shapes, start_pad)
	terrain.rebuild()

	# --- Rails on the smoothed ground (points every 4 m, following the corridor).
	for i: int in rails.size():
		var r: Dictionary = rails[i]
		var rail: Path3D = RAIL.instantiate() as Path3D
		rail.name = "Rail%d" % (i + 1)
		rail.curve = Curve3D.new()
		var d: float = r["d0"]
		while d <= float(r["d1"]) + 0.01:
			var x: float = _corridor_x(r["corridor"], d)
			rail.curve.add_point(terrain.valley_to_local(x, terrain.surface_height(x, -d) + RAIL_HEIGHT, d))
			d += 4.0
		_add(root, root, rail)

	# --- Hand-placed rails (set pieces), heights from the built ground.
	for rr2: Dictionary in hand_rails:
		var rail2: Path3D = RAIL.instantiate() as Path3D
		rail2.name = String(rr2.get("name", "Rail"))
		rail2.curve = Curve3D.new()
		var keys2: Array = rr2["points"]
		for i: int in keys2.size() - 1:
			var a3: Vector3 = keys2[i]
			var b3: Vector3 = keys2[i + 1]
			var steps: int = maxi(1, ceili(Vector2(b3.x - a3.x, b3.y - a3.y).length() / 4.0))
			for st: int in steps + (1 if i == keys2.size() - 2 else 0):
				var f3: float = float(st) / steps
				var p3: Vector3 = a3.lerp(b3, f3)
				rail2.curve.add_point(terrain.valley_to_local(p3.x, terrain.surface_height(p3.x, -p3.y) + p3.z, p3.y))
		_add(root, root, rail2)

	# --- Boost gates on the risky options: in the air off kickers, just past
	# rail ends, in narrow two-tree gaps off the safe ways, and set-piece ones.
	var gates: Node3D = Node3D.new()
	gates.name = "Gates"
	_add(root, root, gates)
	var placed: Array[Vector3] = []
	for k: Dictionary in kicks:
		var at: Vector2 = (k["p"] as Vector2) + (k["dir"] as Vector2) * float(k["ahead"])
		_gate(root, gates, terrain, at, k["dir"], float(k["up"]))
	for r: Dictionary in rails:
		var d_end: float = float(r["d1"]) + 8.0
		_gate(root, gates, terrain, Vector2(_corridor_x(r["corridor"], d_end), d_end), _corridor_tangent(r["corridor"], d_end), 1.8)
	for g3: Vector3 in spec.get("gates_at", []):
		_gate(root, gates, terrain, Vector2(g3.x, g3.y), Vector2(0, 1), g3.z, 4.5)
	for i: int in int(spec.get("gap_gates", 0)):
		# Two trees close together with a gate between them, away from the
		# open ways: the risky shortcut.
		for attempt: int in 40:
			var d: float = _rng.randf_range(END_CLEAR + 15.0, length - END_CLEAR - 15.0)
			var half: float = terrain.half_play_at(d)
			var x: float = _rng.randf_range(-half + 12.0, half - 12.0)
			var ok: bool = not _in_clear(spec, d)
			for c: PackedVector2Array in corridors:
				if absf(_corridor_x(c, d) - x) < clear + 7.0:
					ok = false
			for t: Vector3 in taken:
				if Vector2(x, d).distance_to(Vector2(t.x, t.y)) < t.z + 10.0:
					ok = false
			if not ok:
				continue
			for side: float in [-1.0, 1.0]:
				var tx: float = x + side * 3.6
				var tree: Node3D = TREE.instantiate() as Node3D
				tree.name = "GapTree%d" % (props.get_child_count() + 1)
				tree.position = terrain.valley_to_local(tx, terrain.surface_height(tx, -d), d)
				_add(root, props, tree)
				placed.append(Vector3(tx, d, RADIUS["tree"]))
			_gate(root, gates, terrain, Vector2(x, d), Vector2(0, 1), 2.6, 2.4)
			taken.append(Vector3(x, d, 4.0))
			break

	# --- Chokepoints: a wall of rocks right across the valley, open only
	# where the corridors pass: pick a gap. Placed in the dense stretches.
	for i: int in int(spec.get("chokes", 0)):
		var d_c: float = _pick_d(spec, length)
		if _in_clear(spec, d_c):
			continue
		var half_c: float = terrain.half_play_at(d_c) - 2.0
		var xc: float = -half_c
		while xc <= half_c:
			var ok_c: bool = true
			for c: PackedVector2Array in corridors:
				if absf(_corridor_x(c, d_c) - xc) < clear + 3.0:
					ok_c = false
			for t: Vector3 in taken:
				if Vector2(xc, d_c).distance_to(Vector2(t.x, t.y)) < t.z + 4.0:
					ok_c = false
			if ok_c:
				var rock: Node3D = ROCK.instantiate() as Node3D
				rock.name = "ChokeRock%d" % (props.get_child_count() + 1)
				rock.position = terrain.valley_to_local(xc, terrain.surface_height(xc, -d_c), d_c)
				rock.rotation.y = _rng.randf() * TAU
				rock.scale = Vector3.ONE * _rng.randf_range(1.3, 1.8)
				_add(root, props, rock)
				placed.append(Vector3(xc, d_c, RADIUS["rock"] * rock.scale.x))
			xc += 4.2

	# --- Obstacle clusters, off the corridors and features (more of them in
	# the spec's "dense" stretches); set pieces also place some by hand.
	for cl: Dictionary in spec.get("clusters_at", []):
		_cluster(root, props, terrain, cl["kind"], corridors, clear, taken, placed, length, spec, cl["at"], int(cl.get("n", 6)), float(cl.get("spread", 9.0)))
	var area: float = 0.0
	for k: int in 20:
		area += terrain.half_play_at(length * (k + 0.5) / 20.0) * 2.0 * length / 20.0
	var clusters: int = int(area / 10000.0 * float(spec.get("clusters", CLUSTERS[tier])))
	var mix: Dictionary = spec.get("mix", {"tree": 4, "rock": 1})
	for i: int in clusters:
		_cluster(root, props, terrain, _pick(mix), corridors, clear, taken, placed, length, spec)

	# --- Boulders: roll across the valley from one side.
	for i: int in int(spec.get("boulders", 0)):
		var d: float = _rng.randf_range(length * 0.3, length * 0.7)
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var half: float = terrain.half_play_at(d)
		# Up on the crest, so it sits clear of the open ground until it rolls.
		var start: Vector3 = terrain.valley_to_local(side * (half + 3.0), 0.0, d)
		var end: Vector3 = terrain.valley_to_local(-side * (half * 0.35), 0.0, d + 25.0)
		var boulder: RollingBoulder = BOULDER.instantiate() as RollingBoulder
		boulder.name = "Boulder%d" % (i + 1)
		boulder.position = Vector3(start.x, terrain.height_at_local(start) + 2.2, start.z)
		boulder.roll_to = Vector3(end.x - start.x, 0.0, end.z - start.z)
		_add(root, root, boulder)

	# --- Invisible corridors as RideLines (respawn, autopilot, tests).
	var lines: Node3D = Node3D.new()
	lines.name = "Lines"
	_add(root, root, lines)
	for i: int in corridors.size():
		var line: RideLine = RideLine.new()
		line.name = "Path%d" % (i + 1)
		line.curve = Curve3D.new()
		for p: Vector2 in corridors[i]:
			line.curve.add_point(terrain.valley_to_local(p.x, terrain.surface_height(p.x, -p.y), p.y))
		line.add_to_group(&"ride_lines", true)
		_add(root, lines, line)

	# --- Tight sections: the whole middle of busy chunks (camera tucks in).
	if spec.get("tight", false):
		var d0: float = END_CLEAR + 20.0
		var d1: float = length - END_CLEAR - 20.0
		var d: float = d0
		while d < d1:
			var seg: float = minf(60.0, d1 - d)
			var zone: TightZone = TIGHT.instantiate() as TightZone
			zone.name = "TightZone%d" % roundi(d)
			var frame: Transform3D = terrain.frame_at(d + seg * 0.5)
			zone.size = Vector3(terrain.half_play_at(d + seg * 0.5) * 2.0, 40.0, seg + 2.0)
			zone.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 8.0)
			_add(root, root, zone)
			d += seg

	# --- Markers, centerline, spawn / finish.
	track.curve.clear_points()
	for i: int in range(0, int(length) + 1):
		track.curve.add_point(terrain.frame_at(float(i)).origin)
	(root.get_node(^"Entry") as Marker3D).transform = terrain.frame_at(0.0)
	(root.get_node(^"Exit") as Marker3D).transform = terrain.exit_transform()
	root.exit_heading_deg = rad_to_deg(terrain.heading_at(length))
	if spec.has("spawn"):
		for marker: Array in [["Spawn", spec["spawn"]], ["DropIn", spec["drop_in"]]]:
			var m: Marker3D = Marker3D.new()
			m.name = marker[0]
			var md: float = marker[1]
			m.position = terrain.valley_to_local(0.0, terrain.surface_height(0.0, -md), md)
			_add(root, root, m)
	if spec.has("finish"):
		var gate: Node3D = FINISH.instantiate() as Node3D
		gate.name = "FinishGate"
		var fd: float = spec["finish"]
		gate.transform = Transform3D(Basis(Vector3.UP, terrain.heading_at(fd)) * Basis.from_scale(Vector3(3.6, 1.6, 1.0)),
				terrain.valley_to_local(0.0, terrain.surface_height(0.0, -fd), fd))
		_add(root, root, gate)

	var ok: bool = terrain.fold_margin >= 0.0
	get_root().remove_child(root)
	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	print("%s: %s  %d props, %d clusters, exit heading %.0f deg, tightest bend r %.0f m%s" % [
		spec["file"], error_string(err), props.get_child_count(), clusters, root.exit_heading_deg,
		terrain.tightest_radius, "" if ok else "  ** FOLDS: bend tighter than the valley half width **"])
	root.free()


func _add(root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = root


# --- Corridors (valley space: Vector2(x, d) every 2.5 m) ----------------------

## A wandering corridor: a base spot across the valley plus two sine waves,
## squeezed with the valley's width. Curvature stays under 1/45 m.
func _make_corridor(terrain: TerrainPatch, i: int, count: int, wander: float, length: float) -> PackedVector2Array:
	var base: float = 0.0 if count == 1 else lerpf(-0.62, 0.62, (i + _rng.randf_range(-0.2, 0.2)) / float(count - 1))
	var l1: float = _rng.randf_range(160.0, 230.0)
	var l2: float = _rng.randf_range(90.0, 130.0)
	var a1: float = minf(_rng.randf_range(12.0, 20.0), l1 * l1 / 1800.0) * wander
	var a2: float = minf(_rng.randf_range(3.0, 6.0), l2 * l2 / 3600.0) * wander
	var p1: float = _rng.randf() * TAU
	var p2: float = _rng.randf() * TAU
	var out: PackedVector2Array = PackedVector2Array()
	var d: float = 0.0
	while d <= length + 0.01:
		# Stay on the flat floor, clear of the edge banks.
		var room: float = terrain.half_play_at(d) - terrain.wall_width
		var x: float = base * room + a1 * sin(TAU * d / l1 + p1) + a2 * sin(TAU * d / l2 + p2)
		out.append(Vector2(clampf(x, -room, room), d))
		d += 2.5
	return out


static func _corridor_x(c: PackedVector2Array, d: float) -> float:
	var i: int = clampi(int(d / 2.5), 0, c.size() - 2)
	return lerpf(c[i].x, c[i + 1].x, clampf((d - c[i].y) / 2.5, 0.0, 1.0))


## How much corridor c turns between d0 and d1 in the patch's own space (deg).
static func _turn_deg(terrain: TerrainPatch, c: PackedVector2Array, d0: float, d1: float) -> float:
	var dirs: Array[Vector3] = []
	for d: float in [d0, d1]:
		var a: Vector3 = terrain.valley_to_local(_corridor_x(c, d - 2.0), 0.0, d - 2.0)
		var b: Vector3 = terrain.valley_to_local(_corridor_x(c, d + 2.0), 0.0, d + 2.0)
		dirs.append((b - a).normalized())
	return rad_to_deg(dirs[0].angle_to(dirs[1]))


## Unit direction (dx, dd) of the corridor at d, valley space.
static func _corridor_tangent(c: PackedVector2Array, d: float) -> Vector2:
	return Vector2(_corridor_x(c, d + 2.0) - _corridor_x(c, d - 2.0), 4.0).normalized()


## x scaled with the valley width at d (for features placed by fraction).
static func _scale_x(terrain: TerrainPatch, x: float, d: float) -> float:
	return x * terrain.half_play_at(d) / (terrain.width * 0.5)


## A d where a `span` long stretch of corridor c is free of other features
## and turns less than `max_turn_deg` in the world (valley bend + corridor
## wander): rails and kickers want straight-ish ground.
func _free_d(c: PackedVector2Array, taken: Array[Vector3], span: float, length: float,
		terrain: TerrainPatch = null, max_turn_deg: float = 180.0) -> float:
	for attempt: int in 60:
		var d0: float = _rng.randf_range(END_CLEAR + 8.0, length - END_CLEAR - span - 8.0)
		var ok: bool = terrain == null or _turn_deg(terrain, c, d0, d0 + span) <= max_turn_deg
		for t: Vector3 in taken:
			for k: int in 5:
				var d: float = d0 + span * k / 4.0
				if Vector2(_corridor_x(c, d), d).distance_to(Vector2(t.x, t.y)) < t.z + 10.0:
					ok = false
		if ok:
			return d0
	return -1.0


# --- Shapes and pads ----------------------------------------------------------

## A TerrainShape along corridor c from d0 to d1 (y on the plain slope + lift).
func _shape_along(terrain: TerrainPatch, c: PackedVector2Array, d0: float, d1: float, mode: TerrainShape.Mode,
		shape_width: float, depth: float, flat: float, lift: float) -> TerrainShape:
	var line: PackedVector2Array = PackedVector2Array()
	var d: float = d0
	while d <= d1 + 0.01:
		line.append(Vector2(_corridor_x(c, d), d))
		d += 2.5
	var shape: TerrainShape = _shape_from(terrain, line, mode, shape_width, depth, flat)
	for i: int in shape.curve.point_count:
		var p: Vector3 = shape.curve.get_point_position(i)
		shape.curve.set_point_position(i, p + Vector3.UP * lift)
	return shape


## A TerrainShape through valley points (x, d), heights on the plain slope.
func _shape_from(terrain: TerrainPatch, line: PackedVector2Array, mode: TerrainShape.Mode,
		shape_width: float, depth: float, flat: float) -> TerrainShape:
	var shape: TerrainShape = TerrainShape.new()
	shape.mode = mode
	shape.width = shape_width
	shape.depth = depth
	shape.flat = flat
	shape.curve = Curve3D.new()
	for p: Vector2 in line:
		shape.curve.add_point(terrain.valley_to_local(p.x, terrain.base_height(p.x, -p.y), p.y))
	return shape


## A pad on the plain slope at valley point p, facing along valley direction dir.
func _pad_transform(terrain: TerrainPatch, p: Vector2, dir: Vector2) -> Transform3D:
	var a: Vector3 = terrain.valley_to_local(p.x, 0.0, p.y)
	var b: Vector3 = terrain.valley_to_local(p.x + dir.x * 4.0, 0.0, p.y + dir.y * 4.0)
	var yaw: float = atan2(-(b.x - a.x), -(b.z - a.z))
	var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-SLOPE))
	return Transform3D(basis, Vector3(a.x, terrain.base_height(p.x, -p.y), a.z))


# --- Props ------------------------------------------------------------------------

func _pick(mix: Dictionary) -> String:
	var total: float = 0.0
	for k: String in mix:
		total += float(mix[k])
	var roll: float = _rng.randf() * total
	for k: String in mix:
		roll -= float(mix[k])
		if roll <= 0.0:
			return k
	return String(mix.keys()[0])


## One cluster of `kind` around a spot (random, weighted toward the spec's
## "dense" stretches, or `at` for a hand-placed one); members that would
## block a corridor, a feature, a "clear" stretch or the open seams are skipped.
func _cluster(root: Node, props: Node3D, terrain: TerrainPatch, kind: String, corridors: Array[PackedVector2Array],
		clear: float, taken: Array[Vector3], placed: Array[Vector3], length: float, spec: Dictionary,
		at: Vector2 = Vector2.INF, count: int = -1, spread: float = -1.0) -> void:
	var d: float = at.y
	var x: float = at.x
	if at == Vector2.INF:
		d = _pick_d(spec, length)
		var half_d: float = terrain.half_play_at(d)
		x = _rng.randf_range(-half_d + 6.0, half_d - 6.0)
	var members: Array[Vector3] = []
	match kind:
		"tree":
			var s1: float = 10.0 if spread < 0.0 else spread
			for i: int in (_rng.randi_range(4, 10) if count < 0 else count):
				members.append(Vector3(x + _rng.randf_range(-s1, s1), d + _rng.randf_range(-s1, s1), _rng.randf() * TAU))
		"rock":
			var s2: float = 8.0 if spread < 0.0 else spread
			for i: int in (_rng.randi_range(3, 6) if count < 0 else count):
				members.append(Vector3(x + _rng.randf_range(-s2, s2), d + _rng.randf_range(-s2, s2), _rng.randf() * TAU))
		"log":
			members.append(Vector3(x, d, _rng.randf() * TAU))
		"fence", "barrier":
			# A short run, roughly across or along the valley.
			var angle: float = _rng.randf() * PI
			var step: float = 6.2 if kind == "fence" else 3.1
			for i: int in (_rng.randi_range(2, 5) if count < 0 else count):
				members.append(Vector3(x + cos(angle) * step * i, d + sin(angle) * step * i, angle))
	var scene: PackedScene = {"tree": TREE, "rock": ROCK, "log": LOG, "fence": FENCE, "barrier": BARRIER}[kind] as PackedScene
	var radius: float = float(RADIUS[kind])
	for m: Vector3 in members:
		var p: Vector2 = Vector2(m.x, m.y)
		if p.y < END_CLEAR or p.y > length - END_CLEAR or absf(p.x) > terrain.half_play_at(p.y) - 3.0 or _in_clear(spec, p.y):
			continue
		var ok: bool = true
		for c: PackedVector2Array in corridors:
			if absf(_corridor_x(c, p.y) - p.x) < clear + radius + 1.0:
				ok = false
				break
		for t: Vector3 in taken:
			if ok and p.distance_to(Vector2(t.x, t.y)) < t.z + radius + 3.0:
				ok = false
		for q: Vector3 in placed:
			if ok and p.distance_to(Vector2(q.x, q.y)) < q.z + radius + 1.5:
				ok = false
		if not ok:
			continue
		var prop: Node3D = scene.instantiate() as Node3D
		prop.name = "%s%d" % [kind.capitalize(), props.get_child_count() + 1]
		prop.position = terrain.valley_to_local(p.x, terrain.surface_height(p.x, -p.y), p.y)
		# Yaw relative to the valley's heading there.
		prop.rotation.y = m.z + terrain.heading_at(p.y)
		if kind == "tree":
			prop.scale = Vector3.ONE * _rng.randf_range(0.8, 1.35)
		elif kind == "rock":
			prop.scale = Vector3.ONE * _rng.randf_range(0.9, 1.8)
		_add(root, props, prop)
		placed.append(Vector3(p.x, p.y, radius * (prop.scale.x if kind == "rock" else 1.0)))


## A d for a random cluster: uniform, but the spec's "dense" stretches
## (Vector3(d0, d1, extra weight)) get picked that much more often.
func _pick_d(spec: Dictionary, length: float) -> float:
	var dense: Array = spec.get("dense", [])
	for attempt: int in 50:
		var d: float = _rng.randf_range(END_CLEAR, length - END_CLEAR)
		var weight: float = 1.0
		var top: float = 1.0
		for r: Vector3 in dense:
			top = maxf(top, 1.0 + r.z)
			if d >= r.x and d <= r.y:
				weight += r.z
		if _rng.randf() * top <= weight:
			return d
	return _rng.randf_range(END_CLEAR, length - END_CLEAR)


## True inside one of the spec's "clear" stretches (Vector2(d0, d1)): no
## obstacles there (run-ups, landings).
static func _in_clear(spec: Dictionary, d: float) -> bool:
	for r: Vector2 in spec.get("clear", []):
		if d >= r.x and d <= r.y:
			return true
	return false


## A boost gate at valley point p, facing along valley direction dir, its
## centre `up` m above the ground.
func _gate(root: Node, parent: Node3D, terrain: TerrainPatch, p: Vector2, dir: Vector2, up: float, radius: float = 3.2) -> void:
	# Plain Node3D: the BoostGate script can't load in this -s tool run (it
	# needs the Events autoload), so size the gate by scale instead of `radius`.
	var gate: Node3D = GATE.instantiate() as Node3D
	gate.name = "Gate%d" % (parent.get_child_count() + 1)
	var a: Vector3 = terrain.valley_to_local(p.x, 0.0, p.y)
	var b: Vector3 = terrain.valley_to_local(p.x + dir.x * 4.0, 0.0, p.y + dir.y * 4.0)
	var yaw: float = atan2(-(b.x - a.x), -(b.z - a.z))
	gate.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * radius / 3.2), Vector3(a.x, terrain.surface_height(p.x, -p.y) + up, a.z))
	_add(root, parent, gate)


## A hand-drawn way through (set pieces): key points Vector2(x, d), eased
## from key to key, sampled every 2.5 m like the random corridors.
static func _path_from_keys(keys: Array, length: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var d: float = 0.0
	while d <= length + 0.01:
		var x: float = (keys[-1] as Vector2).x
		for i: int in range(1, keys.size()):
			var a: Vector2 = keys[i - 1]
			var b: Vector2 = keys[i]
			if d <= b.y:
				var f: float = clampf((d - a.y) / maxf(b.y - a.y, 0.001), 0.0, 1.0)
				x = lerpf(a.x, b.x, f * f * (3.0 - 2.0 * f))
				break
		out.append(Vector2(x, d))
		d += 2.5
	return out

static func _curve(points: Array, lo: float, hi: float) -> Curve:
	if points.is_empty():
		return null
	var curve: Curve = Curve.new()
	curve.min_value = lo
	curve.max_value = hi
	for p: Vector2 in points:
		curve.add_point(p)
	return curve
