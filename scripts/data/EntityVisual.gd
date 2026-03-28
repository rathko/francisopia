extends Resource
## Data-driven visual definition for any game entity.
## Adding a new creature/decoration = create art + create a .tres with this resource type.
## No code changes needed.
##
## Usage:
##   var visual = preload("res://assets/visuals/dog_visual.tres") as Resource
##   if visual and visual.sprite_frames:
##       animated_sprite.sprite_frames = visual.sprite_frames

# Preload this script to use as resource type:
# const EntityVisual = preload("res://scripts/data/EntityVisual.gd")

@export var display_name: String = ""
@export var sprite_frames: SpriteFrames = null
@export var default_animation: String = "idle"
@export var scale: Vector2 = Vector2(1, 1)
@export var offset: Vector2 = Vector2.ZERO
@export var has_shadow: bool = true
@export var shadow_scale: float = 1.0
@export var follow_distance: float = 60.0
@export var follow_speed: float = 150.0
