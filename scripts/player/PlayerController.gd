extends CharacterBody2D
## Player character controller. Platformer movement with coyote time,
## variable jump height, and forgiving physics for young players.

signal dig_requested(dig_position: Vector2)

@export var move_speed := 200.0
@export var jump_velocity := -350.0
@export var gravity_multiplier := 1.0
@export var coyote_time := 0.15  # Seconds after leaving platform where jump still works
@export var jump_buffer_time := 0.1  # Seconds before landing where jump input is remembered
@export var respawn_y := 900.0  # Fall below this to respawn

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _was_on_floor := false
var _facing_right := true
var _last_safe_position := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var letter_detector: Area2D = $LetterDetector
@onready var interact_area: Area2D = $InteractArea

func _ready() -> void:
	_last_safe_position = global_position
	if letter_detector:
		letter_detector.body_entered.connect(_on_letter_contact)
		letter_detector.area_entered.connect(_on_letter_area_contact)

func _physics_process(delta: float) -> void:
	_check_respawn()
	_apply_gravity(delta)
	_handle_coyote_time(delta)
	_handle_jump_buffer(delta)
	_handle_movement()
	_handle_jump()
	_handle_interactions()
	_update_animation()
	move_and_slide()
	# Check if we landed on a LetterThief — scare it away!
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_method("scare_away"):
			if collision.get_normal().y < -0.5:  # Hit from above
				collider.scare_away()
				velocity.y = jump_velocity * 0.5  # Little bounce
	# Track safe position when on solid ground
	if is_on_floor():
		_last_safe_position = global_position

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity", 980.0) * gravity_multiplier * delta
		# Clamp fall speed for safety
		velocity.y = min(velocity.y, 600.0)

func _handle_coyote_time(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_was_on_floor = true
	elif _was_on_floor:
		_coyote_timer -= delta
		if _coyote_timer <= 0.0:
			_was_on_floor = false

func _handle_jump_buffer(delta: float) -> void:
	if InputHelper.is_jumping():
		_jump_buffer_timer = jump_buffer_time
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

func _handle_movement() -> void:
	var direction := InputHelper.get_movement()
	if abs(direction) > 0.1:
		velocity.x = direction * move_speed
		_facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.2)

func _handle_jump() -> void:
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	var wants_jump := _jump_buffer_timer > 0.0

	if can_jump and wants_jump:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_was_on_floor = false

	# Variable jump height — release early for shorter jump
	if not is_on_floor() and velocity.y < 0 and not Input.is_action_pressed("jump"):
		velocity.y *= 0.5

func _handle_interactions() -> void:
	if InputHelper.is_interacting() and interact_area:
		var bodies := interact_area.get_overlapping_bodies()
		var areas := interact_area.get_overlapping_areas()
		for body in bodies:
			if body.has_method("interact"):
				body.interact()
		for area in areas:
			if area.has_method("interact"):
				area.interact()

	# Dig action
	if InputHelper.is_digging() and is_on_floor():
		dig_requested.emit(global_position)

func _check_respawn() -> void:
	if global_position.y > respawn_y:
		global_position = _last_safe_position
		velocity = Vector2.ZERO

func is_facing_right() -> bool:
	return _facing_right

func _update_animation() -> void:
	if sprite:
		sprite.flip_h = not _facing_right

func _on_letter_contact(body: Node2D) -> void:
	if body.has_method("get_letter"):
		var letter: String = body.get_letter()
		if WordEngine.try_collect_letter(letter):
			body.collect()
		else:
			body.reject()

func _on_letter_area_contact(area: Area2D) -> void:
	if area.has_method("get_letter"):
		var letter: String = area.get_letter()
		if WordEngine.try_collect_letter(letter):
			area.collect()
		else:
			area.reject()
