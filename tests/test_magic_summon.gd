extends Node
## Unit tests for MagicSummon. Tests registry completeness and helper methods.

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== MagicSummon Tests ===")
	test_registry_exists()
	test_registry_entries_have_required_fields()
	test_known_words_have_summons()
	test_get_hint_color_known_word()
	test_get_hint_color_unknown_word()
	test_get_summon_type_known_word()
	test_get_summon_type_unknown_word()
	test_get_hint_label()
	test_summon_types_are_valid()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_registry_exists() -> void:
	_test_name = "registry_exists"
	assert_true(MagicSummon.summon_registry.size() > 0, "Summon registry should not be empty")

func test_registry_entries_have_required_fields() -> void:
	_test_name = "registry_entries_have_required_fields"
	var all_valid := true
	for word in MagicSummon.summon_registry:
		var entry: Dictionary = MagicSummon.summon_registry[word]
		if not entry.has("type"):
			all_valid = false
			print("  FAIL: %s — '%s' missing 'type'" % [_test_name, word])
		if not entry.has("builder"):
			all_valid = false
			print("  FAIL: %s — '%s' missing 'builder'" % [_test_name, word])
		if not entry.has("label"):
			all_valid = false
			print("  FAIL: %s — '%s' missing 'label'" % [_test_name, word])
		if not entry.has("color"):
			all_valid = false
			print("  FAIL: %s — '%s' missing 'color'" % [_test_name, word])
	if all_valid:
		_pass_count += 1
		print("  PASS: %s — All entries have type, builder, label, color" % _test_name)
	else:
		_fail_count += 1

func test_known_words_have_summons() -> void:
	_test_name = "known_words_have_summons"
	# Level 1 words that should definitely have summons
	var core_words := ["cat", "dog", "sun", "hat", "bed", "cup", "bug", "box"]
	for word in core_words:
		assert_true(word in MagicSummon.summon_registry, "Core word '%s' should have a summon" % word)

func test_get_hint_color_known_word() -> void:
	_test_name = "get_hint_color_known_word"
	var color := MagicSummon.get_hint_color_for_word("cat")
	assert_true(color != Color.WHITE, "Known word 'cat' should have non-white color")

func test_get_hint_color_unknown_word() -> void:
	_test_name = "get_hint_color_unknown_word"
	var color := MagicSummon.get_hint_color_for_word("xyzzyplugh")
	assert_eq(color, Color.WHITE, "Unknown word should return white")

func test_get_summon_type_known_word() -> void:
	_test_name = "get_summon_type_known_word"
	assert_eq(MagicSummon.get_summon_type_for_word("cat"), "pet", "'cat' should be pet type")
	assert_eq(MagicSummon.get_summon_type_for_word("sun"), "world", "'sun' should be world type")

func test_get_summon_type_unknown_word() -> void:
	_test_name = "get_summon_type_unknown_word"
	assert_eq(MagicSummon.get_summon_type_for_word("xyzzy"), "", "Unknown word should return empty string")

func test_get_hint_label() -> void:
	_test_name = "get_hint_label"
	var label := MagicSummon.get_hint_label_for_word("cat")
	assert_true(label.length() > 0, "'cat' should have non-empty hint label")

func test_summon_types_are_valid() -> void:
	_test_name = "summon_types_are_valid"
	var valid_types := ["pet", "world", "item", "cosmetic"]
	var all_valid := true
	for word in MagicSummon.summon_registry:
		var entry: Dictionary = MagicSummon.summon_registry[word]
		var summon_type: String = entry.get("type", "")
		if summon_type not in valid_types:
			all_valid = false
			print("  FAIL: %s — '%s' has invalid type '%s'" % [_test_name, word, summon_type])
	if all_valid:
		_pass_count += 1
		print("  PASS: %s — All summon types are valid" % _test_name)
	else:
		_fail_count += 1

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
