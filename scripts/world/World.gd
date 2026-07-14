extends Node2D

# 宗门节点脚本，用来生成地图上的宗门据点。
const SectNodeScript := preload("res://scripts/world/SectNode.gd")

# 宗门领地范围脚本，用来显示宗门控制范围。
const TerritoryAreaScript := preload("res://scripts/world/TerritoryArea.gd")

# 资源点节点脚本，用来生成地图上的灵矿、灵脉、灵草地和秘境入口。
const ResourceNodeScript := preload("res://scripts/world/ResourceNode.gd")

# 建设点脚本，用来显示青云宗的可建设空地。
const BuildSlotNodeScript := preload("res://scripts/world/BuildSlotNode.gd")

const USE_RUNTIME_WORLD_GENERATION := false
const GENERATED_WORLD_MAP_PATH := "res://scenes/world/GeneratedWorldMap.scn"
const SIMPLE_WORLD_FALLBACK_PATH := "res://scenes/world/SimpleWorldFallback.tscn"
const WORLD_READY_WARNING_MS: int = 2000
const MAP_INSTANTIATE_WARNING_MS: int = 1000

## 正式世界尺寸只从 WorldMapSpec 获取；旧地图坐标不再在显示层缩放。
const MAP_SIZE: Vector2 = Vector2(WorldMapSpec.WORLD_SIZE)
const MAP_ORIGIN: Vector2 = Vector2.ZERO

# 宗门图标统一配置，后续只需要修改这里即可调整显示大小。
const SECT_ICON_DIRECTORY: String = "res://assets/pixel/sects/processed"
const SECT_ICON_FALLBACK_DIRECTORY: String = "res://assets/pixel/sects"
const PLAYER_SECT_ICON_NAME: String = "sect_01_player_qingxuan.png"
const SECT_ICON_SIZE: int = 72

# 资源点图标统一配置，四类资源分别扫描自己的处理后目录。
const RESOURCE_ICON_DIRECTORY: String = "res://assets/pixel/resources/processed"
const RESOURCE_ICON_SIZE: float = 36.0
const SECRET_REALM_ICON_SIZE: float = 48.0
const RESOURCE_ICON_RANDOM_SEED: int = 20260709
const RESOURCE_TYPE_DIRECTORIES: Dictionary = {
	"spirit_mine": "spirit_mine",
	"herb_field": "herb_field",
	"spirit_vein": "spirit_vein",
	"secret_realm": "secret_realm",
}

# 资源点与宗门/资源点之间的最小格距，坐标阈值从同一常量推导。
const RESOURCE_MIN_CELL_DISTANCE: int = 16
const RESOURCE_MIN_DISTANCE_TO_SECT: float = float(RESOURCE_MIN_CELL_DISTANCE * WorldMapSpec.TILE_SIZE.x)

# 启动时自动扫描到的宗门图标路径，按文件名排序。
var sect_icon_paths: Array[String] = []
var active_sect_icon_directory: String = SECT_ICON_DIRECTORY

# 按资源类型保存扫描到的图片路径；缺失类型会回退到 ResourceNode 的代码绘制。
var resource_icon_paths_by_type: Dictionary = {}
var resource_icon_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var texture_cache: Dictionary = {}
var pending_texture_paths: Dictionary = {}
var texture_bindings: Array[Dictionary] = []
var visual_assets_started_at: int = 0

# 当前地图对象选中状态，由 World 统一管理。
var current_selected_type: String = "none"
var current_selected_id: Variant = null
var current_selected_node: Node = null

# 地图层，只放已经通过的修仙像素世界实例。
@onready var map_layer: Node2D = $MapLayer

# 正式地图只引用预生成结果或简化回退，不引用程序化生成器。
var pixel_world: Node2D

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
@onready var enter_sect_button: Button = $UILayer/InfoPanel/InfoBox/EnterSectButton


