@tool
class_name SkyLook
extends Resource
## The sky for one biome (sky/looks/*.tres): an anime_sky shader material
## plus how much the world fog may wash over it. Biome `sky_look` points at
## one; BiomeLook swaps it into the WorldEnvironment every stage. Tune the
## material's uniforms in the Inspector (open sky/sky_preview.tscn to see it
## with the mountains and light of a biome).

@export var material: ShaderMaterial
## How much the distance fog tints the sky (Environment fog_sky_affect).
## Keep it low: the shader already hazes its own horizon.
@export_range(0.0, 1.0, 0.01) var fog_sky_affect: float = 0.0

@export_group("Sea of clouds")
## The cloud layer under the valley (FarGround). Lit tops / shadow side /
## deep gaps between the clouds.
@export var sea_light: Color = Color(1.0, 0.93, 0.85)
@export var sea_shadow: Color = Color(0.75, 0.66, 0.85)
@export var sea_gap: Color = Color(0.62, 0.55, 0.7)
@export var sea_rim: Color = Color(1.0, 0.86, 0.65)
@export_range(0.0, 1.0, 0.01) var sea_coverage: float = 0.62
