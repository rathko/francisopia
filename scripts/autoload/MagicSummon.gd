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
	# === LEVEL 1: CVC words ===
	# Companions
	"cat": {"type": "pet", "builder": "_summon_cat", "label": "A cute cat!", "color": Color(0.95, 0.65, 0.25)},
	"dog": {"type": "pet", "builder": "_summon_dog", "label": "A friendly dog!", "color": Color(0.6, 0.4, 0.2)},
	"bug": {"type": "pet", "builder": "_summon_bug", "label": "A friendly bug!", "color": Color(0.4, 0.8, 0.3)},
	"hen": {"type": "pet", "builder": "_summon_hen", "label": "A clucky hen!", "color": Color(0.85, 0.6, 0.35)},
	"pig": {"type": "pet", "builder": "_summon_pig", "label": "A cute pig!", "color": Color(1.0, 0.65, 0.7)},
	"bat": {"type": "pet", "builder": "_summon_bat", "label": "A friendly bat!", "color": Color(0.4, 0.3, 0.5)},
	"rat": {"type": "pet", "builder": "_summon_rat", "label": "A cheeky rat!", "color": Color(0.5, 0.45, 0.4)},
	"fox": {"type": "pet", "builder": "_summon_fox", "label": "A clever fox!", "color": Color(0.9, 0.5, 0.15)},
	"pup": {"type": "pet", "builder": "_summon_pup", "label": "A bouncy puppy!", "color": Color(0.7, 0.5, 0.3)},
	# Cosmetics
	"hat": {"type": "cosmetic", "builder": "_summon_hat", "label": "A magic hat!", "color": Color(0.7, 0.2, 0.8)},
	"cap": {"type": "cosmetic", "builder": "_summon_cap", "label": "Cool cap!", "color": Color(0.2, 0.5, 0.9)},
	"wig": {"type": "cosmetic", "builder": "_summon_wig", "label": "Funny wig!", "color": Color(1.0, 0.4, 0.8)},
	"lip": {"type": "cosmetic", "builder": "_summon_lip", "label": "Silly lips!", "color": Color(1.0, 0.3, 0.4)},
	"big": {"type": "cosmetic", "builder": "_summon_big", "label": "SUPER SIZE!", "color": Color(1.0, 0.5, 0.2), "temporary": true},
	# Power-ups (temporary — timed buffs, not saved across sessions)
	"run": {"type": "cosmetic", "builder": "_summon_run", "label": "SUPER SPEED!", "color": Color(1.0, 0.9, 0.2), "temporary": true},
	"hop": {"type": "cosmetic", "builder": "_summon_hop", "label": "SUPER JUMP!", "color": Color(0.5, 1.0, 0.5), "temporary": true},
	"zip": {"type": "cosmetic", "builder": "_summon_zip", "label": "ZIP DASH!", "color": Color(0.3, 0.8, 1.0), "temporary": true},
	"dig": {"type": "cosmetic", "builder": "_summon_dig", "label": "DIG POWER!", "color": Color(0.6, 0.4, 0.2), "temporary": true},
	"fan": {"type": "cosmetic", "builder": "_summon_fan", "label": "Whoooosh!", "color": Color(0.7, 0.9, 1.0), "temporary": true},
	"leg": {"type": "cosmetic", "builder": "_summon_leg", "label": "Fast legs!", "color": Color(0.9, 0.7, 0.5), "temporary": true},
	"hug": {"type": "cosmetic", "builder": "_summon_hug", "label": "Big hug!", "color": Color(1.0, 0.5, 0.6), "temporary": true},
	# Anti-thief (temporary — one-shot effects)
	"net": {"type": "cosmetic", "builder": "_summon_net", "label": "Caught one!", "color": Color(0.6, 0.8, 0.4), "temporary": true},
	"web": {"type": "cosmetic", "builder": "_summon_web", "label": "Sticky web!", "color": Color(0.9, 0.9, 0.95), "temporary": true},
	"jam": {"type": "cosmetic", "builder": "_summon_jam", "label": "Sticky jam!", "color": Color(0.8, 0.2, 0.3), "temporary": true},
	"fog": {"type": "cosmetic", "builder": "_summon_fog", "label": "Thick fog!", "color": Color(0.8, 0.8, 0.85), "temporary": true},
	# Ground effects (temporary — timed visual/physics effects)
	"red": {"type": "cosmetic", "builder": "_summon_red", "label": "Everything is RED!", "color": Color(1.0, 0.2, 0.2), "temporary": true},
	"mud": {"type": "cosmetic", "builder": "_summon_mud", "label": "So slippery!", "color": Color(0.5, 0.35, 0.2), "temporary": true},
	"hot": {"type": "cosmetic", "builder": "_summon_hot", "label": "So hot!", "color": Color(1.0, 0.5, 0.1), "temporary": true},
	"wet": {"type": "cosmetic", "builder": "_summon_wet", "label": "Rain!", "color": Color(0.5, 0.7, 1.0), "temporary": true},
	"mix": {"type": "cosmetic", "builder": "_summon_mix", "label": "Color mix!", "color": Color(0.8, 0.4, 1.0), "temporary": true},
	"mop": {"type": "cosmetic", "builder": "_summon_mop", "label": "All clean!", "color": Color(0.6, 0.85, 1.0), "temporary": true},
	# Coin rewards
	"gem": {"type": "cosmetic", "builder": "_summon_gem", "label": "A shiny gem!", "color": Color(0.4, 0.8, 1.0)},
	"pot": {"type": "cosmetic", "builder": "_summon_pot", "label": "Pot of gold!", "color": Color(1.0, 0.85, 0.2)},
	"bag": {"type": "cosmetic", "builder": "_summon_bag", "label": "Coin bag!", "color": Color(0.7, 0.5, 0.25)},
	"six": {"type": "cosmetic", "builder": "_summon_six", "label": "Six coins!", "color": Color(1.0, 0.85, 0.2)},
	"ten": {"type": "cosmetic", "builder": "_summon_ten", "label": "Ten coins!", "color": Color(1.0, 0.9, 0.3)},
	"nut": {"type": "cosmetic", "builder": "_summon_nut", "label": "A squirrel!", "color": Color(0.6, 0.45, 0.2)},
	"bun": {"type": "cosmetic", "builder": "_summon_bun", "label": "A tasty bun!", "color": Color(0.85, 0.65, 0.3)},
	"gum": {"type": "cosmetic", "builder": "_summon_gum", "label": "Bubble gum!", "color": Color(1.0, 0.5, 0.7)},
	# World objects
	"sun": {"type": "world", "builder": "_summon_sun", "label": "Sunshine!", "color": Color(1.0, 0.9, 0.2)},
	"bed": {"type": "world", "builder": "_summon_bed", "label": "A cozy bed!", "color": Color(0.6, 0.5, 0.8)},
	"cup": {"type": "world", "builder": "_summon_cup", "label": "A golden cup!", "color": Color(1.0, 0.85, 0.2)},
	"box": {"type": "world", "builder": "_summon_box", "label": "A mystery box!", "color": Color(0.7, 0.5, 0.2)},
	"log": {"type": "world", "builder": "_summon_log", "label": "A log bridge!", "color": Color(0.5, 0.35, 0.15)},
	"mat": {"type": "world", "builder": "_summon_mat", "label": "Bouncy mat!", "color": Color(0.9, 0.3, 0.5)},
	"van": {"type": "world", "builder": "_summon_van", "label": "A fun van!", "color": Color(0.3, 0.6, 0.9)},
	"hut": {"type": "world", "builder": "_summon_hut", "label": "A tiny hut!", "color": Color(0.6, 0.45, 0.2)},
	"tub": {"type": "world", "builder": "_summon_tub", "label": "Bubble bath!", "color": Color(0.6, 0.8, 1.0)},
	"bin": {"type": "cosmetic", "builder": "_summon_bin", "label": "Letter bin!", "color": Color(0.3, 0.7, 0.3)},
	"cot": {"type": "world", "builder": "_summon_cot", "label": "A baby cot!", "color": Color(0.85, 0.75, 0.6)},
	"pen": {"type": "world", "builder": "_summon_pen", "label": "A fence!", "color": Color(0.55, 0.4, 0.2)},
	"jug": {"type": "world", "builder": "_summon_jug", "label": "A jug of water!", "color": Color(0.4, 0.65, 0.85)},
	"pan": {"type": "cosmetic", "builder": "_summon_pan", "label": "Frying pan!", "color": Color(0.45, 0.45, 0.5)},
	# Simple/visual effects
	"dot": {"type": "cosmetic", "builder": "_summon_dot", "label": "Confetti!", "color": Color(1.0, 0.6, 0.2)},
	"can": {"type": "cosmetic", "builder": "_summon_can", "label": "Kick the can!", "color": Color(0.6, 0.6, 0.65)},
	"map": {"type": "cosmetic", "builder": "_summon_map", "label": "Treasure nearby!", "color": Color(0.85, 0.7, 0.4)},
	"pin": {"type": "cosmetic", "builder": "_summon_pin", "label": "Marker placed!", "color": Color(1.0, 0.3, 0.3)},
	"bit": {"type": "cosmetic", "builder": "_summon_bit", "label": "8-BIT MODE!", "color": Color(0.3, 1.0, 0.3)},
	"fin": {"type": "cosmetic", "builder": "_summon_fin", "label": "Shark!", "color": Color(0.5, 0.55, 0.6)},
	"sit": {"type": "cosmetic", "builder": "_summon_sit", "label": "Rest time!", "color": Color(0.7, 0.8, 0.5)},
	"hit": {"type": "cosmetic", "builder": "_summon_hit", "label": "BOOM!", "color": Color(1.0, 0.8, 0.2)},
	"men": {"type": "cosmetic", "builder": "_summon_men", "label": "Dance party!", "color": Color(0.5, 0.7, 1.0)},
	"bus": {"type": "cosmetic", "builder": "_summon_bus", "label": "Beep beep!", "color": Color(1.0, 0.8, 0.1)},

	# === LEVEL 2: Blends / digraphs ===
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
	"portal": {"type": "world", "builder": "_summon_portal_unlock", "label": "Portals unlocked!", "color": Color(0.6, 0.2, 0.9)},
	"zap": {"type": "world", "builder": "_summon_portal_unlock", "label": "Zap! Teleport!", "color": Color(0.6, 0.2, 0.9)},

	# === LEVEL 3+: Long vowels / complex ===
	"flower": {"type": "world", "builder": "_summon_flower_garden", "label": "A flower garden!", "color": Color(1.0, 0.5, 0.7)},
	"castle": {"type": "world", "builder": "_summon_castle", "label": "A tiny castle!", "color": Color(0.7, 0.7, 0.75)},
	"rainbow": {"type": "world", "builder": "_summon_rainbow", "label": "A rainbow!", "color": Color(1.0, 0.4, 0.4)},
}

const MAX_COMPANIONS := 5
const PET_WORDS := ["dog", "cat", "frog", "pig", "bug", "fish", "bird", "hen", "bat", "rat", "fox", "pup"]

var _pet_scene: PackedScene = null
var _summoned_entities: Array[Node] = []
# Companion tracking: word -> node. Only the active companion follows the player.
var _companions: Dictionary = {}  # "dog" -> Node, "cat" -> Node, etc.
var _home_node: Node = null  # Reference to the house node

func _ready() -> void:
	_pet_scene = load(PET_SCENE_PATH) as PackedScene
	WordEngine.word_spelled_correctly.connect(_on_word_spelled)

func get_companion_count() -> int:
	var count := 0
	for word in _companions:
		if is_instance_valid(_companions[word]):
			count += 1
	return count

func is_companion_word(word: String) -> bool:
	return word in PET_WORDS

func is_temporary_effect(word: String) -> bool:
	var entry: Dictionary = summon_registry.get(word.to_lower(), {})
	return entry.get("temporary", false)

func register_companion(word: String, node: Node, player: Node2D, auto_activate: bool = true) -> void:
	_companions[word] = node
	_clamp_companion_scale(node)
	if auto_activate:
		# New pet always becomes active; oldest active gets sent home if over 3
		activate_companion(word, player)
	elif word in GameManager.active_companions:
		_set_companion_owner(node, player)
	else:
		_send_companion_home(node)

func activate_companion(new_word: String, player: Node2D) -> void:
	# Add to active list; if over 3, oldest gets sent home
	if new_word in GameManager.active_companions:
		return  # Already active
	GameManager.active_companions.append(new_word)
	# Evict oldest if over 3
	while GameManager.active_companions.size() > 3:
		var evicted: String = GameManager.active_companions.pop_front()
		if evicted in _companions and is_instance_valid(_companions[evicted]):
			_send_companion_home(_companions[evicted])
	# Activate the new one
	if new_word in _companions and is_instance_valid(_companions[new_word]):
		_set_companion_owner(_companions[new_word], player)
	GameManager.save_game()

func _evict_oldest_companion() -> void:
	# Send the oldest idle companion home (don't destroy, just deactivate)
	# Prefer evicting idle ones first
	for word in _companions:
		if word not in GameManager.active_companions and is_instance_valid(_companions[word]):
			_send_companion_home(_companions[word])
			print("Francis-opia: %s went home to make room!" % word.capitalize())
			return
	# All are active, send the oldest active one home
	if not GameManager.active_companions.is_empty():
		var evicted: String = GameManager.active_companions.pop_front()
		if evicted in _companions and is_instance_valid(_companions[evicted]):
			_send_companion_home(_companions[evicted])
		print("Francis-opia: %s went home to make room!" % evicted.capitalize())

