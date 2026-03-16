extends Node2D
## TowerFall-style bow weapon. Instant-fire with gravity arrows.
## Visible in player's hands when equipped, rotates with aim direction.

@export var arrow_speed := 800.0
@export var arrow_scene: PackedScene
@export var cooldown := 0.3

var _can_shoot := true
var _cooldown_timer := 0.0
var _unlocked := false
var _equipped := false

# Visual bow parts (created in code for now — replace with sprites later)
var _bow_body: Node2D = null

func _ready() -> void:
	_create_bow_visual()
	# Check if already unlocked from save
	_unlocked = "bow" in GameManager.items_owned

func _create_bow_visual() -> void:
	_bow_body = Node2D.new()
	_bow_body.name = "BowVisual"

	# Bow arc — brown curved shape approximated with rects
	var grip := ColorRect.new()
	grip.position = Vector2(-2, -3)
	grip.size = Vector2(4, 6)
	grip.color = Color(0.55, 0.35, 0.15, 1)
	_bow_body.add_child(grip)

	# Upper limb
	var upper := ColorRect.new()
	upper.position = Vector2(0, -14)
	upper.size = Vector2(3, 12)
	upper.color = Color(0.6, 0.4, 0.18, 1)
	_bow_body.add_child(upper)

	# Lower limb
	var lower := ColorRect.new()
	lower.position = Vector2(0, 3)
	lower.size = Vector2(3, 12)
	lower.color = Color(0.6, 0.4, 0.18, 1)
	_bow_body.add_child(lower)

	# String
	var string_top := ColorRect.new()
	string_top.position = Vector2(-3, -14)
	string_top.size = Vector2(1, 14)
	string_top.color = Color(0.9, 0.85, 0.75, 0.8)
	_bow_body.add_child(string_top)

	var string_bot := ColorRect.new()
	string_bot.position = Vector2(-3, 0)
	string_bot.size = Vector2(1, 15)
	string_bot.color = Color(0.9, 0.85, 0.75, 0.8)
	_bow_body.add_child(string_bot)

	add_child(_bow_body)
	# Offset to player's hand area
	_bow_body.position = Vector2(12, 0)

func _process(delta: float) -> void:
	if not _equipped:
		return

	if not _can_shoot:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_can_shoot = true

	# Rotate bow visual to aim direction
	var player := _get_player()
	if player and player.has_method("get_aim_direction"):
		var aim: Vector2 = player.get_aim_direction()
		if _bow_body:
			_bow_body.rotation = aim.angle()
			# Flip bow visual when aiming left
			if aim.x < 0:
				_bow_body.scale.y = -1.0
			else:
				_bow_body.scale.y = 1.0

func use_weapon() -> void:
	## Called by PlayerController when shoot is pressed
	if not _equipped or not _can_shoot:
		return
	_shoot()

func _shoot() -> void:
	if not arrow_scene:
		return
	var arrow := arrow_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(arrow)

	# Spawn arrow at bow tip
	var aim_dir := Vector2.RIGHT
	var player := _get_player()
	if player and player.has_method("get_aim_direction"):
		aim_dir = player.get_aim_direction()
	elif player and player.has_method("is_facing_right"):
		aim_dir = Vector2.RIGHT if player.is_facing_right() else Vector2.LEFT

	arrow.global_position = global_position + aim_dir * 20.0

	if arrow.has_method("launch"):
		arrow.launch(aim_dir, arrow_speed)

	_can_shoot = false
	_cooldown_timer = cooldown

func equip() -> void:
	_equipped = true
	if _bow_body:
		_bow_body.visible = true

func unequip() -> void:
	_equipped = false
	if _bow_body:
		_bow_body.visible = false

func is_available() -> bool:
	return _unlocked

func unlock() -> void:
	_unlocked = true

func _get_player() -> Node2D:
	# Walk up: BowWeapon -> WeaponHolder -> Player
	var holder := get_parent()
	if holder:
		return holder.get_parent() as Node2D
	return null
