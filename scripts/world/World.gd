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


# 地图启动时，初始化世界数据，并生成宗门和资源点。
func _ready() -> void:
	world_camera.map_size = MAP_SIZE
	world_camera.make_current()
	WorldDataManager.init_world_data()
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
	for sect_data in WorldDataManager.get_all_sects():
		var sect_node: SectNode = SectNodeScript.new()
		sect_node.setup(sect_data)
		sect_node.selected.connect(_on_sect_selected)
		add_child(sect_node)


# 创建地图上的资源点。
func _create_resource_nodes() -> void:
	for resource_data in WorldDataManager.get_all_resources():
		var resource_node: ResourceNode = ResourceNodeScript.new()
		resource_node.setup(resource_data)
		resource_node.selected.connect(_on_resource_selected)
		add_child(resource_node)


# 未选择对象时，信息面板显示地图概况。
func _show_empty_panel() -> void:
	title_label.text = "地图信息"
	name_label.text = "宗门名称：未选择"
	owner_label.text = "资源点：未选择"
	disciple_count_label.text = "宗门数量：" + str(WorldDataManager.get_all_sects().size())
	spirit_stone_label.text = "资源点数量：" + str(WorldDataManager.get_all_resources().size())
	power_label.text = "地图大小：4096 x 4096"
	tip_label.text = "点击宗门或资源点查看信息。"


# 点击宗门后，右侧显示宗门信息。
func _on_sect_selected(sect_data: Dictionary) -> void:
	title_label.text = "宗门信息"
	name_label.text = "宗门名称：" + str(sect_data["sect_name"])
	owner_label.text = "是否玩家宗门：" + ("是" if bool(sect_data["is_player"]) else "否")
	disciple_count_label.text = "弟子数量：" + str(sect_data["disciples_count"])
	spirit_stone_label.text = "灵石：" + str(sect_data["spirit_stones"])
	power_label.text = "战力：" + str(sect_data["power"])
	tip_label.text = "sect_id：" + str(sect_data["sect_id"])


# 点击资源点后，右侧显示资源点信息。
func _on_resource_selected(resource_data: Dictionary) -> void:
	title_label.text = "资源点信息"
	name_label.text = "名称：" + str(resource_data["resource_name"])
	owner_label.text = "类型：" + _get_resource_type_name(str(resource_data["resource_type"]))
	disciple_count_label.text = "等级：Lv" + str(resource_data["level"])
	spirit_stone_label.text = "储量：" + str(resource_data["amount"])
	power_label.text = "当前归属：" + _get_resource_owner_name(int(resource_data["owner_sect_id"]))
	tip_label.text = "resource_id：" + str(resource_data["resource_id"])


# 检查资源点是否离宗门太近，方便开发阶段排查摆放问题。
func _validate_resource_positions() -> void:
	for resource_data in WorldDataManager.get_all_resources():
		var resource_position: Vector2 = resource_data["position"]
		for sect_data in WorldDataManager.get_all_sects():
			var sect_position: Vector2 = sect_data["position"]
			if resource_position.distance_to(sect_position) < RESOURCE_MIN_DISTANCE_TO_SECT:
				push_error("资源点距离宗门过近：" + str(resource_data["resource_name"]) + " / " + str(sect_data["sect_name"]))


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
	if owner_sect_id == 0:
		return "无主资源点"

	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(owner_sect_id)
	if sect_data.is_empty():
		return "未知宗门"

	return str(sect_data["sect_name"])
