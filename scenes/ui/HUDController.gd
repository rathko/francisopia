extends CanvasLayer
## HUD — all nodes created in code. Uses a root Control for proper rendering.

var _hint_label: RichTextLabel = null
var _word_box: HBoxContainer = null
var _coin_label: Label = null
var _weapon_label: Label = null
var _letter_labels: Array[Label] = []
var _magic_summon: Node = null

func _ready() -> void:
	_magic_summon = get_node_or_null("/root/MagicSummon")

	# Root control fills the viewport — required for CanvasLayer children to render
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# Dark background panel across top
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.offset_bottom = 170.0
	bg.color = Color(0.0, 0.0, 0.1, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(bg)

	# "Spell: DOG" rich text — word gets a distinct color
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.text = ""
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top = 15.0
	_hint_label.offset_bottom = 80.0
	_hint_label.add_theme_font_size_override("normal_font_size", 52)
	_hint_label.add_theme_font_size_override("bold_font_size", 52)
	_hint_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 0.9))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_hint_label)

	# Letter slots container
	_word_box = HBoxContainer.new()
	_word_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_word_box.offset_top = 85.0
	_word_box.offset_bottom = 165.0
	_word_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_ctrl.add_child(_word_box)

	# Coin display
	_coin_label = Label.new()
	_coin_label.text = "Coins: 0"
	_coin_label.position = Vector2(20, 180)
	_coin_label.add_theme_font_size_override("font_size", 36)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	root_ctrl.add_child(_coin_label)

	# Weapon indicator — bottom-left
	_weapon_label = Label.new()
	_weapon_label.text = ""
	_weapon_label.position = Vector2(20, 720)
	_weapon_label.add_theme_font_size_override("font_size", 32)
	_weapon_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
	_weapon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_weapon_label.add_theme_constant_override("outline_size", 3)
	root_ctrl.add_child(_weapon_label)

	# Connect signals
	WordEngine.target_word_changed.connect(_on_target_word_changed)
	WordEngine.letter_collected.connect(_on_letter_collected)
	WordEngine.word_spelled_correctly.connect(_on_word_complete)
	WordEngine.letter_lost.connect(_on_letter_lost)
	GameManager.coins_changed.connect(_on_coins_changed)

	# Catch up if word already selected
	_catch_up.call_deferred()

func _catch_up() -> void:
	if _magic_summon == null:
		_magic_summon = get_node_or_null("/root/MagicSummon")
	if WordEngine.current_target_word != "":
		_on_target_word_changed(WordEngine.current_target_word, WordEngine.current_hint_image)
	# Connect to weapon holder if available
	var scene := get_tree().current_scene
	if scene:
		var player := scene.get_node_or_null("Player")
		if player:
			var holder := player.get_node_or_null("WeaponHolder")
			if holder and holder.has_signal("weapon_changed"):
				holder.weapon_changed.connect(_on_weapon_changed)
				# Show current weapon if already equipped
				if holder.has_method("get_active_weapon_name"):
					var w: String = holder.get_active_weapon_name()
					_on_weapon_changed(w)

func _on_target_word_changed(word: String, hint_image: String) -> void:
	_clear_word_display()

	# Word color — bright and distinct from the rest of the text
	var word_color := Color(0.3, 1.0, 0.5)  # Bright green by default
	if _magic_summon:
		var c: Color = _magic_summon.get_hint_color_for_word(word)
		if c != Color.WHITE:
			word_color = c
	var word_hex := word_color.to_html(false)

	# Build BBCode: "Spell:" in white, WORD in bright color, hint in softer tone
	var bbcode := "[center]Spell: [color=#%s][b]%s[/b][/color]" % [word_hex, word]
	if _magic_summon:
		var hint: String = _magic_summon.get_hint_label_for_word(word)
		if hint != "":
			bbcode += "  —  [color=#ccccaa]%s[/color]" % hint
	elif hint_image != "":
		bbcode += "  —  [color=#ccccaa]%s[/color]" % hint_image.capitalize()
	bbcode += "[/center]"
	_hint_label.text = bbcode

	# Create letter slots
	for i in word.length():
		var slot := Label.new()
		slot.text = "_"
		slot.add_theme_font_size_override("font_size", 64)
		slot.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
		slot.custom_minimum_size = Vector2(60, 80)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_word_box.add_child(slot)
		_letter_labels.append(slot)

func _on_letter_collected(letter: String, position: int) -> void:
	if position < _letter_labels.size():
		_letter_labels[position].text = letter
		_letter_labels[position].add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		var tween := create_tween()
		tween.tween_property(_letter_labels[position], "scale", Vector2(1.4, 1.4), 0.1)
		tween.tween_property(_letter_labels[position], "scale", Vector2(1.0, 1.0), 0.1)

func _on_letter_lost() -> void:
	# A letter was lost — revert last filled slot to underscore with red flash
	var lost_index := WordEngine.collected_letters.size()  # Already popped, so this is the slot
	if lost_index < _letter_labels.size():
		_letter_labels[lost_index].text = "_"
		_letter_labels[lost_index].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		var tween := create_tween()
		tween.tween_property(_letter_labels[lost_index], "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(_letter_labels[lost_index], "scale", Vector2(1.0, 1.0), 0.1)
		# Fade back to white
		tween.tween_callback(func() -> void:
			if lost_index < _letter_labels.size():
				_letter_labels[lost_index].add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
		)

func _on_word_complete(_word: String) -> void:
	for label in _letter_labels:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		var tween := create_tween()
		tween.tween_property(label, "scale", Vector2(1.6, 1.6), 0.2)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_coins_changed(total: int) -> void:
	if _coin_label:
		_coin_label.text = "Coins: " + str(total)

func _on_weapon_changed(weapon_name: String) -> void:
	if _weapon_label:
		if weapon_name.is_empty():
			_weapon_label.text = ""
		else:
			# Clean up name: "BowWeapon" -> "Bow"
			var display := weapon_name.replace("Weapon", "")
			_weapon_label.text = "🏹 " + display

func _clear_word_display() -> void:
	_letter_labels.clear()
	if _word_box:
		for child in _word_box.get_children():
			child.queue_free()
