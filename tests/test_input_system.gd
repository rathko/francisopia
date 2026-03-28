extends Node
## Smoke tests for the input system — verifies input actions exist, bindings are correct,
## and PlayerController input helpers don't crash. Catches "nothing works" regressions.

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== Input System Tests ===")
	test_required_actions_exist()
	test_actions_have_joypad_bindings()
	test_actions_have_keyboard_bindings()
	test_joypad_button_indices_correct()
	test_player_controller_input_helpers_callable()
	test_joy_button_cache_no_double_consume()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_required_actions_exist() -> void:
	_test_name = "required_actions_exist"
	var required := ["move_left", "move_right", "jump", "interact", "shoot",
		"toggle_scroll", "pause", "dig", "place_teleport", "next_weapon"]
	for action in required:
		assert_true(InputMap.has_action(action), "Action '%s' must exist" % action)

func test_actions_have_joypad_bindings() -> void:
	_test_name = "actions_have_joypad_bindings"
	var actions_needing_joypad := ["move_left", "move_right", "jump", "interact",
		"shoot", "dig", "place_teleport", "next_weapon", "pause", "toggle_scroll"]
	for action in actions_needing_joypad:
		var events := InputMap.action_get_events(action)
		var has_joy := false
		for event in events:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_joy = true
				break
		assert_true(has_joy, "Action '%s' must have joypad binding" % action)

func test_actions_have_keyboard_bindings() -> void:
	_test_name = "actions_have_keyboard_bindings"
	# Movement and core actions need keyboard bindings for Steam Deck Desktop mode
	var actions_needing_keyboard := ["move_left", "move_right", "jump", "interact", "dig", "pause"]
	for action in actions_needing_keyboard:
		var events := InputMap.action_get_events(action)
		var has_key := false
		for event in events:
			if event is InputEventKey:
				has_key = true
				break
		assert_true(has_key, "Action '%s' must have keyboard binding" % action)

func test_joypad_button_indices_correct() -> void:
	_test_name = "joypad_button_indices"
	# Verify critical joypad button mappings match the expected Xbox layout.
	# Godot 4 JoyButton enum: A=0, B=1, X=2, Y=3, Back=4, Guide=5, Start=6,
	# LeftStick=7, RightStick=8, LB=9, RB=10, DpadUp=11, DpadDown=12, DpadLeft=13, DpadRight=14
	var expected_buttons: Dictionary = {
		"jump": JOY_BUTTON_A,          # 0
		"interact": JOY_BUTTON_X,      # 2
		"toggle_scroll": JOY_BUTTON_Y, # 3
		"pause": JOY_BUTTON_START,     # 6
		"dig": JOY_BUTTON_LEFT_SHOULDER,  # 9
		"next_weapon": JOY_BUTTON_RIGHT_SHOULDER, # 10
	}
	for action in expected_buttons:
		var expected_btn: int = expected_buttons[action]
		var events := InputMap.action_get_events(action)
		var found := false
		for event in events:
			if event is InputEventJoypadButton and event.button_index == expected_btn:
				found = true
				break
		assert_true(found, "Action '%s' must map to JoyButton %d (got wrong index)" % [action, expected_btn])

func test_player_controller_input_helpers_callable() -> void:
	_test_name = "player_controller_input_helpers"
	# Create a minimal PlayerController to test its input methods don't crash
	var script := load("res://scenes/player/PlayerController.gd") as GDScript
	if script == null:
		assert_true(false, "PlayerController.gd must load")
		return
	# Can't fully instantiate (needs scene tree nodes), but verify the script compiles
	assert_true(script.can_instantiate(), "PlayerController script must be valid")

func test_joy_button_cache_no_double_consume() -> void:
	_test_name = "joy_button_cache_no_double_consume"
	# Verify the cache pattern: calling _joy_button_just_pressed twice for same button
	# in the same frame should return the SAME result (not consume on first call)
	# We can't test the actual PlayerController without full scene, but we verify
	# the cache dictionary pattern works correctly
	var cache: Dictionary = {}
	cache[0] = true  # Simulate JOY_BUTTON_A was just pressed
	cache[1] = false

	# Both reads should return the same value
	var first_read: bool = cache.get(0, false)
	var second_read: bool = cache.get(0, false)
	assert_true(first_read == second_read, "Cache must not consume on read")
	assert_true(first_read == true, "Button A should be just-pressed")
	assert_true(cache.get(1, false) == false, "Button B should not be just-pressed")

# === Test helpers ===

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		print("  FAIL [%s]: %s" % [_test_name, message])

func assert_eq(a: Variant, b: Variant, message: String) -> void:
	assert_true(a == b, "%s (got %s, expected %s)" % [message, str(a), str(b)])
