extends Node2D

# 宗门节点脚本，用来生成地图上的宗门据点。
const SectNodeScript := preload("res://scripts/world/SectNode.gd")

# 资源点节点脚本，用来生成地图上的灵矿、灵脉、灵草地和秘境入口。
const ResourceNodeScript := preload("res://scripts/world/ResourceNode.gd")

# 世界地图尺寸。
const MAP_SIZE: Vector2 = Vector2(4096, 4096)

# 简单网格间距。
const GRID_SIZE: float = 256.0

# 资源点与宗门之间的最小距离，避免图标重叠。
const RESOURCE_MIN_DISTANCE_TO_SECT: float = 250.0

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

# 第一版固定资源点数据，总计 26 个。
const RESOURCE_LIST: Array[Dictionary] = [
	{"resource_id": 1, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 1200, "owner_sect_id": -1, "position": Vector2(350, 450), "level": 1},
	{"resource_id": 2, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 1500, "owner_sect_id": -1, "position": Vector2(1050, 420), "level": 1},
	{"resource_id": 3, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 2100, "owner_sect_id": -1, "position": Vector2(2350, 620), "level": 2},
	{"resource_id": 4, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 1800, "owner_sect_id": -1, "position": Vector2(3720, 720), "level": 2},
	{"resource_id": 5, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 2600, "owner_sect_id": -1, "position": Vector2(3600, 2400), "level": 3},
	{"resource_id": 6, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 2300, "owner_sect_id": -1, "position": Vector2(2520, 3500), "level": 2},
	{"resource_id": 7, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 1600, "owner_sect_id": -1, "position": Vector2(1200, 3600), "level": 1},
	{"resource_id": 8, "resource_name": "灵矿", "resource_type": "spirit_mine", "amount": 2000, "owner_sect_id": -1, "position": Vector2(420, 2550), "level": 2},
	{"resource_id": 9, "resource_name": "灵脉", "resource_type": "spirit_vein", "amount": 900, "owner_sect_id": -1, "position": Vector2(410, 1250), "level": 1},
	{"resource_id": 10, "resource_name": "灵脉", "resource_type": "spirit_vein", "amount": 1300, "owner_sect_id": -1, "position": Vector2(1900, 520), "level": 2},
	{"resource_id": 11, "resource_name": "灵脉", "resource_type": "spirit_vein", "amount": 1700, "owner_sect_id": -1, "position": Vector2(2600, 1280), "level": 2},
	{"resource_id": 12, "resource_name": "灵脉", "resource_type": "spirit_vein", "amount": 2200, "owner_sect_id": -1, "position": Vector2(3260, 2200), "level": 3},
	{"resource_id": 13, "resource_name": "灵脉", "resource_type": "spirit_vein", "amount": 1500, "owner_sect_id": -1, "position": Vector2(1450, 2650), "level": 2},
	{"resource_id": 14, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 600, "owner_sect_id": -1, "position": Vector2(350, 650), "level": 1},
	{"resource_id": 15, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 720, "owner_sect_id": -1, "position": Vector2(980, 1350), "level": 1},
	{"resource_id": 16, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 850, "owner_sect_id": -1, "position": Vector2(1600, 1250), "level": 2},
	{"resource_id": 17, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 780, "owner_sect_id": -1, "position": Vector2(2300, 950), "level": 1},
	{"resource_id": 18, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 960, "owner_sect_id": -1, "position": Vector2(3600, 1200), "level": 2},
	{"resource_id": 19, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 1100, "owner_sect_id": -1, "position": Vector2(3260, 2850), "level": 3},
	{"resource_id": 20, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 890, "owner_sect_id": -1, "position": Vector2(2800, 3600), "level": 2},
	{"resource_id": 21, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 730, "owner_sect_id": -1, "position": Vector2(1500, 3400), "level": 1},
	{"resource_id": 22, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 690, "owner_sect_id": -1, "position": Vector2(600, 3500), "level": 1},
	{"resource_id": 23, "resource_name": "灵草地", "resource_type": "herb_field", "amount": 820, "owner_sect_id": -1, "position": Vector2(350, 2300), "level": 2},
	{"resource_id": 24, "resource_name": "秘境入口", "resource_type": "secret_realm", "amount": 1, "owner_sect_id": -1, "position": Vector2(2500, 1650), "level": 2},
	{"resource_id": 25, "resource_name": "秘境入口", "resource_type": "secret_realm", "amount": 1, "owner_sect_id": -1, "position": Vector2(3800, 3000), "level": 3},
	{"resource_id": 26, "resource_name": "秘境入口", "resource_type": "secret_realm", "amount": 1, "owner_sect_id": -1, "position": Vector2(1100, 2200), "level": 1},
]

# 世界镜头。
@onready var world_camera: Camera2D = $WorldCamera

