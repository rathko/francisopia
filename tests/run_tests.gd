extends SceneTree
## Test runner for Francis-opia. Run with: godot --headless --script tests/run_tests.gd
## Manually creates autoload singletons, then runs all test suites.

var _has_run := false

func _initialize() -> void:
	# Set up autoloads manually since --script mode doesn't load them
	var gm = load("res://scripts/autoload/GameManager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	var we = load("res://scripts/autoload/WordEngine.gd").new()
	we.name = "WordEngine"
	root.add_child(we)

	var am = load("res://scripts/autoload/AudioManager.gd").new()
	am.name = "AudioManager"
	root.add_child(am)

	var ih = load("res://scripts/autoload/InputHelper.gd").new()
	ih.name = "InputHelper"
	root.add_child(ih)

	var qg = load("res://scripts/autoload/QuestGenerator.gd").new()
	qg.name = "QuestGenerator"
	root.add_child(qg)

	var ms = load("res://scripts/autoload/MagicSummon.gd").new()
	ms.name = "MagicSummon"
	root.add_child(ms)

func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true

	print("")
	print("========================================")
	print("  Francis-opia Test Suite")
	print("========================================")
	print("")

	# Run word engine tests
	var word_tests = load("res://tests/test_word_engine.gd").new()
	root.add_child(word_tests)
	word_tests.run_all_tests()

	# Run quest generator tests
	var quest_tests = load("res://tests/test_quest_generator.gd").new()
	root.add_child(quest_tests)
	quest_tests.run_all_tests()

	# Run game manager tests
	var gm_tests = load("res://tests/test_game_manager.gd").new()
	root.add_child(gm_tests)
	gm_tests.run_all_tests()

	# Run magic summon tests
	var magic_tests = load("res://tests/test_magic_summon.gd").new()
	root.add_child(magic_tests)
	magic_tests.run_all_tests()

	# Run terrain height tests
	var terrain_tests = load("res://tests/test_terrain_height.gd").new()
	root.add_child(terrain_tests)
	terrain_tests.run_all_tests()

	print("")
	print("========================================")
	print("  All tests complete!")
	print("========================================")

	quit()
	return true
