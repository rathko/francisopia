extends CanvasLayer
## Heads-up display showing target word, collected letters, and coin count.
## Shows the word to spell prominently at the top center.
## All text uses 32pt+ for age-5 readability.

@onready var word_display: HBoxContainer = $WordDisplay
@onready var coin_label: Label = $CoinLabel
@onready var hint_label: Label = $HintLabel

var _letter_labels: Array[Label] = []
var _hint_icon: ColorRect = null
var _word_bg: ColorRect = null
var _magic_summon: Node = null

func _ready() -> void:
	# Cache MagicSummon reference safely — it may not exist yet during early init
	_magic_summon = get_node_or_null("/root/MagicSummon")
	WordEngine.target_word_changed.connect(_on_target_word_changed)
	WordEngine.letter_collected.connect(_on_letter_collected)
	WordEngine.word_spelled_correctly.connect(_on_word_complete)
	GameManager.coins_changed.connect(_on_coins_changed)
	_update_coins(0)

	# Add a dark background behind word display for visibility
	if word_display:
		_word_bg = ColorRect.new()
		_word_bg.name = "WordBg"
		_word_bg.color = Color(0.05, 0.05, 0.15, 0.6)
		_word_bg.position = Vector2(word_display.offset_left - 10, word_display.offset_top - 5)
		_word_bg.size = Vector2(word_display.offset_right - word_display.offset_left + 20, word_display.offset_bottom - word_display.offset_top + 10)
		_word_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_word_bg)
		move_child(_word_bg, word_display.get_index())

func _on_target_word_changed(word: String, hint_image: String) -> void:
	_clear_word_display()

	# Show hint — "Spell: CAT" at top center
	if hint_label:
		var type_emoji := ""
		if _magic_summon:
			var summon_type := _magic_summon.get_summon_type_for_word(word)
			match summon_type:
				"pet": type_emoji = "~ "
				"world": type_emoji = "* "
				"item": type_emoji = "+ "
				"cosmetic": type_emoji = "^ "
		var hint_text := hint_image.capitalize() if hint_image else ""
		hint_label.text = "Spell: " + word + "  " + type_emoji + hint_text
		hint_label.add_theme_font_size_override("font_size", 40)

		# Color the hint
		var hint_color := Color(1.0, 0.95, 0.7)  # Default warm white
		if _magic_summon:
			var summon_color := _magic_summon.get_hint_color_for_word(word)
			if summon_color != Color.WHITE:
				hint_color = summon_color
		hint_label.add_theme_color_override("font_color", hint_color)

	# Show colored summon hint icon
	_update_hint_icon(word)

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

func _update_hint_icon(word: String) -> void:
	if _hint_icon:
		_hint_icon.queue_free()
		_hint_icon = null

	if not _magic_summon:
		return

	var color := _magic_summon.get_hint_color_for_word(word)
	if color == Color.WHITE:
		return

	_hint_icon = ColorRect.new()
	_hint_icon.custom_minimum_size = Vector2(32, 32)
	_hint_icon.color = color
	_hint_icon.tooltip_text = _magic_summon.get_hint_label_for_word(word)

	if word_display:
		word_display.add_child(_hint_icon)
		word_display.move_child(_hint_icon, 0)

func _on_letter_collected(letter: String, position: int) -> void:
	if position < _letter_labels.size():
		_letter_labels[position].text = letter
		# Color the collected letter
		var hint_color := Color(0.3, 1.0, 0.3)  # Green for collected
		if _magic_summon:
			var summon_color := _magic_summon.get_hint_color_for_word(WordEngine.current_target_word)
			if summon_color != Color.WHITE:
				hint_color = summon_color
		_letter_labels[position].add_theme_color_override("font_color", hint_color)
		# Brief scale animation
		var tween := create_tween()
		tween.tween_property(_letter_labels[position], "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(_letter_labels[position], "scale", Vector2(1.0, 1.0), 0.1)

func _on_word_complete(_word: String) -> void:
	var color := Color(0.3, 1.0, 0.3)  # Green celebration
	if _magic_summon:
		var summon_color := _magic_summon.get_hint_color_for_word(_word)
		if summon_color != Color.WHITE:
			color = summon_color
	for label in _letter_labels:
		label.add_theme_color_override("font_color", color)
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
	if _hint_icon:
		_hint_icon = null
	if word_display:
		for child in word_display.get_children():
			child.queue_free()
