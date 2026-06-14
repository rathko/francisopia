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
const SpriteLoader = preload("res://scripts/world/SpriteLoader.gd")
# Fixed bedrock accommodates max hill amplitude so L2 anchoring is stable
const BEDROCK_Y := GROUND_Y + (TerrainHeight.MAX_AMPLITUDE + UNDERGROUND_ROWS + 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
# Stairwell spacing: guaranteed every N chunks (±jitter). Deeper levels = longer walks.
# At 200px/s and 1280px/chunk: 12 chunks ≈ 77s walk, 20 chunks ≈ 128s walk.
# At 200px/s and 1280px/chunk: 3 chunks ≈ 19s walk ≈ 20 seconds
const STAIRWELL_SPACING_BASE := 3   # Level 2 entrance every ~3 chunks (~20s walk)
const STAIRWELL_SPACING_SCALE := 5  # Each deeper level adds this many chunks between entrances
const STAIRWELL_JITTER := 1         # ± random offset so it doesn't feel perfectly regular
const STAIRWELL_MIN_DISTANCE := 6   # No stairwells within this many chunks of spawn (~2 screens away)

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
var _teleport_beacon: Node2D = null  # Visual beacon node in the world
var _home_teleport_pad: Node2D = null  # Teleport pad at HOME
# --- House interior (Slice 1: enter/exit + rooms). See docs/house-interior-architecture.md ---
var _in_house := false
var _house_root: Node2D = null
var _house_door: Area2D = null
const HOUSE_ROOM_W := 280.0
# --- Level 3 "Car Town": a flat driveable street below Level 2. ---
const L3_SKY_H := 420.0          # height of the L3 sky band above the street
const L3_LAND_X := 400.0         # world-x where the CAR TOWN portal drops you (chunk 0)
const DRIVE_SPEED := 360.0       # px/s when driving a vehicle
const L3_CAR_WORDS := ["van", "car", "bus"]  # the 3 driveable types — only appear once spelled
var _driving := false
var _driven_vehicle: Node2D = null
var _drive_hint: CanvasLayer = null
var _drive_lock := 0.0           # brief lock so the ENTER press can't instantly exit
var _drive_companions: Array = []  # active companions riding along while driving
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
		# Push the "fell into the void" respawn line BELOW the Level 3 street, otherwise descending
		# the L2->L3 shaft (or the Car Town portal) crosses the old 2500 line and bounces Francis
		# straight back up before he can land. _l3_ground_y() is the street; +300 is under its road.
		player.respawn_y = _l3_ground_y() + 300.0
		var body_rect := player.get_node_or_null("BodyColor") as ColorRect
		if body_rect:
			body_rect.color = PLAYER1_COLOR

	# Spawn Player 2 if a second controller is connected
	_check_and_spawn_player2()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# === REGRESSION GUARD: build the terrain FIRST ===
	# Generate the world BEFORE any save-restore / word / quest call below. If one of those ever
	# throws a runtime error, Francis must still have solid ground under him instead of an empty
	# void ("level one disappeared, you fall in"). Re-running _update_chunks later is harmless
	# (it skips chunks that already exist), and the ground-clamp below still finalises his spawn.
	if player:
		if GameManager.player_pos_x != 400.0 or GameManager.player_pos_y != 700.0:
			player.global_position = Vector2(GameManager.player_pos_x, GameManager.player_pos_y)
		_update_chunks()
		_last_chunk_index = _get_chunk_index(player.global_position.x)
		print("Francis-opia: Terrain ready: %d blocks in %d chunks" % [_terrain_blocks.size(), _chunks.size()])

	# Dog companion always spawns (it's the first word in the game)
	if "dog" in GameManager.words_summoned:
		_spawn_dog_companion.call_deferred()

	# Restore hammer upgrade if player already has it — single source of truth is
	# MagicSummon.equip_hammer(), so the in-hand hammer is identical to when first earned.
	if "hammer" in GameManager.items_owned and player:
		var ms := get_node_or_null("/root/MagicSummon")
		if ms and ms.has_method("equip_hammer"):
			ms.equip_hammer(player)
			print("Francis-opia: Hammer restored from save!")

	# Restore the hiking backpack onto his back if he has earned it (stays forever).
	if "bag" in GameManager.items_owned and player:
		var ms_bag := get_node_or_null("/root/MagicSummon")
		if ms_bag and ms_bag.has_method("equip_backpack"):
			ms_bag.equip_backpack(player)
			print("Francis-opia: Backpack restored from save!")

	# Save is loaded in GameManager._ready() (before other autoloads)
	# Re-summon persistent world effects from previous session
	if GameManager.words_summoned.size() > 0:
		_restore_summons.call_deferred()

	# Restore teleport beacon from save
	_restore_teleport_beacon.call_deferred()

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

	# Wire monster spawning to wrong letter, new words, and stun thieves on word completion
	WordEngine.wrong_letter_rejected.connect(_on_wrong_letter)
	WordEngine.word_spelled_correctly.connect(_on_word_stun_thieves)
	WordEngine.target_word_changed.connect(_on_new_word_thief_chance)

	# Regenerate chunks when world-changing words are spelled (e.g. "tree")
	GameManager.word_completed.connect(_on_world_word_completed)

	# Wire digging for all players
	if player:
		player.dig_requested.connect(_on_dig)
		player.teleport_beacon_requested.connect(_on_teleport_beacon_placed)

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
		# Always ensure player is above terrain (fixes stuck-in-hill on load)
		var spawn_chunk := _get_chunk_index(player.global_position.x)
		var spawn_local_x := player.global_position.x - spawn_chunk * CHUNK_WIDTH
		var spawn_centers := _get_stairwell_centers(spawn_chunk)
		var ground_at_spawn := _get_ground_y_at_px(spawn_chunk, spawn_local_x, spawn_centers)
		var min_spawn_y := ground_at_spawn - 40  # 40px clearance above ground (player is 48px tall)
		if player.global_position.y > min_spawn_y:
			player.global_position.y = min_spawn_y
		player._last_safe_position = player.global_position
		if player2 and is_instance_valid(player2):
			player2.global_position = player.global_position + Vector2(60, 0)
			player2._last_safe_position = player2.global_position

	# Parallax background layers for depth
	_setup_parallax_background()

	print("Francis-opia: Ground at Y=%d, Player at Y=%d, Chunks: %d, Seed: %d" % [GROUND_Y, player.global_position.y, _chunks.size(), _world_seed])
	print("Francis-opia: WASD/arrows to move, Space to jump, Click/RT to shoot, Q/LB to dig, Tab for quests")

	# Steam Deck: show on-screen hint if no gamepad detected
	if Input.get_connected_joypads().size() == 0 and OS.has_feature("linux"):
		_show_no_gamepad_warning()

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
	pet1.follow_offset = Vector2(50, 0)

	# Cat for Player 2 (or follows Player 1 if solo)
	pet2 = _pet_scene.instantiate() as CharacterBody2D
	pet2.name = "CatPet"
	var cat_owner: CharacterBody2D = player2 if player2 else player
	pet2.global_position = cat_owner.global_position + Vector2(-40, 0)
	add_child(pet2)
	if pet2.has_method("setup"):
		pet2.setup(cat_owner, 1)  # 1 = CAT
	pet2.follow_offset = Vector2(-50, 0)

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
	player2.respawn_y = _l3_ground_y() + 300.0  # keep the void line below Level 3 (see Player 1)
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
	# While driving, move the van and snap the (hidden) player onto it BEFORE the normal body
	# runs — so the camera, parallax and chunk-loading below all follow the van for free.
	if _driving:
		_drive_update(_delta)
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

		# Track which level Francis is actually on (by depth) — drives word difficulty AND the
		# HAMMER/VAN/FRIEND priority. current_level used to never update during play.
		var _py := player.global_position.y
		var _lvl := 1
		if _py > _l3_top_y(BEDROCK_Y) - 60.0:
			_lvl = 3
		elif _py > BEDROCK_Y - 40.0:
			_lvl = 2
		if GameManager.current_level != _lvl:
			var _was: int = GameManager.current_level
			GameManager.current_level = _lvl
			# On first ARRIVAL in Car Town, immediately switch the goal to VAN (if no car spelled
			# yet) instead of waiting for the current word to finish — and if he already owns a
			# car, park one right next to him, ready to drive. Scoped to the one-way descent into
			# Level 3 so it can't reset letter progress by jittering across a boundary.
			if _lvl == 3 and _was < 3:
				WordEngine.select_word_for_area(GameManager.current_area)
				_ensure_l3_car_near_player()
				# Mark Level 3 as DISCOVERED — this unlocks the Car Town racing gate near the
				# house on the surface (a fast way back down). Regenerate so it appears next visit.
				if not GameManager.found_level3:
					GameManager.found_level3 = true
					GameManager.save_game()

		# Parallax: offset mountain and cloud layers based on camera position
		if _mountain_container:
			_mountain_container.position.x = player.global_position.x * (1.0 - PARALLAX_MOUNTAIN_RATE)
		if _cloud_container:
			_cloud_container.position.x = player.global_position.x * (1.0 - PARALLAX_CLOUD_RATE)

		var current_chunk := _get_chunk_index(player.global_position.x)
		if current_chunk != _last_chunk_index:
			_last_chunk_index = current_chunk
			_update_chunks()

func _get_chunk_index(x: float) -> int:
	return int(floor(x / CHUNK_WIDTH))

func _get_ground_y_at_px(chunk_index: int, local_pixel_x: float, centers: Array[int]) -> float:
	## Returns the ground Y position for a given pixel X within a chunk.
	## Uses flat zones (stairwells + houses) for terrain flattening.
	var gx := int(floor(local_pixel_x / BLOCK_SIZE))
	gx = clampi(gx, 0, BLOCKS_PER_CHUNK - 1)
	var world_block_x := chunk_index * BLOCKS_PER_CHUNK + gx
	var zones := _get_flat_zones(chunk_index)
	var offset := TerrainHeight.get_height_with_flat_zones(
		world_block_x, _world_seed, zones)
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

func _get_flat_zones(chunk_index: int) -> Array[Dictionary]:
	## Returns all flat zones for this chunk (stairwells + houses).
	## Each zone: {"center": int, "flat_radius": int, "blend_radius": int}
	var zones: Array[Dictionary] = []
	# Stairwell flat zones
	if _should_have_stairwell(chunk_index):
		var start_x := _get_stairwell_start_x(chunk_index)
		var center := chunk_index * BLOCKS_PER_CHUNK + start_x + STAIRWELL_WIDTH / 2
		zones.append({"center": center, "flat_radius": 4, "blend_radius": 6})
		# House flat zone next to stairwell (if houses are unlocked)
		if "hut" in GameManager.words_summoned or "house" in GameManager.words_summoned:
			var house_center := center + 10  # House is placed to the right of stairwell
			zones.append({"center": house_center, "flat_radius": 8, "blend_radius": 12})
	# Home castle (chunk 0, near spawn) — wide flat zone for the large castle
	# Castle spawns at player_x(400) + 400 = x=800, center at x=800+240=1040
	# Block 1040/32 = block 32.5, centered. Need wide radius for 640px castle + margins
	if ("hut" in GameManager.words_summoned or "house" in GameManager.words_summoned) and chunk_index == 0:
		var home_center := int(1040.0 / 32.0)  # Block position of castle center
		zones.append({"center": home_center, "flat_radius": 16, "blend_radius": 20})
	return zones

func _update_chunks() -> void:
	if _in_house:
		return  # the overworld is torn down while inside the house
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

# === PARALLAX BACKGROUND ===

var _mountain_container: Node2D = null
var _cloud_container: Node2D = null
const PARALLAX_MOUNTAIN_RATE := 0.3  # Mountains scroll at 30% of camera speed
const PARALLAX_CLOUD_RATE := 0.5    # Clouds scroll at 50% of camera speed

func _setup_parallax_background() -> void:
	## Terraria-inspired parallax layers — mountains and clouds behind the sky.
	## Uses manual position offset in _process() for seamless infinite-world parallax.
	if not camera:
		return

	# Mountain silhouette container — positioned behind sky chunks
	_mountain_container = Node2D.new()
	_mountain_container.name = "MountainParallax"
	_mountain_container.z_index = -9  # Behind chunks (-10 is sky, -9 is mountains)
	add_child(_mountain_container)

	# Generate procedural mountain silhouettes
	var mountain_span := 12000.0  # Wide enough for parallax-reduced travel
	var mountain_start_x := -mountain_span / 2.0
	var mountain_base_y := GROUND_Y - 80

	# Back range — taller, softer mountains
	for i in 50:
		var peak_x := mountain_start_x + i * 240.0
		var peak_hash := absi((i * 7919 + _world_seed) % 1000)
		var peak_height := 100.0 + float(peak_hash % 160)
		var peak_width := 140.0 + float(peak_hash % 120)

		var mountain := ColorRect.new()
		mountain.position = Vector2(peak_x - peak_width / 2.0, mountain_base_y - peak_height)
		mountain.size = Vector2(peak_width, peak_height + 200)
		mountain.color = Color(0.30, 0.38, 0.52, 0.45)
		_mountain_container.add_child(mountain)

		# Narrower peak on top for triangle-ish shape
		var peak := ColorRect.new()
		peak.position = Vector2(peak_x - peak_width * 0.2, mountain_base_y - peak_height - 25)
		peak.size = Vector2(peak_width * 0.4, 25)
		peak.color = Color(0.33, 0.40, 0.55, 0.35)
		_mountain_container.add_child(peak)

	# Front range — shorter, darker
	for i in 35:
		var peak_x := mountain_start_x + i * 340.0 + 100.0
		var peak_hash := absi((i * 3571 + _world_seed + 42) % 1000)
		var peak_height := 50.0 + float(peak_hash % 90)
		var peak_width := 100.0 + float(peak_hash % 100)

		var mountain := ColorRect.new()
		mountain.position = Vector2(peak_x - peak_width / 2.0, mountain_base_y - peak_height)
		mountain.size = Vector2(peak_width, peak_height + 200)
		mountain.color = Color(0.22, 0.28, 0.40, 0.55)
		_mountain_container.add_child(mountain)

	# Cloud layer
	_cloud_container = Node2D.new()
	_cloud_container.name = "CloudParallax"
	_cloud_container.z_index = -8  # Above mountains, behind chunks
	add_child(_cloud_container)

	var cloud_span := 8000.0
	var cloud_start_x := -cloud_span / 2.0

	for i in 25:
		var cloud_hash := absi((i * 4999 + _world_seed + 137) % 1000)
		var cx := cloud_start_x + float(cloud_hash % int(cloud_span))
		var cy := 30.0 + float(cloud_hash % 220)
		var cw := 80.0 + float(cloud_hash % 130)
		var ch := 18.0 + float(cloud_hash % 28)

		var cloud := ColorRect.new()
		cloud.position = Vector2(cx, cy)
		cloud.size = Vector2(cw, ch)
		cloud.color = Color(1, 1, 1, 0.12 + float(cloud_hash % 100) / 600.0)
		_cloud_container.add_child(cloud)

		# Puff for fluffy shape
		var puff := ColorRect.new()
		puff.position = Vector2(cx + cw * 0.2, cy - ch * 0.4)
		puff.size = Vector2(cw * 0.6, ch * 0.7)
		puff.color = Color(1, 1, 1, 0.10 + float(cloud_hash % 70) / 700.0)
		_cloud_container.add_child(puff)

# === CHUNK GENERATION WITH BLOCK TERRAIN ===

func _generate_chunk(index: int) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk_%d" % index
	var base_x := index * CHUNK_WIDTH
	chunk.position = Vector2(base_x, 0)
	add_child(chunk)
	_chunks[index] = chunk

	# Sky background — try pixel art sky sprite, fallback to solid color
	var sky_path := "res://assets/sprites/sky/sky_day.png"
	if ResourceLoader.exists(sky_path):
		var sky_tex := load(sky_path) as Texture2D
		if sky_tex:
			var sky_spr := Sprite2D.new()
			sky_spr.texture = sky_tex
			sky_spr.z_index = -10
			sky_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			# Scale to fill chunk width, position at top
			var scale_x := CHUNK_WIDTH / float(sky_tex.get_width())
			var scale_y := 800.0 / float(sky_tex.get_height())
			sky_spr.scale = Vector2(scale_x, maxf(scale_x, scale_y))
			sky_spr.position = Vector2(CHUNK_WIDTH / 2.0, 200)
			chunk.add_child(sky_spr)
	else:
		var sky := ColorRect.new()
		sky.z_index = -10
		sky.position = Vector2(0, -200)
		sky.size = Vector2(CHUNK_WIDTH, 1000)
		sky.color = Color(0.53, 0.81, 0.92, 1)
		chunk.add_child(sky)

	# Dark earth behind terrain — visible when blocks are dug out
	var earth_bg := ColorRect.new()
	earth_bg.z_index = -5
	earth_bg.position = Vector2(0, GROUND_Y - 4 * BLOCK_SIZE)  # Start above highest possible hill
	earth_bg.size = Vector2(CHUNK_WIDTH, (UNDERGROUND_ROWS + TerrainHeight.MAX_AMPLITUDE + 6) * BLOCK_SIZE)
	earth_bg.color = Color(0.18, 0.12, 0.08, 1)  # Very dark brown
	chunk.add_child(earth_bg)

	# === BLOCK-BASED TERRAIN ===
	# Top row = grass, rows below = dirt, some contain treasure
	var terrain_container := Node2D.new()
	terrain_container.name = "Terrain"
	chunk.add_child(terrain_container)

	# Background wall layer — darker blocks behind terrain, visible when blocks are dug out
	var wall_container := Node2D.new()
	wall_container.name = "BackgroundWalls"
	wall_container.z_index = -3
	chunk.add_child(wall_container)

	var block_script := load("res://scenes/world/TerrainBlock.gd") as GDScript

	# Determine if this chunk has a stairwell — guaranteed spacing, not random chance.
	# Level 2 entrance every ~12 chunks (~1 min walk), Level 3 every ~20 chunks, etc.
	var has_stairwell := _should_have_stairwell(index)
	var stairwell_start_x := _get_stairwell_start_x(index) if has_stairwell else -1
	var stairwell_centers := _get_stairwell_centers(index)
	var flat_zones := _get_flat_zones(index)

	for gx in BLOCKS_PER_CHUNK:
		# Per-column height offset for rolling hills (flattened around structures)
		var world_block_x := index * BLOCKS_PER_CHUNK + gx
		var height_offset := TerrainHeight.get_height_with_flat_zones(
			world_block_x, _world_seed, flat_zones)
		var column_ground_y := GROUND_Y + height_offset * BLOCK_SIZE
		# Underground fills from surface down to fixed bedrock
		var column_underground := int((BEDROCK_Y - column_ground_y) / BLOCK_SIZE) - 1
		if column_underground < 1:
			column_underground = 1

		for gy in (column_underground + 1):  # +1 for grass row
			var is_grass := (gy == 0)
			# Always consume RNG to keep sequence deterministic regardless of dug state
			var has_treasure := (not is_grass and _rng.randf() < TREASURE_CHANCE)

			var block_x := gx * BLOCK_SIZE + BLOCK_SIZE / 2.0
			var block_y := column_ground_y + gy * BLOCK_SIZE + BLOCK_SIZE / 2.0

			# Background wall — always present, visible when foreground block is dug
			if not is_grass:
				_add_background_wall(wall_container, block_x, block_y, gx, gy, column_underground)

			var key := "%d,%d,%d" % [index, gx, gy]
			# Skip blocks that were previously dug out
			if GameManager.block_changes.has(key):
				continue

			var block := StaticBody2D.new()
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
				block.total_depth = column_underground
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
		# Teleport pad next to stairwell exit in L2 (only if player has spelled "portal")
		if "zap" in GameManager.words_summoned or "portal" in GameManager.words_summoned:
			var l2_sky_h: float = LEVEL_CONFIGS[1].get("sky_height", 450.0)
			var l2_ground_y := bedrock_y + 20 + l2_sky_h
			_add_teleport_pad(chunk, Vector2(
				(stairwell_start_x - 2) * BLOCK_SIZE + BLOCK_SIZE / 2.0,
				l2_ground_y - BLOCK_SIZE / 2.0),
				Vector2(stairwell_start_x * BLOCK_SIZE + BLOCK_SIZE * 3, GROUND_Y - 40),
				"Level 1")
		# Small cottage ONLY on L2 near the stairwell exit (not on surface — too cluttered)
		if "hut" in GameManager.words_summoned or "house" in GameManager.words_summoned:
			var l2_sky_h2: float = LEVEL_CONFIGS[1].get("sky_height", 450.0)
			var l2_ground_y2 := bedrock_y + 20 + l2_sky_h2
			var stairwell_right_x := (stairwell_start_x + STAIRWELL_WIDTH + 2) * BLOCK_SIZE
			_add_stairwell_house(chunk, Vector2(stairwell_right_x, l2_ground_y2))
	else:
		# Solid bedrock — no stairwell
		_add_bedrock_segment(chunk, 0.0, CHUNK_WIDTH, bedrock_y)

	# Level 2 is generated for ALL chunks (infinite, just like Level 1). Chunks that have an
	# L1->L2 stairwell ALSO get an L2->L3 elevator shaft at the SAME column (directly below it),
	# so the descent to Car Town works exactly like the descent to Level 2.
	_generate_level(chunk, block_script, index, bedrock_y, LEVEL_CONFIGS[1],
		has_stairwell, stairwell_start_x, _l3_ground_y(), "LEVEL 3")

	# Level 3 — "Car Town": a flat driveable street below Level 2 (generated for ALL chunks).
	_generate_car_street(chunk, index, _l3_top_y(bedrock_y))
	# CAR TOWN racing gate — a big checkered start/finish gate next to the HOUSE that drops Francis
	# onto the Level 3 street. It only appears AFTER he's discovered Level 3 (descended the elevator
	# at least once), as a fast way back down. Placed in whichever chunk holds his house.
	if GameManager.found_level3 and (GameManager.home_pos_x != 0.0 or GameManager.home_pos_y != 0.0):
		var gate_world_x := GameManager.home_pos_x - 340.0   # just left of the castle, beside the house
		var gate_chunk := int(floor(gate_world_x / CHUNK_WIDTH))
		if index == gate_chunk:
			var gate_x := gate_world_x - index * CHUNK_WIDTH
			var gate_ground := _get_ground_y_at_px(index, gate_x, stairwell_centers)
			_add_cartown_gate(chunk, Vector2(gate_x, gate_ground),
				Vector2(L3_LAND_X, _l3_ground_y() - 40))

	# === ABOVE-GROUND DECORATIONS ===
	# Build exclusion zones — areas where trees/flowers/platforms must NOT spawn
	# Prevents clutter in front of structures
	var exclusion_zones: Array[Dictionary] = []
	if has_stairwell:
		# Stairwell shaft — wide exclusion so platforms NEVER block the descent
		var sw_center_x := (stairwell_start_x + STAIRWELL_WIDTH / 2.0) * BLOCK_SIZE
		exclusion_zones.append({"x": sw_center_x, "radius": 500.0})
	# Home castle (chunk 0)
	if ("hut" in GameManager.words_summoned or "house" in GameManager.words_summoned) and index == 0:
		exclusion_zones.append({"x": 400.0 + 120 + 240, "radius": 500.0})

	# Random platforms (0-1 per chunk, away from structures)
	var platform_count := _rng.randi_range(0, 1)
	for p in platform_count:
		var plat_x := _rng.randf_range(100, CHUNK_WIDTH - 100)
		if _is_in_exclusion_zone(plat_x, exclusion_zones):
			continue  # Skip — too close to a structure
		var plat_ground := _get_ground_y_at_px(index, plat_x, stairwell_centers)
		_add_platform(chunk, Vector2(
			plat_x,
			plat_ground - _rng.randf_range(75, 275)
		), _rng.randf_range(120, 220))

	# Random trees (1-2) — only appear after player spells "tree", away from structures
	var trees_unlocked := "tree" in GameManager.words_summoned
	var tree_count := _rng.randi_range(1, 2)
	for t in tree_count:
		var tree_x := _rng.randf_range(50, CHUNK_WIDTH - 50)
		if _is_in_exclusion_zone(tree_x, exclusion_zones):
			continue  # Skip — don't put trees in front of buildings
		var tree_ground := _get_ground_y_at_px(index, tree_x, stairwell_centers)
		if trees_unlocked:
			_add_tree(chunk, Vector2(tree_x, tree_ground))

	# Random flowers (2-4), away from structures
	var flower_count := _rng.randi_range(2, 4)
	for f in flower_count:
		var flower_x := _rng.randf_range(30, CHUNK_WIDTH - 30)
		if _is_in_exclusion_zone(flower_x, exclusion_zones):
			continue
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

	# Occasional archery target (20% chance, away from structures)
	if _rng.randf() < 0.2:
		var target_x := _rng.randf_range(200, CHUNK_WIDTH - 200)
		if not _is_in_exclusion_zone(target_x, exclusion_zones):
			var target_ground := _get_ground_y_at_px(index, target_x, stairwell_centers)
			_add_archery_target(chunk, Vector2(target_x, target_ground))

	# Surface treasure chests (1-2 per chunk, minimum 300px apart)
	var surface_chests := _rng.randi_range(1, 2)
	var chest_positions: Array[float] = []
	for sc in surface_chests:
		var chest_x := _rng.randf_range(100, CHUNK_WIDTH - 100)
		# Enforce minimum distance between chests
		var too_close := false
		for prev_x in chest_positions:
			if absf(chest_x - prev_x) < 300.0:
				too_close = true
				break
		if too_close or _is_in_exclusion_zone(chest_x, exclusion_zones):
			continue  # Skip — too close to another chest or a structure
		chest_positions.append(chest_x)
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

	# Try bedrock tile sprite, tiled across width
	var bedrock_tex_path := "res://assets/sprites/world/tile_bedrock.png"
	if ResourceLoader.exists(bedrock_tex_path):
		var tex = load(bedrock_tex_path) as Texture2D
		if tex:
			# Tile the 32px texture across the bedrock width
			var tile_count: int = int(ceil((width + 4) / 32.0))
			for ti in tile_count:
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.position = Vector2(-width / 2.0 - 2 + ti * 32 + 16, 0)
				bedrock.add_child(spr)
			return

	# Fallback: ColorRect
	var bedrock_visual := ColorRect.new()
	bedrock_visual.position = Vector2(-width / 2.0 - 2, -10)
	bedrock_visual.size = Vector2(width + 4, 20)
	bedrock_visual.color = Color(0.3, 0.3, 0.35, 1)
	bedrock.add_child(bedrock_visual)

func _is_in_exclusion_zone(x: float, zones: Array[Dictionary]) -> bool:
	## Returns true if x is within any exclusion zone (too close to a structure).
	for zone in zones:
		if absf(x - zone.get("x", 0.0)) < zone.get("radius", 200.0):
			return true
	return false

func _add_background_wall(container: Node2D, block_x: float, block_y: float, gx: int, gy: int, col_underground: int) -> void:
	## Background wall block — darker semi-transparent, visible when foreground is dug.
	var wall := ColorRect.new()
	wall.position = Vector2(block_x - BLOCK_SIZE / 2.0, block_y - BLOCK_SIZE / 2.0)
	wall.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	var wall_shade := float(absi((gx * 2654435761 + gy * 340573321) % 80)) / 1000.0
	if gy >= TerrainHeight.MAX_AMPLITUDE + 2:  # Roughly stone depth
		wall.color = Color(0.25 + wall_shade, 0.25 + wall_shade, 0.28 + wall_shade, 0.6)
	else:
		wall.color = Color(0.30 + wall_shade, 0.22 + wall_shade, 0.12 + wall_shade, 0.6)
	# Depth darkening on walls
	if gy >= 3:
		var depth_ratio := float(gy - 3) / float(maxi(col_underground - 3, 1))
		var brightness := lerpf(1.0, 0.4, clampf(depth_ratio, 0.0, 1.0))
		wall.modulate = Color(brightness, brightness, brightness, 1.0)
	container.add_child(wall)

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

	# Climbing ledges inside the shaft — ONE block wide, on the OUTER inner columns only,
	# alternating sides. The centre two inner columns are NEVER blocked, so there is always a
	# clear >=2-wide vertical channel: Francis can always drop straight down (or climb the
	# ledges back up) and can never get wedged. (Was a 2-wide zigzag that could fully block.)
	var going_left := true
	var current_y := stair_top_y + BLOCK_SIZE * 3
	var stop_y := l2_ground_y - BLOCK_SIZE * (exit_rows + 2)  # Stop ledges above exit zone
	while current_y < stop_y:
		var ledge_col := inner_left if going_left else inner_right
		_add_stair_block(stair_container, Vector2(
			ledge_col * BLOCK_SIZE + BLOCK_SIZE / 2.0, current_y))
		current_y += BLOCK_SIZE * 3
		going_left = not going_left

	# Shaft markers removed — pillars above are sufficient visual cue

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

	# Stairwell marker is now just the stone pillars — no text clutter

func _generate_descent_stairwell(chunk: Node2D, start_x: int, top_bedrock_y: float, target_ground_y: float, label_text: String) -> void:
	## Generic indestructible elevator shaft from one level's bedrock down to the next level's
	## ground — identical shape to the L1->L2 stairwell, parameterised by depth + label. The
	## centre two inner columns are ALWAYS clear, so Francis can never get wedged.
	var stair_container := Node2D.new()
	stair_container.name = "DescentStairwell"
	chunk.add_child(stair_container)
	var stair_top_y := top_bedrock_y - 10
	var total_depth: int = int((target_ground_y - stair_top_y) / BLOCK_SIZE) + 1
	var inner_left := start_x + 1
	var inner_right := start_x + STAIRWELL_WIDTH - 2
	var exit_rows := 6
	for step_i in total_depth:
		var wall_y := stair_top_y + step_i * BLOCK_SIZE
		var is_exit_zone := step_i >= (total_depth - exit_rows)
		if not is_exit_zone:
			_add_stair_block(stair_container, Vector2(
				start_x * BLOCK_SIZE + BLOCK_SIZE / 2.0, wall_y))
			_add_stair_block(stair_container, Vector2(
				(start_x + STAIRWELL_WIDTH - 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0, wall_y))
	var going_left := true
	var current_y := stair_top_y + BLOCK_SIZE * 3
	var stop_y := target_ground_y - BLOCK_SIZE * (exit_rows + 2)
	while current_y < stop_y:
		var ledge_col := inner_left if going_left else inner_right
		_add_stair_block(stair_container, Vector2(
			ledge_col * BLOCK_SIZE + BLOCK_SIZE / 2.0, current_y))
		current_y += BLOCK_SIZE * 3
		going_left = not going_left
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	label.position = Vector2((start_x + 1) * BLOCK_SIZE, target_ground_y - BLOCK_SIZE * 2)
	label.z_index = 5
	stair_container.add_child(label)

func _add_descent_marker(chunk: Node2D, start_x: int, surface_y: float) -> void:
	## Surface hint on the LEVEL 2 ground that there's a way down here — mirrors the L1 marker.
	var center_x := (start_x + STAIRWELL_WIDTH / 2.0) * BLOCK_SIZE
	var marker := Node2D.new()
	marker.name = "DescentMarker"
	marker.position = Vector2(center_x, surface_y)
	chunk.add_child(marker)
	for side in [-1, 1]:
		var pillar := ColorRect.new()
		pillar.position = Vector2(side * (STAIRWELL_WIDTH * BLOCK_SIZE / 2.0 - 8) - 6, -40)
		pillar.size = Vector2(12, 40)
		pillar.color = Color(0.4, 0.45, 0.55, 1)
		marker.add_child(pillar)
		var cap := ColorRect.new()
		cap.position = Vector2(side * (STAIRWELL_WIDTH * BLOCK_SIZE / 2.0 - 8) - 8, -46)
		cap.size = Vector2(16, 6)
		cap.color = Color(0.45, 0.5, 0.6, 1)
		marker.add_child(cap)
	var rune := ColorRect.new()
	rune.position = Vector2(-5, -20)
	rune.size = Vector2(10, 10)
	rune.color = Color(0.4, 0.7, 1.0, 0.6)
	rune.z_index = 2
	marker.add_child(rune)
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-30, -6)
	glow.size = Vector2(60, 12)
	glow.color = Color(0.3, 0.6, 1.0, 0.1)
	marker.add_child(glow)

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
	pad.collision_mask = 1  # Detect player bodies (layer 1)
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

# === PLAYER TELEPORT BEACON SYSTEM ===

func _on_teleport_beacon_placed(pos: Vector2) -> void:
	# Remove old beacon if any
	if _teleport_beacon and is_instance_valid(_teleport_beacon):
		_teleport_beacon.queue_free()

	# Create visual beacon at player position
	_teleport_beacon = _create_beacon_visual(pos)
	add_child(_teleport_beacon)

	# Save beacon position
	GameManager.teleport_beacon_x = pos.x
	GameManager.teleport_beacon_y = pos.y
	GameManager.save_game()

	# Also create/update HOME teleport pad if house exists
	_ensure_home_teleport()

	print("Francis-opia: Teleport beacon placed! Press E near it to teleport HOME.")

func _create_beacon_visual(pos: Vector2) -> Node2D:
	var beacon := Area2D.new()
	beacon.name = "TeleportBeacon"
	beacon.global_position = pos
	beacon.collision_layer = 4  # Interactable
	beacon.collision_mask = 1  # Detect player bodies (layer 1)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, 70)
	col.shape = shape
	col.position = Vector2(0, -30)
	beacon.add_child(col)

	# Diablo 1 style town portal: red/orange glowing oval
	# Outer glow
	var outer_glow := ColorRect.new()
	outer_glow.z_index = -1
	outer_glow.position = Vector2(-28, -68)
	outer_glow.size = Vector2(56, 76)
	outer_glow.color = Color(0.8, 0.3, 0.1, 0.12)
	beacon.add_child(outer_glow)

	# Portal ring segments (oval shape from rects)
	var portal_colors := [Color(0.9, 0.35, 0.1, 0.7), Color(1.0, 0.5, 0.15, 0.6), Color(0.8, 0.2, 0.05, 0.65)]
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var rx := cos(angle) * 18.0
		var ry := sin(angle) * 28.0
		var seg := ColorRect.new()
		seg.position = Vector2(rx - 4, -32 + ry - 4)
		seg.size = Vector2(8, 8)
		seg.color = portal_colors[i % portal_colors.size()]
		seg.z_index = 1
		beacon.add_child(seg)

	# Inner swirl (dark center)
	var inner := ColorRect.new()
	inner.position = Vector2(-10, -42)
	inner.size = Vector2(20, 24)
	inner.color = Color(0.15, 0.05, 0.2, 0.8)
	inner.z_index = 2
	beacon.add_child(inner)

	# Core glow
	var core := ColorRect.new()
	core.position = Vector2(-6, -38)
	core.size = Vector2(12, 16)
	core.color = Color(0.9, 0.4, 0.15, 0.5)
	core.z_index = 3
	beacon.add_child(core)

	# Base rune circle on ground
	var rune := ColorRect.new()
	rune.position = Vector2(-20, -4)
	rune.size = Vector2(40, 6)
	rune.color = Color(0.8, 0.3, 0.1, 0.6)
	beacon.add_child(rune)

	# Label
	var label := Label.new()
	label.text = "PORTAL"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0, 0.7))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -76)
	label.size = Vector2(60, 18)
	label.z_index = 5
	beacon.add_child(label)

	# Pulsing animation
	var pulser := Node2D.new()
	pulser.name = "Pulser"
	beacon.add_child(pulser)
	var pulse_script := GDScript.new()
	pulse_script.source_code = """extends Node2D
var _time := 0.0
func _process(delta):
	_time += delta
	get_parent().modulate.a = 0.8 + sin(_time * 2.5) * 0.2
"""
	pulse_script.reload()
	pulser.set_script(pulse_script)

	# Interaction script: teleport to HOME
	var script := GDScript.new()
	var code := "extends Area2D\n\n"
	code += "func interact() -> void:\n"
	code += "\tvar home_x := GameManager.home_pos_x\n"
	code += "\tvar home_y := GameManager.home_pos_y\n"
	code += "\tif home_x == 0.0 and home_y == 0.0:\n"
	code += "\t\tprint(\"Francis-opia: No home yet! Spell HOUSE first.\")\n"
	code += "\t\treturn\n"
	code += "\tvar target := Vector2(home_x, home_y)\n"  # Inside the house
	code += "\tvar bodies := get_overlapping_bodies()\n"
	code += "\tfor body in bodies:\n"
	code += "\t\tif body is CharacterBody2D and body.name.begins_with(\"Player\"):\n"
	code += "\t\t\tbody.global_position = target\n"
	code += "\t\t\tbody.velocity = Vector2.ZERO\n"
	code += "\t\t\tvar magic := body.get_node_or_null(\"/root/MagicSummon\")\n"
	code += "\t\t\tif magic:\n"
	code += "\t\t\t\tmagic.teleport_active_companion(target)\n"
	code += "\t\t\tprint(\"Francis-opia: Teleported HOME!\")\n"
	script.source_code = code
	script.reload()
	beacon.set_script(script)

	return beacon

