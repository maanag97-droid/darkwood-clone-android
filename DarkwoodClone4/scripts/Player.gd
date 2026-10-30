extends CharacterBody2D

# Stats
var max_health: float = 100.0
var health: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var ammo: int = 12
var max_ammo: int = 12
var reserve_ammo: int = 48

# Movement
var walk_speed: float = 180.0
var sprint_speed: float = 300.0
var stamina_drain: float = 30.0
var stamina_regen: float = 20.0
var is_sprinting: bool = false

# Combat
var can_shoot: bool = true
var shoot_cooldown: float = 0.4
var can_melee: bool = true
var melee_cooldown: float = 0.6
var melee_damage: float = 35.0
var bullet_damage: float = 25.0
var is_reloading: bool = false
var reload_time: float = 2.0

# Sprite states
enum SpriteState {STAND, GUN, HOLD, RELOAD, MACHINE, SILENCER}
var current_weapon: int = SpriteState.GUN
var in_melee_anim: bool = false

# Footstep timing
var footstep_timer: float = 0.0
var footstep_interval_walk: float = 0.45
var footstep_interval_sprint: float = 0.25

# Timers
var shoot_timer_val: float = 0.0
var melee_timer_val: float = 0.0
var reload_timer_val: float = 0.0
var hurt_flash_alpha: float = 0.0

# Touch / aim
var touch_aim_position: Vector2 = Vector2.ZERO
var _move_input: Vector2 = Vector2.ZERO
var _touch_sprint: bool = false
var flashlight: PointLight2D = null
var _hurt_layer: CanvasLayer = null

signal health_changed(new_health, max_h)
signal stamina_changed(new_stamina, max_s)
signal ammo_changed(current, reserve)
signal reload_state_changed(is_reloading)
signal player_died
signal camera_shake(intensity)

@onready var sprite: Sprite2D = $Sprite2D
@onready var melee_area: Area2D = $MeleeArea
var hurt_flash: ColorRect = null
@onready var sfx_shoot: AudioStreamPlayer2D = $SFXShoot
@onready var sfx_footstep: AudioStreamPlayer2D = $SFXFootstep

var bullet_scene: PackedScene

var tex_stand: Texture2D
var tex_gun: Texture2D
var tex_hold: Texture2D
var tex_reload: Texture2D
var tex_machine: Texture2D
var tex_silencer: Texture2D

func _ready() -> void:
	bullet_scene = load("res://scenes/Bullet.tscn")
	add_to_group("player")
	_setup_hurt_flash()
	_load_textures()
	_apply_sprite(SpriteState.GUN)
	sprite.offset = Vector2(8, -6)
	touch_aim_position = global_position + Vector2(50, 0)
	_setup_player_light()

func _setup_hurt_flash() -> void:
	# Old HurtFlash lived in world space (rotated with player, wrong size). Use a screen-space layer.
	var old: Node = get_node_or_null("HurtFlash")
	if old:
		old.queue_free()
	_hurt_layer = CanvasLayer.new()
	_hurt_layer.layer = 9
	add_child(_hurt_layer)
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.8, 0.0, 0.0, 1.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.modulate.a = 0.0
	_hurt_layer.add_child(hurt_flash)

func _load_img(path: String) -> Texture2D:
	return load(path) as Texture2D

func _load_textures() -> void:
	var base: String = "res://assets/textures/player/"
	tex_stand    = _load_img(base + "manBrown_stand.png")
	tex_gun      = _load_img(base + "manBrown_gun.png")
	tex_hold     = _load_img(base + "manBrown_hold.png")
	tex_reload   = _load_img(base + "manBrown_reload.png")
	tex_machine  = _load_img(base + "manBrown_machine.png")
	tex_silencer = _load_img(base + "manBrown_silencer.png")

func _apply_sprite(s: int) -> void:
	match s:
		SpriteState.STAND:    if tex_stand:    sprite.texture = tex_stand
		SpriteState.GUN:      if tex_gun:      sprite.texture = tex_gun
		SpriteState.HOLD:     if tex_hold:     sprite.texture = tex_hold
		SpriteState.RELOAD:   if tex_reload:   sprite.texture = tex_reload
		SpriteState.MACHINE:  if tex_machine:  sprite.texture = tex_machine
		SpriteState.SILENCER: if tex_silencer: sprite.texture = tex_silencer

func _setup_player_light() -> void:
	# ── Flashlight cone (directional, shadow-casting) ──────────────────────
	var flash := PointLight2D.new()
	flash.name = "Flashlight"
	var fl_tex: ImageTexture = TextureGen.make_flashlight_texture(512, 256)
	flash.texture = fl_tex
	# Offset so the cone tip sits at the player sprite centre, beam goes right
	flash.offset = Vector2(256, 0)
	flash.energy = 1.15
	flash.color = Color(0.96, 0.91, 0.78, 1.0)
	flash.shadow_enabled = true
	flash.shadow_color = Color(0.0, 0.0, 0.0, 0.92)
	flash.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	flash.shadow_filter_smooth = 1.8
	add_child(flash)
	flashlight = flash

	# ── Ambient lantern glow (round, no shadows — just body illumination) ──
	var glow := PointLight2D.new()
	glow.name = "PlayerGlow"
	if GameManager.light_tex:
		glow.texture = GameManager.light_tex
	glow.energy = 0.38
	glow.scale = Vector2(2.2, 2.2)
	glow.color = Color(1.0, 0.76, 0.45, 1.0)
	glow.shadow_enabled = false
	add_child(glow)

	# Soft heartbeat pulse on the ambient fill only
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(glow, "energy", 0.44, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "energy", 0.30, 1.3).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_stamina(delta)
	_handle_facing()
	_handle_timers(delta)
	_handle_footsteps(delta)
	hurt_flash_alpha = max(0.0, hurt_flash_alpha - delta * 3.0)
	hurt_flash.modulate.a = hurt_flash_alpha

