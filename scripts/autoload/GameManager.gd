extends Node
## Global game state manager. Handles save/load, scene transitions, and player data.
## Auto-saves on every meaningful event + every 2 minutes + on quit.

signal area_changed(area_name: String)
signal coins_changed(new_total: int)
signal word_completed(word: String)
signal progress_reset()  # Emitted when player resets all progress

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const AUTO_SAVE_INTERVAL := 120.0  # 2 minutes
const SAVE_VERSION := 2            # Bump when save format changes
const GENERATOR_VERSION := 1       # Bump when terrain generation algorithm changes

var player_name := "Explorer"
var planet_name := "Francis-opia"
var castle_style := "stone"
var character_index := 0
var word_coins := 0
var words_completed: Array[String] = []
var quests_completed: Array[String] = []
var current_area := "Meadow"
var items_owned: Array[String] = []
var words_summoned: Array[String] = []
var starter_index := 0       # How far through the starter word sequence
var starter_complete := false # Whether starter sequence is done
var equipped_weapon := ""    # Currently equipped weapon name (empty = none)
var current_level := 1       # Underground depth level (1 = surface, 2+ = deeper caves)
var world_seed: int = 0      # Terrain generation seed (0 = generate new on first play)
var generator_ver: int = 1   # Generator version this world was created with
var player_pos_x: float = 400.0  # Last player position
var player_pos_y: float = 700.0
# World deltas: only player-caused changes are stored. Everything else regenerates from seed.
# Key: "chunk,gx,gy" or "Level 2_chunk,gx,gy". Value: block type string ("air" = dug out).
# Future: "wood_plank", "stone_brick" etc. for player-placed blocks.
var block_changes: Dictionary = {}
var opened_chests: Dictionary = {}  # "chunk,index" -> true for looted chests

var _auto_save_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load save early so other autoloads (WordEngine) can read restored state
	if load_game():
		print("Francis-opia: Save loaded! Welcome back to %s!" % planet_name)
	else:
		print("Francis-opia: New adventure begins!")

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()

func _notification(what: int) -> void:
	# Save on quit / window close / app suspend
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()

func add_coins(amount: int) -> void:
	word_coins += amount
	coins_changed.emit(word_coins)
	save_game()

func complete_word(word: String) -> void:
	if word not in words_completed:
		words_completed.append(word)
		word_completed.emit(word)
		add_coins(_coin_reward_for_word(word))
		save_game()

func _coin_reward_for_word(word: String) -> int:
	var length := word.length()
	if length <= 3:
		return 1
	elif length <= 4:
		return 2
	else:
		return 3

func complete_quest(quest_id: String) -> void:
	if quest_id not in quests_completed:
		quests_completed.append(quest_id)
		save_game()

func change_area(area_name: String) -> void:
	current_area = area_name
	area_changed.emit(area_name)
	save_game()

func save_game() -> void:
	var save_data := {
		"save_version": SAVE_VERSION,
		"generator_version": generator_ver,
		"player_name": player_name,
		"planet_name": planet_name,
		"castle_style": castle_style,
		"character_index": character_index,
		"word_coins": word_coins,
		"words_completed": words_completed,
		"quests_completed": quests_completed,
		"current_area": current_area,
		"items_owned": items_owned,
		"words_summoned": words_summoned,
		"starter_index": starter_index,
		"starter_complete": starter_complete,
		"equipped_weapon": equipped_weapon,
		"current_level": current_level,
		"world_seed": world_seed,
		"player_pos_x": player_pos_x,
		"player_pos_y": player_pos_y,
		"block_changes": block_changes,
		"opened_chests": opened_chests.keys(),
	}
	# Atomic write: write to temp, then rename over real file
	# Keep one backup of previous save
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		# Rotate backup: current save -> backup
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		# Temp -> real save (atomic-ish)
		DirAccess.rename_absolute(tmp_path, SAVE_PATH)

func load_game() -> bool:
	var data := _try_load_file(SAVE_PATH)
	if data.is_empty():
		# Try backup if main save is corrupt
		data = _try_load_file(BACKUP_PATH)
		if data.is_empty():
			return false
		print("Francis-opia: Restored from backup save!")
	player_name = data.get("player_name", player_name)
	planet_name = data.get("planet_name", planet_name)
	castle_style = data.get("castle_style", castle_style)
	character_index = data.get("character_index", character_index)
	word_coins = data.get("word_coins", word_coins)
	words_completed.assign(data.get("words_completed", []))
	quests_completed.assign(data.get("quests_completed", []))
	current_area = data.get("current_area", current_area)
	items_owned.assign(data.get("items_owned", []))
	words_summoned.assign(data.get("words_summoned", []))
	starter_index = data.get("starter_index", 0)
	starter_complete = data.get("starter_complete", false)
	equipped_weapon = data.get("equipped_weapon", "")
	current_level = data.get("current_level", 1)
	# Clamp seed to JSON-safe range (JSON floats lose precision above 2^53)
	var loaded_seed: int = data.get("world_seed", 0)
	if loaded_seed > 1000000000 or loaded_seed < -1000000000:
		# Seed was corrupted by JSON float precision loss, re-derive a stable one
		loaded_seed = absi(loaded_seed) % 1000000000
		if loaded_seed == 0:
			loaded_seed = 42
		print("Francis-opia: Fixed oversized world seed to %d" % loaded_seed)
	world_seed = loaded_seed
	generator_ver = data.get("generator_version", 1)
	player_pos_x = data.get("player_pos_x", 400.0)
	player_pos_y = data.get("player_pos_y", 700.0)

	# Restore world deltas with migration from old format
	block_changes.clear()
	var save_ver: int = data.get("save_version", 1)
	if save_ver < 2 and data.has("dug_blocks"):
		# Migrate v1: dug_blocks was Array of keys, convert to block_changes dict
		var old_dug: Array = data.get("dug_blocks", [])
		for key in old_dug:
			block_changes[key] = "air"
		print("Francis-opia: Migrated %d dug blocks from save v1 to v2" % old_dug.size())
	else:
		var saved_changes: Dictionary = data.get("block_changes", {})
		for key in saved_changes:
			block_changes[key] = saved_changes[key]

	opened_chests.clear()
	var saved_chests: Array = data.get("opened_chests", [])
	for key in saved_chests:
		opened_chests[key] = true

	coins_changed.emit(word_coins)
	return true

func _try_load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

func reset_progress() -> void:
	## Wipe all progress and start fresh
	player_name = "Explorer"
	planet_name = "Francis-opia"
	castle_style = "stone"
	character_index = 0
	word_coins = 0
	words_completed.clear()
	quests_completed.clear()
	current_area = "Meadow"
	items_owned.clear()
	words_summoned.clear()
	starter_index = 0
	starter_complete = false
	equipped_weapon = ""
	current_level = 1
	world_seed = 0
	generator_ver = 1
	player_pos_x = 400.0
	player_pos_y = 700.0
	block_changes.clear()
	opened_chests.clear()
	# Delete save files
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	coins_changed.emit(0)
	progress_reset.emit()
	print("Francis-opia: Progress reset! Starting fresh.")

func get_total_words_completed() -> int:
	return words_completed.size()