func _ensure_home_teleport() -> void:
	if GameManager.home_pos_x == 0.0 and GameManager.home_pos_y == 0.0:
		return
	# Remove old home teleport pad
	if _home_teleport_pad and is_instance_valid(_home_teleport_pad):
		_home_teleport_pad.queue_free()

	# Create teleport pad at HOME that goes back to beacon
	var home_pos := Vector2(GameManager.home_pos_x, GameManager.home_pos_y)
	_home_teleport_pad = Area2D.new()
	_home_teleport_pad.name = "HomeTeleportPad"
	_home_teleport_pad.global_position = home_pos
	_home_teleport_pad.collision_layer = 4
	_home_teleport_pad.collision_mask = 1  # Detect player bodies (layer 1)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, 70)
	col.shape = shape
	col.position = Vector2(0, -30)
	_home_teleport_pad.add_child(col)

	# Matching Diablo 1 portal (blue tint for return)
	var outer_glow := ColorRect.new()
	outer_glow.z_index = -1
	outer_glow.position = Vector2(-28, -68)
	outer_glow.size = Vector2(56, 76)
	outer_glow.color = Color(0.1, 0.3, 0.8, 0.12)
	_home_teleport_pad.add_child(outer_glow)
	var p_colors := [Color(0.2, 0.4, 0.9, 0.7), Color(0.3, 0.5, 1.0, 0.6), Color(0.15, 0.3, 0.85, 0.65)]
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var rx := cos(angle) * 18.0
		var ry := sin(angle) * 28.0
		var seg := ColorRect.new()
		seg.position = Vector2(rx - 4, -32 + ry - 4)
		seg.size = Vector2(8, 8)
		seg.color = p_colors[i % p_colors.size()]
		seg.z_index = 1
		_home_teleport_pad.add_child(seg)
	var inner := ColorRect.new()
	inner.position = Vector2(-10, -42)
	inner.size = Vector2(20, 24)
	inner.color = Color(0.05, 0.1, 0.2, 0.8)
	inner.z_index = 2
	_home_teleport_pad.add_child(inner)
	var core := ColorRect.new()
	core.position = Vector2(-6, -38)
	core.size = Vector2(12, 16)
	core.color = Color(0.3, 0.5, 1.0, 0.5)
	core.z_index = 3
	_home_teleport_pad.add_child(core)
	var rune := ColorRect.new()
	rune.position = Vector2(-20, -4)
	rune.size = Vector2(40, 6)
	rune.color = Color(0.2, 0.4, 0.9, 0.6)
	_home_teleport_pad.add_child(rune)
	var label := Label.new()
	label.text = "RETURN"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0.05, 0.2, 0.7))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -76)
	label.size = Vector2(60, 18)
	label.z_index = 5
	_home_teleport_pad.add_child(label)
	# Pulse animation
	var pulser := Node2D.new()
	_home_teleport_pad.add_child(pulser)
	var ps := GDScript.new()
	ps.source_code = "extends Node2D\nvar _t := 0.0\nfunc _process(d):\n\t_t += d\n\tget_parent().modulate.a = 0.8 + sin(_t * 2.5) * 0.2\n"
	ps.reload()
	pulser.set_script(ps)

	# Script: teleport back to beacon
	var script := GDScript.new()
	var code := "extends Area2D\n\n"
	code += "func interact() -> void:\n"
	code += "\tvar bx := GameManager.teleport_beacon_x\n"
	code += "\tvar by := GameManager.teleport_beacon_y\n"
	code += "\tif bx == 0.0 and by == 0.0:\n"
	code += "\t\tprint(\"Francis-opia: No beacon placed! Press T to place one.\")\n"
	code += "\t\treturn\n"
	code += "\tvar target := Vector2(bx, by)\n"
	code += "\tvar bodies := get_overlapping_bodies()\n"
	code += "\tfor body in bodies:\n"
	code += "\t\tif body is CharacterBody2D and body.name.begins_with(\"Player\"):\n"
	code += "\t\t\tbody.global_position = target\n"
	code += "\t\t\tbody.velocity = Vector2.ZERO\n"
	code += "\t\t\tvar magic := body.get_node_or_null(\"/root/MagicSummon\")\n"
	code += "\t\t\tif magic:\n"
	code += "\t\t\t\tmagic.teleport_active_companion(target)\n"
	code += "\t\t\tprint(\"Francis-opia: Teleported back to beacon!\")\n"
	script.source_code = code
	script.reload()
	_home_teleport_pad.set_script(script)

	add_child(_home_teleport_pad)
	_ensure_house_door()

