extends Area2D
## TowerFall-style arrow with gravity arc and wall sticking.

@export var arrow_gravity := 430.0
@export var max_fall_speed := 600.0
@export var stuck_despawn_time := 5.0

var _velocity := Vector2.ZERO
var _active := true
var _stuck := false
var _lifetime := 8.0  # Max time before auto-cleanup

func launch(direction: Vector2, speed: float) -> void:
	_velocity = direction.normalized() * speed
	rotation = _velocity.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Safety cleanup
	get_tree().create_timer(_lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not _active or _stuck:
		return

	# Apply gravity — TowerFall-style arc
	_velocity.y += arrow_gravity * delta
	_velocity.y = min(_velocity.y, max_fall_speed)

	# Move
	position += _velocity * delta

	# Rotate to follow velocity vector (nose points forward during arc)
	rotation = _velocity.angle()

func _on_body_entered(body: Node2D) -> void:
	if not _active or _stuck:
		return

	if body.has_method("hit_by_arrow"):
		body.hit_by_arrow()

	# Arrow sticks on impact
	_stick()

func _stick() -> void:
	_active = false
	_stuck = true
	_velocity = Vector2.ZERO

	# Embed slightly into surface (TowerFall-style)
	position += Vector2.from_angle(rotation) * 4.0

	# Disable monitoring so it doesn't keep detecting collisions
	monitoring = false

	# Fade out and despawn after timeout
	var tween := create_tween()
	tween.tween_interval(stuck_despawn_time - 1.0)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
