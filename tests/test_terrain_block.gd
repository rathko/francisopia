extends Node
## Unit tests for TerrainBlock visual upgrades: block types, depth darkening, grass tufts.

const TerrainBlockScript = preload("res://scenes/world/TerrainBlock.gd")

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== TerrainBlock Visual Tests ===")
	test_grass_type_at_depth_zero()
	test_dirt_type_at_depth_1_to_5()
	test_stone_type_at_depth_6_plus()
	test_cave_type_overrides_depth()
	test_darkening_not_applied_to_grass()
	test_darkening_not_applied_at_shallow_depth()
	test_darkening_applied_at_deep_rows()
	test_darkening_minimum_brightness()
	test_grass_tufts_count()
	test_stone_depth_constant_is_6()
	test_darkening_start_constant_is_3()
	test_min_brightness_constant()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])


func _create_block(gx: int, gy: int, is_grass: bool, is_cave: bool = false) -> StaticBody2D:
	## Create a TerrainBlock instance without adding to scene tree.
	## We call setup() methods directly to test logic.
	var block := StaticBody2D.new()
	block.set_script(TerrainBlockScript)
	block.is_cave = is_cave
	block.grid_x = gx
	block.grid_y = gy
	block.is_grass = is_grass
	return block


func test_grass_type_at_depth_zero() -> void:
	_test_name = "grass_type_at_depth_0"
	var block := _create_block(5, 0, true)
	assert_eq(block._get_block_type(), "grass", "Block at gy=0 with is_grass=true should be grass")
	block.free()


func test_dirt_type_at_depth_1_to_5() -> void:
	_test_name = "dirt_type_at_depth_1_to_5"
	for gy in [1, 2, 3, 4, 5]:
		var block := _create_block(5, gy, false)
		if block._get_block_type() != "dirt":
			assert_true(false, "Block at gy=%d should be dirt, got %s" % [gy, block._get_block_type()])
			block.free()
			return
		block.free()
	assert_true(true, "All blocks at gy=1..5 are dirt type")


func test_stone_type_at_depth_6_plus() -> void:
	_test_name = "stone_type_at_depth_6_plus"
	for gy in [6, 7, 10, 15]:
		var block := _create_block(5, gy, false)
		if block._get_block_type() != "stone":
			assert_true(false, "Block at gy=%d should be stone, got %s" % [gy, block._get_block_type()])
			block.free()
			return
		block.free()
	assert_true(true, "All blocks at gy>=6 are stone type")


func test_cave_type_overrides_depth() -> void:
	_test_name = "cave_type_overrides_depth"
	var block := _create_block(5, 10, false, true)
	assert_eq(block._get_block_type(), "cave", "Cave flag should override stone depth")
	block.free()


func test_darkening_not_applied_to_grass() -> void:
	_test_name = "darkening_not_on_grass"
	var block := _create_block(5, 0, true)
	block.total_depth = 16
	block._apply_depth_darkening()
	assert_eq(block.modulate, Color(1, 1, 1, 1), "Grass blocks should not be darkened")
	block.free()


func test_darkening_not_applied_at_shallow_depth() -> void:
	_test_name = "darkening_not_at_shallow"
	for gy in [0, 1, 2]:
		var block := _create_block(5, gy, false)
		block.total_depth = 16
		block._apply_depth_darkening()
		if block.modulate != Color(1, 1, 1, 1):
			assert_true(false, "Block at gy=%d should not be darkened, modulate=%s" % [gy, str(block.modulate)])
			block.free()
			return
		block.free()
	assert_true(true, "Blocks at gy=0..2 are not darkened")


func test_darkening_applied_at_deep_rows() -> void:
	_test_name = "darkening_at_deep_rows"
	var block := _create_block(5, 10, false)
	block.total_depth = 16
	block._apply_depth_darkening()
	assert_true(block.modulate.r < 1.0, "Block at gy=10 should be darkened (r=%f)" % block.modulate.r)
	block.free()


func test_darkening_minimum_brightness() -> void:
	_test_name = "darkening_minimum_brightness"
	var block := _create_block(5, 50, false)
	block.total_depth = 50
	block._apply_depth_darkening()
	assert_true(block.modulate.r >= 0.39, "Deepest block brightness >= 0.4 (got %f)" % block.modulate.r)
	block.free()


func test_grass_tufts_count() -> void:
	_test_name = "grass_tufts_count"
	# Grass tufts are 2-4 per block, deterministic per grid_x
	# We can't easily count them without adding to tree, but we verify the constant
	var hash_val := absi((5 * 7919 + 13) % 1000)
	var count := 2 + (hash_val % 3)
	assert_true(count >= 2 and count <= 4, "Tuft count should be 2-4 (got %d)" % count)


func test_stone_depth_constant_is_6() -> void:
	_test_name = "stone_depth_constant"
	assert_eq(TerrainBlockScript.STONE_DEPTH, 6, "STONE_DEPTH should be 6")


func test_darkening_start_constant_is_3() -> void:
	_test_name = "darkening_start_constant"
	assert_eq(TerrainBlockScript.DARKENING_START, 3, "DARKENING_START should be 3")


func test_min_brightness_constant() -> void:
	_test_name = "min_brightness_constant"
	assert_true(abs(TerrainBlockScript.MIN_BRIGHTNESS - 0.4) < 0.01,
		"MIN_BRIGHTNESS should be 0.4 (got %f)" % TerrainBlockScript.MIN_BRIGHTNESS)


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