# =====================================================================
# HOUSE INTERIOR (Slice 1: enter, look around, exit). Architecture:
# docs/house-interior-architecture.md. Self-contained build/teardown that
# swaps out the overworld — no procedural-generator surgery.
# =====================================================================

func _ensure_house_door() -> void:
	## The ENTRANCE to the house IS the castle's own doorway (home_pos sits on the castle door).
	## We do NOT draw a second door — the castle sprite already has one. We just place an
	## invisible interact zone over it plus an "ENTRANCE" sign above. Stand on it + press the
	## action button to go inside. Only exists once Francis has a house (home_pos set).
	if GameManager.home_pos_x == 0.0 and GameManager.home_pos_y == 0.0:
		return
	if _house_door and is_instance_valid(_house_door):
		_house_door.queue_free()
	_house_door = Area2D.new()
	_house_door.name = "HouseEnterDoor"
	# Centre the zone on the castle's own door (home_pos), not 60px to the side.
	_house_door.global_position = Vector2(GameManager.home_pos_x, GameManager.home_pos_y)
	_house_door.collision_layer = 4
	_house_door.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# BIG, forgiving zone — Francis only has to be NEAR the castle (anywhere in the doorway
	# region), not on an exact pixel. Spans ~300px wide and from below ground to well overhead.
	shape.size = Vector2(320, 260)
	col.position = Vector2(0, -10)
	col.shape = shape
	_house_door.add_child(col)
	# No fake door rect — reuse the castle's drawn doorway. Just a floating "ENTRANCE" sign.
	var label := Label.new()
	label.text = "ENTRANCE"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-55, -120)
	label.size = Vector2(110, 20)
	_house_door.add_child(label)
	var ds := GDScript.new()
	ds.source_code = "extends Area2D\nfunc interact() -> void:\n\tvar s = get_tree().current_scene\n\tif s and s.has_method(\"enter_house\"):\n\t\ts.enter_house()\n"
	ds.reload()
	_house_door.set_script(ds)
	add_child(_house_door)

