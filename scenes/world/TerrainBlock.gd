extends StaticBody2D
## A single breakable terrain block (32x32). Part of the block-based terrain grid.
## Can be destroyed by player dig action. May contain treasure.
## Terraria-inspired visuals: depth-based types, grass tufts, underground darkening.

const BLOCK_SIZE := 32.0
const STONE_DEPTH := 6  # Rows below surface where stone begins
const DARKENING_START := 3  # Row where underground darkening begins
const MIN_BRIGHTNESS := 0.4  # Deepest blocks don't go fully black

var grid_x := 0
var grid_y := 0
var is_grass := false
var has_treasure := false
var is_cave := false  # Set by L2 generation for cave-themed tiles
var total_depth := 16  # Total underground rows, set by MainScene

func setup(gx: int, gy: int, p_is_grass: bool, p_has_treasure: bool = false) -> void:
	grid_x = gx
	grid_y = gy
	is_grass = p_is_grass
	has_treasure = p_has_treasure
	_build_visual()
	_apply_depth_darkening()

func _get_block_type() -> String:
	if is_grass:
		return "grass"
	if is_cave:
		return "cave"
	if grid_y >= STONE_DEPTH:
		return "stone"
	return "dirt"

func _build_visual() -> void:
	# Try sprite tile first
	var tile_path := ""
	if is_cave:
		if is_grass:
			tile_path = "res://assets/sprites/world/tile_cave_surface.png"
		else:
			tile_path = "res://assets/sprites/world/tile_cave_dirt.png"
	elif is_grass:
		tile_path = "res://assets/sprites/world/tile_grass.png"
	else:
		if grid_y >= STONE_DEPTH:
			tile_path = "res://assets/sprites/world/tile_deep.png"
		else:
			tile_path = "res://assets/sprites/world/tile_dirt.png"

	if tile_path != "" and ResourceLoader.exists(tile_path):
		var tex = load(tile_path) as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.name = "Visual"
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = true
			add_child(spr)
			if is_grass:
				_add_grass_tufts()
			if has_treasure:
				_add_sparkle()
			return

	# Fallback: ColorRect with Terraria-inspired depth variation
	var rect := ColorRect.new()
	rect.name = "Visual"
	rect.position = Vector2(-BLOCK_SIZE / 2.0, -BLOCK_SIZE / 2.0)
	rect.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)

	var block_type := _get_block_type()
	# Use grid_x + grid_y hash for deterministic per-block variation
	var hash_val := absi((grid_x * 2654435761 + grid_y * 340573321) % 1000)
	var shade := float(hash_val % 80) / 1000.0  # 0.0 to 0.08 variation

	match block_type:
		"grass":
			var green_var := float(hash_val % 60) / 1000.0
			rect.color = Color(0.32 + green_var, 0.65 + green_var * 0.5, 0.30 + green_var, 1)
		"dirt":
			# 3+ distinct shade variations using hash
			var dirt_variant := hash_val % 4
			match dirt_variant:
				0: rect.color = Color(0.50 + shade, 0.35 + shade, 0.20 + shade * 0.5, 1)
				1: rect.color = Color(0.48 + shade, 0.33 + shade, 0.22 + shade * 0.5, 1)
				2: rect.color = Color(0.52 + shade, 0.36 + shade, 0.18 + shade * 0.5, 1)
				3: rect.color = Color(0.46 + shade, 0.34 + shade, 0.24 + shade * 0.5, 1)
		"stone":
			# Grey stone palette — distinct from brown dirt
			var stone_variant := hash_val % 3
			match stone_variant:
				0: rect.color = Color(0.42 + shade, 0.42 + shade, 0.44 + shade, 1)
				1: rect.color = Color(0.38 + shade, 0.40 + shade, 0.42 + shade, 1)
				2: rect.color = Color(0.44 + shade, 0.43 + shade, 0.40 + shade, 1)
		"cave":
			rect.color = Color(0.32 + shade, 0.30 + shade, 0.38 + shade, 1)

	add_child(rect)

	# Border with varied opacity for natural grid feel
	var border := ColorRect.new()
	border.name = "Border"
	border.position = Vector2(-BLOCK_SIZE / 2.0, -BLOCK_SIZE / 2.0)
	border.size = Vector2(BLOCK_SIZE, 1)
	var border_opacity := 0.05 + float(hash_val % 60) / 1000.0  # 0.05 to 0.11
	border.color = Color(0, 0, 0, border_opacity)
	add_child(border)

	if is_grass:
		_add_grass_tufts()

	if has_treasure:
		_add_sparkle()

