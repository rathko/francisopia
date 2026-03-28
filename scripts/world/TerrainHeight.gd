## Pure height function for terrain generation. Stateless, deterministic.
## Returns block-count offset from baseline GROUND_Y per world column.
##
## Usage:
##   const TerrainHeight = preload("res://scripts/world/TerrainHeight.gd")
##   var offset: int = TerrainHeight.get_height(world_block_x, world_seed)
##   var ground_y := GROUND_Y + offset * BLOCK_SIZE

const MAX_AMPLITUDE: int = 4
const FREQ_PRIMARY: float = 0.02
const FREQ_SECONDARY: float = 0.05
const AMP_RATIO: float = 0.3
const STAIRWELL_FLAT_RADIUS: int = 4

## Smoothness proof:
## max |h'(x)| = MAX_AMPLITUDE * (FREQ_PRIMARY + AMP_RATIO * FREQ_SECONDARY) * TAU / (1 + AMP_RATIO)
##             = 4 * (0.02 + 0.3 * 0.05) * 6.283 / 1.3
##             = 4 * 0.035 * 6.283 / 1.3 = 0.677
## 0.677 < 1.0 so adjacent columns always differ by at most 1 block.


static func get_height(world_block_x: int, world_seed: int) -> int:
	# Reduce seed to small range to preserve sin() floating point precision
	var seed_reduced: float = fmod(float(world_seed % 100000) * 0.7123, TAU)
	var x: float = float(world_block_x)
	var h1: float = sin(x * FREQ_PRIMARY * TAU + seed_reduced)
	var h2: float = sin(x * FREQ_SECONDARY * TAU + seed_reduced * 1.3)
	var raw: float = h1 + h2 * AMP_RATIO
	var normalized: float = raw / (1.0 + AMP_RATIO)
	return int(roundf(normalized * MAX_AMPLITUDE))


static func get_height_with_stairwell(
	world_block_x: int, world_seed: int,
	stairwell_centers: Array[int]
) -> int:
	var natural: int = get_height(world_block_x, world_seed)
	for center in stairwell_centers:
		var dist: int = absi(world_block_x - center)
		if dist <= STAIRWELL_FLAT_RADIUS:
			if dist <= 2:
				return 0
			else:
				var blend: float = float(dist - 2) / float(STAIRWELL_FLAT_RADIUS - 2)
				return int(roundf(float(natural) * blend))
	return natural