func enter_house() -> void:
	if _in_house:
		return
	_in_house = true
	GameManager.in_house = true
	GameManager.house_outdoor_x = player.global_position.x
	GameManager.house_outdoor_y = player.global_position.y
	# Tear down the overworld + overworld interactables.
	for idx in _chunks.keys().duplicate():
		_remove_chunk(idx)
	if _house_door and is_instance_valid(_house_door):
		_house_door.queue_free()
	if _home_teleport_pad and is_instance_valid(_home_teleport_pad):
		_home_teleport_pad.queue_free()
	_build_house_interior()
	# Drop Francis just inside the entrance and bring his followers in with him.
	player.global_position = Vector2(56.0, GROUND_Y - 24.0)
	player.velocity = Vector2.ZERO
	var ms := get_node_or_null("/root/MagicSummon")
	if ms and ms.has_method("teleport_active_companion"):
		ms.teleport_active_companion(player.global_position)

func exit_house() -> void:
	if not _in_house:
		return
	_in_house = false
	GameManager.in_house = false
	if _house_root and is_instance_valid(_house_root):
		_house_root.queue_free()
		_house_root = null
	player.global_position = Vector2(GameManager.house_outdoor_x, GameManager.house_outdoor_y)
	player.velocity = Vector2.ZERO
	_regenerate_all_chunks()
	_ensure_house_door()
	_ensure_home_teleport()
	var ms := get_node_or_null("/root/MagicSummon")
	if ms and ms.has_method("teleport_active_companion"):
		ms.teleport_active_companion(player.global_position)

# =====================================================================
# LEVEL 3 — "CAR TOWN": a flat, paved, driveable street below Level 2.
# Reached via the CAR TOWN portal near spawn. No digging (the road is solid,
# non-diggable). A VAN greets you at the landing; CAR + more are parked along it.
# =====================================================================

func _l3_top_y(l1_bedrock_y: float) -> float:
	## Absolute Y of the top of the Level 3 sky band — just below Level 2's bedrock floor.
	var l2_sky_h: float = LEVEL_CONFIGS[1].get("sky_height", 450.0)
	var l2_under: int = LEVEL_CONFIGS[1].get("underground_rows", 8)
	var l2_ground_y := (l1_bedrock_y + 20) + l2_sky_h
	var l2_bedrock_y := l2_ground_y + (l2_under + 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
	return l2_bedrock_y + 20

func _l3_ground_y() -> float:
	## Absolute Y of the Level 3 street surface (flat — same for every chunk).
	return _l3_top_y(BEDROCK_Y) + L3_SKY_H

func _generate_car_street(chunk: Node2D, chunk_index: int, top_y: float) -> void:
	var ground_y := top_y + L3_SKY_H
	# Sky.
	var sky := ColorRect.new()
	sky.z_index = -10
	sky.position = Vector2(0, top_y - 10)
	sky.size = Vector2(CHUNK_WIDTH, L3_SKY_H + 220)
	sky.color = Color(0.55, 0.78, 0.95, 1)
	chunk.add_child(sky)
	for _c in 2:
		var cloud := ColorRect.new()
		cloud.z_index = -9
		cloud.position = Vector2(_rng.randf_range(0, CHUNK_WIDTH - 170), top_y + _rng.randf_range(26, 150))
		cloud.size = Vector2(_rng.randf_range(110, 190), _rng.randf_range(24, 40))
		cloud.color = Color(1, 1, 1, 0.7)
		chunk.add_child(cloud)
	# Houses far in the background.
	var hx := 30.0
	while hx < CHUNK_WIDTH - 130:
		_add_street_house(chunk, Vector2(hx, ground_y - 124))
		hx += _rng.randf_range(250, 360)
	# Sidewalk + curb.
	var sidewalk := ColorRect.new()
	sidewalk.z_index = -3
	sidewalk.position = Vector2(0, ground_y - 24)
	sidewalk.size = Vector2(CHUNK_WIDTH, 24)
	sidewalk.color = Color(0.74, 0.74, 0.76, 1)
	chunk.add_child(sidewalk)
	# Solid paved road — collision floor, NOT a diggable block, so there's no digging here.
	var road := StaticBody2D.new()
	road.position = Vector2(CHUNK_WIDTH / 2.0, ground_y + 60)
	road.collision_layer = 1
	road.collision_mask = 0
	chunk.add_child(road)
	var road_col := CollisionShape2D.new()
	var road_shape := RectangleShape2D.new()
	road_shape.size = Vector2(CHUNK_WIDTH + 4, 120)
	road_col.shape = road_shape
	road.add_child(road_col)
	var road_vis := ColorRect.new()
	road_vis.z_index = -4
	road_vis.position = Vector2(-CHUNK_WIDTH / 2.0, -60)
	road_vis.size = Vector2(CHUNK_WIDTH + 4, 120)
	road_vis.color = Color(0.28, 0.28, 0.31, 1)
	road.add_child(road_vis)
	# Dashed centre line.
	var lx := 18.0
	while lx < CHUNK_WIDTH:
		var dash := ColorRect.new()
		dash.z_index = -3
		dash.position = Vector2(lx, ground_y + 44)
		dash.size = Vector2(34, 6)
		dash.color = Color(0.95, 0.85, 0.2, 0.9)
		chunk.add_child(dash)
		lx += 64.0
	# Treasure — Car Town has LOTS of chests on the pavement by the houses (you can't dig here).
	for _ci in _rng.randi_range(2, 4):
		_spawn_surface_chest(chunk, Vector2(_rng.randf_range(110, CHUNK_WIDTH - 110), ground_y - 33))
	# Cars — ONLY the types Francis has SPELLED appear, and only parked at the entrance (chunk 0).
	# There are no cars at all until he spells one. (Driving carries Francis + his animals along.)
	if chunk_index == 0:
		var slot := 0
		for cw in L3_CAR_WORDS:
			if cw in GameManager.items_owned:
				_add_street_vehicle(chunk, Vector2(L3_LAND_X + 150.0 + slot * 250.0, ground_y), cw)
				slot += 1
		_add_l3_return_portal(chunk, Vector2(L3_LAND_X - 90, ground_y - 30))
		var town_sign := Label.new()
		town_sign.text = "CAR TOWN"
		town_sign.add_theme_font_size_override("font_size", 26)
		town_sign.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
		town_sign.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		town_sign.add_theme_constant_override("outline_size", 3)
		town_sign.position = Vector2(L3_LAND_X - 36, top_y + 56)
		town_sign.z_index = 5
		chunk.add_child(town_sign)
		if slot == 0:
			var tip := Label.new()
			tip.text = "Spell VAN, CAR or BUS to park one here!"
			tip.add_theme_font_size_override("font_size", 17)
			tip.add_theme_color_override("font_color", Color(0.15, 0.2, 0.35))
			tip.position = Vector2(L3_LAND_X - 30, top_y + 110)
			tip.z_index = 5
			chunk.add_child(tip)

func _add_street_house(chunk: Node2D, pos: Vector2) -> void:
	var house := Node2D.new()
	house.position = pos
	house.z_index = -7
	chunk.add_child(house)
	var palette := [Color(0.86, 0.72, 0.62), Color(0.72, 0.79, 0.86), Color(0.83, 0.84, 0.64), Color(0.84, 0.67, 0.64)]
	var body_col: Color = palette[absi(int(pos.x)) % palette.size()]
	var body := ColorRect.new()
	body.position = Vector2.ZERO
	body.size = Vector2(154, 124)
	body.color = body_col
	house.add_child(body)
	var roof := ColorRect.new()
	roof.position = Vector2(-8, -22)
	roof.size = Vector2(170, 24)
	roof.color = Color(0.45, 0.31, 0.28)
	house.add_child(roof)
	var door := ColorRect.new()
	door.position = Vector2(66, 82)
	door.size = Vector2(28, 42)
	door.color = Color(0.4, 0.28, 0.2)
	house.add_child(door)
	for wxy in [Vector2(18, 22), Vector2(108, 22), Vector2(18, 62), Vector2(108, 62)]:
		var win_pos: Vector2 = wxy
		var win := ColorRect.new()
		win.position = win_pos
		win.size = Vector2(30, 26)
		win.color = Color(0.6, 0.8, 0.95)
		house.add_child(win)

func _add_street_vehicle_at(world_x: float, kind: String) -> void:
	## Spawn a driveable vehicle at runtime (when a car word is spelled on Level 3), parented to
	## the scene so it isn't freed when chunks unload. Replaces any existing one of the same kind
	## so repeated spelling can't pile up (memory-safe).
	var existing := get_node_or_null("Vehicle_%s" % kind)
	if existing and is_instance_valid(existing):
		existing.queue_free()
	_add_street_vehicle(self, Vector2(world_x, _l3_ground_y()), kind)

func _add_street_vehicle(parent: Node2D, pos: Vector2, kind: String) -> void:
	## A parked, driveable vehicle. Interact zone (layer 4) -> enter_vehicle. VAN and BUS use their
	## REAL rendered sprites (van.png / bus.png — the same art shown when you spell them); CAR has no
	## sprite so it falls back to a drawn sedan.
	var v := Area2D.new()
	v.name = "Vehicle_%s" % kind
	v.position = pos                       # origin at the road surface (wheels at y=0)
	v.collision_layer = 4
	v.collision_mask = 1
	v.set_meta("vehicle_kind", kind)
	var iw := 80.0     # interact half-width
	var ih := 120.0    # interact height
	var hint_y := -132.0
	var sprite_path := "res://assets/sprites/summons/%s.png" % kind
	var tex = load(sprite_path) if ResourceLoader.exists(sprite_path) else null
	if tex:
		# REAL rendered sprite — scaled up so Francis can drive it; bottom sits on the road.
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc := 2.2 if kind == "van" else 1.5   # the VAN is ~50% bigger than the others
		spr.scale = Vector2(sc, sc)
		var tw2 := float(tex.get_width()) * sc
		var th2 := float(tex.get_height()) * sc
		spr.position = Vector2(0, -th2 / 2.0 + 6.0)
		spr.z_index = 0
		v.add_child(spr)
		iw = tw2 * 0.40
		ih = th2
		hint_y = -th2 - 2.0
		# Where Francis sits and where the animals ride, proportional to the vehicle height.
		v.set_meta("seat_y", -th2 * 0.34)
		v.set_meta("roof_y", -th2 * 0.66)
	else:
		_draw_car(v, pos)
		v.set_meta("seat_y", -34.0)
		v.set_meta("roof_y", -58.0)
	# Big, forgiving interact zone.
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(iw * 2.0 + 40, ih + 30)
	col.position = Vector2(0, -ih / 2.0)
	col.shape = shape
	v.add_child(col)
	var hint := Label.new()
	hint.text = "Press X to drive"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 0.9))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("outline_size", 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-70, hint_y)
	hint.size = Vector2(140, 18)
	v.add_child(hint)
	var vs := GDScript.new()
	vs.source_code = "extends Area2D\nfunc interact() -> void:\n\tvar s = get_tree().current_scene\n\tif s and s.has_method(\"enter_vehicle\"):\n\t\ts.enter_vehicle(self)\n"
	vs.reload()
	v.set_script(vs)
	parent.add_child(v)

func _draw_car(v: Area2D, pos: Vector2) -> void:
	## Drawn sedan — the fallback for CAR (which has no sprite). Wheels at y=0 (road).
	var w := 122.0
	var h := 50.0
	var car_palette := [Color(0.85, 0.25, 0.25), Color(0.2, 0.5, 0.85), Color(0.3, 0.72, 0.45), Color(0.7, 0.3, 0.7)]
	var body_col: Color = car_palette[absi(int(pos.x)) % car_palette.size()]
	for wx in [-w * 0.32, w * 0.32]:
		var wheel := ColorRect.new()
		wheel.position = Vector2(wx - 11, -22); wheel.size = Vector2(22, 22); wheel.color = Color(0.12, 0.12, 0.14, 1)
		v.add_child(wheel)
		var hub := ColorRect.new()
		hub.position = Vector2(wx - 5, -15); hub.size = Vector2(10, 10); hub.color = Color(0.65, 0.65, 0.7, 1)
		v.add_child(hub)
	var body := ColorRect.new()
	body.position = Vector2(-w / 2.0, -h - 16); body.size = Vector2(w, h); body.color = body_col
	v.add_child(body)
	var trim := ColorRect.new()
	trim.position = Vector2(-w / 2.0, -18); trim.size = Vector2(w, 6); trim.color = body_col.darkened(0.4)
	v.add_child(trim)
	var cabin := ColorRect.new()
	cabin.position = Vector2(-w / 2.0 + 26, -h - 12); cabin.size = Vector2(w - 52, h - 16); cabin.color = Color(0.62, 0.83, 0.96, 1)
	v.add_child(cabin)
	var light := ColorRect.new()
	light.position = Vector2(w / 2.0 - 6, -h + 2); light.size = Vector2(5, 9); light.color = Color(1.0, 0.95, 0.6, 1)
	v.add_child(light)

