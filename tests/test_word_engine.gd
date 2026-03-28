extends Node
## Unit tests for WordEngine. Tests word selection, validation, difficulty, and repeatable logic.

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== WordEngine Tests ===")
	test_builtin_word_bank_loads()
	test_word_bank_has_levels()
	test_word_selection_returns_uppercase()
	test_correct_letter_collection()
	test_wrong_letter_rejection()
	test_word_completion()
	test_difficulty_progression()
	test_coin_reward_scaling()
	test_letters_needed()
	test_force_house_at_3_companions()
	test_starter_sequence_words_valid()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_builtin_word_bank_loads() -> void:
	_test_name = "builtin_word_bank_loads"
	assert_true(WordEngine.word_bank.size() > 0, "Word bank should not be empty")
	assert_true(WordEngine.word_bank.size() >= 50, "Word bank should have at least 50 words (got %d)" % WordEngine.word_bank.size())

func test_word_bank_has_levels() -> void:
	_test_name = "word_bank_has_levels"
	var levels_found: Dictionary = {}
	for entry in WordEngine.word_bank:
		var lvl: int = entry.get("level", 0)
		levels_found[lvl] = levels_found.get(lvl, 0) + 1
	assert_true(levels_found.has(1), "Should have level 1 words")
	assert_true(levels_found.has(2), "Should have level 2 words")
	assert_true(levels_found.has(3), "Should have level 3 words")
	assert_true(levels_found.get(1, 0) >= 15, "Level 1 should have 15+ words (got %d)" % levels_found.get(1, 0))

func test_word_selection_returns_uppercase() -> void:
	_test_name = "word_selection_returns_uppercase"
	var word := WordEngine.select_word_for_area("meadow")
	assert_true(word == word.to_upper(), "Selected word should be uppercase: " + word)
	assert_true(word.length() >= 3, "Word should be at least 3 letters: " + word)

func test_correct_letter_collection() -> void:
	_test_name = "correct_letter_collection"
	WordEngine.current_target_word = "CAT"
	WordEngine.collected_letters.clear()
	var result := WordEngine.try_collect_letter("C")
	assert_true(result, "Correct first letter should be accepted")
	assert_eq(WordEngine.collected_letters.size(), 1, "Should have 1 collected letter")

func test_wrong_letter_rejection() -> void:
	_test_name = "wrong_letter_rejection"
	WordEngine.current_target_word = "CAT"
	WordEngine.collected_letters.clear()
	var result := WordEngine.try_collect_letter("Z")
	assert_false(result, "Wrong letter should be rejected")
	assert_eq(WordEngine.collected_letters.size(), 0, "Should have 0 collected letters")

func test_word_completion() -> void:
	_test_name = "word_completion"
	WordEngine.current_target_word = "SUN"
	WordEngine.collected_letters.clear()
	WordEngine.try_collect_letter("S")
	WordEngine.try_collect_letter("U")
	WordEngine.try_collect_letter("N")
	assert_true(WordEngine.is_word_complete(), "Word should be complete after all letters")

func test_difficulty_progression() -> void:
	_test_name = "difficulty_progression"
	var orig_completed := GameManager.words_completed.duplicate()
	var orig_diff := WordEngine.current_difficulty

	GameManager.words_completed.clear()
	WordEngine._check_difficulty_progression()
	assert_eq(WordEngine.current_difficulty, 1, "Should start at difficulty 1")

	for i in 10:
		GameManager.words_completed.append("word_%d" % i)
	WordEngine._check_difficulty_progression()
	assert_eq(WordEngine.current_difficulty, 2, "Should be difficulty 2 after 10 words")

	for i in 15:
		GameManager.words_completed.append("extra_%d" % i)
	WordEngine._check_difficulty_progression()
	assert_eq(WordEngine.current_difficulty, 3, "Should be difficulty 3 after 25 words")

	# Cleanup
	GameManager.words_completed.clear()
	for w in orig_completed:
		GameManager.words_completed.append(w)
	WordEngine.current_difficulty = orig_diff

func test_coin_reward_scaling() -> void:
	_test_name = "coin_reward_scaling"
	assert_eq(GameManager._coin_reward_for_word("cat"), 1, "3-letter word = 1 coin")
	assert_eq(GameManager._coin_reward_for_word("frog"), 2, "4-letter word = 2 coins")
	assert_eq(GameManager._coin_reward_for_word("flower"), 3, "6-letter word = 3 coins")

func test_letters_needed() -> void:
	_test_name = "letters_needed"
	WordEngine.current_target_word = "DOG"
	WordEngine.collected_letters.clear()
	var needed := WordEngine.get_letters_needed()
	assert_eq(needed.size(), 3, "DOG needs 3 letters")
	assert_eq(needed[0], "D", "First letter should be D")
	assert_eq(WordEngine.get_next_needed_letter(), "D", "Next needed should be D")

	WordEngine.try_collect_letter("D")
	assert_eq(WordEngine.get_next_needed_letter(), "O", "After D, next should be O")

func test_force_house_at_3_companions() -> void:
	_test_name = "force_house_at_3_companions"
	# Save state
	var orig_summoned := GameManager.words_summoned.duplicate()
	var orig_target := WordEngine.current_target_word
	var orig_hint := WordEngine.current_hint_image
	var orig_starter_idx := WordEngine._starter_index
	var orig_starter_done := WordEngine._starter_complete

	# Simulate 3 companions, no hut
	GameManager.words_summoned.clear()
	GameManager.words_summoned.append("dog")
	GameManager.words_summoned.append("cat")
	GameManager.words_summoned.append("pig")
	WordEngine._starter_complete = true

	var word := WordEngine.select_word_for_area("meadow")
	assert_eq(word, "HUT", "Should force HUT when 3 companions and no hut")

	# Cleanup
	GameManager.words_summoned.clear()
	for w in orig_summoned:
		GameManager.words_summoned.append(w)
	WordEngine.current_target_word = orig_target
	WordEngine.current_hint_image = orig_hint
	WordEngine._starter_index = orig_starter_idx
	WordEngine._starter_complete = orig_starter_done

func test_starter_sequence_words_valid() -> void:
	_test_name = "starter_sequence_words_valid"
	for word in WordEngine._starter_sequence:
		var found := false
		for entry in WordEngine.word_bank:
			if entry.get("word", "") == word:
				found = true
				break
		if not found:
			# Check summon registry too
			found = word in MagicSummon.summon_registry
		assert_true(found, "Starter word '%s' should be in word bank or registry" % word)

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
