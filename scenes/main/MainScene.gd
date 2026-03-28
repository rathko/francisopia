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
const UNDERGROUND_ROWS := 16  # How deep the diggable terrain goes (player must dig a lot)
const TREASURE_CHANCE := 0.06 # 6% chance per underground block
const STAIRWELL_WIDTH := 6    # Blocks wide (outer 2 are walls, inner 4 are traversable)
const CAVE_TREASURE_CHANCE := 0.10 # Default, overridden per level config
const TerrainHeight = preload("res://scripts/world/TerrainHeight.gd")
# Fixed bedrock accommodates max hill amplitude so L2 anchoring is stable
const BEDROCK_Y := GROUND_Y + (TerrainHeight.MAX_AMPLITUDE + UNDERGROUND_ROWS + 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
# Stairwell spacing: guaranteed every N chunks (±jitter). Deeper levels = longer walks.
# At 200px/s and 1280px/chunk: 12 chunks ≈ 77s walk, 20 chunks ≈ 128s walk.
# At 200px/s and 1280px/chunk: 3 chunks ≈ 19s walk ≈ 20 seconds
const STAIRWELL_SPACING_BASE := 3   # Level 2 entrance every ~3 chunks (~20s walk)
const STAIRWELL_SPACING_SCALE := 5  # Each deeper level adds this many chunks between entrances
const STAIRWELL_JITTER := 1         # ± random offset so it doesn't feel perfectly regular
const STAIRWELL_MIN_DISTANCE := 4   # No stairwells within this many chunks of spawn

# Level configuration templates — each level is a full world with its own palette
# Add new levels by appending to this array
var LEVEL_CONFIGS: Array = [
	{}, # Index 0 unused (Level 1 is the surface, generated separately)
	{   # Level 2 — Twilight underground
		"name": "Level 2",
		"sky_color": Color(0.18, 0.15, 0.28, 1),
		"surface_color": Color(0.22, 0.45, 0.3, 1),
		"dirt_color": Color(0.32, 0.3, 0.38, 1),
		"sky_height": 450.0,
		"underground_rows": 8,
		"treasure_chance": 0.10,
		"min_difficulty": 2,
		"has_mushrooms": true,
		"has_crystals": true,
		"has_glow_trees": true,
		"star_count_min": 4,
		"star_count_max": 8,
		"tree_count_min": 2,
		"tree_count_max": 4,
		"platform_count_min": 2,
		"platform_count_max": 3,
	},
	{   # Level 3 — Deep magma caverns (future)
		"name": "Level 3",
		"sky_color": Color(0.15, 0.05, 0.05, 1),
		"surface_color": Color(0.35, 0.2, 0.15, 1),
		"dirt_color": Color(0.25, 0.15, 0.1, 1),
		"sky_height": 500.0,
		"underground_rows": 10,
		"treasure_chance": 0.15,
		"min_difficulty": 3,
		"has_mushrooms": false,
		"has_crystals": true,
		"has_glow_trees": false,
		"star_count_min": 0,
		"star_count_max": 2,
		"tree_count_min": 0,
		"tree_count_max": 1,
		"platform_count_min": 2,
		"platform_count_max": 4,
	},
]

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
var _world_seed: int = 0  # Captured once at startup for deterministic terrain height
var _thief_scene: PackedScene = null
var _active_thieves: Array[Node2D] = []
const MAX_THIEVES := 3
var _midpoint_camera: Camera2D = null

# Block terrain tracking — maps "chunk_x,grid_x,grid_y" -> block node
var _terrain_blocks: Dictionary = {}

func _ready() -> void:
	# Use saved world seed or generate a new one for first play
	if GameManager.world_seed != 0:
		_world_seed = GameManager.world_seed
		_rng.seed = _world_seed
	else:
		_rng.randomize()
		# Clamp seed to JSON-safe range (floats lose precision above 2^53)
		_world_seed = absi(_rng.seed) % 1000000000
		if _world_seed == 0:
			_world_seed = 42
		_rng.seed = _world_seed
		GameManager.world_seed = _world_seed
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

	# Dog companion always spawns (it's the first word in the game)
	if "dog" in GameManager.words_summoned:
		_spawn_dog_companion.call_deferred()

	# Restore hammer upgrade if player already has it
	if "hammer" in GameManager.items_owned and player:
		player.dig_cooldown = 0.1
		player.dig_range = 128.0
		# Add visual hammer
		var hammer_visual := Node2D.new()
		hammer_visual.name = "HammerVisual"
		var handle := ColorRect.new()
		handle.position = Vector2(14, -8)
		handle.size = Vector2(4, 20)
		handle.color = Color(0.55, 0.35, 0.15, 1)
		hammer_visual.add_child(handle)
		var head := ColorRect.new()
		head.position = Vector2(10, -14)
		head.size = Vector2(12, 10)
		head.color = Color(0.6, 0.6, 0.65, 1)
		hammer_visual.add_child(head)
		player.add_child(hammer_visual)
		print("Francis-opia: Hammer restored from save!")

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

	# Regenerate chunks when world-changing words are spelled (e.g. "tree")
	GameManager.word_completed.connect(_on_world_word_completed)

	# Wire digging for all players
	if player:
		player.dig_requested.connect(_on_dig)

	# Start first word
	WordEngine.select_word_for_area(GameManager.current_area)
	print("Francis-opia: Spell '%s'!" % WordEngine.current_target_word)

	# Generate initial quests
	QuestGenerator.generate_quests_for_area(GameManager.current_area, 3)

	# Restore player position from save or place on terrain surface
	if player:
		var has_saved_pos := GameManager.player_pos_x != 400.0 or GameManager.player_pos_y != 700.0
		if has_saved_pos:
			player.global_position = Vector2(GameManager.player_pos_x, GameManager.player_pos_y)
		# Generate initial chunks around player (must happen after position restore)
		_update_chunks()
		_last_chunk_index = _get_chunk_index(player.global_position.x)
		if not has_saved_pos:
			# First play: place player on terrain surface
			var spawn_chunk := _get_chunk_index(player.global_position.x)
			var spawn_local_x := player.global_position.x - spawn_chunk * CHUNK_WIDTH
			var spawn_centers := _get_stairwell_centers(spawn_chunk)
			var ground_at_spawn := _get_ground_y_at_px(spawn_chunk, spawn_local_x, spawn_centers)
			player.global_position.y = ground_at_spawn - 30
		player._last_safe_position = player.global_position
		if player2 and is_instance_valid(player2):
			player2.global_position = player.global_position + Vector2(60, 0)
			player2._last_safe_position = player2.global_position

	print("Francis-opia: Ground at Y=%d, Player at Y=%d, Chunks: %d, Seed: %d" % [GROUND_Y, player.global_position.y, _chunks.size(), _world_seed])
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

		# Keep GameManager in sync for save
		GameManager.player_pos_x = player.global_position.x
		GameManager.player_pos_y = player.global_position.y

		var current_chunk := _get_chunk_index(player.global_position.x)
		if current_chunk != _last_chunk_index:
			_last_chunk_index = current_chunk
			_update_chunks()

func _get_chunk_index(x: float) -> int:
	return int(floor(x / CHUNK_WIDTH))

func _get_ground_y_at_px(chunk_index: int, local_pixel_x: float, centers: Array[int]) -> float:
	## Returns the ground Y position for a given pixel X within a chunk.
	var gx := int(floor(local_pixel_x / BLOCK_SIZE))
	gx = clampi(gx, 0, BLOCKS_PER_CHUNK - 1)
	var world_block_x := chunk_index * BLOCKS_PER_CHUNK + gx
	var offset := TerrainHeight.get_height_with_stairwell(
		world_block_x, _world_seed, centers)
	return GROUND_Y + offset * BLOCK_SIZE

func _get_stairwell_start_x(chunk_index: int) -> int:
	## Returns deterministic local block X for stairwell placement in a chunk.
	## Uses hash instead of RNG so position is consistent across calls.
	var range_size := BLOCKS_PER_CHUNK - STAIRWELL_WIDTH - 8
	if range_size <= 0:
		return 4
	var hash_val: int = abs((chunk_index * 2654435761 + 37) % 2147483647)
	return (hash_val % range_size) + 4

func _get_stairwell_centers(chunk_index: int) -> Array[int]:
	## Returns world-space block X centers of stairwells in this chunk.
	var centers: Array[int] = []
	if _should_have_stairwell(chunk_index):
		var start_x := _get_stairwell_start_x(chunk_index)
		var center := chunk_index * BLOCKS_PER_CHUNK + start_x + STAIRWELL_WIDTH / 2
		centers.append(center)
	return centers

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

	# Determine if this chunk has a stairwell — guaranteed spacing, not random chance.
	# Level 2 entrance every ~12 chunks (~1 min walk), Level 3 every ~20 chunks, etc.
	var has_stairwell := _should_have_stairwell(index)
	var stairwell_start_x := _get_stairwell_start_x(index) if has_stairwell else -1
	var stairwell_centers := _get_stairwell_centers(index)

	for gx in BLOCKS_PER_CHUNK:
		# Per-column height offset for rolling hills
		var world_block_x := index * BLOCKS_PER_CHUNK + gx
		var height_offset := TerrainHeight.get_height_with_stairwell(
			world_block_x, _world_seed, stairwell_centers)
		var column_ground_y := GROUND_Y + height_offset * BLOCK_SIZE
		# Underground fills from surface down to fixed bedrock
		var column_underground := int((BEDROCK_Y - column_ground_y) / BLOCK_SIZE) - 1
		if column_underground < 1:
			column_underground = 1

		for gy in (column_underground + 1):  # +1 for grass row
			var is_grass := (gy == 0)
			# Always consume RNG to keep sequence deterministic regardless of dug state
			var has_treasure := (not is_grass and _rng.randf() < TREASURE_CHANCE)

			var key := "%d,%d,%d" % [index, gx, gy]
			# Skip blocks that were previously dug out
			if GameManager.block_changes.has(key):
				continue

			var block := StaticBody2D.new()
			var block_x := gx * BLOCK_SIZE + BLOCK_SIZE / 2.0
			var block_y := column_ground_y + gy * BLOCK_SIZE + BLOCK_SIZE / 2.0
			block.position = Vector2(block_x, block_y)
			block.collision_layer = 1
			block.collision_mask = 0

			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
			col.shape = shape
			block.add_child(col)

			chunk.add_child(block)

			if block_script:
				block.set_script(block_script)
				block.setup(gx, gy, is_grass, has_treasure)

			_terrain_blocks[key] = block

	# Bedrock — solid floor below Level 1, with gap for stairwell
	var bedrock_y := BEDROCK_Y
	if has_stairwell:
		# Bedrock gap matches inner opening (between stairwell walls)
		var inner_left_x := (stairwell_start_x + 1) * BLOCK_SIZE
		var inner_right_x := (stairwell_start_x + STAIRWELL_WIDTH - 1) * BLOCK_SIZE
		_add_bedrock_segment(chunk, 0.0, inner_left_x, bedrock_y)
		_add_bedrock_segment(chunk, inner_right_x, CHUNK_WIDTH - inner_right_x, bedrock_y)
		# Generate stairwell connecting L1 to L2
		_generate_stairwell(chunk, terrain_container, block_script, index, stairwell_start_x, bedrock_y)
		# Surface marker
		_add_stairwell_marker(chunk, stairwell_start_x)
		# Teleport pad next to stairwell exit in L2 to return to L1
		var l2_sky_h: float = LEVEL_CONFIGS[1].get("sky_height", 450.0)
		var l2_ground_y := bedrock_y + 20 + l2_sky_h
		_add_teleport_pad(chunk, Vector2(
			(stairwell_start_x - 2) * BLOCK_SIZE + BLOCK_SIZE / 2.0,
			l2_ground_y - BLOCK_SIZE / 2.0),
			Vector2(stairwell_start_x * BLOCK_SIZE + BLOCK_SIZE * 3, GROUND_Y - 40),
			"Level 1")
	else:
		# Solid bedrock — no stairwell
		_add_bedrock_segment(chunk, 0.0, CHUNK_WIDTH, bedrock_y)

	# Level 2 is generated for ALL chunks (infinite, just like Level 1)
	_generate_level(chunk, block_script, index, bedrock_y, LEVEL_CONFIGS[1])

	# === ABOVE-GROUND DECORATIONS ===

	# Random platforms (1-3 per chunk) — above ground level
	var platform_count := _rng.randi_range(1, 3)
	for p in platform_count:
		var plat_x := _rng.randf_range(100, CHUNK_WIDTH - 100)
		var plat_ground := _get_ground_y_at_px(index, plat_x, stairwell_centers)
		# Place platforms 75-275px above the local ground
		_add_platform(chunk, Vector2(
			plat_x,
			plat_ground - _rng.randf_range(75, 275)
		), _rng.randf_range(120, 220))

	# Random trees (1-3) — only appear after player spells "tree"
	var trees_unlocked := "tree" in GameManager.words_summoned
	var tree_count := _rng.randi_range(1, 3)
	for t in tree_count:
		var tree_x := _rng.randf_range(50, CHUNK_WIDTH - 50)
		var tree_ground := _get_ground_y_at_px(index, tree_x, stairwell_centers)
		if trees_unlocked:
			_add_tree(chunk, Vector2(tree_x, tree_ground))

	# Random flowers (2-5)
	var flower_count := _rng.randi_range(2, 5)
	for f in flower_count:
		var flower_x := _rng.randf_range(30, CHUNK_WIDTH - 30)
		var flower_ground := _get_ground_y_at_px(index, flower_x, stairwell_centers)
		_add_flower(chunk, Vector2(flower_x, flower_ground - _rng.randf_range(0, 5)))

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
		var target_x := _rng.randf_range(200, CHUNK_WIDTH - 200)
		var target_ground := _get_ground_y_at_px(index, target_x, stairwell_centers)
		_add_archery_target(chunk, Vector2(target_x, target_ground))

	# Surface treasure chests (1-2 per chunk, sitting on the ground)
	var surface_chests := _rng.randi_range(1, 2)
	for sc in surface_chests:
		var chest_x := _rng.randf_range(100, CHUNK_WIDTH - 100)
		var chest_ground := _get_ground_y_at_px(index, chest_x, stairwell_centers)
		_spawn_surface_chest(chunk, Vector2(chest_x, chest_ground - 9))

# === DIGGING (Terraria-style aim-based) ===

func _on_dig(dig_position: Vector2) -> void:
	# Find the block closest to the cursor/aim position
	# The dig_position is already snapped to a 32px grid by the player controller
	var best_block: Node2D = null
	var best_dist := 999.0

	for key in _terrain_blocks:
		if not is_instance_valid(_terrain_blocks[key]):
			continue
		var block: Node2D = _terrain_blocks[key]
		var dist := dig_position.distance_to(block.global_position)
		# Match within 20px (generous for grid-snapped positions)
		if dist < 20.0 and dist < best_dist:
			best_dist = dist
			best_block = block

	# Fallback: wider search if grid snap didn't perfectly align
	if best_block == null:
		for key in _terrain_blocks:
			if not is_instance_valid(_terrain_blocks[key]):
				continue
			var block: Node2D = _terrain_blocks[key]
			var dist := dig_position.distance_to(block.global_position)
			if dist < 40.0 and dist < best_dist:
				best_dist = dist
				best_block = block

	if best_block and best_block.has_method("dig"):
		best_block.dig()
		for key in _terrain_blocks:
			if _terrain_blocks[key] == best_block:
				_terrain_blocks.erase(key)
				# Persist the dug block so it stays gone across sessions
				GameManager.block_changes[key] = "air"
				break

# === STAIRWELL SPACING ===

func _should_have_stairwell(chunk_index: int) -> bool:
	## Zone-based stairwell placement. World is divided into zones of `spacing` chunks.
	## Each zone gets exactly one stairwell at a deterministic position within it.
	## No stairwells near spawn so the player has to explore first.
	if abs(chunk_index) < STAIRWELL_MIN_DISTANCE:
		return false
	var level := 1  # Currently placing Level 2 entrances from Level 1
	var spacing := STAIRWELL_SPACING_BASE + (level - 1) * STAIRWELL_SPACING_SCALE
	# Determine which zone this chunk belongs to (works for negative indices too)
	var zone: int
	if chunk_index >= 0:
		zone = chunk_index / spacing
	else:
		zone = (chunk_index - spacing + 1) / spacing
	# Hash the zone index to pick which chunk within the zone gets the stairwell
	var zone_hash: int = abs(zone * 2654435761) % spacing  # Knuth multiplicative hash
	var stairwell_chunk: int = zone * spacing + zone_hash
	# Double-check minimum distance (zone hash could land near spawn)
	if abs(stairwell_chunk) < STAIRWELL_MIN_DISTANCE:
		stairwell_chunk = zone * spacing + STAIRWELL_MIN_DISTANCE
	return chunk_index == stairwell_chunk

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
	## Generates indestructible stone stairwell from bottom of Level 1 down to Level 2.
	## 6 blocks wide: outer columns are walls, inner 4 are open with zigzag platforms.
	## Player digs down through L1 underground, finds the stairwell entrance at bedrock level.
	var stair_container := Node2D.new()
	stair_container.name = "Stairwell"
	chunk.add_child(stair_container)

	# Stairwell starts at bedrock (bottom of L1 underground) and goes down to L2 ground
	var stair_top_y := bedrock_y - 10  # Just above bedrock
	var l2_sky_h: float = LEVEL_CONFIGS[1].get("sky_height", 450.0)
	var l2_ground_y := bedrock_y + 20 + l2_sky_h
	var total_depth: int = int((l2_ground_y - stair_top_y) / BLOCK_SIZE) + 1

	# Inner columns (traversable space)
	var inner_left := start_x + 1
	var inner_right := start_x + STAIRWELL_WIDTH - 2  # 4 inner blocks

	# Indestructible walls on both sides
	# Bottom 6 rows are OPEN on both sides for wide exits into Level 2
	var exit_rows := 6
	for step_i in total_depth:
		var wall_y := stair_top_y + step_i * BLOCK_SIZE
		var is_exit_zone := step_i >= (total_depth - exit_rows)
		if not is_exit_zone:
			# Left wall
			_add_stair_block(stair_container, Vector2(
				start_x * BLOCK_SIZE + BLOCK_SIZE / 2.0, wall_y))
			# Right wall
			_add_stair_block(stair_container, Vector2(
				(start_x + STAIRWELL_WIDTH - 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0, wall_y))

	# Zigzag platforms inside the shaft
	var going_left := true
	var current_y := stair_top_y + BLOCK_SIZE * 3
	var stop_y := l2_ground_y - BLOCK_SIZE * (exit_rows + 2)  # Stop platforms above exit zone
	while current_y < stop_y:
		if going_left:
			for sx in 2:
				_add_stair_block(stair_container, Vector2(
					(inner_left + sx) * BLOCK_SIZE + BLOCK_SIZE / 2.0, current_y))
		else:
			for sx in 2:
				_add_stair_block(stair_container, Vector2(
					(inner_right - 1 + sx) * BLOCK_SIZE + BLOCK_SIZE / 2.0, current_y))
		current_y += BLOCK_SIZE * 3
		going_left = not going_left

	# "DIG HERE" sign just above bedrock (visible when player digs deep enough)
	var sign_label := Label.new()
	sign_label.text = "DIG HERE"
	sign_label.add_theme_font_size_override("font_size", 18)
	sign_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	sign_label.position = Vector2(
		(start_x + 1) * BLOCK_SIZE,
		GROUND_Y + (UNDERGROUND_ROWS - 1) * BLOCK_SIZE)
	sign_label.z_index = 5
	stair_container.add_child(sign_label)

	# "LEVEL 2" sign at the bottom of the shaft
	var l2_label := Label.new()
	l2_label.text = "LEVEL 2"
	l2_label.add_theme_font_size_override("font_size", 28)
	l2_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.7))
	l2_label.position = Vector2(
		(start_x + 1) * BLOCK_SIZE,
		l2_ground_y - BLOCK_SIZE * 2)
	l2_label.z_index = 5
	stair_container.add_child(l2_label)