func _add_icecream(parent: Node2D, base: Vector2) -> void:
	## A big ice-cream cone (cone + two scoops + a cherry) sitting on the van roof.
	var holder := Node2D.new()
	holder.position = base
	parent.add_child(holder)
	var cone := Polygon2D.new()
	cone.polygon = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(0, 34)])
	cone.color = Color(0.85, 0.6, 0.32, 1)
	holder.add_child(cone)
	holder.add_child(_blob(Vector2(0, -6), 21.0, Color(0.6, 0.9, 0.72, 1)))    # mint scoop
	holder.add_child(_blob(Vector2(0, -28), 18.0, Color(0.98, 0.7, 0.78, 1)))  # strawberry scoop
	holder.add_child(_blob(Vector2(0, -46), 6.0, Color(0.9, 0.15, 0.2, 1)))    # cherry

func _blob(center: Vector2, r: float, c: Color) -> Polygon2D:
	## A filled circle (12-gon) used for ice-cream scoops.
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	poly.color = c
	return poly

func _add_l3_return_portal(chunk: Node2D, pos: Vector2) -> void:
	## A portal on the Level 3 street that takes Francis back up to the surface near spawn.
	_add_teleport_pad(chunk, pos, Vector2(720, GROUND_Y - 40), "SURFACE")

func _add_cartown_gate(chunk: Node2D, pos: Vector2, target: Vector2) -> void:
	## A big checkered racing START/FINISH gate (next to the house) that drops Francis onto the
	## Level 3 street. Stand under it + press the action button. Hard to miss — that's the point.
	var gate := Area2D.new()
	gate.name = "CarTownGate"
	gate.position = pos
	gate.collision_layer = 4
	gate.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(132, 130)
	col.position = Vector2(0, -65)
	col.shape = shape
	gate.add_child(col)
	var post_h := 116.0
	# Two candy-striped posts.
	for side in [-1.0, 1.0]:
		var post_x: float = side * 58.0
		var n := 12
		for i in n:
			var seg := ColorRect.new()
			seg.position = Vector2(post_x - 8, -post_h + i * (post_h / n))
			seg.size = Vector2(16, post_h / n + 1.0)
			seg.color = Color(0.86, 0.18, 0.2, 1) if i % 2 == 0 else Color(1, 1, 1, 1)
			seg.z_index = 2
			gate.add_child(seg)
	# Dark top banner + checker squares + label.
	var by := -post_h - 30.0
	var banner := ColorRect.new()
	banner.position = Vector2(-70, by)
	banner.size = Vector2(140, 32)
	banner.color = Color(0.12, 0.12, 0.15, 1)
	banner.z_index = 2
	gate.add_child(banner)
	var sq := 8.0
	for cxn in 17:
		for cyn in 4:
			if (cxn + cyn) % 2 == 0:
				var chk := ColorRect.new()
				chk.position = Vector2(-68 + cxn * sq, by + 2 + cyn * sq)
				chk.size = Vector2(sq, sq)
				chk.color = Color(1, 1, 1, 0.85)
				chk.z_index = 3
				gate.add_child(chk)
	var label := Label.new()
	label.text = "CAR TOWN"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-70, by + 4)
	label.size = Vector2(140, 28)
	label.z_index = 4
	gate.add_child(label)
	# Checkered finish line painted on the ground.
	for fi in 13:
		var fl := ColorRect.new()
		fl.position = Vector2(-64 + fi * 10, -6)
		fl.size = Vector2(10, 8)
		fl.color = Color(0.1, 0.1, 0.12, 1) if fi % 2 == 0 else Color(1, 1, 1, 1)
		fl.z_index = 1
		gate.add_child(fl)
	# A waving checkered flag on top.
	var flag := ColorRect.new()
	flag.position = Vector2(58, by - 24)
	flag.size = Vector2(26, 18)
	flag.color = Color(0.95, 0.95, 0.95, 1)
	flag.z_index = 3
	gate.add_child(flag)
	var hint := Label.new()
	hint.text = "Press X to race down!"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 0.85))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-90, -post_h * 0.5)
	hint.size = Vector2(180, 18)
	hint.z_index = 4
	gate.add_child(hint)
	var script := GDScript.new()
	var code := "extends Area2D\n\n"
	code += "var tgt := Vector2(%f, %f)\n\n" % [target.x, target.y]
	code += "func interact() -> void:\n"
	code += "\tfor body in get_overlapping_bodies():\n"
	code += "\t\tif body is CharacterBody2D and body.name.begins_with(\"Player\"):\n"
	code += "\t\t\tbody.global_position = tgt\n"
	code += "\t\t\tbody.velocity = Vector2.ZERO\n"
	code += "\t\t\tvar m = body.get_node_or_null(\"/root/MagicSummon\")\n"
	code += "\t\t\tif m and m.has_method(\"teleport_active_companion\"):\n"
	code += "\t\t\t\tm.teleport_active_companion(tgt)\n"
	code += "\t\t\tprint(\"Francis-opia: Racing down to Car Town!\")\n"
	script.source_code = code
	script.reload()
	gate.set_script(script)
	chunk.add_child(gate)

func enter_vehicle(vehicle: Node2D) -> void:
	if _driving or not is_instance_valid(vehicle) or not player:
		return
	_driving = true
	_driven_vehicle = vehicle
	_drive_lock = 0.35
	# Detach from its chunk (deferred — safe during physics) so driving across chunk
	# boundaries can't free the van when its home chunk unloads.
	_reparent_vehicle.call_deferred(vehicle)
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.visible = true   # Francis stays VISIBLE, riding in the cab.
	player.z_index = 3      # draw him on top of the vehicle body
	# Bring his ACTIVE animals along for the ride (freeze their physics so they sit on the roof).
	_drive_companions.clear()
	var ms_c := get_node_or_null("/root/MagicSummon")
	if ms_c and ms_c.has_method("get_companion_nodes"):
		var nodes: Dictionary = ms_c.get_companion_nodes()
		for wname in nodes:
			if wname in GameManager.active_companions and is_instance_valid(nodes[wname]):
				var c: Node = nodes[wname]
				_drive_companions.append(c)
				if c.has_method("set_physics_process"):
					c.set_physics_process(false)
	# On-screen driving hint.
	if _drive_hint and is_instance_valid(_drive_hint):
		_drive_hint.queue_free()
	_drive_hint = CanvasLayer.new()
	_drive_hint.layer = 60
	var lbl := Label.new()
	lbl.text = "VROOM!   Arrow keys to drive   -   X to get out"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(40, 28)
	_drive_hint.add_child(lbl)
	add_child(_drive_hint)
	var sfx := get_node_or_null("/root/SoundFX")
	if sfx and sfx.has_method("play_summon_accent"):
		sfx.play_summon_accent("world")
	print("Francis-opia: Vroom! Driving the %s!" % str(vehicle.get_meta("vehicle_kind", "car")))

func _reparent_vehicle(vehicle: Node) -> void:
	if is_instance_valid(vehicle) and vehicle.get_parent() != self:
		vehicle.reparent(self)

func _drive_update(delta: float) -> void:
	if _drive_lock > 0.0:
		_drive_lock -= delta
	if not is_instance_valid(_driven_vehicle):
		exit_vehicle()
		return
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_driven_vehicle.global_position.x += dir * DRIVE_SPEED * delta
		# Sprites face LEFT by default, so flip to -1 when driving RIGHT (otherwise it looks like
		# it's reversing).
		_driven_vehicle.scale.x = -1.0 if dir > 0.0 else 1.0
	_driven_vehicle.global_position.y = _l3_ground_y()
	var seat_y := -46.0
	var roof_y := -86.0
	if _driven_vehicle.has_meta("seat_y"):
		seat_y = _driven_vehicle.get_meta("seat_y")
	if _driven_vehicle.has_meta("roof_y"):
		roof_y = _driven_vehicle.get_meta("roof_y")
	if player:
		# Francis sits in the driver area, visible, riding along.
		player.global_position = _driven_vehicle.global_position + Vector2(0, seat_y)
		player.velocity = Vector2.ZERO
	# The animals ride on the roof, spread out so they don't overlap.
	for i in _drive_companions.size():
		var c = _drive_companions[i]
		if is_instance_valid(c):
			c.global_position = _driven_vehicle.global_position + Vector2(-52.0 + i * 36.0, roof_y)
			if "velocity" in c:
				c.velocity = Vector2.ZERO
	if _drive_lock <= 0.0 and Input.is_action_just_pressed("interact"):
		exit_vehicle()

func exit_vehicle() -> void:
	if not _driving:
		return
	_driving = false
	if is_instance_valid(_driven_vehicle):
		_driven_vehicle.scale.x = 1.0
		if player:
			player.global_position = _driven_vehicle.global_position + Vector2(96, -24)
	# Let the animals walk again, next to the vehicle.
	for c in _drive_companions:
		if is_instance_valid(c):
			if c.has_method("set_physics_process"):
				c.set_physics_process(true)
			if is_instance_valid(_driven_vehicle):
				c.global_position = _driven_vehicle.global_position + Vector2(60, -24)
	_drive_companions.clear()
	_driven_vehicle = null
	if _drive_hint and is_instance_valid(_drive_hint):
		_drive_hint.queue_free()
		_drive_hint = null
	if player:
		player.velocity = Vector2.ZERO
		player.visible = true
		player.z_index = 0
		player.set_physics_process(true)
	print("Francis-opia: Hopped out!")

func _animal_color(word: String) -> Color:
	var ms := get_node_or_null("/root/MagicSummon")
	if ms and "summon_registry" in ms:
		var e: Dictionary = ms.summon_registry.get(word, {})
		if e.has("color"):
			var c: Color = e["color"]
			return c
	return Color(0.6, 0.5, 0.4)

func _build_house_interior() -> void:
	_house_root = Node2D.new()
	_house_root.name = "HouseInterior"
	add_child(_house_root)
	var fy := GROUND_Y
	var following: Array = GameManager.active_companions
	# Width = living room (0) + a room per housed animal + 1 ghost room to telegraph more.
	var max_room := 0
	for w in GameManager.housed_animals:
		max_room = maxi(max_room, GameManager.get_room_index(w))
	var total_rooms := max_room + 2
	var floor_w := float(total_rooms) * HOUSE_ROOM_W

	# Beautifully-rendered interior shell — plaster walls with wallpaper stripes, a beamed
	# ceiling, wainscot panelling, a wood-plank floor and a daylight window — so the inside
	# reads as polished as Level 1 instead of a flat tan box.
	_decorate_house_shell(floor_w, fy)

	# Solid floor
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, fy)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	_house_root.add_child(floor_body)
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(floor_w, 40)
	floor_col.position = Vector2(floor_w / 2.0, 20)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	# (the floor SURFACE is drawn as wood planks by _decorate_house_shell, above)

	# Far-right wall stops Francis walking off the end.
	var rwall := StaticBody2D.new()
	rwall.position = Vector2(floor_w, fy - 120)
	rwall.collision_layer = 1
	rwall.collision_mask = 0
	_house_root.add_child(rwall)
	var rwall_col := CollisionShape2D.new()
	var rwall_shape := RectangleShape2D.new()
	rwall_shape.size = Vector2(20, 280)
	rwall_col.shape = rwall_shape
	rwall.add_child(rwall_col)

	# Left wall + ceiling — Francis can no longer fall out the left or jump out the top.
	var lwall := StaticBody2D.new()
	lwall.position = Vector2(-10, fy - 140)
	lwall.collision_layer = 1
	lwall.collision_mask = 0
	_house_root.add_child(lwall)
	var lwall_col := CollisionShape2D.new()
	var lwall_shape := RectangleShape2D.new()
	lwall_shape.size = Vector2(20, 320)
	lwall_col.shape = lwall_shape
	lwall.add_child(lwall_col)
	var ceil := StaticBody2D.new()
	ceil.position = Vector2(floor_w / 2.0, fy - 282)
	ceil.collision_layer = 1
	ceil.collision_mask = 0
	_house_root.add_child(ceil)
	var ceil_col := CollisionShape2D.new()
	var ceil_shape := RectangleShape2D.new()
	ceil_shape.size = Vector2(floor_w, 16)
	ceil_col.shape = ceil_shape
	ceil.add_child(ceil_col)

	# Header
	var header := Label.new()
	header.text = "Francis's House"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.5, 0.3, 0.15))
	header.position = Vector2(40, fy - 250)
	_house_root.add_child(header)

	# Living room: rug + decorative stairs (background, NOT interactable — no false affordance).
	var rug := ColorRect.new()
	rug.position = Vector2(70, fy - 22)
	rug.size = Vector2(120, 14)
	rug.color = Color(0.7, 0.3, 0.3, 0.8)
	_house_root.add_child(rug)
	for i in 5:
		var step := ColorRect.new()
		step.z_index = -5
		step.position = Vector2(200.0 + i * 12.0, fy - 40.0 - i * 18.0)
		step.size = Vector2(64 - i * 4, 14)
		step.color = Color(0.62, 0.45, 0.28, 1)
		_house_root.add_child(step)

	# Exit doors at BOTH ends (NOT the middle — a middle door would overlap a room's tap-zone
	# and pressing X would both toggle the animal AND exit. Ends are clear of all rooms).
	_build_house_exit_door(30.0)
	_build_house_exit_door(floor_w - 30.0)

	# One room per housed animal (deterministic room index, never reshuffled).
	for w in GameManager.housed_animals:
		var ri := GameManager.get_room_index(w)
		var rx := float(ri) * HOUSE_ROOM_W
		var divider := ColorRect.new()
		divider.z_index = -6
		divider.position = Vector2(rx - 6, fy - 210)
		divider.size = Vector2(6, 210)
		divider.color = Color(0.66, 0.46, 0.34, 1)
		_house_root.add_child(divider)
		var sign_label := Label.new()
		sign_label.text = w.to_upper()
		sign_label.add_theme_font_size_override("font_size", 16)
		sign_label.add_theme_color_override("font_color", Color(0.4, 0.25, 0.12))
		sign_label.position = Vector2(rx + 40, fy - 200)
		_house_root.add_child(sign_label)
		var bed := ColorRect.new()
		bed.position = Vector2(rx + 44, fy - 10)
		bed.size = Vector2(44, 8)
		bed.color = Color(0.55, 0.5, 0.7, 1)
		_house_root.add_child(bed)
		if w in following:
			# Out with Francis — empty bed + a note (the animal is NOT duplicated here).
			var note := Label.new()
			note.text = "(out with you!)"
			note.add_theme_font_size_override("font_size", 12)
			note.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
			note.position = Vector2(rx + 40, fy - 180)
			_house_root.add_child(note)
		else:
			# Home — render the actual animal: its pixel sprite if one exists, else a shape.
			_house_root.add_child(_house_item_visual(w, Vector2(rx + 64, fy - 30), 0.24))
		# Slice 2: the WHOLE room is a big tap-zone. Press X anywhere in it to take this animal
		# with you (or send it home if it's already following). Generous size for a 5-year-old.
		_build_room_animal_zone(w, rx, fy, w in following)

	# A dim ghost room to telegraph "more is coming" so an early house never reads as empty.
	var ghost := ColorRect.new()
	ghost.z_index = -6
	ghost.position = Vector2(float(max_room + 1) * HOUSE_ROOM_W + 20, fy - 200)
	ghost.size = Vector2(HOUSE_ROOM_W - 60, 200)
	ghost.color = Color(0.5, 0.4, 0.32, 0.25)
	_house_root.add_child(ghost)
	var qmark := Label.new()
	qmark.text = "?"
	qmark.add_theme_font_size_override("font_size", 40)
	qmark.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 0.6))
	qmark.position = Vector2(float(max_room + 1) * HOUSE_ROOM_W + HOUSE_ROOM_W / 2.0 - 30, fy - 130)
	_house_root.add_child(qmark)