# 地图启动时，初始化世界数据，并生成宗门和资源点。
func _ready() -> void:
	var ready_started_at: int = Time.get_ticks_msec()
	set_process(false)
	_load_runtime_world_map()
	world_camera.map_size = MAP_SIZE
	world_camera.map_origin = MAP_ORIGIN
	world_camera.position = MAP_ORIGIN + MAP_SIZE * 0.5
	world_camera.make_current()
	WorldDataManager.init_world_data()
	if pixel_world == null or not _resolve_world_positions_on_generated_land():
		_abort_world_initialization("无法将世界对象放置到烘焙地图的安全陆地。")
		return
	var icon_scan_started_at: int = Time.get_ticks_msec()
	_load_sect_icon_paths()
	_load_resource_icon_paths()
	print("[WorldPerf] Icon path scan: %d ms" % (Time.get_ticks_msec() - icon_scan_started_at))
	_validate_resource_positions()
	var territory_recalculate_started_at: int = Time.get_ticks_msec()
	TerritoryManager.recalculate_all()
	print("[WorldPerf] Territory recalculate: %d ms" % (Time.get_ticks_msec() - territory_recalculate_started_at))
	var territory_nodes_started_at: int = Time.get_ticks_msec()
	_create_territory_areas()
	print("[WorldPerf] Territory nodes: %d ms" % (Time.get_ticks_msec() - territory_nodes_started_at))
	visual_assets_started_at = Time.get_ticks_msec()
	var resource_started_at: int = Time.get_ticks_msec()
	_create_resource_nodes()
	print("[WorldPerf] Resource nodes: %d ms" % (Time.get_ticks_msec() - resource_started_at))
	var build_slot_started_at: int = Time.get_ticks_msec()
	_create_build_slot_nodes()
	print("[WorldPerf] Build slot nodes: %d ms" % (Time.get_ticks_msec() - build_slot_started_at))
	build_slot_layer.visible = false
	var sect_started_at: int = Time.get_ticks_msec()
	_create_sect_nodes()
	print("[WorldPerf] Sect nodes: %d ms" % (Time.get_ticks_msec() - sect_started_at))
	enter_sect_button.pressed.connect(_on_enter_sect_button_pressed)
	_show_empty_panel()
	var ready_elapsed: int = Time.get_ticks_msec() - ready_started_at
	print("[WorldPerf] World ready total: %d ms" % ready_elapsed)
	if ready_elapsed > WORLD_READY_WARNING_MS:
		push_warning("[WorldPerf][WARNING] 世界地图加载超过2秒")


func _abort_world_initialization(message: String) -> void:
	push_error("[World] 初始化已中止：" + message)
	set_process(false)
	set_process_unhandled_input(false)
	pending_texture_paths.clear()
	texture_bindings.clear()
	for layer in [territory_layer, resource_layer, build_slot_layer, sect_layer, map_layer]:
		if layer == null:
			continue
		for child in layer.get_children():
			child.queue_free()
	pixel_world = null
	build_slot_layer.visible = false
	_set_enter_sect_button_visible(false)
	tip_label.text = "世界地图初始化失败，请检查烘焙地图与日志。"


