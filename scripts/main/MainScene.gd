extends Node2D
## Main scene — infinite scrolling world with procedural chunk generation.
## Generates terrain chunks as the player walks, recycles old ones.

const CHUNK_WIDTH := 1280.0
const MAX_CHUNKS := 7  # Keep max this many chunks alive
const GROUND_Y := 725.0
const THIEF_SCENE_PATH := "res://scenes/world/LetterThief.tscn"

@onready var quest_scroll = $QuestScroll
@onready var player: CharacterBody2D = $Player
@onready var letter_spawner: Node2D = $LetterSpawner

var _chunks: Dictionary = {}  # chunk_index -> Node2D
var _last_chunk_index := -999
var _rng := RandomNumberGenerator.new()
var _thief_scene: PackedScene = null
var _active_thieves: Array[Node2D] = []
const MAX_THIEVES := 3

func _ready() -> void:
	_rng.randomize()
	_thief_scene = load(THIEF_SCENE_PATH) as PackedScene

	# Try loading saved game
	if GameManager.load_game():
		print("Francis-opia: Save loaded! Welcome back to %s!" % GameManager.planet_name)
	else:
		print("Francis-opia: New adventure begins!")
		GameManager.planet_name = "Francis-opia"

	# Wire quest generator to quest scroll UI
	if quest_scroll:
		QuestGenerator.quest_added.connect(func(quest: Dictionary) -> void:
			quest_scroll.add_quest(quest)
		)
		QuestGenerator.quest_completed.connect(func(quest_id: String) -> void:
			quest_scroll.complete_quest(quest_id)
		)

	# Wire letter spawner to player
	if letter_spawner and player:
		letter_spawner.set_player(player)

	# Wire monster spawning to wrong letter
	WordEngine.wrong_letter_rejected.connect(_on_wrong_letter)

	# Wire digging
	if player:
		player.dig_requested.connect(_on_dig)

	# Start first word
	WordEngine.select_word_for_area(GameManager.current_area)
	print("Francis-opia: Spell '%s'!" % WordEngine.current_target_word)

	# Generate initial quests
	QuestGenerator.generate_quests_for_area(GameManager.current_area, 3)

	# Generate initial chunks around player
	_update_chunks()

	print("Francis-opia: WASD/arrows to move, Space to jump, Click/RT to shoot, Q/LB to dig, Tab for quests")

func _process(_delta: float) -> void:
	if player:
		var current_chunk := _get_chunk_index(player.global_position.x)
		if current_chunk != _last_chunk_index:
			_last_chunk_index = current_chunk
			_update_chunks()

func _get_chunk_index(x: float) -> int:
	return int(floor(x / CHUNK_WIDTH))

func _update_chunks() -> void:
	var center := _get_chunk_index(player.global_position.x)
	var keep_range := 3  # chunks on each side

	# Generate new chunks
	for i in range(center - keep_range, center + keep_range + 1):
		if i not in _chunks:
			_generate_chunk(i)

	# Remove old chunks
	var to_remove: Array[int] = []
	for idx in _chunks:
		if abs(idx - center) > keep_range:
			to_remove.append(idx)
	for idx in to_remove:
		_chunks[idx].queue_free()
		_chunks.erase(idx)

