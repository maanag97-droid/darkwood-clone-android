extends Node2D

@onready var hud: CanvasLayer = $HUD
@onready var day_night: Node = $DayNightCycle
@onready var world: Node2D = $World
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var pause_screen: CanvasLayer = $PauseScreen
@onready var final_score_label: Label = $GameOverScreen/VBox/FinalScore
@onready var touch_controls: CanvasLayer = $TouchControls

var _camera: Camera2D = null
var _shake_intensity: float = 0.0
const SHAKE_DECAY: float = 10.0
var _paused: bool = false

func _ready() -> void:
	add_to_group("main")
	hud.add_to_group("hud")
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Node = players[0]
		p.health_changed.connect(hud.update_health)
		p.stamina_changed.connect(hud.update_stamina)
		p.ammo_changed.connect(hud.update_ammo)
		p.reload_state_changed.connect(hud.show_reload)
		p.player_died.connect(_on_player_died)
		p.camera_shake.connect(_on_camera_shake)
		_camera = p.get_node_or_null("Camera2D")

	day_night.night_started.connect(_on_night_started)
	day_night.day_started.connect(_on_day_started)

	touch_controls.visible = DisplayServer.is_touchscreen_available()
	pause_screen.visible = false
	game_over_screen.visible = false
	# Pause menu must keep processing while the tree is paused, or Resume/ESC never work
	pause_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	var pi := Node.new()
	pi.name = "PauseInput"
	pi.process_mode = Node.PROCESS_MODE_ALWAYS
	pi.set_script(load("res://scripts/PauseInput.gd"))
	add_child(pi)

func _process(delta: float) -> void:
	hud.update_score(GameManager.score)
	if _camera and _shake_intensity > 0.0:
		_shake_intensity = max(0.0, _shake_intensity - delta * SHAKE_DECAY)
		_camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		if _shake_intensity <= 0.0:
			_camera.offset = Vector2.ZERO

func _on_camera_shake(intensity: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)

func _on_player_died() -> void:
	game_over_screen.visible = true
	hud.update_score(GameManager.score)
	final_score_label.text = "SCORE: %d" % GameManager.score

func _on_night_started() -> void:
	hud.show_night_warning()
	world.spawn_night_enemies()
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		e.night_aggro_multiplier = day_night.get_night_multiplier()

func _on_day_started() -> void:
	GameManager.register_day_survived()
	hud.show_day_message()
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		e.night_aggro_multiplier = 1.0

func _on_restart_pressed() -> void:
	GameManager.reset()
	get_tree().paused = false
	_paused = false
	get_tree().reload_current_scene()

func _on_pause_btn_pressed() -> void:
	_toggle_pause()

func _on_resume_pressed() -> void:
	_toggle_pause()

func _toggle_pause() -> void:
	if game_over_screen.visible:
		return
	_paused = not _paused
	get_tree().paused = _paused
	pause_screen.visible = _paused