func _process(_delta: float) -> void:
	for path_value in pending_texture_paths.keys():
		var path: String = str(path_value)
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		pending_texture_paths.erase(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_warning("地图图标后台加载失败，继续使用 fallback：" + path)
			_remove_texture_bindings(path)
			continue
		var texture := ResourceLoader.load_threaded_get(path) as Texture2D
		if texture == null:
			push_warning("地图图标资源不是 Texture2D：" + path)
			_remove_texture_bindings(path)
			continue
		texture_cache[path] = texture
		_apply_texture_bindings(path, texture)
	if pending_texture_paths.is_empty():
		set_process(false)
		print("[WorldPerf] Visual assets ready: %d ms" % (Time.get_ticks_msec() - visual_assets_started_at))


func _load_runtime_world_map() -> void:
	if USE_RUNTIME_WORLD_GENERATION:
		push_error("正式运行禁止启用完整程序化地图生成。")
	var map_path: String = GENERATED_WORLD_MAP_PATH
	if not ResourceLoader.exists(map_path):
		push_error("预生成地图缺失，当前使用简化地图。")
		map_path = SIMPLE_WORLD_FALLBACK_PATH
	var load_started_at: int = Time.get_ticks_msec()
	var map_scene := load(map_path) as PackedScene
	print("[WorldPerf] Map resource load: %d ms" % (Time.get_ticks_msec() - load_started_at))
	if map_scene == null and map_path != SIMPLE_WORLD_FALLBACK_PATH:
		push_error("预生成地图加载失败，当前使用简化地图。")
		map_scene = load(SIMPLE_WORLD_FALLBACK_PATH) as PackedScene
	if map_scene == null:
		push_error("简化地图也无法加载。")
		return
	var instantiate_started_at: int = Time.get_ticks_msec()
	pixel_world = map_scene.instantiate() as Node2D
	if (
		map_path == GENERATED_WORLD_MAP_PATH
		and pixel_world != null
		and pixel_world.has_method("is_baked_map_valid")
		and not bool(pixel_world.call("is_baked_map_valid"))
	):
		push_error("预生成地图内容无效，当前使用简化地图。")
		pixel_world.free()
		map_scene = load(SIMPLE_WORLD_FALLBACK_PATH) as PackedScene
		pixel_world = map_scene.instantiate() as Node2D if map_scene != null else null
	var instantiate_elapsed: int = Time.get_ticks_msec() - instantiate_started_at
	print("[WorldPerf] Map instantiate: %d ms" % instantiate_elapsed)
	if instantiate_elapsed > MAP_INSTANTIATE_WARNING_MS:
		push_warning("[WorldPerf][WARNING] 烘焙地图实例化过慢")
	if pixel_world == null:
		push_error("世界地图实例化失败。")
		return
	var add_child_started_at: int = Time.get_ticks_msec()
	map_layer.add_child(pixel_world)
	print("[WorldPerf] Map add child: %d ms" % (Time.get_ticks_msec() - add_child_started_at))
	print("[WorldPerf] Generated map load: %d ms" % (Time.get_ticks_msec() - load_started_at))


# ESC 取消当前选择、隐藏建设点并恢复地图概况。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_clear_current_selection()
		build_slot_layer.visible = false
		_set_enter_sect_button_visible(false)
		_show_empty_panel()
		get_viewport().set_input_as_handled()


# 创建地图上的宗门据点。
func _create_sect_nodes() -> void:
	var all_sects: Array = WorldDataManager.get_all_sects()
	for sect_index in range(all_sects.size()):
		var sect_data: Dictionary = all_sects[sect_index]
		var display_data: Dictionary = sect_data.duplicate(true)
		display_data["position"] = sect_data["location"]
		var sect_node: SectNode = SectNodeScript.new()
		var icon_path: String = _get_sect_icon_path(
			sect_index,
			bool(display_data.get("is_player", false))
		)
		sect_node.setup(display_data, null, SECT_ICON_SIZE)
		sect_node.selected.connect(_on_sect_selected.bind(sect_node))
		sect_layer.add_child(sect_node)
		_queue_texture_binding(icon_path, sect_node, "sect", float(SECT_ICON_SIZE))


# 优先扫描处理后的小图；目录为空时回退到原图目录。
func _load_sect_icon_paths() -> void:
	sect_icon_paths = _scan_sect_icon_directory(SECT_ICON_DIRECTORY)
	active_sect_icon_directory = SECT_ICON_DIRECTORY
	if sect_icon_paths.is_empty():
		sect_icon_paths = _scan_sect_icon_directory(SECT_ICON_FALLBACK_DIRECTORY)
		active_sect_icon_directory = SECT_ICON_FALLBACK_DIRECTORY

	if sect_icon_paths.is_empty():
		push_warning("宗门图标目录中没有 PNG。")


# 扫描指定目录中的 PNG，并按文件名排序。
func _scan_sect_icon_directory(directory_path: String) -> Array[String]:
	var icon_paths: Array[String] = []
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return icon_paths

	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "png":
			icon_paths.append(directory_path.path_join(file_name))

	icon_paths.sort()
	return icon_paths


# 玩家优先使用青玄图标，AI 使用其余图标并在数量不足时循环。
func _get_sect_icon_path(sect_index: int, is_player: bool) -> String:
	if sect_icon_paths.is_empty():
		return ""

	var player_icon_path: String = sect_icon_paths[0]
	var preferred_player_path: String = active_sect_icon_directory.path_join(PLAYER_SECT_ICON_NAME)
	if preferred_player_path in sect_icon_paths:
		player_icon_path = preferred_player_path

	var selected_path: String = player_icon_path
	if not is_player:
		var ai_icon_paths: Array[String] = []
		for icon_path in sect_icon_paths:
			if icon_path != player_icon_path:
				ai_icon_paths.append(icon_path)
		if not ai_icon_paths.is_empty():
			selected_path = ai_icon_paths[(sect_index - 1) % ai_icon_paths.size()]

	return selected_path


# 启动时扫描四类资源点图片；目录缺失或为空时只发出 warning。
func _load_resource_icon_paths() -> void:
	resource_icon_paths_by_type.clear()
	resource_icon_rng.seed = RESOURCE_ICON_RANDOM_SEED

	for resource_type in RESOURCE_TYPE_DIRECTORIES:
		var category_directory: String = str(RESOURCE_TYPE_DIRECTORIES[resource_type])
		var directory_path: String = RESOURCE_ICON_DIRECTORY.path_join(category_directory)
		var icon_paths: Array[String] = _scan_resource_icon_directory(directory_path)
		resource_icon_paths_by_type[str(resource_type)] = icon_paths
		if icon_paths.is_empty():
			push_warning(
				"资源点图片缺失，将使用代码绘制 fallback："
				+ str(resource_type)
				+ " / "
				+ directory_path
			)


# 扫描指定资源类型目录中的 PNG，并按英文文件名排序。
func _scan_resource_icon_directory(directory_path: String) -> Array[String]:
	var icon_paths: Array[String] = []
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return icon_paths

	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "png":
			icon_paths.append(directory_path.path_join(file_name))

	icon_paths.sort()
	return icon_paths


# 从对应资源类型中随机选一张路径；后台加载失败时节点继续使用代码绘制 fallback。
func _get_resource_icon_path(resource_type: String) -> String:
	var icon_paths: Array = resource_icon_paths_by_type.get(resource_type, [])
	if icon_paths.is_empty():
		return ""

	var selected_index: int = resource_icon_rng.randi_range(0, icon_paths.size() - 1)
	return str(icon_paths[selected_index])


func _queue_texture_binding(path: String, target: Node, binding_type: String, display_size: float) -> void:
	if path == "" or not is_instance_valid(target):
		return
	if texture_cache.has(path):
		_apply_texture_to_target(target, binding_type, texture_cache[path] as Texture2D, display_size)
		return
	texture_bindings.append({"path": path, "target": target, "type": binding_type, "display_size": display_size})
	if pending_texture_paths.has(path):
		return
	var error: Error = ResourceLoader.load_threaded_request(path, "Texture2D", true)
	if error != OK:
		push_warning("无法请求后台加载地图图标：%s（%s）" % [path, error_string(error)])
		_remove_texture_bindings(path)
		return
	pending_texture_paths[path] = true
	set_process(true)


func _apply_texture_bindings(path: String, texture: Texture2D) -> void:
	for index in range(texture_bindings.size() - 1, -1, -1):
		var binding: Dictionary = texture_bindings[index]
		if str(binding.get("path", "")) != path:
			continue
		var target: Node = binding.get("target") as Node
		if is_instance_valid(target):
			_apply_texture_to_target(target, str(binding.get("type", "")), texture, float(binding.get("display_size", 36.0)))
		texture_bindings.remove_at(index)


func _remove_texture_bindings(path: String) -> void:
	for index in range(texture_bindings.size() - 1, -1, -1):
		if str(texture_bindings[index].get("path", "")) == path:
			texture_bindings.remove_at(index)


func _apply_texture_to_target(target: Node, binding_type: String, texture: Texture2D, display_size: float) -> void:
	if binding_type == "sect" and target.has_method("set_icon_texture"):
		target.call("set_icon_texture", texture, int(display_size))
	elif binding_type == "resource" and target.has_method("set_resource_texture"):
		target.call("set_resource_texture", texture, display_size)


# 秘境入口尺寸更大，其余三类资源点使用统一尺寸。
func _get_resource_icon_size(resource_type: String) -> float:
	if resource_type == "secret_realm":
		return SECRET_REALM_ICON_SIZE
	return RESOURCE_ICON_SIZE


# 创建宗门领地范围，先生成它们，保证显示在图标和文字下方。
func _create_territory_areas() -> void:
	for sect_data in WorldDataManager.get_all_sects():
		var territory_area: TerritoryArea = TerritoryAreaScript.new()
		territory_area.setup(sect_data, TerritoryManager.get_territory(str(sect_data.get("sect_id", ""))))
		territory_layer.add_child(territory_area)


# 创建地图上的资源点。
func _create_resource_nodes() -> void:
	for resource_data in WorldDataManager.get_all_resources():
		var display_data: Dictionary = resource_data.duplicate(true)
		display_data["position"] = resource_data["position"]
		var resource_node: ResourceNode = ResourceNodeScript.new()
		var resource_type: String = str(display_data["resource_type"])
		var icon_path: String = _get_resource_icon_path(resource_type)
		var icon_size: float = _get_resource_icon_size(resource_type)
		resource_node.setup(
			display_data,
			null,
			icon_size
		)
		resource_node.selected.connect(_on_resource_selected.bind(resource_node))
		resource_layer.add_child(resource_node)
		_queue_texture_binding(icon_path, resource_node, "resource", icon_size)


# 创建玩家宗门建设点。
func _create_build_slot_nodes() -> void:
	for slot_data in WorldDataManager.get_build_slots_by_sect_id("sect_001"):
		var display_data: Dictionary = slot_data.duplicate(true)
		display_data["position"] = slot_data["position"]
		var build_slot_node: BuildSlotNode = BuildSlotNodeScript.new()
		build_slot_node.setup(display_data)
		build_slot_node.selected.connect(_on_build_slot_selected.bind(build_slot_node))
		build_slot_layer.add_child(build_slot_node)


## 将归一化锚点落到正式烘焙地图的安全陆地。结果写回世界数据，
## 保证领地、点击节点、存档与地图显示使用同一套世界坐标。
func _resolve_world_positions_on_generated_land() -> bool:
	if pixel_world == null or not pixel_world.has_method("find_nearest_available_land_world_position"):
		push_error("Generated world map cannot resolve safe land positions.")
		return false
	var occupied_cells: Dictionary = {}
	var sect_resolve_started_at: int = Time.get_ticks_msec()
	var sects: Array = WorldDataManager.get_all_sects().duplicate()
	sects.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("sect_id", "")) < str(right.get("sect_id", "")))
	for sect_data in sects:
		var sect_id: String = str(sect_data.get("sect_id", ""))
		var resolved: Vector2 = pixel_world.call(
			"find_nearest_available_land_world_position",
			WorldMapSpec.clamp_world_position(sect_data.get("location", WorldMapSpec.world_center())),
			occupied_cells,
			0
		)
		if not WorldMapSpec.is_world_position_in_bounds(resolved):
			push_error("Could not place sect on safe compact world land: " + sect_id)
			return false
		WorldDataManager.update_sect_data(sect_id, "location", resolved)
		occupied_cells[pixel_world.call("world_position_to_cell", resolved)] = true
	print("[WorldPerf] Sect land resolve: %d ms" % (Time.get_ticks_msec() - sect_resolve_started_at))
	var resource_resolve_started_at: int = Time.get_ticks_msec()
	var resources: Array = WorldDataManager.get_all_resources().duplicate()
	resources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("resource_id", 0)) < int(right.get("resource_id", 0)))
	for resource_data in resources:
		var resource_id: int = int(resource_data.get("resource_id", -1))
		var resolved: Vector2 = pixel_world.call(
			"find_nearest_available_land_world_position",
			WorldMapSpec.clamp_world_position(resource_data.get("position", WorldMapSpec.world_center())), occupied_cells, RESOURCE_MIN_CELL_DISTANCE
		)
		if not WorldMapSpec.is_world_position_in_bounds(resolved):
			push_error("Could not place resource on safe compact world land: %d" % resource_id)
			return false
		WorldDataManager.update_resource_position(resource_id, resolved)
		occupied_cells[pixel_world.call("world_position_to_cell", resolved)] = true
	print("[WorldPerf] Resource land resolve: %d ms" % (Time.get_ticks_msec() - resource_resolve_started_at))
	var build_slot_reposition_started_at: int = Time.get_ticks_msec()
	var player_position: Vector2 = WorldDataManager.get_player_sect().get("location", WorldMapSpec.world_center())
	WorldDataManager.reposition_player_build_slots(player_position)
	print("[WorldPerf] Build slot reposition: %d ms" % (Time.get_ticks_msec() - build_slot_reposition_started_at))
	return true


