@tool
class_name BoostGate
extends Area3D
## A glowing ring on a risky option (a tight gap between trees, the end of a
## rail, the air off a big kicker, over a gap). Riding through it once gives
## speed and score, and counts toward upgrade rerolls (RunRules). It faces
## along its -Z: rotate it to face the way you'd fly / ride through.

## Speed added on the way through (m/s, never past PlayerTuning.speed_cap).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var speed_boost: float = 6.0
## Points (added to the combo, so it keeps a combo going).
@export_range(0, 5000, 10) var score: int = 300
## Ring size (m). The trigger matches it.
@export_range(1.0, 10.0, 0.1, "suffix:m") var radius: float = 3.2:
	set(v):
		radius = v
		_update_size()

## Gate Magnet only: how far before the gate the pull starts (m).
@export_range(5.0, 200.0, 1.0, "suffix:m") var magnet_look_ahead: float = 70.0

var _taken: bool = false
var _player: Player

@onready var _ring: Node3D = $Ring


func _ready() -> void:
	add_to_group(&"boost_gates")
	_update_size()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


## Gate Magnet upgrade (v0.13): coming up on the gate (within
## `magnet_look_ahead`) and within the player's gate_magnet_radius to the
## side, the gate asks the player for a sideways pull toward its centre (capped by the
## player), and the ring pulses.
func _physics_process(_delta: float) -> void:
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
	var going: Vector3 = _player.velocity.normalized() if _player.velocity.length() > 1.0 else -global_basis.z
	var ahead: float = to.dot(going)
	var side: Vector3 = to - going * ahead
	# Reach is sideways; it starts `magnet_look_ahead` m before the gate.
	if ahead <= 0.0 or ahead > magnet_look_ahead or side.length() > reach + radius:
		_ring.scale = Vector3.ONE * radius
		return
	if side.length() > 0.2:
		# Eases off as you line up, so it doesn't swing you past the centre.
		_player.add_side_pull(side, _player.tuning.gate_magnet_pull * clampf(side.length() / 2.0, 0.0, 1.0))
	_ring.scale = Vector3.ONE * radius * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02))


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
	player.speed = t.capped(player.speed + speed_boost)
	if player.state_machine.get_state_name() == &"Air" and player.velocity.length() > 1.0:
		player.velocity += player.velocity.normalized() * speed_boost
	player.flash_boost()
	Events.speed_gained.emit(speed_boost)
	player.combo.add_action(score)
	Events.gate_collected.emit(score)
	# Pop and vanish.
	var ring: Node3D = $Ring
	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", ring.scale * 1.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.25)
	tween.tween_callback(ring.hide)
