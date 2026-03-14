extends StaticBody2D
## A treasure chest found underground. Press interact to open!
## Gives 3-5 coins and shows a sparkle animation.

var _opened := false
var _coin_reward := 3

func _ready() -> void:
	_coin_reward = randi_range(3, 5)
	collision_layer = 4  # Interactable layer

func interact() -> void:
	if _opened:
		return
	_opened = true

	# Give coins
	GameManager.add_coins(_coin_reward)

	# Drop a needed letter!
	_drop_letter()

	print("Francis-opia: Found %d coins and a letter in a treasure chest!" % _coin_reward)

	# Open animation — lid flies up, sparkle
	var tween := create_tween()
	var lid := get_node_or_null("Lid")
	if lid:
		tween.tween_property(lid, "position:y", lid.position.y - 30, 0.3)
		tween.tween_property(lid, "modulate:a", 0.0, 0.5)

	# Color change to show it's opened
	var body_rect := get_node_or_null("ChestBody")
	if body_rect:
		body_rect.color = Color(0.5, 0.35, 0.2, 0.5)  # Faded

	# Coin burst text
	var coin_text := Label.new()
	coin_text.text = "+%d" % _coin_reward
	coin_text.add_theme_font_size_override("font_size", 36)
	coin_text.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	coin_text.position = Vector2(-15, -50)
	add_child(coin_text)

	var text_tween := create_tween()
	text_tween.tween_property(coin_text, "position:y", coin_text.position.y - 40, 0.8)
	text_tween.parallel().tween_property(coin_text, "modulate:a", 0.0, 0.8)
	text_tween.tween_callback(coin_text.queue_free)

func _drop_letter() -> void:
	## Always drops a needed letter — treasure chests are generous!
	var letter_scene_path := "res://scenes/reading/FloatingLetter.tscn"
	var letter_packed := load(letter_scene_path) as PackedScene
	if not letter_packed:
		return
	var letter_instance := letter_packed.instantiate() as Node2D
	get_tree().current_scene.add_child(letter_instance)
	letter_instance.global_position = global_position + Vector2(0, -30)

	var next_needed := WordEngine.get_next_needed_letter()
	var letter_char := next_needed if next_needed != "" else "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[randi() % 26]
	var is_needed := (next_needed != "")

	if letter_instance.has_method("setup"):
		letter_instance.setup(str(letter_char), is_needed)
