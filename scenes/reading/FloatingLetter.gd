extends Area2D
## A single floating letter in the world. Drifts on a gentle sine-wave path.
## Needed letters GLOW brightly so Francis can spot them easily.

@export var float_speed := 30.0
@export var float_amplitude := 20.0
@export var font_size := 48

var _letter := "A"
var _is_needed := false
var _base_position := Vector2.ZERO
var _time := 0.0
var _collected := false
var _phase_offset := 0.0

@onready var label: Label = $Label
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_base_position = global_position
	_phase_offset = randf() * TAU

func setup(letter_char: String, is_needed: bool) -> void:
	_letter = letter_char.to_upper()
	_is_needed = is_needed
	# Update base position — critical! _ready() may have captured wrong position
	_base_position = global_position
	if label:
		label.text = _letter
		if is_needed:
			# BIG golden letter — inspired by mockup 08-word-ui-mockup-dog.png
			label.add_theme_font_size_override("font_size", 96)
			label.modulate = Color(1.0, 0.9, 0.3, 1.0)  # Warm golden = magical
			label.add_theme_color_override("font_outline_color", Color(0.6, 0.4, 0.0))
			label.add_theme_constant_override("outline_size", 6)
		else:
			# Smaller, dim, clearly not the right one
			label.add_theme_font_size_override("font_size", 48)
			label.modulate = Color(0.5, 0.5, 0.55, 0.3)

	# Glow background — bright warm glow for needed, dim for distractors
	var bg := get_node_or_null("Background")
	if bg:
		if is_needed:
			bg.color = Color(1.0, 0.85, 0.2, 0.25)  # Golden glow
			bg.offset_left = -40
			bg.offset_top = -40
			bg.offset_right = 40
			bg.offset_bottom = 40
		else:
			bg.color = Color(0.4, 0.4, 0.5, 0.1)
			bg.offset_left = -16
			bg.offset_top = -16
			bg.offset_right = 16
			bg.offset_bottom = 16

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta

	# Gentle sine-wave floating
	var offset := sin(_time * float_speed * 0.05 + _phase_offset) * float_amplitude
	global_position.y = _base_position.y + offset
	global_position.x = _base_position.x + sin(_time * 0.3 + _phase_offset) * 10.0

	# Needed letters PULSE big and bright — warm golden glow
	if _is_needed and label:
		var pulse := 0.95 + sin(_time * 2.0) * 0.15  # Gentle pulse
		label.scale = Vector2(pulse, pulse)
		# Warm golden shimmer
		var shimmer := (sin(_time * 3.0) + 1.0) * 0.5
		label.modulate = Color(1.0, 0.85 + shimmer * 0.15, 0.2 + shimmer * 0.2, 1.0)

func get_letter() -> String:
	return _letter

func is_needed() -> bool:
	return _is_needed

func collect() -> void:
	_collected = true
	# Play correct phoneme for this letter position in the word
	# Approach C: first letter of a digraph triggers the sound, rest are silent
	# e.g., "S" in "SHIP" plays /sh/, "H" plays nothing
	var phoneme := get_node_or_null("/root/PhonemePlayer")
	if phoneme:
		var pos := WordEngine.collected_letters.size() - 1
		phoneme.play_phoneme_for_position(WordEngine.current_target_word, pos)
	# Ascending pentatonic chime based on position in word
	var sfx := get_node_or_null("/root/SoundFX")
	if sfx:
		sfx.play_letter_chime(WordEngine.collected_letters.size() - 1)
	# Trail particles float upward toward HUD
	var scene_root := get_tree().current_scene
	var vfx := get_node_or_null("/root/MagicVFX")
	var summon := get_node_or_null("/root/MagicSummon")
	if scene_root and is_instance_valid(scene_root) and vfx and summon:
		var summon_type: String = summon.get_summon_type_for_word(
			WordEngine.current_target_word.to_lower())
		var trail_color: Color = vfx.get_color_for_type(summon_type)
		vfx.spawn_trail_particles(scene_root, global_position, trail_color, 5)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

func reject() -> void:
	var tween := create_tween()
	var original_pos := global_position
	tween.tween_property(self, "global_position", original_pos + Vector2(10, -10), 0.1)
	tween.tween_property(self, "global_position", original_pos, 0.1)

func steal() -> void:
	# Called by LetterThief — letter poofs and respawns elsewhere
	_collected = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
