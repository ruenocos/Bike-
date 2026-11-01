@tool
class_name BoostGate
extends Area3D
## A glowing ring on a risky option (a tight gap between trees, the end of a
## rail, the air off a big kicker, over a gap). Riding through it once gives
## speed and score, and counts toward upgrade rerolls (RunRules). It faces
## along its -Z: rotate it to face the way you'd fly / ride through.

## Speed added on the way through (m/s, never past max_speed).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var speed_boost: float = 6.0
## Points (added to the combo, so it keeps a combo going).
@export_range(0, 5000, 10) var score: int = 300
## Ring size (m). The trigger matches it.
@export_range(1.0, 10.0, 0.1, "suffix:m") var radius: float = 3.2:
	set(v):
		radius = v
		_update_size()

var _taken: bool = false
var _player: Player


func _ready() -> void:
	add_to_group(&"boost_gates")
	_update_size()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


## Gate Magnet upgrade (v0.13): within the player's gate_magnet_radius the
## gate pulls you sideways toward its centre, and the ring pulses.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _taken:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var reach: float = _player.tuning.gate_magnet_radius
	if reach <= 0.0:
		return
	var to: Vector3 = global_position - _player.global_position
	var dist: float = to.length()
	var ring: Node3D = $Ring
	if dist > reach + radius or dist < 0.5:
		ring.scale = Vector3.ONE * radius
		return
	var going: Vector3 = _player.velocity.normalized() if _player.velocity.length() > 1.0 else -global_basis.z
	var side: Vector3 = to - going * to.dot(going)
	if to.dot(going) <= 0.0 or side.length() < 0.05:
		return
	var pull: Vector3 = side.normalized() * minf(_player.tuning.gate_magnet_pull * delta, side.length())
	if _player.state_machine.get_state_name() == &"Air":
		_player.velocity += pull
	elif _player.is_on_floor():
		_player.ground_dir = _player.tangent_dir(_player.ground_dir * _player.speed + pull * 3.0, _player.ground_normal)
	ring.scale = Vector3.ONE * radius * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02))


func _update_size() -> void:
	var ring: MeshInstance3D = get_node_or_null(^"Ring") as MeshInstance3D
	if ring != null:
		ring.scale = Vector3.ONE * radius
	var col: CollisionShape3D = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if col != null:
		var disc: CylinderShape3D = CylinderShape3D.new()
		disc.radius = radius
		disc.height = 2.0
		col.shape = disc


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if _taken or player == null:
		return
	_taken = true
	var t: PlayerTuning = player.tuning
	player.speed = minf(player.speed + speed_boost, t.max_speed)
	if player.state_machine.get_state_name() == &"Air" and player.velocity.length() > 1.0:
		player.velocity += player.velocity.normalized() * speed_boost
	player.flash_boost()
	player.combo.add_action(score)
	Events.gate_collected.emit(score)
	# Pop and vanish.
	var ring: Node3D = $Ring
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", ring.scale * 1.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.25)
	tween.tween_callback(ring.hide)
