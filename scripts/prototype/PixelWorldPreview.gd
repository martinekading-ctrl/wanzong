@tool
extends Node2D

# 独立修仙像素世界视觉样张，不读取正式 World 数据，也不包含玩法交互。

const WORLD_SIZE: Vector2i = WorldMapSpec.WORLD_SIZE
const TILE_SIZE: Vector2i = WorldMapSpec.TILE_SIZE
const GRID_SIZE: Vector2i = WorldMapSpec.GRID_SIZE

const WORLD_OBJECT_DIRECTORY: String = "res://assets/pixel/world_objects/processed"
const TREE_ICON_SIZE: int = 28
const PINE_ICON_SIZE: int = 30
const BAMBOO_ICON_SIZE: int = 28
const ROCK_ICON_SIZE: int = 24
const HILL_ICON_SIZE: int = 34
const MOUNTAIN_ICON_SIZE: int = 38
const SNOW_MOUNTAIN_ICON_SIZE: int = 42
const SPECIAL_TREE_ICON_SIZE: int = 34

const DEEP_WATER: String = "deep_water"
const WATER: String = "water"
const SHALLOW_WATER: String = "shallow_water"
const SAND: String = "sand"
const GRASS: String = "grass"
const FROST_GRASS: String = "frost_grass"
const FOREST: String = "forest"
const DIRT: String = "dirt"
const MOUNTAIN: String = "mountain"
const SNOW: String = "snow"
const WASTELAND: String = "wasteland"

const TILE_COLORS: Dictionary = {
	DEEP_WATER: Color("#1f5f9e"),
	WATER: Color("#2f7fc0"),
	SHALLOW_WATER: Color("#65b6d6"),
	SAND: Color("#e2c16f"),
	GRASS: Color("#5fa34a"),
	FROST_GRASS: Color("#759a7c"),
	FOREST: Color("#2f6b3c"),
	DIRT: Color("#8b6138"),
	MOUNTAIN: Color("#777066"),
	SNOW: Color("#dceff2"),
	WASTELAND: Color("#9b7a42"),
}

const TILE_ACCENTS: Dictionary = {
	DEEP_WATER: Color("#174b80"),
	WATER: Color("#286da5"),
	SHALLOW_WATER: Color("#8acde3"),
	SAND: Color("#c9a95b"),
	GRASS: Color("#45843d"),
	FROST_GRASS: Color("#a8bcae"),
	FOREST: Color("#1f4f31"),
	DIRT: Color("#704a2c"),
	MOUNTAIN: Color("#55504a"),
	SNOW: Color("#a9cfd8"),
	WASTELAND: Color("#775d31"),
}

# 五座外围小岛，位置与形状属于《万宗》自己的世界布局。
const ISLAND_SPECS: Array = [
	{"center": Vector2(0.060, 0.29), "radius": Vector2(0.050, 0.040)},
	{"center": Vector2(0.940, 0.27), "radius": Vector2(0.055, 0.042)},
	{"center": Vector2(0.055, 0.71), "radius": Vector2(0.058, 0.045)},
	{"center": Vector2(0.945, 0.72), "radius": Vector2(0.060, 0.044)},
	{"center": Vector2(0.52, 0.94), "radius": Vector2(0.055, 0.036)},
]

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var preview_camera: Camera2D = $PreviewCamera

@export var preview_mode: bool = true
@export var regenerate_preview_now: bool = false:
	set(value):
		regenerate_preview_now = false
		if value and Engine.is_editor_hint():
			call_deferred("generate_for_bake")

var terrain_map: Array = []
var terrain_sources: Dictionary = {}
var tree_markers: Array[Dictionary] = []
var mountain_markers: Array[Vector2i] = []
var snow_markers: Array[Vector2i] = []
var wasteland_markers: Array[Vector2i] = []
var rock_markers: Array[Vector2i] = []
var hill_markers: Array[Vector2i] = []
var sect_cells: Array[Vector2i] = []
var resource_cells: Array[Vector2i] = []
var marker_placement_valid: bool = true

var tree_green_textures: Array[Texture2D] = []
var tree_pine_textures: Array[Texture2D] = []
var bamboo_textures: Array[Texture2D] = []
var dead_tree_textures: Array[Texture2D] = []
var spirit_tree_textures: Array[Texture2D] = []
var rock_textures: Array[Texture2D] = []
var hill_textures: Array[Texture2D] = []
var mountain_rock_textures: Array[Texture2D] = []
var mountain_snow_textures: Array[Texture2D] = []

var continent_noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()
var river_noise := FastNoiseLite.new()

var move_speed: float = 900.0
var min_zoom: float = 0.31
var max_zoom: float = 2.0
var zoom_step: float = 0.12


func _ready() -> void:
	if Engine.is_editor_hint():
		preview_camera.enabled = false
		return
	generate_for_bake()


func generate_for_bake() -> void:
	var ready_started_at: int = Time.get_ticks_msec()
	_setup_noises()
	_load_world_object_textures()
	_create_tile_set()
	_generate_world()
	_collect_nature_markers()
	if preview_mode:
		_place_world_markers()
		preview_camera.position = Vector2(WORLD_SIZE) * 0.5
		preview_camera.zoom = Vector2(0.32, 0.32)
		preview_camera.make_current()
	else:
		sect_cells.clear()
		resource_cells.clear()
		preview_camera.enabled = false
	queue_redraw()
	print("[WorldPerf] PixelWorldPreview ready total: %d ms" % (Time.get_ticks_msec() - ready_started_at))


func _process(delta: float) -> void:
	if not preview_mode:
		return

	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		preview_camera.position += direction.normalized() * move_speed * delta / preview_camera.zoom.x
		_clamp_camera()


func _unhandled_input(event: InputEvent) -> void:
	if not preview_mode:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom(preview_camera.zoom.x + zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom(preview_camera.zoom.x - zoom_step)


# 自然物先绘制，宗门和资源标记最后绘制，保证地图信息清楚。
func _draw() -> void:
	for marker in tree_markers:
		_draw_tree_object(
			_cell_center(marker["cell"]) + marker["offset"],
			str(marker["kind"]),
			int(marker["variant"])
		)

	for cell in mountain_markers:
		_draw_texture_variant(
			mountain_rock_textures,
			_cell_center(cell),
			MOUNTAIN_ICON_SIZE,
			_cell_hash(cell.x, cell.y)
		)

	for cell in snow_markers:
		_draw_texture_variant(
			mountain_snow_textures,
			_cell_center(cell),
			SNOW_MOUNTAIN_ICON_SIZE,
			_cell_hash(cell.x, cell.y)
		)

	for cell in wasteland_markers:
		_draw_tree_object(_cell_center(cell), "dead", _cell_hash(cell.x, cell.y))

	for cell in rock_markers:
		_draw_texture_variant(
			rock_textures,
			_cell_center(cell),
			ROCK_ICON_SIZE,
			_cell_hash(cell.x, cell.y)
		)

	for cell in hill_markers:
		_draw_texture_variant(
			hill_textures,
			_cell_center(cell),
			HILL_ICON_SIZE,
			_cell_hash(cell.x, cell.y)
		)

	for sect_index in range(sect_cells.size()):
		_draw_sect(_cell_center(sect_cells[sect_index]), sect_index)

	for resource_index in range(resource_cells.size()):
		_draw_resource(_cell_center(resource_cells[resource_index]), resource_index % 3)


func _load_world_object_textures() -> void:
	tree_green_textures = _load_texture_series("trees", "tree_green", 5)
	tree_pine_textures = _load_texture_series("trees", "tree_pine", 2)
	bamboo_textures = _load_texture_series("bamboo", "bamboo", 3)
	dead_tree_textures = _load_texture_series("special", "tree_dead", 2)
	spirit_tree_textures = _load_named_textures(
		["special/resource_spirit_tree_01.png"]
	)
	rock_textures = _load_texture_series("rocks", "rock", 8)
	hill_textures = _load_texture_series("hills", "hill_grass", 4)
	mountain_rock_textures = _load_texture_series("mountains", "mountain_rock", 6)
	mountain_snow_textures = _load_texture_series("mountains", "mountain_snow", 4)


func _load_texture_series(category: String, prefix: String, count: int) -> Array[Texture2D]:
	var relative_paths: Array[String] = []
	for texture_index in range(1, count + 1):
		relative_paths.append(
			category.path_join("%s_%02d.png" % [prefix, texture_index])
		)
	return _load_named_textures(relative_paths)


func _load_named_textures(relative_paths: Array[String]) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for relative_path in relative_paths:
		var texture_path: String = WORLD_OBJECT_DIRECTORY.path_join(relative_path)
		var texture: Texture2D = load(texture_path) as Texture2D
		if texture == null:
			push_warning("World object texture could not be loaded: " + texture_path)
			continue
		textures.append(texture)
	return textures


func _setup_noises() -> void:
	continent_noise.seed = 1902001
	continent_noise.frequency = 0.012 * WorldMapSpec.NOISE_FREQUENCY_SCALE
	continent_noise.fractal_octaves = 4
	continent_noise.fractal_gain = 0.52

	biome_noise.seed = 1902002
	biome_noise.frequency = 0.018 * WorldMapSpec.NOISE_FREQUENCY_SCALE
	biome_noise.fractal_octaves = 3

	forest_noise.seed = 1902003
	forest_noise.frequency = 0.027 * WorldMapSpec.NOISE_FREQUENCY_SCALE
	forest_noise.fractal_octaves = 3

	river_noise.seed = 1902004
	river_noise.frequency = 0.016 * WorldMapSpec.NOISE_FREQUENCY_SCALE
	river_noise.fractal_octaves = 3


# 每类地形使用八个同色系变体，保持细节但不形成规则纹路。
func _create_tile_set() -> void:
	var started_at: int = Time.get_ticks_msec()
	terrain_layer.tile_set = TileSet.new()
	terrain_layer.tile_set.tile_size = TILE_SIZE
	terrain_sources.clear()

	for terrain_type in TILE_COLORS.keys():
		var source_ids: Array[int] = []
		for variant in range(8):
			var base_color: Color = TILE_COLORS[terrain_type]
			if variant % 4 == 1:
				base_color = base_color.lightened(0.025)
			elif variant % 4 == 2:
				base_color = base_color.darkened(0.025)

			var source := TileSetAtlasSource.new()
			source.texture = _create_tile_texture(
				terrain_type,
				base_color,
				TILE_ACCENTS[terrain_type],
				variant
			)
			source.texture_region_size = TILE_SIZE
			source.create_tile(Vector2i.ZERO)
			source_ids.append(terrain_layer.tile_set.add_source(source))

		terrain_sources[terrain_type] = source_ids
	print("[WorldPerf] create_tile_set: %d ms" % (Time.get_ticks_msec() - started_at))


# 地表 Tile 只画细小像素纹理，大型树木和山峰作为独立对象绘制。
func _create_tile_texture(
	terrain_type: String,
	base_color: Color,
	accent_color: Color,
	variant: int
) -> Texture2D:
	var image := Image.create_empty(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(base_color)

	if terrain_type == DEEP_WATER or terrain_type == WATER or terrain_type == SHALLOW_WATER:
		for line_index in range(2):
			var line_y: int = 4 + line_index * 7 + variant % 2
			for line_x in range(2, 14):
				if (line_x + variant + line_index) % 6 < 3:
					image.set_pixel(line_x, line_y, accent_color)
	elif terrain_type == SAND:
		for point_index in range(5):
			var shore_x: int = 2 + (point_index * 5 + variant * 3) % 12
			var shore_y: int = 3 + (point_index * 7 + variant * 2) % 10
			image.set_pixel(shore_x, shore_y, accent_color)
	elif terrain_type == SNOW:
		for point_index in range(4):
			var snow_x: int = 2 + (point_index * 7 + variant) % 12
			var snow_y: int = 2 + (point_index * 5 + variant * 3) % 12
			image.set_pixel(snow_x, snow_y, accent_color)
	else:
		for point_index in range(5):
			var point_x: int = 2 + (point_index * 5 + variant * 3 + terrain_type.length()) % 12
			var point_y: int = 2 + (point_index * 7 + variant * 5) % 12
			image.set_pixel(point_x, point_y, accent_color)
			if terrain_type == WASTELAND and point_index < 2:
				image.set_pixel(point_x, mini(point_y + 1, 15), accent_color)

	return ImageTexture.create_from_image(image)


# 先生成修仙大陆，再添加海岸和深浅水过渡。
func _generate_world() -> void:
	var started_at: int = Time.get_ticks_msec()
	var raw_map: Array = []
	for cell_y in range(GRID_SIZE.y):
		var row: Array[String] = []
		row.resize(GRID_SIZE.x)
		for cell_x in range(GRID_SIZE.x):
			row[cell_x] = _get_raw_terrain(cell_x, cell_y)
		raw_map.append(row)

	terrain_map.clear()
	terrain_layer.clear()
	for cell_y in range(GRID_SIZE.y):
		var final_row: Array[String] = []
		final_row.resize(GRID_SIZE.x)
		for cell_x in range(GRID_SIZE.x):
			var cell := Vector2i(cell_x, cell_y)
			var terrain_type: String = str(raw_map[cell_y][cell_x])
			terrain_type = _apply_biome_transitions(cell, terrain_type, raw_map)
			final_row[cell_x] = terrain_type
			_set_terrain_cell(cell, terrain_type)
		terrain_map.append(final_row)
	print("[WorldPerf] generate_world: %d ms" % (Time.get_ticks_msec() - started_at))


# 大陆轮廓独立生成，内部按修仙地域划分寒域、剑山、荒土和灵州。
func _get_raw_terrain(cell_x: int, cell_y: int) -> String:
	var normalized_x: float = float(cell_x) / float(GRID_SIZE.x - 1)
	var normalized_y: float = float(cell_y) / float(GRID_SIZE.y - 1)
	var world_position := Vector2(normalized_x, normalized_y)
	var continent_value: float = continent_noise.get_noise_2d(float(cell_x), float(cell_y))

	if not _is_world_land(world_position, continent_value):
		return DEEP_WATER

	if _is_spirit_river(cell_y, normalized_x, normalized_y):
		return SHALLOW_WATER
	if _is_mirror_lake(cell_x, cell_y, world_position):
		return SHALLOW_WATER

	var biome_value: float = biome_noise.get_noise_2d(float(cell_x), float(cell_y))
	if normalized_x < 0.47 + biome_value * 0.05 and normalized_y < 0.27 + biome_value * 0.08:
		return SNOW

	if normalized_x > 0.80 + biome_value * 0.05:
		return MOUNTAIN

	if normalized_x < 0.34 + biome_value * 0.05 and normalized_y > 0.70 - biome_value * 0.06:
		return WASTELAND

	var forest_value: float = forest_noise.get_noise_2d(float(cell_x), float(cell_y))
	var river_distance: float = absf(normalized_x - _get_spirit_river_center(cell_y, normalized_y))
	var near_river_forest: bool = river_distance < 0.075 and forest_value > 0.10
	if (forest_value > 0.27 or near_river_forest) and normalized_y > 0.24 and normalized_x < 0.75:
		return FOREST

	if biome_value > 0.43 and normalized_y > 0.25:
		return DIRT

	return GRASS


# 中央主大陆之外再生成五座外围小岛。
func _is_world_land(world_position: Vector2, coast_noise: float) -> bool:
	var continent_center := Vector2(0.49, 0.52)
	var continent_offset := Vector2(
		(world_position.x - continent_center.x) / 0.30,
		(world_position.y - continent_center.y) / 0.32
	)
	var continent_distance: float = continent_offset.length()
	var continent_angle: float = atan2(continent_offset.y, continent_offset.x)
	var continent_edge: float = (
		1.0
		+ coast_noise * 0.28
		+ sin(continent_angle * 3.0 + 0.7) * 0.07
		+ sin(continent_angle * 7.0 - 0.4) * 0.035
	)
	if continent_distance <= continent_edge:
		return true

	for island_index in range(ISLAND_SPECS.size()):
		var island_data: Dictionary = ISLAND_SPECS[island_index]
		var island_center: Vector2 = island_data["center"]
		var island_radius: Vector2 = island_data["radius"]
		var island_offset := Vector2(
			(world_position.x - island_center.x) / island_radius.x,
			(world_position.y - island_center.y) / island_radius.y
		)
		var island_distance: float = island_offset.length()
		var island_angle: float = atan2(island_offset.y, island_offset.x)
		var island_edge: float = (
			1.0
			+ coast_noise * 0.34
			+ sin(island_angle * float(3 + island_index % 3) + float(island_index)) * 0.16
			+ sin(island_angle * float(6 + island_index % 2) - 0.8) * 0.08
		)
		if island_distance <= island_edge:
			return true

	return false


# 灵河由北部寒域发源，穿过中央灵州后流向南海。
func _is_spirit_river(cell_y: int, normalized_x: float, normalized_y: float) -> bool:
	var river_center: float = _get_spirit_river_center(cell_y, normalized_y)
	var river_width: float = 0.008 + (sin(normalized_y * TAU * 2.2) + 1.0) * 0.003
	return absf(normalized_x - river_center) <= river_width


func _get_spirit_river_center(cell_y: int, normalized_y: float) -> float:
	var curve: float = sin(normalized_y * TAU * 1.55) * 0.075
	curve += sin(normalized_y * TAU * 3.4 + 0.8) * 0.018
	var natural_offset: float = river_noise.get_noise_1d(float(cell_y)) * 0.04
	return 0.48 + curve + natural_offset


func _is_mirror_lake(cell_x: int, cell_y: int, world_position: Vector2) -> bool:
	var lake_center := Vector2(0.60, 0.36)
	var lake_noise: float = continent_noise.get_noise_2d(float(cell_x) * 1.8, float(cell_y) * 1.8)
	return world_position.distance_to(lake_center) < 0.055 + lake_noise * 0.014


# 水边生成浅水和沙岸，雪地边缘生成一圈霜草过渡。
func _apply_biome_transitions(cell: Vector2i, terrain_type: String, raw_map: Array) -> String:
	var is_water: bool = _is_water(terrain_type)

	if is_water:
		var distance_to_land: int = _get_nearest_opposite_distance(raw_map, cell, true, 6)
		if distance_to_land <= 2:
			return SHALLOW_WATER
		if distance_to_land <= 5:
			return WATER
		return DEEP_WATER

	var distance_to_water: int = _get_nearest_opposite_distance(raw_map, cell, false, 3)
	var uneven_sand_edge: bool = distance_to_water == 2 and _cell_hash(cell.x, cell.y) % 4 == 0
	if distance_to_water <= 1 or uneven_sand_edge:
		return SAND

	if _has_raw_neighbor(raw_map, cell, SNOW, 2) and (
		terrain_type == GRASS or terrain_type == FOREST or terrain_type == DIRT
	):
		return FROST_GRASS

	if _has_raw_neighbor(raw_map, cell, MOUNTAIN, 2) and (
		terrain_type == GRASS or terrain_type == FOREST
	) and _cell_hash(cell.x, cell.y) % 3 != 0:
		return DIRT

	return terrain_type


# 查找距离最近的陆地或水域，用于构造稳定的五层海岸。
func _get_nearest_opposite_distance(
	raw_map: Array,
	cell: Vector2i,
	seek_land: bool,
	max_distance: int
) -> int:
	for radius in range(1, max_distance + 1):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var terrain_type: String = _raw_at(raw_map, cell + Vector2i(offset_x, offset_y))
				var matches: bool = not _is_water(terrain_type) if seek_land else _is_water(terrain_type)
				if matches:
					return radius
	return max_distance + 1


func _has_raw_neighbor(
	raw_map: Array,
	cell: Vector2i,
	target_terrain: String,
	radius: int
) -> bool:
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			if _raw_at(raw_map, cell + Vector2i(offset_x, offset_y)) == target_terrain:
				return true
	return false


func _set_terrain_cell(cell: Vector2i, terrain_type: String) -> void:
	var variants: Array = terrain_sources[terrain_type]
	var variant_index: int = _cell_hash(cell.x, cell.y) % variants.size()
	terrain_layer.set_cell(cell, int(variants[variant_index]), Vector2i.ZERO)


# 根据地形收集稀疏自然物，避免把每一格都塞满图标。
func _collect_nature_markers() -> void:
	var started_at: int = Time.get_ticks_msec()
	tree_markers.clear()
	mountain_markers.clear()
	snow_markers.clear()
	wasteland_markers.clear()
	rock_markers.clear()
	hill_markers.clear()

	for cell_y in range(2, GRID_SIZE.y - 2):
		for cell_x in range(2, GRID_SIZE.x - 2):
			var cell := Vector2i(cell_x, cell_y)
			var terrain_type: String = _terrain_at(cell)
			var hash_value: int = _cell_hash(cell_x, cell_y)

			if terrain_type == FOREST:
				if hash_value % 5000 < 2:
					_add_tree_marker(cell, "spirit", hash_value)
				elif _is_near_water(cell, 3) and hash_value % 100 < 3:
					_add_tree_marker(cell, "bamboo", hash_value)
				elif hash_value % 100 < 10:
					_add_tree_marker(cell, "green", hash_value)
			elif terrain_type == GRASS:
				if _is_near_water(cell, 2) and hash_value % 1000 < 3:
					_add_tree_marker(cell, "bamboo", hash_value)
				elif hash_value % 1000 < 6:
					hill_markers.append(cell)
				elif hash_value % 1000 < 9:
					_add_tree_marker(cell, "green", hash_value)
			elif terrain_type == MOUNTAIN:
				if hash_value % 100 < 7:
					mountain_markers.append(cell)
				elif _is_mountain_edge(cell) and hash_value % 100 < 11:
					rock_markers.append(cell)
			elif terrain_type == SNOW:
				if hash_value % 100 < 3:
					_add_tree_marker(cell, "pine", hash_value)
				elif hash_value % 100 < 4:
					snow_markers.append(cell)
			elif terrain_type == WASTELAND:
				if hash_value % 100 < 2:
					wasteland_markers.append(cell)
				elif hash_value % 100 < 5:
					rock_markers.append(cell)
	print("[WorldPerf] collect_nature_markers: %d ms" % (Time.get_ticks_msec() - started_at))


func _add_tree_marker(cell: Vector2i, kind: String, hash_value: int) -> void:
	tree_markers.append({
		"cell": cell,
		"kind": kind,
		"variant": hash_value,
		"offset": Vector2(
			float((hash_value / 7) % 13) - 6.0,
			float((hash_value / 17) % 13) - 6.0
		),
	})


func _is_near_water(cell: Vector2i, radius: int) -> bool:
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			if _is_water(_terrain_at(cell + Vector2i(offset_x, offset_y))):
				return true
	return false


func _is_mountain_edge(cell: Vector2i) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _terrain_at(cell + offset) != MOUNTAIN:
			return true
	return false


func _place_world_markers() -> void:
	var requested_sects: Array[Vector2] = [
		Vector2(0.50, 0.52), # 青玄宗，中央灵州。
		Vector2(0.24, 0.23), Vector2(0.40, 0.19), Vector2(0.70, 0.23),
		Vector2(0.83, 0.34), Vector2(0.78, 0.53), Vector2(0.82, 0.76),
		Vector2(0.59, 0.81), Vector2(0.30, 0.80), Vector2(0.19, 0.54),
	]
	var occupied: Dictionary = {}
	marker_placement_valid = true
	sect_cells.clear()
	for requested_anchor in requested_sects:
		var sect_cell := _find_marker_land(WorldMapSpec.normalized_to_cell(requested_anchor), occupied)
		if sect_cell.x < 0:
			marker_placement_valid = false
			push_error("World map baker could not place a sect marker on safe land.")
			continue
		sect_cells.append(sect_cell)
		occupied[sect_cell] = true

	resource_cells.clear()
	var margin: int = WorldMapSpec.marker_margin_cells()
	var usable: int = GRID_SIZE.x - margin * 2
	for resource_index in range(20):
		var requested_cell := Vector2i(
			margin + (resource_index * 71 + 29) % usable,
			margin + (resource_index * 107 + 53) % usable
		)
		var resource_cell := _find_marker_land(requested_cell, occupied)
		if resource_cell.x < 0:
			marker_placement_valid = false
			push_error("World map baker could not place every resource marker on safe land.")
			continue
		resource_cells.append(resource_cell)
		occupied[resource_cell] = true


func _find_marker_land(start_cell: Vector2i, occupied: Dictionary = {}) -> Vector2i:
	if _can_place_marker(_terrain_at(start_cell)) and not occupied.has(start_cell):
		return start_cell

	for radius in range(1, WorldMapSpec.marker_search_radius_cells() + 1):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var candidate := start_cell + Vector2i(offset_x, offset_y)
				if _can_place_marker(_terrain_at(candidate)) and not occupied.has(candidate):
					return candidate
	return Vector2i(-1, -1)


func _can_place_marker(terrain_type: String) -> bool:
	return _is_safe_marker_terrain(terrain_type)


func _draw_tree_object(position: Vector2, kind: String, variant: int) -> void:
	if kind == "pine":
		_draw_texture_variant(tree_pine_textures, position, PINE_ICON_SIZE, variant)
	elif kind == "bamboo":
		_draw_texture_variant(bamboo_textures, position, BAMBOO_ICON_SIZE, variant)
	elif kind == "dead":
		_draw_texture_variant(dead_tree_textures, position, SPECIAL_TREE_ICON_SIZE, variant)
	elif kind == "spirit":
		_draw_texture_variant(spirit_tree_textures, position, SPECIAL_TREE_ICON_SIZE, variant)
	else:
		_draw_texture_variant(tree_green_textures, position, TREE_ICON_SIZE, variant)


func _draw_texture_variant(
	textures: Array[Texture2D],
	position: Vector2,
	icon_size: int,
	variant: int
) -> void:
	if textures.is_empty():
		return
	var texture: Texture2D = textures[abs(variant) % textures.size()]
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = float(icon_size) / maxf(source_size.x, source_size.y)
	var draw_size: Vector2 = (source_size * scale_factor).round()
	var draw_position := Vector2(
		roundf(position.x - draw_size.x * 0.5),
		roundf(position.y - draw_size.y)
	)
	draw_texture_rect(texture, Rect2(draw_position, draw_size), false)


# 宗门使用像素山门建筑，玩家青云宗为金绿配色。
func _draw_sect(position: Vector2, sect_index: int) -> void:
	var player: bool = sect_index == 0
	var roof: Color = Color("#d8bc55") if player else (Color("#4d83b6") if sect_index % 2 == 0 else Color("#a65353"))
	var wall: Color = Color("#d5c69d") if player else Color("#b8b1a0")
	var origin := position - Vector2(12, 12)

	draw_rect(Rect2(origin + Vector2(2, 18), Vector2(20, 5)), Color("#30383a"))
	draw_rect(Rect2(origin + Vector2(5, 10), Vector2(14, 10)), wall)
	draw_rect(Rect2(origin + Vector2(3, 7), Vector2(18, 4)), roof.darkened(0.18))
	draw_rect(Rect2(origin + Vector2(6, 4), Vector2(12, 4)), roof)
	draw_rect(Rect2(origin + Vector2(10, 13), Vector2(4, 7)), Color("#4b3a2d"))
	if player:
		draw_rect(Rect2(origin + Vector2(11, 1), Vector2(2, 5)), Color("#f1dd79"))


# 灵矿、灵草和秘境入口使用修仙主题像素符号。
func _draw_resource(position: Vector2, resource_type: int) -> void:
	var origin := position.floor()
	if resource_type == 0:
		var purple := Color("#9a68b8")
		draw_rect(Rect2(origin + Vector2(-5, -3), Vector2(10, 7)), Color("#493a55"))
		draw_rect(Rect2(origin + Vector2(-2, -8), Vector2(5, 12)), purple)
		draw_rect(Rect2(origin + Vector2(1, -6), Vector2(2, 7)), purple.lightened(0.22))
	elif resource_type == 1:
		var herb := Color("#72b95c")
		draw_rect(Rect2(origin + Vector2(-1, -7), Vector2(2, 13)), Color("#315b32"))
		draw_rect(Rect2(origin + Vector2(-7, -4), Vector2(6, 4)), herb)
		draw_rect(Rect2(origin + Vector2(1, -1), Vector2(7, 4)), herb.lightened(0.12))
	else:
		var gold := Color("#d6b64c")
		draw_rect(Rect2(origin + Vector2(-6, -8), Vector2(12, 16)), Color("#4f4229"))
		draw_rect(Rect2(origin + Vector2(-4, -6), Vector2(8, 14)), gold)
		draw_rect(Rect2(origin + Vector2(-1, -2), Vector2(2, 10)), Color("#453a27"))


func _raw_at(raw_map: Array, cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return DEEP_WATER
	return str(raw_map[cell.y][cell.x])


func _terrain_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return DEEP_WATER
	return str(terrain_map[cell.y][cell.x])


# 为正式宗门和资源点寻找最近的安全陆地显示位置。
func find_nearest_land_world_position(world_position: Vector2) -> Vector2:
	var start_cell := Vector2i(
		clampi(int(world_position.x / TILE_SIZE.x), 0, GRID_SIZE.x - 1),
		clampi(int(world_position.y / TILE_SIZE.y), 0, GRID_SIZE.y - 1)
	)
	if _is_safe_marker_terrain(_terrain_at(start_cell)):
		return _cell_center(start_cell)

	for radius in range(1, WorldMapSpec.marker_search_radius_cells() + 1):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var candidate := start_cell + Vector2i(offset_x, offset_y)
				if _is_safe_marker_terrain(_terrain_at(candidate)):
					return _cell_center(candidate)
	return world_position


func _is_safe_marker_terrain(terrain_type: String) -> bool:
	return (
		not _is_water(terrain_type)
		and terrain_type != MOUNTAIN
		and terrain_type != SAND
	)


func _is_water(terrain_type: String) -> bool:
	return terrain_type == DEEP_WATER or terrain_type == WATER or terrain_type == SHALLOW_WATER


func _cell_center(cell: Vector2i) -> Vector2:
	return WorldMapSpec.cell_center(cell)


func _cell_hash(cell_x: int, cell_y: int) -> int:
	return abs(
		cell_x * 928371
		+ cell_y * 364479
		+ cell_x * cell_y * 97
		+ 1902
	)


func _set_camera_zoom(new_zoom: float) -> void:
	var zoom_value: float = clampf(new_zoom, min_zoom, max_zoom)
	preview_camera.zoom = Vector2(zoom_value, zoom_value)
	_clamp_camera()


func _clamp_camera() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view: Vector2 = viewport_size / (preview_camera.zoom * 2.0)
	if half_view.x * 2.0 >= WORLD_SIZE.x:
		preview_camera.position.x = WorldMapSpec.world_center().x
	else:
		preview_camera.position.x = clampf(preview_camera.position.x, half_view.x, WORLD_SIZE.x - half_view.x)
	if half_view.y * 2.0 >= WORLD_SIZE.y:
		preview_camera.position.y = WorldMapSpec.world_center().y
	else:
		preview_camera.position.y = clampf(preview_camera.position.y, half_view.y, WORLD_SIZE.y - half_view.y)
