@tool
class_name GroundCover
extends Resource
## What grows on a TerrainPatch (chunks/terrain/cover/*.tres): where the grass
## patches are (a world-space noise, so patches run across chunk joins) and
## the layers scattered on top (grass tufts, bushes...). The patch writes the
## grass amount into the terrain's vertex colour, so the ground shader paints
## grass and dirt exactly where the tufts grow.

## Size of the grass / dirt patches (lower = bigger patches).
@export_range(0.001, 0.1, 0.001) var patch_frequency: float = 0.014:
	set(v):
		patch_frequency = v
		_noise = null
@export var patch_seed: int = 7:
	set(v):
		patch_seed = v
		_noise = null
## Share of the ground that is grass (0..1).
@export_range(0.0, 1.0, 0.01) var grass_amount: float = 0.55
## Width of the grass / dirt border (0..1 of the noise range).
@export_range(0.01, 0.5, 0.01) var patch_softness: float = 0.1
## Faces steeper than this (deg) are bare.
@export_range(0.0, 90.0, 0.5) var bare_slope_deg: float = 34.0
## Scatter tiles (m): each tile is one MultiMesh that hides past the layer's
## `visibility_end`.
@export_range(8.0, 200.0, 1.0) var tile_size: float = 48.0
@export var layers: Array[GroundCoverLayer] = []

var _noise: FastNoiseLite


## Grass amount 0..1 at a world position with the ground normal's y.
func mask_at(world: Vector3, normal_y: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = patch_frequency
		_noise.fractal_octaves = 3
		_noise.seed = patch_seed
	var n: float = clampf(_noise.get_noise_2d(world.x, world.z) * 0.8 + 0.5, 0.0, 1.0)
	var edge: float = 1.0 - grass_amount
	var grass: float = smoothstep(edge - patch_softness, edge + patch_softness, n)
	var flat: float = cos(deg_to_rad(bare_slope_deg))
	return grass * smoothstep(flat - 0.06, flat + 0.06, normal_y)
