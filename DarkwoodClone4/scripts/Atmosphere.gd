extends Node2D

## Spawns ambient light dabs and drifting fog sprites at world start.
## Attached to the Main scene as a child of World.

func _ready() -> void:
	call_deferred("_build")

func _build() -> void:
	_scatter_ambient_lights()
	_add_vignette()

func _scatter_ambient_lights() -> void:
	## Darkwood style: NO scattered ambient lights in the forest.
	## The world should be pitch black except for the player flashlight and campfire.
	## Any ambient glow completely breaks the oppressive darkness feel.
	## This function is intentionally left empty.
	pass

func _add_vignette() -> void:
	## Full-screen vignette on a CanvasLayer above the world but below HUD.
	if not GameManager.vignette_tex:
		return
	var cl := CanvasLayer.new()
	cl.layer = 8   # above world, below HUD (layer 10)
	get_tree().current_scene.add_child(cl)

	var spr := Sprite2D.new()
	spr.texture = GameManager.vignette_tex
	spr.centered = true
	# Stretch to fill screen
	spr.scale = Vector2(22.0, 22.0)   # 128px texture stretched; soft gradient, cheap to generate
	spr.modulate = Color(1, 1, 1, 0.85)
	# Anchor to screen centre via script each frame
	spr.set_script(load("res://scripts/ScreenAnchor.gd") if ResourceLoader.exists("res://scripts/ScreenAnchor.gd") else null)
	cl.add_child(spr)
