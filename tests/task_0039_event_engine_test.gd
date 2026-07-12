extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _disciple_manager: Node
var _world_data_manager: Node
var _event_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_disciple_manager = root.get_node("DiscipleManager")
	_world_data_manager = root.get_node("WorldDataManager")
	_event_manager = root.get_node("EventManager")
	_test_definition_catalog_and_trigger_types()
	_test_fixed_date_event_and_single_trigger()
	_test_resource_event_resolution()
	_test_disciple_event_resolution()
	_test_probability_trigger_and_daily_report()
	await _test_pending_event_ui()
	if _failures.is_empty():
		print("[Task0039Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0039Test] " + failure)
	quit(1)


func _test_definition_catalog_and_trigger_types() -> void:
	_event_manager.reload_definitions()
	var definitions: Array[EventDefinition] = _event_manager.get_all_definitions()
	_expect(definitions.size() == 4, "第一版应加载4种事件配置。")
	var categories: Array[String] = []
	for definition in definitions:
		categories.append(definition.category)
	for category in ["disciple", "resource", "sect", "world"]:
		_expect(category in categories, "事件类型缺失：" + category)

	_game_state.new_game()
	var relation_definition := EventDefinition.new()
	relation_definition.trigger = {"type": "sect_relation", "sect_id": "sect_002", "relation": "neutral"}
	var relation_result: Dictionary = _event_manager.call("_evaluate_trigger", relation_definition, {})
	_expect(bool(relation_result.get("matched", false)), "宗门关系触发器应支持关系状态。")
	var mission_definition := EventDefinition.new()
	mission_definition.trigger = {"type": "mission_result", "result": "success"}
	var mission_result: Dictionary = _event_manager.call(
		"_evaluate_trigger",
		mission_definition,
		{"mission_result": {"mission_id": "mission_test", "result": "success"}}
	)
	_expect(bool(mission_result.get("matched", false)), "任务结果触发器应读取上下文。")


func _test_fixed_date_event_and_single_trigger() -> void:
	_game_state.new_game()
	var reputation_before: int = int(_world_data_manager.get_player_sect().get("reputation", 0))
	var triggered: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 3},
	})
	var event_data: Dictionary = _find_event(triggered, "sect_first_council")
	_expect(not event_data.is_empty(), "固定日期应触发宗门议事事件。")
	var duplicate: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 3},
	})
	_expect(_find_event(duplicate, "sect_first_council").is_empty(), "未决事件不得重复创建。")
	var resolved: Dictionary = _event_manager.resolve_event(str(event_data.get("instance_id", "")), "steady_growth")
	_expect(bool(resolved.get("success", false)), "宗门议事选项应成功结算。")
	_expect(int(_world_data_manager.get_player_sect().get("reputation", 0)) == reputation_before + 5, "事件效果应增加5点宗门声望。")
	var after_resolve: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 3},
	})
	_expect(_find_event(after_resolve, "sect_first_council").is_empty(), "一次性事件解决后不得再次触发。")


func _test_resource_event_resolution() -> void:
	_game_state.new_game()
	var resources: Dictionary = _world_data_manager.get_sect_resources("sect_001")
	_world_data_manager.update_sect_resource("sect_001", "food", 100 - int(resources["food"]))
	var stones_before: int = int(resources["spirit_stone"])
	var events: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 1},
	})
	var event_data: Dictionary = _find_event(events, "resource_food_shortage")
	_expect(not event_data.is_empty(), "粮食达到阈值时应触发资源事件。")
	var result: Dictionary = _event_manager.resolve_event(str(event_data.get("instance_id", "")), "purchase_food")
	_expect(bool(result.get("success", false)), "购买粮食选项应成功。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["food"]) == 200, "事件应增加100粮食。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == stones_before - 20, "事件应扣除20灵石。")


func _test_disciple_event_resolution() -> void:
	_game_state.new_game()
	var disciple: DiscipleData = _disciple_manager.get_disciple_by_id("disciple_012")
	disciple.cultivation = 50
	disciple.at_bottleneck = true
	_disciple_manager.sync_disciple_state(disciple)
	var loyalty_before: int = disciple.loyalty
	var stones_before: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var events: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 1},
	})
	var event_data: Dictionary = _find_event(events, "disciple_bottleneck_guidance")
	_expect(not event_data.is_empty(), "弟子瓶颈应触发弟子事件。")
	var result: Dictionary = _event_manager.resolve_event(str(event_data.get("instance_id", "")), "personal_guidance")
	_expect(bool(result.get("success", false)), "亲自指点选项应成功。")
	_expect(disciple.loyalty == loyalty_before + 3, "事件应同步增加运行时弟子忠诚。")
	_expect(int(_world_data_manager.get_disciple_by_id(disciple.id)["loyalty"]) == loyalty_before + 3, "事件应同步增加持久数据忠诚。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == stones_before - 5, "指点事件应扣除5灵石。")


func _test_probability_trigger_and_daily_report() -> void:
	_game_state.new_game()
	var events: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 1},
		"_test_rolls": {"world_spiritual_tide": 0.0},
	})
	_expect(not _find_event(events, "world_spiritual_tide").is_empty(), "每日概率事件应支持固定测试判定。")

	_game_state.new_game()
	_game_state.day = 3
	var report: Dictionary = _game_state.next_day()
	_expect(report.has("events"), "每日结算报告必须包含事件列表。")
	_expect(not _find_event(report.get("events", []), "sect_first_council").is_empty(), "每日推进应接入固定日期事件触发。")


func _test_pending_event_ui() -> void:
	_game_state.new_game()
	var disciple: DiscipleData = _disciple_manager.get_disciple_by_id("disciple_012")
	disciple.cultivation = 50
	disciple.at_bottleneck = true
	_disciple_manager.sync_disciple_state(disciple)
	_event_manager.daily_update({"sect_id": "sect_001", "date": {"year": 1, "month": 1, "day": 1}})
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	var panel: PanelContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/PendingEventPanel")
	var option_box: HBoxContainer = panel.get_node("EventBox/EventOptionBox")
	_expect(panel.visible, "存在未决事件时宗门详情应显示事件面板。")
	_expect(option_box.get_child_count() >= 1, "事件面板应由配置动态生成选项按钮。")
	overview.queue_free()
	await process_frame


func _find_event(events: Array, definition_id: String) -> Dictionary:
	for event_data in events:
		if str(event_data.get("definition_id", "")) == definition_id:
			return event_data
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
