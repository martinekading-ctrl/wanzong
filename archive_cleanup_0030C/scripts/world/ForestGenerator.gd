extends RefCounted
class_name ForestGenerator

# 森林生成器只负责生成森林数据，不负责采集、砍树或任何玩法逻辑。

const MAP_WIDTH: int = 100
const MAP_HEIGHT: int = 100
const WORLD_SIZE: Vector2 = Vector2(4096, 4096)

const TERRAIN_GRASS: String = "grass"
const TERRAIN_DIRT: String = "dirt"
const TERRAIN_WATER: String = "water"
const TERRAIN_SNOW: String = "snow"
const TERRAIN_DEAD_GROUND: String = "dead_ground"

const FOREST_MIN_COUNT: int = 8
const FOREST_MAX_COUNT: int = 12
const TREE_MIN_COUNT: int = 10
const TREE_MAX_COUNT: int = 30

const CENTER_MAX_ATTEMPTS: int = 1200
const TREE_ATTEMPT_MULTIPLIER: int = 16

const MIN_DISTANCE_TO_SECT: float = 300.0
const MIN_DISTANCE_TO_BUILD_SLOT: float = 160.0
const MIN_DISTANCE_TO_RESOURCE: float = 120.0
const MIN_DISTANCE_BETWEEN_FORESTS: float = 180.0

# 固定种子保证每次运行生成结果一致，后续可以接入存档种子。
var seed: int = 20260708 + 130
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


# 根据世界地形、宗门、建设点和资源点生成森林与树点数据。
func generate_forests(world_data: Dictionary, sects: Array, build_slots: Array, resources: Array = []) -> Dictionary:
	rng.seed = seed

	var terrain_map: Array = world_data.get("terrain_map", []) as Array
	if terrain_map.is_empty():
		return {"forests": [], "trees": []}

	var forest_count: int = rng.randi_range(FOREST_MIN_COUNT, FOREST_MAX_COUNT)
	var forests: Array = _generate_forest_areas(terrain_map, forest_count, sects, build_slots, resources)
	var trees: Array = _generate_tree_points(forests, terrain_map, sects, build_slots, resources)

	return {
		"forests": forests,
		"trees": trees,
	}


# 生成 8~12 片自然森林区域。
func _generate_forest_areas(terrain_map: Array, target_count: int, sects: Array, build_slots: Array, resources: Array) -> Array:
	var forests: Array = []
	var attempts: int = 0

	while forests.size() < target_count and attempts < CENTER_MAX_ATTEMPTS:
		attempts += 1

		var cell_position: Vector2i = Vector2i(
			rng.randi_range(4, MAP_WIDTH - 5),
			rng.randi_range(4, MAP_HEIGHT - 5)
		)
		var terrain_type: String = _get_terrain_at_cell(terrain_map, cell_position)
		if not _is_valid_forest_center_terrain(terrain_type, cell_position, terrain_map):
			continue

		var world_position: Vector2 = _cell_to_world_position(cell_position)
		var radius: float = rng.randf_range(150.0, 280.0)
		if _is_near_blocked_position(world_position, sects, build_slots, resources, radius):
			continue
		if _is_near_existing_forest(world_position, radius, forests):
			continue

		var center_score: float = _get_forest_center_score(cell_position, terrain_map)
		if rng.randf() > center_score:
			continue

		forests.append({
			"forest_id": forests.size() + 1,
			"position": world_position,
			"radius": radius,
			"tree_count": rng.randi_range(TREE_MIN_COUNT, TREE_MAX_COUNT),
		})

	return forests


# 为每片森林生成不规则散布的树点。
func _generate_tree_points(forests: Array, terrain_map: Array, sects: Array, build_slots: Array, resources: Array) -> Array:
	var trees: Array = []
	var tree_id: int = 1

	for forest_index in range(forests.size()):
		var forest_data: Dictionary = forests[forest_index]
		var forest_position: Vector2 = forest_data["position"]
		var forest_radius: float = float(forest_data["radius"])
		var target_tree_count: int = int(forest_data["tree_count"])
		var created_count: int = 0
		var attempts: int = 0

		while created_count < target_tree_count and attempts < target_tree_count * TREE_ATTEMPT_MULTIPLIER:
			attempts += 1

			var angle: float = rng.randf_range(0.0, TAU)
			var distance: float = sqrt(rng.randf()) * forest_radius
			var scatter: Vector2 = Vector2(cos(angle), sin(angle)) * distance
			var natural_offset: Vector2 = _get_natural_offset(tree_id, forest_index)
			var tree_position: Vector2 = forest_position + scatter + natural_offset

			if not _is_inside_world(tree_position):
				continue
			if _is_near_blocked_position(tree_position, sects, build_slots, resources, 0.0):
				continue

			var tree_cell: Vector2i = _world_to_cell_position(tree_position)
			if not _is_valid_tree_terrain(tree_cell, terrain_map):
				continue

			trees.append({
				"tree_id": tree_id,
				"position": tree_position,
				"forest_id": int(forest_data["forest_id"]),
			})
			tree_id += 1
			created_count += 1

		forest_data["tree_count"] = created_count
		forests[forest_index] = forest_data

	return trees


# 草地优先生成森林，泥地只允许在草地边缘少量生成。
func _is_valid_forest_center_terrain(terrain_type: String, cell_position: Vector2i, terrain_map: Array) -> bool:
	if terrain_type == TERRAIN_GRASS:
		return true
	if terrain_type == TERRAIN_DIRT:
		return _has_nearby_terrain(cell_position, terrain_map, TERRAIN_GRASS, 3)

	return false


