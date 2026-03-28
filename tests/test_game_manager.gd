extends Node
## Unit tests for GameManager. Tests save/load, coins, companions, and progression tracking.

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== GameManager Tests ===")
	test_initial_state()
	test_coin_reward_scaling()
	test_add_coins()
	test_complete_word()
	test_complete_word_duplicate()
	test_area_change()
	test_active_companions_is_array()
	test_big_scale_default()
	test_teleport_fields_default()
	test_save_load_roundtrip()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_initial_state() -> void:
	_test_name = "initial_state"
	assert_eq(GameManager.planet_name, "Francis-opia", "Default planet name")
	assert_true(GameManager.word_coins >= 0, "Coins should be non-negative")

func test_coin_reward_scaling() -> void:
	_test_name = "coin_reward_scaling"
	if GameManager.has_method("_coin_reward_for_word"):
		assert_eq(GameManager._coin_reward_for_word("cat"), 1, "3-letter = 1 coin")
		assert_eq(GameManager._coin_reward_for_word("frog"), 2, "4-letter = 2 coins")
		assert_eq(GameManager._coin_reward_for_word("flower"), 3, "6-letter = 3 coins")
		assert_eq(GameManager._coin_reward_for_word("a"), 1, "1-letter = 1 coin minimum")
	else:
		print("  SKIP: %s -- _coin_reward_for_word not found" % _test_name)

func test_add_coins() -> void:
	_test_name = "add_coins"
	var before := GameManager.word_coins
	GameManager.add_coins(5)
	assert_eq(GameManager.word_coins, before + 5, "Coins should increase by 5")
	# Restore
	GameManager.word_coins = before

func test_complete_word() -> void:
	_test_name = "complete_word"
	var before_count := GameManager.words_completed.size()
	GameManager.complete_word("testword")
	assert_eq(GameManager.words_completed.size(), before_count + 1, "Words completed should grow")
	assert_true("testword" in GameManager.words_completed, "Word should be in completed list")
	# Cleanup
	GameManager.words_completed.erase("testword")

func test_complete_word_duplicate() -> void:
	_test_name = "complete_word_duplicate"
	GameManager.complete_word("duptest")
	var count_after_first := GameManager.words_completed.size()
	GameManager.complete_word("duptest")
	var count_after_second := GameManager.words_completed.size()
	assert_true(count_after_second >= count_after_first, "Should not crash on duplicate word")
	# Cleanup
	while "duptest" in GameManager.words_completed:
		GameManager.words_completed.erase("duptest")

func test_area_change() -> void:
	_test_name = "area_change"
	var original_area := GameManager.current_area
	GameManager.change_area("beach")
	assert_eq(GameManager.current_area, "beach", "Area should change to beach")
	# Restore
	GameManager.current_area = original_area

func test_active_companions_is_array() -> void:
	_test_name = "active_companions_is_array"
	assert_true(GameManager.active_companions is Array, "active_companions should be an Array")
	assert_true(GameManager.active_companions.size() <= 3, "active_companions should have at most 3 entries (got %d)" % GameManager.active_companions.size())

func test_big_scale_default() -> void:
	_test_name = "big_scale_default"
	assert_true(GameManager.big_scale >= 1.0, "big_scale should be >= 1.0")
	assert_true(GameManager.big_scale <= 2.0, "big_scale should be <= 2.0 (got %f)" % GameManager.big_scale)

func test_teleport_fields_default() -> void:
	_test_name = "teleport_fields_default"
	# These may be non-zero if game has been played; just verify they exist
	assert_true("teleport_beacon_x" in GameManager, "Should have teleport_beacon_x field")
	assert_true("teleport_beacon_y" in GameManager, "Should have teleport_beacon_y field")
	assert_true("home_pos_x" in GameManager, "Should have home_pos_x field")
	assert_true("home_pos_y" in GameManager, "Should have home_pos_y field")

func test_save_load_roundtrip() -> void:
	_test_name = "save_load_roundtrip"
	var original_coins := GameManager.word_coins
	var original_name := GameManager.planet_name
	var original_companions := GameManager.active_companions.duplicate()
	# Modify state
	GameManager.word_coins = 999
	GameManager.planet_name = "TestPlanet"
	GameManager.save_game()
	# Reset
	GameManager.word_coins = 0
	GameManager.planet_name = ""
	# Load
	GameManager.load_game()
	assert_eq(GameManager.word_coins, 999, "Coins should survive save/load")
	assert_eq(GameManager.planet_name, "TestPlanet", "Planet name should survive save/load")
	assert_true(GameManager.active_companions is Array, "active_companions should survive save/load as Array")
	# Restore original
	GameManager.word_coins = original_coins
	GameManager.planet_name = original_name
	GameManager.active_companions = original_companions
	GameManager.save_game()

# --- Test helpers ---

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s -- %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s -- %s" % [_test_name, message])

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s -- %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s -- %s (got %s, expected %s)" % [_test_name, message, str(actual), str(expected)])