func _add_stairwell_marker(chunk: Node2D, start_x: int) -> void:
	## Subtle surface marker above a stairwell — stone pillars and a mysterious glow.
	## Hints that something is underground without giving it away completely.
	var center_x := (start_x + STAIRWELL_WIDTH / 2.0) * BLOCK_SIZE
	var marker := Node2D.new()
	marker.name = "StairwellMarker"
	marker.position = Vector2(center_x, GROUND_Y)
	chunk.add_child(marker)

	# Two small stone pillars flanking the entrance area
	for side in [-1, 1]:
		var pillar := ColorRect.new()
		pillar.position = Vector2(side * (STAIRWELL_WIDTH * BLOCK_SIZE / 2.0 - 8) - 6, -40)
		pillar.size = Vector2(12, 40)
		pillar.color = Color(0.45, 0.42, 0.5, 1)
		marker.add_child(pillar)

		# Pillar cap
		var cap := ColorRect.new()
		cap.position = Vector2(side * (STAIRWELL_WIDTH * BLOCK_SIZE / 2.0 - 8) - 8, -46)
		cap.size = Vector2(16, 6)
		cap.color = Color(0.5, 0.48, 0.55, 1)
		marker.add_child(cap)

	# Mysterious glowing rune between the pillars
	var rune := ColorRect.new()
	rune.position = Vector2(-5, -20)
	rune.size = Vector2(10, 10)
	rune.color = Color(0.4, 0.9, 0.6, 0.5)
	rune.z_index = 2
	marker.add_child(rune)

	# Soft ground glow
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-30, -6)
	glow.size = Vector2(60, 12)
	glow.color = Color(0.3, 0.8, 0.5, 0.08)
	marker.add_child(glow)

	# Clear "DIG HERE" sign
	var hint := Label.new()
	hint.text = "DIG HERE"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.9))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-45, -70)
	hint.size = Vector2(90, 30)
	hint.z_index = 5
	marker.add_child(hint)

	# Arrow pointing down
	var arrow := Label.new()
	arrow.text = "v v v"
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3, 0.7))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.position = Vector2(-30, -48)
	arrow.size = Vector2(60, 20)
	arrow.z_index = 5
	marker.add_child(arrow)

