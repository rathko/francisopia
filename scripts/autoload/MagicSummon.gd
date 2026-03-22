extends Node
## Magic Word Summoning System — spelling words brings things to life!
## When a word is spelled correctly, the thing it represents magically appears.

signal summon_started(word: String, summon_type: String)
signal summon_completed(word: String, summoned_node: Node)

const PET_SCENE_PATH := "res://scenes/world/Pet.tscn"

# Word → Summon registry. Each entry defines what happens when the word is spelled.
# summon_type: "pet", "world", "item", "cosmetic"
# builder: method name that creates the summoned thing
var summon_registry: Dictionary = {
	# CVC words (Level 1) — simple, delightful
	"cat": {"type": "pet", "builder": "_summon_cat", "label": "A cute cat!", "color": Color(0.95, 0.65, 0.25)},
	"dog": {"type": "pet", "builder": "_summon_dog", "label": "A friendly dog!", "color": Color(0.6, 0.4, 0.2)},
	"sun": {"type": "world", "builder": "_summon_sun", "label": "Sunshine!", "color": Color(1.0, 0.9, 0.2)},
	"hat": {"type": "cosmetic", "builder": "_summon_hat", "label": "A magic hat!", "color": Color(0.7, 0.2, 0.8)},
	"bed": {"type": "world", "builder": "_summon_bed", "label": "A cozy bed!", "color": Color(0.6, 0.5, 0.8)},
	"cup": {"type": "world", "builder": "_summon_cup", "label": "A golden cup!", "color": Color(1.0, 0.85, 0.2)},
	"bug": {"type": "pet", "builder": "_summon_bug", "label": "A friendly bug!", "color": Color(0.4, 0.8, 0.3)},
	"box": {"type": "world", "builder": "_summon_box", "label": "A mystery box!", "color": Color(0.7, 0.5, 0.2)},

	# Blends / harder (Level 2)
	"fish": {"type": "pet", "builder": "_summon_fish", "label": "A magic fish!", "color": Color(0.3, 0.7, 1.0)},
	"bird": {"type": "pet", "builder": "_summon_bird", "label": "A singing bird!", "color": Color(1.0, 0.6, 0.3)},
	"frog": {"type": "pet", "builder": "_summon_frog", "label": "A bouncy frog!", "color": Color(0.3, 0.8, 0.3)},
	"star": {"type": "world", "builder": "_summon_star", "label": "A glowing star!", "color": Color(1.0, 1.0, 0.5)},
	"tree": {"type": "world", "builder": "_summon_tree", "label": "A magic tree!", "color": Color(0.2, 0.7, 0.3)},
	"jump": {"type": "world", "builder": "_summon_trampoline", "label": "A trampoline!", "color": Color(1.0, 0.4, 0.6)},
	"leaf": {"type": "world", "builder": "_summon_leaves", "label": "Falling leaves!", "color": Color(0.8, 0.6, 0.2)},
	"hand": {"type": "world", "builder": "_summon_hand", "label": "A helping hand!", "color": Color(0.95, 0.82, 0.7)},
	"bow":  {"type": "item", "builder": "_summon_bow_upgrade", "label": "Bow upgraded!", "color": Color(0.8, 0.4, 0.2)},
	"hammer": {"type": "item", "builder": "_summon_hammer", "label": "Dig faster now!", "color": Color(0.6, 0.6, 0.65)},
	"house": {"type": "world", "builder": "_summon_house", "label": "A cozy house!", "color": Color(0.85, 0.55, 0.25)},

	# Long vowel / complex (Level 3+)
	"flower": {"type": "world", "builder": "_summon_flower_garden", "label": "A flower garden!", "color": Color(1.0, 0.5, 0.7)},
	"castle": {"type": "world", "builder": "_summon_castle", "label": "A tiny castle!", "color": Color(0.7, 0.7, 0.75)},
	"rainbow": {"type": "world", "builder": "_summon_rainbow", "label": "A rainbow!", "color": Color(1.0, 0.4, 0.4)},
}

var _pet_scene: PackedScene = null
var _summoned_entities: Array[Node] = []

func _ready() -> void:
	_pet_scene = load(PET_SCENE_PATH) as PackedScene
	WordEngine.word_spelled_correctly.connect(_on_word_spelled)

func _on_word_spelled(word: String) -> void:
	var entry: Dictionary = summon_registry.get(word, {})
	if entry.is_empty():
		# No summon registered — just give coins (fallback)
		return
	summon_started.emit(word, entry.get("type", "world"))
	_play_summon_animation(word, entry)

