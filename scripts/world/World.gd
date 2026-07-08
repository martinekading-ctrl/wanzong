extends Node2D

# 宗门节点脚本，用来生成地图上的宗门据点。
const SectNodeScript := preload("res://scripts/world/SectNode.gd")

# 宗门领地范围脚本，用来显示宗门控制范围。
const TerritoryAreaScript := preload("res://scripts/world/TerritoryArea.gd")

# 资源点节点脚本，用来生成地图上的灵矿、灵脉、灵草地和秘境入口。
const ResourceNodeScript := preload("res://scripts/world/ResourceNode.gd")

# 建设点脚本，用来显示青云宗的可建设空地。
const BuildSlotNodeScript := preload("res://scripts/world/BuildSlotNode.gd")

# 世界地图生成器，用来生成 100 x 100 的连续地形数据。
const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")

# 森林生成器，用来在草地和河流附近生成自然树群。
const ForestGeneratorScript := preload("res://scripts/world/ForestGenerator.gd")

# 世界地图尺寸。
const MAP_SIZE: Vector2 = Vector2(4096, 4096)

# 地图底色，用来兜住地形素材边缘，避免露出灰色背景。
const MAP_BACKGROUND_COLOR: Color = Color(0.24, 0.38, 0.20)

# 资源点与宗门之间的最小距离，避免图标重叠。
const RESOURCE_MIN_DISTANCE_TO_SECT: float = 250.0

# 当前世界生成数据，森林会复用这里的地形和河流信息。
var world_data: Dictionary = {}

# 地图层，只放合成后的世界底图。
@onready var map_layer: Node2D = $MapLayer

# 领地层，只放宗门领地范围。
@onready var territory_layer: Node2D = $TerritoryLayer

# 资源层，只放灵矿、灵脉、灵草地、秘境入口。
@onready var resource_layer: Node2D = $ResourceLayer

# 建设点层，只放可建设空地。
@onready var build_slot_layer: Node2D = $BuildSlotLayer

# 宗门层，只放宗门节点。
@onready var sect_layer: Node2D = $SectLayer

# 自然层，只放森林、树木等自然覆盖物。
@onready var nature_layer: Node2D = $NatureLayer

# 角色层，以后放弟子、妖兽、NPC。
@onready var character_layer: Node2D = $CharacterLayer

# 建筑层，以后放宗门建筑。
@onready var building_layer: Node2D = $BuildingLayer

# 特效层，以后放攻击特效、天气、动画、伤害数字。
@onready var effect_layer: Node2D = $EffectLayer

# UI 层，只放信息面板、以后的小地图、时间、按钮。
@onready var ui_layer: CanvasLayer = $UILayer

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
	queue_redraw()
	_create_map_tiles()
	_validate_resource_positions()
	_create_territory_areas()
	_create_resource_nodes()
	_create_build_slot_nodes()
	_create_sect_nodes()
	_create_forest_nodes()
	_show_empty_panel()


# 绘制地图底色，底图加载失败时也不会露出灰色背景。
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), MAP_BACKGROUND_COLOR, true)


# 使用 WorldGenerator 生成连续世界底图。
func _create_map_tiles() -> void:
	for child in map_layer.get_children():
		child.queue_free()

	var world_generator: WorldGenerator = WorldGeneratorScript.new()
	world_data = world_generator.generate_world()
	var map_texture: Texture2D = world_generator.create_world_texture(world_data)
	if map_texture == null:
		push_error("世界地图生成失败。")
		return

	var map_sprite: Sprite2D = Sprite2D.new()
	map_sprite.texture = map_texture
	map_sprite.centered = false
	map_sprite.position = Vector2.ZERO
	map_sprite.scale = Vector2(MAP_SIZE.x / map_texture.get_width(), MAP_SIZE.y / map_texture.get_height())
	map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	map_layer.add_child(map_sprite)


# 创建地图上的森林树点。森林是覆盖在地形上的自然对象，不是地形类型。
func _create_forest_nodes() -> void:
	for child in nature_layer.get_children():
		child.queue_free()

	if world_data.is_empty():
		return

	var forest_generator: ForestGenerator = ForestGeneratorScript.new()
	var forest_result: Dictionary = forest_generator.generate_forests(
		world_data,
		WorldDataManager.get_all_sects(),
		WorldDataManager.get_all_build_slots(),
		WorldDataManager.get_all_resources()
	)
	var tree_texture: Texture2D = _create_tree_texture()
	var tree_list: Array = forest_result.get("trees", []) as Array

	for tree_data in tree_list:
		var tree_sprite: Sprite2D = Sprite2D.new()
		tree_sprite.texture = tree_texture
		tree_sprite.position = tree_data["position"]
		tree_sprite.scale = _get_tree_scale(int(tree_data["tree_id"]))
		tree_sprite.modulate = _get_tree_color(int(tree_data["tree_id"]))
		tree_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		nature_layer.add_child(tree_sprite)


