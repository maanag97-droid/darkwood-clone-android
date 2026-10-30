extends Area2D

enum PickupType { AMMO, HEALTH }

@export var pickup_type: int = PickupType.AMMO
@export var ammo_amount: int = 12
@export var heal_amount: float = 30.0

var _collected: bool = false
var _bob_timer: float = 0.0

@onready var sprite: Sprite2D   = $Sprite2D
@onready var label: Label       = $Label
@onready var glow: PointLight2D = $Glow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	var col: Color = Color(0.2, 0.6, 1.0, 1.0) if pickup_type == PickupType.AMMO else Color(0.2, 1.0, 0.3, 1.0)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in range(16):
		for y in range(16):
			var edge: bool = x == 0 or x == 15 or y == 0 or y == 15
			img.set_pixel(x, y, Color.WHITE if edge else col)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(2.0, 2.0)
	label.text = "AMMO" if pickup_type == PickupType.AMMO else "MED"
	glow.color = col
	glow.energy = 0.6

func _process(delta: float) -> void:
	_bob_timer += delta * 2.5
	sprite.position.y = sin(_bob_timer) * 4.0
	glow.energy = 0.5 + sin(_bob_timer * 1.3) * 0.2

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	if pickup_type == PickupType.AMMO:
		if body.has_method("give_ammo"):
			body.give_ammo(ammo_amount)
		_notify_hud("+%d AMMO" % ammo_amount, Color(0.3, 0.7, 1.0, 1.0))
	else:
		if body.has_method("heal"):
			body.heal(heal_amount)
		_notify_hud("+%d HP" % int(heal_amount), Color(0.3, 1.0, 0.4, 1.0))
	queue_free()

func _notify_hud(msg: String, col: Color) -> void:
	var huds: Array = get_tree().get_nodes_in_group("hud")
	for h in huds:
		if h.has_method("show_pickup_message"):
			h.show_pickup_message(msg, col)