# 未选择对象时，信息面板显示地图概况。
func _show_empty_panel() -> void:
	_set_enter_sect_button_visible(false)
	title_label.text = "地图信息"
	name_label.text = "宗门名称：未选择"
	owner_label.text = "资源点：未选择"
	disciple_count_label.text = "宗门数量：" + str(WorldDataManager.get_all_sects().size())
	spirit_stone_label.text = "资源点数量：" + str(WorldDataManager.get_all_resources().size())
	power_label.text = "建设点数量：" + str(WorldDataManager.get_all_build_slots().size())
	tip_label.text = "点击宗门或资源点查看信息。"


# 取消旧对象的视觉选中状态，并重置当前选择记录。
func _clear_current_selection() -> void:
	if is_instance_valid(current_selected_node) and current_selected_node.has_method("set_selected"):
		current_selected_node.call("set_selected", false)
	current_selected_type = "none"
	current_selected_id = null
	current_selected_node = null


# 切换到新对象；支持 set_selected 的节点会自动收到视觉状态更新。
func _set_current_selection(
	selection_type: String,
	selection_id: Variant,
	selection_node: Node
) -> void:
	_clear_current_selection()
	current_selected_type = selection_type
	current_selected_id = selection_id
	current_selected_node = selection_node
	if is_instance_valid(current_selected_node) and current_selected_node.has_method("set_selected"):
		current_selected_node.call("set_selected", true)


