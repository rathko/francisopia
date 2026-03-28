@tool
extends SceneTree
## Generates WAV sound samples for Francis-opia feedback sounds.
## Run with: godot --headless --script tools/generate_sounds.gd
##
## Produces 4 WAV files in assets/sounds/:
##   chime_c4.wav    — Kalimba-like chime (warm, with harmonics)
##   wood_tap.wav    — Soft wooden tap (wrong letter feedback)
##   dirt_break.wav  — Dirt crumble (dig feedback)
##   stone_break.wav — Stone clink (dig feedback)

const SAMPLE_RATE := 44100
const OUTPUT_DIR := "res://assets/sounds/"

func _initialize() -> void:
	print("=== Francis-opia Sound Generator ===")

	_generate_chime("chime_c4.wav", 261.63, 0.4)
	_generate_wood_tap("wood_tap.wav", 0.12)
	_generate_dirt_break("dirt_break.wav", 0.18)
	_generate_stone_break("stone_break.wav", 0.15)

	print("=== All sounds generated! ===")
	quit()


func _generate_chime(filename: String, freq: float, duration: float) -> void:
	## Kalimba-like chime: fundamental + harmonics with different decay rates.
	## The key to warmth: harmonics 2-5 with decreasing amplitude + slight inharmonicity.
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedFloat32Array()
	data.resize(samples)

	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var env := _kalimba_envelope(t, duration)

		# Fundamental + harmonics (kalimba recipe from research)
		var sig := 0.0
		sig += sin(TAU * freq * t) * 1.0 * exp(-t * 2.5)                    # Fundamental
		sig += sin(TAU * freq * 2.0 * t) * 0.45 * exp(-t * 3.5)             # 2nd harmonic (octave warmth)
		sig += sin(TAU * freq * 3.0 * t) * 0.2 * exp(-t * 5.0)              # 3rd harmonic (character)
		sig += sin(TAU * freq * 6.2 * t) * 0.15 * exp(-t * 8.0)             # Inharmonic overtone (kalimba signature)
		sig += sin(TAU * freq * 11.5 * t) * 0.06 * exp(-t * 20.0)           # High shimmer (attack only)

		# Brief metallic attack noise
		if t < 0.008:
			sig += (randf() * 2.0 - 1.0) * 0.2 * exp(-t * 200.0)

		data[i] = sig * env * 0.7  # Master volume

	_save_wav(filename, data)
	print("  Generated: %s (kalimba chime, %.0f Hz, %.2fs)" % [filename, freq, duration])


func _generate_wood_tap(filename: String, duration: float) -> void:
	## Soft wooden tap: filtered noise with fast decay. Non-punishing "not quite" sound.
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedFloat32Array()
	data.resize(samples)

	# Two resonant frequencies (wood body resonances)
	var f1 := 280.0  # Low body resonance
	var f2 := 520.0  # Higher tap

	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 30.0)  # Very fast decay

		var sig := 0.0
		sig += sin(TAU * f1 * t) * 0.6 * exp(-t * 25.0)
		sig += sin(TAU * f2 * t) * 0.3 * exp(-t * 35.0)
		# Brief noise for attack transient
		if t < 0.005:
			sig += (randf() * 2.0 - 1.0) * 0.4 * exp(-t * 300.0)

		data[i] = sig * env * 0.5

	_save_wav(filename, data)
	print("  Generated: %s (wood tap, %.2fs)" % [filename, duration])


func _generate_dirt_break(filename: String, duration: float) -> void:
	## Dirt crumble: low-frequency thud + filtered noise tail.
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedFloat32Array()
	data.resize(samples)

	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 15.0)

		var sig := 0.0
		# Low thud
		sig += sin(TAU * 80.0 * t) * 0.5 * exp(-t * 20.0)
		sig += sin(TAU * 120.0 * t) * 0.3 * exp(-t * 18.0)
		# Crumbly noise (filtered by simple averaging)
		var noise := (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 12.0)
		sig += noise

		data[i] = sig * env * 0.45

	_save_wav(filename, data)
	print("  Generated: %s (dirt crumble, %.2fs)" % [filename, duration])


func _generate_stone_break(filename: String, duration: float) -> void:
	## Stone clink: higher pitched, more metallic than dirt. Brief resonant tap.
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedFloat32Array()
	data.resize(samples)

	var f1 := 800.0   # Primary resonance
	var f2 := 1200.0   # Secondary
	var f3 := 340.0    # Low body

	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 20.0)

		var sig := 0.0
		sig += sin(TAU * f1 * t) * 0.4 * exp(-t * 25.0)
		sig += sin(TAU * f2 * t) * 0.2 * exp(-t * 35.0)
		sig += sin(TAU * f3 * t) * 0.3 * exp(-t * 15.0)
		# Sharp attack
		if t < 0.003:
			sig += (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 400.0)

		data[i] = sig * env * 0.5

	_save_wav(filename, data)
	print("  Generated: %s (stone clink, %.2fs)" % [filename, duration])


func _kalimba_envelope(t: float, duration: float) -> float:
	## Natural kalimba ADSR: fast attack, medium decay, no sustain, gentle release.
	var attack := 0.005   # 5ms attack (fast pluck)
	var decay := duration * 0.8

	if t < attack:
		return t / attack  # Linear attack
	else:
		# Exponential decay with gentle curve
		var decay_t := (t - attack) / decay
		return exp(-decay_t * 3.0)


func _save_wav(filename: String, data: PackedFloat32Array) -> void:
	## Writes a 16-bit mono WAV file.
	var path := OUTPUT_DIR + filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Cannot open %s for writing" % path)
		return

	var num_samples := data.size()
	var byte_rate := SAMPLE_RATE * 2  # 16-bit mono = 2 bytes per sample
	var data_size := num_samples * 2

	# WAV header (44 bytes)
	file.store_string("RIFF")
	file.store_32(36 + data_size)  # File size - 8
	file.store_string("WAVE")

	# fmt chunk
	file.store_string("fmt ")
	file.store_32(16)        # Chunk size
	file.store_16(1)         # PCM format
	file.store_16(1)         # Mono
	file.store_32(SAMPLE_RATE)
	file.store_32(byte_rate)
	file.store_16(2)         # Block align (16-bit mono)
	file.store_16(16)        # Bits per sample

	# data chunk
	file.store_string("data")
	file.store_32(data_size)

	# Convert float samples to 16-bit PCM
	for sample in data:
		var clamped := clampf(sample, -1.0, 1.0)
		var pcm := int(clamped * 32767.0)
		file.store_16(pcm)

	file.close()
