extends Node2D
## Main scene — infinite scrolling world with procedural chunk generation.
## Supports 1-2 players with shared screen. Player 2 spawns if a second controller is detected.
## Terrain is block-based (Terraria-style) — players can dig through blocks.

const CHUNK_WIDTH := 1280.0
const MAX_CHUNKS := 7
const GROUND_Y := 725.0
const THIEF_SCENE_PATH := "res://scenes/world/LetterThief.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/Player.tscn"
const PET_SCENE_PATH := "res://scenes/world/Pet.tscn"
const BLOCK_SIZE := 32.0
const BLOCKS_PER_CHUNK := 40  # 1280 / 32
const UNDERGROUND_ROWS := 8   # How deep the diggable terrain goes
const TREASURE_CHANCE := 0.06 # 6% chance per underground block
const STAIRWELL_CHANCE := 0.15 # 15% chance per chunk to have a stairwell
const STAIRWELL_WIDTH := 3    # Blocks wide
const CAVE_ROWS := 6          # Diggable rows in Level 2
const CAVE_TREASURE_CHANCE := 0.10 # Richer treasure underground

const PLAYER1_COLOR := Color(0.25, 0.55, 0.85, 1)  # Blue
const PLAYER2_COLOR := Color(0.85, 0.35, 0.25, 1)  # Red-orange

@onready var quest_scroll = $QuestScroll
@onready var player: CharacterBody2D = $Player
@onready var letter_spawner: Node2D = $LetterSpawner
@onready var camera: Camera2D = $Player/Camera2D

var player2: CharacterBody2D = null
var pet1: CharacterBody2D = null
var pet2: CharacterBody2D = null
var _player_scene: PackedScene = null
var _pet_scene: PackedScene = null
var _chunks: Dictionary = {}  # chunk_index -> Node2D
var _last_chunk_index := -999
var _rng := RandomNumberGenerator.new()
var _thief_scene: PackedScene = null
var _active_thieves: Array[Node2D] = []
const MAX_THIEVES := 3
var _midpoint_camera: Camera2D = null

# Block terrain tracking — maps "chunk_x,grid_x,grid_y" -> block node
var _terrain_blocks: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	_thief_scene = load(THIEF_SCENE_PATH) as PackedScene
	_player_scene = load(PLAYER_SCENE_PATH) as PackedScene
	_pet_scene = load(PET_SCENE_PATH) as PackedScene

	# Set Player 1 color and index
	if player:
		player.player_index = 0
		player.player_color = PLAYER1_COLOR
		var body_rect := player.get_node_or_null("BodyColor") as ColorRect
		if body_rect:
			body_rect.color = PLAYER1_COLOR

	# Spawn Player 2 if a second controller is connected
	_check_and_spawn_player2()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# Pets spawn via magic summoning (spell "cat" or "dog"), not auto-spawned

	# Save is loaded in GameManager._ready() (before other autoloads)
	# Re-summon persistent world effects from previous session
	if GameManager.words_summoned.size() > 0:
		_restore_summons.call_deferred()

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

	# Wire digging for all players
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

# === PETS ===

func _spawn_pets() -> void:
	if not _pet_scene or not player:
		return

	# Dog for Player 1
	pet1 = _pet_scene.instantiate() as CharacterBody2D
	pet1.name = "DogPet"
	pet1.global_position = player.global_position + Vector2(40, 0)
	add_child(pet1)
	if pet1.has_method("setup"):
		pet1.setup(player, 0)  # 0 = DOG

	# Cat for Player 2 (or follows Player 1 if solo)
	pet2 = _pet_scene.instantiate() as CharacterBody2D
	pet2.name = "CatPet"
	var cat_owner: CharacterBody2D = player2 if player2 else player
	pet2.global_position = cat_owner.global_position + Vector2(-40, 0)
	add_child(pet2)
	if pet2.has_method("setup"):
		pet2.setup(cat_owner, 1)  # 1 = CAT

