extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _diplomacy_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_diplomacy_manager = root.get_node("DiplomacyManager")
	_test_relation_catalog_and_statuses()
	_test_gift_trade_cooldown_and_rejection()
	_test_demand_ai_and_save_restore()
	await _test_diplomacy_ui()
	if _failures.is_empty():
		print("[Task0051Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0051Test] " + failure)
	quit(1)


func _test_relation_catalog_and_statuses() -> void:
	_game_state.new_game()
	_expect(_world_data_manager.relations.size() == 45, "十个宗门应形成45组无向关系。")
	_expect(_diplomacy_manager.get_relations_for_sect("sect_001").size() == 9, "玩家应拥有九个外交对象。")
	_expect(DiplomaticActionRegistry.get_all().size() == 4, "Task-0051应提供四类基础外交行动。")
	var relation: Dictionary = _diplomacy_manager.get_relation("sect_001", "sect_002")
	_expect(not relation.is_empty() and relation.has("value") and relation.has("status"), "关系值与外交状态必须分别存储。")
	_diplomacy_manager.change_relation_value("sect_001", "sect_002", 35, "测试友好")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "friendly", "关系值达到30应转为友好。")
	_diplomacy_manager.change_relation_value("sect_001", "sect_002", -80, "测试紧张")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "tense", "关系值低于-30应转为紧张。")
	_diplomacy_manager.change_relation_value("sect_001", "sect_002", -40, "测试敌对")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "hostile", "关系值低于-70应转为敌对。")
	_expect(str(_world_data_manager.get_sect_by_id("sect_002")["relation_to_player"]) == "hostile", "旧地图字段只能作为统一关系的派生缓存。")


func _test_gift_trade_cooldown_and_rejection() -> void:
	_game_state.new_game()
	var actor_stone: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var target_stone: int = int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"])
	var gift: Dictionary = _diplomacy_manager.perform_action("sect_001", "sect_002", "small_gift", {"_test_roll": 0.0})
	_expect(bool(gift.get("accepted", false)), "赠礼应被接受。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == actor_stone - 50, "赠礼应扣除玩家灵石。")
	_expect(int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"]) == target_stone + 50, "赠礼资源应实际转入目标宗门。")
	_expect(int(gift.get("relation", {}).get("value", 0)) == 10 and int(gift.get("relation", {}).get("trust", 0)) == 55, "赠礼应同步提高关系与信任。")
	var cooldown: Dictionary = _diplomacy_manager.perform_action("sect_001", "sect_002", "small_gift", {"_test_roll": 0.0})
	_expect(str(cooldown.get("code", "")) == "action_cooldown", "相同外交行动应受方向性冷却约束。")

	var food_before: int = int(_world_data_manager.get_sect_resources("sect_001")["food"])
	actor_stone = int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var trade: Dictionary = _diplomacy_manager.perform_action("sect_001", "sect_003", "fair_trade", {"_test_roll": 0.0})
	_expect(bool(trade.get("accepted", false)), "公平贸易应能按评分接受。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["food"]) == food_before - 60, "贸易应交付粮食。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == actor_stone + 25, "贸易应收到目标灵石。")

	var before_rejection: Dictionary = _world_data_manager.get_sect_resources("sect_001")
	var rejected: Dictionary = _diplomacy_manager.perform_action("sect_001", "sect_004", "goodwill_visit", {"_test_roll": 1.0})
	_expect(not bool(rejected.get("accepted", true)), "强制高判定应模拟外交拒绝。")
	_expect(_world_data_manager.get_sect_resources("sect_001") == before_rejection, "行动被拒绝时不得扣除成本。")
	_expect(int(rejected.get("relation", {}).get("tension", 0)) == 2, "拒绝应产生轻微紧张后果。")


func _test_demand_ai_and_save_restore() -> void:
	_game_state.new_game()
	var player_stone: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var target_stone: int = int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"])
	var demand: Dictionary = _diplomacy_manager.perform_action("sect_001", "sect_002", "demand_tribute", {"_test_roll": 0.0})
	_expect(bool(demand.get("accepted", false)), "强制低判定时索取应被接受。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == player_stone + 50, "贡礼应转入玩家仓库。")
	_expect(int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"]) == target_stone - 50, "目标宗门应实际支付贡礼。")
	_expect(int(demand.get("relation", {}).get("value", 0)) == -12 and int(demand.get("relation", {}).get("tension", 0)) == 15, "索取应恶化关系并增加紧张。")

	var state: Dictionary = _world_data_manager.ai_states["sect_002"]
	state["current_goal"] = "diplomacy"
	var ai_result: Dictionary = root.get_node("AISimulationManager").call("_perform_strategic_action", "sect_002", state)
	_expect(bool(ai_result.get("success", false)), "AI外交目标应复用DiplomacyManager。")
	_expect(int(_diplomacy_manager.get_relation("sect_001", "sect_002")["value"]) == -10, "AI外交行动应写入统一关系数据。")
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.relations.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "关系与行动历史应可恢复。")
	var restored: Dictionary = _diplomacy_manager.get_relation("sect_001", "sect_002")
	_expect(int(restored.get("value", 0)) == -10 and restored.get("action_history", []).size() >= 2, "读档后关系值与行动历史不得丢失。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("diplomacy").size() == 1, "玩家外交行动应写入全局历史。")


func _test_diplomacy_ui() -> void:
	_game_state.new_game()
	var packed := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = packed.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_diplomacy_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection")
	var target_option: OptionButton = section.get_node("ControlBox/TargetOption")
	var action_option: OptionButton = section.get_node("ControlBox/ActionOption")
	var list: VBoxContainer = section.get_node("RelationScroll/RelationList")
	_expect(section.visible, "点击外交按钮应显示外交界面。")
	_expect(target_option.item_count == 9, "外交目标应包含九个AI宗门。")
	_expect(action_option.item_count == 4, "外交界面应读取四个数据化行动。")
	_expect(list.get_child_count() == 9, "外交界面应展示玩家的九组关系。")
	overview.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
