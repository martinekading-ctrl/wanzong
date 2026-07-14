extends Node2D

const TILE_SIZE := WorldMapSpec.TILE_SIZE
const GRID_SIZE := WorldMapSpec.GRID_SIZE

@export var safe_land_source_ids: Array[int] = []
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var nature_objects: Node2D = $NatureObjects

var _load_started_at: int = 0
var max_search_radius: int = WorldMapSpec.marker_search_radius_cells()
# 对象落点需要同时避开已占用格；半图半径足以跨越海岸且不会遍历完整 272×272 地图。
var max_available_search_radius: int = WorldMapSpec.object_placement_search_radius_cells()


func _enter_tree() -> void:
	_load_started_at = Time.get_ticks_msec()


func _ready() -> void:
	visible = true
	terrain_layer.visible = true
	terrain_layer.z_index = -10
	nature_objects.visible = true
	nature_objects.z_index = 0
	print("[WorldPerf] Generated map scene ready: %d ms" % (Time.get_ticks_msec() - _load_started_at))
	print(
		"[WorldMap] root=%s terrain_cells=%d nature_instances=%d used_rect=%s" % [
			name,
			terrain_layer.get_used_cells().size(),
			get_nature_instance_count(),
			terrain_layer.get_used_rect(),
		]
	)


func is_baked_map_valid() -> bool:
	var terrain: TileMapLayer = get_node_or_null("TerrainLayer") as TileMapLayer
	var nature: Node = get_node_or_null("NatureObjects")
	if terrain == null or nature == null:
		return false
	return terrain.get_used_cells().size() == GRID_SIZE.x * GRID_SIZE.y and get_nature_instance_count() > 0


func get_terrain_cell_count() -> int:
	var terrain: TileMapLayer = terrain_layer if terrain_layer != null else get_node_or_null("TerrainLayer") as TileMapLayer
	return terrain.get_used_cells().size() if terrain != null else 0


func get_nature_instance_count() -> int:
	var nature: Node = get_node_or_null("NatureObjects")
	if nature == null:
		return 0
	var count: int = 0
	for child in nature.get_children():
		var batch := child as MultiMeshInstance2D
		if batch != null and batch.multimesh != null:
			count += batch.multimesh.instance_count
	return count


# 直接查询烘焙后的 TileMap，不重建 terrain_map 或陆地索引。
func find_nearest_land_world_position(world_position: Vector2) -> Vector2:
	var start_cell := world_position_to_cell(world_position)
	if _is_safe_land(start_cell):
		return _cell_center(start_cell)
	for radius in range(1, max_search_radius + 1):
		var candidate: Vector2i = _find_safe_cell_on_ring(start_cell, radius)
		if candidate.x >= 0:
			return _cell_center(candidate)
	return world_position


func world_position_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(world_position.x / TILE_SIZE.x), 0, GRID_SIZE.x - 1),
		clampi(int(world_position.y / TILE_SIZE.y), 0, GRID_SIZE.y - 1)
	)


func is_safe_land_world_position(world_position: Vector2) -> bool:
	return WorldMapSpec.is_world_position_in_bounds(world_position) and _is_safe_land(world_position_to_cell(world_position))


func find_nearest_available_land_world_position(world_position: Vector2, occupied_cells: Dictionary, minimum_cell_distance: int = 0) -> Vector2:
	var start_cell := world_position_to_cell(world_position)
	for radius in range(0, max_available_search_radius + 1):
		for candidate in _ring_cells(start_cell, radius):
			if _is_safe_land(candidate) and _is_available_cell(candidate, occupied_cells, minimum_cell_distance):
				return _cell_center(candidate)
	return Vector2.INF


func _ring_cells(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	var result: Array[Vector2i] = []
	for offset_x in range(-radius, radius + 1):
		result.append(center + Vector2i(offset_x, -radius))
		result.append(center + Vector2i(offset_x, radius))
	for offset_y in range(-radius + 1, radius):
		result.append(center + Vector2i(-radius, offset_y))
		result.append(center + Vector2i(radius, offset_y))
	return result


func _is_available_cell(candidate: Vector2i, occupied_cells: Dictionary, minimum_cell_distance: int) -> bool:
	if occupied_cells.has(candidate):
		return false
	if minimum_cell_distance <= 0:
		return true
	for occupied in occupied_cells.keys():
		if candidate.distance_to(occupied as Vector2i) < float(minimum_cell_distance):
			return false
	return true


# 小半径逐格搜索以保证精确；大半径控制在约64个采样点，避免海上坐标产生数万次查询。
func _find_safe_cell_on_ring(center: Vector2i, radius: int) -> Vector2i:
	var stride: int = maxi(1, int(radius / 16.0))
	for offset_x in range(-radius, radius + 1, stride):
		var top := center + Vector2i(offset_x, -radius)
		if _is_safe_land(top):
			return top
		var bottom := center + Vector2i(offset_x, radius)
		if _is_safe_land(bottom):
			return bottom
	for offset_y in range(-radius + stride, radius, stride):
		var left := center + Vector2i(-radius, offset_y)
		if _is_safe_land(left):
			return left
		var right := center + Vector2i(radius, offset_y)
		if _is_safe_land(right):
			return right
	return Vector2i(-1, -1)


func _is_safe_land(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return false
	var terrain: TileMapLayer = terrain_layer if terrain_layer != null else get_node_or_null("TerrainLayer") as TileMapLayer
	return terrain != null and terrain.get_cell_source_id(cell) in safe_land_source_ids


func _cell_center(cell: Vector2i) -> Vector2:
	return WorldMapSpec.cell_center(cell)
