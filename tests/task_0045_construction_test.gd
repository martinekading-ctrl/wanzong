extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _construction_manager: Node
var _save_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_construction_manager = root.get_node("ConstructionManager")
	_save_manager = root.get_node("SaveManager")
	_test_building_catalog()
	_test_prerequisites_costs_slots_and_daily_completion()
	_test_upgrade_and_save_restore()
	await _test_building_ui()
	if _failures.is_empty():
		print("[Task0045Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0045Test] " + failure)
	quit(1)


func _test_building_catalog() -> void:
	BuildingRegistry.reload()
	var definitions: Array[BuildingDefinition] = BuildingRegistry.get_all()
	_expect(definitions.size() == 10, "首批建筑配置必须包含10类建筑。")
	_expect(BuildingRegistry.validate().is_empty(), "建筑配置校验必须通过。")
	var expected_ids: Array[String] = [
		"sect_hall", "disciple_quarters", "spirit_field", "herb_garden", "mine",
		"scripture_pavilion", "alchemy_room", "forge", "mission_hall", "mountain_array",
	]
	for building_id in expected_ids:
		var definition: BuildingDefinition = BuildingRegistry.get_by_id(building_id)
		_expect(definition != null, "缺少建筑配置：" + building_id)
		if definition != null:
			_expect(definition.construction_days > 0, building_id + "必须有建设时间。")
			_expect(not definition.construction_costs.is_empty(), building_id + "必须有建设成本。")
			_expect(not definition.maintenance_costs.is_empty(), building_id + "必须有维护费。")
			_expect(not definition.effects.is_empty(), building_id + "必须预留建筑效果。")


func _test_prerequisites_costs_slots_and_daily_completion() -> void:
	_game_state.new_game()
	var resources_before: Dictionary = _world_data_manager.get_sect_resources("sect_001").duplicate(true)
	var blocked: Dictionary = _construction_manager.start_construction("sect_001", "herb_garden")
	_expect(str(blocked.get("code", "")) == "prerequisite_missing", "药园在大殿建成前必须被前置条件阻止。")
	_expect(_world_data_manager.get_sect_resources("sect_001") == resources_before, "前置检查失败不得扣资源。")

	var start: Dictionary = _construction_manager.start_construction("sect_001", "sect_hall")
	_expect(bool(start.get("success", false)), "初始资源应足以建设宗门大殿。")
	var costs: Dictionary = start.get("costs", {})
	for resource_key in costs:
		_expect(int(_world_data_manager.get_sect_resources("sect_001")[resource_key]) == int(resources_before[resource_key]) - int(costs[resource_key]), "建设成本扣除错误：" + str(resource_key))
	var instance: Dictionary = start.get("instance", {})
	var slot_id: int = int(instance.get("build_slot_id", -1))
	_expect(slot_id > 0, "玩家建筑必须占用真实建设点。")
	var occupied_slot: Dictionary = _find_slot(slot_id)
	_expect(not bool(occupied_slot.get("is_empty", true)), "建设开始后建设点应被占用。")
	var second: Dictionary = _construction_manager.start_construction("sect_001", "disciple_quarters")
	_expect(str(second.get("code", "")) == "construction_limit", "同一宗门当前只能进行一项建设。")

	for _day in range(4):
		_game_state.next_day()
	var before_completion: Dictionary = _construction_manager.get_buildings_by_sect_id("sect_001")[0]
	_expect(str(before_completion.get("status", "")) == "constructing", "大殿在第4日不应提前完成。")
	_expect(int(before_completion.get("remaining_days", -1)) == 1, "第4日后应剩余1日。")
	var completion_report: Dictionary = _game_state.next_day()
	var completed: Array = completion_report.get("construction", {}).get("completed", [])
	_expect(completed.size() == 1, "第5日应完成宗门大殿。")
	var active: Dictionary = _construction_manager.get_buildings_by_sect_id("sect_001")[0]
	_expect(str(active.get("status", "")) == "active" and int(active.get("level", 0)) == 1, "完成后大殿应为1级有效建筑。")
	_expect(str(active.get("instance_id", "")) in _world_data_manager.get_player_sect().get("buildings", []), "完成建筑应写入宗门建筑列表。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("building_completed").size() == 1, "建筑完成应写入历史。")


func _test_upgrade_and_save_restore() -> void:
	_game_state.new_game()
	_add_resources_for_testing()
	var start: Dictionary = _construction_manager.start_construction("sect_001", "sect_hall")
	for _day in range(5):
		_game_state.next_day()
	var original_instance_id: String = str(start.get("instance", {}).get("instance_id", ""))
	var snapshot: Dictionary = _save_manager.create_snapshot()
	_game_state.new_game()
	_expect(_save_manager.apply_snapshot(snapshot), "包含建筑实例的完整存档应恢复。")
	var restored: Array[Dictionary] = _construction_manager.get_buildings_by_sect_id("sect_001")
	_expect(restored.size() == 1 and str(restored[0].get("instance_id", "")) == original_instance_id, "读档后建筑实例ID和状态应保留。")

	_add_resources_for_testing()
	var upgrade: Dictionary = _construction_manager.start_construction("sect_001", "sect_hall")
	_expect(bool(upgrade.get("success", false)), "已建成建筑应支持升级。")
	_expect(str(upgrade.get("instance", {}).get("instance_id", "")) == original_instance_id, "升级必须复用原建筑实例和建设点。")
	var upgrade_days: int = int(upgrade.get("instance", {}).get("remaining_days", 0))
	for _day in range(upgrade_days):
		_game_state.next_day()
	var upgraded: Dictionary = _construction_manager.get_buildings_by_sect_id("sect_001")[0]
	_expect(int(upgraded.get("level", 0)) == 2 and str(upgraded.get("status", "")) == "active", "升级完成后建筑等级应为2。")


func _test_building_ui() -> void:
	_game_state.new_game()
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_building_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection")
	var list: VBoxContainer = section.get_node("BuildingScroll/BuildingList")
	_expect(section.visible, "点击建筑按钮后应显示建设界面。")
	_expect(list.get_child_count() == 10, "建设界面应显示全部10类建筑。")
	overview.queue_free()
	await process_frame


func _add_resources_for_testing() -> void:
	for resource_key in ["spirit_stone", "wood", "stone", "spirit_grass", "spirit_ore"]:
		_world_data_manager.update_sect_resource("sect_001", resource_key, 5000)


func _find_slot(slot_id: int) -> Dictionary:
	for slot in _world_data_manager.get_all_build_slots():
		if int(slot.get("slot_id", -1)) == slot_id:
			return slot
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
