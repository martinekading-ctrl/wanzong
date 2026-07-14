class_name WorldMapSpec
extends RefCounted

## 世界地图唯一规格。运行时、烘焙器、数据锚点与测试都必须从这里读取尺寸。
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const GRID_SIZE: Vector2i = Vector2i(272, 272)
const WORLD_SIZE: Vector2i = GRID_SIZE * TILE_SIZE
const WORLD_RECT: Rect2 = Rect2(Vector2.ZERO, Vector2(WORLD_SIZE))

## 仅用于旧存档迁移、性能对比和噪声频率补偿，不能再作为当前地图尺寸使用。
const OLD_GRID_SIZE: Vector2i = Vector2i(384, 384)
const OLD_WORLD_SIZE: Vector2i = OLD_GRID_SIZE * TILE_SIZE
const MAP_LAYOUT_VERSION: int = 2
const OLD_MAP_LAYOUT_VERSION: int = 1
const GRID_SCALE: float = float(GRID_SIZE.x) / float(OLD_GRID_SIZE.x)
const WORLD_SCALE: float = float(WORLD_SIZE.x) / float(OLD_WORLD_SIZE.x)
const LEGACY_SOURCE_WORLD_SIZE: float = 4096.0
const LEGACY_SOURCE_TO_CURRENT_SCALE: float = float(WORLD_SIZE.x) / LEGACY_SOURCE_WORLD_SIZE
const NOISE_FREQUENCY_SCALE: float = float(OLD_GRID_SIZE.x) / float(GRID_SIZE.x)
const MARKER_MARGIN_RATIO: float = 0.0625


static func world_center() -> Vector2:
	return Vector2(WORLD_SIZE) * 0.5


static func normalized_to_cell(anchor: Vector2) -> Vector2i:
	return Vector2i(
		clampi(roundi(anchor.x * float(GRID_SIZE.x - 1)), 0, GRID_SIZE.x - 1),
		clampi(roundi(anchor.y * float(GRID_SIZE.y - 1)), 0, GRID_SIZE.y - 1)
	)


static func normalized_to_world(anchor: Vector2) -> Vector2:
	return cell_center(normalized_to_cell(anchor))


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE) * 0.5


static func marker_margin_cells() -> int:
	return maxi(1, ceili(float(GRID_SIZE.x) * MARKER_MARGIN_RATIO))


static func marker_search_radius_cells() -> int:
	return maxi(1, ceili(64.0 * float(GRID_SIZE.x) / float(OLD_GRID_SIZE.x)))


static func object_placement_search_radius_cells() -> int:
	# 受限于半张地图的环形搜索：可跨越海岸，但不会扫描完整 272×272 格地形。
	return GRID_SIZE.x / 2


static func is_world_position_in_bounds(world_position: Vector2) -> bool:
	return WORLD_RECT.has_point(world_position)


static func clamp_world_position(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, 0.0, float(WORLD_SIZE.x) - 0.001),
		clampf(world_position.y, 0.0, float(WORLD_SIZE.y) - 0.001)
	)


static func compact_from_old_world_position(old_position: Vector2) -> Vector2:
	return clamp_world_position(old_position * WORLD_SCALE)


static func compact_from_legacy_source_position(source_position: Vector2) -> Vector2:
	return clamp_world_position(source_position * LEGACY_SOURCE_TO_CURRENT_SCALE)
