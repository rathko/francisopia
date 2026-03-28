extends Node2D
## Spawns floating letters in the world near the player.
## Letters drift gently on sine-wave paths.
## Spawns both the letters needed for the current target word and some distractors.

@export var letter_scene: PackedScene
@export var spawn_radius_x := 400.0  # How far left/right from player to spawn
@export var spawn_height_min := 100.0  # Letters float high — visible and clear
@export var spawn_height_max := 300.0  # High up in the sky, inspired by mockup
@export var max_letters := 8           # Fewer letters = less visual clutter
@export var distractor_count := 2      # Only 2 distractors — focus on the right letters
@export var ground_y := 725.0  # Ground level Y position

var _spawned_letters: Array[Node2D] = []
var _current_area := "meadow"
var _player: Node2D = null

func _ready() -> void:
	# Letters now come from treasure chests only — no floating spawns
	WordEngine.word_spelled_correctly.connect(_on_word_completed)

func set_player(player: Node2D) -> void:
	_player = player

func spawn_letters_for_word(word: String) -> void:
	_clear_letters()
	var all_chars := word.to_upper().split("")
	var needed_letters: Array[String] = []
	for s in all_chars:
		if s != "":
			needed_letters.append(s)

	# Spawn each needed letter near the player
	for letter_char in needed_letters:
		_spawn_letter(letter_char, true)

	# Spawn distractors (random letters not in the word)
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i in distractor_count:
		var distractor := alphabet[randi() % alphabet.length()]
		var attempts := 0
		while distractor in word.to_upper() and attempts < 10:
			distractor = alphabet[randi() % alphabet.length()]
			attempts += 1
		_spawn_letter(distractor, false)

func _spawn_letter(letter_char: String, is_needed: bool) -> void:
	if not letter_scene:
		return
	var instance := letter_scene.instantiate() as Node2D

	# Calculate spawn position BEFORE adding to tree
	var center_x := 640.0
	if _player:
		center_x = _player.global_position.x

	var x := center_x + (randf() * 2.0 - 1.0) * spawn_radius_x
	var y := ground_y - spawn_height_min - randf() * (spawn_height_max - spawn_height_min)

	# Set position before add_child so _ready() captures the correct _base_position
	instance.position = Vector2(x, y) - global_position
	add_child(instance)

	if instance.has_method("setup"):
		instance.setup(letter_char, is_needed)

	_spawned_letters.append(instance)

func _clear_letters() -> void:
	for letter in _spawned_letters:
		if is_instance_valid(letter):
			letter.queue_free()
	_spawned_letters.clear()

func _on_target_word_changed(_word: String, _hint: String) -> void:
	spawn_letters_for_word(_word)

func _on_word_completed(_word: String) -> void:
	# Brief pause, then select next word
	await get_tree().create_timer(2.0).timeout
	WordEngine.select_word_for_area(_current_area)

func _process(_delta: float) -> void:
	if not _player:
		return
	# Check if all needed letters are too far away — respawn closer to player
	var any_needed_nearby := false
	for letter in _spawned_letters:
		if not is_instance_valid(letter):
			continue
		if letter.has_method("is_needed") and letter.is_needed():
			var dist := _player.global_position.distance_to(letter.global_position)
			if dist < 800.0:
				any_needed_nearby = true
				break

	# If no needed letters are within 800px, respawn the word
	if not any_needed_nearby and not _spawned_letters.is_empty():
		var has_any_needed := false
		for letter in _spawned_letters:
			if is_instance_valid(letter) and letter.has_method("is_needed") and letter.is_needed():
				has_any_needed = true
				break
		if has_any_needed:
			# Move distant needed letters closer to player
			for letter in _spawned_letters:
				if is_instance_valid(letter) and letter.has_method("is_needed") and letter.is_needed():
					var dist := _player.global_position.distance_to(letter.global_position)
					if dist > 800.0:
						var new_x := _player.global_position.x + (randf() * 2.0 - 1.0) * spawn_radius_x
						var new_y := ground_y - spawn_height_min - randf() * (spawn_height_max - spawn_height_min)
						letter.global_position = Vector2(new_x, new_y)
						if letter.has_method("setup"):
							# Re-set base position for floating animation
							letter._base_position = letter.global_position

func set_area(area_name: String) -> void:
	_current_area = area_name
