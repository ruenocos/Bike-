@tool
class_name TerrainPatch
extends Node3D
## A wide downhill valley: one generated mesh + collision, built from the
## settings below and the shaping nodes placed under it. Previews live in the
## editor: change a value or drag a shaping node and the terrain rebuilds.
##
## The valley runs along a spine that starts at this node's origin heading
## down -Z and bends as `heading_curve` says (v0.8.1). Everything about the
## valley's shape is worked out in "valley space": x = metres across from the
## spine (+ = right), d = metres downhill along it. The play area is `width`
## wide (|x| <= width/2, edge walls included, optionally narrowed along the
## length by `width_profile`); past the wall crests the ground falls away for
## `outside_width` more on each side. That strip is rideable but out of
## bounds (the game counts it down).
##
## Height at a point, in order:
##   1. base slope (slope_deg, shaped along the length by slope_profile)
##   2. + noise (rolling ground)
##   3. + TerrainShape GULLY / RIDGE children (dig / raise along a curve)
##   4. blend toward TerrainShape LINE children (the ground follows the curve's
##      own height) and TerrainFlatten children (a flat pad for kickers, rails)
##   5. + edge walls (soft banks up to the crests), the outside fall-away, and
##      optional invisible boundary walls at the very edge
## Steps 2-4 fade out over `seam_blend` at the entry and exit, so every patch
## with the same width / slope / walls / cell size has exactly the same entry
## and exit edge, whatever its bend: patches placed exit-to-entry (exit_transform)
## meet without a step.
##
## Shaping nodes can sit anywhere under this node (also nested), in the
## patch's normal 3D space: they follow the bend because the patch converts
## them into valley space. Their order matters for LINE and Flatten (later
## ones win where they overlap).
##
## Bending: the inner side of a bend must stay wider than the valley's half
## width (plus the outside strip), or the ground would fold over itself. The
## inspector shows the tightest radius; rebuilding warns when it's too tight.
##
## Godot note: the mesh and collision are generated children that aren't
## saved with the scene (they're "internal" and have no owner); the scene
## only stores the settings. They're rebuilt when the scene loads.

const BOUNDARY_SEGMENT: float = 20.0

@export_tool_button("Rebuild terrain") var rebuild_button: Callable = rebuild
## Puts every child of the "Props" node under this patch on the ground (keeps
## x/z, sets the height). Press after reshaping the terrain.
@export_tool_button("Snap props to ground") var snap_props_button: Callable = snap_props

@export_group("Size")
## Across the play area, crest to crest (edge walls included).
@export_range(20.0, 400.0, 1.0, "suffix:m") var width: float = 150.0:
	set(v):
		width = v
		queue_rebuild()
## Downhill, along the spine.
@export_range(20.0, 1000.0, 1.0, "suffix:m") var length: float = 300.0:
	set(v):
		length = v
		queue_rebuild()
## Grid spacing of the mesh and collision. Smaller = smoother, slower to build.
## Patches that join must use the same cell size.
@export_range(0.5, 8.0, 0.25, "suffix:m") var cell_size: float = 2.0:
	set(v):
		cell_size = v
		queue_rebuild()
## Optional: the play width along the length, as a multiplier of `width`
## (x 0 = entry, x 1 = exit). Keep both ends at 1 so patches still join.
## Empty = the same width all the way.
@export var width_profile: Curve:
	set(v):
		width_profile = _watch(width_profile, v)

@export_group("Bend")
## The valley's heading along its length, in degrees (+ = bending left,
## - = right; x 0 = entry, x 1 = exit). Start at 0. The exit edge faces the
## end heading, and the next chunk carries on from there. Empty = straight.
## Set the curve's min/max value (e.g. -120 / 120) to draw big bends.
@export var heading_curve: Curve:
	set(v):
		heading_curve = _watch(heading_curve, v)