func _reassign_cat_owner() -> void:
	if pet2 and is_instance_valid(pet2):
		var cat_owner: CharacterBody2D = player2 if player2 and is_instance_valid(player2) else player
		pet2.pet_owner = cat_owner

# === PLAYER 2 ===

func _check_and_spawn_player2() -> void:
	var connected_joypads := Input.get_connected_joypads()
	if connected_joypads.size() >= 2 and player2 == null:
		_spawn_player2()
	elif connected_joypads.size() < 2 and player2 != null:
		_remove_player2()

func _spawn_player2() -> void:
	if not _player_scene or player2 != null:
		return
	player2 = _player_scene.instantiate() as CharacterBody2D
	player2.name = "Player2"
	player2.player_index = 1
	player2.player_color = PLAYER2_COLOR
	player2.position = player.position + Vector2(60, 0)
	add_child(player2)

	var body_rect := player2.get_node_or_null("BodyColor") as ColorRect
	if body_rect:
		body_rect.color = PLAYER2_COLOR

	player2.dig_requested.connect(_on_dig)

	_setup_midpoint_camera()
	_reassign_cat_owner()
	print("Francis-opia: Player 2 joined! Red character is Player 2.")

func _remove_player2() -> void:
	if player2:
		player2.queue_free()
		player2 = null
		_teardown_midpoint_camera()
		_reassign_cat_owner()
		print("Francis-opia: Player 2 disconnected.")

func _setup_midpoint_camera() -> void:
	if camera:
		camera.reparent(self)
		_midpoint_camera = camera

func _teardown_midpoint_camera() -> void:
	if _midpoint_camera and player:
		_midpoint_camera.reparent(player)
		_midpoint_camera.position = Vector2.ZERO
		_midpoint_camera = null

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	call_deferred("_check_and_spawn_player2")

# === MAIN LOOP ===

func _process(_delta: float) -> void:
	if player:
		if _midpoint_camera and player2 and is_instance_valid(player2):
			var midpoint := (player.global_position + player2.global_position) / 2.0
			_midpoint_camera.global_position = midpoint
			var dist := player.global_position.distance_to(player2.global_position)
			var zoom_level := clampf(800.0 / maxf(dist, 400.0), 0.6, 1.2)
			_midpoint_camera.zoom = Vector2(zoom_level, zoom_level)

		var current_chunk := _get_chunk_index(player.global_position.x)
		if current_chunk != _last_chunk_index:
			_last_chunk_index = current_chunk
			_update_chunks()

func _get_chunk_index(x: float) -> int:
	return int(floor(x / CHUNK_WIDTH))

func _update_chunks() -> void:
	var center := _get_chunk_index(player.global_position.x)
	if player2 and is_instance_valid(player2):
		var center2 := _get_chunk_index(player2.global_position.x)
		center = int((center + center2) / 2.0)
	var keep_range := 3

	for i in range(center - keep_range, center + keep_range + 1):
		if i not in _chunks:
			_generate_chunk(i)

	var to_remove: Array[int] = []
	for idx in _chunks:
		if abs(idx - center) > keep_range:
			to_remove.append(idx)
	for idx in to_remove:
		_remove_chunk(idx)

func _remove_chunk(idx: int) -> void:
	# Clean up block references for this chunk
	var keys_to_remove: Array = []
	var idx_str := "%d," % idx
	var l2_idx_str := "L2_%d," % idx
	for key in _terrain_blocks:
		var k: String = str(key)
		if k.begins_with(idx_str) or k.begins_with(l2_idx_str):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_terrain_blocks.erase(key)

	if _chunks.has(idx):
		_chunks[idx].queue_free()
		_chunks.erase(idx)

# === CHUNK GENERATION WITH BLOCK TERRAIN ===

