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
var _recent_words: Array[String] = []  # Last N words to avoid repetition
const RECENT_WORD_MEMORY := 30  # How many recent words to avoid repeating

# Fixed starter sequence — these words always come first in order
# Phonics-informed: CVC words the child already knows, pets early for engagement
var _starter_sequence: Array[String] = ["cat", "dog", "sun", "hut"]
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
		# ============================================================
		# LEVEL 1 — CVC words (short vowels, 3 letters)
		# Phonics progression: short a > short o > short i > short e > short u
		# Only concrete, visualizable words a 5-year-old knows
		# ============================================================

		# Short A family
		{"word": "cat", "level": 1, "area": "meadow", "image": "cat"},
		{"word": "hat", "level": 1, "area": "meadow", "image": "hat"},
		{"word": "bat", "level": 1, "area": "meadow", "image": "bat"},
		{"word": "mat", "level": 1, "area": "meadow", "image": "mat"},
		{"word": "rat", "level": 1, "area": "meadow", "image": "rat"},
		{"word": "van", "level": 1, "area": "meadow", "image": "van"},
		{"word": "fan", "level": 1, "area": "meadow", "image": "fan"},
		{"word": "can", "level": 1, "area": "meadow", "image": "can"},
		{"word": "pan", "level": 1, "area": "meadow", "image": "pan"},
		{"word": "map", "level": 1, "area": "meadow", "image": "map"},
		{"word": "cap", "level": 1, "area": "meadow", "image": "cap"},
		{"word": "jam", "level": 1, "area": "meadow", "image": "jam"},
		{"word": "bag", "level": 1, "area": "meadow", "image": "bag"},

		# Short O family
		{"word": "dog", "level": 1, "area": "meadow", "image": "dog"},
		{"word": "log", "level": 1, "area": "meadow", "image": "log"},
		{"word": "fog", "level": 1, "area": "meadow", "image": "fog"},
		{"word": "hop", "level": 1, "area": "meadow", "image": "hop"},
		{"word": "pot", "level": 1, "area": "meadow", "image": "pot"},
		{"word": "hot", "level": 1, "area": "meadow", "image": "hot"},
		{"word": "box", "level": 1, "area": "meadow", "image": "box"},
		{"word": "fox", "level": 1, "area": "meadow", "image": "fox"},
		{"word": "dot", "level": 1, "area": "meadow", "image": "dot"},
		{"word": "cot", "level": 1, "area": "meadow", "image": "cot"},
		{"word": "mop", "level": 1, "area": "meadow", "image": "mop"},

		# Short I family
		{"word": "pig", "level": 1, "area": "meadow", "image": "pig"},
		{"word": "big", "level": 1, "area": "meadow", "image": "big"},
		{"word": "dig", "level": 1, "area": "meadow", "image": "dig"},
		{"word": "wig", "level": 1, "area": "meadow", "image": "wig"},
		{"word": "fin", "level": 1, "area": "meadow", "image": "fin"},
		{"word": "bin", "level": 1, "area": "meadow", "image": "bin"},
		{"word": "pin", "level": 1, "area": "meadow", "image": "pin"},
		{"word": "sit", "level": 1, "area": "meadow", "image": "sit"},
		{"word": "hit", "level": 1, "area": "meadow", "image": "hit"},
		{"word": "bit", "level": 1, "area": "meadow", "image": "bit"},
		{"word": "lip", "level": 1, "area": "meadow", "image": "lip"},
		{"word": "zip", "level": 1, "area": "meadow", "image": "zip"},
		{"word": "mix", "level": 1, "area": "meadow", "image": "mix"},
		{"word": "six", "level": 1, "area": "meadow", "image": "six"},

		# Short E family
		{"word": "bed", "level": 1, "area": "meadow", "image": "bed"},
		{"word": "red", "level": 1, "area": "meadow", "image": "red"},
		{"word": "hen", "level": 1, "area": "meadow", "image": "hen"},
		{"word": "pen", "level": 1, "area": "meadow", "image": "pen"},
		{"word": "ten", "level": 1, "area": "meadow", "image": "ten"},
		{"word": "men", "level": 1, "area": "meadow", "image": "men"},
		{"word": "net", "level": 1, "area": "meadow", "image": "net"},
		{"word": "pet", "level": 1, "area": "meadow", "image": "pet"},
		{"word": "jet", "level": 1, "area": "meadow", "image": "jet"},
		{"word": "wet", "level": 1, "area": "meadow", "image": "wet"},
		{"word": "web", "level": 1, "area": "meadow", "image": "web"},
		{"word": "leg", "level": 1, "area": "meadow", "image": "leg"},
		{"word": "gem", "level": 1, "area": "meadow", "image": "gem"},

		# Short U family
		{"word": "sun", "level": 1, "area": "meadow", "image": "sun"},
		{"word": "cup", "level": 1, "area": "meadow", "image": "cup"},
		{"word": "bug", "level": 1, "area": "meadow", "image": "bug"},
		{"word": "run", "level": 1, "area": "meadow", "image": "run"},
		{"word": "mud", "level": 1, "area": "meadow", "image": "mud"},
		{"word": "hug", "level": 1, "area": "meadow", "image": "hug"},
		{"word": "rug", "level": 1, "area": "meadow", "image": "rug"},
		{"word": "jug", "level": 1, "area": "meadow", "image": "jug"},
		{"word": "tub", "level": 1, "area": "meadow", "image": "tub"},
		{"word": "bus", "level": 1, "area": "meadow", "image": "bus"},
		{"word": "nut", "level": 1, "area": "meadow", "image": "nut"},
		{"word": "hut", "level": 1, "area": "meadow", "image": "hut"},
		{"word": "pup", "level": 1, "area": "meadow", "image": "pup"},
		{"word": "gum", "level": 1, "area": "meadow", "image": "gum"},
		{"word": "bun", "level": 1, "area": "meadow", "image": "bun"},
		{"word": "bow", "level": 1, "area": "meadow", "image": "bow"},

		# Level 1 additions — building + teleport
		{"word": "hut", "level": 1, "area": "meadow", "image": "hut"},
		{"word": "zap", "level": 1, "area": "meadow", "image": "zap"},

		# ============================================================
		# LEVEL 2 — CCVC/CVCC consonant blends
		# Two consonants together (fr, cr, dr, st, mp, nd, etc.)
		# ============================================================
		{"word": "frog", "level": 2, "area": "meadow", "image": "frog"},
		{"word": "crab", "level": 2, "area": "meadow", "image": "crab"},
		{"word": "drum", "level": 2, "area": "meadow", "image": "drum"},
		{"word": "flag", "level": 2, "area": "meadow", "image": "flag"},
		{"word": "jump", "level": 2, "area": "meadow", "image": "jump"},
		{"word": "hand", "level": 2, "area": "meadow", "image": "hand"},
		{"word": "lamp", "level": 2, "area": "meadow", "image": "lamp"},
		{"word": "pond", "level": 2, "area": "meadow", "image": "pond"},
		{"word": "nest", "level": 2, "area": "meadow", "image": "nest"},
		{"word": "tent", "level": 2, "area": "meadow", "image": "tent"},
		{"word": "sand", "level": 2, "area": "meadow", "image": "sand"},
		{"word": "milk", "level": 2, "area": "meadow", "image": "milk"},
		{"word": "gold", "level": 2, "area": "meadow", "image": "gold"},
		{"word": "swim", "level": 2, "area": "meadow", "image": "swim"},
		{"word": "clap", "level": 2, "area": "meadow", "image": "clap"},
		{"word": "snap", "level": 2, "area": "meadow", "image": "snap"},
		{"word": "drop", "level": 2, "area": "meadow", "image": "drop"},
		{"word": "step", "level": 2, "area": "meadow", "image": "step"},
		{"word": "wind", "level": 2, "area": "meadow", "image": "wind"},
		{"word": "worm", "level": 2, "area": "meadow", "image": "worm"},
		{"word": "bell", "level": 2, "area": "meadow", "image": "bell"},
		{"word": "hill", "level": 2, "area": "meadow", "image": "hill"},
		{"word": "well", "level": 2, "area": "meadow", "image": "well"},

		# ============================================================
		# LEVEL 3 — Digraphs (sh, ch, th, ck, ng) + vowel teams (ee, oo, ai, oa)
		# Two letters making ONE sound
		# ============================================================
		{"word": "fish", "level": 3, "area": "meadow", "image": "fish"},
		{"word": "ship", "level": 3, "area": "meadow", "image": "ship"},
		{"word": "duck", "level": 3, "area": "meadow", "image": "duck"},
		{"word": "rock", "level": 3, "area": "meadow", "image": "rock"},
		{"word": "lock", "level": 3, "area": "meadow", "image": "lock"},
		{"word": "sock", "level": 3, "area": "meadow", "image": "sock"},
		{"word": "ring", "level": 3, "area": "meadow", "image": "ring"},
		{"word": "king", "level": 3, "area": "meadow", "image": "king"},
		{"word": "sing", "level": 3, "area": "meadow", "image": "sing"},
		{"word": "path", "level": 3, "area": "meadow", "image": "path"},
		{"word": "bath", "level": 3, "area": "meadow", "image": "bath"},
		{"word": "tree", "level": 3, "area": "meadow", "image": "tree"},
		{"word": "moon", "level": 3, "area": "meadow", "image": "moon"},
		{"word": "boot", "level": 3, "area": "meadow", "image": "boot"},
		{"word": "rain", "level": 3, "area": "meadow", "image": "rain"},
		{"word": "seed", "level": 3, "area": "meadow", "image": "seed"},
		{"word": "leaf", "level": 3, "area": "meadow", "image": "leaf"},
		{"word": "star", "level": 3, "area": "meadow", "image": "star"},
		{"word": "bird", "level": 3, "area": "meadow", "image": "bird"},
		{"word": "snow", "level": 3, "area": "meadow", "image": "snow"},
		{"word": "hammer", "level": 3, "area": "meadow", "image": "hammer"},

		# ============================================================
		# LEVEL 4 — Magic E (split digraphs) + long vowels
		# Silent e makes the vowel "say its name"
		# ============================================================
		{"word": "cake", "level": 4, "area": "meadow", "image": "cake"},
		{"word": "lake", "level": 4, "area": "meadow", "image": "lake"},
		{"word": "cave", "level": 4, "area": "meadow", "image": "cave"},
		{"word": "wave", "level": 4, "area": "meadow", "image": "wave"},
		{"word": "bone", "level": 4, "area": "meadow", "image": "bone"},
		{"word": "home", "level": 4, "area": "meadow", "image": "home"},
		{"word": "rope", "level": 4, "area": "meadow", "image": "rope"},
		{"word": "kite", "level": 4, "area": "meadow", "image": "kite"},
		{"word": "bike", "level": 4, "area": "meadow", "image": "bike"},
		{"word": "fire", "level": 4, "area": "meadow", "image": "fire"},
		{"word": "cube", "level": 4, "area": "meadow", "image": "cube"},
		{"word": "tube", "level": 4, "area": "meadow", "image": "tube"},
		{"word": "rose", "level": 4, "area": "meadow", "image": "rose"},
		{"word": "nose", "level": 4, "area": "meadow", "image": "nose"},
		{"word": "gate", "level": 4, "area": "meadow", "image": "gate"},
		{"word": "vine", "level": 4, "area": "meadow", "image": "vine"},
		{"word": "boat", "level": 4, "area": "meadow", "image": "boat"},
		{"word": "goat", "level": 4, "area": "meadow", "image": "goat"},
		{"word": "toad", "level": 4, "area": "meadow", "image": "toad"},
		{"word": "snail", "level": 4, "area": "meadow", "image": "snail"},
		{"word": "train", "level": 4, "area": "meadow", "image": "train"},
		{"word": "sheep", "level": 4, "area": "meadow", "image": "sheep"},
		{"word": "queen", "level": 4, "area": "meadow", "image": "queen"},
		{"word": "mouse", "level": 4, "area": "meadow", "image": "mouse"},
		{"word": "cloud", "level": 4, "area": "meadow", "image": "cloud"},
		{"word": "crown", "level": 4, "area": "meadow", "image": "crown"},
		{"word": "flower", "level": 4, "area": "meadow", "image": "flower"},
		{"word": "castle", "level": 4, "area": "meadow", "image": "castle"},
		{"word": "bridge", "level": 4, "area": "meadow", "image": "bridge"},
		{"word": "garden", "level": 4, "area": "meadow", "image": "garden"},
		{"word": "planet", "level": 4, "area": "meadow", "image": "planet"},
		{"word": "rabbit", "level": 4, "area": "meadow", "image": "rabbit"},
		{"word": "kitten", "level": 4, "area": "meadow", "image": "kitten"},
		{"word": "puppy", "level": 4, "area": "meadow", "image": "puppy"},

		# ============================================================
		# LEVEL 5 — R-controlled vowels, multi-syllable, complex
		# ============================================================
		{"word": "rainbow", "level": 5, "area": "meadow", "image": "rainbow"},
		{"word": "dragon", "level": 5, "area": "meadow", "image": "dragon"},
		{"word": "forest", "level": 5, "area": "meadow", "image": "forest"},
		{"word": "river", "level": 5, "area": "meadow", "image": "river"},
		{"word": "island", "level": 5, "area": "meadow", "image": "island"},
		{"word": "mountain", "level": 5, "area": "meadow", "image": "mountain"},
		{"word": "butterfly", "level": 5, "area": "meadow", "image": "butterfly"},
		{"word": "treasure", "level": 5, "area": "meadow", "image": "treasure"},
		{"word": "dolphin", "level": 5, "area": "meadow", "image": "dolphin"},
		{"word": "penguin", "level": 5, "area": "meadow", "image": "penguin"},
		{"word": "monster", "level": 5, "area": "meadow", "image": "monster"},
		{"word": "wizard", "level": 5, "area": "meadow", "image": "wizard"},
		{"word": "lantern", "level": 4, "area": "meadow", "image": "lantern"},
		{"word": "thunder", "level": 4, "area": "meadow", "image": "thunder"},
		{"word": "mushroom", "level": 4, "area": "meadow", "image": "mushroom"},
	]

