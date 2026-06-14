extends Node
## Unit tests for the house interior STATE model in GameManager.
## "following" == membership of active_companions (single source of truth); home = housed and
## not following. These invariants prevent the duplication / save-desync bug class.

var _pass := 0
var _fail := 0
var _name := ""

const GM := "res://scripts/autoload/GameManager.gd"

func run_all_tests() -> void:
	print("=== House Tests ===")
	test_following_is_active_membership()
	test_home_animals_exclude_following()
	test_validate_clamps_following_to_three()
	test_validate_assigns_unique_rooms()
	test_room_index_never_reshuffles()
	test_following_forced_into_housed()
	test_take_then_leave_round_trip()
	test_interior_prop_table_loads()
	test_register_interior_prop_idempotent()
	test_non_furniture_word_not_registered()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])

func _gm() -> Node:
	# Fresh instance, NOT added to the tree, so _ready/load_game side effects never fire.
	return load(GM).new()

func test_following_is_active_membership() -> void:
	_name = "following_is_active_membership"
	var gm := _gm()
	gm.active_companions.assign(["dog", "cat"])
	assert_true(gm.is_following("dog") and not gm.is_following("rat"),
		"is_following reflects active_companions")
	gm.free()

func test_home_animals_exclude_following() -> void:
	_name = "home_animals_exclude_following"
	var gm := _gm()
	gm.housed_animals.assign(["dog", "cat", "rat", "bunny"])
	gm.active_companions.assign(["dog", "cat"])
	var home: Array = gm.get_home_animals()
	assert_true("rat" in home and "bunny" in home and "dog" not in home,
		"home = housed minus following (no animal both home AND following)")
	gm.free()

func test_validate_clamps_following_to_three() -> void:
	_name = "validate_clamps_following_to_three"
	var gm := _gm()
	gm.active_companions.assign(["dog", "cat", "rat", "bunny"])   # 4 — invalid
	gm.housed_animals.assign(["dog", "cat", "rat", "bunny"])
	gm._validate_house_state()
	assert_true(gm.active_companions.size() == 3, "following clamped to 3 (was 4)")
	gm.free()

func test_validate_assigns_unique_rooms() -> void:
	_name = "validate_assigns_unique_rooms"
	var gm := _gm()
	gm.active_companions.assign([])
	gm.housed_animals.assign(["dog", "cat", "rat"])
	gm._validate_house_state()
	var rooms: Array = [gm.get_room_index("dog"), gm.get_room_index("cat"), gm.get_room_index("rat")]
	var all_valid: bool = rooms[0] >= 1 and rooms[1] >= 1 and rooms[2] >= 1
	var all_unique: bool = rooms[0] != rooms[1] and rooms[1] != rooms[2] and rooms[0] != rooms[2]
	assert_true(all_valid and all_unique, "every housed animal gets a unique room >= 1")
	gm.free()

func test_room_index_never_reshuffles() -> void:
	_name = "room_index_never_reshuffles"
	var gm := _gm()
	gm.active_companions.assign([])
	gm.housed_animals.assign(["dog", "cat"])
	gm._validate_house_state()
	var dog_room: int = gm.get_room_index("dog")
	gm.housed_animals.append("rat")   # a new animal arrives later
	gm._validate_house_state()
	assert_true(gm.get_room_index("dog") == dog_room,
		"an existing animal's room is unchanged when new animals are added")
	gm.free()

func test_following_forced_into_housed() -> void:
	_name = "following_forced_into_housed"
	var gm := _gm()
	gm.active_companions.assign(["dog"])
	gm.housed_animals.assign([])   # dog follows but isn't housed — inconsistent
	gm._validate_house_state()
	assert_true("dog" in gm.housed_animals, "a following animal is forced into the housed list")
	gm.free()

func test_take_then_leave_round_trip() -> void:
	# Mirrors MainScene.toggle_room_animal's state machine: taking adds to active_companions,
	# leaving removes it. "following" == active membership; home == housed and not following.
	_name = "take_then_leave_round_trip"
	var gm := _gm()
	gm.housed_animals.assign(["dog", "cat", "rat"])
	gm.active_companions.assign(["dog"])
	# Take "rat" -> now following, no longer shown in a home room.
	gm.active_companions.append("rat")
	assert_true(gm.is_following("rat") and "rat" not in gm.get_home_animals(),
		"taking an animal makes it follow and removes it from the home rooms")
	# Leave "rat" -> stops following, returns to its home room.
	gm.active_companions.erase("rat")
	assert_true(not gm.is_following("rat") and "rat" in gm.get_home_animals(),
		"leaving an animal stops following and returns it to its home room")
	gm.free()

func test_interior_prop_table_loads() -> void:
	# Slice 3: the furniture/trophy table loads from data/house_props.json and identifies prop words.
	_name = "interior_prop_table_loads"
	var gm := _gm()
	gm.load_house_props()
	var count: int = gm.house_props.size()
	var bed_is_prop: bool = gm.is_interior_prop("bed")
	var lamp_is_prop: bool = gm.is_interior_prop("lamp")
	var dog_is_prop: bool = gm.is_interior_prop("dog")   # an animal, NOT a furniture prop
	assert_true(count == 7 and bed_is_prop and lamp_is_prop and not dog_is_prop,
		"table has 7 props; bed/lamp are props, dog is not")
	gm.free()

func test_register_interior_prop_idempotent() -> void:
	# Registering a furniture word places it once; a second register is a no-op (returns false).
	_name = "register_interior_prop_idempotent"
	var gm := _gm()
	var first: bool = gm.register_interior_prop("lamp")
	var second: bool = gm.register_interior_prop("lamp")
	var placed: bool = gm.interior_props.has("lamp")
	assert_true(first and not second and placed,
		"first register places the prop, second is a no-op, prop is recorded")
	gm.free()

func test_non_furniture_word_not_registered() -> void:
	# Slice 3 anti-criterion: spelling a non-furniture word must NOT add anything to interior_props.
	_name = "non_furniture_word_not_registered"
	var gm := _gm()
	var ok: bool = gm.register_interior_prop("dog")   # dog is an animal, not a prop
	assert_true(not ok and not gm.interior_props.has("dog"),
		"a non-prop word is never placed inside the house")
	gm.free()

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  PASS: %s — %s" % [_name, msg])
	else:
		_fail += 1
		print("  FAIL: %s — %s" % [_name, msg])
