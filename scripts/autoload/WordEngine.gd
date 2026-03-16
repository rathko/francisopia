extends Node
## Core reading engine. Manages word selection, validation, difficulty progression,
## and spaced repetition for educational effectiveness.

signal target_word_changed(word: String, hint_image: String)
signal letter_collected(letter: String, position: int)
signal word_spelled_correctly(word: String)
signal wrong_letter_rejected(letter: String)
signal letter_lost()  # Emitted when a collected letter is lost (wrong pick penalty)

const WORDS_PATH := "res://data/words.json"
const WORD_BANK_TRES := "res://data/words/word_bank.tres"

var word_bank: Array[Dictionary] = []
var _resource_bank: Resource = null  # WordBank resource (if loaded)
var current_target_word := ""
var current_hint_image := ""
var collected_letters: Array[String] = []
var current_difficulty := 1
var _word_attempts: Dictionary = {}  # word -> {correct: int, hints_used: int, time_ms: int}

# Fixed starter sequence — these words always come first in order
var _starter_sequence: Array[String] = ["dog", "sun", "tree", "rainbow"]
var _starter_index := 0
var _starter_complete := false

func _ready() -> void:
	_load_word_bank()
	# Restore starter sequence progress from saved state
	_starter_index = GameManager.starter_index
	_starter_complete = GameManager.starter_complete
	GameManager.progress_reset.connect(_on_progress_reset)

