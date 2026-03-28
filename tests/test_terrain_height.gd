extends Node
## Unit tests for TerrainHeight. Tests determinism, smoothness, range, and stairwell flat zones.
## VSDD Red Gate: these tests are written BEFORE the implementation exists.

const TerrainHeight = preload("res://scripts/world/TerrainHeight.gd")

var _pass_count := 0
var _fail_count := 0
var _test_name := ""

func run_all_tests() -> void:
	print("=== TerrainHeight Tests ===")
	test_determinism_same_seed()
	test_determinism_different_seed()
	test_range_within_bounds()
	test_smoothness_no_cliffs()
	test_smoothness_multiple_seeds()
	test_chunk_boundary_continuity()
	test_stairwell_flat_zone_center()
	test_stairwell_flat_zone_transition()
	test_stairwell_does_not_affect_distant_columns()
	test_height_varies_across_world()
	test_negative_world_coordinates()
	test_seed_zero_works()
	print("=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])

func test_determinism_same_seed() -> void:
	_test_name = "determinism_same_seed"
	# Same inputs must always produce same output
	for x in range(-100, 100):
		var h1 := TerrainHeight.get_height(x, 42)
		var h2 := TerrainHeight.get_height(x, 42)
		if h1 != h2:
			assert_true(false, "Height differs at x=%d: %d vs %d" % [x, h1, h2])
			return
	assert_true(true, "200 columns all deterministic with seed 42")

func test_determinism_different_seed() -> void:
	_test_name = "determinism_different_seed"
	# Different seeds should produce different terrain (at least sometimes)
	var same_count := 0
	for x in range(0, 50):
		if TerrainHeight.get_height(x, 1) == TerrainHeight.get_height(x, 9999):
			same_count += 1
	# Allow some coincidental matches, but not all
	assert_true(same_count < 45, "Different seeds should differ (same: %d/50)" % same_count)

func test_range_within_bounds() -> void:
	_test_name = "range_within_bounds"
	# Height offset should stay within [-MAX_AMPLITUDE, +MAX_AMPLITUDE]
	var max_amp: int = TerrainHeight.MAX_AMPLITUDE
	for seed_val in [0, 1, 42, 999, 123456]:
		for x in range(-200, 200):
			var h := TerrainHeight.get_height(x, seed_val)
			if abs(h) > max_amp:
				assert_true(false, "Out of range at x=%d seed=%d: %d (max %d)" % [x, seed_val, h, max_amp])
				return
	assert_true(true, "All heights within [-%d, %d] across 5 seeds x 400 columns" % [max_amp, max_amp])

func test_smoothness_no_cliffs() -> void:
	_test_name = "smoothness_no_cliffs"
	# Adjacent columns must differ by at most 1 block
	var seed_val := 42
	var prev := TerrainHeight.get_height(-200, seed_val)
	for x in range(-199, 200):
		var curr := TerrainHeight.get_height(x, seed_val)
		if abs(curr - prev) > 1:
			assert_true(false, "Cliff at x=%d: %d -> %d (step %d)" % [x, prev, curr, abs(curr - prev)])
			return
		prev = curr
	assert_true(true, "400 columns smooth with seed 42")

func test_smoothness_multiple_seeds() -> void:
	_test_name = "smoothness_multiple_seeds"
	# Verify smoothness across many seeds (property-based style)
	for seed_val in [0, 1, 7, 42, 100, 999, 12345, 99999]:
		var prev := TerrainHeight.get_height(0, seed_val)
		for x in range(1, 500):
			var curr := TerrainHeight.get_height(x, seed_val)
			if abs(curr - prev) > 1:
				assert_true(false, "Cliff at seed=%d x=%d: %d -> %d" % [seed_val, x, prev, curr])
				return
			prev = curr
	assert_true(true, "8 seeds x 500 columns all smooth")

func test_chunk_boundary_continuity() -> void:
	_test_name = "chunk_boundary_continuity"
	# Chunks are 40 blocks wide. Height at block 39 of chunk N must be
	# within 1 of block 0 of chunk N+1 (which is world_block_x = 40*(N+1))
	var blocks_per_chunk := 40
	var seed_val := 42
	for chunk_idx in range(-5, 5):
		var last_in_chunk := chunk_idx * blocks_per_chunk + (blocks_per_chunk - 1)
		var first_in_next := (chunk_idx + 1) * blocks_per_chunk
		var h_last := TerrainHeight.get_height(last_in_chunk, seed_val)
		var h_first := TerrainHeight.get_height(first_in_next, seed_val)
		if abs(h_first - h_last) > 1:
			assert_true(false, "Chunk boundary cliff at %d->%d: %d->%d" % [
				last_in_chunk, first_in_next, h_last, h_first])
			return
	assert_true(true, "10 chunk boundaries all continuous")

func test_stairwell_flat_zone_center() -> void:
	_test_name = "stairwell_flat_zone_center"
	# Stairwell center and immediate neighbors must return 0
	var seed_val := 42
	var center := 100
	var centers: Array[int] = [center]
	for x in range(center - 2, center + 3):  # center +/- 2
		var h := TerrainHeight.get_height_with_stairwell(x, seed_val, centers)
		if h != 0:
			assert_true(false, "Stairwell flat zone not flat at x=%d: %d" % [x, h])
			return
	assert_true(true, "Stairwell center +/-2 blocks all flat (0)")

func test_stairwell_flat_zone_transition() -> void:
	_test_name = "stairwell_flat_zone_transition"
	# Transition zone should be between 0 and natural height
	var seed_val := 42
	var center := 100
	var centers: Array[int] = [center]
	var natural := TerrainHeight.get_height(center + 4, seed_val)
	var blended := TerrainHeight.get_height_with_stairwell(center + 4, seed_val, centers)
	# Blended should be closer to 0 than natural (or equal if natural is 0)
	if natural == 0:
		assert_eq(blended, 0, "Transition matches natural when natural is 0")
	else:
		assert_true(abs(blended) <= abs(natural),
			"Transition at +4 should blend toward 0: natural=%d blended=%d" % [natural, blended])

func test_stairwell_does_not_affect_distant_columns() -> void:
	_test_name = "stairwell_does_not_affect_distant"
	# Columns far from stairwell should match natural height
	var seed_val := 42
	var center := 100
	var centers: Array[int] = [center]
	var far_x := center + 20
	var natural := TerrainHeight.get_height(far_x, seed_val)
	var with_stairwell := TerrainHeight.get_height_with_stairwell(far_x, seed_val, centers)
	assert_eq(with_stairwell, natural, "Distant column unaffected by stairwell")

func test_height_varies_across_world() -> void:
	_test_name = "height_varies"
	# Terrain should not be completely flat (at least some non-zero heights)
	var non_zero := 0
	for x in range(0, 200):
		if TerrainHeight.get_height(x, 42) != 0:
			non_zero += 1
	assert_true(non_zero > 50, "Terrain should vary (non-zero: %d/200)" % non_zero)

func test_negative_world_coordinates() -> void:
	_test_name = "negative_coordinates"
	# Player can walk left from spawn; negative coordinates must work
	var h := TerrainHeight.get_height(-500, 42)
	assert_true(abs(h) <= TerrainHeight.MAX_AMPLITUDE,
		"Negative coord height in range: %d" % h)

func test_seed_zero_works() -> void:
	_test_name = "seed_zero"
	# Seed 0 should not cause division by zero or degenerate output
	var h := TerrainHeight.get_height(50, 0)
	assert_true(abs(h) <= TerrainHeight.MAX_AMPLITUDE, "Seed 0 produces valid height: %d" % h)

# --- Test helpers ---

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s - %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s - %s" % [_test_name, message])

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s - %s" % [_test_name, message])
	else:
		_fail_count += 1
		print("  FAIL: %s - %s (got %s, expected %s)" % [_test_name, message, str(actual), str(expected)])
