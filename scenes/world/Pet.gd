extends CharacterBody2D
## A cute pet companion that follows its owner player.
## Smoothly follows, jumps when owner is above, teleports if too far.

enum PetType { DOG, CAT }

@export var pet_type: PetType = PetType.DOG
@export var follow_speed := 120.0
@export var jump_velocity := -320.0
@export var teleport_distance := 500.0
@export var follow_distance := 50.0  # Stay this far from owner
@export var gravity_val := 980.0

var pet_owner: CharacterBody2D = null
var _idle_timer := 0.0
var _wag_time := 0.0

func _ready() -> void:
	# Pets don't collide with players — only with terrain
	collision_layer = 0
	collision_mask = 1  # Only collide with ground/blocks
	z_index = 5  # Render above terrain blocks

func setup(p_owner: CharacterBody2D, p_type: PetType) -> void:
	pet_owner = p_owner
	pet_type = p_type
	_build_visuals()

func _build_visuals() -> void:
	# Clear existing visuals
	for child in get_children():
		if child is ColorRect:
			child.queue_free()

	if pet_type == PetType.DOG:
		_build_dog()
	else:
		_build_cat()

func _build_dog() -> void:
	# Body — brown rectangle
	var body := ColorRect.new()
	body.name = "Body"
	body.position = Vector2(-12, -10)
	body.size = Vector2(24, 14)
	body.color = Color(0.6, 0.4, 0.2, 1)
	add_child(body)

	# Head — slightly lighter, square-ish
	var head := ColorRect.new()
	head.name = "Head"
	head.position = Vector2(-8, -20)
	head.size = Vector2(14, 12)
	head.color = Color(0.65, 0.45, 0.25, 1)
	add_child(head)

	# Nose — dark
	var nose := ColorRect.new()
	nose.name = "Nose"
	nose.position = Vector2(-2, -14)
	nose.size = Vector2(5, 4)
	nose.color = Color(0.2, 0.15, 0.1, 1)
	add_child(nose)

	# Ears — floppy (two small rects on sides of head)
	var ear_l := ColorRect.new()
	ear_l.name = "EarL"
	ear_l.position = Vector2(-10, -22)
	ear_l.size = Vector2(5, 8)
	ear_l.color = Color(0.5, 0.32, 0.18, 1)
	add_child(ear_l)

	var ear_r := ColorRect.new()
	ear_r.name = "EarR"
	ear_r.position = Vector2(4, -22)
	ear_r.size = Vector2(5, 8)
	ear_r.color = Color(0.5, 0.32, 0.18, 1)
	add_child(ear_r)

	# Tail — small rect behind body
	var tail := ColorRect.new()
	tail.name = "Tail"
	tail.position = Vector2(10, -14)
	tail.size = Vector2(4, 10)
	tail.color = Color(0.6, 0.4, 0.2, 1)
	add_child(tail)

	# Eyes — two tiny dots
	var eye_l := ColorRect.new()
	eye_l.position = Vector2(-5, -19)
	eye_l.size = Vector2(3, 3)
	eye_l.color = Color(0.1, 0.1, 0.1, 1)
	add_child(eye_l)

	var eye_r := ColorRect.new()
	eye_r.position = Vector2(1, -19)
	eye_r.size = Vector2(3, 3)
	eye_r.color = Color(0.1, 0.1, 0.1, 1)
	add_child(eye_r)

