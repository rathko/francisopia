extends Node
## Unit tests for the Friends system (companion quest-giver NPCs).
##
## TDD: authored RED before implementation. Maps 1:1 to behaviours in
## docs/friends-system-architecture.md. Tests are defensive — they report a clean
## FAIL (not a crash) when the not-yet-built pieces are missing, so the suite stays
## runnable. They go GREEN as each VSDD slice lands.
##
## Wire into tests/run_tests.gd:
##   var friend_tests = load("res://tests/test_friends.gd").new()
##   root.add_child(friend_tests); friend_tests.run_all_tests()

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

const FRIENDS_JSON := "res://data/friends.json"
const WORDS_JSON := "res://data/words.json"
const FRIEND_SCRIPT := "res://scripts/world/Friend.gd"
const PET_SCRIPT := "res://scripts/world/Pet.gd"
const WORDENGINE_SCRIPT := "res://scripts/autoload/WordEngine.gd"
const GAMEMANAGER_SCRIPT := "res://scripts/autoload/GameManager.gd"
const MAGICSUMMON_SCRIPT := "res://scripts/autoload/MagicSummon.gd"

# NOTE: behavioural tests that need a live player + scene (override-clears-on-swap timing,
# follow-physics, the actual demote-on-swap) run as INTEGRATION tests on framework with a
# headless scene — they cannot be driven from this unit harness. The cases below assert the
# data contract and the public API surface that those behaviours require.

func run_all_tests() -> void:
	print("=== Friends Tests ===")
	test_friends_json_loads()
	test_first_meadow_friend_is_level_1()
	test_asks_words_exist_in_wordbank()
	test_asks_words_have_summon()
	test_wordengine_has_set_clear_override()
	test_wordengine_has_active_friend_ask_lock()
	test_friend_is_pet_subclass()
	test_gamemanager_persists_recruited_friends()
	test_gamemanager_tracks_single_active_friend()
	test_friend_supports_reselect_swap()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

# --- data ---

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	return JSON.parse_string(txt)

func test_friends_json_loads() -> void:
	_test_name = "friends_json_loads"
	var data = _load_json(FRIENDS_JSON)
	if data == null or not (data is Dictionary) or not data.has("friends"):
		assert_true(false, "friends.json missing/invalid (expected {friends:[...]})")
		return
	var friends: Array = data["friends"]
	assert_true(friends.size() >= 1, "friends.json should define >=1 friend")
	var required := ["id", "name", "area", "asks", "level", "reward_type", "follow"]
	var ok := true
	for fr in friends:
		for key in required:
			if not fr.has(key):
				ok = false
	assert_true(ok, "every friend has required keys %s" % str(required))

func test_first_meadow_friend_is_level_1() -> void:
	_test_name = "first_meadow_friend_is_level_1"
	var data = _load_json(FRIENDS_JSON)
	if data == null:
		assert_true(false, "friends.json not loadable")
		return
	var first_meadow: Variant = null
	for fr in data.get("friends", []):
		if fr.get("area", "") == "meadow":
			first_meadow = fr
			break
	if first_meadow == null:
		assert_true(false, "no meadow friend for cold-start (LP1)")
		return
	assert_true(int(first_meadow.get("level", 99)) == 1, "cold-start meadow friend must be level 1 (CVC)")

func test_asks_words_exist_in_wordbank() -> void:
	_test_name = "asks_words_exist_in_wordbank"
	var friends_data = _load_json(FRIENDS_JSON)
	var words_data = _load_json(WORDS_JSON)
	if friends_data == null or words_data == null:
		assert_true(false, "friends.json or words.json not loadable")
		return
	var bank := {}
	for w in words_data.get("words", []):
		bank[String(w.get("word", "")).to_lower()] = true
	var all_present := true
	var missing := ""
	for fr in friends_data.get("friends", []):
		for ask in fr.get("asks", []):
			if not bank.has(String(ask).to_lower()):
				all_present = false
				missing += " " + String(ask)
	assert_true(all_present, "all friend ask words exist in words.json (missing:%s)" % missing)

