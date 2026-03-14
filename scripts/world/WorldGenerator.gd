extends Node
## Procedural world generation. Varies platform positions, item placement,
## and decoration each playthrough for unique experiences.

var _seed: int = 0
var _rng := RandomNumberGenerator.new()

func initialize(world_seed: int = 0) -> void:
	if world_seed == 0:
		_seed = randi()
	else:
		_seed = world_seed
	_rng.seed = _seed

func get_seed() -> int:
	return _seed

func generate_platform_positions(area_width: float, area_height: float, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var min_gap := 100.0  # Minimum gap between platforms (easy jumping for age 5)
	var max_height := area_height * 0.7  # Don't place too high

	for i in count:
		var x := _rng.randf_range(100, area_width - 100)
		var y := _rng.randf_range(area_height * 0.3, max_height)
		positions.append(Vector2(x, y))

	# Sort left-to-right for natural progression
	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return positions

func generate_decoration_positions(area_bounds: Rect2, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i in count:
		var x := _rng.randf_range(area_bounds.position.x, area_bounds.end.x)
		var y := _rng.randf_range(area_bounds.position.y, area_bounds.end.y)
		positions.append(Vector2(x, y))
	return positions

func pick_weather() -> String:
	var weathers := ["sunny", "cloudy", "gentle_rain", "sunset", "starry"]
	var weights := [0.4, 0.2, 0.1, 0.2, 0.1]  # Mostly sunny
	var roll := _rng.randf()
	var cumulative := 0.0
	for i in weathers.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return weathers[i]
	return "sunny"

func should_wonder_event() -> bool:
	# 5% chance per area load — rare and special
	return _rng.randf() < 0.05

func pick_wonder_event() -> String:
	var events := ["rainbow", "shooting_stars", "aurora", "butterflies", "double_sun"]
	return events[_rng.randi() % events.size()]