func _load_word_bank() -> void:
	# Try Resource-based word bank first (.tres), fall back to JSON, then built-in
	if ResourceLoader.exists(WORD_BANK_TRES):
		_resource_bank = ResourceLoader.load(WORD_BANK_TRES)
		if _resource_bank and _resource_bank.get("words") is Array:
			word_bank.clear()
			for entry in _resource_bank.get("words"):
				word_bank.append({
					"word": entry.get("word"),
					"level": entry.get("level"),
					"area": entry.get("area"),
					"image": entry.get("image"),
					"phonics": Array(entry.get("phonics")) if entry.get("phonics") else [],
				})
			print("WordEngine: Loaded %d words from word_bank.tres" % word_bank.size())
			return
	if not FileAccess.file_exists(WORDS_PATH):
		push_warning("WordEngine: No word bank found, using built-in defaults")
		_use_builtin_words()
		return
	var file := FileAccess.open(WORDS_PATH, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("WordEngine: Failed to parse words.json, using defaults")
		_use_builtin_words()
		return
	var raw_words: Array = json.data.get("words", [])
	word_bank.clear()
	for entry in raw_words:
		word_bank.append(entry)

func _use_builtin_words() -> void:
	# Fallback word bank — every word can be magically summoned!
	# Level 1: CVC words (3 letters, simple sounds)
	# Level 2: Blends and 4-letter words
	# Level 3+: Longer/complex words
	word_bank = [
		# Level 1 — CVC (easiest, for beginners)
		{"word": "cat", "level": 1, "area": "meadow", "image": "cat"},
		{"word": "dog", "level": 1, "area": "meadow", "image": "dog"},
		{"word": "sun", "level": 1, "area": "meadow", "image": "sun"},
		{"word": "hat", "level": 1, "area": "meadow", "image": "hat"},
		{"word": "bed", "level": 1, "area": "meadow", "image": "bed"},
		{"word": "cup", "level": 1, "area": "meadow", "image": "cup"},
		{"word": "bug", "level": 1, "area": "meadow", "image": "bug"},
		{"word": "box", "level": 1, "area": "meadow", "image": "box"},
		{"word": "bow", "level": 1, "area": "meadow", "image": "bow"},
		# Level 2 — Blends and longer CVC
		{"word": "fish", "level": 2, "area": "meadow", "image": "fish"},
		{"word": "bird", "level": 2, "area": "meadow", "image": "bird"},
		{"word": "frog", "level": 2, "area": "meadow", "image": "frog"},
		{"word": "star", "level": 2, "area": "meadow", "image": "star"},
		{"word": "tree", "level": 2, "area": "meadow", "image": "tree"},
		{"word": "jump", "level": 2, "area": "meadow", "image": "jump"},
		{"word": "hand", "level": 2, "area": "meadow", "image": "hand"},
		{"word": "leaf", "level": 2, "area": "meadow", "image": "leaf"},
		# Level 3 — Long vowels and multi-syllable
		{"word": "flower", "level": 3, "area": "meadow", "image": "flower"},
		{"word": "castle", "level": 3, "area": "meadow", "image": "castle"},
		# Level 4 — Complex
		{"word": "rainbow", "level": 4, "area": "meadow", "image": "rainbow"},
	]

func select_word_for_area(area: String) -> String:
	# Fixed starter sequence: DOG > SUN > TREE > RAINBOW
	if not _starter_complete and _starter_index < _starter_sequence.size():
		var starter_word: String = _starter_sequence[_starter_index]
		_starter_index += 1
		if _starter_index >= _starter_sequence.size():
			_starter_complete = true
		# Find matching entry in word bank for hint image
		var hint := starter_word
		for entry in word_bank:
			if entry.get("word", "") == starter_word:
				hint = entry.get("image", starter_word)
				break
		current_target_word = starter_word.to_upper()
		current_hint_image = hint
		collected_letters.clear()
		target_word_changed.emit(current_target_word, current_hint_image)
		return current_target_word

	# After starter sequence, use random selection by area and difficulty
	var candidates := word_bank.filter(func(w: Dictionary) -> bool:
		return w.get("level", 1) <= current_difficulty and w.get("area", "") == area.to_lower()
	)
	if candidates.is_empty():
		candidates = word_bank.filter(func(w: Dictionary) -> bool:
			return w.get("level", 1) <= current_difficulty
		)
	if candidates.is_empty():
		candidates = word_bank.filter(func(w: Dictionary) -> bool:
			return w.get("level", 1) <= 1
		)
	if candidates.is_empty():
		return "cat"
	var entry: Dictionary = candidates[randi() % candidates.size()]
	current_target_word = entry.get("word", "cat").to_upper()
	current_hint_image = entry.get("image", "")
	collected_letters.clear()
	target_word_changed.emit(current_target_word, current_hint_image)
	return current_target_word

func try_collect_letter(letter: String) -> bool:
	letter = letter.to_upper()
	if current_target_word.is_empty():
		return false
	var next_index := collected_letters.size()
	if next_index >= current_target_word.length():
		return false
	var expected := current_target_word[next_index]
	if letter == expected:
		collected_letters.append(letter)
		letter_collected.emit(letter, next_index)
		if collected_letters.size() == current_target_word.length():
			_on_word_complete()
		return true
	else:
		wrong_letter_rejected.emit(letter)
		return false

func _on_word_complete() -> void:
	var word := current_target_word.to_lower()
	word_spelled_correctly.emit(word)
	GameManager.complete_word(word)
	# Sync starter progress to GameManager for persistence
	GameManager.starter_index = _starter_index
	GameManager.starter_complete = _starter_complete
	_track_attempt(word, true)
	_check_difficulty_progression()

func _track_attempt(word: String, correct: bool) -> void:
	if word not in _word_attempts:
		_word_attempts[word] = {"correct": 0, "hints_used": 0}
	if correct:
		_word_attempts[word]["correct"] += 1

func _check_difficulty_progression() -> void:
	var total := GameManager.get_total_words_completed()
	if total >= 60:
		current_difficulty = 5
	elif total >= 40:
		current_difficulty = 4
	elif total >= 25:
		current_difficulty = 3
	elif total >= 10:
		current_difficulty = 2
	else:
		current_difficulty = 1

func get_current_difficulty() -> int:
	return current_difficulty

func get_letters_needed() -> Array[String]:
	var needed: Array[String] = []
	for i in range(current_target_word.length()):
		needed.append(current_target_word[i])
	return needed

func get_next_needed_letter() -> String:
	var idx := collected_letters.size()
	if idx < current_target_word.length():
		return current_target_word[idx]
	return ""

func get_progress_for_current_word() -> float:
	if current_target_word.is_empty():
		return 0.0
	return float(collected_letters.size()) / float(current_target_word.length())

func is_word_complete() -> bool:
	return collected_letters.size() == current_target_word.length() and not current_target_word.is_empty()

func _on_progress_reset() -> void:
	_starter_index = 0
	_starter_complete = false
	current_target_word = ""
	current_hint_image = ""
	collected_letters.clear()
	current_difficulty = 1
	_word_attempts.clear()