func _set_companion_owner(node: Node, player: Node2D) -> void:
	if node.has_method("setup"):
		# Pet.gd-based (dog/cat)
		node.pet_owner = player
	elif "_owner" in node:
		# Inline-scripted companions
		node._owner = player

func _send_companion_home(node: Node) -> void:
	# Stop following by clearing owner
	if node.has_method("setup"):
		node.pet_owner = null
	elif "_owner" in node:
		node._owner = null
	# Move to main house interior (offset left from portal room into the house)
	if _home_node and is_instance_valid(_home_node):
		# Main house interior: house origin + 240 (center), at ground level
		var house_interior: Vector2 = (_home_node as Node2D).global_position + Vector2(240, -40)
		var idx := 0
		for word in _companions:
			if is_instance_valid(_companions[word]) and _companions[word] == node:
				break
			idx += 1
		var offset_x := (idx - 2) * 50.0
		if node is CharacterBody2D:
			node.global_position = house_interior + Vector2(offset_x, 10)
			node.velocity = Vector2.ZERO
		else:
			node.global_position = house_interior + Vector2(offset_x, -30)
	elif GameManager.home_pos_x != 0.0 or GameManager.home_pos_y != 0.0:
		# Fallback if home node lost (e.g. after reload)
		var home := Vector2(GameManager.home_pos_x - 200, GameManager.home_pos_y)
		if node is CharacterBody2D:
			node.global_position = home
			node.velocity = Vector2.ZERO
		else:
			node.global_position = home + Vector2(0, -40)

func teleport_active_companion(target_pos: Vector2) -> void:
	for i in GameManager.active_companions.size():
		var word: String = GameManager.active_companions[i]
		if word in _companions and is_instance_valid(_companions[word]):
			var offset := Vector2((i + 1) * 30, -10)
			_companions[word].global_position = target_pos + offset
			if _companions[word] is CharacterBody2D:
				_companions[word].velocity = Vector2.ZERO

func _clamp_companion_scale(node: Node) -> void:
	var n2d := node as Node2D
	if not n2d:
		return
	if abs(n2d.scale.y) > 2.0:
		var sx: float = sign(n2d.scale.x) if n2d.scale.x != 0 else 1.0
		n2d.scale = Vector2(sx * 2.0, 2.0)

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

	# === PHASE 3: GPUParticles2D sparkle burst + camera + atmosphere + sound ===
	await get_tree().create_timer(0.6).timeout
	var vfx_color := MagicVFX.get_color_for_type(entry.get("type", "world"))
	MagicVFX.spawn_sparkle_burst(scene_root, summon_pos, vfx_color, 24)
	MagicVFX.flash_warm_atmosphere(scene_root)
	# Word completion chord + summon type accent
	SoundFX.play_word_complete()
	SoundFX.play_summon_accent(entry.get("type", "world"))
	# Word pronunciation handled by PhonemePlayer via WordEngine.word_spelled_correctly signal
	# Camera zoom + gentle shake
	var active_camera := get_viewport().get_camera_2d()
	MagicVFX.camera_word_complete(active_camera)

	# === PHASE 4: Summon the thing! ===
	await get_tree().create_timer(0.3).timeout
	# Auto-evict oldest companion if at limit (queue behavior)
	if is_companion_word(word) and get_companion_count() >= MAX_COMPANIONS:
		_evict_oldest_companion()
	var builder_name: String = entry.get("builder", "")
	if builder_name != "" and has_method(builder_name):
		var summoned: Variant = call(builder_name, scene_root, player, summon_pos)
		if summoned is Node:
			_summoned_entities.append(summoned)
			# Register companion for active/idle tracking
			if is_companion_word(word):
				register_companion(word, summoned, player)
			summon_completed.emit(word, summoned)
			# Track in GameManager for persistence (skip temporary effects)
			var is_temporary: bool = entry.get("temporary", false)
			if not is_temporary:
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
		push_warning("Francis-opia: Pet scene failed to load!")
		return null
	# Don't double-spawn if a cat already exists
	for entity in _summoned_entities:
		if is_instance_valid(entity) and entity.name == "CatPet":
			return entity
	var pet := _pet_scene.instantiate() as CharacterBody2D
	pet.name = "CatPet"
	# Spawn beside the player, slightly above ground to avoid collision issues
	pet.global_position = player.global_position + Vector2(-60, -20)
	scene_root.add_child(pet)
	if pet.has_method("setup"):
		pet.setup(player, 1)  # CAT type
	pet.follow_offset = Vector2(-50, 0)
	print("Francis-opia: A magical cat appeared!")
	return pet

