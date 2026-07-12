extends Node2D

const TILE_SIZE := Vector2i(16, 16)
const GRID_SIZE := Vector2i(384, 384)
const MAX_SEARCH_RADIUS: int = 128

@export var safe_land_source_ids: Array[int] = []
@onready var terrain_layer: TileMapLayer = $TerrainLayer

var _load_started_at: int = 0


func _enter_tree() -> void:
	_load_started_at = Time.get_ticks_msec()


func _ready() -> void:
	print("[WorldPerf] Generated map scene ready: %d ms" % (Time.get_ticks_msec() - _load_started_at))


# 直接查询烘焙后的 TileMap，不重建 terrain_map 或陆地索引。
func find_nearest_land_world_position(world_position: Vector2) -> Vector2:
	var start_cell := Vector2i(
		clampi(int(world_position.x / TILE_SIZE.x), 0, GRID_SIZE.x - 1),
		clampi(int(world_position.y / TILE_SIZE.y), 0, GRID_SIZE.y - 1)
	)
	if _is_safe_land(start_cell):
		return _cell_center(start_cell)
	for radius in range(1, MAX_SEARCH_RADIUS + 1):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var candidate := start_cell + Vector2i(offset_x, offset_y)
				if _is_safe_land(candidate):
					return _cell_center(candidate)
	return world_position


func _is_safe_land(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return false
	return terrain_layer.get_cell_source_id(cell) in safe_land_source_ids


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE) * 0.5