func _add_stair_block(container: Node2D, pos: Vector2) -> void:
	## Creates a single indestructible stone stair block. No dig method = can't break it.
	var block := StaticBody2D.new()
	block.position = pos
	block.collision_layer = 1
	block.collision_mask = 0
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

# === TELEPORT PAD ===

func _add_teleport_pad(chunk: Node2D, pad_pos: Vector2, target_pos: Vector2, label_text: String) -> void:
	## Glowing teleport pad that sends the player to target_pos when they press Interact.
	var pad := Area2D.new()
	pad.name = "TeleportPad"
	pad.position = pad_pos
	pad.collision_layer = 4  # Interactable layer
	pad.collision_mask = 0
	chunk.add_child(pad)

	# Collision area for detection
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 32)
	col.shape = shape
	pad.add_child(col)

	# Visual — glowing platform
	var base := ColorRect.new()
	base.position = Vector2(-24, -8)
	base.size = Vector2(48, 16)
	base.color = Color(0.2, 0.6, 1.0, 0.8)
	pad.add_child(base)

	# Glow effect
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-30, -14)
	glow.size = Vector2(60, 28)
	glow.color = Color(0.2, 0.5, 1.0, 0.15)
	pad.add_child(glow)

	# Arrow up symbol
	var arrow := Label.new()
	arrow.text = "^ %s ^" % label_text
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 0.9))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.position = Vector2(-50, -32)
	arrow.size = Vector2(100, 20)
	arrow.z_index = 5
	pad.add_child(arrow)

	# Teleport script
	var script := GDScript.new()
	var code := "extends Area2D\n\n"
	code += "var teleport_target := Vector2(%f, %f)\n\n" % [target_pos.x, target_pos.y]
	code += "func interact() -> void:\n"
	code += "\tvar bodies := get_overlapping_bodies()\n"
	code += "\tfor body in bodies:\n"
	code += "\t\tif body is CharacterBody2D and body.name.begins_with(\"Player\"):\n"
	code += "\t\t\tbody.global_position = teleport_target\n"
	code += "\t\t\tbody.velocity = Vector2.ZERO\n"
	code += "\t\t\tprint(\"Francis-opia: Teleported!\")\n"
	script.source_code = code
	script.reload()
	pad.set_script(script)