func _build_cat() -> void:
	# Body — orange rectangle, slightly smaller than dog
	var body := ColorRect.new()
	body.name = "Body"
	body.position = Vector2(-10, -10)
	body.size = Vector2(20, 12)
	body.color = Color(0.9, 0.6, 0.2, 1)
	add_child(body)

	# Head — round-ish
	var head := ColorRect.new()
	head.name = "Head"
	head.position = Vector2(-8, -20)
	head.size = Vector2(14, 12)
	head.color = Color(0.95, 0.65, 0.25, 1)
	add_child(head)

	# Triangle ears — two small rects angled (approximated with small rects)
	var ear_l := ColorRect.new()
	ear_l.name = "EarL"
	ear_l.position = Vector2(-8, -26)
	ear_l.size = Vector2(5, 7)
	ear_l.color = Color(0.95, 0.65, 0.25, 1)
	add_child(ear_l)

	# Inner ear pink
	var ear_l_inner := ColorRect.new()
	ear_l_inner.position = Vector2(-6, -24)
	ear_l_inner.size = Vector2(3, 4)
	ear_l_inner.color = Color(1.0, 0.7, 0.75, 1)
	add_child(ear_l_inner)

	var ear_r := ColorRect.new()
	ear_r.name = "EarR"
	ear_r.position = Vector2(2, -26)
	ear_r.size = Vector2(5, 7)
	ear_r.color = Color(0.95, 0.65, 0.25, 1)
	add_child(ear_r)

	var ear_r_inner := ColorRect.new()
	ear_r_inner.position = Vector2(3, -24)
	ear_r_inner.size = Vector2(3, 4)
	ear_r_inner.color = Color(1.0, 0.7, 0.75, 1)
	add_child(ear_r_inner)

	# Nose — tiny pink
	var nose := ColorRect.new()
	nose.name = "Nose"
	nose.position = Vector2(-1, -14)
	nose.size = Vector2(3, 2)
	nose.color = Color(1.0, 0.6, 0.65, 1)
	add_child(nose)

	# Tail — long curved (approximated as thin rect)
	var tail := ColorRect.new()
	tail.name = "Tail"
	tail.position = Vector2(8, -18)
	tail.size = Vector2(3, 14)
	tail.color = Color(0.9, 0.6, 0.2, 1)
	add_child(tail)

	# Eyes — green cat eyes
	var eye_l := ColorRect.new()
	eye_l.position = Vector2(-5, -19)
	eye_l.size = Vector2(3, 4)
	eye_l.color = Color(0.3, 0.75, 0.3, 1)
	add_child(eye_l)

	var eye_r := ColorRect.new()
	eye_r.position = Vector2(1, -19)
	eye_r.size = Vector2(3, 4)
	eye_r.color = Color(0.3, 0.75, 0.3, 1)
	add_child(eye_r)

	# Whiskers — tiny lines (thin rects)
	for side in [-1, 1]:
		for i in 2:
			var whisker := ColorRect.new()
			whisker.position = Vector2(side * 6, -14 + i * 3)
			whisker.size = Vector2(8 if side > 0 else 8, 1)
			if side < 0:
				whisker.position.x = -14
			whisker.color = Color(0.7, 0.5, 0.2, 0.6)
			add_child(whisker)

func _physics_process(delta: float) -> void:
	if not pet_owner or not is_instance_valid(pet_owner):
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity_val * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0

	var dist := global_position.distance_to(pet_owner.global_position)

	# Teleport if too far or fell below the world
	if dist > teleport_distance or global_position.y > pet_owner.global_position.y + 400:
		global_position = pet_owner.global_position + Vector2(30, 0)
		velocity = Vector2.ZERO
		return

	# Follow pet_owner
	var dir_to_owner := global_position.direction_to(pet_owner.global_position)

	if dist > follow_distance:
		velocity.x = dir_to_owner.x * follow_speed
		_idle_timer = 0.0
	else:
		# Slow down when close
		velocity.x = move_toward(velocity.x, 0, follow_speed * 0.3)
		_idle_timer += delta

	# Jump if pet_owner is above and we're on the floor
	if is_on_floor() and pet_owner.global_position.y < global_position.y - 40:
		velocity.y = jump_velocity

	# Flip to face direction of movement
	var body_node := get_node_or_null("Body")
	if body_node and velocity.x != 0:
		# Flip all visuals by adjusting scale
		var facing_right := velocity.x > 0
		scale.x = 1.0 if facing_right else -1.0

	# Cute idle animation — slight bob
	if _idle_timer > 1.0:
		_wag_time += delta
		if pet_type == PetType.DOG:
			# Tail wag
			var tail := get_node_or_null("Tail")
			if tail:
				tail.rotation = sin(_wag_time * 8.0) * 0.4
		else:
			# Cat tail sway
			var tail := get_node_or_null("Tail")
			if tail:
				tail.rotation = sin(_wag_time * 3.0) * 0.3

	move_and_slide()
