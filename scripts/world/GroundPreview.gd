class_name GroundPreview
extends Node2D

## Deliberately small visual test patch. Gameplay placement still uses the
## hidden baked map; this layer only previews the single supplied grass tile.

const TILE_PATH := "res://assets/world_preview/grass_tile.png"
const TILE_SCALE := 0.55
const TILE_POSITIONS := [
	Vector2(1976.0, 1900.0), Vector2(2376.0, 1900.0),
	Vector2(1776.0, 2170.0), Vector2(2176.0, 2170.0), Vector2(2576.0, 2170.0),
	Vector2(1976.0, 2440.0), Vector2(2376.0, 2440.0),
]


func _ready() -> void:
	var texture := load(TILE_PATH) as Texture2D
	if texture == null:
		push_error("Grass preview tile could not be loaded: " + TILE_PATH)
		return
	for index in range(TILE_POSITIONS.size()):
		var sprite := Sprite2D.new()
		sprite.name = "GrassTile%02d" % (index + 1)
		sprite.texture = texture
		sprite.position = TILE_POSITIONS[index]
		sprite.scale = Vector2.ONE * TILE_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = int(index / 2)
		add_child(sprite)
