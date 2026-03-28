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

	var mvfx = load("res://scripts/autoload/MagicVFX.gd").new()
	mvfx.name = "MagicVFX"
	root.add_child(mvfx)

	var sfx = load("res://scripts/autoload/SoundFX.gd").new()
	sfx.name = "SoundFX"
	root.add_child(sfx)

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

	# Run input system smoke tests
	var input_tests = load("res://tests/test_input_system.gd").new()
	root.add_child(input_tests)
	input_tests.run_all_tests()

	# Run sprite loader tests
	var sprite_tests = load("res://tests/test_sprite_loader.gd").new()
	root.add_child(sprite_tests)
	sprite_tests.run_all_tests()

	# Run terrain block visual tests
	var terrain_block_tests = load("res://tests/test_terrain_block.gd").new()
	root.add_child(terrain_block_tests)
	terrain_block_tests.run_all_tests()

	# Run magic VFX tests
	var vfx_tests = load("res://tests/test_magic_vfx.gd").new()
	root.add_child(vfx_tests)
	vfx_tests.run_all_tests()

	print("")
	print("========================================")
	print("  All tests complete!")
	print("========================================")

	quit()
	return true
