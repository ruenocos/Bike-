class_name StageStats
extends Node
## Keeps score for one stage: time on the clock, the best combo banked and
## the total banked during the stage. The game starts and stops it.

var time: float = 0.0
var best_combo: int = 0
var score: int = 0
var running: bool = false


func _ready() -> void:
	Events.combo_banked.connect(_on_combo_banked)


func start() -> void:
	time = 0.0
	best_combo = 0
	score = 0
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