func _generate_chunk(index: int) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d" % index
	var base_x := index * CHUNK_WIDTH
	chunk.position = Vector2(base_x, 0)
	add_child(chunk)
	_chunks[index] = chunk

	# Sky background
	var sky := ColorRect.new()
	sky.z_index = -10
	sky.position = Vector2(0, -200)
	sky.size = Vector2(CHUNK_WIDTH, 1000)
	sky.color = Color(0.53, 0.81, 0.92, 1)
	chunk.add_child(sky)

	# === BLOCK-BASED TERRAIN ===
	# Top row = grass, rows below = dirt, some contain treasure
	var terrain_container := Node2D.new()
	terrain_container.name = "Terrain"
	chunk.add_child(terrain_container)

	var block_script := load("res://scenes/world/TerrainBlock.gd") as GDScript

	# Determine if this chunk has a stairwell to Level 2
	var has_stairwell := _rng.randf() < STAIRWELL_CHANCE
	var stairwell_start_x := _rng.randi_range(4, BLOCKS_PER_CHUNK - STAIRWELL_WIDTH - 4) if has_stairwell else -1

	for gx in BLOCKS_PER_CHUNK:
		for gy in (UNDERGROUND_ROWS + 1):  # +1 for grass row
			# Skip blocks where the stairwell opening is (bottom 3 rows of underground)
			if has_stairwell and gx >= stairwell_start_x and gx < stairwell_start_x + STAIRWELL_WIDTH:
				if gy >= UNDERGROUND_ROWS - 2:  # Last 3 rows open for stairwell
					continue

			var block := StaticBody2D.new()
			var block_x := gx * BLOCK_SIZE + BLOCK_SIZE / 2.0
			var block_y := GROUND_Y + gy * BLOCK_SIZE + BLOCK_SIZE / 2.0
			block.position = Vector2(block_x, block_y)

			# Collision
			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
			col.shape = shape
			block.add_child(col)

			terrain_container.add_child(block)

			var is_grass := (gy == 0)
			var has_treasure := (not is_grass and _rng.randf() < TREASURE_CHANCE)

			if block_script:
				block.set_script(block_script)
				block.setup(gx, gy, is_grass, has_treasure)

			# Track block
			var key := "%d,%d,%d" % [index, gx, gy]
			_terrain_blocks[key] = block

	# Bedrock — solid floor below Level 1, with gap for stairwell
	var bedrock_y := GROUND_Y + (UNDERGROUND_ROWS + 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
	if has_stairwell:
		# Two bedrock segments with a gap for the stairwell
		var gap_left := stairwell_start_x * BLOCK_SIZE
		var gap_right := (stairwell_start_x + STAIRWELL_WIDTH) * BLOCK_SIZE
		_add_bedrock_segment(chunk, 0.0, gap_left, bedrock_y)
		_add_bedrock_segment(chunk, gap_right, CHUNK_WIDTH - gap_right, bedrock_y)
		# Generate stairwell and Level 2 cave
		_generate_stairwell(chunk, terrain_container, block_script, index, stairwell_start_x, bedrock_y)
		_generate_cave_level(chunk, terrain_container, block_script, index, bedrock_y)
	else:
		# Solid bedrock — no stairwell
		_add_bedrock_segment(chunk, 0.0, CHUNK_WIDTH, bedrock_y)

	# === ABOVE-GROUND DECORATIONS ===

	# Random platforms (1-3 per chunk) — above ground level
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

	# Surface treasure chests (1-2 per chunk, sitting on the ground)
	var surface_chests := _rng.randi_range(1, 2)
	for sc in surface_chests:
		_spawn_surface_chest(chunk, Vector2(
			_rng.randf_range(100, CHUNK_WIDTH - 100),
			GROUND_Y - 9  # Sitting on grass
		))

# === DIGGING (Terraria-style aim-based) ===

func _on_dig(dig_position: Vector2) -> void:
	# Find the block closest to the cursor/aim position
	# The dig_position is already snapped to a 32px grid by the player controller
	var best_block: Node2D = null
	var best_dist := 999.0

	for key in _terrain_blocks:
		var block: Node2D = _terrain_blocks[key]
		if not is_instance_valid(block):
			continue
		var dist := dig_position.distance_to(block.global_position)
		# Match within 20px (generous for grid-snapped positions)
		if dist < 20.0 and dist < best_dist:
			best_dist = dist
			best_block = block

	# Fallback: wider search if grid snap didn't perfectly align
	if best_block == null:
		for key in _terrain_blocks:
			var block: Node2D = _terrain_blocks[key]
			if not is_instance_valid(block):
				continue
			var dist := dig_position.distance_to(block.global_position)
			if dist < 40.0 and dist < best_dist:
				best_dist = dist
				best_block = block

	if best_block and best_block.has_method("dig"):
		best_block.dig()
		for key in _terrain_blocks:
			if _terrain_blocks[key] == best_block:
				_terrain_blocks.erase(key)
				break

# === BEDROCK HELPER ===

func _add_bedrock_segment(chunk: Node2D, x_offset: float, width: float, y_pos: float) -> void:
	if width <= 0:
		return
	var bedrock := StaticBody2D.new()
	bedrock.position = Vector2(x_offset + width / 2.0, y_pos)
	chunk.add_child(bedrock)

	var bedrock_col := CollisionShape2D.new()
	var bedrock_shape := RectangleShape2D.new()
	bedrock_shape.size = Vector2(width + 4, 20)
	bedrock_col.shape = bedrock_shape
	bedrock.add_child(bedrock_col)

	var bedrock_visual := ColorRect.new()
	bedrock_visual.position = Vector2(-width / 2.0 - 2, -10)
	bedrock_visual.size = Vector2(width + 4, 20)
	bedrock_visual.color = Color(0.3, 0.3, 0.35, 1)
	bedrock.add_child(bedrock_visual)

# === STAIRWELL GENERATION ===

func _generate_stairwell(chunk: Node2D, terrain: Node2D, _block_script: GDScript, chunk_index: int, start_x: int, bedrock_y: float) -> void:
	## Generates indestructible stone stairs from underground through bedrock to Level 2.
	## Stairs descend in a step pattern — each block steps 1 grid cell down.
	var stair_container := Node2D.new()
	stair_container.name = "Stairwell"
	chunk.add_child(stair_container)

	# Stairs start at underground row 6 (just above the opening) and go down
	# through the bedrock gap into the cave level
	var stair_top_y := GROUND_Y + (UNDERGROUND_ROWS - 2) * BLOCK_SIZE + BLOCK_SIZE / 2.0
	var cave_floor_y := bedrock_y + 20 + CAVE_ROWS * BLOCK_SIZE
	var total_stair_depth := int((cave_floor_y - stair_top_y) / BLOCK_SIZE)

	# Build zigzag platforms — 2-block-wide steps alternating left/right
	# Player walks onto step, walks off edge, drops 2 blocks to next step
	var going_right := true
	var current_y := stair_top_y
	while current_y < cave_floor_y - BLOCK_SIZE:
		if going_right:
			# Platform on left side (blocks 0, 1), gap on right (block 2)
			for sx in 2:
				var stair_x := (start_x + sx) * BLOCK_SIZE + BLOCK_SIZE / 2.0
				_add_stair_block(stair_container, Vector2(stair_x, current_y))
		else:
			# Platform on right side (blocks 1, 2), gap on left (block 0)
			for sx in 2:
				var stair_x := (start_x + 1 + sx) * BLOCK_SIZE + BLOCK_SIZE / 2.0
				_add_stair_block(stair_container, Vector2(stair_x, current_y))
		current_y += BLOCK_SIZE * 2  # 2-block drop between steps
		going_right = not going_right

	# Walls on both sides of stairwell (indestructible) — 2 blocks deep on each side
	for step_i in total_stair_depth:
		var wall_y := stair_top_y + step_i * BLOCK_SIZE
		# Left wall
		var left_x := (start_x - 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0
		if start_x > 0:
			_add_stair_block(stair_container, Vector2(left_x, wall_y))
		# Right wall
		var right_x := (start_x + STAIRWELL_WIDTH) * BLOCK_SIZE + BLOCK_SIZE / 2.0
		if start_x + STAIRWELL_WIDTH < BLOCKS_PER_CHUNK:
			_add_stair_block(stair_container, Vector2(right_x, wall_y))

	# "CAVE" label hint near the entrance — a sign for the player
	var sign_label := Label.new()
	sign_label.text = "CAVE"
	sign_label.add_theme_font_size_override("font_size", 24)
	sign_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	sign_label.position = Vector2(start_x * BLOCK_SIZE - 8, stair_top_y - BLOCK_SIZE - 20)
	sign_label.z_index = 5
	stair_container.add_child(sign_label)

func _add_stair_block(container: Node2D, pos: Vector2) -> void:
	## Creates a single indestructible stone stair block. No dig method = can't break it.
	var block := StaticBody2D.new()
	block.position = pos
	container.add_child(block)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	col.shape = shape
	block.add_child(col)

	var visual := ColorRect.new()
	visual.position = Vector2(-BLOCK_SIZE / 2.0, -BLOCK_SIZE / 2.0)
	visual.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	# Grey stone look — distinct from brown dirt
	var shade := randf_range(0.0, 0.05)
	visual.color = Color(0.42 + shade, 0.42 + shade, 0.48 + shade, 1)
	block.add_child(visual)

	# Subtle stone border
	var border := ColorRect.new()
	border.position = Vector2(-BLOCK_SIZE / 2.0, -BLOCK_SIZE / 2.0)
	border.size = Vector2(BLOCK_SIZE, 2)
	border.color = Color(0.55, 0.55, 0.6, 0.3)
	block.add_child(border)

# === CAVE LEVEL 2 GENERATION ===

func _generate_cave_level(chunk: Node2D, terrain: Node2D, block_script: GDScript, chunk_index: int, bedrock_y: float) -> void:
	## Generates Level 2 cave terrain below bedrock. Darker colors, richer treasure.
	var cave_top_y := bedrock_y + 20  # Just below bedrock

	# Dark cave background (replaces sky blue)
	var cave_bg := ColorRect.new()
	cave_bg.z_index = -10
	cave_bg.position = Vector2(0, cave_top_y - 10)
	cave_bg.size = Vector2(CHUNK_WIDTH, (CAVE_ROWS + 2) * BLOCK_SIZE + 40)
	cave_bg.color = Color(0.08, 0.06, 0.12, 1)  # Very dark purple-black
	chunk.add_child(cave_bg)

	# Cave terrain blocks — stone/slate colors
	for gx in BLOCKS_PER_CHUNK:
		for gy in CAVE_ROWS:
			var block := StaticBody2D.new()
			var block_x := gx * BLOCK_SIZE + BLOCK_SIZE / 2.0
			var block_y := cave_top_y + gy * BLOCK_SIZE + BLOCK_SIZE / 2.0
			block.position = Vector2(block_x, block_y)

			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
			col.shape = shape
			block.add_child(col)

			terrain.add_child(block)

			var has_treasure := _rng.randf() < CAVE_TREASURE_CHANCE

			if block_script:
				block.set_script(block_script)
				# Use negative gy to distinguish cave blocks visually
				# TerrainBlock.setup treats gy > 0 as dirt; we'll add cave color logic
				block.setup(gx, gy, false, has_treasure)
				# Override visual to cave stone colors
				var visual: ColorRect = block.get_node_or_null("Visual")
				if visual:
					var shade := randf_range(0.0, 0.06)
					visual.color = Color(0.32 + shade, 0.3 + shade, 0.38 + shade, 1)

			# Track with L2 prefix to avoid key collision with Level 1
			var key := "L2_%d,%d,%d" % [chunk_index, gx, gy]
			_terrain_blocks[key] = block

	# Level 2 bedrock (cave floor)
	var cave_bedrock_y := cave_top_y + CAVE_ROWS * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
	_add_bedrock_segment(chunk, 0.0, CHUNK_WIDTH, cave_bedrock_y)

# === DECORATIONS ===

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

func _spawn_surface_chest(chunk: Node2D, pos: Vector2) -> void:
	var chest_script := load("res://scenes/world/TreasureChest.gd") as GDScript
	var chest := StaticBody2D.new()
	chest.position = pos
	chest.collision_layer = 4  # Interactable

	# Chest body
	var chest_body := ColorRect.new()
	chest_body.name = "ChestBody"
	chest_body.position = Vector2(-14, -11)
	chest_body.size = Vector2(28, 18)
	chest_body.color = Color(0.6, 0.4, 0.15, 1)
	chest.add_child(chest_body)

	# Chest lid
	var lid := ColorRect.new()
	lid.name = "Lid"
	lid.position = Vector2(-16, -17)
	lid.size = Vector2(32, 8)
	lid.color = Color(0.7, 0.5, 0.2, 1)
	chest.add_child(lid)

	# Gold clasp
	var clasp := ColorRect.new()
	clasp.position = Vector2(-3, -13)
	clasp.size = Vector2(6, 5)
	clasp.color = Color(1, 0.85, 0.2, 1)
	chest.add_child(clasp)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 18)
	col.shape = shape
	chest.add_child(col)

	if chest_script:
		chest.set_script(chest_script)

	chunk.add_child(chest)

func _add_archery_target(chunk: Node2D, pos: Vector2) -> void:
	var target := StaticBody2D.new()
	target.position = pos
	target.collision_layer = 8
	chunk.add_child(target)

	var stand := ColorRect.new()
	stand.position = Vector2(-4, -40)
	stand.size = Vector2(8, 40)
	stand.color = Color(0.45, 0.3, 0.15, 1)
	target.add_child(stand)

	var board := ColorRect.new()
	board.position = Vector2(-18, -68)
	board.size = Vector2(36, 28)
	board.color = Color(0.85, 0.75, 0.55, 1)
	target.add_child(board)

	var ring := ColorRect.new()
	ring.position = Vector2(-14, -64)
	ring.size = Vector2(28, 20)
	ring.color = Color(0.9, 0.2, 0.2, 1)
	target.add_child(ring)

	var center := ColorRect.new()
	center.position = Vector2(-6, -58)
	center.size = Vector2(12, 8)
	center.color = Color(1, 1, 1, 1)
	target.add_child(center)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 28)
	col.position = Vector2(0, -54)
	col.shape = shape
	target.add_child(col)

	var script := GDScript.new()
	script.source_code = """extends StaticBody2D

func hit_by_arrow() -> void:
	var tween := create_tween()
	tween.tween_property(self, \"scale\", Vector2(0.1, 0.1), 0.3)
	tween.tween_property(self, \"scale\", Vector2(1.0, 1.0), 0.3)
"""
	script.reload()
	target.set_script(script)

