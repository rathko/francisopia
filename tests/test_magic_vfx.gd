extends Node
## Unit tests for MagicVFX: color coding, camera constants, particle creation.

const MagicVFXScript = preload("res://scripts/autoload/MagicVFX.gd")

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== MagicVFX Tests ===")
	test_color_for_pet_type()
	test_color_for_world_type()
	test_color_for_item_type()
	test_color_for_cosmetic_type()
	test_color_for_unknown_type()
	test_camera_shake_max_is_child_safe()
	test_camera_zoom_is_subtle()
	test_color_constants_are_opaque()
	test_sparkle_burst_creates_node()
	test_trail_particles_creates_nodes()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])


func test_color_for_pet_type() -> void:
	_test_name = "color_for_pet"
	var vfx := _get_vfx()
	var color: Color = vfx.get_color_for_type("pet")
	assert_eq(color, MagicVFXScript.COLOR_NATURE, "Pet type should return nature green")


func test_color_for_world_type() -> void:
	_test_name = "color_for_world"
	var vfx := _get_vfx()
	var color: Color = vfx.get_color_for_type("world")
	assert_eq(color, MagicVFXScript.COLOR_MAGIC, "World type should return magic gold")


func test_color_for_item_type() -> void:
	_test_name = "color_for_item"
	var vfx := _get_vfx()
	var color: Color = vfx.get_color_for_type("item")
	assert_eq(color, MagicVFXScript.COLOR_WATER, "Item type should return water blue")


func test_color_for_cosmetic_type() -> void:
	_test_name = "color_for_cosmetic"
	var vfx := _get_vfx()
	var color: Color = vfx.get_color_for_type("cosmetic")
	assert_eq(color, MagicVFXScript.COLOR_COSMETIC, "Cosmetic type should return purple")


func test_color_for_unknown_type() -> void:
	_test_name = "color_for_unknown"
	var vfx := _get_vfx()
	var color: Color = vfx.get_color_for_type("nonexistent")
	assert_eq(color, MagicVFXScript.COLOR_MAGIC, "Unknown type should fallback to magic gold")


func test_camera_shake_max_is_child_safe() -> void:
	_test_name = "camera_shake_child_safe"
	assert_true(MagicVFXScript.CAMERA_SHAKE_MAX <= 5.0,
		"Camera shake max should be <= 5px for children (got %f)" % MagicVFXScript.CAMERA_SHAKE_MAX)


func test_camera_zoom_is_subtle() -> void:
	_test_name = "camera_zoom_subtle"
	assert_true(MagicVFXScript.CAMERA_ZOOM_IN <= 1.3,
		"Camera zoom should be subtle <= 1.3x (got %f)" % MagicVFXScript.CAMERA_ZOOM_IN)
	assert_true(MagicVFXScript.CAMERA_ZOOM_IN >= 1.05,
		"Camera zoom should be noticeable >= 1.05x (got %f)" % MagicVFXScript.CAMERA_ZOOM_IN)


func test_color_constants_are_opaque() -> void:
	_test_name = "color_constants_opaque"
	var colors := [
		MagicVFXScript.COLOR_MAGIC,
		MagicVFXScript.COLOR_NATURE,
		MagicVFXScript.COLOR_WATER,
		MagicVFXScript.COLOR_COSMETIC,
	]
	for c in colors:
		if c.a != 1.0:
			assert_true(false, "Color constant has alpha != 1.0: %s" % str(c))
			return
	assert_true(true, "All color constants are fully opaque")


func test_sparkle_burst_creates_node() -> void:
	_test_name = "sparkle_burst_creates_node"
	var vfx := _get_vfx()
	var parent := Node2D.new()
	add_child(parent)
	var child_count_before := parent.get_child_count()
	vfx.spawn_sparkle_burst(parent, Vector2.ZERO, Color.WHITE, 8)
	var child_count_after := parent.get_child_count()
	assert_true(child_count_after > child_count_before,
		"Sparkle burst should add child node (before=%d after=%d)" % [child_count_before, child_count_after])
	# Verify it's a GPUParticles2D
	var last_child := parent.get_child(parent.get_child_count() - 1)
	assert_true(last_child is GPUParticles2D,
		"Sparkle burst should create GPUParticles2D (got %s)" % last_child.get_class())
	parent.queue_free()


func test_trail_particles_creates_nodes() -> void:
	_test_name = "trail_particles_creates_nodes"
	var vfx := _get_vfx()
	var parent := Node2D.new()
	add_child(parent)
	vfx.spawn_trail_particles(parent, Vector2.ZERO, Color.WHITE, 5)
	assert_eq(parent.get_child_count(), 5,
		"Trail particles should create exactly 5 children")
	parent.queue_free()


func _get_vfx() -> Node:
	var vfx := get_node_or_null("/root/MagicVFX")
	if vfx:
		return vfx
	# Fallback: create instance for pure unit testing
	vfx = Node.new()
	vfx.set_script(MagicVFXScript)
	vfx.name = "MagicVFX"
	add_child(vfx)
	return vfx


# --- Test helpers ---

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s - %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s - %s" % [_test_name, message])

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s - %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s - %s (got %s, expected %s)" % [_test_name, message, str(actual), str(expected)])
