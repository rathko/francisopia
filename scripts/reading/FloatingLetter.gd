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
			# BIG glowing golden letter — easy to spot!
			label.add_theme_font_size_override("font_size", 64)
			label.modulate = Color(1.0, 0.95, 0.3, 1.0)  # Bright gold
		else:
			# Smaller, faded distractor
			label.add_theme_font_size_override("font_size", 36)
			label.modulate = Color(0.6, 0.6, 0.7, 0.5)

	# Update background glow for needed letters
	var bg := get_node_or_null("Background")
	if bg and is_needed:
		bg.color = Color(1.0, 0.9, 0.3, 0.4)  # Golden glow
		bg.offset_left = -28
		bg.offset_top = -28
		bg.offset_right = 28
		bg.offset_bottom = 28

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta

	# Gentle sine-wave floating
	var offset := sin(_time * float_speed * 0.05 + _phase_offset) * float_amplitude
	global_position.y = _base_position.y + offset
	global_position.x = _base_position.x + sin(_time * 0.3 + _phase_offset) * 10.0

	# Needed letters PULSE to attract attention
	if _is_needed and label:
		var pulse := 0.8 + sin(_time * 3.0) * 0.2  # Pulse between 0.6 and 1.0 scale
		label.scale = Vector2(pulse, pulse)

func get_letter() -> String:
	return _letter

func is_needed() -> bool:
	return _is_needed

func collect() -> void:
	_collected = true
	AudioManager.play_letter_sound(_letter)
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
