extends Node2D

const WORLD_SIZE := Vector2(6144, 6144)
const SAFE_AREA := Rect2(900, 700, 4344, 4744)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#244b65"))
	draw_rect(SAFE_AREA, Color("#72945a"))
	draw_rect(SAFE_AREA.grow(-32.0), Color("#88a968"), false, 32.0)


func find_nearest_land_world_position(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, SAFE_AREA.position.x, SAFE_AREA.end.x),
		clampf(world_position.y, SAFE_AREA.position.y, SAFE_AREA.end.y)
	)