func _generate_chunk(index: int) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d" % index
	var base_x := index * CHUNK_WIDTH
	chunk.position = Vector2(base_x, 0)
	add_child(chunk)
	_chunks[index] = chunk

	# Ground
	var ground := StaticBody2D.new()
	ground.position = Vector2(CHUNK_WIDTH / 2.0, GROUND_Y + 25)
	chunk.add_child(ground)

	var ground_col := CollisionShape2D.new()
	var ground_shape := RectangleShape2D.new()
	ground_shape.size = Vector2(CHUNK_WIDTH + 20, 50)
	ground_col.shape = ground_shape
	ground.add_child(ground_col)

	# Ground visual — grass
	var grass := ColorRect.new()
	grass.position = Vector2(-CHUNK_WIDTH / 2.0, -25)
	grass.size = Vector2(CHUNK_WIDTH + 20, 15)
	grass.color = Color(0.36, 0.68, 0.34, 1)
	ground.add_child(grass)

	# Ground visual — dirt
	var dirt := ColorRect.new()
	dirt.position = Vector2(-CHUNK_WIDTH / 2.0, -10)
	dirt.size = Vector2(CHUNK_WIDTH + 20, 60)
	dirt.color = Color(0.5, 0.35, 0.2, 1)
	ground.add_child(dirt)

	# Sky background (per chunk)
	var sky := ColorRect.new()
	sky.z_index = -10
	sky.position = Vector2(0, -200)
	sky.size = Vector2(CHUNK_WIDTH, 1000)
	sky.color = Color(0.53, 0.81, 0.92, 1)
	chunk.add_child(sky)

	# Random platforms (1-3 per chunk)
	var platform_count := _rng.randi_range(1, 3)
	for p in platform_count:
		_add_platform(chunk, Vector2(
			_rng.randf_range(100, CHUNK_WIDTH - 100),
			_rng.randf_range(450, 650)
		), _rng.randf_range(120, 220))

	# Random trees (1-3)
	var tree_count := _rng.randi_range(1, 3)
	for t in tree_count:
		_add_tree(chunk, Vector2(_rng.randf_range(50, CHUNK_WIDTH - 50), GROUND_Y))

	# Random flowers (2-5)
	var flower_count := _rng.randi_range(2, 5)
	for f in flower_count:
		_add_flower(chunk, Vector2(_rng.randf_range(30, CHUNK_WIDTH - 30), GROUND_Y - _rng.randf_range(0, 5)))

	# Clouds (1-2)
	var cloud_count := _rng.randi_range(1, 2)
	for c in cloud_count:
		var cloud := ColorRect.new()
		cloud.z_index = -5
		cloud.position = Vector2(_rng.randf_range(0, CHUNK_WIDTH - 150), _rng.randf_range(30, 120))
		cloud.size = Vector2(_rng.randf_range(100, 200), _rng.randf_range(25, 45))
		cloud.color = Color(1, 1, 1, _rng.randf_range(0.4, 0.7))
		chunk.add_child(cloud)

	# Occasional archery target (20% chance)
	if _rng.randf() < 0.2:
		_add_archery_target(chunk, Vector2(
			_rng.randf_range(200, CHUNK_WIDTH - 200),
			GROUND_Y
		))

func _add_platform(chunk: Node2D, pos: Vector2, width: float) -> void:
	var platform := StaticBody2D.new()
	platform.position = pos
	chunk.add_child(platform)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 20)
	col.shape = shape
	platform.add_child(col)

	var visual := ColorRect.new()
	visual.position = Vector2(-width / 2.0, -10)
	visual.size = Vector2(width, 20)
	visual.color = Color(0.55, 0.4, 0.25, 1)
	platform.add_child(visual)

	var grass_top := ColorRect.new()
	grass_top.position = Vector2(-width / 2.0, -14)
	grass_top.size = Vector2(width, 4)
	grass_top.color = Color(0.3, 0.7, 0.3, 1)
	platform.add_child(grass_top)

func _add_tree(chunk: Node2D, pos: Vector2) -> void:
	var tree := Node2D.new()
	tree.position = pos
	chunk.add_child(tree)

	var trunk_h := _rng.randf_range(60, 100)
	var trunk := ColorRect.new()
	trunk.position = Vector2(-8, -trunk_h)
	trunk.size = Vector2(16, trunk_h)
	trunk.color = Color(_rng.randf_range(0.4, 0.5), _rng.randf_range(0.25, 0.35), _rng.randf_range(0.1, 0.2), 1)
	tree.add_child(trunk)

	var canopy_size := _rng.randf_range(25, 40)
	var leaves := ColorRect.new()
	leaves.position = Vector2(-canopy_size, -trunk_h - canopy_size * 1.5)
	leaves.size = Vector2(canopy_size * 2, canopy_size * 1.5)
	leaves.color = Color(_rng.randf_range(0.18, 0.3), _rng.randf_range(0.55, 0.75), _rng.randf_range(0.2, 0.35), 1)
	tree.add_child(leaves)

