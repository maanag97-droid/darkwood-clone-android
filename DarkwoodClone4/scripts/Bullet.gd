extends Area2D

var speed: float = 700.0
var damage: float = 25.0
var lifetime: float = 1.2
var _timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if GameManager.bullet_tex and sprite:
		sprite.texture = GameManager.bullet_tex
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += Vector2(speed, 0).rotated(rotation) * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return   # bullets never hit the shooter
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
