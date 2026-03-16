extends CharacterBody2D
## A silly, round, slow-moving creature that tries to steal floating letters.
## Spawns only when player touches a wrong letter. Very slow. Non-scary.
## Can be scared away by jumping on it or hitting with an arrow.

@export var move_speed := 30.0  # Very slow — a toddler could outrun it
@export var gravity_val := 980.0

var _target_letter: Node2D = null
var _scared := false
var _steal_range := 30.0

func _ready() -> void:
	# Find nearest needed letter to chase
	_find_target()

func _physics_process(delta: float) -> void:
	if _scared:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity_val * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0

	# Move toward target letter (very slowly)
	if _target_letter and is_instance_valid(_target_letter):
		var dir := global_position.direction_to(_target_letter.global_position)
		velocity.x = dir.x * move_speed

		# Reached the letter — steal it!
		if global_position.distance_to(_target_letter.global_position) < _steal_range:
			if _target_letter.has_method("steal"):
				_target_letter.steal()
			_target_letter = null
			# Look for next target
			await get_tree().create_timer(1.0).timeout
			_find_target()
			if _target_letter == null:
				_run_away()  # No more letters, leave
	else:
		velocity.x = 0
		_find_target()

	move_and_slide()

	# Wobble animation — silly walk
	if abs(velocity.x) > 1:
		rotation = sin(Time.get_ticks_msec() * 0.01) * 0.15

func _find_target() -> void:
	_target_letter = null
	var letters := get_tree().get_nodes_in_group("floating_letters")
	if letters.is_empty():
		# Also try finding by checking all FloatingLetter nodes
		for node in get_tree().get_nodes_in_group(""):
			pass  # Group might not exist yet
	# Search scene tree for FloatingLetter instances
	var best_dist := 99999.0
	for node in _get_all_letters():
		if not is_instance_valid(node):
			continue
		if node.has_method("is_needed") and node.is_needed():
			var dist := global_position.distance_to(node.global_position)
			if dist < best_dist:
				best_dist = dist
				_target_letter = node

func _get_all_letters() -> Array:
	var letters: Array = []
	var spawner := get_tree().current_scene.get_node_or_null("LetterSpawner")
	if spawner:
		for child in spawner.get_children():
			if child.has_method("get_letter"):
				letters.append(child)
	return letters

func scare_away() -> void:
	## Called when player jumps on or shoots the thief
	if _scared:
		return
	_scared = true
	# Funny scare animation — jump up and run!
	velocity = Vector2.ZERO
	var tween := create_tween()
	# Jump up in surprise
	tween.tween_property(self, "position:y", position.y - 60, 0.2)
	# Spin
	tween.tween_property(self, "rotation", TAU * 2, 0.4)
	# Shrink and vanish
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func hit_by_arrow() -> void:
	scare_away()

func _run_away() -> void:
	scare_away()
