extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _disciple_manager: Node
var _ai_manager: Node
var _history_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_disciple_manager = root.get_node("DiscipleManager")
	_ai_manager = root.get_node("AISimulationManager")
	_history_manager = root.get_node("GameHistoryManager")
	_test_strategy_scoring_and_resource_constrained_expansion()
	_test_decline_vassal_and_destruction_states()
	_test_sect_split_preserves_people_and_resources()
	_test_one_year_world_evolution()
	if _failures.is_empty():
		print("[Task0042Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0042Test] " + failure)
	quit(1)


func _test_strategy_scoring_and_resource_constrained_expansion() -> void:
	_game_state.new_game()
	var territory_before: Dictionary = {}
	for sect_id in _ai_manager.get_ai_sect_ids():
		territory_before[sect_id] = float(_world_data_manager.get_sect_by_id(sect_id).get("territory_radius", 0.0))
		var scores: Dictionary = _ai_manager.calculate_strategy_scores(sect_id)
		for goal in ["survival", "development", "military", "diplomacy", "resource_need"]:
			_expect(scores.has(goal), "%s缺少效用评分：%s" % [sect_id, goal])
	var summary: Dictionary = _ai_manager.monthly_update({"year": 1, "month": 1, "day": 30})
	_expect(int(summary.get("sects_updated", 0)) == 9, "战略月度更新应覆盖9个AI宗门。")
	var goals: Dictionary = {}
	var expanded_count: int = 0
	for decision in summary.get("decisions", []):
		var sect_id: String = str(decision.get("sect_id", ""))
		var goal: String = str(decision.get("goal", ""))
		goals[goal] = true
		_expect(goal in ["survival", "development", "military", "diplomacy", "resource_need"], "AI选择了无效目标：" + goal)
		var action: Dictionary = decision.get("strategic_action", {})
		if str(action.get("type", "")) == "expand" and bool(action.get("success", false)):
			expanded_count += 1
			_expect(float(_world_data_manager.get_sect_by_id(sect_id)["territory_radius"]) > float(territory_before[sect_id]), "扩张必须增加实际领地半径。")
	_expect(goals.size() >= 2, "不同性格和资源条件应产生至少两种战略目标。")
	_expect(expanded_count >= 1, "资源充足的AI宗门应能执行受成本约束的扩张。")


func _test_decline_vassal_and_destruction_states() -> void:
	_game_state.new_game()
	var declining_state: Dictionary = _world_data_manager.ai_states["sect_002"]
	declining_state["resource_shortage_days"] = 25
	_world_data_manager.ai_states["sect_002"] = declining_state
	var resources: Dictionary = _world_data_manager.get_sect_resources("sect_002")
	_world_data_manager.update_sect_resource("sect_002", "food", -int(resources["food"]))
	_world_data_manager.update_sect_resource("sect_002", "spirit_stone", -int(resources["spirit_stone"]))
	_ai_manager.monthly_update({"year": 1, "month": 1, "day": 30})
	_expect(str(_world_data_manager.ai_states["sect_002"]["current_goal"]) == "survival", "严重短缺时AI应优先选择生存。")
	_expect(str(_world_data_manager.ai_states["sect_002"]["status"]) == "declining", "长期短缺应使宗门进入衰退状态。")

	_expect(_ai_manager.set_vassal("sect_003", "sect_009"), "有效宗门应能建立附属关系。")
	_expect(str(_world_data_manager.ai_states["sect_003"]["status"]) == "vassal", "附属宗门状态应为vassal。")
	_expect(str(_world_data_manager.ai_states["sect_003"]["vassal_of"]) == "sect_009", "附属宗门应保存宗主宗门ID。")

	_expect(_ai_manager.eliminate_sect("sect_007", "测试覆灭"), "AI宗门应支持覆灭。")
	_expect(not bool(_world_data_manager.get_sect_by_id("sect_007").get("is_active", true)), "覆灭宗门应标记为非活跃。")
	var daily: Dictionary = _ai_manager.daily_update({"year": 1, "month": 2, "day": 1})
	_expect(int(daily.get("sects_updated", 0)) == 8, "覆灭宗门不应继续参与每日模拟。")
	_expect(_history_manager.get_entries_by_category("ai_world_change").size() >= 3, "附属、衰退和覆灭应留下世界历史。")


