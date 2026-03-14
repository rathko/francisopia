extends Node2D
## Bow controller for archery training. Shoots arrows at standing targets only.
## On gamepad: shoots in facing direction. On keyboard: shoots toward mouse.

@export var arrow_speed := 500.0
@export var arrow_scene: PackedScene

var _can_shoot := true
var _cooldown := 0.5
var _cooldown_timer := 0.0

func _process(delta: float) -> void:
	if not _can_shoot:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_can_shoot = true

	if InputHelper.is_shooting() and _can_shoot:
		_shoot()

func _shoot() -> void:
	if not arrow_scene:
		return
	var arrow := arrow_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = global_position

	# Determine aim direction based on input device
	var aim_dir := Vector2.RIGHT
	var player := get_parent()
	if player and player.has_method("is_facing_right"):
		aim_dir = Vector2.RIGHT if player.is_facing_right() else Vector2.LEFT

	if not InputHelper.is_gamepad():
		# On keyboard/mouse: aim toward mouse
		var vp := get_viewport()
		if vp:
			var mouse_pos := vp.get_mouse_position()
			var cam := vp.get_camera_2d()
			if cam:
				# Convert screen mouse position to world position
				var world_mouse := mouse_pos + cam.global_position - Vector2(640, 400)
				var dir := global_position.direction_to(world_mouse)
				if dir.length() > 0.01:
					aim_dir = dir.normalized()

	if arrow.has_method("launch"):
		arrow.launch(aim_dir, arrow_speed)

	_can_shoot = false
	_cooldown_timer = _cooldown
