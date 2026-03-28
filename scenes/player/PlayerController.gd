extends CharacterBody2D
## Player character controller — Terraria-inspired movement and digging.
## Aim-based mining: right stick/mouse aims a dig cursor, LB/Q mines the targeted block.
## Supports local multiplayer — each player reads from their own gamepad device.

signal dig_requested(dig_position: Vector2)
signal teleport_beacon_requested(position: Vector2)

@export var player_index := 0  # 0 = Player 1 (device 0 + keyboard), 1 = Player 2 (device 1)
@export var player_color := Color(0.25, 0.55, 0.85, 1)
@export var move_speed := 200.0
@export var jump_velocity := -280.0  # Lower, gentler jump for a children's game
@export var gravity_multiplier := 1.0
@export var coyote_time := 0.15
@export var jump_buffer_time := 0.1
@export var respawn_y := 2500.0
@export var dig_range := 96.0  # 3 blocks (32px each)
@export var dig_cooldown := 0.25  # Seconds between digs (hold to mine)
@export var wall_slide_speed := 60.0  # Max fall speed when sliding on wall
var friction := 1.0  # 1.0 = normal, lower = slippery (set by MUD spell)
var on_mud := false   # When true, player slides with no steering control

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _was_on_floor := false
var _facing_right := true
var _last_safe_position := Vector2.ZERO
var _dig_cooldown_timer := 0.0
var _aim_direction := Vector2.DOWN  # Current aim for digging
var _touching_wall := false
var _wall_direction := 0  # -1 left wall, 1 right wall, 0 none
var _highlighted_letter: Node2D = null  # Currently proximity-highlighted letter
var _highlight_original_modulate := Color.WHITE
var _highlighted_companion: Node = null
var _companion_original_modulate := Color.WHITE
var _prev_lt_rt := false
var _stuck_timer := 0.0
const STUCK_THRESHOLD := 2.0  # Seconds before auto-unstuck

# Per-frame joy button cache — computed ONCE in _physics_process to avoid
# double-consumption when multiple handlers check the same button.
var _joy_just_pressed_cache: Dictionary = {}  # button -> bool
var _prev_joy_buttons: Dictionary = {}        # button -> bool (previous frame)

# Dig cursor visual
var _dig_cursor: Node2D = null
var _cursor_target_pos := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var letter_detector: Area2D = $LetterDetector
@onready var interact_area: Area2D = $InteractArea
@onready var weapon_holder: Node2D = $WeaponHolder

func _ready() -> void:
	_last_safe_position = global_position
	# Start animated sprite if available
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("idle")
	# Diagnostic: log connected joypads (helps debug Steam Deck issues)
	var joypads := Input.get_connected_joypads()
	if joypads.size() == 0:
		print("Francis-opia: WARNING — No gamepads detected! On Steam Deck, check controller layout is set to 'Gamepad' (Steam button > Controller Settings).")
	else:
		for idx in joypads:
			print("Francis-opia: Gamepad %d: %s (GUID: %s)" % [idx, Input.get_joy_name(idx), Input.get_joy_guid(idx)])
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
	_update_joy_button_cache()
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
	_handle_weapon(delta)
	_handle_interactions()
	_handle_teleport()
	_update_letter_highlight()
	_update_companion_highlight()
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

	# Stuck detection — if player is pressing movement but velocity stays near zero
	var pressing_move: bool = abs(_get_movement_axis()) > 0.3 or _is_jump_just_pressed()
	var barely_moving: bool = velocity.length() < 5.0
	if pressing_move and barely_moving and not is_on_floor():
		_stuck_timer += delta
		if _stuck_timer >= STUCK_THRESHOLD:
			print("Francis-opia: Oops, you were stuck! Popping you free.")
			global_position = _last_safe_position
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

# === Per-player input helpers ===

func _get_movement_axis() -> float:
	# Player 0: use action system FIRST — it handles all devices (keyboard, gamepad,
	# Steam Input virtual gamepad) via device=-1 bindings in the input map.
	if player_index == 0:
		var action_val := Input.get_axis("move_left", "move_right")
		if abs(action_val) > 0.1:
			return action_val
	# Direct joy API — needed for player 2+ (multiplayer), also works as extra
	# path for player 0 if action system misses something.
	var joy_val := Input.get_joy_axis(player_index, JOY_AXIS_LEFT_X)
	if abs(joy_val) > 0.2:
		return joy_val
	var dpad_left := Input.is_joy_button_pressed(player_index, JOY_BUTTON_DPAD_LEFT)
	var dpad_right := Input.is_joy_button_pressed(player_index, JOY_BUTTON_DPAD_RIGHT)
	if dpad_left:
		return -1.0
	if dpad_right:
		return 1.0
	return 0.0

func _get_vertical_axis() -> float:
	## Returns vertical input: -1 = up, +1 = down
	# Keyboard: W/Up = aim up, S/Down = aim down
	if player_index == 0:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			return -1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			return 1.0
	# Gamepad
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
	if player_index == 0 and Input.is_action_pressed("jump"):
		return true
	if Input.is_joy_button_pressed(player_index, JOY_BUTTON_A):
		return true
	return false