func _add_flower(chunk: Node2D, pos: Vector2) -> void:
	var flower := ColorRect.new()
	flower.position = pos + Vector2(0, -12)
	flower.size = Vector2(10, 12)
	var colors := [
		Color(1, 0.4, 0.5, 1), Color(1, 0.85, 0.2, 1),
		Color(0.7, 0.4, 1, 1), Color(1, 0.6, 0.8, 1),
		Color(0.5, 0.8, 1, 1)
	]
	flower.color = colors[_rng.randi() % colors.size()]
	chunk.add_child(flower)

func _add_archery_target(chunk: Node2D, pos: Vector2) -> void:
	var target := StaticBody2D.new()
	target.position = pos
	target.collision_layer = 8
	chunk.add_child(target)

	# Stand
	var stand := ColorRect.new()
	stand.position = Vector2(-4, -40)
	stand.size = Vector2(8, 40)
	stand.color = Color(0.45, 0.3, 0.15, 1)
	target.add_child(stand)

	# Board
	var board := ColorRect.new()
	board.position = Vector2(-18, -68)
	board.size = Vector2(36, 28)
	board.color = Color(0.85, 0.75, 0.55, 1)
	target.add_child(board)

	# Red ring
	var ring := ColorRect.new()
	ring.position = Vector2(-14, -64)
	ring.size = Vector2(28, 20)
	ring.color = Color(0.9, 0.2, 0.2, 1)
	target.add_child(ring)

	# White center
	var center := ColorRect.new()
	center.position = Vector2(-6, -58)
	center.size = Vector2(12, 8)
	center.color = Color(1, 1, 1, 1)
	target.add_child(center)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 28)
	col.position = Vector2(0, -54)
	col.shape = shape
	target.add_child(col)

	# Add hit_by_arrow method via script
	var script := GDScript.new()
	script.source_code = """extends StaticBody2D

func hit_by_arrow() -> void:
	var tween := create_tween()
	tween.tween_property(self, \"scale\", Vector2(0.1, 0.1), 0.3)
	tween.tween_property(self, \"scale\", Vector2(1.0, 1.0), 0.3)
"""
	script.reload()
	target.set_script(script)

# === LETTER THIEF (monster spawning) ===

func _on_wrong_letter(_letter: String) -> void:
	# Clean up dead thieves
	_active_thieves = _active_thieves.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	if _active_thieves.size() >= MAX_THIEVES:
		return
	if not _thief_scene or not player:
		return
	# Spawn thief off-screen near the player
	var thief := _thief_scene.instantiate() as Node2D
	var spawn_side := 1.0 if _rng.randf() > 0.5 else -1.0
	thief.global_position = Vector2(
		player.global_position.x + spawn_side * 700,
		GROUND_Y - 30
	)
	add_child(thief)
	_active_thieves.append(thief)
	print("Francis-opia: Oh no! A silly letter thief appeared!")

# === DIGGING ===

func _on_dig(dig_position: Vector2) -> void:
	_create_dig_hole(dig_position)

