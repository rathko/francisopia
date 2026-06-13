extends Node
## Followers occasionally make their animal noise in the background, and chirp when
## Francis walks up to one. Central + data-free: it reads the active companions from
## MagicSummon (keyed by word = species) and asks SoundFX for an asset-free voice.
##
## No per-companion wiring needed — any pet-word companion (dog/cat/frog/bunny/...) is
## covered automatically because MagicSummon already tracks them.

const NEAR_RADIUS := 90.0      # px: "Francis came up to the animal" distance
const CHATTER_MIN := 5.0       # s: min gap between background noises
const CHATTER_MAX := 11.0      # s: max gap
const AUDIBLE_RADIUS := 600.0  # px: only animals roughly on-screen pipe up

var _player: Node2D = null
var _timer := 0.0
var _next := 6.0
var _was_near: Dictionary = {}  # word -> bool (edge-detect the approach)

func _process(delta: float) -> void:
	var nodes: Dictionary = {}
	if MagicSummon and MagicSummon.has_method("get_companion_nodes"):
		nodes = MagicSummon.get_companion_nodes()
	if nodes.is_empty():
		return

	if _player == null or not is_instance_valid(_player):
		var scene := get_tree().current_scene
		_player = scene.get_node_or_null("Player") if scene else null
		if _player == null:
			return

	# Approach chirp — fire once when Francis crosses INTO a companion's near radius.
	for word in nodes:
		var n2d := nodes[word] as Node2D
		if n2d == null:
			continue
		var near: bool = n2d.global_position.distance_to(_player.global_position) < NEAR_RADIUS
		if near and not _was_near.get(word, false):
			SoundFX.play_critter(word, false)
		_was_near[word] = near

	# Background chatter — every few seconds a nearby companion pipes up, quietly.
	_timer += delta
	if _timer < _next:
		return
	_timer = 0.0
	_next = randf_range(CHATTER_MIN, CHATTER_MAX)
	var nearby: Array = []
	for word in nodes:
		var n2d := nodes[word] as Node2D
		if n2d and n2d.global_position.distance_to(_player.global_position) < AUDIBLE_RADIUS:
			nearby.append(word)
	if not nearby.is_empty():
		SoundFX.play_critter(nearby[randi() % nearby.size()], true)