## Tightest bend radius of the spine in the last build (m, read only, not saved).
## `fold_margin` is the smallest (radius - local half width incl. the outside
## strip) along the spine; below 0 the ground folds over itself.
@export_custom(PROPERTY_HINT_NONE, "suffix:m", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var tightest_radius: float = INF

@export_group("Slope")
## Downhill angle. Chunks join at 23 deg (Chunk.JOIN_PITCH_DEG).
@export_range(0.0, 60.0, 0.5, "suffix:deg") var slope_deg: float = 23.0:
	set(v):
		slope_deg = v
		queue_rebuild()
## Optional: the slope along the length, as a multiplier of slope_deg
## (x 0 = entry, x 1 = exit). Keep both ends at 1 so patches still join.
## Empty = the same slope all the way.
@export var slope_profile: Curve:
	set(v):
		slope_profile = _watch(slope_profile, v)

@export_group("Noise")
## Height of the rolling ground, up and down from the slope.
@export_range(0.0, 20.0, 0.1, "suffix:m") var noise_amplitude: float = 2.5:
	set(v):
		noise_amplitude = v
		queue_rebuild()
## Bumps per metre. 0.01 = long swells, 0.05 = choppy.
@export_range(0.001, 0.2, 0.001) var noise_frequency: float = 0.015:
	set(v):
		noise_frequency = v
		queue_rebuild()
@export_range(1, 6) var noise_octaves: int = 3:
	set(v):
		noise_octaves = v
		queue_rebuild()
@export var noise_seed: int = 1:
	set(v):
		noise_seed = v
		queue_rebuild()
## Short, punchy bumps on top of the rolling ground (v0.33, Wons: "the
## noise the terrain makes needs to be intense more bump more hill"): up and
## down from the slope (m). 0 = none. Lines-shapes and flatten pads (rail
## beds, kicker pads) smooth them out like the rest of the noise.
@export_range(0.0, 10.0, 0.05, "suffix:m") var bump_amplitude: float = 0.0:
	set(v):
		bump_amplitude = v
		queue_rebuild()
## Bumps per metre (0.035 = one every ~28 m: at 50 m/s each one pops you).
@export_range(0.005, 0.2, 0.001) var bump_frequency: float = 0.035:
	set(v):
		bump_frequency = v
		queue_rebuild()
## How far in from the entry and exit the noise and shaping fade in, so the
## edges stay plain slope and line up with the next patch.
@export_range(0.0, 100.0, 1.0, "suffix:m") var seam_blend: float = 30.0:
	set(v):
		seam_blend = v
		queue_rebuild()

@export_group("Swells")
## Big rolling swells across the valley (v0.31 "drastic landscape"): long
## waves you pump down the back of, instead of small bumps. Height up and
## down from the slope (m). 0 = none.
@export_range(0.0, 20.0, 0.1, "suffix:m") var swell_amplitude: float = 0.0:
	set(v):
		swell_amplitude = v
		queue_rebuild()
## Crest to crest, along the valley (m).
@export_range(20.0, 300.0, 1.0, "suffix:m") var swell_wavelength: float = 90.0:
	set(v):
		swell_wavelength = v
		queue_rebuild()
## Crests run this many degrees off square to the valley (diagonal swells
## make you pick where to cross them).
@export_range(-60.0, 60.0, 1.0, "suffix:deg") var swell_skew_deg: float = 18.0:
	set(v):
		swell_skew_deg = v
		queue_rebuild()
## Swells ease out this far around rail beds, kicker pads and other LINE /
## flatten shapes (m), so features keep a smooth run-in.
@export_range(0.0, 120.0, 1.0, "suffix:m") var swell_calm_margin: float = 35.0:
	set(v):
		swell_calm_margin = v
		queue_rebuild()
## Shifts the waves along the valley (m), so neighbouring chunks differ.
@export var swell_phase: float = 0.0:
	set(v):
		swell_phase = v
		queue_rebuild()

@export_group("Edges")
## How far in from each side the edge walls start to rise.
@export_range(0.0, 80.0, 0.5, "suffix:m") var wall_width: float = 16.0:
	set(v):
		wall_width = v
		queue_rebuild()
## How high the walls are at the very edge.
@export_range(0.0, 60.0, 0.5, "suffix:m") var wall_height: float = 14.0:
	set(v):
		wall_height = v
		queue_rebuild()
## Wall shape: 1 = straight ramp, 2 = curves up like a bank, 3+ = cliffier.
@export_range(1.0, 5.0, 0.1) var wall_curve: float = 2.2:
	set(v):
		wall_curve = v
		queue_rebuild()
## Optional: wall height along the length, as a multiplier of wall_height
## (x 0 = entry, x 1 = exit). Keep both ends at 1 so patches still join.
## The Megapipe (v0.31) raises it to a 40 m halfpipe. Empty = constant.
@export var wall_profile: Curve:
	set(v):
		wall_profile = _watch(wall_profile, v)
## Optional: wall width (how far in the banks start) along the length, as a
## multiplier of wall_width. Keep both ends at 1. Empty = constant.
@export var wall_width_profile: Curve:
	set(v):
		wall_width_profile = _watch(wall_width_profile, v)
## The ground counts as a transition (group "transitions"): carving scores,
## steep banks launch lip airs and the camera goes into halfpipe mode on
## them. On for the Megapipe.
@export var transition_surface: bool = false:
	set(v):
		transition_surface = v
		queue_rebuild()
## Out-of-bounds ground past each crest (m). 0 = the mesh ends at the crests.
@export_range(0.0, 200.0, 1.0, "suffix:m") var outside_width: float = 50.0:
	set(v):
		outside_width = v
		queue_rebuild()
## How far the outside ground falls from the crest to the outer edge (m).
@export_range(0.0, 200.0, 1.0, "suffix:m") var outside_drop: float = 30.0:
	set(v):
		outside_drop = v
		queue_rebuild()
## Invisible walls at the outer edges, this high above the ground there.
## 0 = none (the game handles out of bounds instead).
@export_range(0.0, 200.0, 1.0, "suffix:m") var boundary_height: float = 0.0:
	set(v):
		boundary_height = v
		queue_rebuild()

@export_group("Look")
@export var material: Material = preload("res://chunks/materials/terrain.tres"):
	set(v):
		material = v
		if _mesh_instance != null:
			_mesh_instance.material_override = material
## The current stage's biome cover, set by the game (v0.12); wins over
## `ground_cover` outside the editor.
static var cover_override: GroundCover

## Grass / dirt patches and what grows on them (v0.11). Empty = bare ground.
@export var ground_cover: GroundCover = preload("res://chunks/terrain/cover/meadow.tres"):
	set(v):
		ground_cover = v
		queue_rebuild()

## Grid size and heights of the last build (row-major; row r is r * row
## spacing down the spine, column c runs across it).
var columns: int = 0
var rows: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _cover: Node3D
var _mesh_arrays: Array = []
## Patches waiting for their ground cover (one is built per frame).
static var _cover_queue: Array[TerrainPatch] = []
static var _cover_driver: TerrainPatch
## Queued covers build nearest this point first (the game keeps it on the
## spawn, then on the rider).
static var cover_focus: Vector3 = Vector3.ZERO
## After the cover is built: instances per layer and the mean grass amount
## (also filled headless, where no MultiMesh is made; the tests read it).
var cover_stats: Dictionary = {}
var _rebuild_queued: bool = false
var _noise: FastNoiseLite = FastNoiseLite.new()
var _bumps: FastNoiseLite = FastNoiseLite.new()
## Per row: height of the base slope, half the play width, the spine point
## (x, z in patch space) and its heading (radians, + = left).
var _row_base: PackedFloat32Array = PackedFloat32Array()
var _row_half: PackedFloat32Array = PackedFloat32Array()
var _row_center: PackedVector2Array = PackedVector2Array()
var _row_heading: PackedFloat32Array = PackedFloat32Array()
## Per row: edge wall height and width (wall_profile / wall_width_profile).
var _row_wall_h: PackedFloat32Array = PackedFloat32Array()
var _row_wall_w: PackedFloat32Array = PackedFloat32Array()
## Swell height per grid point (before the seam fade), see _compute_swells.
var _swell: PackedFloat32Array = PackedFloat32Array()
## Smallest bend radius minus the local half width (m); < 0 = folds over.
var fold_margin: float = INF


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	add_child(_mesh_instance, false, Node.INTERNAL_MODE_BACK)
	_body = StaticBody3D.new()
	_body.name = "TerrainBody"
	add_child(_body, false, Node.INTERNAL_MODE_BACK)
	_cover = Node3D.new()
	_cover.name = "GroundCover"
	add_child(_cover, false, Node.INTERNAL_MODE_BACK)
	rebuild()
	# Adding or removing shaping nodes rebuilds (connected after our own children).
	child_order_changed.connect(queue_rebuild)


## One queued patch at a time drives the queue (the others don't process).
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _cover_driver != self:
		set_process(false)
		return
	var nearest: TerrainPatch = null
	var best: float = INF
	for patch: TerrainPatch in _cover_queue:
		if is_instance_valid(patch) and patch.is_inside_tree():
			var d: float = patch.global_position.distance_squared_to(cover_focus)
			if d < best:
				best = d
				nearest = patch
	if nearest != null:
		_cover_queue.erase(nearest)
		nearest._build_cover()
	if not _cover_queue.has(self):
		_hand_off()


## Passes driving the queue to another queued patch (or ends it).
func _hand_off() -> void:
	set_process(false)
	_cover_driver = null
	for patch: TerrainPatch in _cover_queue:
		if is_instance_valid(patch) and patch.is_inside_tree():
			_cover_driver = patch
			patch.set_process(true)
			return


func _exit_tree() -> void:
	_cover_queue.erase(self)
	if _cover_driver == self:
		_hand_off()


## Rebuild once at the end of this frame (many edits in a row = one build).
func queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	_compute_rows()
	_compute_heights()
	_build_mesh()
	_build_collision()
	# Grass patches are in world space: wait until whoever added us has put
	# us in place (StageBuilder moves a chunk right after adding it). In the
	# game, patches queue up and build one per frame, nearest the camera
	# first, so a new stage doesn't hitch.
	if Engine.is_editor_hint():
		_build_cover.call_deferred()
	elif not _cover_queue.has(self):
		_cover_queue.append(self)
		if _cover_driver == null or not is_instance_valid(_cover_driver):
			_cover_driver = self
			set_process(true)


## Swaps a watched Curve: edits to the curve rebuild the terrain.
func _watch(old: Curve, new: Curve) -> Curve:
	if old != null and old.changed.is_connected(queue_rebuild):
		old.changed.disconnect(queue_rebuild)
	if new != null and not new.changed.is_connected(queue_rebuild):
		new.changed.connect(queue_rebuild)
	queue_rebuild()
	return new


# --- Valley space ------------------------------------------------------------

## Height of the plain slope + edge walls (no noise or shaping) at valley
## (x across, z = -d along). The entry and exit edges are exactly this.
func base_height(x: float, z: float) -> float:
	return _slope_height(-z) + _wall_height(x, half_play_at(-z), wall_height_at(-z), wall_width_at(-z))


## Height of the built surface at valley (x across, z = -d along): the mesh /
## collision. Outside the patch it clamps to the nearest edge.
func surface_height(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var dz: float = length / float(rows - 1)
	var fz: float = clampf(-z / dz, 0.0, float(rows - 1) - 0.0001)
	var r: int = int(fz)
	var tz: float = fz - r
	# Columns are spaced per row (the width can change), so find the column
	# fraction in both rows and blend.
	var fx0: float = _column_f(r, x)
	var fx1: float = _column_f(r + 1, x)
	var fx: float = lerpf(fx0, fx1, tz)
	var c: int = int(fx)
	var tx: float = fx - c
	var h00: float = heights[r * columns + c]
	var h10: float = heights[r * columns + c + 1]
	var h01: float = heights[(r + 1) * columns + c]
	var h11: float = heights[(r + 1) * columns + c + 1]
	# Same split as the mesh: diagonal from (c, r) to (c+1, r+1).
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


## Surface height under a point in this patch's own 3D space.
func height_at_local(p: Vector3) -> float:
	var v: Vector3 = local_to_valley(p)
	return surface_height(v.x, -v.z)


## Valley (x across, y up, d along) to this patch's 3D space.
func valley_to_local(x: float, y: float, d: float) -> Vector3:
	var f: Dictionary = _spine_at(d)
	var right: Vector3 = f["right"]
	var center: Vector3 = f["center"]
	return Vector3(center.x + right.x * x, y, center.z + right.z * x)


## This patch's 3D space to valley space: Vector3(x across, y, d along).
## `hint` = a row to start searching from (speeds up walking along a curve).
func local_to_valley(p: Vector3, hint: int = -1) -> Vector3:
	if _row_center.is_empty():
		return Vector3(p.x, p.y, -p.z)
	var best: int = 0
	var best_d: float = INF
	var from: int = 0 if hint < 0 else maxi(hint - 12, 0)
	var to: int = rows - 1 if hint < 0 else mini(hint + 12, rows - 1)
	var p2: Vector2 = Vector2(p.x, p.z)
	for r: int in range(from, to + 1):
		var dd: float = _row_center[r].distance_squared_to(p2)
		if dd < best_d:
			best_d = dd
			best = r
	var dz: float = length / float(rows - 1)
	var h: float = _row_heading[best]
	var forward: Vector2 = Vector2(-sin(h), -cos(h))
	var right: Vector2 = Vector2(cos(h), -sin(h))
	var rel: Vector2 = p2 - _row_center[best]
	return Vector3(rel.dot(right), p.y, clampf(best * dz + rel.dot(forward), 0.0, length))


## Spine frame at distance d: origin on the plain slope at the spine, -Z
## down the slope along the heading, X across to the right, no bank.
func frame_at(d: float) -> Transform3D:
	var f: Dictionary = _spine_at(d)
	var right: Vector3 = f["right"]
	var flat_forward: Vector3 = Vector3.UP.cross(right)
	var pitch: float = deg_to_rad(_slope_at(clampf(d / length, 0.0, 1.0)))
	var forward: Vector3 = (flat_forward * cos(pitch) + Vector3.DOWN * sin(pitch)).normalized()
	var up: Vector3 = right.cross(forward)
	var center: Vector3 = f["center"]
	return Transform3D(Basis(right, up, -forward), Vector3(center.x, _slope_height(d), center.z))


## Where the next patch's entry goes (its frame_at(0) lands here).
func exit_transform() -> Transform3D:
	return frame_at(length)


## Middle of the exit edge in this patch's space.
func exit_point() -> Vector3:
	return exit_transform().origin


## Heading at distance d (radians, + = left).
func heading_at(d: float) -> float:
	if heading_curve == null:
		return 0.0
	return deg_to_rad(heading_curve.sample(clampf(d / length, 0.0, 1.0)))


## Half the play width at distance d (crest to spine).
func half_play_at(d: float) -> float:
	var k: float = 1.0 if width_profile == null else width_profile.sample(clampf(d / length, 0.0, 1.0))
	return width * 0.5 * maxf(k, 0.05)


## Half the mesh width at the widest point: the play area plus the outside strip.
func half_total_width() -> float:
	var widest: float = width * 0.5
	if width_profile != null:
		for i: int in 21:
			widest = maxf(widest, half_play_at(length * i / 20.0))
	return widest + outside_width


## True when a point (this patch's space) is past the crests.
func is_out_of_bounds_local(p: Vector3) -> bool:
	var v: Vector3 = local_to_valley(p)
	return absf(v.x) > half_play_at(v.z)


## Sets the height of every child of the "Props" node to the surface under it.
func snap_props() -> void:
	var props: Node = get_node_or_null(^"Props")
	if props == null:
		return
	if heights.is_empty() or _rebuild_queued:
		rebuild()
	for child: Node in props.get_children():
		var prop: Node3D = child as Node3D
		if prop == null:
			continue
		var at: Vector3 = _to_patch(prop).origin
		var offset: float = float(prop.get_meta(&"ground_offset", 0.0))
		prop.position.y += height_at_local(at) + offset - at.y


## Interpolated spine point and right vector at distance d.
func _spine_at(d: float) -> Dictionary:
	if _row_center.is_empty():
		var h0: float = heading_at(d)
		return {"center": Vector3(0.0, 0.0, -d), "right": Vector3(cos(h0), 0.0, -sin(h0))}
	var dz: float = length / float(rows - 1)
	var fr: float = clampf(d / dz, 0.0, float(rows - 1))
	var r: int = mini(int(fr), rows - 2)
	var t: float = fr - r
	var c: Vector2 = _row_center[r].lerp(_row_center[r + 1], t)
	var h: float = lerpf(_row_heading[r], _row_heading[r + 1], t)
	# Past the ends: carry on straight.
	if d > length:
		c += Vector2(-sin(h), -cos(h)) * (d - length)
	elif d < 0.0:
		c += Vector2(-sin(h), -cos(h)) * d
	return {"center": Vector3(c.x, 0.0, c.y), "right": Vector3(cos(h), 0.0, -sin(h))}


## Column position of valley x in row r (fractional).
func _column_f(r: int, x: float) -> float:
	var half_total: float = _row_half[r] + outside_width
	var dx: float = half_total * 2.0 / float(columns - 1)
	return clampf((x + half_total) / dx, 0.0, float(columns - 1) - 0.0001)


## Valley x of column c in row r.
func _column_x(r: int, c: int) -> float:
	var half_total: float = _row_half[r] + outside_width
	return -half_total + c * half_total * 2.0 / float(columns - 1)


## Patch-space position (x, z) of grid point (r, c).
func _grid_xz(r: int, c: int) -> Vector2:
	var h: float = _row_heading[r]
	return _row_center[r] + Vector2(cos(h), -sin(h)) * _column_x(r, c)


# --- Heights ---------------------------------------------------------------

## The spine: per row, base slope, play half width, centre and heading.
func _compute_rows() -> void:
	rows = maxi(2, int(round(length / cell_size)) + 1)
	columns = maxi(2, int(round(half_total_width() * 2.0 / cell_size)) + 1)
	var dz: float = length / float(rows - 1)
	_row_base.resize(rows)
	_row_half.resize(rows)
	_row_center.resize(rows)
	_row_heading.resize(rows)
	_row_wall_h.resize(rows)
	_row_wall_w.resize(rows)
	_row_base[0] = 0.0
	_row_center[0] = Vector2.ZERO
	var tightest: float = INF
	fold_margin = INF
	for r: int in rows:
		var d: float = r * dz
		_row_half[r] = half_play_at(d)
		_row_heading[r] = heading_at(d)
		_row_wall_h[r] = wall_height_at(d)
		_row_wall_w[r] = wall_width_at(d)
		if r == 0:
			continue
		var mid: float = (r - 0.5) * dz
		_row_base[r] = _row_base[r - 1] - tan(deg_to_rad(_slope_at(mid / length))) * dz
		var h: float = heading_at(mid)
		_row_center[r] = _row_center[r - 1] + Vector2(-sin(h), -cos(h)) * dz
		var turn: float = absf(_row_heading[r] - _row_heading[r - 1])
		if turn > 0.000001:
			tightest = minf(tightest, dz / turn)
			fold_margin = minf(fold_margin, dz / turn - (_row_half[r] + outside_width))
	tightest_radius = tightest
	if fold_margin < 0.0:
		push_warning("%s: a bend is %.0f m too tight for the valley's width there; the ground folds over. Ease the bend or narrow the valley (width_profile)." % [name, -fold_margin])


func _compute_heights() -> void:
	var dz: float = length / float(rows - 1)

	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM if noise_octaves > 1 else FastNoiseLite.FRACTAL_NONE
	_noise.fractal_octaves = noise_octaves
	_bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bumps.seed = noise_seed + 101
	_bumps.frequency = bump_frequency
	_bumps.fractal_type = FastNoiseLite.FRACTAL_NONE

	var count: int = columns * rows
	# Height on top of the base slope (noise + shaping), before the seam fade.
	var detail: PackedFloat32Array = PackedFloat32Array()
	detail.resize(count)
	for r: int in rows:
		var d: float = r * dz
		for c: int in columns:
			var x: float = _column_x(r, c)
			detail[r * columns + c] = _noise.get_noise_2d(x, d) * noise_amplitude
			if bump_amplitude > 0.0:
				detail[r * columns + c] += _bumps.get_noise_2d(x, d) * bump_amplitude

	var shapes: Array[Node3D] = []
	_collect_shapers(self, shapes)
	_compute_swells(shapes, dz)
	for i: int in count:
		detail[i] += _swell[i]
	# Additive shapes first (gullies dig into the noise), then the blends.
	for s: Node3D in shapes:
		if s is TerrainShape and (s as TerrainShape).mode != TerrainShape.Mode.LINE:
			_apply_shape(s as TerrainShape, detail, dz)
	for s: Node3D in shapes:
		if s is TerrainShape and (s as TerrainShape).mode == TerrainShape.Mode.LINE:
			_apply_shape(s as TerrainShape, detail, dz)
		elif s is TerrainFlatten:
			_apply_flatten(s as TerrainFlatten, detail, dz)

	heights.resize(count)
	for r: int in rows:
		var d: float = r * dz
		var fade: float = _seam_fade(d)
		for c: int in columns:
			heights[r * columns + c] = _row_base[r] + detail[r * columns + c] * fade + _wall_height(_column_x(r, c), _row_half[r], _row_wall_h[r], _row_wall_w[r])


func _slope_at(t: float) -> float:
	var k: float = 1.0 if slope_profile == null else slope_profile.sample(clampf(t, 0.0, 1.0))
	return clampf(slope_deg * k, -60.0, 75.0)


## Base slope height at distance d downhill (between rows: linear, same as the mesh).
func _slope_height(d: float) -> float:
	if _row_base.is_empty():
		return -tan(deg_to_rad(slope_deg)) * d
	var dz: float = length / float(rows - 1)
	var f: float = clampf(d / dz, 0.0, float(rows - 1))
	var r: int = mini(int(f), rows - 2)
	return lerpf(_row_base[r], _row_base[r + 1], f - r)


## Edge profile across the valley: 0 in the middle, rising to wall_height at
## the crests (|x| = half_play), then falling away by outside_drop.
func _wall_height(x: float, half_play: float, wall_h: float, wall_w: float) -> float:
	var e: float = half_play - absf(x)
	if e < 0.0:
		var t: float = minf(-e / maxf(outside_width, 0.001), 1.0)
		return wall_h - outside_drop * t * t
	if wall_w <= 0.0 or e >= wall_w:
		return 0.0
	return wall_h * pow(1.0 - e / wall_w, wall_curve)


## Edge wall height at distance d (wall_profile x wall_height).
func wall_height_at(d: float) -> float:
	var k: float = 1.0 if wall_profile == null else wall_profile.sample(clampf(d / length, 0.0, 1.0))
	return wall_height * maxf(k, 0.0)


## Edge wall width at distance d (wall_width_profile x wall_width).
func wall_width_at(d: float) -> float:
	var k: float = 1.0 if wall_width_profile == null else wall_width_profile.sample(clampf(d / length, 0.0, 1.0))
	return wall_width * maxf(k, 0.0)


## Swell height at valley (x, d), before the seam fade (0 without swells).
## Fades out toward the banks so the walls keep their shape.
func swell_at(x: float, d: float) -> float:
	if swell_amplitude <= 0.0:
		return 0.0
	var along: float = d + x * tan(deg_to_rad(swell_skew_deg)) + swell_phase
	var wave: float = sin(TAU * along / maxf(swell_wavelength, 1.0))
	var half: float = half_play_at(d)
	var edge: float = 1.0 - smoothstep(half - wall_width_at(d) * 1.2, half, absf(x))
	return wave * swell_amplitude * edge


## Swell height at a point in this patch's space, with the seam fade and the
## calm zones: what the swells added to the ground there.
func swell_offset_local(p: Vector3) -> float:
	if swell_amplitude <= 0.0 or _swell.is_empty():
		return 0.0
	var v: Vector3 = local_to_valley(p)
	return _sample_grid(_swell, v.x, -v.z) * _seam_fade(v.z)


## Swells per grid point, calmed to 0 around LINE shapes and flatten pads
## (rail beds, kicker pads, causeways) so features keep a smooth run-in
## instead of sitting in a trough. `swell_calm_margin` is the ease-out.
func _compute_swells(shapes: Array[Node3D], dz: float) -> void:
	var count: int = columns * rows
	_swell.resize(count)
	_swell.fill(0.0)
	if swell_amplitude <= 0.0:
		return
	# Calm discs (valley x, d, radius) from the line-like shapers.
	var calm: Array[Vector3] = []
	for s: Node3D in shapes:
		if s is TerrainShape and (s as TerrainShape).mode == TerrainShape.Mode.LINE:
			var shape: TerrainShape = s as TerrainShape
			if shape.curve == null:
				continue
			var xform: Transform3D = _to_patch(shape)
			var baked: PackedVector3Array = shape.curve.get_baked_points()
			for i: int in range(0, baked.size(), 4):
				var v: Vector3 = local_to_valley(xform * baked[i])
				calm.append(Vector3(v.x, v.z, shape.width * 0.5))
		elif s is TerrainFlatten:
			var flat: TerrainFlatten = s as TerrainFlatten
			var v2: Vector3 = local_to_valley(_to_patch(flat).origin)
			calm.append(Vector3(v2.x, v2.z, flat.size.length() * 0.5 + flat.blend))
	for r: int in rows:
		var d: float = r * dz
		for c: int in columns:
			var x: float = _column_x(r, c)
			var k: float = 1.0
			for disc: Vector3 in calm:
				var dist: float = Vector2(x - disc.x, d - disc.y).length() - disc.z
				if dist < swell_calm_margin:
					k = minf(k, smoothstep(0.0, swell_calm_margin, dist))
					if k <= 0.0:
						break
			if k > 0.0:
				_swell[r * columns + c] = swell_at(x, d) * k


## Bilinear sample of a per-vertex grid at valley (x, z = -d), same split as the mesh.
func _sample_grid(grid: PackedFloat32Array, x: float, z: float) -> float:
	var dz: float = length / float(rows - 1)
	var fz: float = clampf(-z / dz, 0.0, float(rows - 1) - 0.0001)
	var r: int = int(fz)
	var tz: float = fz - r
	var fx: float = lerpf(_column_f(r, x), _column_f(r + 1, x), tz)
	var c: int = clampi(int(fx), 0, columns - 2)
	var tx: float = clampf(fx - c, 0.0, 1.0)
	var h00: float = grid[r * columns + c]
	var h10: float = grid[r * columns + c + 1]
	var h01: float = grid[(r + 1) * columns + c]
	var h11: float = grid[(r + 1) * columns + c + 1]
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


func _seam_fade(d: float) -> float:
	if seam_blend <= 0.0:
		return 1.0
	return smoothstep(0.0, seam_blend, d) * smoothstep(0.0, seam_blend, length - d)


func _collect_shapers(node: Node, out: Array[Node3D]) -> void:
	for child: Node in node.get_children():
		if child is TerrainShape or child is TerrainFlatten:
			if (child as Node3D).visible:
				out.append(child as Node3D)
		_collect_shapers(child, out)


## Transform from a descendant's space into this patch's space (works in the
## editor before global transforms are valid).
func _to_patch(node: Node3D) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			xform = (n as Node3D).transform * xform
		n = n.get_parent()
	return xform


## Rasterizes the curve (in valley space) segment by segment: each grid point
## within reach gets its distance to the curve and the curve's height there.
func _apply_shape(shape: TerrainShape, detail: PackedFloat32Array, dz: float) -> void:
	if shape.curve == null or shape.curve.point_count < 2:
		return
	var xform: Transform3D = _to_patch(shape)
	var baked: PackedVector3Array = shape.curve.get_baked_points()
	if baked.size() < 2:
		return
	# Curve points as Vector3(x across, y, d along).
	var pts: PackedVector3Array = PackedVector3Array()
	pts.resize(baked.size())
	var hint: int = -1
	var step_rows: float = 1.0 / dz
	for i: int in baked.size():
		pts[i] = local_to_valley(xform * baked[i], hint)
		hint = int(pts[i].z * step_rows)
	var half: float = shape.width * 0.5
	var count: int = columns * rows
	var best_dist: PackedFloat32Array = PackedFloat32Array()
	best_dist.resize(count)
	best_dist.fill(INF)
	var best_y: PackedFloat32Array = PackedFloat32Array()
	best_y.resize(count)
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var a2: Vector2 = Vector2(a.x, a.z)
		var ab: Vector2 = Vector2(b.x, b.z) - a2
		var ab_len2: float = ab.length_squared()
		var r0: int = maxi(0, int(floor((minf(a.z, b.z) - half) / dz)))
		var r1: int = mini(rows - 1, int(ceil((maxf(a.z, b.z) + half) / dz)))
		for r: int in range(r0, r1 + 1):
			var d: float = r * dz
			var c0: int = int(floor(_column_f(r, minf(a.x, b.x) - half)))
			var c1: int = mini(columns - 1, int(ceil(_column_f(r, maxf(a.x, b.x) + half))) + 1)
			for c: int in range(c0, c1 + 1):
				var p: Vector2 = Vector2(_column_x(r, c), d)
				var t: float = 0.0 if ab_len2 <= 0.0 else clampf((p - a2).dot(ab) / ab_len2, 0.0, 1.0)
				var dist: float = p.distance_to(a2 + ab * t)
				var idx: int = r * columns + c
				if dist < best_dist[idx]:
					best_dist[idx] = dist
					best_y[idx] = lerpf(a.y, b.y, t)
	for r: int in rows:
		var row_base: float = _row_base[r]
		for c: int in columns:
			var idx: int = r * columns + c
			var dist: float = best_dist[idx]
			if dist >= half:
				continue
			var k: float = shape.profile(dist / half)
			match shape.mode:
				TerrainShape.Mode.GULLY:
					detail[idx] -= shape.depth * k
				TerrainShape.Mode.RIDGE:
					detail[idx] += shape.depth * k
				TerrainShape.Mode.LINE:
					var target: float = best_y[idx] - row_base
					detail[idx] = lerpf(detail[idx], target, k)


## Blends the ground toward the flatten node's own XZ plane (tilt the node to
## match the slope) inside its size, easing out over `blend`.
func _apply_flatten(flat: TerrainFlatten, detail: PackedFloat32Array, dz: float) -> void:
	var xform: Transform3D = _to_patch(flat)
	var inv: Transform3D = xform.affine_inverse()
	var plane_n: Vector3 = xform.basis.y.normalized()
	if absf(plane_n.y) < 0.2:
		return
	var origin: Vector3 = xform.origin
	var at: Vector3 = local_to_valley(origin)
	var reach: float = flat.size.length() * 0.5 + flat.blend
	var r0: int = maxi(0, int(floor((at.z - reach) / dz)))
	var r1: int = mini(rows - 1, int(ceil((at.z + reach) / dz)))
	for r: int in range(r0, r1 + 1):
		var c0: int = int(floor(_column_f(r, at.x - reach)))
		var c1: int = mini(columns - 1, int(ceil(_column_f(r, at.x + reach))) + 1)
		for c: int in range(c0, c1 + 1):
			var g: Vector2 = _grid_xz(r, c)
			# Height of the pad's plane here, then its footprint in pad space.
			var plane_y: float = origin.y - (plane_n.x * (g.x - origin.x) + plane_n.z * (g.y - origin.z)) / plane_n.y
			var local: Vector3 = inv * Vector3(g.x, plane_y, g.y)
			var ex: float = maxf(absf(local.x) - flat.size.x * 0.5, 0.0)
			var ez: float = maxf(absf(local.z) - flat.size.y * 0.5, 0.0)
			var out: float = Vector2(ex, ez).length()
			if out >= flat.blend and out > 0.0:
				continue
			var k: float = 1.0 if flat.blend <= 0.0 else 1.0 - smoothstep(0.0, flat.blend, out)
			var idx: int = r * columns + c
			detail[idx] = lerpf(detail[idx], plane_y - _row_base[r], k)


# --- Ground cover (v0.11) --------------------------------------------------

## Writes the grass amount into the vertex colours (red) and scatters the
## cover layers into MultiMesh tiles. Headless only the amounts are worked
## out (cover_stats), no MultiMesh.
func _build_cover() -> void:
	if not is_inside_tree() or _cover == null or _mesh_arrays.is_empty():
		return
	for child: Node in _cover.get_children():
		child.free()
	cover_stats = {}
	var cover: GroundCover = ground_cover
	if cover_override != null and not Engine.is_editor_hint():
		cover = cover_override
	if cover == null:
		return
	var verts: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = _mesh_arrays[Mesh.ARRAY_NORMAL]
	var to_world: Transform3D = global_transform
	var mask: PackedFloat32Array = PackedFloat32Array()
	mask.resize(verts.size())
	var total: float = 0.0
	for i: int in verts.size():
		var n_world: Vector3 = (to_world.basis * normals[i]).normalized()
		mask[i] = cover.mask_at(to_world * verts[i], n_world.y)
		total += mask[i]
	cover_stats["grass"] = total / maxf(verts.size(), 1.0)
	# The CPU copy of the colours stays in step with the GPU one (tests read it).
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(mask.size())
	for i: int in mask.size():
		colors[i] = Color(mask[i], 0.0, 0.0, 1.0)
	_mesh_arrays[Mesh.ARRAY_COLOR] = colors
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless:
		_write_mask(mask)
	for li: int in cover.layers.size():
		var layer: GroundCoverLayer = cover.layers[li]
		if layer != null and layer.density > 0.0 and layer.get_mesh() != null:
			cover_stats[li] = _scatter(cover, layer, li, verts, normals, mask, not headless)


## Puts the grass amounts into the existing mesh's colour stream (RGBA8:
## 4 bytes per vertex) without building a new mesh.
func _write_mask(mask: PackedFloat32Array) -> void:
	var mesh: ArrayMesh = _mesh_instance.mesh as ArrayMesh
	var stride: int = RenderingServer.mesh_surface_get_format_attribute_stride(mesh.surface_get_format(0), mask.size())
	if stride == 4:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(mask.size() * 4)
		for i: int in mask.size():
			bytes[i * 4] = int(clampf(mask[i], 0.0, 1.0) * 255.0)
			bytes[i * 4 + 3] = 255
		RenderingServer.mesh_surface_update_attribute_region(mesh.get_rid(), 0, 0, bytes)
		return
	# Unexpected layout: rebuild the mesh with the colours instead.
	var arrays: Array = _mesh_arrays
	var rebuilt: ArrayMesh = ArrayMesh.new()
	rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = rebuilt


## Returns the number of instances placed.
func _scatter(cover: GroundCover, layer: GroundCoverLayer, index: int, verts: PackedVector3Array, normals: PackedVector3Array, mask: PackedFloat32Array, make: bool) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(noise_seed, index, cover.patch_seed))
	var cells: int = (rows - 1) * (columns - 1)
	var dz: float = length / float(rows - 1)
	var area: float = 0.0
	for r: int in rows - 1:
		area += (_row_half[r] + outside_width) * 2.0 * dz
	var tries: int = int(area / 100.0 * layer.density)
	var weight_max: float = maxf(layer.on_grass, 1.0 - layer.on_grass)
	var tiles: Dictionary[Vector2i, Array] = {}
	var tile: float = cover.tile_size
	for t: int in tries:
		var cell: int = rng.randi_range(0, cells - 1)
		var r: int = cell / (columns - 1)
		var c: int = cell % (columns - 1)
		var u: float = rng.randf()
		var v: float = rng.randf()
		var a: int = r * columns + c
		var m: float = lerpf(lerpf(mask[a], mask[a + 1], u), lerpf(mask[a + columns], mask[a + columns + 1], u), v)
		var w: float = (m * layer.on_grass + (1.0 - m) * (1.0 - layer.on_grass)) / weight_max
		if rng.randf() > w:
			continue
		var x: float = lerpf(_column_x(r, c), _column_x(r, c + 1), u)
		var half: float = _row_half[r]
		match layer.zone:
			GroundCoverLayer.Zone.PLAY:
				if absf(x) > half - wall_width * 0.6:
					continue
			GroundCoverLayer.Zone.EDGE:
				if absf(x) < half - wall_width or absf(x) > half + outside_width * 0.5:
					continue
			GroundCoverLayer.Zone.OUTSIDE:
				if absf(x) < half:
					continue
		var p: Vector3 = verts[a].lerp(verts[a + 1], u).lerp(verts[a + columns].lerp(verts[a + columns + 1], u), v)
		var n: Vector3 = normals[a].lerp(normals[a + columns + 1], v).normalized()
		var up: Vector3 = Vector3.UP.lerp(n, layer.follow_ground).normalized()
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU)
		basis = Basis(Quaternion(Vector3.UP, up)) * basis
		basis = basis.scaled(Vector3.ONE * rng.randf_range(layer.scale_min, layer.scale_max))
		var key: Vector2i = Vector2i(floori(p.x / tile), floori(p.z / tile))
		if not tiles.has(key):
			tiles[key] = []
		tiles[key].append(Transform3D(basis, p - up * layer.sink))
	var placed: int = 0
	for key: Vector2i in tiles:
		placed += tiles[key].size()
	if not make:
		return placed
	for key: Vector2i in tiles:
		var list: Array = tiles[key]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = layer.get_mesh()
		mm.instance_count = list.size()
		for i: int in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, Color(rng.randf(), rng.randf(), 0.0, 1.0))
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = layer.get_material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if layer.cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = layer.visibility_end
		mmi.visibility_range_end_margin = layer.visibility_end * 0.15
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_cover.add_child(mmi)
	return placed