# === LEVEL GENERATION (PARAMETERIZED) ===

func _generate_level(chunk: Node2D, block_script: GDScript, chunk_index: int, above_bedrock_y: float, config: Dictionary) -> void:
	## Generates a full sub-level below a bedrock layer — parameterized by config.
	## Each level is a complete world: sky, ground, trees, underground, bedrock floor.
	var level_name: String = config.get("name", "Level ?")
	var sky_color: Color = config.get("sky_color", Color(0.18, 0.15, 0.28, 1))
	var surface_color: Color = config.get("surface_color", Color(0.22, 0.45, 0.3, 1))
	var dirt_color: Color = config.get("dirt_color", Color(0.32, 0.3, 0.38, 1))
	var sky_height: float = config.get("sky_height", 450.0)
	var underground_rows: int = config.get("underground_rows", 8)
	var treasure_chance: float = config.get("treasure_chance", 0.10)

	var level_top_y := above_bedrock_y + 20
	var level_ground_y := level_top_y + sky_height

	# Sky background
	var sky := ColorRect.new()
	sky.z_index = -10
	sky.position = Vector2(0, level_top_y - 10)
	sky.size = Vector2(CHUNK_WIDTH, sky_height + (underground_rows + 2) * BLOCK_SIZE + 60)
	sky.color = sky_color
	chunk.add_child(sky)

	# Stars / ambient sky particles
	var star_min: int = config.get("star_count_min", 0)
	var star_max: int = config.get("star_count_max", 0)
	for _s in _rng.randi_range(star_min, star_max):
		var star := ColorRect.new()
		star.z_index = -9
		star.position = Vector2(
			_rng.randf_range(10, CHUNK_WIDTH - 10),
			level_top_y + _rng.randf_range(10, sky_height - 40))
		star.size = Vector2(2, 2)
		star.color = Color(1, 1, 0.8, _rng.randf_range(0.3, 0.8))
		chunk.add_child(star)

	# Terrain blocks — surface + underground
	for gx in BLOCKS_PER_CHUNK:
		for gy in (underground_rows + 1):
			var is_surface := (gy == 0)
			var has_treasure := (not is_surface and _rng.randf() < treasure_chance)

			var key := "%s_%d,%d,%d" % [level_name, chunk_index, gx, gy]
			if GameManager.block_changes.has(key):
				continue

			var block := StaticBody2D.new()
			var block_x := gx * BLOCK_SIZE + BLOCK_SIZE / 2.0
			var block_y := level_ground_y + gy * BLOCK_SIZE + BLOCK_SIZE / 2.0
			block.position = Vector2(block_x, block_y)
			block.collision_layer = 1
			block.collision_mask = 0

			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
			col.shape = shape
			block.add_child(col)

			chunk.add_child(block)

			if block_script:
				block.set_script(block_script)
				block.setup(gx, gy, is_surface, has_treasure)
				var visual: ColorRect = block.get_node_or_null("Visual")
				if visual:
					if is_surface:
						visual.color = surface_color
					else:
						var shade := randf_range(0.0, 0.06)
						visual.color = Color(
							dirt_color.r + shade, dirt_color.g + shade,
							dirt_color.b + shade, 1)

			_terrain_blocks[key] = block

	# Bedrock floor
	var bedrock_y := level_ground_y + (underground_rows + 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
	_add_bedrock_segment(chunk, 0.0, CHUNK_WIDTH, bedrock_y)

	# === Decorations (driven by config) ===

	if config.get("has_mushrooms", false):
		for _m in _rng.randi_range(3, 6):
			_add_l2_mushroom(chunk, Vector2(
				_rng.randf_range(30, CHUNK_WIDTH - 30), level_ground_y))

	if config.get("has_glow_trees", false):
		var tree_min: int = config.get("tree_count_min", 1)
		var tree_max: int = config.get("tree_count_max", 3)
		var l2_trees_unlocked := "tree" in GameManager.words_summoned
		for _t in _rng.randi_range(tree_min, tree_max):
			var l2_tree_x := _rng.randf_range(60, CHUNK_WIDTH - 60)
			if l2_trees_unlocked:
				_add_l2_tree(chunk, Vector2(l2_tree_x, level_ground_y))

	var plat_min: int = config.get("platform_count_min", 1)
	var plat_max: int = config.get("platform_count_max", 3)
	for _p in _rng.randi_range(plat_min, plat_max):
		_add_l2_platform(chunk, Vector2(
			_rng.randf_range(100, CHUNK_WIDTH - 100),
			level_ground_y - _rng.randf_range(80, sky_height * 0.6)),
			_rng.randf_range(100, 200))

	if config.get("has_crystals", false):
		for _c in _rng.randi_range(2, 4):
			_add_l2_crystal(chunk, Vector2(
				_rng.randf_range(40, CHUNK_WIDTH - 40), level_ground_y))

	# Ambient fireflies
	for _f in _rng.randi_range(3, 6):
		var particle := ColorRect.new()
		particle.z_index = 3
		particle.position = Vector2(
			_rng.randf_range(20, CHUNK_WIDTH - 20),
			level_ground_y - _rng.randf_range(20, sky_height - 20))
		particle.size = Vector2(3, 3)
		particle.color = Color(0.4, 1.0, 0.6, _rng.randf_range(0.2, 0.5))
		chunk.add_child(particle)

func _add_l2_mushroom(chunk: Node2D, pos: Vector2) -> void:
	var mushroom := Node2D.new()
	mushroom.position = pos
	chunk.add_child(mushroom)

	# Stem
	var stem := ColorRect.new()
	stem.position = Vector2(-3, -18)
	stem.size = Vector2(6, 18)
	stem.color = Color(0.75, 0.7, 0.6, 1)
	mushroom.add_child(stem)

	# Cap — glowing colors
	var cap_colors := [
		Color(0.8, 0.2, 0.3, 1),   # Red
		Color(0.3, 0.6, 0.9, 1),   # Blue
		Color(0.9, 0.5, 0.1, 1),   # Orange
		Color(0.6, 0.3, 0.8, 1),   # Purple
	]
	var cap := ColorRect.new()
	cap.position = Vector2(-10, -26)
	cap.size = Vector2(20, 10)
	cap.color = cap_colors[_rng.randi() % cap_colors.size()]
	mushroom.add_child(cap)

	# Glow spots on cap
	for _d in 2:
		var dot := ColorRect.new()
		dot.position = Vector2(_rng.randf_range(-7, 5), -24)
		dot.size = Vector2(3, 3)
		dot.color = Color(1, 1, 0.8, 0.6)
		mushroom.add_child(dot)

func _add_l2_tree(chunk: Node2D, pos: Vector2) -> void:
	var tree := Node2D.new()
	tree.position = pos
	chunk.add_child(tree)

	var trunk_h := _rng.randf_range(50, 80)
	# Dark twisted trunk
	var trunk := ColorRect.new()
	trunk.position = Vector2(-6, -trunk_h)
	trunk.size = Vector2(12, trunk_h)
	trunk.color = Color(0.25, 0.2, 0.3, 1)
	tree.add_child(trunk)

	# Glowing canopy — cyan/teal bioluminescent
	var canopy_size := _rng.randf_range(20, 35)
	var leaves := ColorRect.new()
	leaves.position = Vector2(-canopy_size, -trunk_h - canopy_size)
	leaves.size = Vector2(canopy_size * 2, canopy_size)
	leaves.color = Color(0.1, 0.65, 0.55, 0.85)
	tree.add_child(leaves)

	# Glow effect (slightly larger, transparent)
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-canopy_size - 4, -trunk_h - canopy_size - 4)
	glow.size = Vector2(canopy_size * 2 + 8, canopy_size + 8)
	glow.color = Color(0.1, 0.7, 0.5, 0.15)
	tree.add_child(glow)

