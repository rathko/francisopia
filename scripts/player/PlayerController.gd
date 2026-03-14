extends CharacterBody2D
## Player character controller — Terraria-inspired movement and digging.
## Aim-based mining: right stick/mouse aims a dig cursor, LB/Q mines the targeted block.
## Supports local multiplayer — each player reads from their own gamepad device.

signal dig_requested(dig_position: Vector2)

@export var player_index := 0  # 0 = Player 1 (device 0 + keyboard), 1 = Player 2 (device 1)
@export var player_color := Color(0.25, 0.55, 0.85, 1)
@export var move_speed := 200.0
@export var jump_velocity := -350.0
@export var gravity_multiplier := 1.0
@export var coyote_time := 0.15
@export var jump_buffer_time := 0.1
@export var respawn_y := 1200.0
@export var dig_range := 96.0  # 3 blocks (32px each)
@export var dig_cooldown := 0.25  # Seconds between digs (hold to mine)
@export var wall_slide_speed := 60.0  # Max fall speed when sliding on wall

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _was_on_floor := false
var _facing_right := true
var _last_safe_position := Vector2.ZERO
var _dig_cooldown_timer := 0.0
var _aim_direction := Vector2.DOWN  # Current aim for digging
var _touching_wall := false
var _wall_direction := 0  # -1 left wall, 1 right wall, 0 none

# Dig cursor visual
var _dig_cursor: Node2D = null
var _cursor_target_pos := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var letter_detector: Area2D = $LetterDetector
@onready var interact_area: Area2D = $InteractArea

func _ready() -> void:
	_last_safe_position = global_position
	if letter_detector:
		letter_detector.body_entered.connect(_on_letter_contact)
		letter_detector.area_entered.connect(_on_letter_area_contact)
	var body_rect := get_node_or_null("BodyColor") as ColorRect
	if body_rect:
		body_rect.color = player_color
	var label := get_node_or_null("PlayerLabel") as Label
	if label:
		label.text = "P%d" % (player_index + 1)
	_create_dig_cursor()

func _create_dig_cursor() -> void:
	_dig_cursor = Node2D.new()
	_dig_cursor.z_index = 10

	# Crosshair — 4 small lines forming a +
	var cursor_color := Color(1, 1, 1, 0.6)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var line := ColorRect.new()
		line.size = Vector2(2, 8) if dir.x == 0 else Vector2(8, 2)
		line.position = dir * 6 - line.size / 2.0
		line.color = cursor_color
		_dig_cursor.add_child(line)

	# Block highlight — translucent square showing which block will be mined
	var highlight := ColorRect.new()
	highlight.name = "Highlight"
	highlight.size = Vector2(32, 32)
	highlight.position = Vector2(-16, -16)
	highlight.color = Color(1, 1, 0.5, 0.15)
	_dig_cursor.add_child(highlight)

	add_child(_dig_cursor)

func _physics_process(delta: float) -> void:
	_check_respawn()
	_apply_gravity(delta)
	_handle_wall_detection()
	_handle_coyote_time(delta)
	_handle_jump_buffer(delta)
	_handle_movement()
	_handle_jump()
	_handle_wall_jump()
	_handle_aim(delta)
	_handle_dig(delta)
	_handle_interactions()
	_update_animation()
	move_and_slide()

	# Check if we landed on a LetterThief — scare it away!
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_method("scare_away"):
			if collision.get_normal().y < -0.5:
				collider.scare_away()
				velocity.y = jump_velocity * 0.5

	if is_on_floor():
		_last_safe_position = global_position

# === Per-player input helpers ===

func _get_movement_axis() -> float:
	var joy_val := Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X)
	if abs(joy_val) > 0.2:
		return joy_val
	var dpad_left := Input.is_joy_button_pressed(player_index, JOY_BUTTON_DPAD_LEFT)
	var dpad_right := Input.is_joy_button_pressed(player_index, JOY_BUTTON_DPAD_RIGHT)
	if dpad_left:
		return -1.0
	if dpad_right:
		return 1.0
	if player_index == 0:
		return Input.get_axis("move_left", "move_right")
	return 0.0

