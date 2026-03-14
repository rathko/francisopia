extends Node2D
## Spawns floating letters in the world near the player.
## Letters drift gently on sine-wave paths.
## Spawns both the letters needed for the current target word and some distractors.

@export var letter_scene: PackedScene
@export var spawn_radius_x := 600.0  # How far left/right from player to spawn
@export var spawn_height_min := 200.0  # Minimum height above ground
@export var spawn_height_max := 500.0  # Maximum height above ground
@export var max_letters := 12
@export var distractor_count := 4
@export var ground_y := 725.0  # Ground level Y position

var _spawned_letters: Array[Node2D] = []
var _current_area := "meadow"
var _player: Node2D = null

func _ready() -> void:
	WordEngine.target_word_changed.connect(_on_target_word_changed)
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
	add_child(instance)

	# Spawn around player position (or world center if no player)
	var center_x := 640.0
	if _player:
		center_x = _player.global_position.x

	var x := center_x + (randf() * 2.0 - 1.0) * spawn_radius_x
	var y := ground_y - spawn_height_min - randf() * (spawn_height_max - spawn_height_min)
	instance.global_position = Vector2(x, y)

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

func set_area(area_name: String) -> void:
	_current_area = area_name
