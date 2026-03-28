extends Node
## Reusable VFX system for word magic effects.
## Provides GPUParticles2D sparkle bursts, camera zoom/shake,
## letter trail particles, and warm atmosphere flashes.

# === COLOR CODING ===
# Consistent palette: gold=magic/items, green=nature/pets, blue=water/special
const COLOR_MAGIC := Color(1.0, 0.85, 0.2, 1.0)    # Gold — word completion, items
const COLOR_NATURE := Color(0.3, 0.9, 0.35, 1.0)    # Green — pets, nature summons
const COLOR_WATER := Color(0.3, 0.6, 1.0, 1.0)      # Blue — water, special effects
const COLOR_COSMETIC := Color(0.85, 0.5, 1.0, 1.0)  # Purple — cosmetic effects

# Camera effect settings (gentle for young children)
const CAMERA_ZOOM_IN := 1.15
const CAMERA_ZOOM_DURATION_IN := 0.3
const CAMERA_ZOOM_DURATION_OUT := 0.5
const CAMERA_SHAKE_MAX := 3.0  # Max pixels offset
const CAMERA_SHAKE_DURATION := 0.5

var _camera_tween: Tween = null
var _shake_tween: Tween = null
var _atmosphere_tween: Tween = null
var _camera_base_zoom := Vector2(1.0, 1.0)  # Stable base zoom to return to

func get_color_for_type(summon_type: String) -> Color:
	match summon_type:
		"pet": return COLOR_NATURE
		"world": return COLOR_MAGIC
		"item": return COLOR_WATER
		"cosmetic": return COLOR_COSMETIC
		_: return COLOR_MAGIC


# === GPUParticles2D SPARKLE BURST ===

func spawn_sparkle_burst(parent: Node, pos: Vector2, color: Color, count: int = 24) -> void:
	## Radial sparkle burst using GPUParticles2D. Auto-frees after emission.
	var particles := GPUParticles2D.new()
	particles.z_index = 25
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = 0.8
	particles.explosiveness = 0.9  # All at once
	particles.randomness = 0.3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0  # Full radial
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3(0, 40, 0)  # Slight downward pull
	mat.damping_min = 20.0
	mat.damping_max = 40.0

	# Scale: 6px -> 1px over lifetime
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	mat.scale_curve = _create_fade_curve()

	# Color: full -> transparent
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = color_ramp
	mat.color_ramp = gradient_tex

	particles.process_material = mat

	# Simple square texture for particles
	var tex := _create_particle_texture(6)
	particles.texture = tex

	parent.add_child(particles)

	# Auto-free after particles finish
	var timer := get_tree().create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func spawn_trail_particles(parent: Node, from_pos: Vector2, color: Color, count: int = 5) -> void:
	## Small sparkle trail that floats upward (toward HUD area).
	for i in count:
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = from_pos + Vector2(randf_range(-15, 15), randf_range(-10, 10))
		particle.color = color
		particle.z_index = 20

		parent.add_child(particle)

		# Float upward and slightly random horizontal drift
		var target := particle.position + Vector2(randf_range(-30, 30), -200 - randf_range(0, 100))
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, 0.5 + randf_range(0, 0.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.5)
		tween.chain().tween_callback(particle.queue_free)


# === CAMERA EFFECTS ===

func camera_word_complete(camera: Camera2D) -> void:
	## Gentle zoom-in + micro-shake for word completion. Safe for young children.
	if not camera:
		return

	# Cancel existing camera tweens and restore base zoom
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
		camera.zoom = _camera_base_zoom
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	# Capture base zoom only if not mid-effect (prevents drift)
	_camera_base_zoom = camera.zoom

	# Zoom in then back to base
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "zoom",
		_camera_base_zoom * CAMERA_ZOOM_IN,
		CAMERA_ZOOM_DURATION_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "zoom",
		_camera_base_zoom,
		CAMERA_ZOOM_DURATION_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Gentle shake
	_do_camera_shake(camera, CAMERA_SHAKE_DURATION)


func _do_camera_shake(camera: Camera2D, duration: float) -> void:
	var original_offset := camera.offset
	_shake_tween = create_tween()
	# 8 small shake steps over duration
	var steps := 8
	var step_time := duration / float(steps)
	for i in steps:
		var intensity := CAMERA_SHAKE_MAX * (1.0 - float(i) / float(steps))  # Decay
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		_shake_tween.tween_property(camera, "offset", original_offset + offset, step_time)
	_shake_tween.tween_property(camera, "offset", original_offset, step_time)


# === WARM ATMOSPHERE FLASH ===

func flash_warm_atmosphere(scene_root: Node) -> void:
	## Brief subtle golden warmth on screen during magic moments.
	# Remove existing warmth node to prevent CanvasModulate stacking
	var existing := scene_root.get_node_or_null("MagicWarmth")
	if existing:
		existing.queue_free()

	if _atmosphere_tween and _atmosphere_tween.is_valid():
		_atmosphere_tween.kill()

	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "MagicWarmth"
	canvas_mod.color = Color(1.0, 1.0, 1.0, 1.0)  # Start neutral
	scene_root.add_child(canvas_mod)

	_atmosphere_tween = create_tween()
	# Warm golden tint — subtle, not overwhelming
	_atmosphere_tween.tween_property(canvas_mod, "color",
		Color(1.05, 1.0, 0.85, 1.0), 0.15)
	_atmosphere_tween.tween_property(canvas_mod, "color",
		Color(1.0, 1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_QUAD)
	_atmosphere_tween.tween_callback(canvas_mod.queue_free)


# === HELPERS ===

func _create_fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(0.5, 0.6))
	curve.add_point(Vector2(1.0, 0.1))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _create_particle_texture(size: int) -> ImageTexture:
	## Creates a simple white square texture for particles.
	## Color is applied via ParticleProcessMaterial color_ramp.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
