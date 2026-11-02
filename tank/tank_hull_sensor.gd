class_name TankHullSensor
extends Area3D
## The tank's real size for obstacles (child of the Player in tank/tank.tscn,
## v0.32). The Player's body stays the small sphere, so riding on terrain, rails
## and transitions is the same as ever; this box only looks at bodies in group
## "obstacles" (generic: anything in that group works):
##   crushable: flattened when the hull reaches it, not only the sphere
##   solid, ahead of the nose: a crash
##   solid, beside the hull: a scrape that pushes you off it, speed barely hurt
## Rail ledges are ignored: the sphere still crashes into those, and you need
## to hop onto them with the hull overlapping.

## Off = the old behaviour: only the small sphere meets obstacles.
@export var enabled: bool = true
## Half the hull's width (m) that counts as head-on; wider hits only scrape.
@export_range(0.1, 3.0, 0.05, "suffix:m") var head_on_half_width: float = 0.9
## Sideways push and speed loss from a scrape.
@export_range(0.0, 200.0, 1.0, "suffix:m/s²") var scrape_push: float = 90.0
@export_range(0.0, 0.3, 0.01) var scrape_speed_cost: float = 0.03

@onready var player: Player = get_parent() as Player

## Solid bodies overlapping the hull, for the push while they do.
var _scraping: Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(body: Node3D) -> void: _scraping.erase(body))


func _physics_process(_delta: float) -> void:
	for i: int in range(_scraping.size() - 1, -1, -1):
		var body: Node3D = _scraping[i]
		if not is_instance_valid(body):
			_scraping.remove_at(i)
			continue
		var away: Vector3 = player.global_position - body.global_position
		player.add_side_pull(away, scrape_push)


func _on_body_entered(body: Node3D) -> void:
	if not enabled or not body.is_in_group(&"obstacles") or body.get_parent() is Rail:
		return
	var state: StringName = player.state_machine.get_state_name()
	if state == &"Grind" or state == &"Bail":
		return
	if player.tuning.crushes_props and body.is_in_group(&"crushable"):
		player.crush_prop(body as CollisionObject3D)
		return
	# Flying over it is fine: the sphere still lands on whatever it lands on.
	if state == &"Air":
		return
	var to_body: Vector3 = body.global_position - player.global_position
	var forward: Vector3 = player.get_heading_dir()
	var across: float = absf(to_body.dot(forward.cross(Vector3.UP).normalized()))
	if to_body.dot(forward) > 0.0 and across < head_on_half_width and player.speed > player.tuning.crash_min_impact:
		player.hit_by_hazard(body.name, body as PhysicsBody3D)
	else:
		player.speed *= 1.0 - scrape_speed_cost
		_scraping.append(body)