func _play_summon_animation(word: String, entry: Dictionary) -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return

	# Find the player who completed the word (use Player 1 as default)
	var player := scene_root.get_node_or_null("Player") as Node2D
	if not player:
		return
	var summon_pos := player.global_position + Vector2(0, -30)

	# === PHASE 1: Golden screen flash ===
	var flash := ColorRect.new()
	flash.z_index = 100
	flash.anchors_preset = 15  # Full rect
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.9, 0.3, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Need a CanvasLayer for screen-space flash
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 50
	scene_root.add_child(flash_layer)
	flash_layer.add_child(flash)

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.5, 0.15)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.4)
	flash_tween.tween_callback(flash_layer.queue_free)

	# === PHASE 2: Swirling letters float up ===
	var letters_container := Node2D.new()
	letters_container.z_index = 20
	scene_root.add_child(letters_container)

	var letter_nodes: Array[Label] = []
	for i in word.length():
		var letter_label := Label.new()
		letter_label.text = word[i].to_upper()
		letter_label.add_theme_font_size_override("font_size", 48)
		letter_label.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
		letter_label.position = summon_pos + Vector2(i * 40 - word.length() * 20, 0)
		letters_container.add_child(letter_label)
		letter_nodes.append(letter_label)

	# Animate letters swirling to center
	var swirl_tween := create_tween()
	swirl_tween.set_parallel(true)
	for i in letter_nodes.size():
		var letter_label := letter_nodes[i]
		var angle := TAU * float(i) / float(letter_nodes.size())
		var orbit_pos := summon_pos + Vector2(cos(angle), sin(angle)) * 60.0
		swirl_tween.tween_property(letter_label, "position", orbit_pos, 0.4).set_trans(Tween.TRANS_BACK)
	swirl_tween.chain().set_parallel(true)
	for letter_label in letter_nodes:
		swirl_tween.tween_property(letter_label, "position", summon_pos, 0.3).set_trans(Tween.TRANS_QUAD)
		swirl_tween.tween_property(letter_label, "modulate:a", 0.0, 0.3)
	swirl_tween.chain().tween_callback(letters_container.queue_free)

	# === PHASE 3: Sparkle particles at summon point (delayed) ===
	await get_tree().create_timer(0.6).timeout
	_spawn_sparkles(scene_root, summon_pos, entry.get("color", Color.WHITE))

	# === PHASE 4: Summon the thing! ===
	await get_tree().create_timer(0.3).timeout
	var builder_name: String = entry.get("builder", "")
	if builder_name != "" and has_method(builder_name):
		var summoned: Variant = call(builder_name, scene_root, player, summon_pos)
		if summoned is Node:
			_summoned_entities.append(summoned)
			summon_completed.emit(word, summoned)
			# Track in GameManager for persistence
			if word not in GameManager.items_owned:
				GameManager.items_owned.append(word)
			if word not in GameManager.words_summoned:
				GameManager.words_summoned.append(word)
			GameManager.save_game()

	# === PHASE 5: Big friendly label ===
	_show_summon_label(scene_root, summon_pos, entry)

func _spawn_sparkles(parent: Node, pos: Vector2, color: Color) -> void:
	for i in 12:
		var sparkle := ColorRect.new()
		sparkle.size = Vector2(6, 6)
		sparkle.color = color
		sparkle.z_index = 25
		sparkle.position = pos - Vector2(3, 3)
		parent.add_child(sparkle)

		var angle := TAU * float(i) / 12.0
		var dist := randf_range(30, 80)
		var target_pos := pos + Vector2(cos(angle), sin(angle)) * dist

		var tween := sparkle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position", target_pos, 0.5).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.6)
		tween.tween_property(sparkle, "scale", Vector2(0.1, 0.1), 0.6)
		tween.chain().tween_callback(sparkle.queue_free)

func _show_summon_label(parent: Node, pos: Vector2, entry: Dictionary) -> void:
	var label_text: String = entry.get("label", "Magic!")
	var color: Color = entry.get("color", Color.WHITE)

	var summon_label := Label.new()
	summon_label.text = label_text
	summon_label.add_theme_font_size_override("font_size", 48)
	summon_label.add_theme_color_override("font_color", color)
	summon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	summon_label.add_theme_constant_override("outline_size", 4)
	summon_label.z_index = 30
	summon_label.position = pos + Vector2(-label_text.length() * 12, -80)
	parent.add_child(summon_label)

	var label_tween := summon_label.create_tween()
	label_tween.tween_property(summon_label, "position:y", summon_label.position.y - 60, 1.5)
	label_tween.parallel().tween_property(summon_label, "scale", Vector2(1.2, 1.2), 0.3)
	label_tween.tween_property(summon_label, "scale", Vector2(1.0, 1.0), 0.2)
	label_tween.tween_property(summon_label, "modulate:a", 0.0, 0.8)
	label_tween.tween_callback(summon_label.queue_free)

# =================================================================
# SUMMON BUILDERS — each returns the created Node (or null)
# =================================================================

# --- PETS ---

