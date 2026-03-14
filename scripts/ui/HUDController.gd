extends CanvasLayer
## Heads-up display showing target word, collected letters, and coin count.
## All text uses 32pt+ for age-5 readability.

@onready var word_display: HBoxContainer = $WordDisplay
@onready var coin_label: Label = $CoinLabel
@onready var hint_label: Label = $HintLabel

var _letter_labels: Array[Label] = []

func _ready() -> void:
	WordEngine.target_word_changed.connect(_on_target_word_changed)
	WordEngine.letter_collected.connect(_on_letter_collected)
	WordEngine.word_spelled_correctly.connect(_on_word_complete)
	GameManager.coins_changed.connect(_on_coins_changed)
	_update_coins(0)

func _on_target_word_changed(word: String, hint_image: String) -> void:
	_clear_word_display()
	# Show hint image name for now (future: actual image)
	if hint_label:
		hint_label.text = hint_image.capitalize() if hint_image else ""
		hint_label.add_theme_font_size_override("font_size", 36)

	# Create letter slots
	for i in word.length():
		var slot := Label.new()
		slot.text = "_"
		slot.add_theme_font_size_override("font_size", 48)
		slot.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		slot.custom_minimum_size = Vector2(50, 60)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if word_display:
			word_display.add_child(slot)
		_letter_labels.append(slot)

func _on_letter_collected(letter: String, position: int) -> void:
	if position < _letter_labels.size():
		_letter_labels[position].text = letter
		# Brief scale animation
		var tween := create_tween()
		tween.tween_property(_letter_labels[position], "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(_letter_labels[position], "scale", Vector2(1.0, 1.0), 0.1)

func _on_word_complete(_word: String) -> void:
	# Celebration animation on all letters
	for label in _letter_labels:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # Gold
		var tween := create_tween()
		tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_coins_changed(total: int) -> void:
	_update_coins(total)

func _update_coins(total: int) -> void:
	if coin_label:
		coin_label.text = str(total)
		coin_label.add_theme_font_size_override("font_size", 32)

func _clear_word_display() -> void:
	_letter_labels.clear()
	if word_display:
		for child in word_display.get_children():
			child.queue_free()
