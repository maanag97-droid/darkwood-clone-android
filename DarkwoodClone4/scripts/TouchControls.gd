extends CanvasLayer

## Virtual touch controls for Android.
## LEFT side: floating joystick. RIGHT side: SHOOT / MELEE / RELOAD / SPRINT / LIGHT / PAUSE.
## Buttons are hit-tested from raw touches, because Godot only emulates mouse for the
## first finger -- GUI Buttons can't be pressed while the joystick finger is down.

@onready var joystick_base: Control = $JoystickBase
@onready var joystick_knob: Control = $JoystickBase/Knob
@onready var btn_shoot:      Button = $BtnShoot
@onready var btn_melee:      Button = $BtnMelee
@onready var btn_reload:     Button = $BtnReload
@onready var btn_sprint:     Button = $BtnSprint
@onready var btn_flashlight: Button = $BtnFlashlight
@onready var btn_pause:      Button = $BtnPause

const JOYSTICK_RADIUS: float = 80.0

var joystick_touch_index: int = -1
var sprint_touch_index: int = -1
var shoot_touch_index: int = -1
var joystick_origin: Vector2 = Vector2.ZERO
var joystick_value: Vector2 = Vector2.ZERO

var player: Node = null

func _ready() -> void:
	# Raw-touch handling below owns these; stop GUI from double-triggering via emulated mouse.
	for b in [btn_shoot, btn_melee, btn_reload, btn_sprint, btn_flashlight, btn_pause]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.position = Vector2.ZERO

func _get_player() -> Node:
	if is_instance_valid(player):
		return player
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	return player

func _process(_delta: float) -> void:
	var p: Node = _get_player()
	if p == null:
		return
	p.set_move_input(joystick_value)
	p.set_sprint_input(sprint_touch_index != -1)
	if joystick_value.length() > 0.1:
		p.set_aim_position(p.global_position + joystick_value * 200.0)
	# Hold SHOOT to keep firing (player cooldown limits the rate)
	if shoot_touch_index != -1:
		p.shoot()

func _hit(btn: Button, pos: Vector2) -> bool:
	return btn.visible and btn.get_global_rect().has_point(pos)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos: Vector2 = event.position
	if event.pressed:
		var p: Node = _get_player()
		if _hit(btn_pause, pos):
			_on_pause_pressed()
			return
		if _hit(btn_shoot, pos):
			shoot_touch_index = event.index
			return
		if _hit(btn_sprint, pos):
			sprint_touch_index = event.index
			return
		if p and _hit(btn_melee, pos):
			p.do_melee()
			return
		if p and _hit(btn_reload, pos):
			p.start_reload()
			return
		if p and _hit(btn_flashlight, pos):
			p.toggle_flashlight()
			return
		if pos.x < get_viewport().get_visible_rect().size.x * 0.45 and joystick_touch_index == -1:
			joystick_touch_index = event.index
			joystick_origin = pos
			joystick_base.position = pos - joystick_base.pivot_offset
			joystick_base.visible = true
			joystick_knob.position = Vector2.ZERO
	else:
		if event.index == joystick_touch_index:
			joystick_touch_index = -1
			joystick_value = Vector2.ZERO
			joystick_knob.position = Vector2.ZERO
			joystick_base.visible = false
		if event.index == sprint_touch_index:
			sprint_touch_index = -1
		if event.index == shoot_touch_index:
			shoot_touch_index = -1

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_index:
		var delta: Vector2 = event.position - joystick_origin
		var clamped: Vector2 = delta.limit_length(JOYSTICK_RADIUS)
		joystick_knob.position = clamped
		joystick_value = clamped / JOYSTICK_RADIUS

func _on_pause_pressed() -> void:
	var mains: Array = get_tree().get_nodes_in_group("main")
	for m in mains:
		if m.has_method("_on_pause_btn_pressed"):
			m._on_pause_btn_pressed()
