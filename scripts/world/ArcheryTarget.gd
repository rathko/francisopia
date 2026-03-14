extends StaticBody2D
## A standing archery target. Reacts when hit by an arrow.
## Can optionally display a letter for Word Archery mode.

signal target_hit(target: Node2D)

@export var letter_on_target := ""  # Empty = plain target
@export var hit_points := 1  # Hits needed to "break" (resets after animation)

var _hits := 0
var _letter := ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if letter_on_target:
		_letter = letter_on_target.to_upper()
		if label:
			label.text = _letter
			label.add_theme_font_size_override("font_size", 36)
			label.visible = true
	elif label:
		label.visible = false

func hit_by_arrow() -> void:
	_hits += 1
	target_hit.emit(self)

	# Spin animation
	var tween := create_tween()
	tween.tween_property(sprite if sprite else self, "rotation", TAU, 0.5)
	tween.tween_property(sprite if sprite else self, "rotation", 0.0, 0.0)

	if _hits >= hit_points:
		# "Break" animation — wobble and reform
		var reform_tween := create_tween()
		reform_tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
		reform_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
		_hits = 0

func get_letter() -> String:
	return _letter

func has_letter() -> bool:
	return not _letter.is_empty()