func _add_l2_platform(chunk: Node2D, pos: Vector2, width: float) -> void:
	var platform := StaticBody2D.new()
	platform.position = pos
	platform.collision_layer = 1
	platform.collision_mask = 0
	chunk.add_child(platform)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 20)
	col.shape = shape
	platform.add_child(col)

	# Dark stone platform with mossy top
	var visual := ColorRect.new()
	visual.position = Vector2(-width / 2.0, -10)
	visual.size = Vector2(width, 20)
	visual.color = Color(0.3, 0.28, 0.35, 1)
	platform.add_child(visual)

	var moss := ColorRect.new()
	moss.position = Vector2(-width / 2.0, -14)
	moss.size = Vector2(width, 4)
	moss.color = Color(0.15, 0.5, 0.35, 1)
	platform.add_child(moss)

func _add_l2_crystal(chunk: Node2D, pos: Vector2) -> void:
	var crystal := Node2D.new()
	crystal.position = pos
	chunk.add_child(crystal)

	var crystal_colors := [
		Color(0.3, 0.7, 1.0, 0.85),   # Ice blue
		Color(0.7, 0.3, 0.9, 0.85),   # Amethyst
		Color(0.2, 0.9, 0.5, 0.85),   # Emerald
		Color(1.0, 0.6, 0.2, 0.85),   # Amber
	]
	var color: Color = crystal_colors[_rng.randi() % crystal_colors.size()]
	var h := _rng.randf_range(16, 32)

	# Main crystal shard (tall thin triangle approximated as narrow rect)
	var shard := ColorRect.new()
	shard.position = Vector2(-4, -h)
	shard.size = Vector2(8, h)
	shard.color = color
	crystal.add_child(shard)

	# Smaller side shard
	var side := ColorRect.new()
	side.position = Vector2(5, -h * 0.6)
	side.size = Vector2(5, h * 0.6)
	side.color = Color(color.r, color.g, color.b, 0.6)
	crystal.add_child(side)

	# Glow on ground
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-12, -4)
	glow.size = Vector2(24, 8)
	glow.color = Color(color.r, color.g, color.b, 0.15)
	crystal.add_child(glow)

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

