extends Node
## Global game state manager. Handles save/load, scene transitions, and player data.

signal area_changed(area_name: String)
signal coins_changed(new_total: int)
signal word_completed(word: String)

const SAVE_PATH := "user://save.json"

var player_name := "Explorer"
var planet_name := "Francis-opia"
var castle_style := "stone"
var character_index := 0
var word_coins := 0
var words_completed: Array[String] = []
var quests_completed: Array[String] = []
var current_area := "Meadow"
var items_owned: Array[String] = []
var words_summoned: Array[String] = []  # Words that have been magically summoned

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_coins(amount: int) -> void:
	word_coins += amount
	coins_changed.emit(word_coins)

func complete_word(word: String) -> void:
	if word not in words_completed:
		words_completed.append(word)
		word_completed.emit(word)
		add_coins(_coin_reward_for_word(word))

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

func change_area(area_name: String) -> void:
	current_area = area_name
	area_changed.emit(area_name)
	save_game()

func save_game() -> void:
	var save_data := {
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
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return false
	var data: Dictionary = json.data
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
	return true

func get_total_words_completed() -> int:
	return words_completed.size()
