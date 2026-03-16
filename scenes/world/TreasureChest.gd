extends StaticBody2D
## A treasure chest found underground or on the surface.
## Press interact to open! Gives coins and drops several letters to choose from.
## The right letter for the current word is always included, plus distractors.

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

	# Drop letters — needed + distractors for the player to choose
	_drop_letters()

	print("Francis-opia: Found %d coins and some letters!" % _coin_reward)

	# Open animation — lid flies up, sparkle
	var tween := create_tween()
	var lid := get_node_or_null("Lid")
	if lid:
		tween.tween_property(lid, "position:y", lid.position.y - 30, 0.3)
		tween.tween_property(lid, "modulate:a", 0.0, 0.5)

	# Color change to show it's opened
	var body_rect := get_node_or_null("ChestBody")
	if body_rect:
		body_rect.color = Color(0.5, 0.35, 0.2, 0.5)

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

func _drop_letters() -> void:
	var letter_scene_path := "res://scenes/reading/FloatingLetter.tscn"
	var letter_packed := load(letter_scene_path) as PackedScene
	if not letter_packed:
		return

	var next_needed := WordEngine.get_next_needed_letter()
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

	# Always include the needed letter
	var letters_to_drop: Array[Dictionary] = []
	if next_needed != "":
		letters_to_drop.append({"char": next_needed, "needed": true})

	# Add 2-3 distractors (random letters NOT matching the needed one)
	var distractor_count := randi_range(2, 3)
	for i in distractor_count:
		var d := alphabet[randi() % alphabet.length()]
		var attempts := 0
		while d == next_needed and attempts < 10:
			d = alphabet[randi() % alphabet.length()]
			attempts += 1
		letters_to_drop.append({"char": d, "needed": false})

	# Shuffle so the needed letter isn't always first
	letters_to_drop.shuffle()

	# Spawn letters in a fan pattern above the chest
	var spread := 50.0
	var total := letters_to_drop.size()
	for i in total:
		var entry: Dictionary = letters_to_drop[i]
		var letter_instance := letter_packed.instantiate() as Node2D
		# Fan out horizontally above the chest
		var offset_x := (float(i) - float(total - 1) / 2.0) * spread
		var spawn_pos := global_position + Vector2(offset_x, -40)
		get_tree().current_scene.add_child(letter_instance)
		letter_instance.global_position = spawn_pos

		if letter_instance.has_method("setup"):
			letter_instance.setup(str(entry["char"]), entry["needed"])