func _handle_movement(_delta: float) -> void:
	var kb_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var input_dir: Vector2 = kb_dir + _move_input
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	is_sprinting = (Input.is_action_pressed("sprint") or _touch_sprint) and stamina > 0.0 and input_dir.length() > 0.1
	var spd: float = sprint_speed if is_sprinting else walk_speed
	velocity = input_dir * spd
	move_and_slide()

func _handle_stamina(delta: float) -> void:
	if is_sprinting:
		stamina = max(0.0, stamina - stamina_drain * delta)
	else:
		stamina = min(max_stamina, stamina + stamina_regen * delta)
	stamina_changed.emit(stamina, max_stamina)

func _handle_facing() -> void:
	var aim_target: Vector2
	if DisplayServer.is_touchscreen_available():
		aim_target = touch_aim_position
	else:
		aim_target = get_global_mouse_position()
	rotation = (aim_target - global_position).angle()

func _handle_timers(delta: float) -> void:
	if shoot_timer_val > 0.0:
		shoot_timer_val -= delta
		if shoot_timer_val <= 0.0:
			can_shoot = true
	if melee_timer_val > 0.0:
		melee_timer_val -= delta
		if melee_timer_val <= 0.0:
			can_melee = true
			if not is_reloading:
				in_melee_anim = false
				_apply_sprite(current_weapon)
	if is_reloading:
		reload_timer_val -= delta
		if reload_timer_val <= 0.0:
			_finish_reload()

func _handle_footsteps(delta: float) -> void:
	if velocity.length() < 10.0:
		footstep_timer = 0.0
		return
	footstep_timer -= delta
	if footstep_timer <= 0.0:
		var interval: float = footstep_interval_sprint if is_sprinting else footstep_interval_walk
		footstep_timer = interval
		if sfx_footstep and not sfx_footstep.playing:
			sfx_footstep.pitch_scale = randf_range(0.9, 1.1)
			sfx_footstep.play()

func _input(event: InputEvent) -> void:
	# Touches are emulated as mouse clicks (device == DEVICE_ID_EMULATION): ignore them,
	# otherwise every joystick touch fires the gun.
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			do_melee()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R: start_reload()
			KEY_1: _equip(SpriteState.GUN)
			KEY_2: _equip(SpriteState.MACHINE)
			KEY_3: _equip(SpriteState.SILENCER)

func set_move_input(dir: Vector2) -> void:
	_move_input = dir

func set_sprint_input(sprinting: bool) -> void:
	_touch_sprint = sprinting

func toggle_flashlight() -> void:
	if flashlight:
		flashlight.enabled = not flashlight.enabled

func set_aim_position(world_pos: Vector2) -> void:
	touch_aim_position = world_pos

func _equip(weapon_state: int) -> void:
	current_weapon = weapon_state
	if not is_reloading and not in_melee_anim:
		_apply_sprite(weapon_state)

func shoot() -> void:
	if health <= 0.0:
		return
	if not can_shoot or is_reloading or ammo <= 0:
		if ammo <= 0 and reserve_ammo > 0:
			start_reload()
		return
	ammo -= 1
	ammo_changed.emit(ammo, reserve_ammo)
	can_shoot = false
	shoot_timer_val = shoot_cooldown

	if sfx_shoot:
		sfx_shoot.pitch_scale = randf_range(0.92, 1.08)
		sfx_shoot.play()

	var bullet: Node = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(30, 0).rotated(rotation)
	bullet.rotation = rotation
	bullet.damage = bullet_damage

	# Muzzle flash
	var mf := ColorRect.new()
	mf.size = Vector2(10, 10)
	mf.position = Vector2(22, -5)
	mf.color = Color(1.0, 0.85, 0.2, 0.9)
	add_child(mf)
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(mf):
		mf.queue_free()

func do_melee() -> void:
	if health <= 0.0:
		return
	if not can_melee or is_reloading:
		return
	can_melee = false
	in_melee_anim = true
	melee_timer_val = melee_cooldown
	_apply_sprite(SpriteState.HOLD)
	var bodies: Array = melee_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(melee_damage)

func start_reload() -> void:
	if health <= 0.0:
		return
	if is_reloading or ammo == max_ammo or reserve_ammo <= 0:
		return
	is_reloading = true
	reload_timer_val = reload_time
	reload_state_changed.emit(true)
	_apply_sprite(SpriteState.RELOAD)

func _finish_reload() -> void:
	var needed: int = max_ammo - ammo
	var loaded: int = min(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false
	reload_state_changed.emit(false)
	ammo_changed.emit(ammo, reserve_ammo)
	_apply_sprite(current_weapon)

func take_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	hurt_flash_alpha = 0.6
	camera_shake.emit(6.0)
	if health <= 0.0:
		die()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)

func give_ammo(amount: int) -> void:
	reserve_ammo = min(reserve_ammo + amount, 120)
	ammo_changed.emit(ammo, reserve_ammo)

func die() -> void:
	player_died.emit()
	set_physics_process(false)
	set_process_input(false)
	_apply_sprite(SpriteState.STAND)
	modulate = Color(0.4, 0.0, 0.0, 0.7)

