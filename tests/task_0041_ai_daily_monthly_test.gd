extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _disciple_manager: Node
var _ai_manager: Node
var _initialization_ms: int = 0
var _first_daily_ms: int = 0
var _monthly_max_daily_ms: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_disciple_manager = root.get_node("DiscipleManager")
	_ai_manager = root.get_node("AISimulationManager")
	_test_ai_data_matches_world_counts()
	_test_daily_simulation_uses_shared_rules()
	_test_monthly_operations_and_persistence()
	print("[Task0041Perf] initialization=%d ms first_day=%d ms monthly_max_day=%d ms" % [
		_initialization_ms,
		_first_daily_ms,
		_monthly_max_daily_ms,
	])
	if _failures.is_empty():
		print("[Task0041Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0041Test] " + failure)
	quit(1)


func _test_ai_data_matches_world_counts() -> void:
	var started_at: int = Time.get_ticks_msec()
	_game_state.new_game()
	_initialization_ms = Time.get_ticks_msec() - started_at
	var ai_sects: Array = _world_data_manager.get_ai_sects()
	_expect(ai_sects.size() == 9, "世界必须包含9个AI宗门。")
	_expect(_ai_manager.get_ai_sect_ids().size() == 9, "AI管理器必须索引9个宗门。")
	_expect(_world_data_manager.ai_states.size() == 9, "每个AI宗门必须拥有独立AI状态。")
	for sect in ai_sects:
		var sect_id: String = str(sect["sect_id"])
		var actual_count: int = _world_data_manager.get_disciples_by_sect_id(sect_id).size()
		_expect(actual_count == int(sect["disciple_count"]), "%s真实弟子数量必须与宗门统计一致。" % sect_id)
		_expect(actual_count > 0, "%s必须拥有真实弟子数据。" % sect_id)
		var state: Dictionary = _world_data_manager.ai_states.get(sect_id, {})
		_expect(not state.is_empty() and str(state.get("personality", "")) != "", "%s缺少AI性格。" % sect_id)
	_expect(_initialization_ms < 1000, "完整AI世界初始化应低于1秒，实际%d毫秒。" % _initialization_ms)


func _test_daily_simulation_uses_shared_rules() -> void:
	_game_state.new_game()
	var sect_id := "sect_002"
	var resources_before: Dictionary = _world_data_manager.get_sect_resources(sect_id).duplicate(true)
	var disciple: DiscipleData
	for candidate in _disciple_manager.get_disciples_by_sect_id(sect_id):
		if candidate.assignment == _disciple_manager.ASSIGNMENT_CULTIVATE:
			disciple = candidate
			break
	_expect(disciple != null, "AI宗门初始应包含修炼弟子。")
	if disciple == null:
		return
	var cultivation_before: int = disciple.cultivation
	var report: Dictionary = _game_state.next_day()
	var ai_summary: Dictionary = report.get("ai_summary", {})
	_first_daily_ms = int(ai_summary.get("duration_ms", 0))
	_expect(int(ai_summary.get("sects_updated", 0)) == 9, "每日推进必须更新全部9个活跃AI宗门。")
	_expect(int(ai_summary.get("disciples_updated", 0)) > 1000, "每日推进必须覆盖全部AI弟子。")
	_expect(int(ai_summary.get("duration_ms", 999999)) < 500, "完整AI世界单日推进目标应低于500毫秒。")
	var resources_after: Dictionary = _world_data_manager.get_sect_resources(sect_id)
	_expect(resources_after != resources_before, "AI宗门资源应通过共享经济规则发生变化。")
	var updated_state: Dictionary = _world_data_manager.ai_states[sect_id]
	_expect(int(updated_state.get("last_update_date", {}).get("day", 0)) == 1, "AI状态应记录最近更新日期。")
	_expect(disciple.cultivation >= cultivation_before, "AI修炼弟子应使用共享修炼规则。")
	for resource_key in ["spirit_stone", "food", "wood", "stone", "spirit_grass", "spirit_ore"]:
		_expect(int(resources_after.get(resource_key, 0)) >= 0, "AI资源不得出现负数：" + resource_key)


func _test_monthly_operations_and_persistence() -> void:
	_game_state.new_game()
	var counts_before: Dictionary = {}
	for sect_id in _ai_manager.get_ai_sect_ids():
		counts_before[sect_id] = _world_data_manager.get_disciples_by_sect_id(sect_id).size()
	var final_report: Dictionary = {}
	for _day in range(30):
		final_report = _game_state.next_day()
		_monthly_max_daily_ms = maxi(
			_monthly_max_daily_ms,
			int(final_report.get("ai_summary", {}).get("duration_ms", 0))
		)
	var monthly: Dictionary = final_report.get("ai_summary", {}).get("monthly", {})
	_expect(_monthly_max_daily_ms < 500, "包含月度决策的完整AI推进也应低于500毫秒。")
	_expect(int(monthly.get("sects_updated", 0)) == 9, "每月末必须更新9个AI宗门的运营决策。")
	for sect_id in _ai_manager.get_ai_sect_ids():
		var state: Dictionary = _world_data_manager.ai_states[sect_id]
		_expect(int(state.get("monthly_cycle_count", 0)) == 1, "%s月度周期计数应增加。" % sect_id)
		_expect(int(state.get("development_points", 0)) == 1, "%s应积累发展点。" % sect_id)
		var count_after: int = _world_data_manager.get_disciples_by_sect_id(sect_id).size()
		_expect(count_after >= int(counts_before[sect_id]), "%s月度运营不得无故丢失弟子。" % sect_id)
		var resources: Dictionary = _world_data_manager.get_sect_resources(sect_id)
		for value in resources.values():
			_expect(int(value) >= 0, "%s月度后资源不得为负数。" % sect_id)
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("ai_monthly_summary").size() == 1, "AI月度演化应写入历史。")

	var state_snapshot: Dictionary = _world_data_manager.ai_states["sect_002"].duplicate(true)
	_ai_manager.initialize_from_world_data()
	_expect(_world_data_manager.ai_states["sect_002"] == state_snapshot, "重新建立AI运行时索引不得重置AI状态。")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
