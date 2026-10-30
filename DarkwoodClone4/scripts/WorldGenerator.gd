extends Node2D

var world_size: int = 2000
var tree_count: int = 80
var enemy_count_day: int = 4
var enemy_count_night_bonus: int = 4
var safe_radius: float = 400.0

var enemy_scene: PackedScene
var pickup_scene: PackedScene

# Original asset textures (still used as base, but tinted dark)
var tex_tree: Texture2D
var tex_tree2: Texture2D
var tex_bush: Texture2D
var tex_rock1: Texture2D
var tex_rock2: Texture2D
var tex_crate: Texture2D
var tex_stain: Texture2D

func _ready() -> void:
	enemy_scene  = load("res://scenes/Enemy.tscn")
	pickup_scene = load("res://scenes/Pickup.tscn")
	_load_asset_textures()
	_generate_ground()
	_generate_boundary()
	_generate_parallax()
	_generate_fog_patches()
	_generate_trees()
	_generate_props()
	_generate_enemies(enemy_count_day)
	_place_campfire()
	_scatter_pickups()

func _load_asset_textures() -> void:
	var t: String = "res://assets/textures/tiles/"
	var p: String = "res://assets/textures/props/"
	tex_tree  = load(t + "tree_green.png")  as Texture2D
	tex_tree2 = load(t + "tree_green2.png") as Texture2D
	tex_bush  = load(t + "bush_orange.png") as Texture2D
	tex_rock1 = load(p + "rock1.png")       as Texture2D
	tex_rock2 = load(p + "rock2.png")       as Texture2D
	tex_crate = load(p + "crate.png")       as Texture2D
	tex_stain = load(p + "stain_dark.png")  as Texture2D

# ── Ground ─────────────────────────────────────────────────────────────────
func _generate_ground() -> void:
	var ground_node: Node2D = $Ground
	var tile_size: int = 128
	var half: int = world_size / 2
	var count: int = ceili(float(world_size) / tile_size) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	var variants: Array = GameManager.dark_ground_tex
	if variants.is_empty():
		return

	for tx in range(count):
		for ty in range(count):
			var spr := Sprite2D.new()
			var vt: Texture2D = variants[rng.randi_range(0, variants.size() - 1)]
			spr.texture = vt
			# Variants differ in size (64px / 677x369 / 1024px): scale each to fill the tile
			spr.scale = Vector2(float(tile_size) / vt.get_width(), float(tile_size) / vt.get_height())
			spr.position = Vector2(
				-half + tx * tile_size + tile_size / 2.0,
				-half + ty * tile_size + tile_size / 2.0
			)
			# Slight random rotation for visual break-up
			spr.rotation = rng.randi_range(0, 3) * (PI / 2.0)
			ground_node.add_child(spr)

# ── Boundary walls ─────────────────────────────────────────────────────────
func _generate_boundary() -> void:
	var half: float = world_size / 2.0
	var t: float = 200.0
	var rects: Array = [
		[Vector2(0, -half - t / 2.0), Vector2(world_size + t * 2.0, t)],
		[Vector2(0,  half + t / 2.0), Vector2(world_size + t * 2.0, t)],
		[Vector2(-half - t / 2.0, 0), Vector2(t, world_size + t * 2.0)],
		[Vector2( half + t / 2.0, 0), Vector2(t, world_size + t * 2.0)],
	]
	for r in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r[1]
		col.shape = shape
		body.add_child(col)
		add_child(body)
		body.position = r[0]

# ── Parallax background ────────────────────────────────────────────────────
func _generate_parallax() -> void:
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBG"
	add_child(pb)
	move_child(pb, 0)

	# 4 layers: void-black sky, then 3 tree silhouette depths.
	# scroll_scale: lower = further away.  mirroring tiles seamlessly.
	var scroll_scales: Array = [
		Vector2(0.0,  0.0 ),   # Layer 0: static void background (no scroll)
		Vector2(0.04, 0.02),   # Layer 1: distant far trees
		Vector2(0.10, 0.05),   # Layer 2: mid trees
		Vector2(0.20, 0.10),   # Layer 3: near trees
	]
	var modulates: Array = [
		Color(0.01, 0.01, 0.01, 1.0),   # almost pure black
		Color(0.02, 0.03, 0.02, 1.0),   # distant — barely visible
		Color(0.04, 0.055, 0.03, 1.0),  # mid depth
		Color(0.07, 0.09, 0.05, 1.0),   # near depth — slightly lighter
	]
	var scales: Array = [
		Vector2(6.0, 6.0),   # sky fill
		Vector2(5.0, 4.0),   # distant trees — large and towering
		Vector2(3.5, 3.0),
		Vector2(2.4, 2.2),
	]

	# Layer 0: solid dark sky rect (no texture needed)
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	pb.add_child(sky_layer)
	var sky_rect := ColorRect.new()
	sky_rect.color = Color(0.008, 0.008, 0.01, 1.0)
	sky_rect.size = Vector2(4096, 2048)
	sky_rect.position = Vector2(-2048, -1024)
	sky_layer.add_child(sky_rect)

	# Layers 1-3: tree silhouettes
	for i in range(3):
		if i >= GameManager.parallax_tree_tex.size():
			break
		var layer := ParallaxLayer.new()
		layer.motion_scale = scroll_scales[i + 1]
		var ptex: Texture2D = GameManager.parallax_tree_tex[i]
		layer.motion_mirroring = Vector2(ptex.get_width() * scales[i + 1].x, ptex.get_height() * scales[i + 1].y)
		pb.add_child(layer)

		var spr := Sprite2D.new()
		spr.texture = GameManager.parallax_tree_tex[i]
		spr.modulate = modulates[i + 1]
		spr.scale = scales[i + 1]
		spr.centered = false
		spr.position = Vector2(-256, -180)   # shift upward so silhouettes frame top edge
		layer.add_child(spr)

