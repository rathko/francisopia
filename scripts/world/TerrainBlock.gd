extends StaticBody2D
## A single breakable terrain block (32x32). Part of the block-based terrain grid.
## Can be destroyed by player dig action. May contain treasure.

const BLOCK_SIZE := 32.0

var grid_x := 0
var grid_y := 0
var is_grass := false
var has_treasure := false

func setup(gx: int, gy: int, p_is_grass: bool, p_has_treasure: bool = false) -> void:
	grid_x = gx
	grid_y = gy
	is_grass = p_is_grass
	has_treasure = p_has_treasure
	_build_visual()

func _build_visual() -> void:
	# Block visual
	var rect := ColorRect.new()
	rect.name = "Visual"
	rect.position = Vector2(-BLOCK_SIZE / 2.0, -BLOCK_SIZE / 2.0)
	rect.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)

	if is_grass:
		rect.color = Color(0.36, 0.68, 0.34, 1)  # Green grass
	else:
		# Vary dirt color slightly for visual interest
		var shade := randf_range(0.0, 0.08)
		rect.color = Color(0.5 + shade, 0.35 + shade, 0.2 + shade * 0.5, 1)

	add_child(rect)

	# Add subtle border line for grid visibility
	var border := ColorRect.new()
	border.name = "Border"
	border.position = Vector2(-BLOCK_SIZE / 2.0, -BLOCK_SIZE / 2.0)
	border.size = Vector2(BLOCK_SIZE, 1)
	border.color = Color(0, 0, 0, 0.08)
	add_child(border)

	# Treasure sparkle hint (subtle)
	if has_treasure:
		var sparkle := ColorRect.new()
		sparkle.name = "Sparkle"
		sparkle.position = Vector2(-2, -2)
		sparkle.size = Vector2(4, 4)
		sparkle.color = Color(1, 0.85, 0.2, 0.4)
		add_child(sparkle)

func dig() -> void:
	## Called when a player digs this block. Destroys it with a small particle effect.
	_spawn_break_particles()

	if has_treasure:
		_spawn_treasure()

	# Remove block
	queue_free()

func _spawn_hidden_letter() -> void:
	var letter_scene_path := "res://scenes/reading/FloatingLetter.tscn"
	var letter_packed := load(letter_scene_path) as PackedScene
	if not letter_packed:
		return
	var letter_instance := letter_packed.instantiate() as Node2D
	var spawn_pos := global_position
	get_tree().current_scene.add_child(letter_instance)
	letter_instance.global_position = spawn_pos

	# 70% chance it's a needed letter, 30% random
	var letter_char := ""
	var is_needed := false
	var next_needed := WordEngine.get_next_needed_letter()
	if next_needed != "" and randf() < 0.7:
		letter_char = next_needed
		is_needed = true
	else:
		var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		letter_char = alphabet[randi() % alphabet.length()]
		is_needed = (letter_char == next_needed)

	if letter_instance.has_method("setup"):
		letter_instance.setup(letter_char, is_needed)

func _spawn_break_particles() -> void:
	# Simple particle burst — a few small rects that fly out
	var parent_node := get_parent()
	if not parent_node:
		return

	for i in 4:
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position - Vector2(3, 3)
		particle.color = Color(0.5, 0.35, 0.2, 0.8) if not is_grass else Color(0.36, 0.68, 0.34, 0.8)
		particle.z_index = 5
		get_tree().current_scene.add_child(particle)

		var dir := Vector2(randf_range(-1, 1), randf_range(-1.5, -0.3)).normalized()
		var tween := particle.create_tween()
		tween.tween_property(particle, "position", particle.position + dir * randf_range(20, 50), 0.4)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(particle.queue_free)

func _spawn_treasure() -> void:
	# Load and spawn treasure chest at this location
	var chest_script := load("res://scripts/world/TreasureChest.gd") as GDScript

	var chest := StaticBody2D.new()
	chest.global_position = global_position
	chest.collision_layer = 4

	# Chest body
	var chest_body := ColorRect.new()
	chest_body.name = "ChestBody"
	chest_body.position = Vector2(-14, -11)
	chest_body.size = Vector2(28, 18)
	chest_body.color = Color(0.6, 0.4, 0.15, 1)
	chest.add_child(chest_body)

	# Chest lid
	var lid := ColorRect.new()
	lid.name = "Lid"
	lid.position = Vector2(-16, -17)
	lid.size = Vector2(32, 8)
	lid.color = Color(0.7, 0.5, 0.2, 1)
	chest.add_child(lid)

	# Gold clasp
	var clasp := ColorRect.new()
	clasp.position = Vector2(-3, -13)
	clasp.size = Vector2(6, 5)
	clasp.color = Color(1, 0.85, 0.2, 1)
	chest.add_child(clasp)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 18)
	col.shape = shape
	chest.add_child(col)

	if chest_script:
		chest.set_script(chest_script)

	get_tree().current_scene.add_child(chest)
