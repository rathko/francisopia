extends CanvasLayer
## Quest Scroll UI — the todo list. Shows current quests in large, readable text.
## Inspired by Untitled Goose Game's todo list.

@export var visible_by_default := false
@export var font_size := 36

var _is_visible := false

@onready var panel: PanelContainer = $Panel
@onready var quest_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title

var _bold_font: Font = null

func _ready() -> void:
	_is_visible = visible_by_default

	# Load Andika-Bold for title
	if ResourceLoader.exists("res://assets/fonts/Andika-Bold.ttf"):
		_bold_font = load("res://assets/fonts/Andika-Bold.ttf") as Font

	# Style the panel with parchment-toned background
	if panel:
		var parchment := StyleBoxFlat.new()
		parchment.bg_color = Color(0.92, 0.87, 0.75, 0.92)
		parchment.set_corner_radius_all(6)
		parchment.border_color = Color(0.6, 0.5, 0.35, 0.6)
		parchment.set_border_width_all(2)
		parchment.content_margin_left = 16
		parchment.content_margin_right = 16
		parchment.content_margin_top = 12
		parchment.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", parchment)

	_update_visibility()
	if title_label:
		title_label.text = "Quest Scroll"
		title_label.add_theme_font_size_override("font_size", 40)
		if _bold_font:
			title_label.add_theme_font_override("font", _bold_font)
		title_label.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15))

func _process(_delta: float) -> void:
	if InputHelper.is_toggling_scroll():
		toggle()

func toggle() -> void:
	_is_visible = not _is_visible
	_update_visibility()

func show_scroll() -> void:
	_is_visible = true
	_update_visibility()

func hide_scroll() -> void:
	_is_visible = false
	_update_visibility()

func _update_visibility() -> void:
	if panel:
		if _is_visible:
			panel.visible = true
			# Slide in from right
			var tween := create_tween()
			panel.modulate.a = 0.0
			tween.tween_property(panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD)
		else:
			var tween := create_tween()
			tween.tween_property(panel, "modulate:a", 0.0, 0.15)
			tween.tween_callback(func() -> void: panel.visible = false)

func add_quest(quest: Dictionary) -> void:
	var label := Label.new()
	label.text = "  " + quest.get("text", "???")
	label.name = quest.get("id", "quest")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))  # Dark ink color
	if quest_list:
		quest_list.add_child(label)

func complete_quest(quest_id: String) -> void:
	if not quest_list:
		return
	for child in quest_list.get_children():
		if child.name == quest_id and child is Label:
			# Strikethrough effect — add line through text
			child.modulate = Color(0.5, 0.5, 0.5, 0.6)
			child.text = "  " + child.text.strip_edges()  # Keep text but gray it out
			break

func clear_quests() -> void:
	if not quest_list:
		return
	for child in quest_list.get_children():
		if child != title_label:
			child.queue_free()
