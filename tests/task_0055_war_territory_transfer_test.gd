extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _war_manager: Node
var _resource_site_manager: Node
var _diplomacy_manager: Node
var _disciple_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_war_manager = root.get_node("WarManager")
	_resource_site_manager = root.get_node("ResourceSiteManager")
	_diplomacy_manager = root.get_node("DiplomacyManager")
	_disciple_manager = root.get_node("DiscipleManager")
	_test_resource_campaign_supply_battle_and_transfer()
	_test_supply_retreat_and_manual_retreat()
	_test_sect_siege_and_save_restore()
	await _test_war_ui()
	if _failures.is_empty():
		print("[Task0055Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0055Test] " + failure)
	quit(1)


func _test_resource_campaign_supply_battle_and_transfer() -> void:
	_game_state.new_game()
	var ai_garrison: Array[String] = _ai_ids("sect_002", 2)
	var transfer: Dictionary = _resource_site_manager.transfer_site_control(1, "sect_002", ai_garrison, _date(1), "test_setup")
	_expect(bool(transfer.get("success", false)), "测试资源点应可交给AI驻守。")
	_diplomacy_manager.declare_war("sect_001", "sect_002", "resource_conflict")
	_make_force_strong(["disciple_003", "disciple_008"])
	_make_force_weak(ai_garrison)
	var food_before: int = int(_world_data_manager.get_sect_resources("sect_001")["food"])
	var stone_before: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var started: Dictionary = _war_manager.start_resource_campaign("sect_001", 1, ["disciple_003", "disciple_008"], {"seed": 55})
	_expect(bool(started.get("success", false)), "战争状态下应可发起资源点争夺。")
	var campaign: Dictionary = started.get("campaign", {})
	var march_days: int = int(campaign.get("remaining_march_days", 0))
	_expect(march_days >= 1 and int(campaign.get("daily_food_cost", 0)) == 4, "行军应按距离和人数计算日数及补给。")
	_expect(bool(_world_data_manager.get_disciple_by_id("disciple_003").get("is_deployed", false)), "出征弟子应离开宗门日常分工。")
	for day in range(march_days):
		_war_manager.daily_update(_date(day + 1))
	var completed: Dictionary = _war_manager.get_campaign(str(campaign.get("campaign_id", "")))
	_expect(str(completed.get("phase", "")) == "resolved", "行军结束后应自动进入并完成战斗。")
	_expect(str(completed.get("winner_sect_id", "")) == "sect_001", "强势玩家队伍应赢得资源点战斗。")
	var site: Dictionary = _resource_site_manager.get_site_by_id(1)
	_expect(str(site.get("owner_sect_id", "")) == "sect_001", "战争胜利应转移资源点控制权。")
	_expect(not site.get("garrison_disciple_ids", []).is_empty(), "存活的进攻弟子应成为新驻守。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["food"]) == food_before - march_days * 4, "行军每日应扣除人数对应食物。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) >= stone_before - march_days * 2, "行军灵石补给与战利品应统一结算。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("territory_transfer").size() >= 2, "控制权设置和战争转移都应留下领地历史。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("war_campaign").size() == 1, "战争行动结果应写入历史。")


func _test_supply_retreat_and_manual_retreat() -> void:
	_game_state.new_game()
	_diplomacy_manager.declare_war("sect_001", "sect_002", "test")
	var started: Dictionary = _war_manager.start_sect_siege("sect_001", "sect_002", ["disciple_001", "disciple_002"], {"seed": 12})
	var campaign_id: String = str(started.get("campaign", {}).get("campaign_id", ""))
	var resources: Dictionary = _world_data_manager.get_sect_resources("sect_001")
	_world_data_manager.update_sect_resource("sect_001", "food", -int(resources.get("food", 0)))
	for day in range(3):
		_war_manager.daily_update(_date(day + 1))
	var retreated: Dictionary = _war_manager.get_campaign(campaign_id)
	_expect(str(retreated.get("phase", "")) == "retreated" and bool(retreated.get("result", {}).get("retreated", false)), "连续三日补给不足必须自动撤退。")
	_expect(not bool(_world_data_manager.get_disciple_by_id("disciple_001").get("is_deployed", true)), "撤退后进攻弟子应返回宗门。")
	_expect(str(retreated.get("battle_id", "")) == "", "补给撤退不得创建战斗实例。")

	_game_state.new_game()
	_diplomacy_manager.declare_war("sect_001", "sect_002", "test")
	started = _war_manager.start_sect_siege("sect_001", "sect_002", ["disciple_001"], {"seed": 13})
	var manual: Dictionary = _war_manager.retreat_campaign(str(started.get("campaign", {}).get("campaign_id", "")))
	_expect(bool(manual.get("retreated", false)) and str(manual.get("reason", "")) == "主动撤退", "行军阶段应允许主动撤退。")


