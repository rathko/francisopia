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

	print("")
	print("========================================")
	print("  All tests complete!")
	print("========================================")

	quit()
