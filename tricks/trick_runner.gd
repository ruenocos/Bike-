class_name TrickRunner
extends Node
## Reads right-stick flicks and plays tricks on the Player's Visual.
## Child of Player. The Air state calls `air_update()` each tick; everything
## else only calls `cancel()`. Finished tricks are reported with the
## `trick_completed` signal (signal up), the Player forwards them to scoring.

signal trick_completed(trick: TrickData)

## The four starter tricks. Order does not matter, each has its own direction.
@export var tricks: Array[TrickData] = []

var player: Player

## Trick playing right now (null when none) and its elapsed time (s).
var current: TrickData
var elapsed: float = 0.0
## Trick waiting to start when `current` finishes (chained in its last 30%).
var queued: TrickData
## Name of the last finished trick, for the debug overlay.
var last_trick_name: String = "-"

# Gesture tracking. The stick must start at neutral ("armed"), then pass the
# threshold within the gesture window. A slow push never counts.
var _armed: bool = true
var _push_time: float = 0.0
var _gesture: TrickData


func setup(owner_player: Player) -> void:
	player = owner_player


## Called by Player every physics tick, in every state, so the stick's
## neutral position is always known. Stores at most one fresh gesture.
func poll_gesture(delta: float) -> void:
	var t: PlayerTuning = player.tuning
	_gesture = null
	# get_vector reads four actions as one 2D stick, with the deadzones from the InputMap.
	var stick: Vector2 = Input.get_vector(&"trick_left", &"trick_right", &"trick_up", &"trick_down")
	var magnitude: float = stick.length()
	if magnitude < t.trick_neutral_threshold:
		_armed = true
		_push_time = 0.0
		return
	if not _armed:
		return
	_push_time += delta
	if magnitude >= t.trick_gesture_threshold:
		_armed = false
		if _push_time <= t.trick_gesture_window + delta:
			_gesture = _trick_for(stick)
	elif _push_time > t.trick_gesture_window:
		_armed = false


func _trick_for(stick: Vector2) -> TrickData:
	var dir: TrickData.Direction
	if absf(stick.x) > absf(stick.y):
		dir = TrickData.Direction.RIGHT if stick.x > 0.0 else TrickData.Direction.LEFT
	else:
		# Stick up is negative y.
		dir = TrickData.Direction.UP if stick.y < 0.0 else TrickData.Direction.DOWN
	for trick: TrickData in tricks:
		if trick.direction == dir:
			return trick
	return null


## Air only: start or chain a trick from a fresh gesture and advance the current one.
func air_update(delta: float) -> void:
	if _gesture != null:
		if current == null:
			_start(_gesture)
		elif queued == null and get_progress() >= 1.0 - player.tuning.trick_chain_window:
			queued = _gesture
		_gesture = null

	if current == null:
		return
	elapsed += delta
	if elapsed >= current.duration:
		var done: TrickData = current
		current = null
		elapsed = 0.0
		last_trick_name = done.display_name
		trick_completed.emit(done)
		if queued != null:
			_start(queued)
			queued = null


func _start(trick: TrickData) -> void:
	current = trick
	elapsed = 0.0


## Finishes the running trick right now (landing it close to done counts).
## A queued chain trick is dropped.
func complete_current() -> void:
	if current == null:
		return
	var done: TrickData = current
	cancel()
	last_trick_name = done.display_name
	trick_completed.emit(done)


## True while a trick is unfinished. Touching down now ends it (see Land).
func is_mid_trick() -> bool:
	return current != null


func get_progress() -> float:
	if current == null:
		return 0.0
	return clampf(elapsed / current.duration, 0.0, 1.0)


func cancel() -> void:
	current = null
	queued = null
	elapsed = 0.0


## Extra transform for the Visual: rotation and squash of the running trick,
## in the bike's own space. Identity when no trick is playing.
func get_visual_offset() -> Basis:
	if current == null:
		return Basis.IDENTITY
	var p: float = get_progress()
	# Smoothstep-style ease in/out so the spin winds up and settles.
	var eased: float = p * p * (3.0 - 2.0 * p)
	var rot: Basis = Basis.IDENTITY
	if current.rotation_degrees != 0.0 and current.rotation_axis.length_squared() > 0.0:
		rot = Basis(current.rotation_axis.normalized(), deg_to_rad(current.rotation_degrees) * eased)
	var squash: float = current.squash * sin(p * PI)
	var scale: Vector3 = Vector3(1.0 + squash * 0.3, 1.0 - squash, 1.0 + squash * 0.3)
	return rot * Basis.from_scale(scale)
