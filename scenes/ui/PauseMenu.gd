extends CanvasLayer
## Pause menu — Escape / Start button to toggle.
## Shows game options and controls reference.

enum MenuPage { MAIN, CONTROLS, SETTINGS, RESTART_CONFIRM }

var _active := false
var _current_page := MenuPage.MAIN
var _panel: PanelContainer = null
var _content: VBoxContainer = null
var _bold_font: Font = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/fonts/Andika-Bold.ttf"):
		_bold_font = load("res://assets/fonts/Andika-Bold.ttf") as Font
	_build_ui()
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _active:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif _active and event.is_action_pressed("ui_cancel"):
		if _current_page == MenuPage.MAIN:
			_close()
		else:
			_show_main_menu()
		get_viewport().set_input_as_handled()

func _open() -> void:
	_active = true
	visible = true
	get_tree().paused = true
	_show_main_menu()
	# Slide-in animation — must use TWEEN_PAUSE_PROCESS since tree is paused
	if _panel:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.9, 0.9)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_parallel(true)
		tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
		tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close() -> void:
	_active = false
	visible = false
	get_tree().paused = false

func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Center panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(700, 500)
	_panel.offset_left = -350
	_panel.offset_top = -250
	_panel.offset_right = 350
	_panel.offset_bottom = 250

	# Panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.8, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)

	add_child(_panel)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 8)
	_panel.add_child(_content)

func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()

