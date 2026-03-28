extends CharacterBody2D
## A silly, round, slow creature that chases the PLAYER to steal collected letters.
## Spawns when player picks a wrong letter. Waddles toward the player.
## If it touches the player, it steals all collected letters (they scatter nearby).
## Defended by: companions (scare on contact), jumping on it, completing a word, arrows.

@export var move_speed := 45.0
@export var gravity_val := 980.0

var _target_player: CharacterBody2D = null
var _scared := false
var _stealing := false
var _time := 0.0

func _ready() -> void:
	# Find the player
	_target_player = get_tree().current_scene.get_node_or_null("Player")
	# Layer 16 so companions can detect us
	collision_layer = 16
	collision_mask = 1  # Collide with terrain

func _physics_process(delta: float) -> void:
	if _scared or _stealing:
		return

	_time += delta

	# Gravity
	if not is_on_floor():
		velocity.y += gravity_val * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0

	# Chase the player
	if _target_player and is_instance_valid(_target_player):
		var dir := global_position.direction_to(_target_player.global_position)
		velocity.x = dir.x * move_speed

		# Jump over small obstacles
		if is_on_floor() and is_on_wall():
			velocity.y = -250

		# Jump if player is above
		if is_on_floor() and _target_player.global_position.y < global_position.y - 30:
			velocity.y = -280

		# Check if touching the player
		var dist := global_position.distance_to(_target_player.global_position)
		if dist < 35.0:
			_steal_letters()
	else:
		velocity.x = 0

	# Check if any companion is nearby and should scare us
	_check_companion_contact()

	move_and_slide()

	# Wobble animation
	if abs(velocity.x) > 1:
		rotation = sin(_time * 8.0) * 0.15

func _steal_letters() -> void:
	if _stealing or _scared:
		return
	if WordEngine.collected_letters.is_empty():
		# Nothing to steal, just bump and look confused
		_run_away()
		return

	_stealing = true
	velocity = Vector2.ZERO

	# Steal all collected letters
	var stolen := WordEngine.collected_letters.duplicate()
	WordEngine.collected_letters.clear()
	WordEngine.letter_lost.emit()

	# Screen shake effect
	var camera := _target_player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		var shake_tween := camera.create_tween()
		shake_tween.tween_property(camera, "offset", Vector2(8, -6), 0.05)
		shake_tween.tween_property(camera, "offset", Vector2(-8, 6), 0.05)
		shake_tween.tween_property(camera, "offset", Vector2(6, -4), 0.05)
		shake_tween.tween_property(camera, "offset", Vector2(-4, 4), 0.05)
		shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

	# Scatter stolen letters around as re-pickupable FloatingLetters
	var letter_scene_path := "res://scenes/reading/FloatingLetter.tscn"
	var letter_scene := load(letter_scene_path) as PackedScene
	if letter_scene:
		var scene_root := get_tree().current_scene
		var spawner := scene_root.get_node_or_null("LetterSpawner")
		for i in stolen.size():
			var letter_node := letter_scene.instantiate() as Node2D
			var angle := TAU * float(i) / float(stolen.size())
			var scatter_pos := _target_player.global_position + Vector2(cos(angle), sin(angle) - 0.5) * 120.0
			letter_node.position = scatter_pos - (spawner.global_position if spawner else Vector2.ZERO)
			if spawner:
				spawner.add_child(letter_node)
				spawner._spawned_letters.append(letter_node)
			else:
				scene_root.add_child(letter_node)
			if letter_node.has_method("setup"):
				letter_node.setup(stolen[i], true)

	# Thief victory dance then flee
	var tween := create_tween()
	# Mischievous hop
	tween.tween_property(self, "position:y", position.y - 30, 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y, 0.15)
	# Wiggle
	tween.tween_property(self, "rotation", 0.3, 0.1)
	tween.tween_property(self, "rotation", -0.3, 0.1)
	tween.tween_property(self, "rotation", 0.3, 0.1)
	tween.tween_property(self, "rotation", 0.0, 0.1)
	# Then run away
	tween.tween_callback(_run_away)

	print("Francis-opia: Oh no! The letter thief stole your letters!")

func _check_companion_contact() -> void:
	var magic := get_node_or_null("/root/MagicSummon")
	if not magic:
		return
	for word in magic._companions:
		var companion: Node = magic._companions[word]
		if not is_instance_valid(companion):
			continue
		# Only active companions protect
		if word not in GameManager.active_companions:
			continue
		var dist := global_position.distance_to(companion.global_position)
		if dist < 50.0:
			_scared_by_companion(companion)
			return

func _scared_by_companion(companion: Node) -> void:
	if _scared:
		return
	_scared = true
	velocity = Vector2.ZERO

	# Companion does a little protective bark/bounce
	var comp_tween := companion.create_tween()
	var orig_y: float = companion.position.y
	comp_tween.tween_property(companion, "position:y", orig_y - 10, 0.1)
	comp_tween.tween_property(companion, "position:y", orig_y, 0.1)

	# Thief gets scared
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 50, 0.2)
	tween.tween_property(self, "rotation", TAU * 2, 0.4)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

	print("Francis-opia: Your %s scared the thief away!" % _get_companion_name(companion))

func _get_companion_name(companion: Node) -> String:
	var magic := get_node_or_null("/root/MagicSummon")
	if magic:
		for word in magic._companions:
			if magic._companions[word] == companion:
				return word
	return "companion"

func scare_away() -> void:
	## Called when player jumps on the thief
	if _scared:
		return
	_scared = true
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 60, 0.2)
	tween.tween_property(self, "rotation", TAU * 2, 0.4)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func hit_by_arrow() -> void:
	scare_away()

func stunned_by_magic() -> void:
	## Called when a word is completed (summon flash scares all thieves)
	scare_away()

func _run_away() -> void:
	_scared = true
	velocity = Vector2.ZERO
	# Run in opposite direction from player then vanish
	var flee_dir := 1.0
	if _target_player and is_instance_valid(_target_player):
		flee_dir = sign(global_position.x - _target_player.global_position.x)
		if flee_dir == 0:
			flee_dir = 1.0
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + flee_dir * 300, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