# 右侧信息面板。
@onready var title_label: Label = $UILayer/InfoPanel/InfoBox/TitleLabel
@onready var name_label: Label = $UILayer/InfoPanel/InfoBox/NameLabel
@onready var owner_label: Label = $UILayer/InfoPanel/InfoBox/OwnerLabel
@onready var disciple_count_label: Label = $UILayer/InfoPanel/InfoBox/DiscipleCountLabel
@onready var spirit_stone_label: Label = $UILayer/InfoPanel/InfoBox/SpiritStoneLabel
@onready var power_label: Label = $UILayer/InfoPanel/InfoBox/PowerLabel
@onready var tip_label: Label = $UILayer/InfoPanel/InfoBox/TipLabel


# 地图启动时，设置镜头范围，并生成宗门和资源点。
func _ready() -> void:
	world_camera.map_size = MAP_SIZE
	world_camera.make_current()
	_validate_resource_positions()
	_create_resource_nodes()
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


# 创建地图上的资源点。
func _create_resource_nodes() -> void:
	for resource_data in RESOURCE_LIST:
		var resource_node: ResourceNode = ResourceNodeScript.new()
		resource_node.setup(resource_data)
		resource_node.selected.connect(_on_resource_selected)
		add_child(resource_node)


# 未选择宗门时，信息面板显示空状态。
func _show_empty_panel() -> void:
	title_label.text = "地图信息"
	name_label.text = "宗门名称：未选择"
	owner_label.text = "资源点：未选择"
	disciple_count_label.text = "宗门数量：" + str(SECT_LIST.size())
	spirit_stone_label.text = "资源点数量：" + str(RESOURCE_LIST.size())
	power_label.text = "地图大小：4096 x 4096"
	tip_label.text = "点击宗门或资源点查看信息。"


# 点击宗门后，右侧显示宗门信息。
func _on_sect_selected(sect_data: Dictionary) -> void:
	title_label.text = "宗门信息"
	name_label.text = "宗门名称：" + str(sect_data["name"])
	owner_label.text = "是否玩家宗门：" + ("是" if bool(sect_data["is_player"]) else "否")
	disciple_count_label.text = "弟子数量：" + str(sect_data["disciple_count"])
	spirit_stone_label.text = "灵石：" + str(sect_data["spirit_stone"])
	power_label.text = "战力：" + str(sect_data["power"])
	tip_label.text = "宗门据点，后续会围绕它展开扩张、战争与经营。"


# 点击资源点后，右侧显示资源点信息。
func _on_resource_selected(resource_data: Dictionary) -> void:
	title_label.text = "资源点信息"
	name_label.text = "名称：" + str(resource_data["resource_name"])
	owner_label.text = "类型：" + _get_resource_type_name(str(resource_data["resource_type"]))
	disciple_count_label.text = "等级：Lv" + str(resource_data["level"])
	spirit_stone_label.text = "储量：" + str(resource_data["amount"])
	power_label.text = "当前归属：" + _get_resource_owner_name(int(resource_data["owner_sect_id"]))
	tip_label.text = "说明：" + _get_resource_description(str(resource_data["resource_type"]))


# 检查资源点是否离宗门太近，方便开发阶段排查摆放问题。
func _validate_resource_positions() -> void:
	for resource_data in RESOURCE_LIST:
		var resource_position: Vector2 = resource_data["position"]
		for sect_data in SECT_LIST:
			var sect_position: Vector2 = sect_data["position"]
			if resource_position.distance_to(sect_position) < RESOURCE_MIN_DISTANCE_TO_SECT:
				push_error("资源点距离宗门过近：" + str(resource_data["resource_name"]) + " / " + str(sect_data["name"]))


# 获取资源类型中文名。
func _get_resource_type_name(resource_type: String) -> String:
	if resource_type == "spirit_mine":
		return "灵矿"
	if resource_type == "spirit_vein":
		return "灵脉"
	if resource_type == "herb_field":
		return "灵草地"
	if resource_type == "secret_realm":
		return "秘境入口"

	return "未知资源"


# 获取资源归属宗门名称。
func _get_resource_owner_name(owner_sect_id: int) -> String:
	if owner_sect_id <= 0:
		return "无主资源点"

	for sect_data in SECT_LIST:
		if int(sect_data.get("sect_id", -1)) == owner_sect_id:
			return str(sect_data["name"])

	return "未知宗门"


# 获取资源点说明文字。
func _get_resource_description(resource_type: String) -> String:
	if resource_type == "spirit_mine":
		return "产出灵石的矿脉，未来会成为宗门争夺目标。"
	if resource_type == "spirit_vein":
		return "灵气汇聚之地，未来可影响修炼和宗门发展。"
	if resource_type == "herb_field":
		return "生长灵草的区域，未来可用于炼丹和供给。"
	if resource_type == "secret_realm":
		return "隐藏机缘入口，未来可扩展探索事件。"

	return "暂无说明。"