func _get_vertical_axis() -> float:
	## Returns vertical input: -1 = up, +1 = down
	var joy_val := Input.get_joy_axis(player_index, JOY_AXIS_LEFT_Y)
	if abs(joy_val) > 0.3:
		return joy_val
	var dpad_up := Input.is_joy_button_pressed(player_index, JOY_BUTTON_DPAD_UP)
	var dpad_down := Input.is_joy_button_pressed(player_index, JOY_BUTTON_DPAD_DOWN)
	if dpad_up:
		return -1.0
	if dpad_down:
		return 1.0
	return 0.0

func _is_jump_pressed() -> bool:
	if Input.is_joy_button_pressed(player_index, JOY_BUTTON_A):
		return true
	if player_index == 0:
		return Input.is_action_pressed("jump")
	return false

func _is_jump_just_pressed() -> bool:
	if _joy_button_just_pressed(JOY_BUTTON_A):
		return true
	if player_index == 0:
		return Input.is_action_just_pressed("jump")
	return false

func _is_interact_just_pressed() -> bool:
	if _joy_button_just_pressed(JOY_BUTTON_X):
		return true
	if player_index == 0:
		return Input.is_action_just_pressed("interact")
	return false

func _is_shoot_just_pressed() -> bool:
	var trigger := Input.get_joy_axis(player_index, JOY_AXIS_TRIGGER_RIGHT)
	if trigger > 0.5:
		return true
	if player_index == 0:
		return Input.is_action_just_pressed("shoot")
	return false

func _is_dig_held() -> bool:
	## Terraria-style: HOLD to keep mining, not just press
	if Input.is_joy_button_pressed(player_index, JOY_BUTTON_LEFT_SHOULDER):
		return true
	if player_index == 0:
		return Input.is_action_pressed("dig")
	return false

func _is_dig_just_pressed() -> bool:
	if _joy_button_just_pressed(JOY_BUTTON_LEFT_SHOULDER):
		return true
	if player_index == 0:
		return Input.is_action_just_pressed("dig")
	return false

var _prev_joy_buttons: Dictionary = {}

func _joy_button_just_pressed(button: int) -> bool:
	var current := Input.is_joy_button_pressed(player_index, button)
	var key := button
	var prev: bool = _prev_joy_buttons.get(key, false)
	_prev_joy_buttons[key] = current
	return current and not prev

# === AIM SYSTEM (Terraria-style) ===

func _handle_aim(_delta: float) -> void:
	## Determine aim direction from right stick (gamepad) or mouse (keyboard player)
	var aim := Vector2.ZERO

	# Right stick aim
	var rs_x := Input.get_joy_axis(player_index, JOY_AXIS_RIGHT_X)
	var rs_y := Input.get_joy_axis(player_index, JOY_AXIS_RIGHT_Y)
	var right_stick := Vector2(rs_x, rs_y)

	if right_stick.length() > 0.3:
		aim = right_stick.normalized()
	else:
		# No right stick input — use left stick / D-pad / movement direction as aim
		var h := _get_movement_axis()
		var v := _get_vertical_axis()
		if abs(h) > 0.1 or abs(v) > 0.1:
			aim = Vector2(h, v).normalized()
		else:
			# Default: aim in facing direction + slightly down (natural digging posture)
			aim = Vector2(1.0 if _facing_right else -1.0, 0.3).normalized()

	_aim_direction = aim

	# Snap cursor to nearest block grid position within range
	var target_world := global_position + aim * dig_range * 0.7
	# Snap to 32px grid
	var grid_x := int(floor(target_world.x / 32.0)) * 32 + 16
	var grid_y := int(floor(target_world.y / 32.0)) * 32 + 16
	_cursor_target_pos = Vector2(grid_x, grid_y)

	# Update dig cursor position (smooth follow)
	if _dig_cursor:
		_dig_cursor.global_position = _cursor_target_pos
		# Only show cursor when digging is active / held
		_dig_cursor.visible = _is_dig_held()

