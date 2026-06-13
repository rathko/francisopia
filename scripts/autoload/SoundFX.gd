extends Node
## Feedback sound system — hybrid sample + pitch-shift approach.
## Loads 4 WAV samples, pitch-shifts for pentatonic scale, adds humanization jitter.
## All parameters are tweakable constants at the top.

# === TWEAKABLE CONSTANTS ===

# Pentatonic scale: semitone offsets from C4 (C-D-E-G-A-C5)
const PENTATONIC := [0, 2, 4, 7, 9, 12]

# Humanization jitter (prevents robotic repetition)
const PITCH_JITTER_CENTS := 5.0     # +/- cents of pitch variation
const VOLUME_JITTER_DB := 1.5       # +/- dB of volume variation
const TIMING_JITTER_MS := 0.0       # Currently unused — could add delayed playback

# Base volumes (linear scale, 0.0-1.0)
const CHIME_VOLUME := 0.7
const TAP_VOLUME := 0.5
const DIG_VOLUME := 0.4
const TREASURE_VOLUME := 0.35
const SUMMON_VOLUME := 0.65

# Player pool size
const POOL_SIZE := 8

# === SAMPLE PATHS ===
const CHIME_PATH := "res://assets/sounds/chime_c4.wav"
const WOOD_TAP_PATH := "res://assets/sounds/wood_tap.wav"
const DIRT_PATH := "res://assets/sounds/dirt_break.wav"
const STONE_PATH := "res://assets/sounds/stone_break.wav"

# === INTERNAL STATE ===
var _chime_stream: AudioStream = null
var _tap_stream: AudioStream = null
var _dirt_stream: AudioStream = null
var _stone_stream: AudioStream = null
var _player_pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _enabled := true


func _ready() -> void:
	_load_samples()
	_create_player_pool()
	_setup_audio_buses()
	# Auto-connect to wrong letter signal for tap sound
	WordEngine.wrong_letter_rejected.connect(func(_letter: String) -> void:
		play_wrong_letter()
	)


func _load_samples() -> void:
	if ResourceLoader.exists(CHIME_PATH):
		_chime_stream = load(CHIME_PATH) as AudioStream
	if ResourceLoader.exists(WOOD_TAP_PATH):
		_tap_stream = load(WOOD_TAP_PATH) as AudioStream
	if ResourceLoader.exists(DIRT_PATH):
		_dirt_stream = load(DIRT_PATH) as AudioStream
	if ResourceLoader.exists(STONE_PATH):
		_stone_stream = load(STONE_PATH) as AudioStream

	var loaded := 0
	if _chime_stream: loaded += 1
	if _tap_stream: loaded += 1
	if _dirt_stream: loaded += 1
	if _stone_stream: loaded += 1
	print("SoundFX: Loaded %d/4 sound samples" % loaded)


func _create_player_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_player_pool.append(player)


func _setup_audio_buses() -> void:
	# Ensure SFX bus exists
	if AudioServer.get_bus_index("SFX") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, -6.0)

		# Add subtle reverb for warmth
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.25
		reverb.wet = 0.15
		reverb.damping = 0.7
		AudioServer.add_bus_effect(idx, reverb)

	# Add HardLimiter to Master if not present
	var master_idx := 0
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master_idx):
		if AudioServer.get_bus_effect(master_idx, i) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -1.0
		AudioServer.add_bus_effect(master_idx, limiter)


# === PUBLIC API ===

func play_letter_chime(position: int) -> void:
	## Play ascending pentatonic chime based on letter position in word.
	if not _enabled or not _chime_stream:
		return
	var note_index := position % PENTATONIC.size()
	var semitones: float = PENTATONIC[note_index]
	var pitch := _semitones_to_pitch_scale(semitones)
	_play_sound(_chime_stream, pitch, CHIME_VOLUME)


func play_word_complete() -> void:
	## Play C major triad: C4 + E4 + G4 simultaneously.
	if not _enabled or not _chime_stream:
		return
	# Stagger slightly for richness (not perfectly simultaneous)
	_play_sound(_chime_stream, _semitones_to_pitch_scale(0), CHIME_VOLUME * 0.8)   # C4
	_play_sound(_chime_stream, _semitones_to_pitch_scale(4), CHIME_VOLUME * 0.7)   # E4
	_play_sound(_chime_stream, _semitones_to_pitch_scale(7), CHIME_VOLUME * 0.65)  # G4


func play_wrong_letter() -> void:
	## Soft wood tap — "not quite" without punishment.
	if not _enabled or not _tap_stream:
		return
	_play_sound(_tap_stream, 1.0, TAP_VOLUME)


func play_dig(block_type: String) -> void:
	## Dirt crumble or stone clink based on block type.
	if not _enabled:
		return
	match block_type:
		"stone":
			if _stone_stream:
				_play_sound(_stone_stream, 1.0, DIG_VOLUME)
		_:
			if _dirt_stream:
				_play_sound(_dirt_stream, 1.0, DIG_VOLUME)