func _spawn_dog_companion() -> void:
	## Always spawn the dog as a companion if the player has earned it.
	if not player:
		return
	var magic_summon := get_node_or_null("/root/MagicSummon")
	if magic_summon and magic_summon.has_method("_summon_dog"):
		var dog: Variant = magic_summon.call("_summon_dog", self, player, player.global_position)
		if dog is Node:
			magic_summon._summoned_entities.append(dog)
			print("Francis-opia: Your dog is here! Woof!")

func _restore_summons() -> void:
	## Re-create persistent summons from previous session (sun, pets, etc.)
	var magic_summon := get_node_or_null("/root/MagicSummon")
	if not magic_summon:
		return
	for word in GameManager.words_summoned:
		# Dog is spawned separately via _spawn_dog_companion
		if word == "dog":
			continue
		# Skip non-persistent effects (cosmetics applied once)
		if word == "big":
			continue
		var entry: Dictionary = magic_summon.summon_registry.get(word, {})
		if entry.is_empty():
			continue
		var builder_name: String = entry.get("builder", "")
		if builder_name != "" and magic_summon.has_method(builder_name):
			var summoned: Variant = magic_summon.call(builder_name, self, player, player.global_position)
			if summoned is Node:
				magic_summon._summoned_entities.append(summoned)
			print("Francis-opia: Restored %s from last session!" % word)

# Words that change the world when spelled — triggers chunk regeneration
const WORLD_CHANGING_WORDS := ["tree"]

func _on_world_word_completed(word: String) -> void:
	if word.to_lower() in WORLD_CHANGING_WORDS:
		_regenerate_all_chunks()

func _regenerate_all_chunks() -> void:
	## Force-reload all visible chunks to reflect world state changes (e.g. trees appearing).
	var chunk_indices: Array = _chunks.keys().duplicate()
	for idx in chunk_indices:
		_remove_chunk(idx)
	_last_chunk_index = -999
	_update_chunks()