# 单棵树不能落在水、雪地、枯地等区域。
func _is_valid_tree_terrain(cell_position: Vector2i, terrain_map: Array) -> bool:
	var terrain_type: String = _get_terrain_at_cell(terrain_map, cell_position)
	if terrain_type == TERRAIN_GRASS:
		return true
	if terrain_type == TERRAIN_DIRT:
		return _has_nearby_terrain(cell_position, terrain_map, TERRAIN_GRASS, 2) and rng.randf() < 0.35

	return false


# 河流附近加权更高，让森林更像沿水系自然生长。
func _get_forest_center_score(cell_position: Vector2i, terrain_map: Array) -> float:
	var terrain_type: String = _get_terrain_at_cell(terrain_map, cell_position)
	var score: float = 0.48 if terrain_type == TERRAIN_GRASS else 0.18
	var water_distance: int = _get_nearest_terrain_distance(cell_position, terrain_map, TERRAIN_WATER, 8)

	if water_distance <= 2:
		score += 0.38
	elif water_distance <= 5:
		score += 0.22
	elif water_distance <= 8:
		score += 0.10

	score += _get_hash_noise(cell_position.x, cell_position.y) * 0.16
	return clamp(score, 0.08, 0.92)


# 避开宗门、建设点和资源点，避免森林盖住核心对象。
func _is_near_blocked_position(position: Vector2, sects: Array, build_slots: Array, resources: Array, extra_radius: float) -> bool:
	for sect_data in sects:
		var sect_position: Vector2 = sect_data["position"]
		if position.distance_to(sect_position) < MIN_DISTANCE_TO_SECT + extra_radius:
			return true

	for slot_data in build_slots:
		var slot_position: Vector2 = slot_data["position"]
		if position.distance_to(slot_position) < MIN_DISTANCE_TO_BUILD_SLOT + extra_radius:
			return true

	for resource_data in resources:
		var resource_position: Vector2 = resource_data["position"]
		if position.distance_to(resource_position) < MIN_DISTANCE_TO_RESOURCE + extra_radius:
			return true

	return false


# 森林之间保持距离，避免所有树点挤成一团。
func _is_near_existing_forest(position: Vector2, radius: float, forests: Array) -> bool:
	for forest_data in forests:
		var forest_position: Vector2 = forest_data["position"]
		var forest_radius: float = float(forest_data["radius"])
		if position.distance_to(forest_position) < radius + forest_radius + MIN_DISTANCE_BETWEEN_FORESTS:
			return true

	return false


# 给树点增加一点固定扰动，避免肉眼看到圆形或网格排列。
func _get_natural_offset(tree_id: int, forest_index: int) -> Vector2:
	var offset_x: float = (_get_hash_noise(tree_id, forest_index * 17) - 0.5) * 42.0
	var offset_y: float = (_get_hash_noise(forest_index * 23, tree_id) - 0.5) * 42.0
	return Vector2(offset_x, offset_y)


# 查询某格周围是否存在指定地形。
func _has_nearby_terrain(cell_position: Vector2i, terrain_map: Array, target_terrain: String, radius: int) -> bool:
	return _get_nearest_terrain_distance(cell_position, terrain_map, target_terrain, radius) <= radius


# 查询附近指定地形的最近距离。
func _get_nearest_terrain_distance(cell_position: Vector2i, terrain_map: Array, target_terrain: String, radius: int) -> int:
	var best_distance: int = radius + 1

	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var check_position: Vector2i = cell_position + Vector2i(offset_x, offset_y)
			if not _is_inside_map(check_position):
				continue
			if str(terrain_map[check_position.y][check_position.x]) != target_terrain:
				continue

			var distance: int = int(round(Vector2(offset_x, offset_y).length()))
			if distance < best_distance:
				best_distance = distance

	return best_distance


# 读取指定格子的地形。
func _get_terrain_at_cell(terrain_map: Array, cell_position: Vector2i) -> String:
	if not _is_inside_map(cell_position):
		return ""

	return str(terrain_map[cell_position.y][cell_position.x])


# 逻辑格转世界坐标。
func _cell_to_world_position(cell_position: Vector2i) -> Vector2:
	var cell_size: Vector2 = Vector2(WORLD_SIZE.x / MAP_WIDTH, WORLD_SIZE.y / MAP_HEIGHT)
	return Vector2(
		(float(cell_position.x) + 0.5) * cell_size.x,
		(float(cell_position.y) + 0.5) * cell_size.y
	)


# 世界坐标转逻辑格。
func _world_to_cell_position(position: Vector2) -> Vector2i:
	return Vector2i(
		int(clamp(floor(position.x / (WORLD_SIZE.x / MAP_WIDTH)), 0.0, float(MAP_WIDTH - 1))),
		int(clamp(floor(position.y / (WORLD_SIZE.y / MAP_HEIGHT)), 0.0, float(MAP_HEIGHT - 1)))
	)


# 世界坐标是否在地图内。
func _is_inside_world(position: Vector2) -> bool:
	return position.x >= 0.0 and position.y >= 0.0 and position.x <= WORLD_SIZE.x and position.y <= WORLD_SIZE.y


# 逻辑格是否在地图内。
func _is_inside_map(cell_position: Vector2i) -> bool:
	return cell_position.x >= 0 and cell_position.y >= 0 and cell_position.x < MAP_WIDTH and cell_position.y < MAP_HEIGHT


# 简单固定哈希噪声，用于可重复的自然扰动。
func _get_hash_noise(x: int, y: int) -> float:
	var raw_value: int = abs((x * 928371 + y * 364479 + seed * 97) % 10000)
	return float(raw_value) / 10000.0