func _add_grass_tufts() -> void:
	## Terraria-style grass decorations on top of grass blocks
	var hash_val := absi((grid_x * 7919 + 13) % 1000)
	var tuft_count := 2 + (hash_val % 3)  # 2-4 tufts per block

	for i in tuft_count:
		var tuft_hash := absi((grid_x * 3571 + i * 997) % 1000)
		var tuft := ColorRect.new()
		var tuft_width := 2 + (tuft_hash % 3)  # 2-4px wide
		var tuft_height := 3 + (tuft_hash % 6)  # 3-8px tall
		var tuft_x := -BLOCK_SIZE / 2.0 + float(tuft_hash % int(BLOCK_SIZE - 4)) + 2
		tuft.position = Vector2(tuft_x, -BLOCK_SIZE / 2.0 - tuft_height)
		tuft.size = Vector2(tuft_width, tuft_height)
		# Slightly varied green shades per tuft
		var green_shift := float(tuft_hash % 100) / 500.0  # 0.0 to 0.2
		tuft.color = Color(0.25 + green_shift * 0.3, 0.55 + green_shift, 0.22 + green_shift * 0.2, 1)
		tuft.z_index = 1
		add_child(tuft)

func _add_sparkle() -> void:
	var sparkle := ColorRect.new()
	sparkle.name = "Sparkle"
	sparkle.position = Vector2(-2, -2)
	sparkle.size = Vector2(4, 4)
	sparkle.color = Color(1, 0.85, 0.2, 0.4)
	sparkle.z_index = 2  # Above darkening
	add_child(sparkle)

func _apply_depth_darkening() -> void:
	## Progressive underground darkening — Terraria-style light falloff
	if is_grass or grid_y < DARKENING_START:
		return  # Surface blocks stay bright
	var depth_ratio := float(grid_y - DARKENING_START) / float(maxi(total_depth - DARKENING_START, 1))
	depth_ratio = clampf(depth_ratio, 0.0, 1.0)
	var brightness := lerpf(1.0, MIN_BRIGHTNESS, depth_ratio)
	modulate = Color(brightness, brightness, brightness, 1.0)

func dig() -> void:
	## Called when a player digs this block. Destroys it with a small particle effect.
	_spawn_break_particles()
	# Dig sound feedback
	var sfx := get_node_or_null("/root/SoundFX")
	if sfx:
		sfx.play_dig(_get_block_type())

	if has_treasure:
		var sfx2 := get_node_or_null("/root/SoundFX")
		if sfx2:
			sfx2.play_treasure_found()
		_spawn_treasure()

	# Remove block
	queue_free()

func _spawn_break_particles() -> void:
	# Simple particle burst — a few small rects that fly out
	var parent_node := get_parent()
	if not parent_node:
		return

	for i in 4:
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position - Vector2(3, 3)
		var block_type := _get_block_type()
		match block_type:
			"grass": particle.color = Color(0.36, 0.68, 0.34, 0.8)
			"stone": particle.color = Color(0.42, 0.42, 0.44, 0.8)
			_: particle.color = Color(0.5, 0.35, 0.2, 0.8)
		particle.z_index = 5
		get_tree().current_scene.add_child(particle)

		var dir := Vector2(randf_range(-1, 1), randf_range(-1.5, -0.3)).normalized()
		var tween := particle.create_tween()
		tween.tween_property(particle, "position", particle.position + dir * randf_range(20, 50), 0.4)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(particle.queue_free)

func _spawn_treasure() -> void:
	# Load and spawn treasure chest at this location
	var chest_script := load("res://scenes/world/TreasureChest.gd") as GDScript

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
