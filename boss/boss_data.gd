class_name BossData
extends Resource
## One boss fight's numbers (boss/data/*.tres, one file per boss tier).
## BossFight picks them in order: the first boss uses the first file, the
## second the second, and the last one repeats with `repeat_scale` more
## health per extra fight. Tune them in the Inspector.

@export var display_name: String = "WARDEN"
## Small line under the name on the intro card.
@export var subtitle: String = "Guardian of the drop"
## Ink colour of the boss's armour (multiplies its texture).
@export var tint: Color = Color(1, 1, 1, 1)
## Size of the mech (1 = the model's own 5.3 m).
@export_range(1.0, 6.0, 0.1) var model_scale: float = 3.0

@export_group("Health and time")
@export_range(10.0, 2000.0, 5.0) var max_health: float = 160.0
## Seconds before the arena collapses under you (run over). Crashes and
## falls take time off.
@export_range(30.0, 600.0, 5.0, "suffix:s") var time_limit: float = 150.0
## Below this share of health it gets angry: faster attacks, more shells.
@export_range(0.0, 1.0, 0.05) var phase_two_at: float = 0.5
## Extra health per repeat after the last tier (0.25 = +25% each time).
@export_range(0.0, 2.0, 0.05) var repeat_scale: float = 0.3

@export_group("Ramming (how you hurt it)")
## Slower than this into it is a crash for you, no damage.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var ram_min_speed: float = 14.0
## Damage of a ram at ram_min_speed...
@export_range(0.0, 200.0, 1.0) var ram_damage: float = 12.0
## ...plus this much per m/s above it.
@export_range(0.0, 20.0, 0.1) var ram_damage_per_speed: float = 0.8
## Coming down onto it from the air multiplies the damage.
@export_range(1.0, 5.0, 0.1) var stomp_multiplier: float = 1.6
## While it staggers after a hit it can't be hurt again (s).
@export_range(0.0, 5.0, 0.05, "suffix:s") var hit_cooldown: float = 0.9

@export_group("Movement")
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var walk_speed: float = 5.0
## Seconds of walking between attacks (phase two: times phase_two_tempo).
@export_range(0.5, 20.0, 0.1, "suffix:s") var attack_interval: float = 4.5
@export_range(0.2, 1.0, 0.05) var phase_two_tempo: float = 0.65

@export_group("Shockwave (hop over it)")
## Weight of this attack in the random pick (0 = never).
@export_range(0.0, 10.0, 0.1) var shockwave_weight: float = 1.0
@export_range(5.0, 80.0, 1.0, "suffix:m/s") var shockwave_speed: float = 24.0
## Rings per slam (phase two adds one).
@export_range(1, 5) var shockwave_rings: int = 1
## Seconds between rings of one slam.
@export_range(0.1, 3.0, 0.05, "suffix:s") var shockwave_gap: float = 0.7

@export_group("Shell barrage (steer out of the circles)")
@export_range(0.0, 10.0, 0.1) var mortar_weight: float = 1.0
## Shells per barrage (phase two adds two).
@export_range(1, 20) var mortar_count: int = 5
## From the red circle appearing to the shell landing (s).
@export_range(0.3, 5.0, 0.05, "suffix:s") var mortar_delay: float = 1.5
@export_range(2.0, 20.0, 0.5, "suffix:m") var mortar_radius: float = 6.0
## Shells aim this many seconds ahead of you (0 = where you are).
@export_range(0.0, 3.0, 0.05, "suffix:s") var mortar_lead: float = 0.8

@export_group("Charge (get out of the way, or meet it fast)")
@export_range(0.0, 10.0, 0.1) var charge_weight: float = 0.7
@export_range(5.0, 80.0, 1.0, "suffix:m/s") var charge_speed: float = 26.0
## Wind-up before it runs (s): the eye glows red.
@export_range(0.2, 3.0, 0.05, "suffix:s") var charge_windup: float = 0.9
@export_range(0.5, 6.0, 0.1, "suffix:s") var charge_time: float = 2.2

@export_group("Reward")
## Added to the run score when it goes down.
@export_range(0, 100000, 100) var score: int = 5000
## Free upgrade rerolls for beating it.
@export_range(0, 5) var reward_rerolls: int = 1