# --- Mesh and collision ----------------------------------------------------

func _build_mesh() -> void:
	var count: int = columns * rows
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	verts.resize(count)
	normals.resize(count)
	for r: int in rows:
		for c: int in columns:
			var idx: int = r * columns + c
			var g: Vector2 = _grid_xz(r, c)
			verts[idx] = Vector3(g.x, heights[idx], g.y)
	for r: int in rows:
		for c: int in columns:
			# Central differences (one-sided on the border): across x down-rows.
			var across: Vector3 = verts[r * columns + mini(c + 1, columns - 1)] - verts[r * columns + maxi(c - 1, 0)]
			var along: Vector3 = verts[mini(r + 1, rows - 1) * columns + c] - verts[maxi(r - 1, 0) * columns + c]
			normals[r * columns + c] = across.cross(along).normalized()
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize((columns - 1) * (rows - 1) * 6)
	var i: int = 0
	for r: int in rows - 1:
		for c: int in columns - 1:
			var a: int = r * columns + c
			var b: int = a + 1
			var d: int = a + columns
			var e: int = d + 1
			# Godot's front faces wind clockwise; seen from above these do.
			indices[i] = a
			indices[i + 1] = e
			indices[i + 2] = b
			indices[i + 3] = a
			indices[i + 4] = d
			indices[i + 5] = e
			i += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	# Grass amount per vertex (red); bare until the ground cover fills it in.
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(count)
	colors.fill(Color(0.0, 0.0, 0.0, 1.0))
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh_arrays = arrays
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material


