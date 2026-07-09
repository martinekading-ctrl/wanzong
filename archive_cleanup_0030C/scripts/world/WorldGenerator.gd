extends RefCounted
class_name WorldGenerator

# 世界地图逻辑尺寸。这里的 100 x 100 是地形数据网格，不是屏幕像素。
const MAP_WIDTH: int = 100
const MAP_HEIGHT: int = 100

# 生成出来的地图贴图尺寸。贴图会在 World.gd 中缩放到 4096 x 4096。
const RENDER_TEXTURE_SIZE: int = 512

# 默认河流数量。
const RIVER_COUNT: int = 2

# 河流最大步数，避免异常情况下无限循环。
const RIVER_MAX_STEPS: int = 180

# 河流最短长度。达到这个长度后才允许在边缘结束。
const RIVER_MIN_LENGTH: int = 38

# 地形类型名称。
const TERRAIN_GRASS: String = "grass"
const TERRAIN_DIRT: String = "dirt"
const TERRAIN_ROCK: String = "rock"
const TERRAIN_SNOW: String = "snow"
const TERRAIN_DEAD_GROUND: String = "dead_ground"
const TERRAIN_WATER: String = "water"

# 地形基础颜色。先用统一色块生成连续大地图，后续可以替换为更细的地表贴图。
const TERRAIN_COLORS := {
	"grass": Color(0.35, 0.58, 0.25),
	"dirt": Color(0.53, 0.38, 0.20),
	"rock": Color(0.42, 0.43, 0.39),
	"snow": Color(0.80, 0.86, 0.88),
	"dead_ground": Color(0.25, 0.22, 0.17),
	"water": Color(0.08, 0.36, 0.62),
}

# 固定种子，保证每次运行地图一致。后续可以改成存档种子。
var seed: int = 20260708


# 生成完整世界数据。
func generate_world() -> Dictionary:
	var noise_values: Array = _generate_noise_values()
	var thresholds: Dictionary = _calculate_thresholds(noise_values)
	var terrain_map: Array = _build_terrain_map(noise_values, thresholds)
	terrain_map = _cleanup_tiny_patches(terrain_map)
	var height_map: Array = _generate_height_map(terrain_map)
	var river_paths: Array = _generate_rivers(terrain_map, height_map)

	return {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"terrain_map": terrain_map,
		"height_map": height_map,
		"river_paths": river_paths,
		"thresholds": thresholds,
		"terrain_counts": _count_terrains(terrain_map),
	}