func test_asks_words_have_summon() -> void:
	# Every ask word must have a summon/reveal mapping so the reward never breaks (advisor #3).
	# Green-capable now: validates the curated-subset contract against MagicSummon's registry.
	_test_name = "asks_words_have_summon"
	var friends_data = _load_json(FRIENDS_JSON)
	if friends_data == null or not ResourceLoader.exists(MAGICSUMMON_SCRIPT):
		assert_true(false, "friends.json or MagicSummon.gd not loadable")
		return
	var ms = load(MAGICSUMMON_SCRIPT).new()
	var reg: Dictionary = ms.summon_registry if "summon_registry" in ms else {}
	var all_ok := true
	var missing := ""
	for fr in friends_data.get("friends", []):
		for ask in fr.get("asks", []):
			if not reg.has(String(ask).to_lower()):
				all_ok = false
				missing += " " + String(ask)
	assert_true(all_ok, "every ask word has a summon mapping (missing:%s)" % missing)

# --- code (RED until slices land) ---

func test_wordengine_has_set_clear_override() -> void:
	_test_name = "wordengine_has_set_clear_override"
	if not ResourceLoader.exists(WORDENGINE_SCRIPT):
		assert_true(false, "WordEngine.gd missing")
		return
	var we = load(WORDENGINE_SCRIPT).new()
	var ok: bool = we.has_method("set_override") and we.has_method("clear_override")
	assert_true(ok, "WordEngine needs set_override()/clear_override() (single slot, depth<=1)")

func test_wordengine_has_active_friend_ask_lock() -> void:
	_test_name = "wordengine_has_active_friend_ask_lock"
	if not ResourceLoader.exists(WORDENGINE_SCRIPT):
		assert_true(false, "WordEngine.gd missing")
		return
	var we = load(WORDENGINE_SCRIPT).new()
	assert_true("active_friend_ask" in we, "WordEngine needs active_friend_ask lock (pre-mortem FM-2)")

func test_friend_is_pet_subclass() -> void:
	_test_name = "friend_is_pet_subclass"
	if not ResourceLoader.exists(FRIEND_SCRIPT):
		assert_true(false, "Friend.gd missing (compose on Pet, do not duplicate)")
		return
	var fs = load(FRIEND_SCRIPT)
	var base = fs.get_base_script()
	var is_pet: bool = base != null and String(base.resource_path).ends_with("Pet.gd")
	assert_true(is_pet, "Friend.gd must extend Pet.gd (reuse follow logic, no parallel system)")

func test_gamemanager_persists_recruited_friends() -> void:
	_test_name = "gamemanager_persists_recruited_friends"
	if not ResourceLoader.exists(GAMEMANAGER_SCRIPT):
		assert_true(false, "GameManager.gd missing")
		return
	var gm = load(GAMEMANAGER_SCRIPT).new()
	assert_true("recruited_friends" in gm, "GameManager needs recruited_friends in save schema (FM-8, day 1)")

func test_gamemanager_tracks_single_active_friend() -> void:
	_test_name = "gamemanager_tracks_single_active_friend"
	if not ResourceLoader.exists(GAMEMANAGER_SCRIPT):
		assert_true(false, "GameManager.gd missing")
		return
	var gm = load(GAMEMANAGER_SCRIPT).new()
	# A single String slot enforces "at most one friend follows at a time".
	assert_true("active_friend" in gm, "GameManager needs active_friend: String (only one follower at a time)")

func test_friend_supports_reselect_swap() -> void:
	_test_name = "friend_supports_reselect_swap"
	if not ResourceLoader.exists(FRIEND_SCRIPT):
		assert_true(false, "Friend.gd missing")
		return
	var fs = load(FRIEND_SCRIPT)
	# Re-selecting a recruited friend must re-activate it as the sole follower.
	# Implementation exposes a select/activate entry point used by RE-SELECT.
	var names := []
	for m in fs.get_script_method_list():
		names.append(m.get("name", ""))
	var has_select: bool = ("select" in names) or ("activate" in names) or ("set_active" in names)
	assert_true(has_select, "Friend.gd needs a select()/activate() entry point for RE-SELECT swap")

# --- harness ---

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s — %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s — %s" % [_test_name, message])
