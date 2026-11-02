extends Node3D
## Sky preview (sky/sky_preview.tscn): the game's environment, sun, far
## ground and mountain rings around a still camera, so a biome's sky can be
## judged without riding. In the editor, pick a biome on the BiomeLook
## node's `preview`. Running it shows `biome` (or `-- --biome=N` from
## `biomes`, `-- --look=res://sky/looks/x.tres` to try another sky,
## `-- --yaw=deg` / `-- --pitch=deg` to turn the camera).

@export var biomes: Array[Biome] = []
@export var biome_index: int = 0
@export var look_override: SkyLook

@onready var biome_look: BiomeLook = $BiomeLook
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	var index: int = biome_index
	var look: SkyLook = look_override
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--biome="):
			index = arg.trim_prefix("--biome=").to_int()
		elif arg.begins_with("--look="):
			look = load(arg.trim_prefix("--look=")) as SkyLook
		elif arg.begins_with("--yaw="):
			camera.rotation_degrees.y = arg.trim_prefix("--yaw=").to_float()
		elif arg.begins_with("--pitch="):
			camera.rotation_degrees.x = arg.trim_prefix("--pitch=").to_float()
	if biomes.is_empty():
		return
	var b: Biome = biomes[clampi(index, 0, biomes.size() - 1)]
	if look != null:
		b = b.duplicate() as Biome
		b.sky_look = look
	biome_look.apply(b)
