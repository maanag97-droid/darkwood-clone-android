extends Node

signal night_started
signal day_started
signal time_changed(normalized)

var day_duration: float = 90.0
var night_duration: float = 60.0
var current_time: float = 0.0
var is_night: bool = false
var day_number: int = 1

## CanvasModulate colours — Darkwood style: world stays near-black at all times.
## PointLight2D nodes (flashlight, campfire, pickups) punch through as the ONLY illumination.
## Even "day" is oppressively dark — just a faint desaturated grey, not readable daylight.
var day_modulate:   Color = Color(0.06, 0.06, 0.055, 1.0)  # near-black with faint grey tint
var dusk_modulate:  Color = Color(0.04, 0.025, 0.02, 1.0)  # deep amber-black dusk
var night_modulate: Color = Color(0.01, 0.01, 0.018, 1.0)  # almost pure black night

@onready var canvas_mod: CanvasModulate = $"../CanvasModulate"
@onready var time_label: Label = $"../HUD/TopRight/TimeLabel"

func _ready() -> void:
	# Start in day
	if canvas_mod:
		canvas_mod.color = day_modulate

func _process(delta: float) -> void:
	current_time += delta
	var total: float = day_duration + night_duration
	var cycle_time: float = fmod(current_time, total)
	time_changed.emit(cycle_time / total)

	if cycle_time < day_duration:
		if is_night:
			is_night = false
			day_number += 1
			day_started.emit()
		var dp: float = cycle_time / day_duration
		if dp > 0.75:
			# Transition to dusk over last 25% of day
			var t: float = (dp - 0.75) / 0.25
			_set_modulate(day_modulate.lerp(dusk_modulate, t))
		else:
			_set_modulate(day_modulate)
		if time_label:
			time_label.text = "DAY %d" % day_number
	else:
		if not is_night:
			is_night = true
			night_started.emit()
		var np: float = (cycle_time - day_duration) / night_duration
		if np < 0.12:
			_set_modulate(dusk_modulate.lerp(night_modulate, np / 0.12))
		elif np > 0.88:
			_set_modulate(night_modulate.lerp(dusk_modulate, (np - 0.88) / 0.12))
		else:
			_set_modulate(night_modulate)
		if time_label:
			time_label.text = "NIGHT %d" % day_number

func _set_modulate(col: Color) -> void:
	if canvas_mod:
		canvas_mod.color = col

func get_night_multiplier() -> float:
	return 1.5 if is_night else 1.0