func _is_jump_just_pressed() -> bool:
	if player_index == 0 and Input.is_action_just_pressed("jump"):
		return true
	if _joy_button_just_pressed(JOY_BUTTON_A):
		return true
	return false

func _is_interact_just_pressed() -> bool:
	if player_index == 0 and Input.is_action_just_pressed("interact"):
		return true
	if _joy_button_just_pressed(JOY_BUTTON_X):
		return true
	return false

func _is_shoot_just_pressed() -> bool:
	if player_index == 0 and Input.is_action_just_pressed("shoot"):
		return true
	var trigger := Input.get_joy_axis(player_index, JOY_AXIS_TRIGGER_RIGHT)
	if trigger > 0.5:
		return true
	return false

func _is_dig_held() -> bool:
	## Terraria-style: HOLD to keep mining, not just press
	if player_index == 0 and Input.is_action_pressed("dig"):
		return true
	if Input.is_joy_button_pressed(player_index, JOY_BUTTON_LEFT_SHOULDER):
		return true
	return false

func _is_dig_just_pressed() -> bool:
	if player_index == 0 and Input.is_action_just_pressed("dig"):
		return true
	if _joy_button_just_pressed(JOY_BUTTON_LEFT_SHOULDER):
		return true
	return false

func _is_next_weapon_just_pressed() -> bool:
	if player_index == 0 and Input.is_action_just_pressed("next_weapon"):
		return true
	if _joy_button_just_pressed(JOY_BUTTON_RIGHT_SHOULDER):
		return true
	return false

func _is_teleport_just_pressed() -> bool:
	# T key / action map (works with Steam Input virtual gamepad)
	if player_index == 0 and Input.is_action_just_pressed("place_teleport"):
		return true
	# LT + RT held together on controller
	var lt := Input.get_joy_axis(player_index, JOY_AXIS_TRIGGER_LEFT) > 0.7
	var rt := Input.get_joy_axis(player_index, JOY_AXIS_TRIGGER_RIGHT) > 0.7
	if lt and rt and not _prev_lt_rt:
		_prev_lt_rt = true
		return true
	if not (lt and rt):
		_prev_lt_rt = false
	return false

func _update_joy_button_cache() -> void:
	## Snapshot all joy button "just pressed" states ONCE per frame.
	## This prevents double-consumption when multiple handlers query the same button.
	_joy_just_pressed_cache.clear()
	var buttons_to_track := [
		JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y,
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	]
	for button in buttons_to_track:
		var current := Input.is_joy_button_pressed(player_index, button)
		var prev: bool = _prev_joy_buttons.get(button, false)
		_joy_just_pressed_cache[button] = current and not prev
		_prev_joy_buttons[button] = current

func _joy_button_just_pressed(button: int) -> bool:
	return _joy_just_pressed_cache.get(button, false)

# === WEAPON SYSTEM ===