func select_word_for_area(area: String) -> String:
	# Force ZAP as the first word on Level 2 (teleport unlock)
	if GameManager.current_level >= 2 and "zap" not in GameManager.words_summoned:
		current_target_word = "ZAP"
		current_hint_image = "zap"
		collected_letters.clear()
		target_word_changed.emit(current_target_word, current_hint_image)
		return current_target_word

	# Force HUT if player has 3+ companions but no hut yet
	if "hut" not in GameManager.words_summoned:
		var pet_words := ["dog", "cat", "frog", "pig", "bug", "fish", "bird", "hen", "bat", "rat", "fox", "pup"]
		var companion_count := 0
		for w in GameManager.words_summoned:
			if w in pet_words:
				companion_count += 1
		if companion_count >= 3:
			current_target_word = "HUT"
			current_hint_image = "hut"
			collected_letters.clear()
			target_word_changed.emit(current_target_word, current_hint_image)
			return current_target_word

	# Fixed starter sequence: DOG > SUN > TREE > HAMMER > HOUSE > RAINBOW
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
	# Only TEMPORARY POWER-UPS are repeatable — regular words should be learned once, then move on
	var repeatable := ["big", "run", "hop", "zip", "dig", "red", "hot", "wet", "hug", "hit", "mud"]
	# Underground levels bump minimum difficulty: Level 2 uses words level 2+
	var min_difficulty: int = maxi(1, GameManager.current_level)
	var max_difficulty: int = maxi(current_difficulty, min_difficulty)
	var candidates := word_bank.filter(func(w: Dictionary) -> bool:
		var wl: int = w.get("level", 1)
		var word: String = w.get("word", "")
		var not_done := word not in GameManager.words_summoned or word in repeatable
		return wl >= min_difficulty and wl <= max_difficulty and w.get("area", "") == area.to_lower() and not_done
	)
	if candidates.is_empty():
		# Relax area filter
		candidates = word_bank.filter(func(w: Dictionary) -> bool:
			var wl: int = w.get("level", 1)
			var word: String = w.get("word", "")
			var not_done := word not in GameManager.words_summoned or word in repeatable
			return wl >= min_difficulty and wl <= max_difficulty and not_done
		)
	if candidates.is_empty():
		# All words done at this difficulty, allow repeats
		candidates = word_bank.filter(func(w: Dictionary) -> bool:
			return w.get("level", 1) <= max_difficulty
		)
	if candidates.is_empty():
		return "cat"

	# Priority 1: ALWAYS prefer words never summoned yet (new words = learning!)
	var never_done := candidates.filter(func(w: Dictionary) -> bool:
		return w.get("word", "") not in GameManager.words_summoned
	)
	if not never_done.is_empty():
		candidates = never_done

	# Priority 2: Filter out recently used words
	var fresh := candidates.filter(func(w: Dictionary) -> bool:
		return w.get("word", "") not in _recent_words
	)
	if not fresh.is_empty():
		candidates = fresh
	elif _recent_words.size() > 0:
		# At minimum avoid the very last word
		var last_word: String = _recent_words[-1]
		var not_last := candidates.filter(func(w: Dictionary) -> bool:
			return w.get("word", "") != last_word
		)
		if not not_last.is_empty():
			candidates = not_last

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
	# Track recent words to avoid repetition
	_recent_words.append(word)
	if _recent_words.size() > RECENT_WORD_MEMORY:
		_recent_words.pop_front()
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
	_recent_words.clear()
