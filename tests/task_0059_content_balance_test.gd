extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data: Node
var _story_goal: Node
var _inventory: Node
var _history: Node
var _save: Node
var _event: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data = root.get_node("WorldDataManager")
	_story_goal = root.get_node("StoryGoalManager")
	_inventory = root.get_node("InventoryManager")
	_history = root.get_node("GameHistoryManager")
	_save = root.get_node("SaveManager")
	_event = root.get_node("EventManager")
	_test_content_registries()
	_test_story_goal_completion_and_save()
	_test_event_chain()
	_test_balance_simulation()
	await _test_goal_ui()
	if _failures.is_empty():
		print("[Task0059Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0059Test] " + failure)
	quit(1)


func _test_content_registries() -> void:
	var regions: Array[RegionDefinition] = RegionRegistry.get_all()
	var goals: Array[StoryGoalDefinition] = StoryGoalRegistry.get_all()
	_expect(regions.size() == 8, "区域配置应包含八个差异化区域。")
	_expect(goals.size() == 6, "长期目标配置应包含六个目标。")
	var region_ids: Dictionary = {}
	for region in regions:
		region_ids[region.id] = true
		_expect(region.display_name != "" and region.tags.size() > 0, "每个区域必须具备名称和内容标签。")
	_expect(region_ids.size() == regions.size(), "区域 ID 必须唯一。")


func _test_story_goal_completion_and_save() -> void:
	_game_state.new_game()
	_expect(_world_data.story_goals.size() == 6, "新游戏必须初始化全部长期目标状态。")
	var stone_before: int = _inventory.get_item_count("sect_001", "spirit_stone")
	var player: Dictionary = _world_data.get_player_sect()
	player["territory_level"] = 2
	_expect(_world_data.update_sect_data("sect_001", "territory_level", 2), "测试条件应可更新宗门等级。")
	var report: Dictionary = _story_goal.daily_update({"year": 1, "month": 1, "day": 1})
	_expect(report.get("completed", []).size() == 1, "达到条件后应完成稳固山门目标。")
	_expect(_inventory.get_item_count("sect_001", "spirit_stone") == stone_before + 200, "目标奖励必须写入真实宗门库存。")
	_expect(_history.get_entries_by_category("story_goal").size() == 1, "目标完成应进入统一历史记录。")
	var snapshot: Dictionary = _save.create_snapshot()
	_world_data.story_goals.clear()
	_expect(_save.apply_snapshot(snapshot), "长期目标状态应可随存档恢复。")
	_expect(str(_world_data.story_goals["goal_foundation"].get("status", "")) == "completed", "读档后已完成目标不得回退。")


func _test_event_chain() -> void:
	_game_state.new_game()
	var day_ten: Dictionary = {"sect_id": "sect_001", "date": {"year": 1, "month": 1, "day": 10}}
	var day_fifteen: Dictionary = {"sect_id": "sect_001", "date": {"year": 1, "month": 1, "day": 15}}
	var first_events: Array[Dictionary] = _event.daily_update(day_ten)
	var first: Dictionary = _find_event(first_events, "story_ancient_map_01")
	_expect(not first.is_empty(), "古图事件链第一段应在指定日期触发。")
	var blocked_events: Array[Dictionary] = _event.daily_update(day_fifteen)
	_expect(_find_event(blocked_events, "story_ancient_map_02").is_empty(), "前置事件未解决时不得触发后续事件。")
	if not first.is_empty():
		var resolved: Dictionary = _event.resolve_event(str(first.get("instance_id", "")), "study")
		_expect(bool(resolved.get("success", false)), "事件链第一段应可正常解决。")
	var second_events: Array[Dictionary] = _event.daily_update(day_fifteen)
	var second: Dictionary = _find_event(second_events, "story_ancient_map_02")
	_expect(not second.is_empty(), "前置事件解决后应解锁事件链第二段。")
	if not second.is_empty():
		_expect(bool(_event.resolve_event(str(second.get("instance_id", "")), "investigate").get("success", false)), "事件链第二段应可正常解决并应用奖励。")


func _test_balance_simulation() -> void:
	_game_state.new_game()
	var original_date: Array[int] = [_game_state.year, _game_state.month, _game_state.day]
	var result: Dictionary = BalanceSimulation.run(360, true)
	_expect(int(result.get("days_completed", 0)) == 360, "数值模拟应完整推进三百六十天。")
	_expect(int(result.get("negative_resource_count", -1)) == 0, "长期模拟中经济资源不得出现负数。")
	_expect(int(result.get("sect_count", 0)) >= 10 and int(result.get("active_ai_count", 0)) >= 9, "长期模拟应维持完整世界宗门数量。")
	_expect(int(result.get("maximum_day_ms", 10000)) < 1000, "包含自动存档的单日模拟峰值不应超过一秒。")
	_expect(bool(result.get("restored", false)), "数值模拟必须成功恢复执行前快照。")
	_expect([_game_state.year, _game_state.month, _game_state.day] == original_date, "回滚后游戏日期必须保持不变。")
	print("[Task0059Balance] %s" % result)


func _test_goal_ui() -> void:
	_game_state.new_game()
	var overview := (load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene).instantiate()
	root.add_child(overview)
	await process_frame
	var description: Label = overview.get_node("MarginContainer/RootBox/SummaryPanel/SummaryBox/DescriptionLabel")
	_expect("长期目标：" in description.text, "宗门概览应展示当前长期目标及进度。")
	overview.queue_free()
	await process_frame


func _find_event(events: Array[Dictionary], definition_id: String) -> Dictionary:
	for event in events:
		if str(event.get("definition_id", "")) == definition_id:
			return event
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
