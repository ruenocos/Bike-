extends Node3D
## Close-up of the tank and crew for checking the look. Run with Movie Maker:
## <exe> --path . --write-movie <abs>.avi --fixed-fps 30 --quit-after 30 res://debug/crew_portrait.tscn -- --angle=210
## --angle sets the camera yaw around the tank; --look=commander zooms in.

const RIG: PackedScene = preload("res://tank/tank_rig.tscn")


func _ready() -> void:
	var angle: float = 205.0
	var look: Vector3 = Vector3(0.0, 1.7, 0.2)
	var far: float = 6.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--angle="):
			angle = arg.trim_prefix("--angle=").to_float()
		elif arg == "--look=commander":
			look = Vector3(0.3, 2.65, 0.4)
			far = 1.8
	add_child(RIG.instantiate())
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	sun.light_energy = 0.75
	add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.7, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.35
	add_child(env)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	add_child(ground)
	var cam: Camera3D = Camera3D.new()
	var dir: Vector3 = Vector3(sin(deg_to_rad(angle)), 0.28, cos(deg_to_rad(angle))).normalized()
	add_child(cam)
	cam.look_at_from_position(look + dir * far, look, Vector3.UP)
	cam.current = true
