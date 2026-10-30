extends CharacterBody2D

enum State {IDLE, PATROL, CHASE, ATTACK, HURT, DEAD}
enum SpriteState {STAND, WALK, ATTACK_ANIM, HURT_ANIM}

var state: int = State.PATROL
var max_health: float = 60.0
var health: float = 60.0
var speed: float = 120.0
var chase_speed: float = 200.0
var attack_damage: float = 15.0
var attack_range: float = 45.0
var detect_range: float = 250.0
var attack_cooldown: float = 1.2
var can_attack: bool = true
var target: Node = null
var patrol_points: Array = []
var patrol_index: int = 0
var patrol_wait: float = 2.0
var patrol_timer: float = 0.0
var hurt_timer: float = 0.0
var hurt_duration: float = 0.3
var attack_timer_val: float = 0.0
var night_aggro_multiplier: float = 1.0

var tex_stand: Texture2D
var tex_walk: Texture2D
var tex_attack: Texture2D
var tex_hurt: Texture2D

signal enemy_died(pos)

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var health_bar: ProgressBar = $HealthBar
@onready var sfx_death: AudioStreamPlayer2D = $SFXDeath

func _ready() -> void:
	add_to_group("enemy")
	health_bar.max_value = max_health
	health_bar.value = max_health
	health_bar.visible = false
	_load_textures()
	_apply_sprite(SpriteState.STAND)
	_generate_patrol_points()
	detection_area.body_entered.connect(_on_body_entered)

func _load_img(path: String) -> Texture2D:
	return load(path) as Texture2D

func _load_textures() -> void:
	var base: String = "res://assets/textures/enemy/"
	tex_stand  = _load_img(base + "zoimbie1_stand.png")
	tex_walk   = _load_img(base + "zoimbie1_gun.png")
	tex_attack = _load_img(base + "zoimbie1_hold.png")
	tex_hurt   = _load_img(base + "zoimbie1_machine.png")

func _apply_sprite(s: int) -> void:
	match s:
		SpriteState.STAND:       if tex_stand:  sprite.texture = tex_stand
		SpriteState.WALK:        if tex_walk:   sprite.texture = tex_walk
		SpriteState.ATTACK_ANIM: if tex_attack: sprite.texture = tex_attack
		SpriteState.HURT_ANIM:   if tex_hurt:   sprite.texture = tex_hurt

func _generate_patrol_points() -> void:
	for i in range(4):
		var angle: float = (PI * 2.0 / 4.0) * float(i)
		patrol_points.append(global_position + Vector2(cos(angle), sin(angle)) * 80.0)

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	match state:
		State.IDLE:   _idle_state(delta)
		State.PATROL: _patrol_state()
		State.CHASE:  _chase_state()
		State.ATTACK: _attack_state()
		State.HURT:   _hurt_state()

func _handle_timers(delta: float) -> void:
	if attack_timer_val > 0.0:
		attack_timer_val -= delta
		if attack_timer_val <= 0.0:
			can_attack = true
	if hurt_timer > 0.0:
		hurt_timer -= delta

func _idle_state(delta: float) -> void:
	_apply_sprite(SpriteState.STAND)
	patrol_timer += delta
	if patrol_timer >= patrol_wait:
		patrol_timer = 0.0
		state = State.PATROL

func _patrol_state() -> void:
	if patrol_points.is_empty():
		state = State.IDLE
		return
	_apply_sprite(SpriteState.WALK)
	var dest: Vector2 = patrol_points[patrol_index]
	if global_position.distance_to(dest) < 15.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		state = State.IDLE
		return
	var dir: Vector2 = (dest - global_position).normalized()
	velocity = dir * speed
	rotation = velocity.angle()
	move_and_slide()
	_try_detect_player()

func _chase_state() -> void:
	if not is_instance_valid(target):
		state = State.PATROL
		return
	_apply_sprite(SpriteState.WALK)
	var dist: float = global_position.distance_to(target.global_position)
	if dist <= attack_range:
		state = State.ATTACK
		return
	if dist > detect_range * 2.2:
		target = null
		state = State.PATROL
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	velocity = dir * chase_speed * night_aggro_multiplier
	rotation = velocity.angle()
	move_and_slide()

func _attack_state() -> void:
	if not is_instance_valid(target):
		state = State.PATROL
		return
	_apply_sprite(SpriteState.ATTACK_ANIM)
	var dist: float = global_position.distance_to(target.global_position)
	if dist > attack_range * 1.5:
		state = State.CHASE
		return
	velocity = Vector2.ZERO
	rotation = (target.global_position - global_position).angle()
	if can_attack:
		_do_attack()

func _hurt_state() -> void:
	_apply_sprite(SpriteState.HURT_ANIM)
	velocity = velocity.lerp(Vector2.ZERO, 0.15)
	move_and_slide()
	if hurt_timer <= 0.0:
		state = State.CHASE if is_instance_valid(target) else State.PATROL

func _try_detect_player() -> void:
	var bodies: Array = detection_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			target = body
			state = State.CHASE
			return

func _do_attack() -> void:
	can_attack = false
	attack_timer_val = attack_cooldown
	if is_instance_valid(target) and target.has_method("take_damage"):
		if global_position.distance_to(target.global_position) <= attack_range:
			target.take_damage(attack_damage * night_aggro_multiplier)
	if is_instance_valid(target):
		velocity = (target.global_position - global_position).normalized() * 400.0

func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health = max(0.0, health - amount)
	health_bar.value = health
	health_bar.visible = true
	if health <= 0.0:
		die()   # state becomes DEAD immediately: no double kill/score/drops
		return
	state = State.HURT
	hurt_timer = hurt_duration
	sprite.modulate = Color(1.0, 0.15, 0.15, 1.0)   # red flash on hit
	if is_instance_valid(target):
		velocity = (global_position - target.global_position).normalized() * 250.0
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self) and state != State.DEAD:
		sprite.modulate = Color.WHITE
		state = State.CHASE

func die() -> void:
	GameManager.register_kill()
	state = State.DEAD
	set_physics_process(false)
	set_deferred("collision_layer", 0)   # deferred: die() can run inside a physics callback
	set_deferred("collision_mask", 0)
	health_bar.visible = false
	enemy_died.emit.call_deferred(global_position)
	_apply_sprite(SpriteState.STAND)
	sprite.modulate = Color(0.3, 0.0, 0.0, 0.5)
	if sfx_death:
		sfx_death.pitch_scale = randf_range(0.85, 1.15)
		var sfx_copy: AudioStreamPlayer2D = sfx_death.duplicate()
		get_parent().add_child(sfx_copy)
		sfx_copy.global_position = global_position
		sfx_copy.play()
		await get_tree().create_timer(sfx_copy.stream.get_length() + 0.1).timeout
		if is_instance_valid(sfx_copy):
			sfx_copy.queue_free()
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target = body
		if state == State.PATROL or state == State.IDLE:
			state = State.CHASE
