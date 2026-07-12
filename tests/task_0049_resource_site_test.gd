extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _resource_site_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_resource_site_manager = root.get_node("ResourceSiteManager")
	_test_schema_discovery_and_capture()
	_test_garrison_production_and_loss()
	_test_save_restore()
	await _test_resource_site_ui()
	if _failures.is_empty():
		print("[Task0049Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0049Test] " + failure)
	quit(1)


func _test_schema_discovery_and_capture() -> void:
	_game_state.new_game()
	var sites: Array[Dictionary] = _resource_site_manager.get_discovered_sites("sect_001")
	_expect(sites.size() == 23, "应有23个可占领的非秘境资源点。")
	var site: Dictionary = sites[0]
	for key in ["owner_sect_id", "garrison_disciple_ids", "distance", "risk", "status", "discovered_by"]:
		_expect(site.has(key), "资源点缺少运行字段：" + key)
	_expect(str(site.get("owner_sect_id", "invalid")) == "", "初始资源点应为无主。")
	var start: Dictionary = _resource_site_manager.start_capture(
		1, "sect_001", ["disciple_001", "disciple_002"], "clear", {"_test_roll": 0.0}
	)
	_expect(bool(start.get("success", false)), "清理占领任务应能派出。")
	_expect(int(start.get("mission", {}).get("context", {}).get("resource_site_id", 0)) == 1, "任务实例应保存资源点目标。")
	for _day in range(6):
		_game_state.next_day()
	site = _resource_site_manager.get_site_by_id(1)
	_expect(str(site.get("owner_sect_id", "")) == "sect_001", "占领任务成功后资源点应归属玩家宗门。")
	_expect(str(site.get("status", "")) == "occupied_unsecured", "新占领资源点应等待驻守。")
	_expect(1 in _world_data_manager.get_player_sect().get("owned_resource_ids", []), "宗门占领列表应同步资源点ID。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("resource_capture").size() == 1, "占领结果应写入历史。")


func _test_garrison_production_and_loss() -> void:
	_game_state.new_game()
	_capture_site_one()
	var assigned: Dictionary = _resource_site_manager.assign_garrison(1, "sect_001", ["disciple_003"])
	_expect(bool(assigned.get("success", false)), "已占领资源点应可指派驻守。")
	var disciple: Dictionary = _world_data_manager.get_disciple_by_id("disciple_003")
	_expect(bool(disciple.get("is_deployed", false)) and str(disciple.get("team_id", "")).begins_with("garrison_resource_"), "驻守弟子应离开宗门日常分工。")
	var ore_before: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_ore"])
	var reserve_before: int = int(_resource_site_manager.get_site_by_id(1)["amount"])
	var report: Dictionary = _game_state.next_day()
	var site_report: Dictionary = report.get("resource_sites", {})
	_expect(site_report.get("production", []).size() == 1, "有驻守且维护充足的资源点应每日生产。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_ore"]) == ore_before + 5, "一级灵矿每日应产出5灵矿。")
	_expect(int(_resource_site_manager.get_site_by_id(1)["amount"]) == reserve_before - 5, "资源产出应同步消耗储量。")
	_expect(_resource_site_manager.withdraw_garrison(1, "sect_001"), "玩家应可撤回驻守。")
	disciple = _world_data_manager.get_disciple_by_id("disciple_003")
	_expect(not bool(disciple.get("is_deployed", true)), "撤回后弟子应恢复可用。")
	for _day in range(3):
		_game_state.next_day()
	var lost: Dictionary = _resource_site_manager.get_site_by_id(1)
	_expect(str(lost.get("owner_sect_id", "invalid")) == "" and str(lost.get("status", "")) == "unclaimed", "连续三日无人驻守应导致资源点失守。")
	_expect(1 not in _world_data_manager.get_player_sect().get("owned_resource_ids", []), "失守后宗门占领列表应移除资源点。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("resource_lost").size() == 1, "资源点失守应写入历史。")


func _test_save_restore() -> void:
	_game_state.new_game()
	_capture_site_one()
	_resource_site_manager.assign_garrison(1, "sect_001", ["disciple_004"])
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.resources[0]["owner_sect_id"] = ""
	_world_data_manager.resources[0]["garrison_disciple_ids"] = []
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "资源点完整状态应可恢复。")
	var restored: Dictionary = _resource_site_manager.get_site_by_id(1)
	_expect(str(restored.get("owner_sect_id", "")) == "sect_001", "读档后资源点归属不得丢失。")
	_expect(restored.get("garrison_disciple_ids", []) == ["disciple_004"], "读档后驻守名单不得丢失。")
	var disciple: Dictionary = _world_data_manager.get_disciple_by_id("disciple_004")
	_expect(bool(disciple.get("is_deployed", false)), "读档后驻守弟子的派遣状态应重建。")


func _test_resource_site_ui() -> void:
	_game_state.new_game()
	var packed := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = packed.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_resource_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection")
	var option: OptionButton = section.get_node("ControlBox/SiteOption")
	var list: VBoxContainer = section.get_node("Body/DisciplePanel/DiscipleScroll/DiscipleList")
	_expect(section.visible, "点击资源按钮应显示资源点管理区。")
	_expect(option.item_count == 23, "资源点管理区应列出23个可占领资源点。")
	_expect(list.get_child_count() == 12, "占领与驻守应从玩家弟子中选择队员。")
	overview.queue_free()
	await process_frame


func _capture_site_one() -> void:
	var start: Dictionary = _resource_site_manager.start_capture(
		1, "sect_001", ["disciple_001", "disciple_002"], "clear", {"_test_roll": 0.0}
	)
	_expect(bool(start.get("success", false)), "测试资源点占领任务应成功派出。")
	for _day in range(6):
		_game_state.next_day()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
