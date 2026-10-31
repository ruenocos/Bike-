extends Node
## Audio buses. Creates them at startup, so there's no bus-layout file to
## keep in sync:
##   Master
##     SFX    one-shots (landings, tricks, crashes) and the rolling / grind loops
##     Wind   the speed wind, through a low-pass that opens up with speed
##     Rumble the collapse
## The sounds themselves live in scenes (player/rider_audio.tscn) with their
## volumes exported there; this autoload only owns the buses and the wind filter.
##
## Godot note: an audio bus is a mixer channel. AudioStreamPlayer.bus picks
## which one a sound goes through; effects (like the low-pass) sit on the bus.

const SFX: StringName = &"SFX"
const WIND: StringName = &"Wind"
const RUMBLE: StringName = &"Rumble"

var _wind_filter: AudioEffectLowPassFilter


func _ready() -> void:
	for bus: StringName in [SFX, WIND, RUMBLE]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	_wind_filter = AudioEffectLowPassFilter.new()
	_wind_filter.cutoff_hz = 800.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(WIND), _wind_filter)


## The wind's low-pass cutoff (Hz): low = muffled, high = roaring.
func set_wind_cutoff(hz: float) -> void:
	if _wind_filter != null:
		_wind_filter.cutoff_hz = hz