# 点击宗门后，右侧显示宗门信息。
func _set_enter_sect_button_visible(value: bool) -> void:
	enter_sect_button.visible = value


func _on_enter_sect_button_pressed() -> void:
	if current_selected_type != "sect":
		_set_enter_sect_button_visible(false)
		return

	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(str(current_selected_id))
	if sect_data.is_empty() or not bool(sect_data.get("is_player", false)):
		_set_enter_sect_button_visible(false)
		return

	SceneManager.go_to_player_sect_overview()


func _on_sect_selected(node_data: Dictionary, sect_node: SectNode) -> void:
	var selected_sect_id: String = str(node_data["sect_id"])
	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(selected_sect_id)
	var sect_resource_data: Dictionary = WorldDataManager.get_sect_resources(selected_sect_id)
	if sect_data.is_empty():
		push_warning("未找到宗门完整数据，临时使用节点数据：" + selected_sect_id)
		sect_data = node_data
	_set_current_selection("sect", selected_sect_id, sect_node)
	var is_player_sect: bool = bool(sect_data.get("is_player", false))
	build_slot_layer.visible = is_player_sect
	_set_enter_sect_button_visible(is_player_sect)

	title_label.text = "宗门信息"
	name_label.text = "宗门名称：" + str(sect_data["sect_name"])
	owner_label.text = (
		"宗门类型：" + _get_sect_type_name(str(sect_data["sect_type"]))
		+ "\n是否玩家宗门：" + ("是" if bool(sect_data["is_player"]) else "否")
	)
	disciple_count_label.text = (
		"宗主：" + str(sect_data["master_name"])
		+ "\n宗门品阶：" + str(sect_data["realm_rank"])
	)
	spirit_stone_label.text = (
		"弟子数量：" + str(sect_data["disciple_count"])
		+ "\n灵石：" + str(sect_resource_data.get("spirit_stone", "-"))
	)
	power_label.text = (
		"声望：" + str(sect_data["reputation"])
		+ "\n战力：" + str(sect_data["combat_power"])
	)
	tip_label.text = (
		"关系：" + str(sect_data["relation_to_player"])
		+ "\n影响力：" + str(TerritoryManager.get_territory(str(sect_data["sect_id"])).get("influence", 0))
		+ "\n介绍：" + str(sect_data["description"])
	)


