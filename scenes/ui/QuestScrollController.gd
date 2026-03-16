extends CanvasLayer
## Quest Scroll UI — the todo list. Shows current quests in large, readable text.
## Inspired by Untitled Goose Game's todo list.

@export var visible_by_default := false
@export var font_size := 36

var _is_visible := false

@onready var panel: PanelContainer = $Panel
@onready var quest_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title

func _ready() -> void:
	_is_visible = visible_by_default
	_update_visibility()
	if title_label:
		title_label.text = "Quest Scroll"
		title_label.add_theme_font_size_override("font_size", 42)

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
		panel.visible = _is_visible

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