func play_treasure_found() -> void:
	## Two-note ascending discovery motif (G4 -> C5).
	if not _enabled or not _chime_stream:
		return
	_play_sound(_chime_stream, _semitones_to_pitch_scale(7), TREASURE_VOLUME)  # G4
	# Second note slightly delayed via a timer
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		_play_sound(_chime_stream, _semitones_to_pitch_scale(12), TREASURE_VOLUME)  # C5
	)


func play_summon_accent(summon_type: String) -> void:
	## Type-specific summon sound accent.
	if not _enabled or not _chime_stream:
		return
	match summon_type:
		"pet":
			# Bright high chime (C5)
			_play_sound(_chime_stream, _semitones_to_pitch_scale(12), SUMMON_VOLUME)
		"world":
			# Lower, warm chime (G4) — let the reverb do the magic
			_play_sound(_chime_stream, _semitones_to_pitch_scale(7), SUMMON_VOLUME)
		"item":
			# Two quick notes (E4, A4)
			_play_sound(_chime_stream, _semitones_to_pitch_scale(4), SUMMON_VOLUME)
			get_tree().create_timer(0.1).timeout.connect(func() -> void:
				_play_sound(_chime_stream, _semitones_to_pitch_scale(9), SUMMON_VOLUME * 0.9)
			)
		"cosmetic":
			# Quick playful two-note (D4, G4)
			_play_sound(_chime_stream, _semitones_to_pitch_scale(2), SUMMON_VOLUME * 0.9)
			get_tree().create_timer(0.08).timeout.connect(func() -> void:
				_play_sound(_chime_stream, _semitones_to_pitch_scale(7), SUMMON_VOLUME)
			)
		_:
			_play_sound(_chime_stream, _semitones_to_pitch_scale(0), SUMMON_VOLUME)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


# === VOLUME CONTROL ===

func set_sfx_volume(linear: float) -> void:
	## Set SFX bus volume (0.0 to 1.0 linear scale).
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)))

func get_sfx_volume() -> float:
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0

func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(linear, 0.001, 1.0)))

func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(0))


# === INTERNALS ===

func _play_sound(stream: AudioStream, base_pitch: float, base_volume: float) -> void:
	## Play a sound with humanization jitter on the next available pool player.
	var player := _get_next_player()
	player.stream = stream

	# Apply humanization
	var pitch_jitter := randf_range(-PITCH_JITTER_CENTS, PITCH_JITTER_CENTS) / 100.0
	player.pitch_scale = base_pitch * pow(2.0, pitch_jitter / 12.0)

	var vol_jitter := randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	player.volume_db = linear_to_db(base_volume) + vol_jitter

	player.play()


func _get_next_player() -> AudioStreamPlayer:
	## Round-robin through player pool. Stops oldest if all busy.
	var player := _player_pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	if player.playing:
		player.stop()
	return player


func _semitones_to_pitch_scale(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)


# === ANIMAL VOICES (asset-free: pitch-shifted existing samples per species) ===

func play_critter(species: String, background: bool = false) -> void:
	## Give each follower a little voice without any new audio files — we pitch-shift
	## the existing chime/tap samples into a short per-species motif. Quieter in the
	## background; a touch louder when Francis walks up to the animal.
	if not _enabled:
		return
	var vol: float = 0.22 if background else 0.42
	match species:
		"dog", "pup":
			_critter_seq([[_tap_stream, 0.60], [_tap_stream, 0.55]], vol, 0.12)   # woof woof
		"cat":
			_critter_seq([[_chime_stream, 0.95], [_chime_stream, 1.20]], vol, 0.14)  # meow
		"bunny":
			_critter_seq([[_chime_stream, 1.70], [_chime_stream, 1.90]], vol, 0.08)  # squeak
		"frog":
			_critter_seq([[_tap_stream, 0.50], [_tap_stream, 0.50]], vol, 0.10)   # ribbit
		"bird":
			_critter_seq([[_chime_stream, 2.00], [_chime_stream, 2.30], [_chime_stream, 2.00]], vol, 0.07)  # tweet
		"pig":
			_critter_seq([[_tap_stream, 0.45], [_tap_stream, 0.50]], vol, 0.09)   # oink
		"hen":
			_critter_seq([[_tap_stream, 0.85], [_tap_stream, 0.95]], vol, 0.10)   # cluck
		"fish", "bug", "bat", "rat", "fox":
			_critter_seq([[_chime_stream, 1.40]], vol, 0.0)                       # soft blip
		_:
			_critter_seq([[_chime_stream, 1.10]], vol, 0.0)

func _critter_seq(notes: Array, vol: float, gap: float) -> void:
	for i in notes.size():
		var note: Array = notes[i]
		var stream: AudioStream = note[0]
		var pitch: float = note[1]
		if stream == null:
			continue
		if i == 0:
			_play_sound(stream, pitch, vol)
		else:
			get_tree().create_timer(gap * float(i)).timeout.connect(func() -> void:
				_play_sound(stream, pitch, vol)
			)
