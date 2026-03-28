extends Node
## Phoneme audio player — plays letter sounds and word pronunciations.
## Uses proper phoneme segmentation (44 English phonemes, not just 26 letters).
## Handles digraphs (sh, ch, th), vowel teams (ee, oo, ai), r-controlled vowels (ar, or, er),
## and split digraphs (a_e, i_e, o_e, u_e).
##
## Voice is swappable by changing VOICE_DIR constant.
## Phoneme segmentation data loaded from data/phoneme_map.json.

# === CONFIGURATION ===
# Change this to swap voice persona. Each voice has phonemes/ and words/ subdirs.
const VOICE_DIR := "res://assets/sounds/voices/alice/"
const PHONEME_DIR := VOICE_DIR + "phonemes/"
const WORD_DIR := VOICE_DIR + "words/"
const PHONEME_MAP_PATH := "res://data/phoneme_map.json"

# Voice bus — loudest in the mix, phoneme clarity is paramount
const VOICE_BUS := "Voice"
const VOICE_VOLUME_DB := 0.0  # Loudest bus

# Pool size for overlapping playback
const POOL_SIZE := 4

# Delay between phonemes when spelling out a word (seconds)
const PHONEME_DELAY := 0.3

# === INTERNAL ===
var _phoneme_cache: Dictionary = {}  # phoneme_id -> AudioStream (includes digraphs)
var _word_cache: Dictionary = {}     # word -> AudioStream
var _phoneme_map: Dictionary = {}    # word -> Array[String] of phoneme segments
var _player_pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _enabled := true

# Kid-readable labels for phoneme display in HUD
const PHONEME_LABELS: Dictionary = {
	# Single letters
	"a": "a", "b": "b", "c": "c", "d": "d", "e": "e",
	"f": "f", "g": "g", "h": "h", "i": "i", "j": "j",
	"k": "k", "l": "l", "m": "m", "n": "n", "o": "o",
	"p": "p", "q": "q", "r": "r", "s": "s", "t": "t",
	"u": "u", "v": "v", "w": "w", "x": "x", "y": "y", "z": "z",
	# Digraphs — show the letter combination
	"sh": "sh", "ch": "ch", "th": "th", "ng": "ng", "ck": "ck",
	"qu": "qu", "ll": "ll", "dge": "dge", "zh": "zh",
	# Vowel teams
	"ee": "ee", "oo": "oo", "ai": "ai", "oa": "oa",
	"ow": "ow", "ou": "ou", "oi": "oi",
	# R-controlled
	"ar": "ar", "or": "or", "ur": "ur", "er": "er", "ir": "ir",
	# Long vowel sounds
	"igh": "igh",
	# Split digraphs (shown as the vowel sound)
	"a_e": "a-e", "i_e": "i-e", "o_e": "o-e", "u_e": "u-e",
}


func _ready() -> void:
	_setup_voice_bus()
	_create_player_pool()
	_load_phoneme_map()
	_preload_phonemes()
	# Auto-play word pronunciation when a word is completed
	WordEngine.word_spelled_correctly.connect(func(word: String) -> void:
		# Small delay so the chime plays first, then the word
		await get_tree().create_timer(0.5).timeout
		play_word(word)
	)


func _setup_voice_bus() -> void:
	if AudioServer.get_bus_index(VOICE_BUS) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, VOICE_BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, VOICE_VOLUME_DB)


func _create_player_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = VOICE_BUS
		add_child(player)
		_player_pool.append(player)


