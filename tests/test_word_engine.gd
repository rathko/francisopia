extends Node
## Unit tests for WordEngine. Run with GUT framework or standalone.
## Tests word selection, validation, difficulty progression, and scoring.

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== WordEngine Tests ===")
	test_builtin_word_bank_loads()
	test_word_selection_returns_uppercase()
	test_correct_letter_collection()
	test_wrong_letter_rejection()
	test_word_completion()
	test_difficulty_progression()
	test_coin_reward_scaling()
	test_letters_needed()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_builtin_word_bank_loads() -> void:
	_test_name = "builtin_word_bank_loads"
	# WordEngine should have words after _ready
	assert_true(WordEngine.word_bank.size() > 0, "Word bank should not be empty")

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
	# Simulate word completions
	GameManager.words_completed.clear()
	WordEngine._check_difficulty_progression()
	assert_eq(WordEngine.current_difficulty, 1, "Should start at difficulty 1")

	# Add 10 words to trigger level 2
	for i in 10:
		GameManager.words_completed.append("word_%d" % i)
	WordEngine._check_difficulty_progression()
	assert_eq(WordEngine.current_difficulty, 2, "Should be difficulty 2 after 10 words")

	# Add more to reach level 3
	for i in 15:
		GameManager.words_completed.append("extra_%d" % i)
	WordEngine._check_difficulty_progression()
	assert_eq(WordEngine.current_difficulty, 3, "Should be difficulty 3 after 25 words")

	# Cleanup
	GameManager.words_completed.clear()
	WordEngine.current_difficulty = 1

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

# --- Test helpers ---

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s — %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s — %s" % [_test_name, message])

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s — %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s — %s (got %s, expected %s)" % [_test_name, message, str(actual), str(expected)])
