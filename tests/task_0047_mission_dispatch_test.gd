extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _mission_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_mission_manager = root.get_node("MissionManager")
	_test_registry_and_successful_dispatch()
	_test_failed_mission_injuries()
	_test_capacity_modifier_and_save_restore()
	await _test_mission_ui()
	if _failures.is_empty():
		print("[Task0047Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0047Test] " + failure)
	quit(1)


func _test_registry_and_successful_dispatch() -> void:
	_game_state.new_game()
	_expect(MissionRegistry.get_all().size() == 6, "应加载六类任务配置。")
	_expect(MissionRegistry.validate().is_empty(), "任务配置校验应通过。")
	var food_before: int = int(_world_data_manager.get_sect_resources("sect_001")["food"])
	var result: Dictionary = _mission_manager.create_and_start_mission(
		"sect_001", ["disciple_001"], "mission_gathering", {"_test_roll": 0.0}
	)
	_expect(bool(result.get("success", false)), "采集任务应能创建并出发。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["food"]) == food_before - 20, "出发时应统一扣除任务成本。")
	var deployed: Dictionary = _world_data_manager.get_disciple_by_id("disciple_001")
	_expect(bool(deployed.get("is_deployed", false)), "出发弟子应标记为派遣中。")
	_expect(str(deployed.get("team_id", "")) != "", "派遣弟子应关联队伍。")
	var prepared: Array = root.get_node("DiscipleManager").prepare_daily_actions("sect_001")
	_expect(not _contains_disciple(prepared, "disciple_001"), "派遣弟子不得参与宗门日常安排结算。")
	var blocked: Dictionary = _mission_manager.create_and_start_mission(
		"sect_001", ["disciple_002"], "mission_scouting", {"_test_roll": 0.0}
	)
	_expect(str(blocked.get("code", "")) == "mission_capacity", "默认任务容量应为一。")
	var wood_before: int = int(_world_data_manager.get_sect_resources("sect_001")["wood"])
	for _day in range(3):
		_game_state.next_day()
	_expect(_mission_manager.get_active_missions("sect_001").is_empty(), "持续时间结束后任务应完成。")
	var returned: Dictionary = _world_data_manager.get_disciple_by_id("disciple_001")
	_expect(not bool(returned.get("is_deployed", true)), "任务结束后弟子应归队。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["wood"]) >= wood_before + 80, "成功采集应写入资源奖励。")
	var missions: Array[Dictionary] = _mission_manager.get_all_missions("sect_001")
	_expect(str(missions[0].get("status", "")) == "completed", "任务实例应保留完整结果。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("mission_result").size() == 1, "任务结果应写入历史。")


func _test_failed_mission_injuries() -> void:
	_game_state.new_game()
	var health_before: int = int(_world_data_manager.get_disciple_by_id("disciple_001")["health"])
	var result: Dictionary = _mission_manager.create_and_start_mission(
		"sect_001", ["disciple_001", "disciple_002"], "mission_hunt", {"_test_roll": 1.0}
	)
	_expect(bool(result.get("success", false)), "讨伐任务应能正常出发。")
	for _day in range(6):
		_game_state.next_day()
	var mission_result: Dictionary = _mission_manager.get_all_missions("sect_001")[0].get("result", {})
	_expect(not bool(mission_result.get("success", true)), "强制失败判定应生效。")
	_expect(not mission_result.get("injuries", []).is_empty(), "失败任务应产生非致命伤势。")
	var health_after: int = int(_world_data_manager.get_disciple_by_id("disciple_001")["health"])
	_expect(health_after < health_before and health_after > 0, "伤势应降低健康但不得直接致死。")


func _test_capacity_modifier_and_save_restore() -> void:
	_game_state.new_game()
	_world_data_manager.building_instances.append({
		"instance_id": "building_test_mission_hall",
		"definition_id": "mission_hall",
		"sect_id": "sect_001",
		"level": 1,
		"target_level": 1,
		"status": "active",
		"remaining_days": 0,
		"build_slot_id": 0,
		"started_date": {},
		"completed_date": {},
		"operational": true,
		"maintenance_shortages": {},
	})
	_expect(root.get_node("ModifierManager").get_mission_capacity("sect_001") == 3, "任务堂应将任务容量从1提高到3。")
	var started: Dictionary = _mission_manager.create_and_start_mission(
		"sect_001", ["disciple_003"], "mission_gathering", {"_test_roll": 0.0}
	)
	_expect(bool(started.get("success", false)), "存档测试任务应能出发。")
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.mission_instances.clear()
	_world_data_manager.expedition_teams.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "包含任务状态的快照应可恢复。")
	_expect(_mission_manager.get_active_missions("sect_001").size() == 1, "恢复后进行中任务不得丢失。")
	var deployed: Dictionary = _world_data_manager.get_disciple_by_id("disciple_003")
	_expect(bool(deployed.get("is_deployed", false)) and str(deployed.get("team_id", "")) != "", "恢复后队伍和派遣状态应一致。")


func _test_mission_ui() -> void:
	_game_state.new_game()
	var packed := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = packed.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_mission_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection")
	var option: OptionButton = section.get_node("MissionControlBox/MissionOption")
	var list: VBoxContainer = section.get_node("MissionBody/AvailablePanel/AvailableScroll/AvailableDiscipleList")
	_expect(section.visible, "点击任务按钮应显示任务派遣区域。")
	_expect(option.item_count == 6, "任务下拉框应展示六类任务。")
	_expect(list.get_child_count() == 12, "任务界面应展示十二名可用弟子。")
	overview.queue_free()
	await process_frame


func _contains_disciple(actions: Array, disciple_id: String) -> bool:
	for action in actions:
		if str(action.get("disciple_id", "")) == disciple_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
