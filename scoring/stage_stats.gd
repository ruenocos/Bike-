class_name StageStats
extends Node
## Keeps score for one stage: time on the clock, the best combo banked, the
## total banked during the stage and the boost gates collected. The game
## starts and stops it.

var time: float = 0.0
var best_combo: int = 0
var score: int = 0
## Boost gates ridden through this stage, and how many the stage has.
var gates: int = 0
var gates_total: int = 0
var running: bool = false


func _ready() -> void:
	Events.combo_banked.connect(_on_combo_banked)
	Events.gate_collected.connect(func(_s: int) -> void:
		if running:
			gates += 1)


func start(stage_gates: int = 0) -> void:
	time = 0.0
	best_combo = 0
	score = 0
	gates = 0
	gates_total = stage_gates
	running = true


func stop() -> void:
	running = false


func _physics_process(delta: float) -> void:
	if running:
		time += delta


func _on_combo_banked(banked: int) -> void:
	if not running:
		return
	score += banked
	best_combo = maxi(best_combo, banked)
