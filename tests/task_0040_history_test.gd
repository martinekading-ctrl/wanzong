extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _disciple_manager: Node
var _world_data_manager: Node
var _breakthrough_manager: Node
var _event_manager: Node
var _history_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_disciple_manager = root.get_node("DiscipleManager")
	_world_data_manager = root.get_node("WorldDataManager")
	_breakthrough_manager = root.get_node("BreakthroughManager")
	_event_manager = root.get_node("EventManager")
	_history_manager = root.get_node("GameHistoryManager")
	_test_integrated_history_sources_and_queries()
	_test_serialization_and_memory_budget()
	await _test_history_ui()
	if _failures.is_empty():
		print("[Task0040Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0040Test] " + failure)
	quit(1)


func _test_integrated_history_sources_and_queries() -> void:
	_game_state.new_game()
	_game_state.next_day()
	var daily_entries: Array[Dictionary] = _history_manager.get_entries_by_category("daily_settlement")
	_expect(daily_entries.size() == 1, "每日推进应写入一条结算历史。")
	_expect(_history_manager.get_entries_by_date(1, 1, 1).size() == 1, "历史应支持按日期查询。")

	var disciple: DiscipleData = _disciple_manager.get_disciple_by_id("disciple_012")
	disciple.realm_id = "mortal"
	disciple.realm = "凡人"
	disciple.cultivation = 50
	disciple.at_bottleneck = true
	disciple.health = 100
	_disciple_manager.sync_disciple_state(disciple)
	_breakthrough_manager.attempt_breakthrough(disciple.id, {"_test_roll": 0.0})
	_expect(_history_manager.get_entries_by_category("disciple_breakthrough").size() == 1, "弟子突破应写入统一历史。")
	_expect(_history_manager.get_entries_by_entity(disciple.id).size() == 1, "历史应支持按弟子ID查询。")

	var events: Array[Dictionary] = _event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": 1, "month": 1, "day": 3},
	})
	var council: Dictionary = _find_event(events, "sect_first_council")
	_event_manager.resolve_event(str(council.get("instance_id", "")), "steady_growth")
	_expect(_history_manager.get_entries_by_category("major_event").size() == 1, "重大事件解决后应写入统一历史。")

	_history_manager.record_entry("building_completed", "建筑完成", "宗门大殿完成。", ["sect_001", "building_001"])
	_history_manager.record_entry("diplomacy_changed", "外交变化", "与凌霄剑派关系变化。", ["sect_001", "sect_002"])
	_history_manager.record_entry("battle_result", "战斗结果", "测试战斗结束。", ["sect_001", "battle_001"])
	_expect(_history_manager.get_entries_by_category("building_completed").size() == 1, "通用入口应支持未来建筑记录。")
	_expect(_history_manager.get_entries_by_entity("sect_001").size() >= 4, "历史应支持一个实体关联多类记录。")


func _test_serialization_and_memory_budget() -> void:
	_history_manager.reset()
	_history_manager.record_entry("test", "记录一", "第一条。")
	_history_manager.record_entry("test", "记录二", "第二条。")
	var serialized: Array[Dictionary] = _history_manager.serialize_history()
	_history_manager.reset()
	_history_manager.restore_history(serialized)
	_expect(_history_manager.get_all_entries().size() == 2, "历史序列化恢复后条数应一致。")
	var restored_entry: Dictionary = _history_manager.record_entry("test", "记录三", "第三条。")
	_expect(str(restored_entry.get("history_id", "")) == "history_000003", "恢复后历史ID应继续递增。")

	_history_manager.reset()
	for index in range(_history_manager.MAX_HISTORY_ENTRIES + 5):
		_history_manager.record_entry("budget", "预算测试", "记录%d" % index)
	var bounded: Array[Dictionary] = _history_manager.get_all_entries()
	_expect(bounded.size() == _history_manager.MAX_HISTORY_ENTRIES, "内存历史条数必须受上限约束。")
	_expect(str(bounded[0].get("message", "")) == "记录5", "超过上限时应淘汰最旧记录。")


func _test_history_ui() -> void:
	_game_state.new_game()
	_history_manager.record_entry("test", "界面记录", "历史界面应显示此条。", ["sect_001"])
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_history_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/HistorySection")
	var list: VBoxContainer = section.get_node("HistoryScroll/HistoryList")
	_expect(section.visible, "点击历史按钮后应显示历史区域。")
	_expect(list.get_child_count() == 1, "历史区域应生成一条记录。")
	var label := list.get_child(0) as Label
	_expect(label != null and label.text.contains("界面记录"), "历史列表应显示记录标题。")
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