func _handle_weapon(_delta: float) -> void:
	if _is_next_weapon_just_pressed() and weapon_holder:
		weapon_holder.cycle_next()

	if _is_shoot_just_pressed() and weapon_holder and weapon_holder.has_weapon_equipped():
		var active: Node2D = weapon_holder.get_active_weapon()
		if active and active.has_method("use_weapon"):
			active.use_weapon()

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
	if on_mud:
		# Sliding on mud — no steering, barely any deceleration
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.02)
		return

	var direction := _get_movement_axis()
	if abs(direction) > 0.1:
		if friction < 1.0:
			# Slippery: lerp toward target speed instead of snapping
			velocity.x = lerp(velocity.x, direction * move_speed, friction * 0.3)
		else:
			velocity.x = direction * move_speed
		_facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.2 * friction)

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

		# Find the single closest letter in range
		var closest_letter_node: Node2D = null
		var closest_dist := INF
		for area in areas:
			if area.has_method("get_letter"):
				var dist := global_position.distance_to(area.global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest_letter_node = area
		if closest_letter_node == null:
			for body in bodies:
				if body.has_method("get_letter"):
					var dist := global_position.distance_to(body.global_position)
					if dist < closest_dist:
						closest_dist = dist
						closest_letter_node = body

		# Pick up ONLY the closest letter — nothing else
		if closest_letter_node:
			var letter: String = closest_letter_node.get_letter()
			_try_pick_letter.call_deferred(closest_letter_node, letter)
		else:
			# No letter nearby — try companion swap first, then other interactables
			var swapped := _try_companion_swap()
			if not swapped:
				for body in bodies:
					if body.has_method("interact"):
						body.interact()
				for area in areas:
					if area.has_method("interact"):
						area.interact()

func _try_pick_letter(letter_node: Node2D, letter: String) -> void:
	if not is_instance_valid(letter_node):
		return
	if WordEngine.try_collect_letter(letter):
		letter_node.collect()
	else:
		# Wrong letter! Lose the last collected letter as penalty
		letter_node.reject()
		if WordEngine.collected_letters.size() > 0:
			WordEngine.collected_letters.pop_back()
			WordEngine.letter_lost.emit()
			print("Francis-opia: Oops! Wrong letter — lost one!")

func _try_companion_swap() -> bool:
	var magic := get_node_or_null("/root/MagicSummon")
	if not magic:
		return false
	# Check if any idle companion is within interact range
	var closest_word := ""
	var closest_dist := 70.0
	for word in magic._companions:
		if word in GameManager.active_companions:
			continue
		var companion: Node = magic._companions[word]
		if not is_instance_valid(companion):
			continue
		var dist := global_position.distance_to(companion.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_word = word
	if closest_word != "":
		magic.activate_companion(closest_word, self)
		print("Francis-opia: %s is now following you!" % closest_word.capitalize())
		return true
	return false

func _handle_teleport() -> void:
	if _is_teleport_just_pressed() and ("zap" in GameManager.words_summoned or "portal" in GameManager.words_summoned):
		teleport_beacon_requested.emit(global_position)

func _check_respawn() -> void:
	if global_position.y > respawn_y:
		print("Francis-opia: Respawn! Player fell to Y=%d, teleporting to %s" % [int(global_position.y), _last_safe_position])
		global_position = _last_safe_position
		velocity = Vector2.ZERO

func is_facing_right() -> bool:
	return _facing_right

func _update_animation() -> void:
	# Animated sprite state machine
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.flip_h = not _facing_right
		if not is_on_floor():
			if velocity.y < 0:
				_play_anim("jump")
			else:
				_play_anim("fall")
		elif abs(velocity.x) > 10:
			_play_anim("walk")
		else:
			_play_anim("idle")
	# Legacy Sprite2D flip
	if sprite and sprite.visible:
		sprite.flip_h = not _facing_right
	# Wall slide visual feedback
	if _touching_wall and not is_on_floor():
		var body_rect := get_node_or_null("BodyColor") as ColorRect
		if body_rect:
			body_rect.rotation = _wall_direction * -0.1
	else:
		var body_rect := get_node_or_null("BodyColor") as ColorRect
		if body_rect:
			body_rect.rotation = 0.0

func _play_anim(anim_name: String) -> void:
	if animated_sprite and animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _update_letter_highlight() -> void:
	## Show green/blue tint on the closest correct letter, red on wrong ones
	if not interact_area:
		return

	# Find closest letter in interact range
	var closest: Node2D = null
	var closest_dist := INF
	for area in interact_area.get_overlapping_areas():
		if area.has_method("get_letter"):
			var dist := global_position.distance_to(area.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = area
	if closest == null:
		for body in interact_area.get_overlapping_bodies():
			if body.has_method("get_letter"):
				var dist := global_position.distance_to(body.global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest = body

	# Un-highlight previous letter if it changed
	if _highlighted_letter != closest:
		if _highlighted_letter and is_instance_valid(_highlighted_letter):
			_highlighted_letter.modulate = _highlight_original_modulate
		_highlighted_letter = closest
		if closest:
			_highlight_original_modulate = closest.modulate

	# Apply highlight tint to closest letter
	if closest and is_instance_valid(closest):
		var letter: String = closest.get_letter()
		var next_needed: String = WordEngine.get_next_needed_letter()
		if letter == next_needed:
			# Correct — soft green/cyan pulse
			var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.005) * 0.15
			closest.modulate = Color(0.6 * pulse, 1.0 * pulse, 0.8 * pulse, 1.0)
		else:
			# Wrong — soft red tint
			var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.004) * 0.1
			closest.modulate = Color(1.0 * pulse, 0.45 * pulse, 0.4 * pulse, 0.85)

func _update_companion_highlight() -> void:
	var magic := get_node_or_null("/root/MagicSummon")
	if not magic:
		return
	# Find closest idle companion within interact range
	var closest: Node = null
	var closest_dist := 70.0
	for word in magic._companions:
		if word in GameManager.active_companions:
			continue
		var companion: Node = magic._companions[word]
		if not is_instance_valid(companion):
			continue
		var dist := global_position.distance_to(companion.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = companion

	# Un-highlight previous
	if _highlighted_companion != closest:
		if _highlighted_companion and is_instance_valid(_highlighted_companion):
			_highlighted_companion.modulate = _companion_original_modulate
		_highlighted_companion = closest
		if closest:
			_companion_original_modulate = closest.modulate

	# Apply highlight pulse
	if closest and is_instance_valid(closest):
		var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.005) * 0.15
		closest.modulate = Color(0.7 * pulse, 1.0 * pulse, 0.7 * pulse, 1.0)

func _on_letter_contact(_body: Node2D) -> void:
	pass  # Letters are now picked up via interact, not auto-collect

func _on_letter_area_contact(_area: Area2D) -> void:
	pass  # Letters are now picked up via interact, not auto-collect
