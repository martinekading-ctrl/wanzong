extends Node2D

# 单个宗门节点脚本资源。
const SectNodeScript := preload("res://scripts/world/SectNode.gd")

# 世界地图尺寸。
const MAP_SIZE: Vector2 = Vector2(4000, 4000)

# 网格间距。
const GRID_SIZE: float = 200.0

# 宗门测试数据，先固定摆放，方便验收。
const SECT_LIST: Array[Dictionary] = [
	{"name": "青云宗", "is_player": true, "position": Vector2(2000, 2000), "power": 5000, "spirit_stone": 1000, "disciple_count": 20},
	{"name": "玄天宗", "is_player": false, "position": Vector2(700, 950), "power": 4200, "spirit_stone": 820, "disciple_count": 16},
	{"name": "万剑宗", "is_player": false, "position": Vector2(1500, 900), "power": 6800, "spirit_stone": 1300, "disciple_count": 28},
	{"name": "赤阳宗", "is_player": false, "position": Vector2(3100, 1000), "power": 5900, "spirit_stone": 960, "disciple_count": 24},
	{"name": "寒月宗", "is_player": false, "position": Vector2(3400, 1600), "power": 4700, "spirit_stone": 740, "disciple_count": 18},
	{"name": "天机宗", "is_player": false, "position": Vector2(2700, 2600), "power": 7300, "spirit_stone": 1500, "disciple_count": 30},
	{"name": "魔罗宗", "is_player": false, "position": Vector2(3400, 3050), "power": 8800, "spirit_stone": 2100, "disciple_count": 36},
	{"name": "灵兽宗", "is_player": false, "position": Vector2(1900, 3100), "power": 5200, "spirit_stone": 900, "disciple_count": 22},
	{"name": "丹霞宗", "is_player": false, "position": Vector2(800, 2950), "power": 3900, "spirit_stone": 620, "disciple_count": 14},
	{"name": "归墟宗", "is_player": false, "position": Vector2(500, 1800), "power": 7600, "spirit_stone": 1700, "disciple_count": 32},
]

# 地图镜头。
@onready var world_camera: Camera2D = $WorldCamera

# 右侧信息面板文本。
@onready var name_label: Label = $UILayer/InfoPanel/InfoBox/NameLabel
@onready var owner_label: Label = $UILayer/InfoPanel/InfoBox/OwnerLabel
@onready var power_label: Label = $UILayer/InfoPanel/InfoBox/PowerLabel
@onready var spirit_stone_label: Label = $UILayer/InfoPanel/InfoBox/SpiritStoneLabel
@onready var disciple_count_label: Label = $UILayer/InfoPanel/InfoBox/DiscipleCountLabel


# 地图启动时，配置镜头并生成宗门据点。
func _ready() -> void:
	world_camera.map_size = MAP_SIZE
	_generate_sects()
	_show_empty_info()
	queue_redraw()


# 绘制简单地图背景和网格。
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.18, 0.27, 0.20), true)

	for x in range(0, int(MAP_SIZE.x) + 1, int(GRID_SIZE)):
		draw_line(Vector2(x, 0), Vector2(x, MAP_SIZE.y), Color(0.25, 0.35, 0.27), 2.0)

	for y in range(0, int(MAP_SIZE.y) + 1, int(GRID_SIZE)):
		draw_line(Vector2(0, y), Vector2(MAP_SIZE.x, y), Color(0.25, 0.35, 0.27), 2.0)

	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.70, 0.78, 0.60), false, 6.0)


# 根据测试数据生成地图上的宗门节点。
func _generate_sects() -> void:
	for sect_data in SECT_LIST:
		var sect_node: SectNode = SectNodeScript.new()
		sect_node.setup(sect_data)
		sect_node.selected.connect(_on_sect_selected)
		add_child(sect_node)


# 没有选择宗门时，右侧面板显示提示。
func _show_empty_info() -> void:
	name_label.text = "宗门名称：未选择"
	owner_label.text = "是否玩家宗门：-"
	power_label.text = "战力：-"
	spirit_stone_label.text = "灵石：-"
	disciple_count_label.text = "弟子数量：-"


# 点击宗门后，刷新右侧信息面板。
func _on_sect_selected(sect_data: Dictionary) -> void:
	name_label.text = "宗门名称：" + str(sect_data["name"])
	owner_label.text = "是否玩家宗门：" + ("是" if sect_data["is_player"] else "否")
	power_label.text = "战力：" + str(sect_data["power"])
	spirit_stone_label.text = "灵石：" + str(sect_data["spirit_stone"])
	disciple_count_label.text = "弟子数量：" + str(sect_data["disciple_count"])
