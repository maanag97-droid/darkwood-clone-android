extends Node

var bullet_tex: ImageTexture
var light_tex: ImageTexture
var vignette_tex: ImageTexture
var dark_ground_tex: Array = []      # Array[ImageTexture] — multiple variants
var parallax_tree_tex: Array = []    # Array[ImageTexture] — 3 layers
var fog_patch_tex: ImageTexture

var score: int = 0
var enemies_killed: int = 0
var days_survived: int = 1

const SCORE_PER_KILL: int = 100
const SCORE_PER_DAY: int = 500

func _ready() -> void:
	_generate_textures()

func _generate_textures() -> void:
	bullet_tex       = TextureGen.make_bullet_texture()
	light_tex        = TextureGen.make_light_texture(256)
	vignette_tex     = TextureGen.make_vignette(128)
	fog_patch_tex    = TextureGen.make_fog_patch(128)
	# Load real floor textures from assets
	var floor_paths: Array = [
		"res://assets/textures/tiles/floor_wood_dark.png",
		"res://assets/textures/tiles/floor_stone_cracked.png",
		"res://assets/textures/tiles/ground_mud.png",
	]
	for path in floor_paths:
		var tex: Texture2D = load(path)
		if tex:
			dark_ground_tex.append(tex)
	# Fallback: procedural variants if none loaded
	if dark_ground_tex.is_empty():
		for i in range(4):
			dark_ground_tex.append(TextureGen.make_dark_ground(64, i + 10))
	# 3 parallax tree silhouette layers (different densities / seeds)
	parallax_tree_tex.append(TextureGen.make_parallax_trees(512, 90, 11))   # far
	parallax_tree_tex.append(TextureGen.make_parallax_trees(512, 70, 22))   # mid
	parallax_tree_tex.append(TextureGen.make_parallax_trees(512, 55, 33))   # near

func register_kill() -> void:
	enemies_killed += 1
	add_score(SCORE_PER_KILL)

func register_day_survived() -> void:
	days_survived += 1
	add_score(SCORE_PER_DAY)

func add_score(points: int) -> void:
	score += points

func reset() -> void:
	score = 0
	enemies_killed = 0
	days_survived = 1
