## Utility for loading sprite scenes with ColorRect fallback.
## Used by visual builder functions to try sprites first, fall back to procedural visuals.
##
## Usage:
##   const SpriteLoader = preload("res://scripts/world/SpriteLoader.gd")
##   var sprite = SpriteLoader.try_load("res://assets/sprites/world/tree.tscn")
##   if sprite:
##       sprite.position = pos
##       parent.add_child(sprite)
##       return  # Skip ColorRect fallback


static func try_load(scene_path: String) -> Node:
	## Try to instantiate a sprite scene. Returns null if not found.
	if not ResourceLoader.exists(scene_path):
		return null
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return null
	return scene.instantiate()


static func try_load_visual(visual_path: String) -> Resource:
	## Try to load an EntityVisual resource. Returns null if not found.
	if not ResourceLoader.exists(visual_path):
		return null
	return load(visual_path)


static func try_load_sprite(texture_path: String, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	## Try to create a Sprite2D from a texture PNG. Returns null if not found.
	if not ResourceLoader.exists(texture_path):
		return null
	var tex = load(texture_path) as Texture2D
	if not tex:
		return null
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.offset = offset
	return spr


static func try_load_random_sprite(base_path: String, count: int, rng_val: int, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	## Pick a random variant sprite. E.g. base_path="res://assets/sprites/world/tree_", count=3
	## tries tree_0.png, tree_1.png, tree_2.png and picks one based on rng_val.
	var idx: int = rng_val % count
	var path := "%s%d.png" % [base_path, idx]
	return try_load_sprite(path, offset)