# === LETTER THIEF ===

func _on_wrong_letter(_letter: String) -> void:
	_active_thieves = _active_thieves.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	if _active_thieves.size() >= MAX_THIEVES:
		return
	if not _thief_scene or not player:
		return
	var thief := _thief_scene.instantiate() as Node2D
	var spawn_side := 1.0 if _rng.randf() > 0.5 else -1.0
	thief.global_position = Vector2(
		player.global_position.x + spawn_side * 700,
		GROUND_Y - 30
	)
	add_child(thief)
	_active_thieves.append(thief)
	print("Francis-opia: Oh no! A silly letter thief appeared!")

func _restore_summons() -> void:
	## Re-create persistent summons from previous session (sun, pets, etc.)
	var magic_summon := get_node_or_null("/root/MagicSummon")
	if not magic_summon:
		return
	for word in GameManager.words_summoned:
		var entry: Dictionary = magic_summon.summon_registry.get(word, {})
		if entry.is_empty():
			continue
		var builder_name: String = entry.get("builder", "")
		if builder_name != "" and magic_summon.has_method(builder_name):
			var summoned: Variant = magic_summon.call(builder_name, self, player, player.global_position)
			if summoned is Node:
				magic_summon._summoned_entities.append(summoned)
			print("Francis-opia: Restored %s from last session!" % word)
