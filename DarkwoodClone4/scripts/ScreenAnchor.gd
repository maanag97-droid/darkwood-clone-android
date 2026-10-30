extends Sprite2D
## Keeps this sprite centred on the screen every frame.
## Used by the vignette overlay.
func _process(_delta: float) -> void:
	var vp: Viewport = get_viewport()
	if vp:
		position = vp.get_visible_rect().size / 2.0