# ── Fog patches ────────────────────────────────────────────────────────────
func _generate_fog_patches() -> void:
	if not GameManager.fog_patch_tex:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var props_node: Node2D = $Props
	for i in range(30):
		var pos := Vector2(
			rng.randf_range(-world_size * 0.48, world_size * 0.48),
			rng.randf_range(-world_size * 0.48, world_size * 0.48)
		)
		var spr := Sprite2D.new()
		spr.texture = GameManager.fog_patch_tex
		spr.scale = Vector2(rng.randf_range(3.0, 8.0), rng.randf_range(2.0, 5.0))
		spr.rotation = rng.randf_range(0.0, PI * 2.0)
		spr.modulate.a = rng.randf_range(0.4, 1.0)
		spr.z_index = 2
		props_node.add_child(spr)
		spr.position = pos

# ── Trees ──────────────────────────────────────────────────────────────────
func _generate_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var trees_node: Node2D = $Trees
	for i in range(tree_count):
		var pos := Vector2(
			rng.randf_range(-world_size * 0.5, world_size * 0.5),
			rng.randf_range(-world_size * 0.5, world_size * 0.5)
		)
		if pos.length() < safe_radius:
			continue
		_spawn_tree(trees_node, pos, rng)

func _spawn_tree(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var tree := StaticBody2D.new()
	tree.add_to_group("wall")
	tree.collision_layer = 2   # wall layer: player (mask 2) and bullets (mask 6) hit it
	tree.collision_mask = 0

	var spr := Sprite2D.new()
	var roll: float = rng.randf()
	if roll < 0.4 and tex_tree:
		spr.texture = tex_tree
	elif roll < 0.7 and tex_tree2:
		spr.texture = tex_tree2
	elif tex_bush:
		spr.texture = tex_bush

	var sc: float = rng.randf_range(1.2, 2.4)
	spr.scale = Vector2(sc, sc)
	var dark: float = rng.randf_range(0.18, 0.35)
	spr.modulate = Color(dark * 0.75, dark, dark * 0.55, 1.0)
	tree.add_child(spr)

	# Physics collider
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0 * sc
	col.shape = shape
	tree.add_child(col)

	# Shadow occluder -- makes the flashlight cast a tree shadow
	var occ := LightOccluder2D.new()
	var occ_poly := OccluderPolygon2D.new()
	var r: float = 16.0 * sc
	var pts: PackedVector2Array = PackedVector2Array()
	for k in range(8):
		var angle: float = k * PI * 2.0 / 8.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	occ_poly.polygon = pts
	occ_poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = occ_poly
	occ.light_mask = 1
	tree.add_child(occ)

	parent.add_child(tree)
	tree.position = pos

# ── Blob shadow helper (dropped under props & enemies) ────────────────────
func _add_blob_shadow(parent: Node, radius: float = 14.0) -> void:
	var shadow := Sprite2D.new()
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var cx: float = 32.0
	var cy: float = 16.0
	for x in range(64):
		for y in range(32):
			var dx: float = (float(x) - cx) / 32.0
			var dy: float = (float(y) - cy) / 16.0
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a * 0.55
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.scale = Vector2(radius / 16.0, radius / 16.0)
	shadow.z_index = -1
	parent.add_child(shadow)

# ── Props ──────────────────────────────────────────────────────────────────
func _generate_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var props_node: Node2D = $Props

	var prop_textures: Array = []
	if tex_rock1: prop_textures.append(tex_rock1)
	if tex_rock2: prop_textures.append(tex_rock2)
	if tex_crate: prop_textures.append(tex_crate)
	if tex_stain: prop_textures.append(tex_stain)
	if prop_textures.is_empty():
		return

	for i in range(40):
		var pos := Vector2(
			rng.randf_range(-world_size * 0.45, world_size * 0.45),
			rng.randf_range(-world_size * 0.45, world_size * 0.45)
		)
		if pos.length() < safe_radius * 1.2:
			continue
		var spr := Sprite2D.new()
		spr.texture = prop_textures[randi() % prop_textures.size()]
		spr.rotation = rng.randf_range(0, PI * 2.0)
		spr.scale = Vector2(rng.randf_range(0.9, 1.6), rng.randf_range(0.9, 1.6))
		# Props almost disappear in darkness — only lit areas reveal them
		var dark: float = rng.randf_range(0.2, 0.45)
		spr.modulate = Color(dark * 0.8, dark * 0.85, dark * 0.7, 1.0)
		_add_blob_shadow(spr, 18.0 * spr.scale.x)
		props_node.add_child(spr)
		spr.position = pos

# ── Campfire ───────────────────────────────────────────────────────────────
func _place_campfire() -> void:
	var fire := Node2D.new()
	fire.name = "Campfire"
	$Props.add_child(fire)
	fire.position = Vector2(0, 40)

	# Outer wide ambient glow
	var glow_outer := PointLight2D.new()
	glow_outer.energy = 0.55
	glow_outer.scale = Vector2(7.0, 7.0)
	glow_outer.color = Color(1.0, 0.38, 0.06, 1.0)
	if GameManager.light_tex:
		glow_outer.texture = GameManager.light_tex
	fire.add_child(glow_outer)

	# Inner hot core — shadow-casting so campfire throws tree/wall shadows
	var glow_inner := PointLight2D.new()
	glow_inner.energy = 1.1
	glow_inner.scale = Vector2(2.5, 2.5)
	glow_inner.color = Color(1.0, 0.72, 0.22, 1.0)
	if GameManager.light_tex:
		glow_inner.texture = GameManager.light_tex
	glow_inner.shadow_enabled = true
	glow_inner.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	glow_inner.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	glow_inner.shadow_filter_smooth = 2.5
	fire.add_child(glow_inner)

	# Procedural flame sprite
	var spr := Sprite2D.new()
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	for x in range(16):
		for y in range(24):
			var cx: float = float(x) - 8.0
			var cy: float = float(y) - 20.0
			var d: float = sqrt(cx * cx * 1.5 + cy * cy)
			if d < 9.0:
				var t: float = d / 9.0
				var r: float = 1.0
				var g: float = 0.55 - t * 0.35
				var b: float = 0.0
				var a: float = (1.0 - t * 0.85)
				img.set_pixel(x, y, Color(r, g, b, a))
	spr.texture = ImageTexture.create_from_image(img)
	spr.scale = Vector2(3.0, 3.0)
	spr.z_index = 3
	fire.add_child(spr)

	# Animated flicker on both lights
	_start_fire_tween(glow_outer, glow_inner, spr)

func _start_fire_tween(outer: PointLight2D, inner: PointLight2D, flame: Sprite2D) -> void:
	# Outer glow flicker
	var tw1: Tween = create_tween().set_loops()
	tw1.tween_property(outer, "energy", 0.7, 0.18).set_trans(Tween.TRANS_SINE)
	tw1.tween_property(outer, "energy", 0.45, 0.22).set_trans(Tween.TRANS_SINE)
	# Inner flicker — offset phase
	var tw2: Tween = create_tween().set_loops()
	tw2.tween_property(inner, "energy", 1.3, 0.13).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(inner, "energy", 0.85, 0.17).set_trans(Tween.TRANS_SINE)
	# Flame wobble
	var tw3: Tween = create_tween().set_loops()
	tw3.tween_property(flame, "scale", Vector2(2.7, 3.2), 0.15).set_trans(Tween.TRANS_SINE)
	tw3.tween_property(flame, "scale", Vector2(3.2, 2.8), 0.19).set_trans(Tween.TRANS_SINE)

# ── Enemies ────────────────────────────────────────────────────────────────
func _generate_enemies(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var enemies_node: Node2D = $Enemies
	for i in range(count):
		var pos := Vector2(
			rng.randf_range(-world_size * 0.4, world_size * 0.4),
			rng.randf_range(-world_size * 0.4, world_size * 0.4)
		)
		if pos.length() < safe_radius * 1.5:
			pos = pos.normalized() * safe_radius * 2.0
		var enemy: Node = enemy_scene.instantiate()
		enemies_node.add_child(enemy)
		enemy.position = pos
		enemy.connect("enemy_died", _on_enemy_died)

func spawn_night_enemies() -> void:
	_generate_enemies(enemy_count_night_bonus)

func _on_enemy_died(pos: Vector2) -> void:
	if randf() < 0.6 and pickup_scene:
		_spawn_pickup(pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0)
	if randf() < 0.25 and pickup_scene:
		_spawn_pickup(pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 1)

func _spawn_pickup(pos: Vector2, type: int) -> void:
	var p: Node = pickup_scene.instantiate()
	$Props.add_child(p)
	p.position = pos
	p.pickup_type = type

func _scatter_pickups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for i in range(20):
		var pos := Vector2(
			rng.randf_range(-world_size * 0.4, world_size * 0.4),
			rng.randf_range(-world_size * 0.4, world_size * 0.4)
		)
		if pos.length() < safe_radius * 1.5:
			continue
		var type: int = 1 if rng.randf() < 0.3 else 0
		_spawn_pickup(pos, type)
