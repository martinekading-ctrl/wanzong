extends Node

# 主菜单场景路径。
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

# 世界地图场景路径。
const WORLD_SCENE: String = "res://scenes/world/World.tscn"

const PLAYER_SECT_OVERVIEW_SCENE: String = "res://scenes/sect/PlayerSectOverview.tscn"
const BATTLE_REPORT_SCENE: String = "res://scenes/battle/BattleReport.tscn"

# 游戏常驻根节点 Main。
var main_root: Node = null

# 当前页面容器，所有页面都会作为它的子节点显示。
var current_page: Node = null


# 由 Main.tscn 启动时调用，登记根节点和页面容器。
func setup_main(root_node: Node, current_page_node: Node) -> void:
	main_root = root_node
	current_page = current_page_node


# 切换到主菜单。
func go_to_main_menu() -> void:
	_change_page(MAIN_MENU_SCENE)


# 切换到俯视大地图。
func go_to_world_map() -> void:
	_change_page(WORLD_SCENE)


func go_to_player_sect_overview() -> void:
	_change_page(PLAYER_SECT_OVERVIEW_SCENE)


func go_to_battle_report() -> void:
	_change_page(BATTLE_REPORT_SCENE)


# 退出游戏。
func quit_game() -> void:
	get_tree().quit()


# 重新整理当前页面尺寸，窗口变化时会用到。
func update_current_page_layout() -> void:
	if current_page == null:
		return

	for child in current_page.get_children():
		_fit_page_to_current_page(child)


# 清空 CurrentPage，并加载新的页面场景。
func _change_page(scene_path: String) -> void:
	if current_page == null:
		push_error("SceneManager：CurrentPage 尚未设置，无法切换页面。")
		return

	# 移除旧页面，保证 CurrentPage 下永远只有当前页面。
	for child in current_page.get_children():
		current_page.remove_child(child)
		child.queue_free()

	var resource_load_started_at: int = Time.get_ticks_msec()
	var scene_resource: Resource = load(scene_path)
	if scene_path == WORLD_SCENE:
		print("[WorldPerf] World page resource load: %d ms" % (Time.get_ticks_msec() - resource_load_started_at))
	if scene_resource == null:
		push_error("SceneManager：找不到页面场景：" + scene_path)
		return

	var packed_scene: PackedScene = scene_resource as PackedScene
	if packed_scene == null:
		push_error("SceneManager：资源不是可实例化场景：" + scene_path)
		return

	# 实例化新页面，并放入 CurrentPage。
	var instantiate_started_at: int = Time.get_ticks_msec()
	var new_page: Node = packed_scene.instantiate()
	if scene_path == WORLD_SCENE:
		print("[WorldPerf] World page instantiate: %d ms" % (Time.get_ticks_msec() - instantiate_started_at))
	var add_child_started_at: int = Time.get_ticks_msec()
	current_page.add_child(new_page)
	if scene_path == WORLD_SCENE:
		print("[WorldPerf] World page add child: %d ms" % (Time.get_ticks_msec() - add_child_started_at))
	_fit_page_to_current_page(new_page)


# 如果页面根节点是 Control，就让它铺满 CurrentPage。
func _fit_page_to_current_page(page_node: Node) -> void:
	var page_control: Control = page_node as Control
	if page_control == null:
		return

	page_control.anchor_left = 0.0
	page_control.anchor_top = 0.0
	page_control.anchor_right = 1.0
	page_control.anchor_bottom = 1.0
	page_control.offset_left = 0.0
	page_control.offset_top = 0.0
	page_control.offset_right = 0.0
	page_control.offset_bottom = 0.0