func _create_dig_hole(pos: Vector2) -> void:
	# Create underground pocket below the dig point
	var hole := Node2D.new()
	hole.position = pos
	add_child(hole)

	# Hole entrance visual
	var entrance := ColorRect.new()
	entrance.position = Vector2(-30, 0)
	entrance.size = Vector2(60, 20)
	entrance.color = Color(0.3, 0.2, 0.1, 1)  # Dark dirt
	entrance.z_index = 1
	hole.add_child(entrance)

	# Underground chamber
	var chamber_depth := 200.0
	var chamber_width := 300.0

	# Chamber background (dark underground)
	var bg := ColorRect.new()
	bg.position = Vector2(-chamber_width / 2.0, 20)
	bg.size = Vector2(chamber_width, chamber_depth)
	bg.color = Color(0.25, 0.18, 0.1, 1)
	bg.z_index = -1
	hole.add_child(bg)

	# Stone texture patches
	for s in 5:
		var stone := ColorRect.new()
		stone.position = Vector2(
			_rng.randf_range(-chamber_width / 2.0 + 10, chamber_width / 2.0 - 30),
			_rng.randf_range(30, chamber_depth - 10)
		)
		stone.size = Vector2(_rng.randf_range(15, 35), _rng.randf_range(10, 20))
		stone.color = Color(0.4, 0.35, 0.28, _rng.randf_range(0.3, 0.6))
		stone.z_index = -1
		hole.add_child(stone)

	# Floor of chamber
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 20 + chamber_depth)
	hole.add_child(floor_body)

	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(chamber_width, 20)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)

	var floor_visual := ColorRect.new()
	floor_visual.position = Vector2(-chamber_width / 2.0, -10)
	floor_visual.size = Vector2(chamber_width, 20)
	floor_visual.color = Color(0.35, 0.25, 0.15, 1)
	floor_body.add_child(floor_visual)

	# Walls
	for side in [-1, 1]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(side * chamber_width / 2.0, 20 + chamber_depth / 2.0)
		hole.add_child(wall)

		var wall_col := CollisionShape2D.new()
		var wall_shape := RectangleShape2D.new()
		wall_shape.size = Vector2(20, chamber_depth)
		wall_col.shape = wall_shape
		wall.add_child(wall_col)

		var wall_visual := ColorRect.new()
		wall_visual.position = Vector2(-10, -chamber_depth / 2.0)
		wall_visual.size = Vector2(20, chamber_depth)
		wall_visual.color = Color(0.35, 0.25, 0.15, 1)
		wall.add_child(wall_visual)

	# Treasure chest (80% chance in each hole)
	if _rng.randf() < 0.8:
		_add_treasure_chest(hole, Vector2(
			_rng.randf_range(-60, 60),
			20 + chamber_depth - 25
		))

	# Small platform inside for climbing back out
	var exit_platform := StaticBody2D.new()
	exit_platform.position = Vector2(-80, 20 + chamber_depth * 0.4)
	hole.add_child(exit_platform)

	var exit_col := CollisionShape2D.new()
	var exit_shape := RectangleShape2D.new()
	exit_shape.size = Vector2(60, 12)
	exit_col.shape = exit_shape
	exit_platform.add_child(exit_col)

	var exit_visual := ColorRect.new()
	exit_visual.position = Vector2(-30, -6)
	exit_visual.size = Vector2(60, 12)
	exit_visual.color = Color(0.4, 0.3, 0.2, 1)
	exit_platform.add_child(exit_visual)

	print("Francis-opia: You dug a hole! Jump in to explore!")

func _add_treasure_chest(parent: Node2D, pos: Vector2) -> void:
	var chest := StaticBody2D.new()
	chest.position = pos
	chest.collision_layer = 4
	parent.add_child(chest)

	# Chest body
	var chest_body := ColorRect.new()
	chest_body.name = "ChestBody"
	chest_body.position = Vector2(-18, -14)
	chest_body.size = Vector2(36, 22)
	chest_body.color = Color(0.6, 0.4, 0.15, 1)  # Wooden brown
	chest.add_child(chest_body)

	# Chest lid
	var lid := ColorRect.new()
	lid.name = "Lid"
	lid.position = Vector2(-20, -22)
	lid.size = Vector2(40, 10)
	lid.color = Color(0.7, 0.5, 0.2, 1)
	chest.add_child(lid)

	# Gold clasp
	var clasp := ColorRect.new()
	clasp.position = Vector2(-4, -16)
	clasp.size = Vector2(8, 6)
	clasp.color = Color(1, 0.85, 0.2, 1)
	chest.add_child(clasp)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 22)
	col.shape = shape
	chest.add_child(col)

	# Add TreasureChest script
	var script := load("res://scripts/world/TreasureChest.gd") as GDScript
	if script:
		chest.set_script(script)
