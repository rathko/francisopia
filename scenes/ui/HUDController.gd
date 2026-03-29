extends CanvasLayer
## HUD — all nodes created in code. Uses a root Control for proper rendering.
## Phase 7: Andika font, styled letter slots, coin icon, polished layout.

var _hint_label: RichTextLabel = null
var _phonetic_label: Label = null
var _word_box: HBoxContainer = null
var _coin_label: Label = null
var _weapon_label: Label = null
var _letter_labels: Array[Label] = []
var _letter_panels: Array[PanelContainer] = []
var _magic_summon: Node = null
var _bold_font: Font = null

func _ready() -> void:
	_magic_summon = get_node_or_null("/root/MagicSummon")

	# Load Andika-Bold for emphasis elements
	if ResourceLoader.exists("res://assets/fonts/Andika-Bold.ttf"):
		_bold_font = load("res://assets/fonts/Andika-Bold.ttf") as Font

	# Root control fills the viewport — required for CanvasLayer children to render
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# Subtle gradient-style top bar — darker at top, fading to transparent
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.offset_bottom = 180.0
	bg.color = Color(0.02, 0.02, 0.08, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(bg)

	# Fade-out strip at bottom of HUD bar
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fade.offset_top = 170.0
	fade.offset_bottom = 190.0
	fade.color = Color(0.02, 0.02, 0.08, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(fade)

	# "Spell: DOG" rich text — word gets a distinct color
	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.text = ""
	_hint_label.fit_content = true
	_hint_label.scroll_active = false
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top = 12.0
	_hint_label.offset_bottom = 70.0
	_hint_label.add_theme_font_size_override("normal_font_size", 48)
	_hint_label.add_theme_font_size_override("bold_font_size", 48)
	if _bold_font:
		_hint_label.add_theme_font_override("bold_font", _bold_font)
	_hint_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 0.85))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_hint_label)

	# Letter slots container — centered
	_word_box = HBoxContainer.new()
	_word_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_word_box.offset_top = 78.0
	_word_box.offset_bottom = 165.0
	_word_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_word_box.add_theme_constant_override("separation", 8)
	root_ctrl.add_child(_word_box)

	# Phonetic spelling removed — research says 4 sensory channels max.
	# Word display + letter slots + hint text + chime is already 4. Adding phonetic text = clutter.

	# Coin display with icon
	var coin_container := HBoxContainer.new()
	coin_container.position = Vector2(16, 176)
	coin_container.add_theme_constant_override("separation", 6)
	root_ctrl.add_child(coin_container)

	# Coin pill background
	var coin_bg := PanelContainer.new()
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = Color(0.1, 0.08, 0.02, 0.6)
	coin_style.set_corner_radius_all(14)
	coin_style.content_margin_left = 10
	coin_style.content_margin_right = 14
	coin_style.content_margin_top = 4
	coin_style.content_margin_bottom = 4
	coin_bg.add_theme_stylebox_override("panel", coin_style)
	coin_container.add_child(coin_bg)

	var coin_inner := HBoxContainer.new()
	coin_inner.add_theme_constant_override("separation", 8)
	coin_bg.add_child(coin_inner)

	# Gold coin circle icon
	_coin_label = Label.new()
	_coin_label.text = "0"
	if _bold_font:
		_coin_label.add_theme_font_override("font", _bold_font)
	_coin_label.add_theme_font_size_override("font_size", 34)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	_coin_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0, 0.5))
	_coin_label.add_theme_constant_override("outline_size", 2)

	# Coin emoji as simple icon prefix
	var coin_icon_label := Label.new()
	coin_icon_label.text = "o"
	if _bold_font:
		coin_icon_label.add_theme_font_override("font", _bold_font)
	coin_icon_label.add_theme_font_size_override("font_size", 28)
	coin_icon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	coin_inner.add_child(coin_icon_label)
	coin_inner.add_child(_coin_label)

	# Weapon indicator — bottom-left
	_weapon_label = Label.new()
	_weapon_label.text = ""
	_weapon_label.position = Vector2(20, 720)
	_weapon_label.add_theme_font_size_override("font_size", 30)
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

	# Phonetic spelling removed to reduce visual clutter

	# Create styled letter slots with rounded backgrounds
	_letter_panels.clear()
	for i in word.length():
		var panel := PanelContainer.new()
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.25, 0.6)
		slot_style.set_corner_radius_all(8)
		slot_style.border_color = Color(0.4, 0.4, 0.6, 0.3)
		slot_style.set_border_width_all(1)
		slot_style.content_margin_left = 6
		slot_style.content_margin_right = 6
		slot_style.content_margin_top = 2
		slot_style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", slot_style)
		panel.custom_minimum_size = Vector2(54, 68)

		var slot := Label.new()
		slot.text = "·"  # Subtle dot indicator for empty slot
		if _bold_font:
			slot.add_theme_font_override("font", _bold_font)
		slot.add_theme_font_size_override("font_size", 56)
		slot.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.4))
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(slot)

		_word_box.add_child(panel)
		_letter_labels.append(slot)
		_letter_panels.append(panel)

