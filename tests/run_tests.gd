extends SceneTree
## Test runner for Francis-opia. Run with: godot --headless --script tests/run_tests.gd
## Loads autoloads manually and runs all test suites.

func _init() -> void:
	print("")
	print("========================================")
	print("  Francis-opia Test Suite")
	print("========================================")
	print("")

	# Run word engine tests
	var word_tests := load("res://tests/test_word_engine.gd").new()
	root.add_child(word_tests)

	# Wait one frame for autoloads to initialize
	await root.get_tree().process_frame

	word_tests.run_all_tests()

	# Run quest generator tests
	var quest_tests := load("res://tests/test_quest_generator.gd").new()
	root.add_child(quest_tests)
	quest_tests.run_all_tests()

	# Run game manager tests
	var gm_tests := load("res://tests/test_game_manager.gd").new()
	root.add_child(gm_tests)
	gm_tests.run_all_tests()

	# Run magic summon tests
	var magic_tests := load("res://tests/test_magic_summon.gd").new()
	root.add_child(magic_tests)
	magic_tests.run_all_tests()

	print("")
	print("========================================")
	print("  All tests complete!")
	print("========================================")

	quit()