func _show_main_menu() -> void:
	_current_page = MenuPage.MAIN
	_clear_content()

	# Title
	var title := _make_label("Francis-opia", 48, Color(1, 0.9, 0.3), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_content.add_child(_make_spacer(16))

	# Menu buttons
	_add_menu_button("Controls", _show_controls, true)
	_add_menu_button("Sound", _show_settings)
	_add_menu_button("Restart Progress", _show_restart_confirm)
	_add_menu_button("Resume", _close)

	_content.add_child(_make_spacer(24))

	# Footer hint
	var hint := _make_label("Escape / Start to resume  |  B to go back", 24, Color(0.6, 0.6, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(hint)

func _show_controls() -> void:
	_current_page = MenuPage.CONTROLS
	_clear_content()

	# Title
	var title := _make_label("Controls", 42, Color(1, 0.9, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_content.add_child(_make_spacer(8))

	# Two-column layout: Keyboard | Controller
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	_content.add_child(columns)

	# --- Keyboard column ---
	var kb_col := VBoxContainer.new()
	kb_col.add_theme_constant_override("separation", 4)
	kb_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(kb_col)

	var kb_title := _make_label("Keyboard", 32, Color(0.5, 0.8, 1.0))
	kb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kb_col.add_child(kb_title)
	kb_col.add_child(_make_spacer(4))

	var kb_controls := [
		["Move", "A / D  or  Arrows"],
		["Jump", "Space"],
		["Dig / Mine", "Q  (hold)"],
		["Aim", "Move direction"],
		["Shoot Arrow", "Left Click"],
		["Interact", "E"],
		["Portal", "T  (spell PORTAL first)"],
		["Quest Scroll", "Tab"],
		["Pause", "Escape"],
	]
	for entry in kb_controls:
		kb_col.add_child(_make_control_row(entry[0], entry[1]))

	# --- Controller column ---
	var pad_col := VBoxContainer.new()
	pad_col.add_theme_constant_override("separation", 4)
	pad_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(pad_col)

	var pad_title := _make_label("Xbox Controller", 32, Color(0.5, 1.0, 0.5))
	pad_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad_col.add_child(pad_title)
	pad_col.add_child(_make_spacer(4))

	var pad_controls := [
		["Move", "Left Stick / D-pad"],
		["Jump", "A Button"],
		["Dig / Mine", "LB  (hold)"],
		["Aim Cursor", "Right Stick"],
		["Shoot Arrow", "RT (Right Trigger)"],
		["Interact", "X Button"],
		["Portal", "LT + RT  (spell PORTAL)"],
		["Quest Scroll", "Y Button"],
		["Pause", "Start / Menu"],
	]
	for entry in pad_controls:
		pad_col.add_child(_make_control_row(entry[0], entry[1]))

	_content.add_child(_make_spacer(8))

	# Tips
	var tips_title := _make_label("Tips", 28, Color(1, 0.85, 0.5))
	_content.add_child(tips_title)

	var tips := [
		"Hold LB/Q and aim to dig tunnels in any direction!",
		"Wall jump: press Jump while sliding on a wall",
		"Dig underground to find letters and treasure!",
		"Spell words to summon magical things!",
	]
	for tip in tips:
		var tip_label := _make_label("  " + tip, 22, Color(0.7, 0.75, 0.8))
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_content.add_child(tip_label)

	_content.add_child(_make_spacer(8))

	# Back button
	_add_menu_button("Back", _show_main_menu, true)

func _show_settings() -> void:
	_current_page = MenuPage.SETTINGS
	_clear_content()

	var title := _make_label("Sound", 42, Color(1, 0.9, 0.3), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_content.add_child(_make_spacer(12))

	# Master volume
	_add_volume_slider("Master Volume", SoundFX.get_master_volume(), func(val: float) -> void:
		SoundFX.set_master_volume(val)
	)

	_content.add_child(_make_spacer(8))

	# SFX volume
	_add_volume_slider("Sound Effects", SoundFX.get_sfx_volume(), func(val: float) -> void:
		SoundFX.set_sfx_volume(val)
	)

	_content.add_child(_make_spacer(20))

	_add_menu_button("Back", _show_main_menu, true)


func _add_volume_slider(label_text: String, initial: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := _make_label(label_text, 26, Color(0.85, 0.85, 0.9))
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(300, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the slider
	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = Color(1, 0.9, 0.3, 0.9)
	grabber_style.set_corner_radius_all(6)
	grabber_style.set_content_margin_all(6)
	slider.add_theme_stylebox_override("grabber_area", grabber_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_style)

	slider.value_changed.connect(func(val: float) -> void:
		callback.call(val)
	)
	row.add_child(slider)

	var pct_label := _make_label("%d%%" % int(initial * 100), 24, Color(0.7, 0.7, 0.8))
	slider.value_changed.connect(func(val: float) -> void:
		pct_label.text = "%d%%" % int(val * 100)
	)
	row.add_child(pct_label)

	_content.add_child(row)


func _show_restart_confirm() -> void:
	_current_page = MenuPage.RESTART_CONFIRM
	_clear_content()

	var title := _make_label("Restart Progress?", 42, Color(1, 0.4, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_content.add_child(_make_spacer(16))

	var warning := _make_label("This will erase all your progress:", 28, Color(0.9, 0.85, 0.8))
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(warning)

	_content.add_child(_make_spacer(8))

	# Show what will be lost
	var stats: Array[String] = []
	if GameManager.words_completed.size() > 0:
		stats.append("  %d words spelled" % GameManager.words_completed.size())
	if GameManager.word_coins > 0:
		stats.append("  %d coins earned" % GameManager.word_coins)
	if GameManager.words_summoned.size() > 0:
		stats.append("  %d magic summons" % GameManager.words_summoned.size())
	if stats.is_empty():
		stats.append("  (no progress yet)")
	for stat in stats:
		var stat_label := _make_label(stat, 26, Color(1, 0.9, 0.6))
		_content.add_child(stat_label)

	_content.add_child(_make_spacer(24))

	_add_menu_button("Yes, Restart", _do_restart)
	_add_menu_button("No, Go Back", _show_main_menu, true)

func _do_restart() -> void:
	GameManager.reset_progress()
	_close()
	# Reload the main scene to start fresh
	get_tree().reload_current_scene()

# === UI Helpers ===

func _make_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold and _bold_font:
		label.add_theme_font_override("font", _bold_font)
	return label

func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _make_control_row(action_name: String, binding: String) -> HBoxContainer:
	var row := HBoxContainer.new()

	var action_label := _make_label(action_name, 24, Color(0.85, 0.85, 0.9))
	action_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(action_label)

	var binding_label := _make_label(binding, 24, Color(1, 0.95, 0.7))
	row.add_child(binding_label)

	return row

func _add_menu_button(text: String, callback: Callable, grab_focus_now := false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 32)
	btn.custom_minimum_size = Vector2(300, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_ALL

	# Style
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.25, 0.4, 0.8)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.3, 0.35, 0.55, 0.9)
	hover.border_color = Color(0.6, 0.7, 1.0, 0.4)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(8)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.3, 0.35, 0.55, 0.9)
	focus.border_color = Color(1, 0.9, 0.3, 0.8)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	focus.set_content_margin_all(8)
	btn.add_theme_stylebox_override("focus", focus)

	btn.pressed.connect(callback)
	_content.add_child(btn)

	if grab_focus_now:
		btn.call_deferred("grab_focus")

	return btn