func _on_letter_collected(letter: String, position: int) -> void:
	if position >= _letter_labels.size():
		return
	_letter_labels[position].text = letter
	_letter_labels[position].add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_letter_labels[position].add_theme_font_size_override("font_size", 60)
	if position < _letter_panels.size():
		_apply_slot_style(_letter_panels[position],
			Color(0.1, 0.25, 0.12, 0.7), Color(0.3, 0.8, 0.3, 0.5))
	var tween := create_tween()
	tween.tween_property(_letter_labels[position], "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(_letter_labels[position], "scale", Vector2(1.0, 1.0), 0.1)

	# Digraph grouping: if this letter is the first of a digraph (e.g., S in "sh"),
	# also light up the partner slot(s) to show they're one sound unit
	var phoneme_player := get_node_or_null("/root/PhonemePlayer")
	if phoneme_player:
		var partners: Dictionary = phoneme_player.get_digraph_partner_positions(
			WordEngine.current_target_word)
		if position in partners:
			for partner_pos: int in partners[position]:
				if partner_pos < _letter_labels.size() and partner_pos < _letter_panels.size():
					# Show the partner letter and style it as "grouped"
					var partner_letter := WordEngine.current_target_word[partner_pos]
					_letter_labels[partner_pos].text = partner_letter
					_letter_labels[partner_pos].add_theme_color_override(
						"font_color", Color(0.3, 0.85, 0.5, 0.7))  # Slightly dimmer green
					_letter_labels[partner_pos].add_theme_font_size_override("font_size", 56)
					_apply_slot_style(_letter_panels[partner_pos],
						Color(0.1, 0.22, 0.12, 0.5), Color(0.3, 0.7, 0.3, 0.3))  # Subtler

func _on_letter_lost() -> void:
	var lost_index := WordEngine.collected_letters.size()
	if lost_index < _letter_labels.size():
		_letter_labels[lost_index].text = "·"
		_letter_labels[lost_index].add_theme_font_size_override("font_size", 56)
		_letter_labels[lost_index].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if lost_index < _letter_panels.size():
			_apply_slot_style(_letter_panels[lost_index],
				Color(0.25, 0.1, 0.1, 0.6), Color(0.8, 0.3, 0.3, 0.5))
		var tween := create_tween()
		tween.tween_property(_letter_labels[lost_index], "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(_letter_labels[lost_index], "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_callback(func() -> void:
			if lost_index < _letter_labels.size():
				_letter_labels[lost_index].add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.4))
			if lost_index < _letter_panels.size():
				_apply_slot_style(_letter_panels[lost_index],
					Color(0.15, 0.15, 0.25, 0.6), Color(0.4, 0.4, 0.6, 0.3))
		)

func _on_word_complete(_word: String) -> void:
	for i in _letter_labels.size():
		_letter_labels[i].add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		var tween := create_tween()
		tween.tween_property(_letter_labels[i], "scale", Vector2(1.6, 1.6), 0.2)
		tween.tween_property(_letter_labels[i], "scale", Vector2(1.0, 1.0), 0.2)
		if i < _letter_panels.size():
			_apply_slot_style(_letter_panels[i],
				Color(0.3, 0.25, 0.05, 0.8), Color(1.0, 0.85, 0.2, 0.7))

func _apply_slot_style(panel: PanelContainer, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

func _on_coins_changed(total: int) -> void:
	if _coin_label:
		_coin_label.text = str(total)

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
	_letter_panels.clear()
	if _word_box:
		for child in _word_box.get_children():
			child.queue_free()