func _summon_cat(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	if not _pet_scene:
		return null
	var pet := _pet_scene.instantiate() as CharacterBody2D
	# Spawn beside the player, not on their head
	pet.global_position = player.global_position + Vector2(-60, 0)
	scene_root.add_child(pet)
	if pet.has_method("setup"):
		pet.setup(player, 1)  # CAT type
	print("Francis-opia: A magical cat appeared!")
	return pet

func _summon_dog(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	if not _pet_scene:
		return null
	var pet := _pet_scene.instantiate() as CharacterBody2D
	# Spawn beside the player, not on their head
	pet.global_position = player.global_position + Vector2(60, 0)
	scene_root.add_child(pet)
	if pet.has_method("setup"):
		pet.setup(player, 0)  # DOG type
	print("Francis-opia: A magical dog appeared!")
	return pet

func _summon_frog(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Green bouncy frog — uses a simple ColorRect character
	var frog := CharacterBody2D.new()
	frog.global_position = pos
	frog.collision_layer = 0
	frog.collision_mask = 1

	# Body
	var body := ColorRect.new()
	body.position = Vector2(-10, -10)
	body.size = Vector2(20, 14)
	body.color = Color(0.3, 0.8, 0.3, 1)
	frog.add_child(body)

	# Eyes — big and round
	var eye_l := ColorRect.new()
	eye_l.position = Vector2(-8, -18)
	eye_l.size = Vector2(7, 7)
	eye_l.color = Color(1, 1, 1, 1)
	frog.add_child(eye_l)
	var pupil_l := ColorRect.new()
	pupil_l.position = Vector2(-6, -16)
	pupil_l.size = Vector2(3, 3)
	pupil_l.color = Color(0.1, 0.1, 0.1, 1)
	frog.add_child(pupil_l)

	var eye_r := ColorRect.new()
	eye_r.position = Vector2(1, -18)
	eye_r.size = Vector2(7, 7)
	eye_r.color = Color(1, 1, 1, 1)
	frog.add_child(eye_r)
	var pupil_r := ColorRect.new()
	pupil_r.position = Vector2(3, -16)
	pupil_r.size = Vector2(3, 3)
	pupil_r.color = Color(0.1, 0.1, 0.1, 1)
	frog.add_child(pupil_r)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 12)
	col.shape = shape
	frog.add_child(col)

	scene_root.add_child(frog)

	# Bouncing behavior via timer
	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.autostart = true
	frog.add_child(timer)

	var script := GDScript.new()
	script.source_code = """extends CharacterBody2D

var _owner: Node2D = null
var _gravity := 980.0

func _ready():
	var players = get_tree().get_nodes_in_group("")
	_owner = get_parent().get_node_or_null("Player")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += _gravity * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0
		velocity.x = move_toward(velocity.x, 0, 100 * delta)

	if _owner and is_instance_valid(_owner):
		var dist = global_position.distance_to(_owner.global_position)
		if dist > 400:
			global_position = _owner.global_position + Vector2(30, 0)

	move_and_slide()

func hop():
	if is_on_floor():
		velocity.y = -250
		if _owner and is_instance_valid(_owner):
			var dir = global_position.direction_to(_owner.global_position)
			velocity.x = dir.x * 80
"""
	script.reload()
	frog.set_script(script)
	frog._owner = player
	timer.timeout.connect(frog.hop)

	print("Francis-opia: ✨ A bouncy frog appeared! Ribbit!")
	return frog

func _summon_bug(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var bug := Node2D.new()
	bug.global_position = pos
	bug.z_index = 5

	# Small green body
	var body := ColorRect.new()
	body.position = Vector2(-5, -5)
	body.size = Vector2(10, 8)
	body.color = Color(0.4, 0.8, 0.3, 1)
	bug.add_child(body)

	# Wings
	var wing_l := ColorRect.new()
	wing_l.position = Vector2(-8, -9)
	wing_l.size = Vector2(6, 5)
	wing_l.color = Color(0.7, 0.9, 1.0, 0.5)
	bug.add_child(wing_l)
	var wing_r := ColorRect.new()
	wing_r.position = Vector2(2, -9)
	wing_r.size = Vector2(6, 5)
	wing_r.color = Color(0.7, 0.9, 1.0, 0.5)
	bug.add_child(wing_r)

	scene_root.add_child(bug)

	# Simple flying script
	var script := GDScript.new()
	script.source_code = """extends Node2D

var _owner: Node2D = null
var _time := 0.0

func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(sin(_time * 2) * 40, -50 + cos(_time * 3) * 15)
		global_position = global_position.lerp(target, delta * 3.0)
		if global_position.distance_to(_owner.global_position) > 400:
			global_position = _owner.global_position + Vector2(0, -50)
"""
	script.reload()
	bug.set_script(script)
	bug._owner = player

	print("Francis-opia: ✨ A friendly bug is buzzing around!")
	return bug

func _summon_fish(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Magic floating fish that swims through the air
	var fish := Node2D.new()
	fish.global_position = pos
	fish.z_index = 5

	var body := ColorRect.new()
	body.position = Vector2(-12, -5)
	body.size = Vector2(24, 10)
	body.color = Color(0.3, 0.7, 1.0, 1)
	fish.add_child(body)

	# Tail
	var tail := ColorRect.new()
	tail.position = Vector2(-18, -7)
	tail.size = Vector2(8, 14)
	tail.color = Color(0.2, 0.6, 0.9, 1)
	fish.add_child(tail)

	# Eye
	var eye := ColorRect.new()
	eye.position = Vector2(6, -4)
	eye.size = Vector2(4, 4)
	eye.color = Color(0.1, 0.1, 0.1, 1)
	fish.add_child(eye)

	scene_root.add_child(fish)

	var script := GDScript.new()
	script.source_code = """extends Node2D

var _owner: Node2D = null
var _time := 0.0

func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(cos(_time * 1.5) * 60, -40 + sin(_time * 2) * 20)
		global_position = global_position.lerp(target, delta * 2.5)
		scale.x = -1.0 if (target.x - global_position.x) < 0 else 1.0
		if global_position.distance_to(_owner.global_position) > 400:
			global_position = _owner.global_position + Vector2(0, -40)
"""
	script.reload()
	fish.set_script(script)
	fish._owner = player

	print("Francis-opia: ✨ A magic fish swims through the air!")
	return fish

func _summon_bird(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var bird := Node2D.new()
	bird.global_position = pos + Vector2(0, -80)
	bird.z_index = 5

	# Body
	var body := ColorRect.new()
	body.position = Vector2(-8, -5)
	body.size = Vector2(16, 10)
	body.color = Color(1.0, 0.6, 0.3, 1)
	bird.add_child(body)

	# Wing
	var wing := ColorRect.new()
	wing.name = "Wing"
	wing.position = Vector2(-6, -10)
	wing.size = Vector2(12, 6)
	wing.color = Color(0.9, 0.5, 0.2, 1)
	bird.add_child(wing)

	# Beak
	var beak := ColorRect.new()
	beak.position = Vector2(7, -3)
	beak.size = Vector2(5, 4)
	beak.color = Color(1.0, 0.8, 0.2, 1)
	bird.add_child(beak)

	scene_root.add_child(bird)

	var script := GDScript.new()
	script.source_code = """extends Node2D

var _owner: Node2D = null
var _time := 0.0

func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(sin(_time) * 80, -90 + sin(_time * 2.5) * 15)
		global_position = global_position.lerp(target, delta * 2.0)
		scale.x = -1.0 if (target.x - global_position.x) < 0 else 1.0
		# Wing flap
		var wing = get_node_or_null("Wing")
		if wing:
			wing.scale.y = 0.5 + abs(sin(_time * 8)) * 0.5
		if global_position.distance_to(_owner.global_position) > 500:
			global_position = _owner.global_position + Vector2(0, -90)
"""
	script.reload()
	bird.set_script(script)
	bird._owner = player

	print("Francis-opia: ✨ A singing bird flies overhead!")
	return bird

# --- WORLD EFFECTS ---

func _summon_sun(scene_root: Node, _player: Node2D, _pos: Vector2) -> Node:
	# Sun on its own CanvasLayer between sky (default layer 0, z_index -10)
	# and game objects. Layer 0 is the game world. We use a CanvasLayer
	# with follow_viewport so it stays fixed on screen but renders above sky.
	var sun_layer := CanvasLayer.new()
	sun_layer.name = "MagicSunLayer"
	# Layer 5: above game world (0), below HUD (10)
	sun_layer.layer = 5

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sun_layer.add_child(root_ctrl)

	# Bright yellow sun — top-right corner
	var cx := 1150.0
	var cy := 120.0

	# Outer glow
	var glow := ColorRect.new()
	glow.offset_left = cx - 60
	glow.offset_top = cy - 60
	glow.offset_right = cx + 60
	glow.offset_bottom = cy + 60
	glow.color = Color(1.0, 0.95, 0.4, 0.25)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(glow)

	# Sun body
	var sun_body := ColorRect.new()
	sun_body.offset_left = cx - 40
	sun_body.offset_top = cy - 40
	sun_body.offset_right = cx + 40
	sun_body.offset_bottom = cy + 40
	sun_body.color = Color(1.0, 0.9, 0.2, 0.95)
	sun_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(sun_body)

	# Bright core
	var core := ColorRect.new()
	core.offset_left = cx - 25
	core.offset_top = cy - 25
	core.offset_right = cx + 25
	core.offset_bottom = cy + 25
	core.color = Color(1.0, 1.0, 0.6, 1.0)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(core)

	# Rays
	for i in 8:
		var ray := ColorRect.new()
		var angle := TAU * float(i) / 8.0
		var rx := cx + cos(angle) * 55
		var ry := cy + sin(angle) * 55
		ray.offset_left = rx - 6
		ray.offset_top = ry - 2
		ray.offset_right = rx + 6
		ray.offset_bottom = ry + 2
		ray.rotation = angle
		ray.color = Color(1.0, 0.95, 0.4, 0.7)
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(ray)

	scene_root.add_child(sun_layer)

	# Fade in
	root_ctrl.modulate.a = 0.0
	var tween := root_ctrl.create_tween()
	tween.tween_property(root_ctrl, "modulate:a", 1.0, 0.8)

	print("Francis-opia: The sun shines brightly!")
	return sun_layer

func _summon_tree(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var tree := Node2D.new()
	tree.global_position = Vector2(pos.x, 725)  # On ground

	# Big magical trunk
	var trunk := ColorRect.new()
	trunk.position = Vector2(-14, -140)
	trunk.size = Vector2(28, 140)
	trunk.color = Color(0.45, 0.3, 0.15, 1)
	tree.add_child(trunk)

	# Large magical canopy — glowing green
	var canopy := ColorRect.new()
	canopy.position = Vector2(-60, -220)
	canopy.size = Vector2(120, 90)
	canopy.color = Color(0.15, 0.7, 0.25, 1)
	tree.add_child(canopy)

	# Second canopy layer
	var canopy2 := ColorRect.new()
	canopy2.position = Vector2(-45, -250)
	canopy2.size = Vector2(90, 50)
	canopy2.color = Color(0.2, 0.75, 0.3, 1)
	tree.add_child(canopy2)

	# Sparkle leaves
	for i in 6:
		var leaf := ColorRect.new()
		leaf.position = Vector2(randf_range(-50, 50), randf_range(-240, -150))
		leaf.size = Vector2(8, 8)
		leaf.color = Color(0.4, 1.0, 0.5, 0.7)
		tree.add_child(leaf)

	scene_root.add_child(tree)

	# Growth animation
	tree.scale = Vector2(0.1, 0.1)
	var tween := tree.create_tween()
	tween.tween_property(tree, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	print("Francis-opia: ✨ A magnificent magic tree grew!")
	return tree

func _summon_flower_garden(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var garden := Node2D.new()
	garden.global_position = Vector2(pos.x, 725)

	var flower_colors := [
		Color(1, 0.3, 0.5), Color(1, 0.85, 0.2), Color(0.7, 0.3, 1),
		Color(1, 0.5, 0.7), Color(0.5, 0.7, 1), Color(1, 0.6, 0.2)
	]

	for i in 10:
		var flower := Node2D.new()
		var fx := randf_range(-80, 80)
		flower.position = Vector2(fx, 0)
		garden.add_child(flower)

		# Stem
		var stem := ColorRect.new()
		stem.position = Vector2(-2, -25)
		stem.size = Vector2(4, 25)
		stem.color = Color(0.3, 0.6, 0.2, 1)
		flower.add_child(stem)

		# Petals
		var petal := ColorRect.new()
		petal.position = Vector2(-8, -35)
		petal.size = Vector2(16, 12)
		petal.color = flower_colors[randi() % flower_colors.size()]
		flower.add_child(petal)

		# Center
		var center := ColorRect.new()
		center.position = Vector2(-3, -32)
		center.size = Vector2(6, 6)
		center.color = Color(1, 0.9, 0.3, 1)
		flower.add_child(center)

		# Pop-in animation
		flower.scale = Vector2.ZERO
		var tween := flower.create_tween()
		tween.tween_interval(i * 0.08)
		tween.tween_property(flower, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK)

	scene_root.add_child(garden)
	print("Francis-opia: ✨ A beautiful flower garden bloomed!")
	return garden

func _summon_star(scene_root: Node, _player: Node2D, pos: Vector2) -> Node:
	var star := Node2D.new()
	star.global_position = Vector2(pos.x, 80)
	star.z_index = -6

	# Glowing star body
	var glow := ColorRect.new()
	glow.position = Vector2(-20, -20)
	glow.size = Vector2(40, 40)
	glow.color = Color(1, 1, 0.5, 0.3)
	star.add_child(glow)

	var core := ColorRect.new()
	core.position = Vector2(-10, -10)
	core.size = Vector2(20, 20)
	core.color = Color(1, 1, 0.7, 0.9)
	star.add_child(core)

	var center := ColorRect.new()
	center.position = Vector2(-5, -5)
	center.size = Vector2(10, 10)
	center.color = Color(1, 1, 1, 1)
	star.add_child(center)

	scene_root.add_child(star)

	# Twinkling
	var script := GDScript.new()
	script.source_code = """extends Node2D
var _time := 0.0
func _process(delta):
	_time += delta
	modulate.a = 0.7 + sin(_time * 3.0) * 0.3
"""
	script.reload()
	star.set_script(script)

	print("Francis-opia: ✨ A glowing star lights up the sky!")
	return star

func _summon_rainbow(scene_root: Node, _player: Node2D, pos: Vector2) -> Node:
	# Rainbow in the game world — scrolls with everything else
	var rainbow := Node2D.new()
	rainbow.name = "MagicRainbow"
	rainbow.global_position = Vector2(pos.x, 200)
	rainbow.z_index = -7

	var colors: Array[Color] = [
		Color(1, 0.2, 0.2, 0.55),    # Red
		Color(1, 0.6, 0.2, 0.55),    # Orange
		Color(1, 1, 0.2, 0.55),      # Yellow
		Color(0.2, 0.8, 0.2, 0.55),  # Green
		Color(0.2, 0.5, 1, 0.55),    # Blue
		Color(0.5, 0.2, 0.8, 0.55),  # Indigo
		Color(0.7, 0.3, 1, 0.55),    # Violet
	]

	# Big arc in the sky
	for band_idx in colors.size():
		var band_color: Color = colors[band_idx]
		var radius := 350.0 - band_idx * 16.0
		for seg in 30:
			var angle := PI * float(seg) / 30.0
			var rect := ColorRect.new()
			rect.position = Vector2(cos(angle) * radius - 7, -sin(angle) * radius - 7)
			rect.size = Vector2(14, 14)
			rect.color = band_color
			rainbow.add_child(rect)

	scene_root.add_child(rainbow)

	# Fade in
	rainbow.modulate.a = 0.0
	var tween := rainbow.create_tween()
	tween.tween_property(rainbow, "modulate:a", 1.0, 1.5)

	print("Francis-opia: A beautiful rainbow stretches across the sky!")
	return rainbow

func _summon_bed(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var bed := Node2D.new()
	bed.global_position = Vector2(pos.x + 60, 725)

	var mattress := ColorRect.new()
	mattress.position = Vector2(-20, -16)
	mattress.size = Vector2(50, 16)
	mattress.color = Color(0.6, 0.4, 0.8, 1)
	bed.add_child(mattress)

	var pillow := ColorRect.new()
	pillow.position = Vector2(-20, -22)
	pillow.size = Vector2(16, 8)
	pillow.color = Color(1, 1, 1, 0.9)
	bed.add_child(pillow)

	var frame := ColorRect.new()
	frame.position = Vector2(-24, -4)
	frame.size = Vector2(58, 6)
	frame.color = Color(0.45, 0.3, 0.15, 1)
	bed.add_child(frame)

	scene_root.add_child(bed)
	print("Francis-opia: ✨ A cozy bed appeared!")
	return bed

func _summon_cup(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var cup := Node2D.new()
	cup.global_position = Vector2(pos.x + 40, 725)

	var body := ColorRect.new()
	body.position = Vector2(-10, -22)
	body.size = Vector2(20, 22)
	body.color = Color(1.0, 0.85, 0.2, 1)
	cup.add_child(body)

	var handle := ColorRect.new()
	handle.position = Vector2(10, -18)
	handle.size = Vector2(6, 12)
	handle.color = Color(0.9, 0.75, 0.15, 1)
	cup.add_child(handle)

	scene_root.add_child(cup)
	print("Francis-opia: ✨ A golden cup appeared!")
	return cup

func _summon_box(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var box := Node2D.new()
	box.global_position = Vector2(pos.x + 50, 725)

	var body := ColorRect.new()
	body.position = Vector2(-16, -20)
	body.size = Vector2(32, 20)
	body.color = Color(0.7, 0.5, 0.2, 1)
	box.add_child(body)

	var lid := ColorRect.new()
	lid.position = Vector2(-18, -26)
	lid.size = Vector2(36, 8)
	lid.color = Color(0.8, 0.6, 0.25, 1)
	box.add_child(lid)

	var qmark := Label.new()
	qmark.text = "?"
	qmark.add_theme_font_size_override("font_size", 24)
	qmark.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	qmark.position = Vector2(-6, -22)
	box.add_child(qmark)

	scene_root.add_child(box)
	print("Francis-opia: ✨ A mystery box appeared!")
	return box

func _summon_trampoline(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var tramp := StaticBody2D.new()
	tramp.global_position = Vector2(pos.x, 725)

	var base := ColorRect.new()
	base.position = Vector2(-30, -8)
	base.size = Vector2(60, 8)
	base.color = Color(0.5, 0.5, 0.55, 1)
	tramp.add_child(base)

	var surface := ColorRect.new()
	surface.position = Vector2(-28, -14)
	surface.size = Vector2(56, 6)
	surface.color = Color(1.0, 0.4, 0.6, 1)
	tramp.add_child(surface)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 6)
	col.position = Vector2(0, -11)
	col.shape = shape
	tramp.add_child(col)

	scene_root.add_child(tramp)
	print("Francis-opia: ✨ A bouncy trampoline appeared! Jump on it!")
	return tramp

func _summon_leaves(scene_root: Node, _player: Node2D, pos: Vector2) -> Node:
	var leaves := Node2D.new()
	leaves.global_position = pos
	leaves.z_index = 5

	var leaf_colors := [Color(0.8, 0.5, 0.1), Color(0.9, 0.6, 0.15), Color(0.7, 0.4, 0.1), Color(0.85, 0.7, 0.2)]

	for i in 15:
		var leaf := ColorRect.new()
		leaf.size = Vector2(8, 6)
		leaf.color = leaf_colors[randi() % leaf_colors.size()]
		leaf.position = Vector2(randf_range(-100, 100), randf_range(-150, -50))
		leaves.add_child(leaf)

		var tween := leaf.create_tween().set_loops()
		tween.tween_property(leaf, "position:y", leaf.position.y + 200, randf_range(3, 6))
		tween.tween_property(leaf, "position:y", leaf.position.y, 0)

	scene_root.add_child(leaves)
	print("Francis-opia: ✨ Autumn leaves are falling!")
	return leaves

func _summon_hand(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# A platform shaped like a hand — helps reach high places
	var hand := StaticBody2D.new()
	hand.global_position = Vector2(pos.x, pos.y - 100)

	var palm := ColorRect.new()
	palm.position = Vector2(-25, -10)
	palm.size = Vector2(50, 20)
	palm.color = Color(0.95, 0.82, 0.7, 1)
	hand.add_child(palm)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, 10)
	col.shape = shape
	hand.add_child(col)

	scene_root.add_child(hand)
	print("Francis-opia: ✨ A helping hand appeared! Use it as a platform!")
	return hand

func _summon_castle(scene_root: Node, _player: Node2D, pos: Vector2) -> Node:
	var castle := Node2D.new()
	castle.global_position = Vector2(pos.x, 725)

	# Main wall
	var wall := ColorRect.new()
	wall.position = Vector2(-40, -80)
	wall.size = Vector2(80, 80)
	wall.color = Color(0.7, 0.7, 0.75, 1)
	castle.add_child(wall)

	# Left tower
	var tower_l := ColorRect.new()
	tower_l.position = Vector2(-50, -110)
	tower_l.size = Vector2(22, 110)
	tower_l.color = Color(0.65, 0.65, 0.7, 1)
	castle.add_child(tower_l)

	# Right tower
	var tower_r := ColorRect.new()
	tower_r.position = Vector2(28, -110)
	tower_r.size = Vector2(22, 110)
	tower_r.color = Color(0.65, 0.65, 0.7, 1)
	castle.add_child(tower_r)

	# Battlements
	for i in 4:
		var b := ColorRect.new()
		b.position = Vector2(-35 + i * 20, -90)
		b.size = Vector2(12, 10)
		b.color = Color(0.7, 0.7, 0.75, 1)
		castle.add_child(b)

	# Door
	var door := ColorRect.new()
	door.position = Vector2(-10, -30)
	door.size = Vector2(20, 30)
	door.color = Color(0.4, 0.25, 0.12, 1)
	castle.add_child(door)

	# Flag
	var pole := ColorRect.new()
	pole.position = Vector2(-2, -130)
	pole.size = Vector2(3, 30)
	pole.color = Color(0.5, 0.5, 0.55, 1)
	castle.add_child(pole)

	var flag := ColorRect.new()
	flag.position = Vector2(1, -130)
	flag.size = Vector2(16, 10)
	flag.color = Color(1, 0.2, 0.2, 1)
	castle.add_child(flag)

	scene_root.add_child(castle)

	castle.scale = Vector2(0.1, 0.1)
	var tween := castle.create_tween()
	tween.tween_property(castle, "scale", Vector2(1, 1), 0.8).set_trans(Tween.TRANS_BACK)

	print("Francis-opia: ✨ A tiny castle appeared!")
	return castle

# --- ITEMS / COSMETICS ---

func _summon_hat(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Add a hat to the player visually
	var hat := ColorRect.new()
	hat.name = "MagicHat"
	hat.position = Vector2(-14, -48)
	hat.size = Vector2(28, 12)
	hat.color = Color(0.7, 0.2, 0.8, 1)
	player.add_child(hat)

	var hat_top := ColorRect.new()
	hat_top.position = Vector2(-8, -60)
	hat_top.size = Vector2(16, 14)
	hat_top.color = Color(0.6, 0.15, 0.7, 1)
	player.add_child(hat_top)

	# Band
	var band := ColorRect.new()
	band.position = Vector2(-8, -50)
	band.size = Vector2(16, 3)
	band.color = Color(1, 0.85, 0.2, 1)
	player.add_child(band)

	print("Francis-opia: ✨ You got a magic hat!")
	return hat

func _summon_bow_upgrade(scene_root: Node, _player: Node2D, _pos: Vector2) -> Node:
	# Grant the bow weapon to the player via WeaponHolder
	var player := scene_root.get_node_or_null("Player") as Node2D
	if player:
		var weapon_holder := player.get_node_or_null("WeaponHolder")
		if weapon_holder and weapon_holder.has_method("grant_weapon"):
			weapon_holder.grant_weapon("BowWeapon")
			print("Francis-opia: ✨ You got a bow! Press RB/R to equip it, RT to shoot!")
			return weapon_holder
	print("Francis-opia: ✨ Bow unlocked!")
	return null

func _summon_hammer(scene_root: Node, _player: Node2D, pos: Vector2) -> Node:
	# Grant the hammer — doubles dig speed, extends reach, shows visual
	var player := scene_root.get_node_or_null("Player") as Node2D
	if player:
		player.dig_cooldown = 0.1  # Was 0.25, now much faster
		player.dig_range = 128.0    # Was 96, now 4 blocks reach
		GameManager.equipped_weapon = "hammer"

		# Add a visible hammer next to the player
		var hammer_visual := Node2D.new()
		hammer_visual.name = "HammerVisual"
		# Remove old one if re-summoned
		var old := player.get_node_or_null("HammerVisual")
		if old:
			old.queue_free()

		# Handle (brown stick)
		var handle := ColorRect.new()
		handle.position = Vector2(14, -8)
		handle.size = Vector2(4, 20)
		handle.color = Color(0.55, 0.35, 0.15, 1)
		hammer_visual.add_child(handle)
		# Head (grey metal)
		var head := ColorRect.new()
		head.position = Vector2(10, -14)
		head.size = Vector2(12, 10)
		head.color = Color(0.6, 0.6, 0.65, 1)
		hammer_visual.add_child(head)

		player.add_child(hammer_visual)
		print("Francis-opia: ✨ Hammer! Hold Q/LB to dig faster and further!")
	return null

func _summon_house(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var house := Node2D.new()
	house.global_position = Vector2(pos.x, 725)  # Place on ground

	# Foundation
	var foundation := ColorRect.new()
	foundation.position = Vector2(-55, -8)
	foundation.size = Vector2(110, 8)
	foundation.color = Color(0.5, 0.45, 0.4, 1)
	house.add_child(foundation)

	# Main walls
	var walls := ColorRect.new()
	walls.position = Vector2(-50, -75)
	walls.size = Vector2(100, 75)
	walls.color = Color(0.9, 0.75, 0.5, 1)  # Warm wood color
	house.add_child(walls)

	# Roof (two angled pieces approximated as rects)
	var roof_left := ColorRect.new()
	roof_left.position = Vector2(-58, -100)
	roof_left.size = Vector2(62, 28)
	roof_left.color = Color(0.7, 0.25, 0.15, 1)  # Red-brown roof
	house.add_child(roof_left)

	var roof_right := ColorRect.new()
	roof_right.position = Vector2(-2, -100)
	roof_right.size = Vector2(62, 28)
	roof_right.color = Color(0.65, 0.22, 0.12, 1)
	house.add_child(roof_right)

	# Roof peak
	var peak := ColorRect.new()
	peak.position = Vector2(-10, -110)
	peak.size = Vector2(20, 12)
	peak.color = Color(0.75, 0.28, 0.15, 1)
	house.add_child(peak)

	# Chimney
	var chimney := ColorRect.new()
	chimney.position = Vector2(25, -120)
	chimney.size = Vector2(14, 25)
	chimney.color = Color(0.55, 0.4, 0.35, 1)
	house.add_child(chimney)

	# Smoke puffs from chimney
	for i in 3:
		var smoke := ColorRect.new()
		smoke.position = Vector2(28, -125 - i * 12)
		smoke.size = Vector2(8 + i * 3, 8 + i * 2)
		smoke.color = Color(0.85, 0.85, 0.85, 0.3 - i * 0.08)
		house.add_child(smoke)

	# Door
	var door := ColorRect.new()
	door.position = Vector2(-12, -40)
	door.size = Vector2(24, 40)
	door.color = Color(0.45, 0.28, 0.12, 1)
	house.add_child(door)

	# Doorknob
	var knob := ColorRect.new()
	knob.position = Vector2(7, -22)
	knob.size = Vector2(4, 4)
	knob.color = Color(1.0, 0.85, 0.2, 1)
	house.add_child(knob)

	# Windows (2, with warm light)
	for wx in [-1, 1]:
		var win_x := wx * 28 - 9
		# Window frame
		var frame := ColorRect.new()
		frame.position = Vector2(win_x - 2, -62)
		frame.size = Vector2(22, 22)
		frame.color = Color(0.4, 0.25, 0.12, 1)
		house.add_child(frame)
		# Window glass (warm glow)
		var glass := ColorRect.new()
		glass.position = Vector2(win_x, -60)
		glass.size = Vector2(18, 18)
		glass.color = Color(1.0, 0.9, 0.5, 0.8)
		house.add_child(glass)
		# Window cross
		var cross_h := ColorRect.new()
		cross_h.position = Vector2(win_x, -51.5)
		cross_h.size = Vector2(18, 2)
		cross_h.color = Color(0.4, 0.25, 0.12, 1)
		house.add_child(cross_h)
		var cross_v := ColorRect.new()
		cross_v.position = Vector2(win_x + 8, -60)
		cross_v.size = Vector2(2, 18)
		cross_v.color = Color(0.4, 0.25, 0.12, 1)
		house.add_child(cross_v)

	# Flower box under left window
	var flower_box := ColorRect.new()
	flower_box.position = Vector2(-39, -40)
	flower_box.size = Vector2(22, 6)
	flower_box.color = Color(0.45, 0.3, 0.15, 1)
	house.add_child(flower_box)
	# Tiny flowers
	for f in 3:
		var fl := ColorRect.new()
		fl.position = Vector2(-36 + f * 7, -46)
		fl.size = Vector2(5, 6)
		fl.color = [Color(1, 0.4, 0.5), Color(1, 0.85, 0.2), Color(0.7, 0.4, 1)][f]
		house.add_child(fl)

	# Welcome mat
	var mat := ColorRect.new()
	mat.position = Vector2(-16, -2)
	mat.size = Vector2(32, 4)
	mat.color = Color(0.6, 0.3, 0.3, 1)
	house.add_child(mat)

	# Warm ground glow
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(-60, -8)
	glow.size = Vector2(120, 16)
	glow.color = Color(1.0, 0.9, 0.5, 0.08)
	house.add_child(glow)

	scene_root.add_child(house)

	# Pop-in animation
	house.scale = Vector2(0.1, 0.1)
	var tween := house.create_tween()
	tween.tween_property(house, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(house, "scale", Vector2(1.0, 1.0), 0.2)

	print("Francis-opia: ✨ A cozy house appeared! Home sweet home!")
	return house

# --- HELPER: Get hint shape for HUD ---

func get_hint_color_for_word(word: String) -> Color:
	var entry: Dictionary = summon_registry.get(word.to_lower(), {})
	return entry.get("color", Color.WHITE)

func get_hint_label_for_word(word: String) -> String:
	var entry: Dictionary = summon_registry.get(word.to_lower(), {})
	return entry.get("label", "Something magical!")

func get_summon_type_for_word(word: String) -> String:
	var entry: Dictionary = summon_registry.get(word.to_lower(), {})
	return entry.get("type", "")
