extends CanvasLayer

@onready var health_bar:  ProgressBar = $MarginContainer/VBox/HealthRow/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBox/StaminaRow/StaminaBar
@onready var ammo_label:  Label       = $MarginContainer/VBox/AmmoRow/AmmoLabel
@onready var score_label: Label       = $MarginContainer/VBox/ScoreRow/ScoreLabel
@onready var reload_label: Label      = $ReloadLabel
@onready var night_warning: Label     = $NightWarning
@onready var pickup_popup: Label      = $PickupPopup

var night_warning_timer: float = 0.0
var pickup_popup_timer: float = 0.0
var _last_score: int = -1

func _process(delta: float) -> void:
	# Night warning fade
	if night_warning_timer > 0.0:
		night_warning_timer -= delta
		night_warning.modulate.a = min(1.0, night_warning_timer * 2.0)
	else:
		night_warning.modulate.a = max(0.0, night_warning.modulate.a - delta * 0.5)
	# Pickup popup fade
	if pickup_popup_timer > 0.0:
		pickup_popup_timer -= delta
		pickup_popup.modulate.a = min(1.0, pickup_popup_timer * 2.0)
		pickup_popup.position.y -= delta * 18.0
	else:
		pickup_popup.modulate.a = max(0.0, pickup_popup.modulate.a - delta * 1.5)

func update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	var pct: float = current / maximum
	if pct > 0.5:
		health_bar.modulate = Color.GREEN
	elif pct > 0.25:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func update_stamina(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func update_ammo(current: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [current, reserve]
	if current == 0:
		ammo_label.modulate = Color.RED
	elif current <= 3:
		ammo_label.modulate = Color.YELLOW
	else:
		ammo_label.modulate = Color.WHITE

func update_score(score: int) -> void:
	if score != _last_score:
		_last_score = score
		score_label.text = "%d" % score

func show_reload(reloading: bool) -> void:
	reload_label.visible = reloading

func show_pickup_message(msg: String, col: Color) -> void:
	pickup_popup.text = msg
	pickup_popup.modulate = col
	pickup_popup.modulate.a = 1.0
	pickup_popup.position = Vector2(get_viewport().get_visible_rect().size / 2.0) + Vector2(-60, 80)
	pickup_popup_timer = 2.0

func show_night_warning() -> void:
	night_warning_timer = 4.0
	night_warning.text = "NIGHT IS FALLING..."
	night_warning.modulate = Color(0.9, 0.3, 0.1, 1.0)

func show_day_message() -> void:
	night_warning_timer = 3.0
	night_warning.text = "YOU SURVIVED THE NIGHT"
	night_warning.modulate = Color(0.8, 1.0, 0.8, 1.0)