func _test_sect_siege_and_save_restore() -> void:
	_game_state.new_game()
	_diplomacy_manager.declare_war("sect_001", "sect_002", "siege_test")
	_make_force_strong(["disciple_003", "disciple_008"])
	var ai_ids: Array[String] = _ai_ids("sect_002", 3)
	_make_force_weak(ai_ids)
	_world_data_manager.building_instances.append({"instance_id": "siege_array", "definition_id": "mountain_array", "sect_id": "sect_002", "level": 1, "target_level": 1, "status": "active", "remaining_days": 0, "build_slot_id": 0, "started_date": {}, "completed_date": {}, "operational": true, "maintenance_shortages": {}})
	var reputation_before: int = int(_world_data_manager.get_sect_by_id("sect_002")["reputation"])
	var power_before: int = int(_world_data_manager.get_sect_by_id("sect_002")["combat_power"])
	var started: Dictionary = _war_manager.start_sect_siege("sect_001", "sect_002", ["disciple_003", "disciple_008"], {"seed": 99})
	var campaign_id: String = str(started.get("campaign", {}).get("campaign_id", ""))
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.war_campaigns.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "行军中的战争行动应可存档恢复。")
	_expect(_war_manager.get_active_campaigns("sect_001").size() == 1, "读档后战争行动不得丢失。")
	_expect(bool(_world_data_manager.get_disciple_by_id("disciple_003").get("is_deployed", false)), "读档后出征状态应重建。")
	var march_days: int = int(_war_manager.get_campaign(campaign_id).get("remaining_march_days", 0))
	for day in range(march_days):
		_war_manager.daily_update(_date(day + 1))
	var completed: Dictionary = _war_manager.get_campaign(campaign_id)
	_expect(str(completed.get("phase", "")) == "resolved", "恢复后的围攻应继续至结算。")
	if str(completed.get("winner_sect_id", "")) == "sect_001":
		_expect(int(_world_data_manager.get_sect_by_id("sect_002")["reputation"]) == reputation_before - 20, "攻破宗门应降低守方声望。")
		_expect(int(_world_data_manager.get_sect_by_id("sect_002")["combat_power"]) < power_before, "攻破宗门应削弱守方战力。")


func _test_war_ui() -> void:
	_game_state.new_game()
	var report: Control = (load("res://scenes/battle/BattleReport.tscn") as PackedScene).instantiate()
	root.add_child(report)
	await process_frame
	var war_button: Button = report.get_node("Margin/RootBox/ControlBar/WarButton")
	_expect(war_button.disabled, "未宣战时宗门进攻按钮必须禁用。")
	_diplomacy_manager.declare_war("sect_001", "sect_002", "ui_test")
	report.call("_on_target_selected", 0)
	_expect(not war_button.disabled, "宣战后对应目标的宗门进攻按钮应启用。")
	var advance_button: Button = report.get_node("Margin/RootBox/ControlBar/AdvanceDayButton")
	_expect(advance_button.text == "推进一天", "战报页应提供战争行军推进入口。")
	report.queue_free()
	await process_frame


func _make_force_strong(ids: Array[String]) -> void:
	for disciple_id in ids:
		_world_data_manager.update_disciple_fields(disciple_id, {"attack": 400, "defense": 180, "speed": 180, "spiritual_power": 300, "hp": 600, "max_hp": 600, "health": 100})
	_disciple_manager.load_from_world_data()


func _make_force_weak(ids: Array[String]) -> void:
	for disciple_id in ids:
		_world_data_manager.update_disciple_fields(disciple_id, {"attack": 5, "defense": 2, "speed": 5, "spiritual_power": 0, "hp": 50, "max_hp": 50, "health": 100})
	_disciple_manager.load_from_world_data()


func _ai_ids(sect_id: String, count: int) -> Array[String]:
	var result: Array[String] = []
	for disciple in _world_data_manager.get_disciples_by_sect_id(sect_id):
		result.append(str(disciple.get("disciple_id", "")))
		if result.size() >= count: break
	return result


func _date(day: int) -> Dictionary:
	return {"year": 1, "month": 1, "day": day}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