# 创建地图上的宗门据点。
func _create_sect_nodes() -> void:
	for sect_data in WorldDataManager.get_all_sects():
		var sect_node: SectNode = SectNodeScript.new()
		sect_node.setup(sect_data)
		sect_node.selected.connect(_on_sect_selected)
		sect_layer.add_child(sect_node)


# 创建宗门领地范围，先生成它们，保证显示在图标和文字下方。
func _create_territory_areas() -> void:
	for sect_data in WorldDataManager.get_all_sects():
		var territory_area: TerritoryArea = TerritoryAreaScript.new()
		territory_area.setup(sect_data)
		territory_layer.add_child(territory_area)


# 创建地图上的资源点。
func _create_resource_nodes() -> void:
	for resource_data in WorldDataManager.get_all_resources():
		var resource_node: ResourceNode = ResourceNodeScript.new()
		resource_node.setup(resource_data)
		resource_node.selected.connect(_on_resource_selected)
		resource_layer.add_child(resource_node)


# 创建玩家宗门建设点。
func _create_build_slot_nodes() -> void:
	for slot_data in WorldDataManager.get_build_slots_by_sect_id(1):
		var build_slot_node: BuildSlotNode = BuildSlotNodeScript.new()
		build_slot_node.setup(slot_data)
		build_slot_node.selected.connect(_on_build_slot_selected)
		build_slot_layer.add_child(build_slot_node)


# 创建树木占位贴图。当前不用正式美术，只用绿色圆点表示树冠。
func _create_tree_texture() -> Texture2D:
	var texture_size: int = 24
	var radius: float = 10.0
	var center: Vector2 = Vector2(float(texture_size - 1) * 0.5, float(texture_size - 1) * 0.5)
	var image: Image = Image.create_empty(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(texture_size):
		for x in range(texture_size):
			var distance: float = Vector2(float(x), float(y)).distance_to(center)
			if distance > radius:
				continue

			var color: Color = Color(0.04, 0.26, 0.08, 0.95)
			if distance < radius * 0.62:
				color = Color(0.09, 0.42, 0.13, 0.98)
			image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


# 每棵树略微不同大小，避免森林看起来太整齐。
func _get_tree_scale(tree_id: int) -> Vector2:
	var scale_value: float = 0.75 + float(tree_id % 6) * 0.07
	return Vector2.ONE * scale_value


# 每棵树略微不同颜色，避免森林像复制粘贴。
func _get_tree_color(tree_id: int) -> Color:
	var color_offset: float = float((tree_id * 37) % 100) / 100.0 * 0.12
	return Color(0.82 + color_offset, 0.95, 0.82 + color_offset, 1.0)


# 未选择对象时，信息面板显示地图概况。
func _show_empty_panel() -> void:
	title_label.text = "地图信息"
	name_label.text = "宗门名称：未选择"
	owner_label.text = "资源点：未选择"
	disciple_count_label.text = "宗门数量：" + str(WorldDataManager.get_all_sects().size())
	spirit_stone_label.text = "资源点数量：" + str(WorldDataManager.get_all_resources().size())
	power_label.text = "建设点数量：" + str(WorldDataManager.get_all_build_slots().size())
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


# 点击建设点后，右侧显示建设点信息。
func _on_build_slot_selected(slot_data: Dictionary) -> void:
	title_label.text = "建设点信息"
	name_label.text = "建设点ID：" + str(slot_data["slot_id"])
	owner_label.text = "所属宗门：" + _get_sect_name_by_id(int(slot_data["owner_sect_id"]))
	disciple_count_label.text = "状态：" + ("空地" if bool(slot_data["is_empty"]) else "已占用")
	spirit_stone_label.text = "类型：可建设区域"
	power_label.text = "说明：这里以后可以建造宗门建筑"
	tip_label.text = "当前只显示空地，不开放建造。"


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


# 根据宗门编号获取宗门名称。
func _get_sect_name_by_id(sect_id: int) -> String:
	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	if sect_data.is_empty():
		return "未知宗门"

	return str(sect_data["sect_name"])