func _test_sect_split_preserves_people_and_resources() -> void:
	_game_state.new_game()
	var parent_id := "sect_010"
	var sect_count_before: int = _world_data_manager.get_all_sects().size()
	var disciple_count_before: int = _world_data_manager.get_disciples_by_sect_id(parent_id).size()
	var resources_before: Dictionary = _world_data_manager.get_sect_resources(parent_id).duplicate(true)
	var result: Dictionary = _ai_manager.split_ai_sect(parent_id)
	_expect(bool(result.get("success", false)), "满足人数条件的AI宗门应可分宗。")
	if not bool(result.get("success", false)):
		return
	var child_id: String = str(result.get("new_sect_id", ""))
	_expect(_world_data_manager.get_all_sects().size() == sect_count_before + 1, "分宗应新增一个真实宗门数据。")
	_expect(child_id in _ai_manager.get_ai_sect_ids(), "分宗应加入AI运行时索引。")
	var parent_count_after: int = _world_data_manager.get_disciples_by_sect_id(parent_id).size()
	var child_count: int = _world_data_manager.get_disciples_by_sect_id(child_id).size()
	_expect(parent_count_after + child_count == disciple_count_before, "分宗前后弟子总数必须守恒。")
	_expect(child_count == int(result.get("transferred_disciples", 0)), "分宗弟子转移数量应与结果一致。")
	for resource_key in resources_before:
		var total_after: int = int(_world_data_manager.get_sect_resources(parent_id)[resource_key]) + int(_world_data_manager.get_sect_resources(child_id)[resource_key])
		_expect(total_after == int(resources_before[resource_key]), "分宗前后资源必须守恒：" + str(resource_key))
	_expect(int(_world_data_manager.get_sect_by_id(child_id).get("combat_power", 0)) > 0, "分宗战力应由转移弟子重新计算。")


func _test_one_year_world_evolution() -> void:
	_game_state.new_game()
	var territory_before: Dictionary = {}
	for sect_id in _ai_manager.get_ai_sect_ids():
		territory_before[sect_id] = float(_world_data_manager.get_sect_by_id(sect_id).get("territory_radius", 0.0))
	var max_duration_ms: int = 0
	for _day in range(360):
		var report: Dictionary = _game_state.next_day()
		max_duration_ms = maxi(max_duration_ms, int(report.get("ai_summary", {}).get("duration_ms", 0)))
	var statuses: Dictionary = {}
	var goals: Dictionary = {}
	var territory_changed: bool = false
	for sect_id in _ai_manager.get_ai_sect_ids():
		var state: Dictionary = _world_data_manager.ai_states[sect_id]
		statuses[str(state.get("status", ""))] = true
		goals[str(state.get("current_goal", ""))] = true
		territory_changed = territory_changed or float(_world_data_manager.get_sect_by_id(sect_id).get("territory_radius", 0.0)) != float(territory_before[sect_id])
		for value in _world_data_manager.get_sect_resources(sect_id).values():
			_expect(int(value) >= 0, "%s一年模拟后资源不得为负。" % sect_id)
	_expect(max_duration_ms < 500, "一年模拟中任何完整AI推进都应低于500毫秒，最慢%d毫秒。" % max_duration_ms)
	_expect(territory_changed, "一年模拟后至少一个AI宗门的领地应发生变化。")
	_expect(goals.size() >= 2, "一年模拟后AI宗门应保留多样化目标。")
	_expect(statuses.keys().all(func(status: String) -> bool: return status in ["active", "rising", "declining", "vassal", "destroyed"]), "AI世界出现无效状态。")
	print("[Task0042Perf] 360_days_max=%d ms statuses=%s goals=%s" % [max_duration_ms, statuses.keys(), goals.keys()])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