func _load_phoneme_map() -> void:
	if not FileAccess.file_exists(PHONEME_MAP_PATH):
		push_warning("PhonemePlayer: phoneme_map.json not found")
		return
	var file := FileAccess.open(PHONEME_MAP_PATH, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("PhonemePlayer: Failed to parse phoneme_map.json")
		return
	var data: Dictionary = json.data
	var count := 0
	for key: String in data:
		if not key.begins_with("_"):
			_phoneme_map[key] = data[key]
			count += 1
	print("PhonemePlayer: Loaded phoneme segmentation for %d words" % count)


func _preload_phonemes() -> void:
	# Collect all unique phoneme IDs from the map
	var all_phonemes: Dictionary = {}
	for word: String in _phoneme_map:
		for seg: String in _phoneme_map[word]:
			all_phonemes[seg] = true
	# Also add single letters a-z as fallback
	for code in range(97, 123):
		all_phonemes[char(code)] = true

	var loaded := 0
	for phoneme_id: String in all_phonemes:
		var path: String = PHONEME_DIR + phoneme_id + ".mp3"
		if ResourceLoader.exists(path):
			_phoneme_cache[phoneme_id] = load(path) as AudioStream
			loaded += 1
	print("PhonemePlayer: Loaded %d/%d phoneme sounds from %s" % [loaded, all_phonemes.size(), VOICE_DIR])


# === PUBLIC API ===

func play_phoneme(phoneme_id: String) -> void:
	## Play a single phoneme sound. Can be a letter ("s") or digraph ("sh").
	if not _enabled:
		return
	phoneme_id = phoneme_id.to_lower()
	if phoneme_id in _phoneme_cache:
		_play(_phoneme_cache[phoneme_id])


func play_phoneme_for_position(word: String, letter_position: int) -> void:
	## Play the correct phoneme for a letter at the given position in a word.
	## Approach C: plays phoneme on the FIRST letter of a segment.
	## Returns silently for continuation letters (e.g., H in "sh").
	if not _enabled:
		return
	word = word.to_lower()
	var lpm := get_letter_phoneme_map(word)
	if letter_position < 0 or letter_position >= lpm.size():
		return
	var phoneme_id: String = lpm[letter_position]
	if phoneme_id.is_empty():
		return  # This letter is part of a digraph already triggered
	play_phoneme(phoneme_id)


func play_word(word: String) -> void:
	## Play the full pronunciation of a word. Loads on demand, caches.
	if not _enabled:
		return
	word = word.to_lower()
	if word not in _word_cache:
		var path := WORD_DIR + word + ".mp3"
		if ResourceLoader.exists(path):
			_word_cache[word] = load(path) as AudioStream
		else:
			# No recording — spell out by phoneme segments
			_spell_out_by_segments(word)
			return
	if word in _word_cache:
		_play(_word_cache[word])


func get_phoneme_segments(word: String) -> Array:
	## Returns the phoneme segmentation for a word: "fish" -> ["f", "i", "sh"]
	word = word.to_lower()
	if word in _phoneme_map:
		return _phoneme_map[word]
	# Fallback: split into individual letters
	var result: Array = []
	for i in word.length():
		result.append(word[i])
	return result


func get_letter_phoneme_map(word: String) -> Array:
	## Returns an array same length as the word. Each element is either:
	## - The phoneme ID to play when this letter is collected (first letter of segment)
	## - Empty string "" if this letter is a continuation of a previous segment
	## Example: "fish" -> ["f", "i", "sh", ""]   (H is part of "sh", triggered on S)
	## Example: "cake" -> ["c", "a_e", "k", ""]  (E is part of "a_e", triggered on A)
	word = word.to_lower()
	var result: Array = []
	result.resize(word.length())
	for i in word.length():
		result[i] = word[i]  # Default: each letter is its own phoneme

	if word not in _phoneme_map:
		return result

	var segments: Array = _phoneme_map[word]
	# Walk through segments and map them onto letter positions
	var letter_pos := 0
	for seg_idx in segments.size():
		var seg: String = segments[seg_idx]
		if seg.contains("_"):
			# Split digraph (a_e, i_e, etc.) — first letter gets the sound,
			# the silent E at the end gets ""
			# Find the silent E position (last letter of the word for split digraphs)
			result[letter_pos] = seg  # First vowel triggers the long vowel sound
			# Mark remaining letters in the word that belong to this split digraph
			# The "e" at the end is the second part — find it
			var e_pos := word.length() - 1  # Silent E is always at end
			if e_pos > letter_pos and e_pos < word.length():
				result[e_pos] = ""  # Silent E — no sound
			letter_pos += 1
		elif seg.length() > 1:
			# Multi-letter phoneme (sh, ch, th, etc.)
			# First letter of the group triggers the phoneme sound
			result[letter_pos] = seg
			# Remaining letters in this group get ""
			for j in range(1, seg.length()):
				if letter_pos + j < word.length():
					result[letter_pos + j] = ""
			letter_pos += seg.length()
		else:
			# Single letter phoneme
			result[letter_pos] = seg
			letter_pos += 1

	return result


func get_digraph_partner_positions(word: String) -> Dictionary:
	## Returns a dict mapping letter positions to their digraph partner positions.
	## e.g., "fish" -> {2: [3], 3: [2]}  (S and H are partners in "sh")
	## Used by HUD to light up both slots when either is collected.
	word = word.to_lower()
	var partners: Dictionary = {}
	if word not in _phoneme_map:
		return partners

	var letter_pos := 0
	var segments: Array = _phoneme_map[word]
	for seg in segments:
		if seg.contains("_"):
			# Split digraph — first vowel + final E
			var e_pos := word.length() - 1
			partners[letter_pos] = [e_pos]
			partners[e_pos] = [letter_pos]
			letter_pos += 1
		elif seg.length() > 1:
			# Multi-letter phoneme — all positions are partners
			var positions: Array = []
			for j in seg.length():
				positions.append(letter_pos + j)
			for pos in positions:
				var others: Array = []
				for p in positions:
					if p != pos:
						others.append(p)
				partners[pos] = others
			letter_pos += seg.length()
		else:
			letter_pos += 1

	return partners


func get_phonetic_spelling(word: String) -> String:
	## Returns kid-readable phonetic display: "fish" -> "f-i-sh"
	var segments := get_phoneme_segments(word)
	var parts: Array[String] = []
	for seg in segments:
		if seg in PHONEME_LABELS:
			parts.append(PHONEME_LABELS[seg])
		else:
			parts.append(seg)
	return " - ".join(parts)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func set_voice_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(VOICE_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)))


func get_voice_volume() -> float:
	var idx := AudioServer.get_bus_index(VOICE_BUS)
	if idx >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0


# === INTERNALS ===

func _play(stream: AudioStream) -> void:
	var player := _player_pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	if player.playing:
		player.stop()
	player.stream = stream
	player.volume_db = VOICE_VOLUME_DB
	player.play()


func _spell_out_by_segments(word: String) -> void:
	## Fallback: play each phoneme segment with delay.
	var segments := get_phoneme_segments(word)
	for i in segments.size():
		if i > 0:
			await get_tree().create_timer(PHONEME_DELAY).timeout
		play_phoneme(segments[i])