# 点击资源点后，右侧显示资源点信息。
func _on_resource_selected(resource_data: Dictionary, resource_node: ResourceNode) -> void:
	_set_current_selection("resource", int(resource_data["resource_id"]), resource_node)
	build_slot_layer.visible = false
	_set_enter_sect_button_visible(false)

	title_label.text = "资源点信息"
	name_label.text = "名称：" + str(resource_data["resource_name"])
	owner_label.text = "类型：" + _get_resource_type_name(str(resource_data["resource_type"]))
	disciple_count_label.text = "等级：Lv" + str(resource_data["level"])
	spirit_stone_label.text = "储量：" + str(resource_data["amount"])
	power_label.text = "当前归属：" + _get_resource_owner_name(resource_data["owner_sect_id"])
	tip_label.text = "resource_id：" + str(resource_data["resource_id"])


# 点击建设点后，右侧显示建设点信息。
func _on_build_slot_selected(slot_data: Dictionary, build_slot_node: BuildSlotNode) -> void:
	_set_current_selection("build_slot", int(slot_data["slot_id"]), build_slot_node)
	build_slot_layer.visible = true
	_set_enter_sect_button_visible(false)

	title_label.text = "建设点信息"
	name_label.text = "建设点ID：" + str(slot_data["slot_id"])
	owner_label.text = "所属宗门：" + _get_sect_name_by_id(str(slot_data["owner_sect_id"]))
	disciple_count_label.text = "状态：" + ("空地" if bool(slot_data["is_empty"]) else "已占用")
	spirit_stone_label.text = "类型：可建设区域"
	power_label.text = "说明：这里以后可以建造宗门建筑"
	tip_label.text = "当前只显示空地，不开放建造。"