func _summon_dog(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	if not _pet_scene:
		push_warning("Francis-opia: Pet scene failed to load!")
		return null
	# Don't double-spawn if a dog already exists
	for entity in _summoned_entities:
		if is_instance_valid(entity) and entity.name == "DogPet":
			return entity
	var pet := _pet_scene.instantiate() as CharacterBody2D
	pet.name = "DogPet"
	# Spawn beside the player, slightly above ground to avoid collision issues
	pet.global_position = player.global_position + Vector2(60, -20)
	scene_root.add_child(pet)
	if pet.has_method("setup"):
		pet.setup(player, 0)  # DOG type
	pet.follow_offset = Vector2(50, 0)
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

	# Script must be set BEFORE adding to scene tree so Godot registers _physics_process
	var script := GDScript.new()
	script.source_code = """extends CharacterBody2D

var _owner: Node2D = null
var _gravity := 980.0
var _hop_timer := 0.0
var _follow_offset := Vector2(80, 0)
var _stuck_timer := 0.0
var _last_dist := 0.0

func _physics_process(delta):
	if not _owner or not is_instance_valid(_owner):
		return

	if not is_on_floor():
		velocity.y += _gravity * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0

	var target = _owner.global_position + _follow_offset
	var dist = global_position.distance_to(_owner.global_position)

	# Prevent sitting on player head
	var dx = global_position.x - _owner.global_position.x
	var dy = global_position.y - _owner.global_position.y
	if abs(dx) < 20 and dy < -10 and dy > -60:
		var push = 1.0 if _follow_offset.x >= 0 else -1.0
		velocity.x = push * 160
		move_and_slide()
		return

	# Teleport if too far
	if dist > 250 or global_position.y > _owner.global_position.y + 400:
		global_position = _owner.global_position + _follow_offset
		velocity = Vector2.ZERO
		_stuck_timer = 0.0
		return

	# Stuck detection
	if dist > 60:
		if dist >= _last_dist - 2.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		if _stuck_timer > 1.5:
			global_position = _owner.global_position + _follow_offset
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
			return
	else:
		_stuck_timer = 0.0
	_last_dist = dist

	# Hop toward owner
	_hop_timer += delta
	if is_on_floor() and dist > 60 and _hop_timer > 0.5:
		_hop_timer = 0.0
		var dir = global_position.direction_to(target)
		velocity.x = dir.x * 160
		velocity.y = -300

	# Jump if owner is above or hitting a wall
	if is_on_floor() and (_owner.global_position.y < global_position.y - 20 or (dist > 60 and is_on_wall())):
		velocity.y = -350
		var dir = global_position.direction_to(target)
		velocity.x = dir.x * 140
		_hop_timer = 0.0

	if is_on_floor() and dist <= 60:
		velocity.x = move_toward(velocity.x, 0, 200 * delta)

	if velocity.x > 1:
		scale.x = abs(scale.x)
	elif velocity.x < -1:
		scale.x = -abs(scale.x)

	move_and_slide()
"""
	script.reload()
	frog.set_script(script)
	frog._owner = player
	frog.add_collision_exception_with(player)
	scene_root.add_child(frog)

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

	# Script must be set BEFORE adding to scene tree
	var script := GDScript.new()
	script.source_code = """extends Node2D

var _owner: Node2D = null
var _time := 0.0

func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(-40 + sin(_time * 2) * 30, -55 + cos(_time * 3) * 15)
		global_position = global_position.lerp(target, delta * 3.0)
		if global_position.distance_to(_owner.global_position) > 400:
			global_position = _owner.global_position + Vector2(-40, -55)
"""
	script.reload()
	bug.set_script(script)
	bug._owner = player
	scene_root.add_child(bug)

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

	var script := GDScript.new()
	script.source_code = """extends Node2D

var _owner: Node2D = null
var _time := 0.0

func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(50 + cos(_time * 1.5) * 40, -45 + sin(_time * 2) * 20)
		global_position = global_position.lerp(target, delta * 2.5)
		scale.x = -1.0 if (target.x - global_position.x) < 0 else 1.0
		if global_position.distance_to(_owner.global_position) > 400:
			global_position = _owner.global_position + Vector2(50, -45)
"""
	script.reload()
	fish.set_script(script)
	fish._owner = player
	scene_root.add_child(fish)

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

	var script := GDScript.new()
	script.source_code = """extends Node2D

var _owner: Node2D = null
var _time := 0.0

func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(sin(_time) * 70, -95 + sin(_time * 2.5) * 15)
		global_position = global_position.lerp(target, delta * 2.0)
		scale.x = -1.0 if (target.x - global_position.x) < 0 else 1.0
		# Wing flap
		var wing = get_node_or_null("Wing")
		if wing:
			wing.scale.y = 0.5 + abs(sin(_time * 8)) * 0.5
		if global_position.distance_to(_owner.global_position) > 500:
			global_position = _owner.global_position + Vector2(0, -95)
"""
	script.reload()
	bird.set_script(script)
	bird._owner = player
	scene_root.add_child(bird)

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
	# Spawn beside the player, not on their head
	var offset_x: float = 120.0 if player.is_facing_right() else -120.0
	tree.global_position = Vector2(player.global_position.x + offset_x, 725)  # On ground

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

func _summon_run(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Super speed for 60 seconds
	var original_speed: float = player.move_speed
	player.move_speed = original_speed * 2.0

	# Speed lines visual attached to player
	var lines := Node2D.new()
	lines.name = "SpeedLines"
	# Remove old if re-cast
	var old := player.get_node_or_null("SpeedLines")
	if old:
		old.queue_free()
	for i in 4:
		var line := ColorRect.new()
		line.position = Vector2(-24, -20 + i * 12)
		line.size = Vector2(8, 2)
		line.color = Color(1.0, 0.9, 0.2, 0.5)
		lines.add_child(line)
	player.add_child(lines)

	# Timer to revert after 60 seconds
	var timer := get_tree().create_timer(60.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.move_speed = original_speed
			var sl := player.get_node_or_null("SpeedLines")
			if sl:
				var fade := sl.create_tween()
				fade.tween_property(sl, "modulate:a", 0.0, 0.5)
				fade.tween_callback(sl.queue_free)
			print("Francis-opia: Speed boost wore off!")
	)

	print("Francis-opia: SUPER SPEED! Go go go!")
	return null

func _summon_red(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Turn nearby terrain blocks red for 60 seconds
	var affected: Array[Node] = []
	var radius := 600.0
	for key in scene_root.get("_terrain_blocks") if "_terrain_blocks" in scene_root else {}:
		var block: Node = scene_root._terrain_blocks[key]
		if not is_instance_valid(block):
			continue
		if block.global_position.distance_to(player.global_position) < radius:
			var visual := block.get_node_or_null("Visual") as ColorRect
			if visual:
				affected.append(visual)
				var orig_color: Color = visual.color
				# Tint red but keep some variation
				visual.color = Color(0.9, 0.15 + randf() * 0.1, 0.1, 1)
				# Store original for restore
				visual.set_meta("orig_color", orig_color)

	# Also tint grass on platforms in visible chunks
	print("Francis-opia: The ground turned RED! (%d blocks)" % affected.size())

	# Revert after 60 seconds
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		for visual in affected:
			if is_instance_valid(visual) and visual.has_meta("orig_color"):
				var tween := visual.create_tween()
				tween.tween_property(visual, "color", visual.get_meta("orig_color"), 1.0)
		print("Francis-opia: The red faded away!")
	)
	return null

func _summon_mud(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Mud that hugs the terrain surface and makes the player slide uncontrollably.
	# Samples terrain height at each column for natural contour.
	const TH = preload("res://scripts/world/TerrainHeight.gd")
	var BLOCK_SIZE := 32.0
	var BLOCKS_PER_CHUNK := 40
	var CHUNK_WIDTH := 1280.0
	var GROUND_Y := 725.0
	var MUD_WIDTH := 400.0  # Total width in pixels (centered on player)
	var MUD_COLUMNS := 13   # Number of terrain-following segments
	var COL_WIDTH := MUD_WIDTH / float(MUD_COLUMNS)

	var mud_zone := Area2D.new()
	mud_zone.name = "MudZone"
	mud_zone.global_position = Vector2(player.global_position.x, 0)
	mud_zone.collision_layer = 0
	mud_zone.collision_mask = 0

	var world_seed: int = GameManager.world_seed

	# Sample terrain height at each column and build terrain-hugging visuals
	var start_x := -MUD_WIDTH / 2.0
	for i in MUD_COLUMNS:
		var local_x := start_x + i * COL_WIDTH
		var world_x := player.global_position.x + local_x
		# Get terrain height at this world X position
		var chunk_idx := int(floor(world_x / CHUNK_WIDTH))
		var world_block_x := int(floor(world_x / BLOCK_SIZE))
		var height_offset := TH.get_height(world_block_x, world_seed)
		var surface_y := GROUND_Y + height_offset * BLOCK_SIZE

		# Mud segment sits on the terrain surface
		var seg := ColorRect.new()
		seg.position = Vector2(local_x, surface_y - 6)
		seg.size = Vector2(COL_WIDTH + 1, 10)  # +1 overlap to avoid gaps
		seg.color = Color(0.38 + randf() * 0.04, 0.26 + randf() * 0.04, 0.10 + randf() * 0.03, 0.85)
		seg.z_index = 1
		mud_zone.add_child(seg)

		# Shiny wet layer on top
		var sheen := ColorRect.new()
		sheen.position = Vector2(local_x + 2, surface_y - 8)
		sheen.size = Vector2(COL_WIDTH - 4, 4)
		sheen.color = Color(0.5, 0.35, 0.18, 0.35)
		sheen.z_index = 2
		mud_zone.add_child(sheen)

		# Occasional puddle spots
		if randf() < 0.5:
			var puddle := ColorRect.new()
			puddle.position = Vector2(local_x + randf() * COL_WIDTH * 0.5, surface_y - 10 - randf() * 3)
			puddle.size = Vector2(12 + randf() * 16, 4 + randf() * 3)
			puddle.color = Color(0.33, 0.20, 0.08, 0.5)
			puddle.z_index = 1
			mud_zone.add_child(puddle)

	# Detection collision — wide box centered on player position, tall enough for hills
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(MUD_WIDTH, 120)
	col.shape = shape
	col.position = Vector2(0, GROUND_Y - 20)
	mud_zone.add_child(col)

	scene_root.add_child(mud_zone)

	# Script: player slides with no steering while on mud
	var script := GDScript.new()
	script.source_code = """extends Area2D

var _players_inside: Array = []

func _ready():
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

func _on_enter(body: Node2D):
	if body is CharacterBody2D and body.name.begins_with(\"Player\"):
		if \"on_mud\" in body:
			body.on_mud = true
			_players_inside.append(body)

func _on_exit(body: Node2D):
	if body in _players_inside:
		_players_inside.erase(body)
		if \"on_mud\" in body:
			body.on_mud = false
"""
	script.reload()
	mud_zone.set_script(script)

	# Remove mud after 60 seconds
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(mud_zone):
			for body in mud_zone._players_inside:
				if is_instance_valid(body) and "on_mud" in body:
					body.on_mud = false
			var fade := mud_zone.create_tween()
			fade.tween_property(mud_zone, "modulate:a", 0.0, 1.0)
			fade.tween_callback(mud_zone.queue_free)
			print("Francis-opia: The mud dried up!")
	)

	print("Francis-opia: Splat! Slippery mud everywhere!")
	return mud_zone

func _summon_big(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Make a companion bigger! Picks the smallest companion so BIG rotates through all of them.
	var grown_pet: Node = null
	var smallest_scale := 999.0
	for word in _companions:
		var companion: Node = _companions[word]
		if not is_instance_valid(companion):
			continue
		var s: float = abs(companion.scale.y)
		if s < smallest_scale:
			smallest_scale = s
			grown_pet = companion
	if grown_pet:
		var abs_y: float = abs(grown_pet.scale.y)
		if abs_y >= 2.0:
			_show_summon_label(scene_root, _pos, {"label": "%s is already max size!" % grown_pet.name, "color": Color(1, 0.8, 0.3)})
			return grown_pet
		# Fixed steps: 1.0 -> 1.5 -> 2.0
		var new_y: float = 1.5 if abs_y < 1.25 else 2.0
		var new_abs: float = new_y
		# Preserve facing sign, only scale magnitude
		var sx: float = sign(grown_pet.scale.x) if grown_pet.scale.x != 0 else 1.0
		var tween := grown_pet.create_tween()
		tween.tween_property(grown_pet, "scale", Vector2(sx * new_abs, new_y), 0.5).set_trans(Tween.TRANS_BACK)
		# Persist the scale for future sessions
		GameManager.big_scale = new_y
		GameManager.save_game()
		print("Francis-opia: %s got BIGGER!" % grown_pet.name)
		return grown_pet
	else:
		# No pets yet, make the player a bit bigger temporarily
		var tween := player.create_tween()
		tween.tween_property(player, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK)
		tween.tween_interval(3.0)
		tween.tween_property(player, "scale", Vector2(1.0, 1.0), 0.3)
		print("Francis-opia: YOU got bigger! (for a moment)")
		return null

func _summon_pig(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var pig := CharacterBody2D.new()
	pig.global_position = pos + Vector2(40, -10)
	pig.collision_layer = 0
	pig.collision_mask = 1
	pig.z_index = 5

	# Round pink body
	var body := ColorRect.new()
	body.name = "Body"
	body.position = Vector2(-14, -10)
	body.size = Vector2(28, 16)
	body.color = Color(1.0, 0.7, 0.75, 1)
	pig.add_child(body)

	# Head
	var head := ColorRect.new()
	head.name = "Head"
	head.position = Vector2(-10, -20)
	head.size = Vector2(16, 12)
	head.color = Color(1.0, 0.72, 0.78, 1)
	pig.add_child(head)

	# Snout — big pink circle
	var snout := ColorRect.new()
	snout.name = "Snout"
	snout.position = Vector2(-4, -16)
	snout.size = Vector2(10, 7)
	snout.color = Color(1.0, 0.6, 0.65, 1)
	pig.add_child(snout)

	# Nostrils
	var nostril_l := ColorRect.new()
	nostril_l.position = Vector2(-2, -14)
	nostril_l.size = Vector2(3, 3)
	nostril_l.color = Color(0.8, 0.45, 0.5, 1)
	pig.add_child(nostril_l)
	var nostril_r := ColorRect.new()
	nostril_r.position = Vector2(3, -14)
	nostril_r.size = Vector2(3, 3)
	nostril_r.color = Color(0.8, 0.45, 0.5, 1)
	pig.add_child(nostril_r)

	# Ears — pointy
	var ear_l := ColorRect.new()
	ear_l.position = Vector2(-10, -25)
	ear_l.size = Vector2(6, 7)
	ear_l.color = Color(1.0, 0.6, 0.68, 1)
	pig.add_child(ear_l)
	var ear_r := ColorRect.new()
	ear_r.position = Vector2(3, -25)
	ear_r.size = Vector2(6, 7)
	ear_r.color = Color(1.0, 0.6, 0.68, 1)
	pig.add_child(ear_r)

	# Eyes — happy dots
	var eye_l := ColorRect.new()
	eye_l.position = Vector2(-7, -19)
	eye_l.size = Vector2(3, 3)
	eye_l.color = Color(0.15, 0.15, 0.15, 1)
	pig.add_child(eye_l)
	var eye_r := ColorRect.new()
	eye_r.position = Vector2(3, -19)
	eye_r.size = Vector2(3, 3)
	eye_r.color = Color(0.15, 0.15, 0.15, 1)
	pig.add_child(eye_r)

	# Curly tail
	var tail := ColorRect.new()
	tail.name = "Tail"
	tail.position = Vector2(12, -12)
	tail.size = Vector2(6, 4)
	tail.color = Color(1.0, 0.6, 0.68, 1)
	pig.add_child(tail)

	# Little legs
	for lx in [-8, -2, 6, 12]:
		var leg := ColorRect.new()
		leg.position = Vector2(lx, 4)
		leg.size = Vector2(4, 6)
		leg.color = Color(1.0, 0.6, 0.65, 1)
		pig.add_child(leg)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 14)
	col.position = Vector2(0, -3)
	col.shape = shape
	pig.add_child(col)

	# Follow + oink behavior (script set before add_child so _physics_process registers)
	var script := GDScript.new()
	script.source_code = """extends CharacterBody2D

var _owner: Node2D = null
var _gravity := 980.0
var _time := 0.0
var _follow_offset := Vector2(-70, 0)
var _stuck_timer := 0.0
var _last_dist := 0.0

func _physics_process(delta):
	if not _owner or not is_instance_valid(_owner):
		return
	_time += delta

	if not is_on_floor():
		velocity.y += _gravity * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0

	var target = _owner.global_position + _follow_offset
	var dist = global_position.distance_to(_owner.global_position)
	var dist_to_target = global_position.distance_to(target)

	# Prevent sitting on player head
	var dx = global_position.x - _owner.global_position.x
	var dy = global_position.y - _owner.global_position.y
	if abs(dx) < 20 and dy < -10 and dy > -60:
		var push = 1.0 if _follow_offset.x >= 0 else -1.0
		velocity.x = push * 150
		move_and_slide()
		return

	if dist > 250 or global_position.y > _owner.global_position.y + 400:
		global_position = _owner.global_position + _follow_offset
		velocity = Vector2.ZERO
		_stuck_timer = 0.0
		return

	# Stuck detection
	if dist > 50:
		if dist >= _last_dist - 2.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		if _stuck_timer > 1.5:
			global_position = _owner.global_position + _follow_offset
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
			return
	else:
		_stuck_timer = 0.0
	_last_dist = dist

	if dist_to_target > 50:
		var dir = global_position.direction_to(target)
		velocity.x = dir.x * 150
	else:
		velocity.x = move_toward(velocity.x, 0, 80 * delta)

	if is_on_floor() and (_owner.global_position.y < global_position.y - 20 or (dist > 50 and is_on_wall())):
		velocity.y = -320

	if velocity.x > 1:
		scale.x = abs(scale.x)
	elif velocity.x < -1:
		scale.x = -abs(scale.x)

	# Tail wiggle
	var tail = get_node_or_null(\"Tail\")
	if tail:
		tail.rotation = sin(_time * 6.0) * 0.3

	move_and_slide()
"""
	script.reload()
	pig.set_script(script)
	pig._owner = player
	pig.add_collision_exception_with(player)
	scene_root.add_child(pig)

	print("Francis-opia: A cute pink pig appeared! Oink oink!")
	return pig

func _summon_hen(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var hen := CharacterBody2D.new()
	hen.global_position = pos + Vector2(-50, -10)
	hen.collision_layer = 0
	hen.collision_mask = 1
	hen.z_index = 5

	# Round body
	var body := ColorRect.new()
	body.name = "Body"
	body.position = Vector2(-12, -10)
	body.size = Vector2(24, 16)
	body.color = Color(0.85, 0.6, 0.35, 1)
	hen.add_child(body)

	# Head
	var head := ColorRect.new()
	head.name = "Head"
	head.position = Vector2(-8, -20)
	head.size = Vector2(14, 12)
	head.color = Color(0.9, 0.65, 0.4, 1)
	hen.add_child(head)

	# Comb (red on top)
	var comb := ColorRect.new()
	comb.position = Vector2(-4, -25)
	comb.size = Vector2(8, 6)
	comb.color = Color(0.9, 0.2, 0.2, 1)
	hen.add_child(comb)

	# Beak
	var beak := ColorRect.new()
	beak.position = Vector2(-1, -16)
	beak.size = Vector2(6, 4)
	beak.color = Color(1.0, 0.8, 0.2, 1)
	hen.add_child(beak)

	# Wattle (red under beak)
	var wattle := ColorRect.new()
	wattle.position = Vector2(0, -12)
	wattle.size = Vector2(4, 4)
	wattle.color = Color(0.9, 0.25, 0.2, 1)
	hen.add_child(wattle)

	# Eyes
	var eye := ColorRect.new()
	eye.position = Vector2(-5, -19)
	eye.size = Vector2(3, 3)
	eye.color = Color(0.1, 0.1, 0.1, 1)
	hen.add_child(eye)

	# Tail feathers
	var tail := ColorRect.new()
	tail.name = "Tail"
	tail.position = Vector2(10, -16)
	tail.size = Vector2(6, 12)
	tail.color = Color(0.75, 0.5, 0.3, 1)
	hen.add_child(tail)

	# Legs
	for lx in [-4, 4]:
		var leg := ColorRect.new()
		leg.position = Vector2(lx, 4)
		leg.size = Vector2(3, 6)
		leg.color = Color(1.0, 0.75, 0.2, 1)
		hen.add_child(leg)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 14)
	col.position = Vector2(0, -3)
	col.shape = shape
	hen.add_child(col)

	# Hen behavior script
	var script := GDScript.new()
	script.source_code = """extends CharacterBody2D

var _owner: Node2D = null
var _gravity := 980.0
var _time := 0.0
var _follow_offset := Vector2(-90, 0)
var _stuck_timer := 0.0
var _last_dist := 0.0
var _peck_timer := 0.0

func _physics_process(delta):
	if not _owner or not is_instance_valid(_owner):
		return
	_time += delta

	if not is_on_floor():
		velocity.y += _gravity * delta
		velocity.y = min(velocity.y, 400.0)
	else:
		velocity.y = 0

	var target = _owner.global_position + _follow_offset
	var dist = global_position.distance_to(_owner.global_position)
	var dist_to_target = global_position.distance_to(target)

	# Prevent sitting on player head
	var dx = global_position.x - _owner.global_position.x
	var dy = global_position.y - _owner.global_position.y
	if abs(dx) < 20 and dy < -10 and dy > -60:
		var push = 1.0 if _follow_offset.x >= 0 else -1.0
		velocity.x = push * 150
		move_and_slide()
		return

	if dist > 250 or global_position.y > _owner.global_position.y + 400:
		global_position = _owner.global_position + _follow_offset
		velocity = Vector2.ZERO
		_stuck_timer = 0.0
		return

	# Stuck detection
	if dist > 50:
		if dist >= _last_dist - 2.0:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
		if _stuck_timer > 1.5:
			global_position = _owner.global_position + _follow_offset
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
			return
	else:
		_stuck_timer = 0.0
	_last_dist = dist

	if dist_to_target > 50:
		var dir = global_position.direction_to(target)
		velocity.x = dir.x * 130
	else:
		velocity.x = move_toward(velocity.x, 0, 80 * delta)
		# Idle pecking animation
		_peck_timer += delta
		if _peck_timer > 2.0:
			_peck_timer = 0.0
			var head = get_node_or_null(\"Head\")
			if head:
				var t = create_tween()
				t.tween_property(head, \"position:y\", head.position.y + 6, 0.1)
				t.tween_property(head, \"position:y\", head.position.y, 0.1)

	if is_on_floor() and (_owner.global_position.y < global_position.y - 20 or (dist > 50 and is_on_wall())):
		velocity.y = -300

	if velocity.x > 1:
		scale.x = abs(scale.x)
	elif velocity.x < -1:
		scale.x = -abs(scale.x)

	# Tail bob
	var tail = get_node_or_null(\"Tail\")
	if tail:
		tail.rotation = sin(_time * 4.0) * 0.15

	move_and_slide()
"""
	script.reload()
	hen.set_script(script)
	hen._owner = player
	hen.add_collision_exception_with(player)
	scene_root.add_child(hen)

	print("Francis-opia: A clucky hen appeared! Bawk bawk!")
	return hen

# --- NEW COMPANIONS ---

func _make_simple_companion(scene_root: Node, player: Node2D, pos: Vector2,
		body_color: Color, head_color: Color, eye_color: Color, detail_color: Color,
		body_size: Vector2, head_size: Vector2, offset: Vector2, name_str: String) -> CharacterBody2D:
	## Helper to create a basic ground companion with follow behavior
	var pet := CharacterBody2D.new()
	pet.global_position = pos + Vector2(40, -10)
	pet.collision_layer = 0
	pet.collision_mask = 1
	pet.z_index = 5
	var body := ColorRect.new()
	body.name = "Body"
	body.position = Vector2(-body_size.x / 2, -body_size.y)
	body.size = body_size
	body.color = body_color
	pet.add_child(body)
	var head := ColorRect.new()
	head.name = "Head"
	head.position = Vector2(-head_size.x / 2, -body_size.y - head_size.y + 2)
	head.size = head_size
	head.color = head_color
	pet.add_child(head)
	var eye := ColorRect.new()
	eye.position = Vector2(-4, -body_size.y - head_size.y + 4)
	eye.size = Vector2(3, 3)
	eye.color = eye_color
	pet.add_child(eye)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(body_size.x, body_size.y * 0.8)
	col.shape = shape
	pet.add_child(col)
	var script := GDScript.new()
	script.source_code = "extends CharacterBody2D\n\nvar _owner: Node2D = null\nvar _gravity := 980.0\nvar _follow_offset := Vector2(%f, 0)\nvar _stuck_timer := 0.0\nvar _last_dist := 0.0\n\nfunc _physics_process(delta):\n\tif not _owner or not is_instance_valid(_owner):\n\t\treturn\n\tif not is_on_floor():\n\t\tvelocity.y += _gravity * delta\n\t\tvelocity.y = min(velocity.y, 400.0)\n\telse:\n\t\tvelocity.y = 0\n\tvar target = _owner.global_position + _follow_offset\n\tvar dist = global_position.distance_to(_owner.global_position)\n\tvar dx = global_position.x - _owner.global_position.x\n\tvar dy = global_position.y - _owner.global_position.y\n\tif abs(dx) < 20 and dy < -10 and dy > -60:\n\t\tvar push = 1.0 if _follow_offset.x >= 0 else -1.0\n\t\tvelocity.x = push * 150\n\t\tmove_and_slide()\n\t\treturn\n\tif dist > 250 or global_position.y > _owner.global_position.y + 400:\n\t\tglobal_position = _owner.global_position + _follow_offset\n\t\tvelocity = Vector2.ZERO\n\t\t_stuck_timer = 0.0\n\t\treturn\n\tif dist > 50:\n\t\tif dist >= _last_dist - 2.0:\n\t\t\t_stuck_timer += delta\n\t\telse:\n\t\t\t_stuck_timer = 0.0\n\t\tif _stuck_timer > 1.5:\n\t\t\tglobal_position = _owner.global_position + _follow_offset\n\t\t\tvelocity = Vector2.ZERO\n\t\t\t_stuck_timer = 0.0\n\t\t\treturn\n\telse:\n\t\t_stuck_timer = 0.0\n\t_last_dist = dist\n\tvar dist_to_target = global_position.distance_to(target)\n\tif dist_to_target > 50:\n\t\tvar dir = global_position.direction_to(target)\n\t\tvelocity.x = dir.x * 140\n\telse:\n\t\tvelocity.x = move_toward(velocity.x, 0, 80 * delta)\n\tif is_on_floor() and (_owner.global_position.y < global_position.y - 20 or (dist > 50 and is_on_wall())):\n\t\tvelocity.y = -320\n\tif velocity.x > 1:\n\t\tscale.x = abs(scale.x)\n\telif velocity.x < -1:\n\t\tscale.x = -abs(scale.x)\n\tmove_and_slide()\n" % offset.x
	script.reload()
	pet.set_script(script)
	pet._owner = player
	pet.add_collision_exception_with(player)
	scene_root.add_child(pet)
	return pet

func _summon_bat(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Flying bat companion
	var bat := Node2D.new()
	bat.global_position = pos + Vector2(0, -80)
	bat.z_index = 5
	var body := ColorRect.new()
	body.position = Vector2(-6, -4)
	body.size = Vector2(12, 8)
	body.color = Color(0.35, 0.25, 0.45, 1)
	bat.add_child(body)
	var wing_l := ColorRect.new()
	wing_l.name = "WingL"
	wing_l.position = Vector2(-16, -6)
	wing_l.size = Vector2(12, 7)
	wing_l.color = Color(0.3, 0.2, 0.4, 0.8)
	bat.add_child(wing_l)
	var wing_r := ColorRect.new()
	wing_r.name = "WingR"
	wing_r.position = Vector2(4, -6)
	wing_r.size = Vector2(12, 7)
	wing_r.color = Color(0.3, 0.2, 0.4, 0.8)
	bat.add_child(wing_r)
	var eye_l := ColorRect.new()
	eye_l.position = Vector2(-4, -6)
	eye_l.size = Vector2(3, 3)
	eye_l.color = Color(1, 0.8, 0.2, 1)
	bat.add_child(eye_l)
	var eye_r := ColorRect.new()
	eye_r.position = Vector2(1, -6)
	eye_r.size = Vector2(3, 3)
	eye_r.color = Color(1, 0.8, 0.2, 1)
	bat.add_child(eye_r)
	var script := GDScript.new()
	script.source_code = """extends Node2D
var _owner: Node2D = null
var _time := 0.0
func _process(delta):
	_time += delta
	if _owner and is_instance_valid(_owner):
		var target = _owner.global_position + Vector2(sin(_time * 1.8) * 50, -75 + sin(_time * 3) * 10)
		global_position = global_position.lerp(target, delta * 2.5)
		scale.x = -1.0 if (target.x - global_position.x) < 0 else 1.0
		var wl = get_node_or_null("WingL")
		var wr = get_node_or_null("WingR")
		if wl: wl.scale.y = 0.4 + abs(sin(_time * 10)) * 0.6
		if wr: wr.scale.y = 0.4 + abs(sin(_time * 10)) * 0.6
		if global_position.distance_to(_owner.global_position) > 400:
			global_position = _owner.global_position + Vector2(0, -75)
"""
	script.reload()
	bat.set_script(script)
	bat._owner = player
	scene_root.add_child(bat)
	print("Francis-opia: A friendly bat appeared!")
	return bat

func _summon_rat(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var rat := _make_simple_companion(scene_root, player, pos,
		Color(0.5, 0.45, 0.4), Color(0.55, 0.48, 0.42), Color(0.1, 0.1, 0.1), Color(0.45, 0.4, 0.35),
		Vector2(18, 12), Vector2(12, 10), Vector2(60, 0), "Rat")
	# Add thin tail
	var tail := ColorRect.new()
	tail.name = "Tail"
	tail.position = Vector2(8, -8)
	tail.size = Vector2(10, 2)
	tail.color = Color(0.6, 0.5, 0.45, 1)
	rat.add_child(tail)
	print("Francis-opia: A cheeky rat appeared!")
	return rat

func _summon_fox(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var fox := _make_simple_companion(scene_root, player, pos,
		Color(0.9, 0.5, 0.15), Color(0.95, 0.55, 0.2), Color(0.15, 0.15, 0.1), Color(0.95, 0.85, 0.7),
		Vector2(24, 14), Vector2(14, 12), Vector2(-80, 0), "Fox")
	# Bushy tail
	var tail := ColorRect.new()
	tail.position = Vector2(10, -14)
	tail.size = Vector2(10, 12)
	tail.color = Color(0.9, 0.5, 0.15, 1)
	fox.add_child(tail)
	var tail_tip := ColorRect.new()
	tail_tip.position = Vector2(14, -10)
	tail_tip.size = Vector2(6, 6)
	tail_tip.color = Color(1, 1, 1, 0.9)
	fox.add_child(tail_tip)
	# Ears
	var ear_l := ColorRect.new()
	ear_l.position = Vector2(-8, -28)
	ear_l.size = Vector2(5, 7)
	ear_l.color = Color(0.9, 0.5, 0.15, 1)
	fox.add_child(ear_l)
	var ear_r := ColorRect.new()
	ear_r.position = Vector2(3, -28)
	ear_r.size = Vector2(5, 7)
	ear_r.color = Color(0.9, 0.5, 0.15, 1)
	fox.add_child(ear_r)
	print("Francis-opia: A clever fox appeared!")
	return fox

func _summon_pup(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var pup := _make_simple_companion(scene_root, player, pos,
		Color(0.7, 0.5, 0.3), Color(0.75, 0.55, 0.35), Color(0.1, 0.1, 0.1), Color(0.6, 0.4, 0.2),
		Vector2(18, 12), Vector2(12, 10), Vector2(70, 0), "Pup")
	# Floppy ears
	var ear := ColorRect.new()
	ear.position = Vector2(-8, -22)
	ear.size = Vector2(4, 8)
	ear.color = Color(0.6, 0.4, 0.25, 1)
	pup.add_child(ear)
	# Tiny tail
	var tail := ColorRect.new()
	tail.position = Vector2(8, -10)
	tail.size = Vector2(4, 6)
	tail.color = Color(0.7, 0.5, 0.3, 1)
	pup.add_child(tail)
	print("Francis-opia: A bouncy puppy appeared!")
	return pup

# --- COSMETICS ---

func _summon_cap(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var old := player.get_node_or_null("MagicCap")
	if old: old.queue_free()
	var cap := ColorRect.new()
	cap.name = "MagicCap"
	cap.position = Vector2(-12, -44)
	cap.size = Vector2(24, 8)
	cap.color = Color(0.2, 0.5, 0.9, 1)
	player.add_child(cap)
	var brim := ColorRect.new()
	brim.position = Vector2(-6, -38)
	brim.size = Vector2(18, 4)
	brim.color = Color(0.15, 0.4, 0.8, 1)
	cap.add_child(brim)
	print("Francis-opia: Cool cap!")
	return cap

func _summon_wig(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var old := player.get_node_or_null("MagicWig")
	if old: old.queue_free()
	var wig := Node2D.new()
	wig.name = "MagicWig"
	var colors := [Color(1, 0.4, 0.8), Color(0.4, 0.8, 1), Color(1, 0.9, 0.2)]
	for i in 5:
		var strand := ColorRect.new()
		strand.position = Vector2(-14 + i * 6, -52 - randi() % 8)
		strand.size = Vector2(6, 14 + randi() % 8)
		strand.color = colors[i % colors.size()]
		wig.add_child(strand)
	player.add_child(wig)
	print("Francis-opia: Funny wig!")
	return wig

func _summon_lip(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var old := player.get_node_or_null("MagicLip")
	if old: old.queue_free()
	var lip := ColorRect.new()
	lip.name = "MagicLip"
	lip.position = Vector2(-8, -18)
	lip.size = Vector2(16, 6)
	lip.color = Color(1.0, 0.3, 0.4, 0.9)
	player.add_child(lip)
	print("Francis-opia: Silly lips!")
	return lip

# --- POWER-UPS ---

func _summon_hop(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var orig: float = player.jump_velocity
	player.jump_velocity = orig * 1.5
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(player): player.jump_velocity = orig
		print("Francis-opia: Jump boost wore off!"))
	print("Francis-opia: SUPER JUMP for 60 seconds!")
	return null

func _summon_zip(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var dir := 1.0 if player.is_facing_right() else -1.0
	player.global_position.x += dir * 200
	# Zip trail
	for i in 5:
		var trail := ColorRect.new()
		trail.global_position = player.global_position - Vector2(dir * i * 40, 0)
		trail.size = Vector2(20, 4)
		trail.color = Color(0.3, 0.8, 1.0, 0.6 - i * 0.1)
		trail.z_index = 5
		scene_root.add_child(trail)
		var tw := trail.create_tween()
		tw.tween_property(trail, "modulate:a", 0.0, 0.5)
		tw.tween_callback(trail.queue_free)
	print("Francis-opia: ZIP!")
	return null

func _summon_dig(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var orig_cd: float = player.dig_cooldown
	var orig_range: float = player.dig_range
	player.dig_cooldown = 0.05
	player.dig_range = 160.0
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.dig_cooldown = orig_cd
			player.dig_range = orig_range
		print("Francis-opia: Dig power wore off!"))
	print("Francis-opia: DIG POWER for 60 seconds!")
	return null

func _summon_fan(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var orig_speed: float = player.move_speed
	player.move_speed = orig_speed * 1.4
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(player): player.move_speed = orig_speed
		print("Francis-opia: Wind died down!"))
	print("Francis-opia: Whoooosh! Wind boost for 60 seconds!")
	return null

func _summon_leg(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var orig_speed: float = player.move_speed
	player.move_speed = orig_speed * 1.5
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if is_instance_valid(player): player.move_speed = orig_speed
		print("Francis-opia: Speed wore off!"))
	print("Francis-opia: Fast legs for 30 seconds!")
	return null

func _summon_hug(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Hearts burst from player and companions
	for i in 8:
		var heart := Label.new()
		heart.text = "<3"
		heart.add_theme_font_size_override("font_size", 24)
		heart.add_theme_color_override("font_color", Color(1, 0.4, 0.5))
		heart.global_position = player.global_position + Vector2(randf_range(-40, 40), randf_range(-60, -20))
		heart.z_index = 20
		scene_root.add_child(heart)
		var tw := heart.create_tween()
		tw.tween_property(heart, "position:y", heart.position.y - 60, 1.0)
		tw.parallel().tween_property(heart, "modulate:a", 0.0, 1.2)
		tw.tween_callback(heart.queue_free)
	print("Francis-opia: Big hug! Everyone feels loved!")
	return null

# --- ANTI-THIEF ---

func _summon_net(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Catch nearest thief
	var main := get_tree().current_scene
	if "_active_thieves" in main:
		for thief in main._active_thieves:
			if is_instance_valid(thief) and thief.has_method("scare_away"):
				thief.scare_away()
				print("Francis-opia: Caught a thief with the net!")
				return null
	print("Francis-opia: No thieves to catch!")
	return null

func _summon_web(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var ground_y := 725.0
	var web := Area2D.new()
	web.name = "WebZone"
	web.global_position = Vector2(player.global_position.x, ground_y)
	web.collision_layer = 0
	web.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(400, 60)
	col.shape = shape
	col.position = Vector2(0, -30)
	web.add_child(col)
	# Web visual
	for i in 6:
		var strand := ColorRect.new()
		strand.position = Vector2(-180 + i * 60, -10 - randf() * 20)
		strand.size = Vector2(50, 2)
		strand.color = Color(0.9, 0.9, 0.95, 0.5)
		strand.z_index = 1
		web.add_child(strand)
	for i in 4:
		var strand := ColorRect.new()
		strand.position = Vector2(-150 + i * 80, -30)
		strand.size = Vector2(2, 30)
		strand.color = Color(0.9, 0.9, 0.95, 0.4)
		strand.z_index = 1
		web.add_child(strand)
	scene_root.add_child(web)
	# Check for thieves touching the web
	var script := GDScript.new()
	script.source_code = """extends Area2D
func _ready():
	monitoring = true
	collision_layer = 0
	collision_mask = 16
	body_entered.connect(_on_enter)
func _on_enter(body):
	if body.has_method("scare_away"):
		body.scare_away()
		print("Francis-opia: Thief caught in web!")
"""
	script.reload()
	web.set_script(script)
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(web): web.queue_free())
	print("Francis-opia: Sticky web placed!")
	return web

func _summon_jam(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var ground_y := 725.0
	var jam_zone := Area2D.new()
	jam_zone.name = "JamZone"
	jam_zone.global_position = Vector2(player.global_position.x, ground_y)
	jam_zone.collision_layer = 0
	jam_zone.collision_mask = 16
	jam_zone.monitoring = true
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(500, 60)
	col.shape = shape
	col.position = Vector2(0, -30)
	jam_zone.add_child(col)
	# Jam visual
	var vis := ColorRect.new()
	vis.position = Vector2(-250, -12)
	vis.size = Vector2(500, 16)
	vis.color = Color(0.8, 0.15, 0.2, 0.5)
	vis.z_index = 1
	jam_zone.add_child(vis)
	for i in 6:
		var blob := ColorRect.new()
		blob.position = Vector2(-200 + i * 70 + randf() * 30, -14 - randf() * 4)
		blob.size = Vector2(25 + randf() * 20, 8 + randf() * 4)
		blob.color = Color(0.85, 0.1, 0.15, 0.4)
		blob.z_index = 1
		jam_zone.add_child(blob)
	scene_root.add_child(jam_zone)
	var script := GDScript.new()
	script.source_code = """extends Area2D
func _ready():
	body_entered.connect(_on_enter)
func _on_enter(body):
	if body.has_method("scare_away"):
		body.scare_away()
		print("Francis-opia: Thief got stuck in jam!")
"""
	script.reload()
	jam_zone.set_script(script)
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(jam_zone): jam_zone.queue_free())
	print("Francis-opia: Sticky jam everywhere!")
	return jam_zone

func _summon_fog(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Fog: thieves wander randomly instead of chasing
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 3
	var fog := ColorRect.new()
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.color = Color(0.85, 0.85, 0.9, 0.25)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_layer.add_child(fog)
	scene_root.add_child(fog_layer)
	# Disable thief targeting during fog
	var main := get_tree().current_scene
	if "_active_thieves" in main:
		for thief in main._active_thieves:
			if is_instance_valid(thief) and "_target_player" in thief:
				thief._target_player = null
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(fog_layer):
			var tw := fog.create_tween()
			tw.tween_property(fog, "color:a", 0.0, 2.0)
			tw.tween_callback(fog_layer.queue_free)
		print("Francis-opia: Fog cleared!"))
	print("Francis-opia: Thick fog! Thieves can't find you!")
	return fog_layer

# --- COIN REWARDS ---

func _spawn_coins(scene_root: Node, pos: Vector2, count: int) -> void:
	for i in count:
		var coin := ColorRect.new()
		coin.size = Vector2(8, 8)
		coin.color = Color(1, 0.85, 0.2, 1)
		coin.global_position = pos
		coin.z_index = 15
		scene_root.add_child(coin)
		var angle := TAU * float(i) / float(count)
		var target := pos + Vector2(cos(angle), sin(angle) - 0.5) * randf_range(30, 60)
		var tw := coin.create_tween()
		tw.tween_property(coin, "global_position", target, 0.4).set_trans(Tween.TRANS_BACK)
		tw.tween_property(coin, "modulate:a", 0.0, 0.5)
		tw.tween_callback(coin.queue_free)
	GameManager.add_coins(count)

func _summon_gem(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 5)
	print("Francis-opia: A shiny gem worth 5 coins!")
	return null

func _summon_pot(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 10)
	print("Francis-opia: Pot of gold! 10 coins!")
	return null

func _summon_bag(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 3)
	print("Francis-opia: Coin bag! 3 coins!")
	return null

func _summon_six(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 6)
	print("Francis-opia: Six coins!")
	return null

func _summon_ten(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 10)
	print("Francis-opia: Ten coins!")
	return null

func _summon_nut(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Squirrel runs in, grabs nut, drops coins
	var squirrel := ColorRect.new()
	squirrel.size = Vector2(12, 10)
	squirrel.color = Color(0.6, 0.4, 0.15, 1)
	squirrel.global_position = Vector2(pos.x + 200, 715)
	squirrel.z_index = 10
	scene_root.add_child(squirrel)
	var tw := squirrel.create_tween()
	tw.tween_property(squirrel, "global_position:x", pos.x, 0.6)
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void: _spawn_coins(scene_root, pos, 2))
	tw.tween_property(squirrel, "global_position:x", pos.x - 200, 0.6)
	tw.tween_callback(squirrel.queue_free)
	print("Francis-opia: A squirrel grabbed the nut and left 2 coins!")
	return null

func _summon_bun(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 1)
	print("Francis-opia: A tasty bun! 1 coin!")
	return null

func _summon_gum(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Blow a bubble
	var bubble := ColorRect.new()
	bubble.size = Vector2(20, 20)
	bubble.color = Color(1.0, 0.5, 0.7, 0.4)
	bubble.global_position = player.global_position + Vector2(-10, -50)
	bubble.z_index = 15
	scene_root.add_child(bubble)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "size", Vector2(40, 40), 0.8)
	tw.parallel().tween_property(bubble, "position:y", bubble.position.y - 40, 0.8)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
	_spawn_coins(scene_root, pos, 1)
	print("Francis-opia: Bubble gum! Pop!")
	return null

# --- VISUAL EFFECTS ---

func _summon_hot(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Orange tint + heat shimmer
	var affected: Array[Node] = []
	for key in scene_root.get("_terrain_blocks") if "_terrain_blocks" in scene_root else {}:
		var block: Node = scene_root._terrain_blocks[key]
		if not is_instance_valid(block): continue
		if block.global_position.distance_to(player.global_position) < 500:
			var visual := block.get_node_or_null("Visual") as ColorRect
			if visual:
				affected.append(visual)
				visual.set_meta("orig_color", visual.color)
				visual.color = Color(0.9, 0.5 + randf() * 0.15, 0.1, 1)
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		for v in affected:
			if is_instance_valid(v) and v.has_meta("orig_color"):
				v.color = v.get_meta("orig_color"))
	print("Francis-opia: So hot! The ground is glowing!")
	return null

func _summon_wet(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Rain particles
	var rain := Node2D.new()
	rain.name = "RainEffect"
	rain.z_index = 15
	scene_root.add_child(rain)
	var script := GDScript.new()
	script.source_code = """extends Node2D
var _player: Node2D = null
var _time := 0.0
func _process(delta):
	_time += delta
	if _player and is_instance_valid(_player):
		global_position = _player.global_position
	if Engine.get_frames_drawn() % 3 == 0:
		var drop = ColorRect.new()
		drop.size = Vector2(2, 8)
		drop.color = Color(0.5, 0.7, 1.0, 0.4)
		drop.position = Vector2(randf_range(-400, 400), -300)
		add_child(drop)
		var tw = drop.create_tween()
		tw.tween_property(drop, "position:y", drop.position.y + 500, randf_range(0.4, 0.8))
		tw.tween_callback(drop.queue_free)
"""
	script.reload()
	rain.set_script(script)
	rain._player = player
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if is_instance_valid(rain): rain.queue_free()
		print("Francis-opia: Rain stopped!"))
	print("Francis-opia: It's raining!")
	return rain

func _summon_dot(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var colors := [Color(1, 0.3, 0.3), Color(0.3, 1, 0.3), Color(0.3, 0.3, 1), Color(1, 1, 0.3), Color(1, 0.5, 0)]
	for i in 30:
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = colors[randi() % colors.size()]
		dot.global_position = pos + Vector2(randf_range(-20, 20), -20)
		dot.z_index = 20
		scene_root.add_child(dot)
		var target := pos + Vector2(randf_range(-150, 150), randf_range(-200, 50))
		var tw := dot.create_tween()
		tw.tween_property(dot, "global_position", target, randf_range(0.5, 1.5)).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(dot, "modulate:a", 0.0, 1.5)
		tw.tween_callback(dot.queue_free)
	print("Francis-opia: Confetti!")
	return null

func _summon_mix(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var colors := [Color(1, 0.3, 0.5), Color(0.3, 0.8, 1), Color(1, 0.9, 0.2), Color(0.5, 1, 0.4), Color(1, 0.5, 0)]
	for key in scene_root.get("_terrain_blocks") if "_terrain_blocks" in scene_root else {}:
		var block: Node = scene_root._terrain_blocks[key]
		if not is_instance_valid(block): continue
		if block.global_position.distance_to(player.global_position) < 400:
			var visual := block.get_node_or_null("Visual") as ColorRect
			if visual:
				visual.set_meta("orig_color", visual.color)
				visual.color = colors[randi() % colors.size()]
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		for key2 in scene_root.get("_terrain_blocks") if "_terrain_blocks" in scene_root else {}:
			var block2: Node = scene_root._terrain_blocks[key2]
			if is_instance_valid(block2):
				var v := block2.get_node_or_null("Visual") as ColorRect
				if v and v.has_meta("orig_color"): v.color = v.get_meta("orig_color"))
	print("Francis-opia: Colors mixed up!")
	return null

func _summon_mop(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Remove active mud/jam/web zones
	for child in scene_root.get_children():
		if child.name in ["MudZone", "JamZone", "WebZone"]:
			child.queue_free()
	# Sparkle effect
	for i in 12:
		var sparkle := ColorRect.new()
		sparkle.size = Vector2(4, 4)
		sparkle.color = Color(0.6, 0.85, 1.0, 0.8)
		sparkle.global_position = player.global_position + Vector2(randf_range(-100, 100), randf_range(-20, 20))
		sparkle.z_index = 10
		scene_root.add_child(sparkle)
		var tw := sparkle.create_tween()
		tw.tween_property(sparkle, "modulate:a", 0.0, 1.0)
		tw.tween_callback(sparkle.queue_free)
	print("Francis-opia: All clean and sparkly!")
	return null

func _summon_pin(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var pin := Node2D.new()
	pin.global_position = player.global_position
	pin.z_index = 10
	var pole := ColorRect.new()
	pole.position = Vector2(-1, -40)
	pole.size = Vector2(3, 40)
	pole.color = Color(0.7, 0.7, 0.75, 1)
	pin.add_child(pole)
	var head := ColorRect.new()
	head.position = Vector2(-6, -48)
	head.size = Vector2(12, 12)
	head.color = Color(1, 0.3, 0.3, 1)
	pin.add_child(head)
	scene_root.add_child(pin)
	print("Francis-opia: Marker placed!")
	return pin

func _summon_bit(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# 8-bit pixel filter (just make everything chunky for 10s)
	var filter := CanvasLayer.new()
	filter.layer = 40
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0.3, 0, 0.08)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter.add_child(overlay)
	# Scanlines
	for i in 40:
		var line := ColorRect.new()
		line.offset_top = i * 20
		line.offset_bottom = i * 20 + 1
		line.offset_left = 0
		line.offset_right = 1280
		line.color = Color(0, 0, 0, 0.1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filter.add_child(line)
	scene_root.add_child(filter)
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(filter): filter.queue_free())
	print("Francis-opia: 8-BIT MODE!")
	return filter

func _summon_fin(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var fin := Node2D.new()
	fin.global_position = Vector2(pos.x + 100, 720)
	fin.z_index = 2
	var tri := ColorRect.new()
	tri.position = Vector2(-4, -16)
	tri.size = Vector2(8, 16)
	tri.color = Color(0.5, 0.55, 0.6, 0.8)
	fin.add_child(tri)
	scene_root.add_child(fin)
	var script := GDScript.new()
	script.source_code = """extends Node2D
var _time := 0.0
var _start_x: float
func _ready(): _start_x = global_position.x
func _process(delta):
	_time += delta
	global_position.x = _start_x + sin(_time * 1.5) * 150
	global_position.y = 720 + sin(_time * 3) * 3
"""
	script.reload()
	fin.set_script(script)
	get_tree().create_timer(15.0).timeout.connect(func() -> void:
		if is_instance_valid(fin): fin.queue_free())
	print("Francis-opia: Is that a shark fin?!")
	return fin

func _summon_sit(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	_spawn_coins(scene_root, pos, 1)
	# Brief sparkle
	for i in 6:
		var sp := ColorRect.new()
		sp.size = Vector2(4, 4)
		sp.color = Color(1, 1, 0.5, 0.7)
		sp.global_position = player.global_position + Vector2(randf_range(-20, 20), randf_range(-40, -10))
		sp.z_index = 15
		scene_root.add_child(sp)
		var tw := sp.create_tween()
		tw.tween_property(sp, "position:y", sp.position.y - 30, 0.8)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.8)
		tw.tween_callback(sp.queue_free)
	print("Francis-opia: Rest time!")
	return null

func _summon_hit(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Screen pulse + sound effect style
	var flash := CanvasLayer.new()
	flash.layer = 50
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1, 0.9, 0.3, 0.4)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.add_child(rect)
	scene_root.add_child(flash)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
	print("Francis-opia: BOOM!")
	return null

func _summon_men(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Three dancing stick figures
	for i in 3:
		var man := Node2D.new()
		man.global_position = pos + Vector2(-40 + i * 40, 0)
		man.z_index = 10
		var body := ColorRect.new()
		body.position = Vector2(-2, -20)
		body.size = Vector2(4, 16)
		body.color = Color(0.4 + randf() * 0.3, 0.4 + randf() * 0.3, 0.8, 1)
		man.add_child(body)
		var head := ColorRect.new()
		head.position = Vector2(-4, -28)
		head.size = Vector2(8, 8)
		head.color = Color(0.95, 0.8, 0.65, 1)
		man.add_child(head)
		scene_root.add_child(man)
		var script := GDScript.new()
		script.source_code = """extends Node2D
var _time := 0.0
func _process(delta):
	_time += delta
	rotation = sin(_time * 6 + %f) * 0.3
	position.y += sin(_time * 4) * 0.3
""" % (float(i) * 2.0)
		script.reload()
		man.set_script(script)
		get_tree().create_timer(8.0).timeout.connect(func() -> void:
			if is_instance_valid(man):
				var tw := man.create_tween()
				tw.tween_property(man, "modulate:a", 0.0, 0.5)
				tw.tween_callback(man.queue_free))
	print("Francis-opia: Dance party!")
	return null

func _summon_bus(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	var bus := Node2D.new()
	bus.global_position = Vector2(player.global_position.x + 700, 690)
	bus.z_index = 3
	var body := ColorRect.new()
	body.position = Vector2(-40, -30)
	body.size = Vector2(80, 30)
	body.color = Color(1, 0.8, 0.1, 1)
	bus.add_child(body)
	var roof := ColorRect.new()
	roof.position = Vector2(-38, -38)
	roof.size = Vector2(60, 10)
	roof.color = Color(1, 0.75, 0.05, 1)
	bus.add_child(roof)
	for wi in 3:
		var win := ColorRect.new()
		win.position = Vector2(-30 + wi * 22, -28)
		win.size = Vector2(14, 10)
		win.color = Color(0.6, 0.8, 1, 0.8)
		bus.add_child(win)
	# Wheels
	for wx in [-25, 25]:
		var wheel := ColorRect.new()
		wheel.position = Vector2(wx - 5, -2)
		wheel.size = Vector2(10, 10)
		wheel.color = Color(0.2, 0.2, 0.2, 1)
		bus.add_child(wheel)
	scene_root.add_child(bus)
	var tw := bus.create_tween()
	tw.tween_property(bus, "global_position:x", player.global_position.x - 700, 3.0)
	tw.tween_callback(bus.queue_free)
	print("Francis-opia: Beep beep! School bus!")
	return null

# --- WORLD OBJECTS ---

func _summon_log(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var log := StaticBody2D.new()
	log.global_position = Vector2(pos.x + 60, 715)
	log.collision_layer = 1
	log.collision_mask = 0
	var visual := ColorRect.new()
	visual.position = Vector2(-50, -6)
	visual.size = Vector2(100, 12)
	visual.color = Color(0.5, 0.35, 0.15, 1)
	log.add_child(visual)
	var rings := ColorRect.new()
	rings.position = Vector2(-4, -4)
	rings.size = Vector2(8, 8)
	rings.color = Color(0.6, 0.42, 0.2, 1)
	log.add_child(rings)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 12)
	col.shape = shape
	log.add_child(col)
	scene_root.add_child(log)
	print("Francis-opia: A log bridge!")
	return log

func _summon_mat(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Bouncy mat (like trampoline)
	var mat := StaticBody2D.new()
	mat.global_position = Vector2(pos.x, 725)
	var visual := ColorRect.new()
	visual.position = Vector2(-30, -6)
	visual.size = Vector2(60, 6)
	visual.color = Color(0.9, 0.3, 0.5, 1)
	mat.add_child(visual)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 6)
	col.shape = shape
	mat.add_child(col)
	scene_root.add_child(mat)
	print("Francis-opia: Bouncy mat!")
	return mat

func _summon_van(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var van := Node2D.new()
	van.global_position = Vector2(pos.x + 80, 725)
	var body := ColorRect.new()
	body.position = Vector2(-35, -40)
	body.size = Vector2(70, 40)
	body.color = Color(0.3, 0.6, 0.9, 1)
	van.add_child(body)
	var cabin := ColorRect.new()
	cabin.position = Vector2(-35, -55)
	cabin.size = Vector2(30, 18)
	cabin.color = Color(0.25, 0.5, 0.85, 1)
	van.add_child(cabin)
	var window := ColorRect.new()
	window.position = Vector2(-30, -52)
	window.size = Vector2(20, 12)
	window.color = Color(0.6, 0.8, 1, 0.8)
	van.add_child(window)
	# "FRANCIS" text
	var txt := Label.new()
	txt.text = "FRANCIS"
	txt.add_theme_font_size_override("font_size", 10)
	txt.add_theme_color_override("font_color", Color(1, 1, 1))
	txt.position = Vector2(-28, -30)
	van.add_child(txt)
	for wx in [-20, 20]:
		var wheel := ColorRect.new()
		wheel.position = Vector2(wx - 5, -4)
		wheel.size = Vector2(10, 8)
		wheel.color = Color(0.2, 0.2, 0.2, 1)
		van.add_child(wheel)
	scene_root.add_child(van)
	print("Francis-opia: A fun van!")
	return van

func _summon_hut(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var hut := Node2D.new()
	hut.global_position = Vector2(pos.x + 60, 725)
	var wall := ColorRect.new()
	wall.position = Vector2(-20, -30)
	wall.size = Vector2(40, 30)
	wall.color = Color(0.6, 0.45, 0.2, 1)
	hut.add_child(wall)
	var roof := ColorRect.new()
	roof.position = Vector2(-25, -42)
	roof.size = Vector2(50, 14)
	roof.color = Color(0.5, 0.35, 0.15, 1)
	hut.add_child(roof)
	var door := ColorRect.new()
	door.position = Vector2(-6, -18)
	door.size = Vector2(12, 18)
	door.color = Color(0.35, 0.22, 0.1, 1)
	hut.add_child(door)
	scene_root.add_child(hut)
	print("Francis-opia: A tiny hut!")
	return hut

func _summon_tub(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var tub := Node2D.new()
	tub.global_position = Vector2(pos.x + 50, 725)
	var basin := ColorRect.new()
	basin.position = Vector2(-22, -20)
	basin.size = Vector2(44, 20)
	basin.color = Color(0.9, 0.9, 0.95, 1)
	tub.add_child(basin)
	for i in 4:
		var bubble := ColorRect.new()
		bubble.position = Vector2(-15 + i * 10 + randf() * 5, -24 - randf() * 10)
		bubble.size = Vector2(6, 6)
		bubble.color = Color(0.7, 0.85, 1, 0.5)
		tub.add_child(bubble)
	scene_root.add_child(tub)
	print("Francis-opia: Bubble bath!")
	return tub

func _summon_bin(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Auto-collect nearest scattered letter
	var spawner := scene_root.get_node_or_null("LetterSpawner")
	if spawner:
		var closest: Node2D = null
		var closest_dist := 999.0
		for child in spawner.get_children():
			if child.has_method("is_needed") and child.is_needed():
				var d := player.global_position.distance_to(child.global_position)
				if d < closest_dist:
					closest_dist = d
					closest = child
		if closest:
			var tw := closest.create_tween()
			tw.tween_property(closest, "global_position", player.global_position, 0.5)
			print("Francis-opia: Letter bin pulled a letter closer!")
			return null
	print("Francis-opia: Letter bin!")
	return null

func _summon_cot(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var cot := Node2D.new()
	cot.global_position = Vector2(pos.x + 40, 725)
	var frame := ColorRect.new()
	frame.position = Vector2(-16, -14)
	frame.size = Vector2(32, 14)
	frame.color = Color(0.75, 0.6, 0.4, 1)
	cot.add_child(frame)
	var blanket := ColorRect.new()
	blanket.position = Vector2(-14, -18)
	blanket.size = Vector2(28, 8)
	blanket.color = Color(0.7, 0.8, 1, 0.8)
	cot.add_child(blanket)
	scene_root.add_child(cot)
	print("Francis-opia: A baby cot!")
	return cot

func _summon_pen(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var fence := Node2D.new()
	fence.global_position = Vector2(pos.x + 60, 725)
	for i in 5:
		var post := ColorRect.new()
		post.position = Vector2(-30 + i * 15, -24)
		post.size = Vector2(4, 24)
		post.color = Color(0.55, 0.4, 0.2, 1)
		fence.add_child(post)
	var rail := ColorRect.new()
	rail.position = Vector2(-30, -20)
	rail.size = Vector2(60, 3)
	rail.color = Color(0.6, 0.45, 0.25, 1)
	fence.add_child(rail)
	var rail2 := ColorRect.new()
	rail2.position = Vector2(-30, -10)
	rail2.size = Vector2(60, 3)
	rail2.color = Color(0.6, 0.45, 0.25, 1)
	fence.add_child(rail2)
	scene_root.add_child(fence)
	print("Francis-opia: A fence!")
	return fence

func _summon_jug(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var jug := Node2D.new()
	jug.global_position = Vector2(pos.x + 40, 725)
	var body := ColorRect.new()
	body.position = Vector2(-10, -22)
	body.size = Vector2(20, 22)
	body.color = Color(0.5, 0.7, 0.85, 1)
	jug.add_child(body)
	var handle := ColorRect.new()
	handle.position = Vector2(10, -18)
	handle.size = Vector2(5, 12)
	handle.color = Color(0.4, 0.6, 0.75, 1)
	jug.add_child(handle)
	# Water puddle
	var puddle := ColorRect.new()
	puddle.position = Vector2(-20, -3)
	puddle.size = Vector2(50, 4)
	puddle.color = Color(0.3, 0.6, 0.9, 0.4)
	jug.add_child(puddle)
	scene_root.add_child(jug)
	print("Francis-opia: A jug of water!")
	return jug

func _summon_pan(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	_spawn_coins(scene_root, player.global_position, 1)
	print("Francis-opia: Frying pan! 1 coin!")
	return null

func _summon_can(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	var can := ColorRect.new()
	can.size = Vector2(10, 14)
	can.color = Color(0.6, 0.6, 0.65, 1)
	can.global_position = player.global_position + Vector2(20, -10)
	can.z_index = 10
	scene_root.add_child(can)
	var tw := can.create_tween()
	tw.tween_property(can, "global_position:x", can.global_position.x + 150, 0.8).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(can, "global_position:y", can.global_position.y - 30, 0.4).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(can, "global_position:y", 720, 0.4).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_property(can, "modulate:a", 0.0, 0.5)
	tw.tween_callback(can.queue_free)
	_spawn_coins(scene_root, pos, 1)
	print("Francis-opia: Kick the can!")
	return null

func _summon_map(scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Glow nearest treasure block
	var closest_treasure: Node = null
	var closest_dist := 99999.0
	for key in scene_root.get("_terrain_blocks") if "_terrain_blocks" in scene_root else {}:
		var block: Node = scene_root._terrain_blocks[key]
		if not is_instance_valid(block): continue
		if "has_treasure" in block and block.has_treasure:
			var d := player.global_position.distance_to(block.global_position)
			if d < closest_dist:
				closest_dist = d
				closest_treasure = block
	if closest_treasure:
		var glow := ColorRect.new()
		glow.size = Vector2(36, 36)
		glow.position = Vector2(-18, -18)
		glow.color = Color(1, 0.85, 0.2, 0.4)
		glow.z_index = 5
		closest_treasure.add_child(glow)
		var tw := glow.create_tween().set_loops(6)
		tw.tween_property(glow, "modulate:a", 0.2, 0.5)
		tw.tween_property(glow, "modulate:a", 1.0, 0.5)
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if is_instance_valid(glow): glow.queue_free())
		print("Francis-opia: Treasure nearby! Look for the glow!")
	else:
		print("Francis-opia: No treasure found nearby...")
	return null

func _hide_colorrects_recursive(node: Node) -> void:
	## Hide all ColorRect children (keep collision, hide old visuals).
	for child in node.get_children():
		if child is ColorRect:
			child.visible = false
		if child is Label:
			child.visible = false  # Hide old text labels too
		if child.get_child_count() > 0:
			_hide_colorrects_recursive(child)

func _summon_house(scene_root: Node, player: Node2D, pos: Vector2) -> Node:
	# Enterable house! Player walks through the open door on the right side.
	var house := Node2D.new()
	house.name = "MagicHouse"
	var ground_y := 725.0  # Baseline ground, always flat
	house.global_position = Vector2(pos.x + 120, ground_y)

	# Castle sprite overlay (replaces old ColorRect visuals, collision still built below)
	var _has_castle_sprite := false
	if ResourceLoader.exists("res://assets/sprites/world/castle_0.png"):
		var tex = load("res://assets/sprites/world/castle_0.png") as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.texture = tex
			# Castle is 256x200 at 2x scale = 512x400 rendered
			# House ground_y is at position 0, castle bottom should be at ground
			# Position sprite relative to house node (which is at ground level).
			# Don't use offset — just set position directly for clarity.
			spr.position = Vector2(240, 0)  # Center over 480px house width
			spr.offset = Vector2(0, -100)  # Bottom-align (half of 200px texture height)
			spr.scale = Vector2(2.5, 2.5)  # Bigger castle (256*2.5 = 640px wide)
			spr.z_index = -2  # Behind player (player default z=0)
			house.add_child(spr)
			_has_castle_sprite = true

	# If we have the castle sprite, add a one-way roof platform (no old house walls).
	# Player can jump through from below and land on the roof.
	if _has_castle_sprite:
		# Roof platform (one-way: pass through from below, stand on top)
		# Castle sprite is at scale 2.5, texture 256x200
		# Rendered: 640x500. Roof is near the top of the sprite.
		var roof := StaticBody2D.new()
		roof.position = Vector2(240, -420)  # Near top of castle
		roof.collision_layer = 1
		roof.collision_mask = 0
		house.add_child(roof)
		var roof_col := CollisionShape2D.new()
		roof_col.one_way_collision = true
		var roof_shape := RectangleShape2D.new()
		roof_shape.size = Vector2(400, 16)  # Wide enough for the castle width
		roof_col.shape = roof_shape
		roof.add_child(roof_col)

		# Mid-level ledge (balcony area)
		var ledge := StaticBody2D.new()
		ledge.position = Vector2(240, -200)
		ledge.collision_layer = 1
		ledge.collision_mask = 0
		house.add_child(ledge)
		var ledge_col := CollisionShape2D.new()
		ledge_col.one_way_collision = true
		var ledge_shape := RectangleShape2D.new()
		ledge_shape.size = Vector2(500, 16)
		ledge_col.shape = ledge_shape
		ledge.add_child(ledge_col)

		scene_root.add_child(house)
		GameManager.home_pos_x = house.global_position.x + 240
		GameManager.home_pos_y = house.global_position.y - 40
		print("Francis-opia: A magnificent castle appeared!")
		return house

	var W := 480.0   # House width (2.5x bigger)
	var H := 300.0   # Wall height
	var WALL := 16.0  # Wall thickness
	var DOOR_W := 80.0
	var DOOR_H := 120.0  # Tall enough for player (48px body + hat)
	var ROOF := 24.0

	# --- Solid foundation under the house (deep enough to survive digging) ---
	var foundation_depth := 200.0  # Deep foundation so house never floats
	var ground_pad := StaticBody2D.new()
	ground_pad.position = Vector2(W / 2, foundation_depth / 2 + 4)
	ground_pad.collision_layer = 1
	ground_pad.collision_mask = 0
	house.add_child(ground_pad)
	var gpad_col := CollisionShape2D.new()
	var gpad_shape := RectangleShape2D.new()
	gpad_shape.size = Vector2(W + 80, foundation_depth)
	gpad_col.shape = gpad_shape
	ground_pad.add_child(gpad_col)
	# Surface layer (visible grass)
	var gpad_vis := ColorRect.new()
	gpad_vis.position = Vector2(-(W + 80) / 2, -foundation_depth / 2)
	gpad_vis.size = Vector2(W + 80, 8)
	gpad_vis.color = Color(0.4, 0.55, 0.3, 1)
	ground_pad.add_child(gpad_vis)
	# Underground fill (dirt, hidden behind terrain but solid)
	var fill := ColorRect.new()
	fill.position = Vector2(-(W + 80) / 2, -foundation_depth / 2 + 8)
	fill.size = Vector2(W + 80, foundation_depth - 8)
	fill.color = Color(0.45, 0.32, 0.18, 1)
	ground_pad.add_child(fill)

	# --- Interior background (warm beige, behind everything) ---
	var interior := ColorRect.new()
	interior.z_index = -2
	interior.position = Vector2(WALL, -H + WALL)
	interior.size = Vector2(W - WALL * 2, H - WALL)
	interior.color = Color(0.95, 0.87, 0.7, 1)
	house.add_child(interior)

	# Warm ambient glow inside
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.position = Vector2(WALL + 10, -H + 20)
	glow.size = Vector2(W - WALL * 2 - 20, H - 30)
	glow.color = Color(1.0, 0.92, 0.7, 0.12)
	house.add_child(glow)

	# --- Wooden floor ---
	var wood_floor := ColorRect.new()
	wood_floor.z_index = -1
	wood_floor.position = Vector2(WALL, -6)
	wood_floor.size = Vector2(W - WALL * 2, 6)
	wood_floor.color = Color(0.6, 0.38, 0.2, 1)
	house.add_child(wood_floor)

	# Floor planks (visual detail)
	for i in 6:
		var plank := ColorRect.new()
		plank.z_index = -1
		plank.position = Vector2(WALL + i * 30, -6)
		plank.size = Vector2(1, 6)
		plank.color = Color(0.5, 0.3, 0.15, 0.3)
		house.add_child(plank)

	# --- LEFT WALL top segment (above door) ---
	var lw_top_h := H - DOOR_H
	var lw := StaticBody2D.new()
	lw.position = Vector2(WALL / 2, -(DOOR_H + lw_top_h / 2))
	lw.collision_layer = 1
	lw.collision_mask = 0
	house.add_child(lw)
	var lw_col := CollisionShape2D.new()
	var lw_shape := RectangleShape2D.new()
	lw_shape.size = Vector2(WALL, lw_top_h)
	lw_col.shape = lw_shape
	lw.add_child(lw_col)
	var lw_vis := ColorRect.new()
	lw_vis.position = Vector2(-WALL / 2, -lw_top_h / 2)
	lw_vis.size = Vector2(WALL, lw_top_h)
	lw_vis.color = Color(0.78, 0.58, 0.32, 1)
	lw.add_child(lw_vis)

	# Left door frame
	var ldf_l := ColorRect.new()
	ldf_l.position = Vector2(-6, -DOOR_H)
	ldf_l.size = Vector2(6, DOOR_H)
	ldf_l.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(ldf_l)
	var ldf_r := ColorRect.new()
	ldf_r.position = Vector2(WALL, -DOOR_H)
	ldf_r.size = Vector2(6, DOOR_H)
	ldf_r.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(ldf_r)
	var ldf_top := ColorRect.new()
	ldf_top.position = Vector2(-6, -DOOR_H - 4)
	ldf_top.size = Vector2(WALL + 12, 4)
	ldf_top.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(ldf_top)

	# Left welcome mat
	var lmat := ColorRect.new()
	lmat.position = Vector2(-36, -3)
	lmat.size = Vector2(36, 4)
	lmat.color = Color(0.7, 0.35, 0.3, 1)
	house.add_child(lmat)

	# --- RIGHT WALL top segment (above door) ---
	var rw_top_h := H - DOOR_H
	var rw := StaticBody2D.new()
	rw.position = Vector2(W - WALL / 2, -(DOOR_H + rw_top_h / 2))
	rw.collision_layer = 1
	rw.collision_mask = 0
	house.add_child(rw)
	var rw_col := CollisionShape2D.new()
	var rw_shape := RectangleShape2D.new()
	rw_shape.size = Vector2(WALL, rw_top_h)
	rw_col.shape = rw_shape
	rw.add_child(rw_col)
	var rw_vis := ColorRect.new()
	rw_vis.position = Vector2(-WALL / 2, -rw_top_h / 2)
	rw_vis.size = Vector2(WALL, rw_top_h)
	rw_vis.color = Color(0.78, 0.58, 0.32, 1)
	rw.add_child(rw_vis)

	# Door frame (decorative arch around opening)
	var door_frame_l := ColorRect.new()
	door_frame_l.position = Vector2(W - WALL - 6, -DOOR_H)
	door_frame_l.size = Vector2(6, DOOR_H)
	door_frame_l.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(door_frame_l)
	var door_frame_r := ColorRect.new()
	door_frame_r.position = Vector2(W, -DOOR_H)
	door_frame_r.size = Vector2(6, DOOR_H)
	door_frame_r.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(door_frame_r)
	var door_frame_top := ColorRect.new()
	door_frame_top.position = Vector2(W - WALL - 6, -DOOR_H - 4)
	door_frame_top.size = Vector2(WALL + 12, 4)
	door_frame_top.color = Color(0.5, 0.3, 0.15, 1)
	house.add_child(door_frame_top)

	# Welcome mat outside
	var mat := ColorRect.new()
	mat.position = Vector2(W - 4, -3)
	mat.size = Vector2(36, 4)
	mat.color = Color(0.7, 0.35, 0.3, 1)
	house.add_child(mat)

	# "WELCOME" text on mat
	var welcome := Label.new()
	welcome.text = "WELCOME"
	welcome.add_theme_font_size_override("font_size", 8)
	welcome.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 0.7))
	welcome.position = Vector2(W, -4)
	house.add_child(welcome)

	# --- ROOF (solid, can stand on) ---
	var roof_node := StaticBody2D.new()
	roof_node.position = Vector2(W / 2, -H - ROOF / 2)
	roof_node.collision_layer = 1
	roof_node.collision_mask = 0
	house.add_child(roof_node)
	var roof_col := CollisionShape2D.new()
	var roof_shape := RectangleShape2D.new()
	roof_shape.size = Vector2(W + 24, ROOF)
	roof_col.shape = roof_shape
	roof_node.add_child(roof_col)
	# Main roof
	var roof_vis := ColorRect.new()
	roof_vis.position = Vector2(-(W + 24) / 2, -ROOF / 2)
	roof_vis.size = Vector2(W + 24, ROOF)
	roof_vis.color = Color(0.7, 0.25, 0.15, 1)
	roof_node.add_child(roof_vis)
	# Roof peak (triangular feel)
	var peak := ColorRect.new()
	peak.position = Vector2(-(W - 20) / 2, -ROOF / 2 - 18)
	peak.size = Vector2(W - 20, 18)
	peak.color = Color(0.75, 0.28, 0.18, 1)
	roof_node.add_child(peak)
	# Roof tip
	var tip := ColorRect.new()
	tip.position = Vector2(-(W - 80) / 2, -ROOF / 2 - 28)
	tip.size = Vector2(W - 80, 12)
	tip.color = Color(0.78, 0.3, 0.2, 1)
	roof_node.add_child(tip)

	# --- CHIMNEY ---
	var chimney := ColorRect.new()
	chimney.position = Vector2(30, -H - ROOF - 20)
	chimney.size = Vector2(16, 28)
	chimney.color = Color(0.55, 0.4, 0.35, 1)
	house.add_child(chimney)
	# Chimney cap
	var chimney_cap := ColorRect.new()
	chimney_cap.position = Vector2(28, -H - ROOF - 24)
	chimney_cap.size = Vector2(20, 4)
	chimney_cap.color = Color(0.5, 0.35, 0.3, 1)
	house.add_child(chimney_cap)
	# Smoke puffs
	for i in 3:
		var smoke := ColorRect.new()
		smoke.position = Vector2(34, -H - ROOF - 30 - i * 14)
		smoke.size = Vector2(8 + i * 4, 8 + i * 3)
		smoke.color = Color(0.85, 0.85, 0.85, 0.25 - i * 0.07)
		house.add_child(smoke)

	# --- INTERIOR DECORATIONS ---

	# Back wall window with warm light
	var win_frame := ColorRect.new()
	win_frame.z_index = -1
	win_frame.position = Vector2(W * 0.35, -H + 30)
	win_frame.size = Vector2(30, 26)
	win_frame.color = Color(0.5, 0.32, 0.15, 1)
	house.add_child(win_frame)
	var win_glass := ColorRect.new()
	win_glass.z_index = -1
	win_glass.position = Vector2(W * 0.35 + 3, -H + 33)
	win_glass.size = Vector2(24, 20)
	win_glass.color = Color(0.7, 0.85, 1.0, 0.8)
	house.add_child(win_glass)
	var win_cross_h := ColorRect.new()
	win_cross_h.z_index = -1
	win_cross_h.position = Vector2(W * 0.35 + 3, -H + 42)
	win_cross_h.size = Vector2(24, 2)
	win_cross_h.color = Color(0.5, 0.32, 0.15, 1)
	house.add_child(win_cross_h)
	var win_cross_v := ColorRect.new()
	win_cross_v.z_index = -1
	win_cross_v.position = Vector2(W * 0.35 + 14, -H + 33)
	win_cross_v.size = Vector2(2, 20)
	win_cross_v.color = Color(0.5, 0.32, 0.15, 1)
	house.add_child(win_cross_v)

	# Fireplace on left wall
	var fireplace := ColorRect.new()
	fireplace.z_index = -1
	fireplace.position = Vector2(WALL + 8, -44)
	fireplace.size = Vector2(30, 44)
	fireplace.color = Color(0.45, 0.35, 0.3, 1)
	house.add_child(fireplace)
	var mantel := ColorRect.new()
	mantel.z_index = -1
	mantel.position = Vector2(WALL + 4, -48)
	mantel.size = Vector2(38, 6)
	mantel.color = Color(0.55, 0.38, 0.22, 1)
	house.add_child(mantel)
	# Fire glow
	var fire1 := ColorRect.new()
	fire1.z_index = -1
	fire1.position = Vector2(WALL + 14, -22)
	fire1.size = Vector2(12, 16)
	fire1.color = Color(1.0, 0.6, 0.1, 0.8)
	house.add_child(fire1)
	var fire2 := ColorRect.new()
	fire2.z_index = -1
	fire2.position = Vector2(WALL + 18, -28)
	fire2.size = Vector2(6, 10)
	fire2.color = Color(1.0, 0.85, 0.2, 0.9)
	house.add_child(fire2)
	# Warm fire glow on floor
	var fire_glow := ColorRect.new()
	fire_glow.z_index = -1
	fire_glow.position = Vector2(WALL + 6, -10)
	fire_glow.size = Vector2(50, 10)
	fire_glow.color = Color(1.0, 0.7, 0.3, 0.1)
	house.add_child(fire_glow)

	# Cozy bed on right side
	var bed_frame := ColorRect.new()
	bed_frame.z_index = -1
	bed_frame.position = Vector2(W - WALL - 60, -18)
	bed_frame.size = Vector2(48, 18)
	bed_frame.color = Color(0.5, 0.32, 0.18, 1)
	house.add_child(bed_frame)
	var mattress := ColorRect.new()
	mattress.z_index = -1
	mattress.position = Vector2(W - WALL - 58, -26)
	mattress.size = Vector2(44, 10)
	mattress.color = Color(0.55, 0.4, 0.75, 1)
	house.add_child(mattress)
	var pillow := ColorRect.new()
	pillow.z_index = -1
	pillow.position = Vector2(W - WALL - 58, -30)
	pillow.size = Vector2(14, 6)
	pillow.color = Color(1, 1, 1, 0.85)
	house.add_child(pillow)
	var blanket := ColorRect.new()
	blanket.z_index = -1
	blanket.position = Vector2(W - WALL - 40, -28)
	blanket.size = Vector2(26, 12)
	blanket.color = Color(0.7, 0.3, 0.35, 0.8)
	house.add_child(blanket)

	# Small rug in center
	var rug := ColorRect.new()
	rug.z_index = -1
	rug.position = Vector2(W * 0.35, -5)
	rug.size = Vector2(40, 5)
	rug.color = Color(0.65, 0.25, 0.25, 0.6)
	house.add_child(rug)

	# Flower box under exterior left wall window
	var ext_win_frame := ColorRect.new()
	ext_win_frame.position = Vector2(-2, -H + 30)
	ext_win_frame.size = Vector2(14, 20)
	ext_win_frame.color = Color(0.5, 0.32, 0.15, 1)
	house.add_child(ext_win_frame)
	var ext_win_glass := ColorRect.new()
	ext_win_glass.position = Vector2(0, -H + 33)
	ext_win_glass.size = Vector2(10, 14)
	ext_win_glass.color = Color(1.0, 0.9, 0.5, 0.7)
	house.add_child(ext_win_glass)

	# Flower box under exterior window
	var fbox := ColorRect.new()
	fbox.position = Vector2(-4, -H + 52)
	fbox.size = Vector2(18, 5)
	fbox.color = Color(0.45, 0.3, 0.15, 1)
	house.add_child(fbox)
	var flower_colors := [Color(1, 0.4, 0.5), Color(1, 0.85, 0.2), Color(0.7, 0.4, 1)]
	for f in 3:
		var fl := ColorRect.new()
		fl.position = Vector2(-2 + f * 6, -H + 47)
		fl.size = Vector2(4, 5)
		fl.color = flower_colors[f]
		house.add_child(fl)

	# "HOME" sign above door
	var sign_board := ColorRect.new()
	sign_board.position = Vector2(W - WALL - 4, -DOOR_H - 18)
	sign_board.size = Vector2(WALL + 14, 12)
	sign_board.color = Color(0.5, 0.32, 0.18, 1)
	house.add_child(sign_board)
	var home_label := Label.new()
	home_label.text = "HOME"
	home_label.add_theme_font_size_override("font_size", 10)
	home_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	home_label.position = Vector2(W - WALL - 1, -DOOR_H - 17)
	house.add_child(home_label)

	# === TELEPORT ROOM (attached to right side of house) ===
	var TR_W := 100.0   # Teleport room width
	var TR_H := 140.0   # Teleport room height
	var TR_X := W + 6   # Start just past right wall
	var TR_WALL := 10.0

	# Teleport room floor (solid, with own foundation)
	var tr_floor := StaticBody2D.new()
	tr_floor.position = Vector2(TR_X + TR_W / 2, 4)
	tr_floor.collision_layer = 1
	tr_floor.collision_mask = 0
	house.add_child(tr_floor)
	var trf_col := CollisionShape2D.new()
	var trf_shape := RectangleShape2D.new()
	trf_shape.size = Vector2(TR_W + 20, 200)  # Deep foundation
	trf_col.shape = trf_shape
	trf_col.position = Vector2(0, 100)
	tr_floor.add_child(trf_col)
	var trf_vis := ColorRect.new()
	trf_vis.position = Vector2(-(TR_W + 20) / 2, -4)
	trf_vis.size = Vector2(TR_W + 20, 8)
	trf_vis.color = Color(0.35, 0.35, 0.4, 1)  # Stone floor
	tr_floor.add_child(trf_vis)
	# Underground fill
	var trf_fill := ColorRect.new()
	trf_fill.position = Vector2(-(TR_W + 20) / 2, 4)
	trf_fill.size = Vector2(TR_W + 20, 196)
	trf_fill.color = Color(0.3, 0.3, 0.35, 1)
	tr_floor.add_child(trf_fill)

	# Right wall of teleport room
	var tr_rw := StaticBody2D.new()
	tr_rw.position = Vector2(TR_X + TR_W - TR_WALL / 2, -TR_H / 2)
	tr_rw.collision_layer = 1
	tr_rw.collision_mask = 0
	house.add_child(tr_rw)
	var trw_col := CollisionShape2D.new()
	var trw_shape := RectangleShape2D.new()
	trw_shape.size = Vector2(TR_WALL, TR_H)
	trw_col.shape = trw_shape
	tr_rw.add_child(trw_col)
	var trw_vis := ColorRect.new()
	trw_vis.position = Vector2(-TR_WALL / 2, -TR_H / 2)
	trw_vis.size = Vector2(TR_WALL, TR_H)
	trw_vis.color = Color(0.45, 0.4, 0.5, 1)  # Dark stone
	tr_rw.add_child(trw_vis)

	# Teleport room roof
	var tr_roof := StaticBody2D.new()
	tr_roof.position = Vector2(TR_X + TR_W / 2, -TR_H - 6)
	tr_roof.collision_layer = 1
	tr_roof.collision_mask = 0
	house.add_child(tr_roof)
	var trr_col := CollisionShape2D.new()
	var trr_shape := RectangleShape2D.new()
	trr_shape.size = Vector2(TR_W + 10, 12)
	trr_col.shape = trr_shape
	tr_roof.add_child(trr_col)
	var trr_vis := ColorRect.new()
	trr_vis.position = Vector2(-(TR_W + 10) / 2, -6)
	trr_vis.size = Vector2(TR_W + 10, 12)
	trr_vis.color = Color(0.4, 0.35, 0.45, 1)
	tr_roof.add_child(trr_vis)

	# Interior background (dark mystical)
	var tr_interior := ColorRect.new()
	tr_interior.z_index = -2
	tr_interior.position = Vector2(TR_X + TR_WALL, -TR_H + TR_WALL)
	tr_interior.size = Vector2(TR_W - TR_WALL * 2, TR_H - TR_WALL)
	tr_interior.color = Color(0.12, 0.08, 0.18, 1)
	house.add_child(tr_interior)

	# Mystical runes on floor
	var rune_colors := [Color(0.8, 0.3, 0.1, 0.4), Color(0.6, 0.2, 0.8, 0.3), Color(0.9, 0.5, 0.1, 0.35)]
	for i in 3:
		var rune := ColorRect.new()
		rune.z_index = -1
		rune.position = Vector2(TR_X + 20 + i * 22, -8)
		rune.size = Vector2(16, 4)
		rune.color = rune_colors[i]
		house.add_child(rune)

	# "PORTAL" sign above entrance
	var portal_sign := ColorRect.new()
	portal_sign.position = Vector2(TR_X - 4, -TR_H - 20)
	portal_sign.size = Vector2(TR_W + 8, 16)
	portal_sign.color = Color(0.25, 0.15, 0.35, 0.9)
	house.add_child(portal_sign)
	var portal_label := Label.new()
	portal_label.text = "PORTAL ROOM"
	portal_label.add_theme_font_size_override("font_size", 11)
	portal_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	portal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal_label.position = Vector2(TR_X - 2, -TR_H - 19)
	portal_label.size = Vector2(TR_W + 4, 14)
	house.add_child(portal_label)

	# Glowing torch on each side of entrance
	for side in [0, 1]:
		var torch_x := TR_X - 8 if side == 0 else TR_X + TR_W - 2
		var torch := ColorRect.new()
		torch.position = Vector2(torch_x, -TR_H + 20)
		torch.size = Vector2(4, 16)
		torch.color = Color(0.5, 0.35, 0.15, 1)
		house.add_child(torch)
		var flame := ColorRect.new()
		flame.position = Vector2(torch_x - 2, -TR_H + 12)
		flame.size = Vector2(8, 10)
		flame.color = Color(1.0, 0.6, 0.1, 0.7)
		house.add_child(flame)
		var flame_core := ColorRect.new()
		flame_core.position = Vector2(torch_x, -TR_H + 14)
		flame_core.size = Vector2(4, 6)
		flame_core.color = Color(1.0, 0.9, 0.3, 0.8)
		house.add_child(flame_core)

	scene_root.add_child(house)

	# Pop-in animation
	house.scale = Vector2(0.1, 0.1)
	var tween := house.create_tween()
	tween.tween_property(house, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(house, "scale", Vector2(1.0, 1.0), 0.2)

	# Store home position for companion management and teleport
	# Teleport room center (where the return portal goes)
	_home_node = house
	GameManager.home_pos_x = house.global_position.x + TR_X + TR_W / 2  # Center of teleport room
	GameManager.home_pos_y = house.global_position.y - 40               # Above floor inside teleport room
	GameManager.save_game()

	# Send idle companions to home now that it exists
	for word in _companions:
		if is_instance_valid(_companions[word]) and word not in GameManager.active_companions:
			_send_companion_home(_companions[word])

	# Hide ColorRect visuals when castle sprite is present
	if _has_castle_sprite:
		_hide_colorrects_recursive(house)

	print("Francis-opia: A cozy house appeared! Walk through the door to go inside!")
	return house

func _summon_portal_unlock(_scene_root: Node, player: Node2D, _pos: Vector2) -> Node:
	# Portal is an ability unlock — no physical summon, just enables LT+RT beacon placement
	# Show a brief visual effect on the player
	var effect := Node2D.new()
	effect.name = "PortalUnlockEffect"
	effect.global_position = player.global_position
	_scene_root.add_child(effect)

	# Purple swirl particles
	for i in 12:
		var particle := ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(0.6, 0.2, 0.9, 0.8)
		particle.z_index = 10
		effect.add_child(particle)
		var angle := TAU * float(i) / 12.0
		var start := Vector2(cos(angle) * 10, sin(angle) * 10 - 20)
		var end := Vector2(cos(angle) * 60, sin(angle) * 60 - 20)
		particle.position = start
		var tween := particle.create_tween()
		tween.tween_property(particle, "position", end, 0.8)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_callback(particle.queue_free)

	# Clean up container after animation
	var cleanup_tween := effect.create_tween()
	cleanup_tween.tween_interval(1.0)
	cleanup_tween.tween_callback(effect.queue_free)

	print("Francis-opia: Portal magic unlocked! Press LT+RT to place a portal!")
	return effect

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
