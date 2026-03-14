extends Area2D
## Arrow projectile for archery training. Hits standing targets only.

var _direction := Vector2.RIGHT
var _speed := 500.0
var _active := true
var _lifetime := 3.0

func launch(direction: Vector2, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	rotation = _direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto-cleanup after lifetime
	get_tree().create_timer(_lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if _active:
		position += _direction * _speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body.has_method("hit_by_arrow"):
		body.hit_by_arrow()
	# Arrow sticks on impact
	_active = false
	# Fade and remove
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