# 根据世界数据生成一张连续地图贴图。
func create_world_texture(world_data: Dictionary) -> ImageTexture:
	var terrain_map: Array = world_data["terrain_map"] as Array
	var detail_noise: FastNoiseLite = _create_detail_noise()
	var image: Image = Image.create_empty(RENDER_TEXTURE_SIZE, RENDER_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in range(RENDER_TEXTURE_SIZE):
		for x in range(RENDER_TEXTURE_SIZE):
			var color: Color = _sample_smooth_terrain_color(terrain_map, x, y)
			var detail_value: float = detail_noise.get_noise_2d(float(x), float(y)) * 0.055
			color = _apply_detail(color, detail_value)
			color.a = 1.0
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


# 生成基础噪声值。低频 FBM 会形成连续大片区域，不会出现棋盘格。
func _generate_noise_values() -> Array:
	var terrain_noise: FastNoiseLite = _create_terrain_noise()
	var values: Array = []

	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			values.append(terrain_noise.get_noise_2d(float(x), float(y)))

	return values


# 按目标比例计算阈值。
# 分布目标：DeadGround 5%，Dirt 15%，Grass 60%，Rock 10%，Snow 10%。
func _calculate_thresholds(noise_values: Array) -> Dictionary:
	var sorted_values: Array = noise_values.duplicate()
	sorted_values.sort()

	var thresholds: Dictionary = {}
	thresholds[TERRAIN_DEAD_GROUND] = _get_percentile(sorted_values, 0.05)
	thresholds[TERRAIN_DIRT] = _get_percentile(sorted_values, 0.20)
	thresholds[TERRAIN_GRASS] = _get_percentile(sorted_values, 0.80)
	thresholds[TERRAIN_ROCK] = _get_percentile(sorted_values, 0.90)
	return thresholds


# 使用阈值把噪声值转换成地形类型。
func _build_terrain_map(noise_values: Array, thresholds: Dictionary) -> Array:
	var terrain_map: Array = []
	var index: int = 0

	for y in range(MAP_HEIGHT):
		var row: Array = []
		for x in range(MAP_WIDTH):
			row.append(_get_terrain_by_value(float(noise_values[index]), thresholds))
			index += 1
		terrain_map.append(row)

	return terrain_map


# 按阈值决定一个格子的地形。
func _get_terrain_by_value(value: float, thresholds: Dictionary) -> String:
	if value <= float(thresholds[TERRAIN_DEAD_GROUND]):
		return TERRAIN_DEAD_GROUND
	if value <= float(thresholds[TERRAIN_DIRT]):
		return TERRAIN_DIRT
	if value <= float(thresholds[TERRAIN_GRASS]):
		return TERRAIN_GRASS
	if value <= float(thresholds[TERRAIN_ROCK]):
		return TERRAIN_ROCK

	return TERRAIN_SNOW


# 清掉极少数孤立小点，进一步避免一个格子一个格子的碎块。
func _cleanup_tiny_patches(terrain_map: Array) -> Array:
	var cleaned_map: Array = terrain_map

	for _iteration in range(2):
		var next_map: Array = _copy_terrain_map(cleaned_map)
		for y in range(MAP_HEIGHT):
			for x in range(MAP_WIDTH):
				var dominant_terrain: String = _get_dominant_neighbor_terrain(cleaned_map, x, y)
				var same_count: int = _count_neighbor_terrain(cleaned_map, x, y, str(cleaned_map[y][x]))
				if same_count <= 2 and dominant_terrain != "":
					next_map[y][x] = dominant_terrain
		cleaned_map = next_map

	return cleaned_map


# 生成高度图。雪地、岩石和上边缘更高，草地和地图边缘更低。
func _generate_height_map(terrain_map: Array) -> Array:
	var height_noise: FastNoiseLite = _create_height_noise()
	var height_map: Array = []

	for y in range(MAP_HEIGHT):
		var row: Array = []
		for x in range(MAP_WIDTH):
			var terrain_type: String = str(terrain_map[y][x])
			var north_height: float = 1.0 - (float(y) / float(MAP_HEIGHT - 1))
			var terrain_height: float = _get_terrain_height_bonus(terrain_type)
			var noise_height: float = height_noise.get_noise_2d(float(x), float(y)) * 0.18
			row.append(north_height * 0.62 + terrain_height + noise_height)
		height_map.append(row)

	return height_map


# 生成所有河流，并直接把河流路径写入地形图。
func _generate_rivers(terrain_map: Array, height_map: Array) -> Array:
	var river_paths: Array = []

	for river_index in range(RIVER_COUNT):
		var start_position: Vector2i = _find_river_start_position(terrain_map, height_map, river_index, river_paths)
		var river_path: Array = _trace_river(start_position, terrain_map, height_map, river_index)
		if river_path.size() > 0:
			river_paths.append(river_path)

	return river_paths


# 从雪地、岩石或地图上边缘中寻找高处起点。
func _find_river_start_position(terrain_map: Array, height_map: Array, river_index: int, existing_paths: Array) -> Vector2i:
	var preferred_x: float = float(river_index + 1) / float(RIVER_COUNT + 1) * float(MAP_WIDTH - 1)
	var best_position: Vector2i = Vector2i(int(preferred_x), 0)
	var best_score: float = -9999.0

	for y in range(0, int(MAP_HEIGHT * 0.36)):
		for x in range(MAP_WIDTH):
			var candidate: Vector2i = Vector2i(x, y)
			if _is_near_existing_river(candidate, existing_paths, 10):
				continue

			var terrain_type: String = str(terrain_map[y][x])
			var source_bonus: float = _get_river_source_bonus(terrain_type, y)
			var spread_penalty: float = abs(float(x) - preferred_x) / float(MAP_WIDTH)
			var score: float = float(height_map[y][x]) + source_bonus - spread_penalty * 0.22
			if score > best_score:
				best_score = score
				best_position = candidate

	return best_position


# 追踪单条河流。河流会倾向低处和地图边缘，同时保留弯曲。
func _trace_river(start_position: Vector2i, terrain_map: Array, height_map: Array, river_index: int) -> Array:
	var river_path: Array = []
	var visited: Dictionary = {}
	var current_position: Vector2i = start_position
	var previous_position: Vector2i = Vector2i(-999, -999)

	for step in range(RIVER_MAX_STEPS):
		if not _is_inside_map(current_position.x, current_position.y):
			break

		river_path.append(current_position)
		visited[str(current_position.x) + "," + str(current_position.y)] = true
		_paint_river_cell(terrain_map, current_position, step, river_index)

		if step >= RIVER_MIN_LENGTH and _is_map_edge(current_position):
			break

		var next_position: Vector2i = _choose_next_river_step(
			current_position,
			previous_position,
			terrain_map,
			height_map,
			visited,
			river_index,
			step
		)
		if next_position == current_position:
			break

		previous_position = current_position
		current_position = next_position

	return river_path


# 选择下一步。分数越低越适合：优先低处、边缘方向、轻微弯曲，避免折返和打圈。
func _choose_next_river_step(
	current_position: Vector2i,
	previous_position: Vector2i,
	terrain_map: Array,
	height_map: Array,
	visited: Dictionary,
	river_index: int,
	step: int
) -> Vector2i:
	var best_position: Vector2i = current_position
	var best_score: float = 999999.0
	var target_position: Vector2 = _get_river_target_position(river_index)
	var current_height: float = float(height_map[current_position.y][current_position.x])

	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue

			var candidate: Vector2i = current_position + Vector2i(offset_x, offset_y)
			if not _is_inside_map(candidate.x, candidate.y):
				continue
			if candidate == previous_position:
				continue

			var candidate_height: float = float(height_map[candidate.y][candidate.x])
			var candidate_vector: Vector2 = Vector2(float(candidate.x), float(candidate.y))
			var target_distance: float = candidate_vector.distance_to(target_position) / float(MAP_WIDTH)
			var uphill_penalty: float = max(candidate_height - current_height, 0.0) * 1.8
			var downhill_bonus: float = min(candidate_height - current_height, 0.0) * 0.4
			var meander: float = _get_river_meander(candidate, river_index, step)
			var visited_penalty: float = 0.65 if visited.has(str(candidate.x) + "," + str(candidate.y)) else 0.0
			var water_penalty: float = 0.28 if str(terrain_map[candidate.y][candidate.x]) == TERRAIN_WATER else 0.0
			var edge_finish_bonus: float = -0.35 if step > RIVER_MIN_LENGTH and _is_map_edge(candidate) else 0.0
			var score: float = candidate_height + target_distance * 0.72 + uphill_penalty + downhill_bonus + meander + visited_penalty + water_penalty + edge_finish_bonus

			if score < best_score:
				best_score = score
				best_position = candidate

	return best_position


# 把河流写入地形图，宽度为 1~2 格。
func _paint_river_cell(terrain_map: Array, position: Vector2i, step: int, river_index: int) -> void:
	terrain_map[position.y][position.x] = TERRAIN_WATER

	if _get_river_width(position, step, river_index) < 2:
		return

	var side_offset: Vector2i = _get_river_side_offset(position, river_index)
	var side_position: Vector2i = position + side_offset
	if _is_inside_map(side_position.x, side_position.y):
		terrain_map[side_position.y][side_position.x] = TERRAIN_WATER


# 根据噪声决定河流局部宽度。
func _get_river_width(position: Vector2i, step: int, river_index: int) -> int:
	var width_noise: float = _get_hash_noise(position.x + river_index * 31, position.y + step * 7)
	return 2 if width_noise > 0.62 else 1


# 选择河流加宽方向。
func _get_river_side_offset(position: Vector2i, river_index: int) -> Vector2i:
	var side_noise: float = _get_hash_noise(position.x + river_index * 19, position.y + 53)
	if side_noise < 0.25:
		return Vector2i(1, 0)
	if side_noise < 0.5:
		return Vector2i(-1, 0)
	if side_noise < 0.75:
		return Vector2i(0, 1)
	return Vector2i(0, -1)


# 河流起点地形加权。
func _get_river_source_bonus(terrain_type: String, y: int) -> float:
	if terrain_type == TERRAIN_SNOW:
		return 0.42
	if terrain_type == TERRAIN_ROCK:
		return 0.34
	if y == 0:
		return 0.24
	return 0.0


# 地形高度加权。
func _get_terrain_height_bonus(terrain_type: String) -> float:
	if terrain_type == TERRAIN_SNOW:
		return 0.24
	if terrain_type == TERRAIN_ROCK:
		return 0.18
	if terrain_type == TERRAIN_DIRT:
		return 0.03
	if terrain_type == TERRAIN_DEAD_GROUND:
		return -0.04
	return 0.0


# 河流目标点。默认让河流最终趋向不同地图边缘，避免重叠。
func _get_river_target_position(river_index: int) -> Vector2:
	if river_index % 2 == 0:
		return Vector2(float(MAP_WIDTH - 1), float(MAP_HEIGHT - 16))
	return Vector2(float(12), float(MAP_HEIGHT - 1))


# 给河流一点自然弯曲。
func _get_river_meander(position: Vector2i, river_index: int, step: int) -> float:
	var noise_value: float = _get_hash_noise(position.x + river_index * 47, position.y + step * 13)
	return (noise_value - 0.5) * 0.22


# 判断是否靠近已有河流，避免两条河从同一个地方出发。
func _is_near_existing_river(position: Vector2i, river_paths: Array, min_distance: int) -> bool:
	var position_vector: Vector2 = Vector2(float(position.x), float(position.y))
	for river_path in river_paths:
		for river_position in river_path:
			var river_position_vector: Vector2 = Vector2(float(river_position.x), float(river_position.y))
			if position_vector.distance_to(river_position_vector) < float(min_distance):
				return true
	return false


# 判断是否到达地图边缘。
func _is_map_edge(position: Vector2i) -> bool:
	return position.x <= 0 or position.y <= 0 or position.x >= MAP_WIDTH - 1 or position.y >= MAP_HEIGHT - 1


# 双线性采样地形颜色，让 100 x 100 逻辑地图显示成连续底图。
func _sample_smooth_terrain_color(terrain_map: Array, pixel_x: int, pixel_y: int) -> Color:
	var map_x: float = float(pixel_x) / float(RENDER_TEXTURE_SIZE - 1) * float(MAP_WIDTH - 1)
	var map_y: float = float(pixel_y) / float(RENDER_TEXTURE_SIZE - 1) * float(MAP_HEIGHT - 1)
	var x0: int = int(floor(map_x))
	var y0: int = int(floor(map_y))
	var x1: int = min(x0 + 1, MAP_WIDTH - 1)
	var y1: int = min(y0 + 1, MAP_HEIGHT - 1)
	var tx: float = _smoothstep(map_x - float(x0))
	var ty: float = _smoothstep(map_y - float(y0))

	var color_00: Color = _get_terrain_color(str(terrain_map[y0][x0]))
	var color_10: Color = _get_terrain_color(str(terrain_map[y0][x1]))
	var color_01: Color = _get_terrain_color(str(terrain_map[y1][x0]))
	var color_11: Color = _get_terrain_color(str(terrain_map[y1][x1]))

	var top_color: Color = color_00.lerp(color_10, tx)
	var bottom_color: Color = color_01.lerp(color_11, tx)
	return top_color.lerp(bottom_color, ty)


# 创建地形主噪声。
func _create_terrain_noise() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.45
	return noise


# 创建高度噪声，用于辅助河流寻找低处。
func _create_height_noise() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed + 41
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.48
	return noise


# 创建细节噪声，只用于颜色明暗变化，不改变地形类型。
func _create_detail_noise() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed + 97
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.018
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise


# 取百分位阈值。
func _get_percentile(sorted_values: Array, ratio: float) -> float:
	var index: int = int(clamp(floor(float(sorted_values.size() - 1) * ratio), 0.0, float(sorted_values.size() - 1)))
	return float(sorted_values[index])


# 获取周围最常见的地形。
func _get_dominant_neighbor_terrain(terrain_map: Array, center_x: int, center_y: int) -> String:
	var counts: Dictionary = {}

	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue

			var check_x: int = center_x + offset_x
			var check_y: int = center_y + offset_y
			if not _is_inside_map(check_x, check_y):
				continue

			var terrain_type: String = str(terrain_map[check_y][check_x])
			counts[terrain_type] = int(counts.get(terrain_type, 0)) + 1

	var best_terrain: String = ""
	var best_count: int = 0
	for terrain_type in counts.keys():
		var count: int = int(counts[terrain_type])
		if count > best_count:
			best_terrain = str(terrain_type)
			best_count = count

	return best_terrain if best_count >= 5 else ""


# 统计周围同类地形数量。
func _count_neighbor_terrain(terrain_map: Array, center_x: int, center_y: int, target_terrain: String) -> int:
	var count: int = 0

	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue

			var check_x: int = center_x + offset_x
			var check_y: int = center_y + offset_y
			if _is_inside_map(check_x, check_y) and str(terrain_map[check_y][check_x]) == target_terrain:
				count += 1

	return count


# 复制地形地图。
func _copy_terrain_map(terrain_map: Array) -> Array:
	var copied_map: Array = []
	for row in terrain_map:
		copied_map.append(row.duplicate())
	return copied_map


# 统计各地形数量，方便后续调试比例。
func _count_terrains(terrain_map: Array) -> Dictionary:
	var counts: Dictionary = {}
	counts[TERRAIN_GRASS] = 0
	counts[TERRAIN_DIRT] = 0
	counts[TERRAIN_ROCK] = 0
	counts[TERRAIN_SNOW] = 0
	counts[TERRAIN_DEAD_GROUND] = 0
	counts[TERRAIN_WATER] = 0

	for row in terrain_map:
		for terrain_type in row:
			counts[str(terrain_type)] = int(counts.get(str(terrain_type), 0)) + 1

	return counts


# 获取地形颜色。
func _get_terrain_color(terrain_type: String) -> Color:
	var terrain_color: Color = TERRAIN_COLORS.get(terrain_type, TERRAIN_COLORS[TERRAIN_GRASS]) as Color
	return terrain_color


# 给颜色加一点明暗细节。
func _apply_detail(color: Color, detail_value: float) -> Color:
	return Color(
		clamp(color.r + detail_value, 0.0, 1.0),
		clamp(color.g + detail_value, 0.0, 1.0),
		clamp(color.b + detail_value, 0.0, 1.0),
		color.a
	)


# 平滑插值，避免地形颜色边界硬切。
func _smoothstep(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# 简单固定哈希噪声，用于河流宽度和弯曲。
func _get_hash_noise(x: int, y: int) -> float:
	var raw_value: int = abs((x * 928371 + y * 364479 + seed * 97) % 10000)
	return float(raw_value) / 10000.0


# 判断坐标是否在地图内。
func _is_inside_map(x: int, y: int) -> bool:
	return x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT
