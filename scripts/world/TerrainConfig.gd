extends RefCounted
class_name TerrainConfig

# 当前地图地形格子尺寸。4096 / 256 = 16，所以整张地图为 16 x 16 个地形格。
const TILE_SIZE := 256

# 当前参与世界地图生成的地形类型。
const TERRAIN_TYPES := [
	"grass",
	"dirt",
	"rock",
	"snow",
	"dead_ground",
]

# 地形类型对应的素材路径。
const TERRAIN_TEXTURE_PATHS := {
	"grass": [
		"res://assets/terrain/grass/grass_01.png",
		"res://assets/terrain/grass/grass_02.png",
		"res://assets/terrain/grass/grass_03.png",
		"res://assets/terrain/grass/grass_04.png",
		"res://assets/terrain/grass/grass_05.png",
	],
	"dirt": [
		"res://assets/terrain/dirt/dirt_01.png",
		"res://assets/terrain/dirt/dirt_02.png",
		"res://assets/terrain/dirt/dirt_03.png",
	],
	"rock": [
		"res://assets/terrain/rock/rock_01.png",
		"res://assets/terrain/rock/rock_02.png",
		"res://assets/terrain/rock/rock_03.png",
		"res://assets/terrain/rock/rock_04.png",
	],
	"snow": [
		"res://assets/terrain/snow/snow_01.png",
		"res://assets/terrain/snow/snow_02.png",
		"res://assets/terrain/snow/snow_03.png",
		"res://assets/terrain/snow/snow_04.png",
		"res://assets/terrain/snow/snow_05.png",
	],
	"dead_ground": [
		"res://assets/terrain/dead_ground/dead_ground_01.png",
		"res://assets/terrain/dead_ground/dead_ground_02.png",
		"res://assets/terrain/dead_ground/dead_ground_03.png",
		"res://assets/terrain/dead_ground/dead_ground_04.png",
		"res://assets/terrain/dead_ground/dead_ground_05.png",
	],
}


# 获取所有参与地图生成的地形类型。
static func get_terrain_types() -> Array:
	return TERRAIN_TYPES


# 获取指定地形类型的素材路径列表。
static func get_texture_paths(terrain_type: String) -> Array:
	return TERRAIN_TEXTURE_PATHS.get(terrain_type, [])


# 根据 0-99 的数值按比例返回地形类型。
static func get_terrain_type_by_roll(roll: int) -> String:
	if roll < 70:
		return "grass"
	if roll < 80:
		return "dirt"
	if roll < 90:
		return "rock"
	if roll < 95:
		return "snow"

	return "dead_ground"
