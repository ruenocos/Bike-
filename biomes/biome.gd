@tool
class_name Biome
extends Resource
## One look for a stage (biomes/*.tres): ground colours, what grows, which
## trees and rocks stand there, sky, fog, sun and the far mountains. The game
## applies one per stage (Game `biomes`); the chunks and their gameplay stay
## the same, only the world around them changes.

@export var display_name: String = "Meadow"
## Short line under the name on the stage title card.
@export var subtitle: String = ""

@export_group("Ground")
@export var ground_dirt: Color = Color(0.6, 0.5, 0.39)
@export var ground_grass: Color = Color(0.46, 0.54, 0.24)
@export var ground_rock: Color = Color(0.56, 0.5, 0.45)
@export var grass_tip: Color = Color(0.74, 0.75, 0.38)
## Grass patches and what grows on them.
@export var ground_cover: GroundCover
## Far ground under the valley.
@export var far_ground: Color = Color(0.46, 0.41, 0.33)

@export_group("Set pieces")
## Set pieces made for this biome; the stage's first set piece is one of
## these (v0.16). The shared ones in StageBuilder still come up too.
@export var set_pieces: Array[PackedScene] = []

@export_group("Props")
## Models for trees / rocks / logs (empty = the prop's own).
@export var trees: Array[PackedScene] = []
@export var rocks: Array[PackedScene] = []
## Size of the biome's trees against the prop's own model_scale.
@export_range(0.2, 3.0, 0.01) var tree_scale: float = 1.0
## Multiplies every prop model's colour (e.g. frosted, sun-bleached).
@export var prop_tint: Color = Color.WHITE
## Multiplies the rider's dust / spray / landing puffs.
@export var dust_tint: Color = Color.WHITE
## Colour of the fill on the shadow side of everything (cel dark band).
@export var shadow_tint: Color = Color(0.52, 0.55, 0.78)
## How much of it (0 = plain cel shadows). Keep it low on bright ground.
@export_range(0.0, 1.0, 0.01) var shadow_tint_strength: float = 0.3
## Soft dark blob on the ground under trees, rocks and logs (v0.27), in the
## shadow tint; this is its darkness at the middle (0 = none).
@export_range(0.0, 1.0, 0.01) var contact_shadow: float = 0.35
## How much of each ink line is its surface's own darkened colour (v0.30; 0 =
## all outline_color).
@export_range(0.0, 1.0, 0.01) var outline_local_mix: float = 0.7
## Ink lines around props and the rider (darker = more contrast).
@export var outline_color: Color = Color(0.16, 0.1, 0.09)

@export_group("Sky and light")
## The painted / anime sky (sky/looks/*.tres). Empty = the old procedural
## sky from sky_top / sky_horizon below.
@export var sky_look: SkyLook
@export var sky_top: Color = Color(0.17, 0.29, 0.56)
@export var sky_horizon: Color = Color(1.0, 0.72, 0.5)
@export var ground_horizon: Color = Color(0.95, 0.69, 0.52)
@export var fog_color: Color = Color(0.93, 0.72, 0.56)
@export_range(0.0, 0.01, 0.0001) var fog_density: float = 0.0007
## Height fog (v0.27): extra fog below the rider, so the valley ahead and
## below sinks into haze. It sits `height_fog_below` m under the rider and
## thickens by `height_fog_density` per m further down (0 = off).
@export_range(0.0, 0.2, 0.001) var height_fog_density: float = 0.004
@export_range(0.0, 200.0, 1.0) var height_fog_below: float = 40.0
@export var sun_color: Color = Color(1.0, 0.79, 0.56)
@export_range(0.0, 4.0, 0.05) var sun_energy: float = 1.5
## Sun height above the horizon (deg) and direction (deg around up).
@export_range(2.0, 90.0, 0.5) var sun_elevation: float = 16.5
@export_range(-180.0, 180.0, 0.5) var sun_heading: float = 143.0
@export_range(0.0, 4.0, 0.05) var ambient_energy: float = 1.1
@export_range(0.0, 2.0, 0.01) var saturation: float = 1.12
## Colour response. Linear keeps the palette as painted (v0.30); AgX and
## ACES mute bright colours.
@export_enum("Linear", "Reinhard", "Filmic", "ACES", "AgX") var tonemap: int = 0
## Glow / bloom (bright snow blooms into a white haze: keep it low there).
@export_range(0.0, 2.0, 0.01) var glow_intensity: float = 0.9
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.08
## Overall exposure (tonemap).
@export_range(0.2, 2.0, 0.01) var exposure: float = 1.0
## Large soft light / dark patches on the ground (0 = flat colour), so an
## all-white snowfield still shows its shape.
@export_range(0.0, 0.5, 0.01) var ground_variation: float = 0.06

@export_group("Mountains")
@export var peak_color: Color = Color(0.36, 0.38, 0.52)
@export var haze_color: Color = Color(0.86, 0.66, 0.56)
