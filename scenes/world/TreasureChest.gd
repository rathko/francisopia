extends StaticBody2D
## A treasure chest found underground or on the surface.
## Press interact to open! Gives coins and drops several letters to choose from.
## The right letter for the current word is always included, plus distractors.

var _opened := false
var _coin_reward := 3

func _ready() -> void:
	_coin_reward = randi_range(3, 5)
	collision_layer = 4  # Interactable layer

func interact() -> void:
	if _opened:
		return
	_opened = true

	# Give coins
	GameManager.add_coins(_coin_reward)

	# Drop letters — needed + distractors for the player to choose
	_drop_letters()

	print("Francis-opia: Found %d coins and some letters!" % _coin_reward)

	# Open animation — lid flies up with golden burst
	var tween := create_tween()
	var lid := get_node_or_null("Lid")
	var lid_highlight := get_node_or_null("LidHighlight")
	if lid:
		tween.tween_property(lid, "position:y", lid.position.y - 35, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(lid, "rotation", -0.3, 0.4)
		tween.tween_property(lid, "modulate:a", 0.0, 0.4)
	if lid_highlight:
		lid_highlight.queue_free()

	# Golden particle burst on open
	var vfx := get_node_or_null("/root/MagicVFX")
	if vfx:
		vfx.spawn_sparkle_burst(get_tree().current_scene, global_position + Vector2(0, -15), MagicVFX.COLOR_MAGIC, 16)

	# Stop idle sparkle
	var idle_sparkle := get_node_or_null("IdleSparkle")
	if idle_sparkle:
		idle_sparkle.queue_free()

	# Dim body to show it's opened
	var body_rect := get_node_or_null("ChestBody")
	if body_rect:
		var dim_tween := body_rect.create_tween()
		dim_tween.tween_property(body_rect, "color", Color(0.4, 0.28, 0.12, 0.6), 0.5)

	# Coin burst text
	var coin_text := Label.new()
	coin_text.text = "+%d" % _coin_reward
	coin_text.add_theme_font_size_override("font_size", 36)
	coin_text.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	coin_text.position = Vector2(-15, -50)
	add_child(coin_text)

	var text_tween := create_tween()
	text_tween.tween_property(coin_text, "position:y", coin_text.position.y - 40, 0.8)
	text_tween.parallel().tween_property(coin_text, "modulate:a", 0.0, 0.8)
	text_tween.tween_callback(coin_text.queue_free)

var _letter_arc: Node2D = null
var _letter_medallions: Array[Node2D] = []  # Container nodes for each medallion
var _letter_labels: Array[Label] = []
var _letter_data: Array[Dictionary] = []
var _selected_index := 0
var _selecting := false
var _player_nearby := false
const PROXIMITY_RANGE := 120.0  # Player must be within this distance to select
const NAV_SOUND_VOLUME := 0.15  # Very quiet navigation feedback

func _drop_letters() -> void:
	var next_needed := WordEngine.get_next_needed_letter()
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

	_letter_data.clear()
	if next_needed != "":
		_letter_data.append({"char": next_needed, "needed": true})

	var distractor_count := randi_range(2, 3)
	for i in distractor_count:
		var d: String = alphabet[randi() % alphabet.length()]
		var attempts := 0
		while d == next_needed and attempts < 10:
			d = alphabet[randi() % alphabet.length()]
			attempts += 1
		_letter_data.append({"char": d, "needed": false})

	_letter_data.shuffle()

	# Create stationary arc of golden medallion letters above the chest
	_letter_arc = Node2D.new()
	_letter_arc.name = "LetterArc"
	_letter_arc.z_index = 20
	_letter_arc.global_position = global_position
	get_tree().current_scene.add_child(_letter_arc)

	_letter_labels.clear()
	_letter_medallions.clear()
	var total := _letter_data.size()
	var arc_radius := 90.0
	var arc_spread := PI * 0.65

	for i in total:
		var entry: Dictionary = _letter_data[i]
		var angle := -PI / 2.0 + arc_spread * (float(i) / float(total - 1) - 0.5) if total > 1 else -PI / 2.0
		var center := Vector2(cos(angle) * arc_radius, sin(angle) * arc_radius - 50)

		var medallion := Node2D.new()
		medallion.position = center
		_letter_arc.add_child(medallion)

		var is_needed: bool = entry["needed"]
		var letter_char: String = str(entry["char"]).to_upper()

		# Try pixel art letter medallion sprite
		var letter_path := "res://assets/sprites/ui/letters/%s.png" % letter_char
		if ResourceLoader.exists(letter_path):
			var tex := load(letter_path) as Texture2D
			if tex:
				var spr := Sprite2D.new()
				spr.texture = tex
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				if is_needed:
					spr.scale = Vector2(1.35, 1.35)  # Big golden coin for needed
				else:
					spr.scale = Vector2(0.9, 0.9)  # Smaller for distractor
					spr.modulate = Color(0.6, 0.6, 0.6, 0.5)  # Dimmed
				medallion.add_child(spr)
		else:
			# Fallback: Label
			var label := Label.new()
			label.text = letter_char
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.position = Vector2(-20, -25)
			if is_needed:
				label.add_theme_font_size_override("font_size", 52)
				label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
			else:
				label.add_theme_font_size_override("font_size", 38)
				label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))
			medallion.add_child(label)

		# Keep a label reference for text (even with sprites, we track by medallion)
		var dummy_label := Label.new()
		dummy_label.text = letter_char
		dummy_label.visible = false
		medallion.add_child(dummy_label)
		_letter_labels.append(dummy_label)
		_letter_medallions.append(medallion)

		# Pop-in animation
		medallion.scale = Vector2.ZERO
		var pop_tween := medallion.create_tween()
		pop_tween.tween_property(medallion, "scale", Vector2(1.0, 1.0), 0.3 + i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_selected_index = 0
	_selecting = true
	_update_selection_highlight()

func _process(_delta: float) -> void:
	if not _selecting or _letter_medallions.is_empty():
		return

	# Check proximity — only allow selection when player is close
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if not player:
		return
	_player_nearby = global_position.distance_to(player.global_position) < PROXIMITY_RANGE

	if not _player_nearby:
		# Dim the arc when player is far
		if _letter_arc:
			_letter_arc.modulate.a = lerp(_letter_arc.modulate.a, 0.4, 0.1)
		return
	else:
		if _letter_arc:
			_letter_arc.modulate.a = lerp(_letter_arc.modulate.a, 1.0, 0.15)

	# Navigate with left/right
	if Input.is_action_just_pressed("move_left"):
		_selected_index = (_selected_index - 1 + _letter_medallions.size()) % _letter_medallions.size()
		_update_selection_highlight()
		# Very quiet nav tick
		SoundFX._play_sound(SoundFX._chime_stream, 1.0, NAV_SOUND_VOLUME)
	elif Input.is_action_just_pressed("move_right"):
		_selected_index = (_selected_index + 1) % _letter_medallions.size()
		_update_selection_highlight()
		SoundFX._play_sound(SoundFX._chime_stream, 1.0, NAV_SOUND_VOLUME)
	elif Input.is_action_just_pressed("interact"):
		_select_letter()

func _update_selection_highlight() -> void:
	for i in _letter_medallions.size():
		var med := _letter_medallions[i]
		if i == _selected_index:
			# Selected: bright, scaled up, with glow
			med.modulate = Color(1.3, 1.2, 1.0, 1.0)
			med.scale = Vector2(1.25, 1.25)
		else:
			med.modulate = Color(1.0, 1.0, 1.0, 1.0)
			med.scale = Vector2(1.0, 1.0)

func _select_letter() -> void:
	if _selected_index < 0 or _selected_index >= _letter_data.size():
		return

	var entry: Dictionary = _letter_data[_selected_index]
	var letter_char: String = entry["char"]
	var is_needed: bool = entry["needed"]

	if WordEngine.try_collect_letter(letter_char):
		# Correct! Play phoneme and chime
		var phoneme_node := get_node_or_null("/root/PhonemePlayer")
		if phoneme_node:
			var pos := WordEngine.collected_letters.size() - 1
			phoneme_node.play_phoneme_for_position(WordEngine.current_target_word, pos)
		# Delayed chime
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			SoundFX.play_letter_chime(WordEngine.collected_letters.size() - 1)
		)
		# Trail particles from medallion position
		var vfx := get_node_or_null("/root/MagicVFX")
		var summon := get_node_or_null("/root/MagicSummon")
		if vfx and summon:
			var summon_type: String = summon.get_summon_type_for_word(
				WordEngine.current_target_word.to_lower())
			var trail_color: Color = vfx.get_color_for_type(summon_type)
			var med_pos := _letter_arc.global_position + _letter_medallions[_selected_index].position
			vfx.spawn_trail_particles(get_tree().current_scene, med_pos, trail_color, 5)
		# Remove selected medallion with animation
		var med := _letter_medallions[_selected_index]
		var tween := med.create_tween()
		tween.tween_property(med, "scale", Vector2(1.5, 1.5), 0.2)
		tween.parallel().tween_property(med, "modulate:a", 0.0, 0.2)
		tween.tween_callback(med.queue_free)
		_selecting = false
		# Clean up remaining letters after a moment
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(_letter_arc):
				var fade := _letter_arc.create_tween()
				fade.tween_property(_letter_arc, "modulate:a", 0.0, 0.3)
				fade.tween_callback(_letter_arc.queue_free)
		)
	else:
		# Wrong letter — shake medallion + tap sound
		SoundFX.play_wrong_letter()
		var med := _letter_medallions[_selected_index]
		var orig_pos := med.position
		var shake_tween := med.create_tween()
		shake_tween.tween_property(med, "position", orig_pos + Vector2(8, 0), 0.05)
		shake_tween.tween_property(med, "position", orig_pos - Vector2(8, 0), 0.05)
		shake_tween.tween_property(med, "position", orig_pos, 0.05)
