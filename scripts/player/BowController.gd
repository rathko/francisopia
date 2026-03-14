extends Node2D
## Bow controller for archery training. Shoots arrows at standing targets only.
## Reads input from parent PlayerController's device.

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

	var player := get_parent()
	if player and player.has_method("_is_shoot_just_pressed"):
		if player._is_shoot_just_pressed() and _can_shoot:
			_shoot()

func _shoot() -> void:
	if not arrow_scene:
		return
	var arrow := arrow_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = global_position

	# Get aim direction from parent player
	var aim_dir := Vector2.RIGHT
	var player := get_parent()
	if player and player.has_method("get_aim_direction"):
		aim_dir = player.get_aim_direction()
	elif player and player.has_method("is_facing_right"):
		aim_dir = Vector2.RIGHT if player.is_facing_right() else Vector2.LEFT

	if arrow.has_method("launch"):
		arrow.launch(aim_dir, arrow_speed)

	_can_shoot = false
	_cooldown_timer = _cooldown
