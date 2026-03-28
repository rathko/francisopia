extends Node
## Unit tests for SpriteLoader. Tests fallback behavior when sprites don't exist.

const SpriteLoader = preload("res://scripts/world/SpriteLoader.gd")

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== SpriteLoader Tests ===")
	test_try_load_nonexistent_returns_null()
	test_try_load_visual_nonexistent_returns_null()
	test_try_load_existing_script_returns_null()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_try_load_nonexistent_returns_null() -> void:
	_test_name = "try_load_nonexistent"
	var result = SpriteLoader.try_load("res://assets/sprites/world/tree.tscn")
	assert_true(result == null, "Nonexistent scene should return null")

func test_try_load_visual_nonexistent_returns_null() -> void:
	_test_name = "try_load_visual_nonexistent"
	var result = SpriteLoader.try_load_visual("res://assets/visuals/dog_visual.tres")
	assert_true(result == null, "Nonexistent visual should return null")

func test_try_load_existing_script_returns_null() -> void:
	_test_name = "try_load_script_not_scene"
	# A .gd file is not a PackedScene, should return null
	var result = SpriteLoader.try_load("res://scripts/world/SpriteLoader.gd")
	assert_true(result == null, "Script file is not a scene, should return null")

# --- Test helpers ---

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s - %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s - %s" % [_test_name, message])
