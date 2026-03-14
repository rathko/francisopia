extends Node
## Abstracts input between gamepad and keyboard. Provides unified input interface.

signal input_device_changed(device: String)  # "keyboard" or "gamepad"

var current_device := "keyboard"
var _last_input_was_joypad := false

func _input(event: InputEvent) -> void:
	var was_joypad := _last_input_was_joypad
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_last_input_was_joypad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_last_input_was_joypad = false

	var new_device := "gamepad" if _last_input_was_joypad else "keyboard"
	if new_device != current_device:
		current_device = new_device
		input_device_changed.emit(current_device)

func is_gamepad() -> bool:
	return current_device == "gamepad"

func get_movement() -> float:
	return Input.get_axis("move_left", "move_right")

func is_jumping() -> bool:
	return Input.is_action_just_pressed("jump")

func is_interacting() -> bool:
	return Input.is_action_just_pressed("interact")

func is_shooting() -> bool:
	return Input.is_action_just_pressed("shoot")

func is_toggling_scroll() -> bool:
	return Input.is_action_just_pressed("toggle_scroll")

func is_digging() -> bool:
	return Input.is_action_just_pressed("dig")

func get_aim_direction(from_global: Vector2) -> Vector2:
	if is_gamepad():
		var aim := Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)
		if aim.length() > 0.2:
			return aim.normalized()
		return Vector2.RIGHT
	else:
		var vp := get_viewport()
		if vp == null:
			return Vector2.RIGHT
		var mouse_pos := vp.get_mouse_position()
		var dir := from_global.direction_to(mouse_pos)
		return dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