func _decorate_house_shell(floor_w: float, fy: float) -> void:
	## Draws the polished interior shell (walls, ceiling, wainscot, plank floor, window). Pure
	## visuals — collision is the separate floor/walls/ceiling bodies in _build_house_interior.
	var top := fy - 280.0
	# Plaster wall backdrop.
	var wallbg := ColorRect.new()
	wallbg.z_index = -10
	wallbg.position = Vector2(-20, top)
	wallbg.size = Vector2(floor_w + 40, 300)
	wallbg.color = Color(0.93, 0.85, 0.72, 1)
	_house_root.add_child(wallbg)
	# Soft vertical wallpaper stripes.
	var sx := 0.0
	while sx < floor_w + 40:
		var stripe := ColorRect.new()
		stripe.z_index = -10
		stripe.position = Vector2(-20 + sx, top + 26)
		stripe.size = Vector2(18, 180)
		stripe.color = Color(0.88, 0.79, 0.64, 0.5)
		_house_root.add_child(stripe)
		sx += 36.0
	# Beamed ceiling.
	var ceiling := ColorRect.new()
	ceiling.z_index = -9
	ceiling.position = Vector2(-20, top)
	ceiling.size = Vector2(floor_w + 40, 26)
	ceiling.color = Color(0.55, 0.41, 0.31, 1)
	_house_root.add_child(ceiling)
	var bx := 8.0
	while bx < floor_w:
		var beam := ColorRect.new()
		beam.z_index = -8
		beam.position = Vector2(bx, top + 26)
		beam.size = Vector2(9, 15)
		beam.color = Color(0.43, 0.31, 0.23, 1)
		_house_root.add_child(beam)
		bx += 110.0
	# Wainscot panelling along the lower wall + a chair rail.
	var wainscot := ColorRect.new()
	wainscot.z_index = -9
	wainscot.position = Vector2(-20, fy - 92)
	wainscot.size = Vector2(floor_w + 40, 92)
	wainscot.color = Color(0.76, 0.62, 0.47, 1)
	_house_root.add_child(wainscot)
	var rail := ColorRect.new()
	rail.z_index = -8
	rail.position = Vector2(-20, fy - 94)
	rail.size = Vector2(floor_w + 40, 5)
	rail.color = Color(0.5, 0.36, 0.26, 1)
	_house_root.add_child(rail)
	var px := 12.0
	while px < floor_w:
		var seam := ColorRect.new()
		seam.z_index = -8
		seam.position = Vector2(px, fy - 84)
		seam.size = Vector2(3, 70)
		seam.color = Color(0.64, 0.5, 0.36, 0.7)
		_house_root.add_child(seam)
		px += 78.0
	# Daylight window (a little view to the outside).
	var win_x := minf(floor_w * 0.66, floor_w - 130.0)
	var win_frame := ColorRect.new()
	win_frame.z_index = -9
	win_frame.position = Vector2(win_x - 6, fy - 212)
	win_frame.size = Vector2(104, 84)
	win_frame.color = Color(0.46, 0.33, 0.24, 1)
	_house_root.add_child(win_frame)
	var win := ColorRect.new()
	win.z_index = -8
	win.position = Vector2(win_x, fy - 206)
	win.size = Vector2(92, 72)
	win.color = Color(0.62, 0.81, 0.96, 1)
	_house_root.add_child(win)
	var win_mullion_v := ColorRect.new()
	win_mullion_v.z_index = -7
	win_mullion_v.position = Vector2(win_x + 44, fy - 206)
	win_mullion_v.size = Vector2(4, 72)
	win_mullion_v.color = Color(0.46, 0.33, 0.24, 1)
	_house_root.add_child(win_mullion_v)
	var win_mullion_h := ColorRect.new()
	win_mullion_h.z_index = -7
	win_mullion_h.position = Vector2(win_x, fy - 174)
	win_mullion_h.size = Vector2(92, 4)
	win_mullion_h.color = Color(0.46, 0.33, 0.24, 1)
	_house_root.add_child(win_mullion_h)
	# Wood-plank floor surface (sits on top of the collision floor body).
	var floorboard := ColorRect.new()
	floorboard.z_index = -6
	floorboard.position = Vector2(0, fy)
	floorboard.size = Vector2(floor_w, 24)
	floorboard.color = Color(0.62, 0.43, 0.26, 1)
	_house_root.add_child(floorboard)
	var fxp := 0.0
	while fxp < floor_w:
		var plank := ColorRect.new()
		plank.z_index = -5
		plank.position = Vector2(fxp, fy + 2)
		plank.size = Vector2(2, 20)
		plank.color = Color(0.5, 0.34, 0.2, 0.8)
		_house_root.add_child(plank)
		fxp += 44.0
	# Baseboard where wall meets floor.
	var baseboard := ColorRect.new()
	baseboard.z_index = -5
	baseboard.position = Vector2(-20, fy - 8)
	baseboard.size = Vector2(floor_w + 40, 8)
	baseboard.color = Color(0.46, 0.33, 0.24, 1)
	_house_root.add_child(baseboard)

func _house_item_visual(word: String, pos: Vector2, scale_f: float) -> Node2D:
	## Renders a spelled thing for the house: its pixel sprite if one exists, else a colored shape.
	var holder := Node2D.new()
	holder.position = pos
	var path := "res://assets/sprites/summons/" + word + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)  # untyped: load() is nullable
		if tex:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.scale = Vector2(scale_f, scale_f)
			holder.add_child(spr)
			return holder
	var rect := ColorRect.new()
	rect.position = Vector2(-12, -22)
	rect.size = Vector2(24, 22)
	rect.color = _animal_color(word)
	holder.add_child(rect)
	return holder

func _build_house_exit_door(door_x: float) -> void:
	var door := Area2D.new()
	door.name = "HouseExitDoor"
	door.global_position = Vector2(door_x, GROUND_Y)
	door.collision_layer = 4
	door.collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 64)
	col.position = Vector2(0, -32)
	col.shape = shape
	door.add_child(col)
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-24, -70)
	glow.size = Vector2(48, 74)
	glow.color = Color(0.4, 1.0, 0.5, 0.18)
	door.add_child(glow)
	var frame := ColorRect.new()
	frame.position = Vector2(-18, -64)
	frame.size = Vector2(36, 62)
	frame.color = Color(0.25, 0.6, 0.35, 1)
	door.add_child(frame)
	var label := Label.new()
	label.text = "← OUT"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0.1, 0, 0.7))
	label.add_theme_constant_override("outline_size", 2)
	label.position = Vector2(-26, -88)
	door.add_child(label)
	var es := GDScript.new()
	es.source_code = "extends Area2D\nfunc interact() -> void:\n\tvar s = get_tree().current_scene\n\tif s and s.has_method(\"exit_house\"):\n\t\ts.exit_house()\n"
	es.reload()
	door.set_script(es)
	_house_root.add_child(door)

func _build_room_animal_zone(word: String, rx: float, fy: float, is_following: bool) -> void:
	## Slice 2: a big interactable zone over a whole animal room. Press X anywhere inside to take
	## the animal with you, or send it home if it is already following. Sized generously so a
	## 5-year-old doesn't have to aim. State + display refresh happen in toggle_room_animal().
	var zone := Area2D.new()
	zone.name = "RoomAnimal_" + word
	zone.global_position = Vector2(rx + HOUSE_ROOM_W / 2.0, fy - 70)
	zone.collision_layer = 4
	zone.collision_mask = 1
	var zcol := CollisionShape2D.new()
	var zshape := RectangleShape2D.new()
	zshape.size = Vector2(HOUSE_ROOM_W - 16, 200)
	zcol.shape = zshape
	zone.add_child(zcol)
	var hint := Label.new()
	hint.text = "Press X: send home" if is_following else "Press X: take with you"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.35, 0.2) if is_following else Color(0.2, 0.5, 0.2))
	hint.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.75))
	hint.add_theme_constant_override("outline_size", 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-HOUSE_ROOM_W / 2.0 + 8, -150)
	hint.size = Vector2(HOUSE_ROOM_W - 16, 18)
	zone.add_child(hint)
	var zs := GDScript.new()
	zs.source_code = "extends Area2D\nvar word := \"" + word + "\"\nfunc interact() -> void:\n\tvar s = get_tree().current_scene\n\tif s and s.has_method(\"toggle_room_animal\"):\n\t\ts.toggle_room_animal(word)\n"
	zs.reload()
	zone.set_script(zs)
	_house_root.add_child(zone)

func toggle_room_animal(word: String) -> void:
	## Slice 2 take/leave. "Following" IS membership of active_companions (single source of truth),
	## so we never end up with an animal both following AND shown home.
	if not _in_house:
		return
	var ms := get_node_or_null("/root/MagicSummon")
	if word in GameManager.active_companions:
		# Leave here — stop following; send the live companion node back to its home spot.
		GameManager.active_companions.erase(word)
		if ms and word in ms._companions and is_instance_valid(ms._companions[word]):
			ms._send_companion_home(ms._companions[word])
		GameManager.save_game()
		print("Francis-opia: %s stays home." % word.capitalize())
	else:
		# Take with you — activate_companion enforces the 3-follower cap (oldest goes home).
		if ms and ms.has_method("activate_companion"):
			ms.activate_companion(word, player)
			# Bring the companion to Francis right away so it's beside him when he heads out.
			if ms.has_method("teleport_active_companion"):
				ms.teleport_active_companion(player.global_position)
		print("Francis-opia: %s comes with you!" % word.capitalize())
	var sfx := get_node_or_null("/root/SoundFX")
	if sfx and sfx.has_method("play_word_complete"):
		sfx.play_word_complete()
	# Rebuild the interior so beds, sprites and hint labels reflect the new state.
	if _house_root and is_instance_valid(_house_root):
		_house_root.queue_free()
		_house_root = null
	_build_house_interior()

func _restore_teleport_beacon() -> void:
	if GameManager.teleport_beacon_x != 0.0 or GameManager.teleport_beacon_y != 0.0:
		# Remove any existing beacon first (safety cleanup)
		if _teleport_beacon and is_instance_valid(_teleport_beacon):
			_teleport_beacon.queue_free()
		var pos := Vector2(GameManager.teleport_beacon_x, GameManager.teleport_beacon_y)
		_teleport_beacon = _create_beacon_visual(pos)
		add_child(_teleport_beacon)
		_ensure_home_teleport()

# === LEVEL GENERATION (PARAMETERIZED) ===