func _build_collision() -> void:
	for child: Node in _body.get_children():
		child.free()
	var mesh: ArrayMesh = _mesh_instance.mesh as ArrayMesh
	if transition_surface:
		_body.add_to_group(&"transitions")
	elif _body.is_in_group(&"transitions"):
		_body.remove_from_group(&"transitions")
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	_body.add_child(col)
	if boundary_height > 0.0:
		_build_boundary(-1.0)
		_build_boundary(1.0)


## Upright boxes along one outer edge, one per BOUNDARY_SEGMENT, from below the
## lowest edge point to boundary_height above the highest.
func _build_boundary(side: float) -> void:
	var edge_c: int = 0 if side < 0.0 else columns - 1
	var dz: float = length / float(rows - 1)
	var steps: int = maxi(1, int(ceil(length / BOUNDARY_SEGMENT)))
	for s: int in steps:
		var r0: int = int(floor(length * s / steps / dz))
		var r1: int = mini(rows - 1, int(ceil(length * (s + 1) / steps / dz)))
		var low: float = INF
		var high: float = -INF
		for r: int in range(r0, r1 + 1):
			low = minf(low, heights[r * columns + edge_c])
			high = maxf(high, heights[r * columns + edge_c])
		var a: Vector2 = _grid_xz(r0, edge_c)
		var b: Vector2 = _grid_xz(r1, edge_c)
		var along: Vector3 = Vector3(b.x - a.x, 0.0, b.y - a.y)
		var outward: Vector3 = Vector3.UP.cross(along).normalized() * -side
		var bottom: float = low - 10.0
		var top: float = high + boundary_height
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.0, top - bottom, along.length() + 1.0)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = box
		var mid: Vector2 = (a + b) * 0.5
		col.transform = Transform3D(Basis.looking_at(along.normalized(), Vector3.UP), Vector3(mid.x, (top + bottom) * 0.5, mid.y) + outward * 0.5)
		_body.add_child(col)
