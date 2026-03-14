extends Node
## Unit tests for QuestGenerator.

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== QuestGenerator Tests ===")
	test_quest_templates_exist()
	test_quest_text_is_short()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_quest_templates_exist() -> void:
	_test_name = "quest_templates_exist"
	var gen := load("res://scripts/reading/QuestGenerator.gd").new()
	gen._load_templates()
	assert_true(gen._quest_templates.size() > 0, "Should have quest templates")

func test_quest_text_is_short() -> void:
	_test_name = "quest_text_is_short"
	var gen := load("res://scripts/reading/QuestGenerator.gd").new()
	gen._load_templates()
	for template in gen._quest_templates:
		var text: String = template.get("text", "")
		var word_count := text.split(" ").size()
		assert_true(word_count <= 5, "Quest text should be <=5 words: '%s' (%d words)" % [text, word_count])

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s — %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s — %s" % [_test_name, message])