func _generate_level(chunk: Node2D, block_script: GDScript, chunk_index: int, above_bedrock_y: float, config: Dictionary, has_descent: bool = false, descent_start_x: int = -1, descent_ground_y: float = 0.0, descent_label: String = "DOWN") -> void:
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
				block.is_cave = true  # Mark as cave block for tile selection
				block.setup(gx, gy, is_surface, has_treasure)
				# Only recolor if using ColorRect fallback (not sprite tiles)
				var visual = block.get_node_or_null("Visual")
				if visual and visual is ColorRect:
					if is_surface:
						visual.color = surface_color
					else:
						var shade := randf_range(0.0, 0.06)
						visual.color = Color(
							dirt_color.r + shade, dirt_color.g + shade,
							dirt_color.b + shade, 1)

			_terrain_blocks[key] = block

	# Bedrock floor — with a stairwell gap + shaft if this chunk descends to the next level.
	var bedrock_y := level_ground_y + (underground_rows + 1) * BLOCK_SIZE + BLOCK_SIZE / 2.0 + 10
	if has_descent and descent_start_x >= 0:
		var inner_left_x := (descent_start_x + 1) * BLOCK_SIZE
		var inner_right_x := (descent_start_x + STAIRWELL_WIDTH - 1) * BLOCK_SIZE
		_add_bedrock_segment(chunk, 0.0, inner_left_x, bedrock_y)
		_add_bedrock_segment(chunk, inner_right_x, CHUNK_WIDTH - inner_right_x, bedrock_y)
		_generate_descent_stairwell(chunk, descent_start_x, bedrock_y, descent_ground_y, descent_label)
		_add_descent_marker(chunk, descent_start_x, level_ground_y)
	else:
		_add_bedrock_segment(chunk, 0.0, CHUNK_WIDTH, bedrock_y)

	# === Decorations (driven by config) ===

	# Keep the elevator-shaft COLUMN clear — platforms/trees/crystals/mushrooms must NEVER land in
	# the shaft (the L1->L2 shaft descends through this level's sky, and the L2->L3 shaft is below,
	# both at descent_start_x). A hanging platform in the shaft is what was blocking Francis.
	var shaft_cx := -100000.0
	var shaft_half := 0.0
	if has_descent and descent_start_x >= 0:
		shaft_cx = (descent_start_x + STAIRWELL_WIDTH / 2.0) * BLOCK_SIZE
		shaft_half = (STAIRWELL_WIDTH / 2.0 + 3.0) * BLOCK_SIZE

	if config.get("has_mushrooms", false):
		for _m in _rng.randi_range(3, 6):
			var mx := _rng.randf_range(30, CHUNK_WIDTH - 30)
			if absf(mx - shaft_cx) < shaft_half:
				continue
			_add_l2_mushroom(chunk, Vector2(mx, level_ground_y))

	if config.get("has_glow_trees", false):
		var tree_min: int = config.get("tree_count_min", 1)
		var tree_max: int = config.get("tree_count_max", 3)
		var l2_trees_unlocked := "tree" in GameManager.words_summoned
		for _t in _rng.randi_range(tree_min, tree_max):
			var l2_tree_x := _rng.randf_range(60, CHUNK_WIDTH - 60)
			if absf(l2_tree_x - shaft_cx) < shaft_half:
				continue
			if l2_trees_unlocked:
				_add_l2_tree(chunk, Vector2(l2_tree_x, level_ground_y))

	var plat_min: int = config.get("platform_count_min", 1)
	var plat_max: int = config.get("platform_count_max", 3)
	for _p in _rng.randi_range(plat_min, plat_max):
		var plat_x := _rng.randf_range(100, CHUNK_WIDTH - 100)
		if absf(plat_x - shaft_cx) < shaft_half:
			continue  # never hang a platform in the elevator shaft
		_add_l2_platform(chunk, Vector2(
			plat_x,
			level_ground_y - _rng.randf_range(80, sky_height * 0.6)),
			_rng.randf_range(100, 200))

	if config.get("has_crystals", false):
		for _c in _rng.randi_range(2, 4):
			var crx := _rng.randf_range(40, CHUNK_WIDTH - 40)
			if absf(crx - shaft_cx) < shaft_half:
				continue
			_add_l2_crystal(chunk, Vector2(crx, level_ground_y))

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
	var cap_idx := _rng.randi()  # Consume RNG regardless of path

	var mush_sprite := SpriteLoader.try_load_random_sprite(
		"res://assets/sprites/world/mushroom_", 3, cap_idx, Vector2(0, -18))
	if mush_sprite:
		mush_sprite.position = pos
		# Still consume dot RNG to keep sequence stable
		_rng.randf_range(-7, 5)
		_rng.randf_range(-7, 5)
		chunk.add_child(mush_sprite)
		return

	var mushroom := Node2D.new()
	mushroom.position = pos
	chunk.add_child(mushroom)
	var stem := ColorRect.new()
	stem.position = Vector2(-3, -18)
	stem.size = Vector2(6, 18)
	stem.color = Color(0.75, 0.7, 0.6, 1)
	mushroom.add_child(stem)
	var cap_colors := [
		Color(0.8, 0.2, 0.3, 1),
		Color(0.3, 0.6, 0.9, 1),
		Color(0.9, 0.5, 0.1, 1),
		Color(0.6, 0.3, 0.8, 1),
	]
	var cap := ColorRect.new()
	cap.position = Vector2(-10, -26)
	cap.size = Vector2(20, 10)
	cap.color = cap_colors[cap_idx % cap_colors.size()]
	mushroom.add_child(cap)

	# Glow spots on cap
	for _d in 2:
		var dot := ColorRect.new()
		dot.position = Vector2(_rng.randf_range(-7, 5), -24)
		dot.size = Vector2(3, 3)
		dot.color = Color(1, 1, 0.8, 0.6)
		mushroom.add_child(dot)

func _add_l2_tree(chunk: Node2D, pos: Vector2) -> void:
	var trunk_h := _rng.randf_range(50, 80)
	var canopy_size := _rng.randf_range(20, 35)

	# L2 glow trees reuse the tree sprites with a tint
	var glow_tree_sprite := SpriteLoader.try_load_random_sprite(
		"res://assets/sprites/world/tree_", 3, int(trunk_h), Vector2(0, -55))
	if glow_tree_sprite:
		glow_tree_sprite.position = pos
		glow_tree_sprite.scale = Vector2(3.0, 3.0)  # 3x bigger L2 trees
		glow_tree_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow_tree_sprite.modulate = Color(0.5, 1.0, 0.85, 0.9)  # Cyan-green bioluminescent tint
		chunk.add_child(glow_tree_sprite)
		return

	var tree := Node2D.new()
	tree.position = pos
	tree.scale = Vector2(3.0, 3.0)  # 3x bigger fallback too
	chunk.add_child(tree)
	var trunk := ColorRect.new()
	trunk.position = Vector2(-6, -trunk_h)
	trunk.size = Vector2(12, trunk_h)
	trunk.color = Color(0.25, 0.2, 0.3, 1)
	tree.add_child(trunk)
	var leaves := ColorRect.new()
	leaves.position = Vector2(-canopy_size, -trunk_h - canopy_size)
	leaves.size = Vector2(canopy_size * 2, canopy_size)
	leaves.color = Color(0.1, 0.65, 0.55, 0.85)
	tree.add_child(leaves)
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
	col.one_way_collision = true
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
	var crystal_colors := [
		Color(0.3, 0.7, 1.0, 0.85),
		Color(0.7, 0.3, 0.9, 0.85),
		Color(0.2, 0.9, 0.5, 0.85),
		Color(1.0, 0.6, 0.2, 0.85),
	]
	var color_idx := _rng.randi()
	var color: Color = crystal_colors[color_idx % crystal_colors.size()]
	var h := _rng.randf_range(16, 32)

	var crystal_sprite := SpriteLoader.try_load_random_sprite(
		"res://assets/sprites/world/crystal_", 3, color_idx, Vector2(0, -32))
	if crystal_sprite:
		crystal_sprite.position = pos
		chunk.add_child(crystal_sprite)
		return

	var crystal := Node2D.new()
	crystal.position = pos
	chunk.add_child(crystal)

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
	# Note: platforms need collision even with sprites, so no early return
	var platform := StaticBody2D.new()
	platform.position = pos
	chunk.add_child(platform)

	var col := CollisionShape2D.new()
	col.one_way_collision = true  # Can jump through from below, land on top
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 20)
	col.shape = shape
	platform.add_child(col)

	# Try magic platform sprite
	var plat_sprite := SpriteLoader.try_load_sprite(
		"res://assets/sprites/world/platform_magic.png", Vector2(0, 0))
	if plat_sprite:
		plat_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Scale to match requested width
		var tex_width := plat_sprite.texture.get_width()
		var scale_x := width / float(tex_width) if tex_width > 0 else 1.0
		plat_sprite.scale = Vector2(scale_x, scale_x)
		platform.add_child(plat_sprite)
	else:
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
	# Consume RNG to keep sequence deterministic regardless of sprite/fallback path
	var trunk_h := _rng.randf_range(60, 100)
	var trunk_r := _rng.randf_range(0.4, 0.5)
	var trunk_g := _rng.randf_range(0.25, 0.35)
	var trunk_b := _rng.randf_range(0.1, 0.2)
	var canopy_size := _rng.randf_range(25, 40)
	var leaf_r := _rng.randf_range(0.18, 0.3)
	var leaf_g := _rng.randf_range(0.55, 0.75)
	var leaf_b := _rng.randf_range(0.2, 0.35)

	# Try sprite first (pick variant based on trunk_h RNG)
	# Offset: sprite is 80x110, bottom-anchored. Place so bottom touches ground.
	# Sprite is 80x110. Offset = -half height so bottom touches ground. Scale applied after.
	var tree_sprite := SpriteLoader.try_load_random_sprite(
		"res://assets/sprites/world/tree_", 3, int(trunk_h), Vector2(0, -55))
	if tree_sprite:
		tree_sprite.position = pos
		tree_sprite.scale = Vector2(2.5, 2.5)
		tree_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chunk.add_child(tree_sprite)
		return

	# Fallback: procedural ColorRect tree (2.5x scale)
	var tree := Node2D.new()
	tree.position = pos
	tree.scale = Vector2(2.5, 2.5)
	chunk.add_child(tree)
	var trunk := ColorRect.new()
	trunk.position = Vector2(-8, -trunk_h)
	trunk.size = Vector2(16, trunk_h)
	trunk.color = Color(trunk_r, trunk_g, trunk_b, 1)
	tree.add_child(trunk)
	var leaves := ColorRect.new()
	leaves.position = Vector2(-canopy_size, -trunk_h - canopy_size * 1.5)
	leaves.size = Vector2(canopy_size * 2, canopy_size * 1.5)
	leaves.color = Color(leaf_r, leaf_g, leaf_b, 1)
	tree.add_child(leaves)

func _add_flower(chunk: Node2D, pos: Vector2) -> void:
	var color_idx := _rng.randi()  # Consume RNG regardless of path

	# Offset: sprite is 20x28, bottom-anchored. Place so stem base touches ground.
	var flower_sprite := SpriteLoader.try_load_random_sprite(
		"res://assets/sprites/world/flower_", 5, color_idx, Vector2(0, -14))
	if flower_sprite:
		flower_sprite.position = pos
		chunk.add_child(flower_sprite)
		return

	var flower := ColorRect.new()
	flower.position = pos + Vector2(0, -12)
	flower.size = Vector2(10, 12)
	var colors := [
		Color(1, 0.4, 0.5, 1), Color(1, 0.85, 0.2, 1),
		Color(0.7, 0.4, 1, 1), Color(1, 0.6, 0.8, 1),
		Color(0.5, 0.8, 1, 1)
	]
	flower.color = colors[color_idx % colors.size()]
	chunk.add_child(flower)

func _spawn_surface_chest(chunk: Node2D, pos: Vector2) -> void:
	var chest_script := load("res://scenes/world/TreasureChest.gd") as GDScript
	var chest := StaticBody2D.new()
	chest.position = pos
	chest.collision_layer = 4
	chest.z_index = 3

	# Try pixel art chest sprite
	var chest_tex_path := "res://assets/sprites/world/chest_closed.png"
	if ResourceLoader.exists(chest_tex_path):
		var tex := load(chest_tex_path) as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.name = "ChestSprite"
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.offset = Vector2(0, -tex.get_height() / 2.0)
			chest.add_child(spr)
	else:
		var chest_body := ColorRect.new()
		chest_body.name = "ChestBody"
		chest_body.position = Vector2(-14, -11)
		chest_body.size = Vector2(28, 18)
		chest_body.color = Color(0.6, 0.4, 0.15, 1)
		chest.add_child(chest_body)
		var lid := ColorRect.new()
		lid.name = "Lid"
		lid.position = Vector2(-16, -17)
		lid.size = Vector2(32, 8)
		lid.color = Color(0.7, 0.5, 0.2, 1)
		chest.add_child(lid)

	# Idle sparkle
	var sparkle := Node2D.new()
	sparkle.name = "IdleSparkle"
	chest.add_child(sparkle)
	var ss := GDScript.new()
	ss.source_code = "extends Node2D\nvar _t := 0.0\nfunc _process(d):\n\t_t += d\n\tif fmod(_t, 1.5) < d:\n\t\tvar s = ColorRect.new()\n\t\ts.size = Vector2(3,3)\n\t\ts.position = Vector2(randf_range(-12,12), -20)\n\t\ts.color = Color(1, 0.85, 0.2, 0.6)\n\t\ts.z_index = 4\n\t\tadd_child(s)\n\t\tvar tw = s.create_tween()\n\t\ttw.tween_property(s, \"position:y\", s.position.y - 25, 1.0)\n\t\ttw.parallel().tween_property(s, \"modulate:a\", 0.0, 1.0)\n\t\ttw.tween_callback(s.queue_free)\n"
	ss.reload()
	sparkle.set_script(ss)

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

func _spawn_thief() -> void:
	var valid_thieves: Array[Node2D] = []
	for t in _active_thieves:
		if is_instance_valid(t):
			valid_thieves.append(t)
	_active_thieves = valid_thieves
	if _active_thieves.size() >= MAX_THIEVES:
		return
	if not _thief_scene or not player:
		return
	var thief := _thief_scene.instantiate() as Node2D
	var spawn_side := 1.0 if _rng.randf() > 0.5 else -1.0
	thief.global_position = Vector2(
		player.global_position.x + spawn_side * 600,
		GROUND_Y - 30
	)
	add_child(thief)
	_active_thieves.append(thief)
	print("Francis-opia: Oh no! A letter thief is coming!")

func _on_wrong_letter(_letter: String) -> void:
	_spawn_thief()

func _on_new_word_thief_chance(_word: String, _hint: String) -> void:
	# 40% chance a thief appears when a new word starts
	if _rng.randf() < 0.4:
		# Small delay so it doesn't feel instant
		get_tree().create_timer(2.0).timeout.connect(_spawn_thief)

func _on_word_stun_thieves(_word: String) -> void:
	var valid_thieves: Array[Node2D] = []
	for t in _active_thieves:
		if is_instance_valid(t):
			valid_thieves.append(t)
	_active_thieves = valid_thieves
	for thief in _active_thieves:
		if thief.has_method("stunned_by_magic"):
			thief.stunned_by_magic()
	_active_thieves.clear()

