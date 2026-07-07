extends Node2D

# 宗门节点脚本，用来生成地图上的宗门据点。
const SectNodeScript := preload("res://scripts/world/SectNode.gd")

# 世界地图尺寸。
const MAP_SIZE: Vector2 = Vector2(4096, 4096)

# 简单网格间距。
const GRID_SIZE: float = 256.0

# 第一版固定宗门数据，先不做随机世界。
const SECT_LIST: Array[Dictionary] = [
	{"name": "青云宗", "is_player": true, "position": Vector2(2048, 2048), "disciple_count": 20, "spirit_stone": 1000, "power": 5000},
	{"name": "玄天宗", "is_player": false, "position": Vector2(720, 900), "disciple_count": 16, "spirit_stone": 800, "power": 4200},
	{"name": "万剑宗", "is_player": false, "position": Vector2(1500, 780), "disciple_count": 28, "spirit_stone": 1300, "power": 6800},
	{"name": "赤阳宗", "is_player": false, "position": Vector2(3050, 900), "disciple_count": 24, "spirit_stone": 960, "power": 5900},
	{"name": "寒月宗", "is_player": false, "position": Vector2(3500, 1700), "disciple_count": 18, "spirit_stone": 740, "power": 4700},
	{"name": "天机宗", "is_player": false, "position": Vector2(2840, 2700), "disciple_count": 30, "spirit_stone": 1500, "power": 7300},
	{"name": "魔罗宗", "is_player": false, "position": Vector2(3400, 3300), "disciple_count": 36, "spirit_stone": 2100, "power": 8800},
	{"name": "灵兽宗", "is_player": false, "position": Vector2(1900, 3250), "disciple_count": 22, "spirit_stone": 900, "power": 5200},
	{"name": "丹霞宗", "is_player": false, "position": Vector2(760, 3050), "disciple_count": 14, "spirit_stone": 620, "power": 3900},
	{"name": "归墟宗", "is_player": false, "position": Vector2(520, 1900), "disciple_count": 32, "spirit_stone": 1700, "power": 7600},
]

# 世界镜头。
@onready var world_camera: Camera2D = $WorldCamera

# 右侧信息面板。
@onready var name_label: Label = $UILayer/InfoPanel/InfoBox/NameLabel
@onready var owner_label: Label = $UILayer/InfoPanel/InfoBox/OwnerLabel
@onready var disciple_count_label: Label = $UILayer/InfoPanel/InfoBox/DiscipleCountLabel
@onready var spirit_stone_label: Label = $UILayer/InfoPanel/InfoBox/SpiritStoneLabel
@onready var power_label: Label = $UILayer/InfoPanel/InfoBox/PowerLabel


# 地图启动时，设置镜头范围，并生成 10 个宗门。
func _ready() -> void:
	world_camera.map_size = MAP_SIZE
	world_camera.make_current()
	_create_sect_nodes()
	_show_empty_panel()
	queue_redraw()


# 绘制绿色地图底色、网格和边界。
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.16, 0.32, 0.18), true)

	for x in range(0, int(MAP_SIZE.x) + 1, int(GRID_SIZE)):
		draw_line(Vector2(x, 0), Vector2(x, MAP_SIZE.y), Color(0.25, 0.42, 0.25), 2.0)

	for y in range(0, int(MAP_SIZE.y) + 1, int(GRID_SIZE)):
		draw_line(Vector2(0, y), Vector2(MAP_SIZE.x, y), Color(0.25, 0.42, 0.25), 2.0)

	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.72, 0.86, 0.62), false, 6.0)


# 创建地图上的宗门据点。
func _create_sect_nodes() -> void:
	for sect_data in SECT_LIST:
		var sect_node: SectNode = SectNodeScript.new()
		sect_node.setup(sect_data)
		sect_node.selected.connect(_on_sect_selected)
		add_child(sect_node)


# 未选择宗门时，信息面板显示空状态。
func _show_empty_panel() -> void:
	name_label.text = "宗门名称：未选择"
	owner_label.text = "是否玩家宗门：-"
	disciple_count_label.text = "弟子数量：-"
	spirit_stone_label.text = "灵石：-"
	power_label.text = "战力：-"


# 点击宗门后，右侧显示宗门信息。
func _on_sect_selected(sect_data: Dictionary) -> void:
	name_label.text = "宗门名称：" + str(sect_data["name"])
	owner_label.text = "是否玩家宗门：" + ("是" if bool(sect_data["is_player"]) else "否")
	disciple_count_label.text = "弟子数量：" + str(sect_data["disciple_count"])
	spirit_stone_label.text = "灵石：" + str(sect_data["spirit_stone"])
	power_label.text = "战力：" + str(sect_data["power"])
