class_name TankCannon
extends Node
## The tank's cannon (child of the Player in tank/tank.tscn):
##   Hop = recoil: the Player's hop fires the cannon down and back (flash,
##   smoke, a short impact frame). The pop itself is the Player's hop.
##   Blast = `cannon_blast` (RB): a shot backward for `blast_speed` m/s, up to
##   the top speed, then `blast_cooldown` seconds to reload.
## Numbers are in PlayerTuning "Tank"; goes through the Player's own speed and
## boost, so it works on any ground the Player can ride.

@onready var player: Player = get_parent() as Player
@onready var rig: TankRig = player.get_node("Visual/TankRig") as TankRig
@onready var fx: AnimeFx = player.get_node("AnimeFx") as AnimeFx
@onready var vfx: RiderVfx = player.get_node("RiderVfx") as RiderVfx

var cooldown: float = 0.0
## Bots fire when they're slow, so recordings show it.
var _auto: bool = false


func _ready() -> void:
	player.hopped.connect(_on_hop)
	player.air_hopped.connect(_on_hop)
	_auto = OS.get_cmdline_user_args().has("--autopilot")


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	# Frozen = a menu is up (Game._freeze_player): nothing to fire.
	if not player.is_physics_processing():
		return
	var wants: bool = Input.is_action_just_pressed(&"cannon_blast")
	if _auto and player.is_grounded() and player.speed < player.tuning.max_speed * 0.85:
		wants = true
	if wants:
		blast()


## Fires backward if it's loaded. True if it fired.
func blast() -> bool:
	if cooldown > 0.0 or player.state_machine.get_state_name() == &"Bail":
		return false
	cooldown = player.tuning.blast_cooldown
	var gained: float = player.add_speed(player.tuning.blast_speed)
	player.flash_boost()
	Events.cannon_fired.emit(&"boost")
	if gained > 0.0:
		Events.speed_gained.emit(gained)
	rig.fire()
	vfx.puff(0.6)
	return true


func _on_hop() -> void:
	rig.fire()
	vfx.puff(0.45)
	fx.cannon_shot()
	Events.cannon_fired.emit(&"hop")
	# A hop adds height, not ground speed, so no speed_gained unless a tuning
	# gives the recoil a forward kick.
	if player.tuning.hop_speed_kick > 0.0:
		player.speed = minf(player.speed + player.tuning.hop_speed_kick, player.tuning.max_speed)
		Events.speed_gained.emit(player.tuning.hop_speed_kick)