func _spawn_dog_companion() -> void:
	## Always spawn the dog as a companion if the player has earned it.
	if not player:
		return
	var magic_summon := get_node_or_null("/root/MagicSummon")
	if magic_summon and magic_summon.has_method("_summon_dog"):
		var dog: Variant = magic_summon.call("_summon_dog", self, player, player.global_position)
		if dog is Node:
			magic_summon._summoned_entities.append(dog)
			magic_summon.register_companion("dog", dog, player, false)
			if GameManager.big_scale > 1.0:
				var s: float = min(GameManager.big_scale, 2.0)
				var sx: float = sign(dog.scale.x) if dog.scale.x != 0 else 1.0
				dog.scale = Vector2(sx * s, s)
			print("Francis-opia: Your dog is here! Woof!")

func _restore_summons() -> void:
	## Re-create persistent summons from previous session (sun, pets, etc.)
	var magic_summon := get_node_or_null("/root/MagicSummon")
	if not magic_summon:
		return
	# Clean up any temporary effects that leaked into old saves
	var cleaned := false
	for word in GameManager.words_summoned.duplicate():
		var check_entry: Dictionary = magic_summon.summon_registry.get(word, {})
		if check_entry.get("temporary", false):
			GameManager.words_summoned.erase(word)
			GameManager.items_owned.erase(word)
			cleaned = true
	if cleaned:
		GameManager.save_game()
		print("Francis-opia: Cleaned temporary effects from save.")

	for word in GameManager.words_summoned:
		# Dog is spawned separately via _spawn_dog_companion
		if word == "dog":
			continue
		var entry: Dictionary = magic_summon.summon_registry.get(word, {})
		if entry.is_empty():
			continue
		# Skip temporary effects (should already be filtered, but defense in depth)
		if entry.get("temporary", false):
			continue
		var builder_name: String = entry.get("builder", "")
		if builder_name != "" and magic_summon.has_method(builder_name):
			var summoned: Variant = magic_summon.call(builder_name, self, player, player.global_position)
			if summoned is Node:
				magic_summon._summoned_entities.append(summoned)
				if magic_summon.is_companion_word(word):
					magic_summon.register_companion(word, summoned, player, false)
			print("Francis-opia: Restored %s from last session!" % word)
	# Apply persisted BIG scale to first pet found
	if GameManager.big_scale > 1.0:
		_apply_big_scale.call_deferred(magic_summon)

func _apply_big_scale(magic_summon: Node) -> void:
	var s: float = min(GameManager.big_scale, 2.0)
	# Clamp persisted value too
	if GameManager.big_scale > 2.0:
		GameManager.big_scale = 2.0
	for word in magic_summon._companions:
		var entity: Node = magic_summon._companions[word]
		if is_instance_valid(entity):
			var sx: float = sign(entity.scale.x) if entity.scale.x != 0 else 1.0
			entity.scale = Vector2(sx * s, s)
			print("Francis-opia: %s is still BIG!" % entity.name)

# Words that change the world when spelled — triggers chunk regeneration
const WORLD_CHANGING_WORDS := ["tree", "portal", "house", "hut", "zap"]

func _on_world_word_completed(word: String) -> void:
	var w := word.to_lower()
	if w in WORLD_CHANGING_WORDS:
		_regenerate_all_chunks()
	# Spelling a car word unlocks that car in Car Town. Mark it owned HERE (robust — some car
	# builders return null, which would skip the normal items_owned path), then if Francis is
	# already on Level 3, park it right next to him immediately.
	if w in L3_CAR_WORDS:
		if w not in GameManager.items_owned:
			GameManager.items_owned.append(w)
			GameManager.save_game()
		if not _driving and _is_on_level3():
			_add_street_vehicle_at(player.global_position.x + 110.0, w)

func _is_on_level3() -> bool:
	## True when Francis is down on the Car Town street (below Level 2's bedrock).
	return player != null and player.global_position.y > _l3_top_y(BEDROCK_Y) - 60.0

func _ensure_l3_car_near_player() -> void:
	## When Francis arrives on Level 3 already owning a car, park one (the ice-cream VAN first)
	## right next to him so it's ready to drive — wherever he came in (portal OR elevator shaft).
	if _driving or player == null:
		return
	for cw in L3_CAR_WORDS:
		if cw in GameManager.items_owned:
			_add_street_vehicle_at(player.global_position.x + 90.0, cw)
			return

func _add_stairwell_house(chunk: Node2D, pos: Vector2) -> void:
	## Places a travel cottage near a stairwell — 3x sized landmark.
	var cottage_sprite := SpriteLoader.try_load_sprite(
		"res://assets/sprites/world/cottage_0.png", Vector2(0, -65))
	if cottage_sprite:
		cottage_sprite.position = pos + Vector2(150, 0)
		cottage_sprite.scale = Vector2(3, 3)
		cottage_sprite.z_index = -2
		cottage_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chunk.add_child(cottage_sprite)

		# Ground platform under the cottage so it doesn't float
		var ground_pad := StaticBody2D.new()
		ground_pad.position = pos + Vector2(150, 10)
		ground_pad.collision_layer = 1
		ground_pad.collision_mask = 0
		chunk.add_child(ground_pad)
		var gp_col := CollisionShape2D.new()
		var gp_shape := RectangleShape2D.new()
		gp_shape.size = Vector2(480 + 60, 80)
		gp_col.shape = gp_shape
		gp_col.position = Vector2(0, 30)
		ground_pad.add_child(gp_col)
		# Collision only — terrain tiles provide the visual

		# Walk-on platform at door level
		var door_platform := StaticBody2D.new()
		door_platform.position = pos + Vector2(150, -10)
		door_platform.collision_layer = 1
		door_platform.collision_mask = 0
		chunk.add_child(door_platform)
		var dp_col := CollisionShape2D.new()
		dp_col.one_way_collision = true
		var dp_shape := RectangleShape2D.new()
		dp_shape.size = Vector2(360, 8)
		dp_col.shape = dp_shape
		door_platform.add_child(dp_col)

		# Roof platform (3x bigger)
		var roof := StaticBody2D.new()
		roof.position = pos + Vector2(150, -360)
		roof.collision_layer = 1
		roof.collision_mask = 0
		chunk.add_child(roof)
		var roof_col := CollisionShape2D.new()
		roof_col.one_way_collision = true
		var roof_shape := RectangleShape2D.new()
		roof_shape.size = Vector2(360, 12)
		roof_col.shape = roof_shape
		roof.add_child(roof_col)
		return

	# Fallback: old ColorRect house
	var house := Node2D.new()
	house.name = "TravelHouse"
	house.position = pos

	var W := 200.0
	var H := 130.0
	var WALL := 10.0
	var DOOR_W := 40.0
	var DOOR_H := 60.0
	var ROOF := 14.0

	# Foundation
	var ground_pad := StaticBody2D.new()
	ground_pad.position = Vector2(W / 2, 40)
	ground_pad.collision_layer = 1
	ground_pad.collision_mask = 0
	chunk.add_child(ground_pad)
	var gpad_col := CollisionShape2D.new()
	var gpad_shape := RectangleShape2D.new()
	gpad_shape.size = Vector2(W + 40, 80)
	gpad_col.shape = gpad_shape
	ground_pad.add_child(gpad_col)
	var gpad_vis := ColorRect.new()
	gpad_vis.position = Vector2(-(W + 40) / 2, -40)
	gpad_vis.size = Vector2(W + 40, 6)
	gpad_vis.color = Color(0.4, 0.55, 0.3, 1)
	ground_pad.add_child(gpad_vis)
	var fill := ColorRect.new()
	fill.position = Vector2(-(W + 40) / 2, -34)
	fill.size = Vector2(W + 40, 74)
	fill.color = Color(0.45, 0.32, 0.18, 1)
	ground_pad.add_child(fill)

	# Interior background
	var interior := ColorRect.new()
	interior.z_index = -2
	interior.position = Vector2(WALL, -H + WALL)
	interior.size = Vector2(W - WALL * 2, H - WALL)
	interior.color = Color(0.95, 0.87, 0.7, 1)
	house.add_child(interior)

	# Warm glow
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(WALL + 5, -H + 10)
	glow.size = Vector2(W - WALL * 2 - 10, H - 15)
	glow.color = Color(1.0, 0.92, 0.7, 0.12)
	house.add_child(glow)

	# Floor
	var wood_floor := ColorRect.new()
	wood_floor.z_index = -1
	wood_floor.position = Vector2(WALL, -4)
	wood_floor.size = Vector2(W - WALL * 2, 4)
	wood_floor.color = Color(0.6, 0.38, 0.2, 1)
	house.add_child(wood_floor)

	# Left wall (solid, above door)
	var lw := StaticBody2D.new()
	lw.position = Vector2(WALL / 2, -(DOOR_H + (H - DOOR_H) / 2))
	lw.collision_layer = 1
	lw.collision_mask = 0
	house.add_child(lw)
	var lw_col := CollisionShape2D.new()
	var lw_shape := RectangleShape2D.new()
	lw_shape.size = Vector2(WALL, H - DOOR_H)
	lw_col.shape = lw_shape
	lw.add_child(lw_col)
	var lw_vis := ColorRect.new()
	lw_vis.position = Vector2(-WALL / 2, -(H - DOOR_H) / 2)
	lw_vis.size = Vector2(WALL, H - DOOR_H)
	lw_vis.color = Color(0.78, 0.58, 0.32, 1)
	lw.add_child(lw_vis)

	# Right wall (solid, full height — door is on the left)
	var rw := StaticBody2D.new()
	rw.position = Vector2(W - WALL / 2, -H / 2)
	rw.collision_layer = 1
	rw.collision_mask = 0
	house.add_child(rw)
	var rw_col := CollisionShape2D.new()
	var rw_shape := RectangleShape2D.new()
	rw_shape.size = Vector2(WALL, H)
	rw_col.shape = rw_shape
	rw.add_child(rw_col)
	var rw_vis := ColorRect.new()
	rw_vis.position = Vector2(-WALL / 2, -H / 2)
	rw_vis.size = Vector2(WALL, H)
	rw_vis.color = Color(0.78, 0.58, 0.32, 1)
	rw.add_child(rw_vis)

	# Door frame
	var df_l := ColorRect.new()
	df_l.position = Vector2(-4, -DOOR_H)
	df_l.size = Vector2(4, DOOR_H)
	df_l.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(df_l)
	var df_r := ColorRect.new()
	df_r.position = Vector2(WALL, -DOOR_H)
	df_r.size = Vector2(4, DOOR_H)
	df_r.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(df_r)
	var df_top := ColorRect.new()
	df_top.position = Vector2(-4, -DOOR_H - 3)
	df_top.size = Vector2(WALL + 8, 3)
	df_top.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(df_top)

	# Welcome mat
	var mat := ColorRect.new()
	mat.position = Vector2(-30, -2)
	mat.size = Vector2(30, 3)
	mat.color = Color(0.7, 0.35, 0.3, 1)
	house.add_child(mat)

	# Roof
	var roof_node := StaticBody2D.new()
	roof_node.position = Vector2(W / 2, -H - ROOF / 2)
	roof_node.collision_layer = 1
	roof_node.collision_mask = 0
	house.add_child(roof_node)
	var roof_col := CollisionShape2D.new()
	var roof_shape := RectangleShape2D.new()
	roof_shape.size = Vector2(W + 16, ROOF)
	roof_col.shape = roof_shape
	roof_node.add_child(roof_col)
	var roof_vis := ColorRect.new()
	roof_vis.position = Vector2(-(W + 16) / 2, -ROOF / 2)
	roof_vis.size = Vector2(W + 16, ROOF)
	roof_vis.color = Color(0.7, 0.25, 0.15, 1)
	roof_node.add_child(roof_vis)
	var peak := ColorRect.new()
	peak.position = Vector2(-(W - 16) / 2, -ROOF / 2 - 10)
	peak.size = Vector2(W - 16, 10)
	peak.color = Color(0.75, 0.28, 0.18, 1)
	roof_node.add_child(peak)

	# Chimney
	var chimney := ColorRect.new()
	chimney.position = Vector2(20, -H - ROOF - 14)
	chimney.size = Vector2(10, 18)
	chimney.color = Color(0.55, 0.4, 0.35, 1)
	house.add_child(chimney)

	# Window
	var win := ColorRect.new()
	win.position = Vector2(W / 2 - 15, -H + 30)
	win.size = Vector2(30, 30)
	win.color = Color(0.7, 0.85, 1.0, 0.5)
	house.add_child(win)
	# Window cross
	var win_h := ColorRect.new()
	win_h.position = Vector2(W / 2 - 15, -H + 44)
	win_h.size = Vector2(30, 2)
	win_h.color = Color(0.5, 0.3, 0.15, 0.8)
	house.add_child(win_h)
	var win_v := ColorRect.new()
	win_v.position = Vector2(W / 2 - 1, -H + 30)
	win_v.size = Vector2(2, 30)
	win_v.color = Color(0.5, 0.3, 0.15, 0.8)
	house.add_child(win_v)

	# "HOME" label
	var label := Label.new()
	label.text = "HOME"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0, 0.7))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(W / 2 - 30, -H - ROOF - 35)
	label.size = Vector2(60, 20)
	label.z_index = 5
	house.add_child(label)

	chunk.add_child(house)

func _regenerate_all_chunks() -> void:
	## Force-reload all visible chunks to reflect world state changes (e.g. trees appearing).
	var chunk_indices: Array = _chunks.keys().duplicate()
	for idx in chunk_indices:
		_remove_chunk(idx)
	_last_chunk_index = -999
	_update_chunks()

func _show_no_gamepad_warning() -> void:
	## On-screen warning when no gamepad is detected (Steam Deck help).
	var warning := Label.new()
	warning.text = "No gamepad detected!\nSteam Deck: Press Steam button > Controller Settings\n> Change layout to 'Gamepad'"
	warning.add_theme_font_size_override("font_size", 28)
	warning.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	warning.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	warning.add_theme_constant_override("outline_size", 4)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.position = Vector2(200, 300)
	warning.size = Vector2(880, 200)
	warning.z_index = 100
	add_child(warning)
	# Auto-dismiss after 10 seconds or when a gamepad connects
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(warning):
			warning.queue_free()
	)
	Input.joy_connection_changed.connect(func(_device: int, connected: bool) -> void:
		if connected and is_instance_valid(warning):
			warning.queue_free()
	)
