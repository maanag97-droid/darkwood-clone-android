extends Node

## Procedurally generates all shared textures at runtime.
## No external image files needed for generated assets.

# ── Bullet ────────────────────────────────────────────────
func make_bullet_texture() -> ImageTexture:
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	for x in range(8):
		for y in range(4):
			var cx: float = float(x) - 4.0
			var cy: float = float(y) - 2.0
			var d: float = sqrt(cx * cx + cy * cy * 4.0)
			if d < 3.5:
				img.set_pixel(x, y, Color(1.0, 0.9, 0.3, 1.0))
	return ImageTexture.create_from_image(img)

# ── Radial light (used by PointLight2D) ───────────────────
func make_light_texture(size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = size / 2.0
	for x in range(size):
		for y in range(size):
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			var d: float = sqrt(dx * dx + dy * dy) / center
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a * a  # Cubic falloff — tight hot centre, long soft tail
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

# ── Flashlight cone — tip-at-origin horizontal ───────────
# Image is 512 wide x 256 tall. Tip is at x=0 (left edge).
# PointLight2D centres the texture on the node position,
# so the centre of this image = x=256. That puts the tip 256px
# to the LEFT of the light node. We correct with offset=Vector2(256,0)
# in Player._setup_flashlight() so the tip sits at the player.
func make_flashlight_texture(w: int = 512, h: int = 256) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cy: float = h / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7771
	for x in range(w):
		for y in range(h):
			var nx: float = float(x) / float(w)          # 0..1 along beam (0=tip)
			var ny: float = (float(y) - cy) / cy          # -1..1 vertical

			# Cone half-width grows with distance from tip
			var inner_half: float = nx * 0.28
			var outer_half: float = nx * 0.55

			var abs_ny: float = abs(ny)

			var inner: float = clamp(1.0 - abs_ny / max(inner_half, 0.04), 0.0, 1.0)
			inner = pow(inner, 0.5)

			var penumbra: float = 0.0
			if abs_ny > inner_half and abs_ny < outer_half:
				penumbra = clamp(1.0 - (abs_ny - inner_half) / max(outer_half - inner_half, 0.01), 0.0, 1.0)
				penumbra = penumbra * penumbra

			var beam: float = max(inner, penumbra * 0.55)

			# Depth falloff
			var depth: float
			if nx < 0.6:
				depth = 1.0 - nx * 0.25
			else:
				depth = clamp(1.0 - (nx - 0.6) / 0.4, 0.0, 1.0)
				depth = depth * depth

			# Tip ramp-in
			var tip_fade: float = clamp(nx / 0.04, 0.0, 1.0)

			var a: float = beam * depth * tip_fade
			var grain: float = rng.randf_range(-0.045, 0.045)
			a = clamp(a + grain * a, 0.0, 1.0)

			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

# ── Dark ground tile ──────────────────────────────────────
func make_dark_ground(size: int = 64, seed: int = 1) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in range(size):
		for y in range(size):
			# Very dark olive/grey base with subtle noise
			var n: float = rng.randf_range(-0.04, 0.04)
			var base: float = 0.09 + n
			var g_tint: float = base + rng.randf_range(-0.01, 0.02)  # slight green
			img.set_pixel(x, y, Color(base * 0.85, g_tint, base * 0.7, 1.0))
	# Add a few lighter speckles
	for _i in range(size * 2):
		var px: int = rng.randi_range(0, size - 1)
		var py: int = rng.randi_range(0, size - 1)
		var bright: float = rng.randf_range(0.13, 0.18)
		img.set_pixel(px, py, Color(bright * 0.8, bright, bright * 0.6, 1.0))
	return ImageTexture.create_from_image(img)

# ── Fog/vignette overlay ──────────────────────────────────
func make_vignette(size: int = 512) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = size / 2.0
	for x in range(size):
		for y in range(size):
			var dx: float = (float(x) - c) / c
			var dy: float = (float(y) - c) / c
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clamp((d - 0.55) / 0.45, 0.0, 1.0)
			a = a * a * 0.88
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	return ImageTexture.create_from_image(img)

# ── Parallax tree silhouette layer ────────────────────────
# Darkwood style: tall pine silhouettes with pointed tips and a
# misty alpha gradient at the bottom so they blend into the ground.
func make_parallax_trees(w: int = 512, h: int = 256, seed: int = 42) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var num_trees: int = rng.randi_range(7, 12)
	for i in range(num_trees):
		var tx: int = rng.randi_range(20, w - 20)
		var tree_h: int = rng.randi_range(int(h * 0.65), h - 4)
		var trunk_w: int = rng.randi_range(5, 10)
		var base_y: int = h - 1

		# Darkness: near-black with tiny variation per tree
		var dark: float = rng.randf_range(0.025, 0.065)
		var col := Color(dark * 0.65, dark, dark * 0.45, 1.0)

		# Trunk column (bottom portion)
		var trunk_top: int = base_y - tree_h + int(tree_h * 0.4)
		for px in range(max(0, tx - trunk_w / 2), min(w, tx + trunk_w / 2 + 1)):
			for py in range(trunk_top, base_y + 1):
				# Fade alpha near ground for mist blending
				var fade: float = 1.0 - clamp(float(base_y - py) / float(tree_h) * 1.8, 0.0, 0.35)
				img.set_pixel(px, py, Color(col.r, col.g, col.b, fade))

		# Pine canopy: stacked triangles that taper to a point
		var canopy_top: int = base_y - tree_h
		var canopy_base_half: int = rng.randi_range(22, 45)
		var segments: int = rng.randi_range(4, 7)
		for seg in range(segments):
			var t: float = float(seg) / float(segments)
			var seg_y_top: int = canopy_top + int(t * tree_h * 0.6)
			var seg_y_bot: int = canopy_top + int((t + 0.28) * tree_h * 0.65)
			for py in range(max(0, seg_y_top), min(h, seg_y_bot + 1)):
				var row_t: float = float(py - seg_y_top) / max(1, seg_y_bot - seg_y_top)
				var half_w: int = int((1.0 - t * 0.55) * canopy_base_half * row_t)
				for px in range(max(0, tx - half_w), min(w, tx + half_w + 1)):
					var fade: float = 1.0 - clamp(float(py - seg_y_top) / float(max(1, tree_h)) * 0.4, 0.0, 0.25)
					img.set_pixel(px, py, Color(col.r, col.g, col.b, fade))

	return ImageTexture.create_from_image(img)

# ── Fog patch (used as scattered atmosphere) ──────────────
func make_fog_patch(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = size / 2.0
	for x in range(size):
		for y in range(size):
			var dx: float = (float(x) - c) / c
			var dy: float = (float(y) - c) / c
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clamp(1.0 - d, 0.0, 1.0) * 0.18
			img.set_pixel(x, y, Color(0.05, 0.07, 0.05, a))
	return ImageTexture.create_from_image(img)
