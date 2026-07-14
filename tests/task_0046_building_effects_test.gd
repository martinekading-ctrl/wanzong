extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _disciple_manager: Node
var _construction_manager: Node
var _modifier_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_disciple_manager = root.get_node("DiscipleManager")
	_construction_manager = root.get_node("ConstructionManager")
	_modifier_manager = root.get_node("ModifierManager")
	_test_capacity_production_cultivation_and_breakthrough_modifiers()
	_test_maintenance_shutdown_and_recovery()
	_test_sect_upgrade()
	_test_ai_uses_same_construction_rules()
	await _test_upgrade_ui()
	if _failures.is_empty():
		print("[Task0046Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0046Test] " + failure)
	quit(1)


func _test_capacity_production_cultivation_and_breakthrough_modifiers() -> void:
	_game_state.new_game()
	_add_resources()
	var base_capacity: int = _modifier_manager.get_disciple_capacity("sect_001")
	_build_and_complete("disciple_quarters")
	_expect(_modifier_manager.get_disciple_capacity("sect_001") == base_capacity + 20, "弟子居所1级应增加20容量。")
	var capacity: int = _modifier_manager.get_disciple_capacity("sect_001")
	var open_slots: int = capacity - _world_data_manager.get_player_disciples().size()
	for _index in range(open_slots):
		var created: DiscipleData = _disciple_manager.create_disciple("sect_001", "容量测试弟子")
		_expect(created != null, "容量范围内应允许新增弟子。")
	_expect(_disciple_manager.create_disciple("sect_001", "超额弟子") == null, "达到弟子容量后必须阻止继续招募。")

	_build_and_complete("spirit_field")
	_expect(is_equal_approx(_modifier_manager.get_multiplier_bonus("sect_001", "food_production"), 0.15), "灵田1级应提供15%粮食产出加成。")
	_expect(roundi(_modifier_manager.apply_numeric_modifier("sect_001", "food_production", 100.0)) == 115, "100基础粮食应被修正为115。")

	_build_and_complete("sect_hall")
	_build_and_complete("scripture_pavilion")
	var disciple: DiscipleData = _disciple_manager.get_disciple_by_id("disciple_012")
	disciple.talent = 50
	_expect(_disciple_manager.get_daily_cultivation_gain(disciple) == 8, "藏经阁应把7点基础修为增益提升到8。")
	disciple.realm_id = "qi_05"
	disciple.realm = "炼气五层"
	disciple.talent = 20
	disciple.potential = 20
	disciple.health = 60
	var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
	var chance_with_building: float = root.get_node("BreakthroughManager").calculate_success_rate(disciple, definition)
	var chance_without_building_bonus: float = root.get_node("BreakthroughManager").calculate_success_rate(disciple, definition, {"building_bonus": 0.0})
	_expect(is_equal_approx(chance_with_building - chance_without_building_bonus, 0.02), "藏经阁应增加2%突破率。")


func _test_maintenance_shutdown_and_recovery() -> void:
	_game_state.new_game()
	_add_resources()
	_build_and_complete("sect_hall")
	var resources: Dictionary = _world_data_manager.get_sect_resources("sect_001")
	_world_data_manager.update_sect_resource("sect_001", "spirit_stone", -int(resources["spirit_stone"]))
	_game_state.next_day()
	var hall: Dictionary = _find_building("sect_hall")
	_expect(not bool(hall.get("operational", true)), "维护灵石不足时宗门大殿必须停运。")
	_expect(not hall.get("maintenance_shortages", {}).is_empty(), "停运建筑应记录维护缺口。")
	_expect(_modifier_manager.get_additive_value("sect_001", "sect_level_cap") == 0.0, "停运建筑不得继续提供效果。")

	_world_data_manager.update_sect_resource("sect_001", "spirit_stone", 100)
	_game_state.next_day()
	hall = _find_building("sect_hall")
	_expect(bool(hall.get("operational", false)), "补足维护费后建筑应自动恢复运转。")
	_expect(_modifier_manager.get_additive_value("sect_001", "sect_level_cap") == 1.0, "恢复运转后效果应重新生效。")


func _test_sect_upgrade() -> void:
	_game_state.new_game()
	_add_resources()
	var before_hall: Dictionary = root.get_node("SectManager").upgrade_sect("sect_001")
	_expect(not bool(before_hall.get("success", true)), "没有宗门大殿时不能升级宗门。")
	_build_and_complete("sect_hall")
	_add_resources()
	var resources_before: Dictionary = _world_data_manager.get_sect_resources("sect_001").duplicate(true)
	var result: Dictionary = root.get_node("SectManager").upgrade_sect("sect_001")
	_expect(bool(result.get("success", false)), "1级有效宗门大殿应允许宗门升到2级。")
	_expect(int(_world_data_manager.get_player_sect().get("territory_level", 0)) == 2, "宗门等级必须写入世界数据。")
	for resource_key in result.get("costs", {}):
		_expect(int(_world_data_manager.get_sect_resources("sect_001")[resource_key]) == int(resources_before[resource_key]) - int(result["costs"][resource_key]), "宗门升级成本扣除错误。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("sect_upgrade").size() == 1, "宗门升级应写入历史。")


func _test_ai_uses_same_construction_rules() -> void:
	_game_state.new_game()
	_game_state.day = 30
	_game_state.next_day()
	var constructing_count: int = 0
	for sect_id in root.get_node("AISimulationManager").get_ai_sect_ids():
		for building in _construction_manager.get_buildings_by_sect_id(sect_id):
			if str(building.get("status", "")) == "constructing":
				constructing_count += 1
	_expect(constructing_count == WorldSectRoster.expected_ai_sect_count(), "首次月度决策应让全部AI宗门按同一规则开始建设。")
	for _day in range(4):
		_game_state.next_day()
	var active_count: int = 0
	for sect_id in root.get_node("AISimulationManager").get_ai_sect_ids():
		for building in _construction_manager.get_buildings_by_sect_id(sect_id):
			if str(building.get("status", "")) == "active":
				active_count += 1
	_expect(active_count == WorldSectRoster.expected_ai_sect_count(), "AI宗门建筑应按相同建设时间完成。")


func _test_upgrade_ui() -> void:
	_game_state.new_game()
	_add_resources()
	_build_and_complete("sect_hall")
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_building_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection")
	var level_label: Label = section.get_node("SectUpgradeBox/SectLevelLabel")
	var upgrade_button: Button = section.get_node("SectUpgradeBox/SectUpgradeButton")
	_expect(level_label.text.contains("大殿等级：1"), "建设界面应显示宗门和大殿等级。")
	_expect(not upgrade_button.disabled, "资源充足且大殿有效时升级按钮应可用。")
	overview.queue_free()
	await process_frame


func _build_and_complete(building_id: String) -> void:
	var result: Dictionary = _construction_manager.start_construction("sect_001", building_id)
	_expect(bool(result.get("success", false)), "建筑应开始建设：" + building_id)
	if not bool(result.get("success", false)):
		return
	for _day in range(int(result.get("instance", {}).get("remaining_days", 0))):
		_game_state.next_day()


func _find_building(building_id: String) -> Dictionary:
	for building in _construction_manager.get_buildings_by_sect_id("sect_001"):
		if str(building.get("definition_id", "")) == building_id:
			return building
	return {}


func _add_resources() -> void:
	for resource_key in ["spirit_stone", "food", "wood", "stone", "spirit_grass", "spirit_ore"]:
		_world_data_manager.update_sect_resource("sect_001", resource_key, 10000)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