# 检查资源点是否离宗门太近，方便开发阶段排查摆放问题。
func _validate_resource_positions() -> void:
	for resource_data in WorldDataManager.get_all_resources():
		var resource_position: Vector2 = resource_data["position"]
		for sect_data in WorldDataManager.get_all_sects():
			var sect_position: Vector2 = sect_data["location"]
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


# 获取宗门类型中文名。
func _get_sect_type_name(sect_type: String) -> String:
	var type_names: Dictionary = {
		"orthodox": "正道",
		"sword": "剑修",
		"alchemy": "丹修",
		"demonic": "魔宗",
		"buddhist": "佛修",
		"snow": "冰雪宗门",
		"desert": "荒漠宗门",
		"ocean": "海岛宗门",
	}
	return str(type_names.get(sect_type, "未知"))


# 获取资源归属宗门名称。
func _get_resource_owner_name(owner_sect_id: Variant) -> String:
	var normalized_id: String = str(owner_sect_id)
	if normalized_id == "" or normalized_id == "0":
		return "无主资源点"

	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(normalized_id)
	if sect_data.is_empty():
		return "未知宗门"

	return str(sect_data["sect_name"])


# 根据宗门编号获取宗门名称。
func _get_sect_name_by_id(sect_id: String) -> String:
	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	if sect_data.is_empty():
		return "未知宗门"

	return str(sect_data["sect_name"])