func get_aim_direction() -> Vector2:
	return _aim_direction

# === TERRARIA-STYLE DIGGING ===

func _handle_dig(delta: float) -> void:
	# Cooldown timer
	if _dig_cooldown_timer > 0:
		_dig_cooldown_timer -= delta

	# Hold LB/Q to continuously mine at the cursor position
	if _is_dig_held() and _dig_cooldown_timer <= 0:
		var dig_target := _cursor_target_pos
		# Verify target is within range
		var dist := global_position.distance_to(dig_target)
		if dist <= dig_range:
			dig_requested.emit(dig_target)
			_dig_cooldown_timer = dig_cooldown

# === WALL DETECTION ===

func _handle_wall_detection() -> void:
	_touching_wall = false
	_wall_direction = 0

	if is_on_floor():
		return

	# Check for wall contact from slide collisions
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		# Wall = mostly horizontal normal
		if abs(normal.x) > 0.7 and abs(normal.y) < 0.3:
			_touching_wall = true
			_wall_direction = int(sign(normal.x))  # Direction AWAY from wall
			break

# === WALL SLIDE + WALL JUMP ===

func _handle_wall_jump() -> void:
	if not _touching_wall or is_on_floor():
		return

	# Wall slide — slow fall speed when touching wall
	if velocity.y > wall_slide_speed:
		velocity.y = wall_slide_speed

	# Wall jump — press jump while on wall to kick off
	if _is_jump_just_pressed():
		velocity.y = jump_velocity * 0.85  # Slightly weaker than ground jump
		velocity.x = _wall_direction * move_speed * 1.2  # Kick away from wall
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_was_on_floor = false
		_facing_right = _wall_direction > 0

# === Core movement ===

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity", 980.0) * gravity_multiplier * delta
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
	if _is_jump_just_pressed():
		_jump_buffer_timer = jump_buffer_time
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

func _handle_movement() -> void:
	var direction := _get_movement_axis()
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
	if not is_on_floor() and velocity.y < 0 and not _is_jump_pressed():
		velocity.y *= 0.5

func _handle_interactions() -> void:
	if _is_interact_just_pressed() and interact_area:
		var bodies := interact_area.get_overlapping_bodies()
		var areas := interact_area.get_overlapping_areas()
		for body in bodies:
			if body.has_method("interact"):
				body.interact()
		for area in areas:
			if area.has_method("interact"):
				area.interact()

func _check_respawn() -> void:
	if global_position.y > respawn_y:
		global_position = _last_safe_position
		velocity = Vector2.ZERO

func is_facing_right() -> bool:
	return _facing_right

func _update_animation() -> void:
	if sprite:
		sprite.flip_h = not _facing_right
	# Wall slide visual feedback — slight rotation toward wall
	if _touching_wall and not is_on_floor():
		var body_rect := get_node_or_null("BodyColor") as ColorRect
		if body_rect:
			body_rect.rotation = _wall_direction * -0.1
	else:
		var body_rect := get_node_or_null("BodyColor") as ColorRect
		if body_rect:
			body_rect.rotation = 0.0

func _on_letter_contact(body: Node2D) -> void:
	if body.has_method("get_letter"):
		var letter: String = body.get_letter()
		# Defer to avoid "Can't change state while flushing queries" error
		_handle_letter_contact.call_deferred(body, letter)

func _on_letter_area_contact(area: Area2D) -> void:
	if area.has_method("get_letter"):
		var letter: String = area.get_letter()
		# Defer to avoid "Can't change state while flushing queries" error
		_handle_letter_contact.call_deferred(area, letter)

func _handle_letter_contact(area: Area2D, letter: String) -> void:
	if not is_instance_valid(area):
		return
	if WordEngine.try_collect_letter(letter):
		area.collect()
	else:
		area.reject()
