extends SceneTree

const TEST_SAVE_PATH := "user://saves/task_0043_complete_test.save"
const CORRUPT_SAVE_PATH := "user://saves/task_0043_corrupt_test.save"

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _disciple_manager: Node
var _event_manager: Node
var _save_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_disciple_manager = root.get_node("DiscipleManager")
	_event_manager = root.get_node("EventManager")
	_save_manager = root.get_node("SaveManager")
	_cleanup_test_files()
	_test_in_memory_complete_restore_and_rng()
	_test_atomic_file_round_trip_and_performance()
	_test_version_migration_and_validation()
	_test_corrupt_file_does_not_load()
	_cleanup_test_files()
	if _failures.is_empty():
		print("[Task0043Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0043Test] " + failure)
	quit(1)


func _test_in_memory_complete_restore_and_rng() -> void:
	_prepare_evolved_world()
	var snapshot: Dictionary = _save_manager.create_snapshot()
	_expect(int(snapshot.get("save_version", 0)) == _save_manager.CURRENT_SAVE_VERSION, "存档必须包含当前save_version。")
	_expect(_save_manager.validate_snapshot(snapshot) == "", "完整快照应通过校验。")
	_expect(not _contains_object(snapshot), "完整快照不得包含Node、Resource或Callable。")
	var expected_next_random: int = _game_state.random_int(1, 1000000)
	var expected_date: Array[int] = [_game_state.year, _game_state.month, _game_state.day]
	var expected_sect_count: int = _world_data_manager.get_all_sects().size()
	var expected_disciple_count: int = _world_data_manager.get_all_disciples().size()
	var expected_stones: int = int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"])
	var expected_location: Vector2 = Vector2(_world_data_manager.get_sect_by_id("sect_002")["location"])
	var expected_pending: int = _event_manager.get_pending_events().size()
	var expected_history: int = _world_data_manager.history_entries.size()
	var expected_ai_state: Dictionary = _world_data_manager.ai_states["sect_002"].duplicate(true)

	_game_state.year = 99
	_game_state.month = 9
	_game_state.day = 9
	_world_data_manager.update_sect_resource("sect_002", "spirit_stone", -expected_stones)
	_world_data_manager.history_entries.clear()
	_world_data_manager.event_instances.clear()
	_world_data_manager.ai_states["sect_002"] = {"status": "corrupted"}
	_expect(_save_manager.apply_snapshot(snapshot), "内存快照应能恢复。")
	_expect([_game_state.year, _game_state.month, _game_state.day] == expected_date, "时间必须完整恢复。")
	_expect(_game_state.random_int(1, 1000000) == expected_next_random, "RNG状态必须恢复到相同随机序列。")
	_expect(_world_data_manager.get_all_sects().size() == expected_sect_count, "所有宗门必须恢复。")
	_expect(_world_data_manager.get_all_disciples().size() == expected_disciple_count, "所有弟子必须恢复。")
	_expect(int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"]) == expected_stones, "AI宗门资源必须恢复。")
	_expect(Vector2(_world_data_manager.get_sect_by_id("sect_002")["location"]) == expected_location, "Vector2世界坐标必须无损恢复。")
	_expect(_event_manager.get_pending_events().size() == expected_pending, "未处理事件必须恢复。")
	_expect(_world_data_manager.history_entries.size() == expected_history, "历史记录必须恢复。")
	_expect(_world_data_manager.ai_states["sect_002"] == expected_ai_state, "AI状态必须恢复。")
	_expect(_world_data_manager.mission_instances.size() == 1, "进行中任务预留数据必须恢复。")
	_expect(_world_data_manager.battle_instances.size() == 1, "战斗预留数据必须恢复。")
	_expect(_world_data_manager.expedition_teams.size() == 1, "队伍预留数据必须恢复。")
	_expect(str(_world_data_manager.ui_state.get("selected_tab", "")) == "history", "必要UI状态必须恢复。")


func _test_atomic_file_round_trip_and_performance() -> void:
	_prepare_evolved_world()
	var expected_day: int = _game_state.day
	var expected_count: int = _world_data_manager.get_all_disciples().size()
	var save_result: Dictionary = _save_manager.save_to_path(TEST_SAVE_PATH)
	_expect(bool(save_result.get("success", false)), "完整世界应成功写入文件。")
	_expect(int(save_result.get("duration_ms", 999999)) < 1000, "存档目标应低于1秒。")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH), "目标存档文件必须存在。")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "成功后不得残留临时文件。")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "成功后不得残留备份文件。")
	var metadata: Dictionary = _save_manager.get_save_metadata(TEST_SAVE_PATH)
	_expect(int(metadata.get("save_version", 0)) == _save_manager.CURRENT_SAVE_VERSION, "无需完整读档即可读取版本元数据。")

	_game_state.day = 29
	_world_data_manager.disciples.clear()
	var load_result: Dictionary = _save_manager.load_from_path(TEST_SAVE_PATH)
	_expect(bool(load_result.get("success", false)), "完整世界应成功从文件恢复。")
	_expect(int(load_result.get("duration_ms", 999999)) < 2000, "读档目标应低于2秒。")
	_expect(_game_state.day == expected_day, "文件读档必须恢复日期。")
	_expect(_world_data_manager.get_all_disciples().size() == expected_count, "文件读档必须恢复全部弟子。")
	print("[Task0043Perf] save=%d ms load=%d ms bytes=%d" % [
		int(save_result.get("duration_ms", 0)),
		int(load_result.get("duration_ms", 0)),
		int(save_result.get("bytes", 0)),
	])


func _test_version_migration_and_validation() -> void:
	_game_state.new_game()
	var legacy: Dictionary = {
		"year": 7,
		"month": 8,
		"day": 9,
		"world_seed": 12345,
		"game_speed": 2.0,
		"player_sect_id": "sect_001",
		"world_data": _world_data_manager.export_world_state(),
	}
	var migration: Dictionary = _save_manager.migrate_snapshot(legacy)
	_expect(bool(migration.get("success", false)), "V0骨架存档应迁移到当前版本。")
	_expect(int(migration.get("snapshot", {}).get("save_version", 0)) == 1, "迁移结果版本应为1。")
	_expect(_save_manager.apply_snapshot(legacy), "apply_snapshot应自动迁移旧版本。")
	_expect([_game_state.year, _game_state.month, _game_state.day] == [7, 8, 9], "迁移后应保留旧日期。")
	var future_result: Dictionary = _save_manager.migrate_snapshot({"save_version": 999})
	_expect(not bool(future_result.get("success", true)), "未来版本存档必须拒绝加载。")
	var invalid: Dictionary = {"save_version": 1, "game_state": {}, "world_data": {}}
	_expect(_save_manager.validate_snapshot(invalid) != "", "缺少完整世界域的存档必须校验失败。")


func _test_corrupt_file_does_not_load() -> void:
	_game_state.new_game()
	var year_before: int = _game_state.year
	var file := FileAccess.open(CORRUPT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("无法创建损坏存档测试文件。")
		return
	file.store_string("{not valid json")
	file.close()
	var result: Dictionary = _save_manager.load_from_path(CORRUPT_SAVE_PATH)
	_expect(not bool(result.get("success", true)), "损坏存档必须返回失败。")
	_expect(_game_state.year == year_before, "损坏存档不得修改当前游戏状态。")


func _prepare_evolved_world() -> void:
	_game_state.new_game()
	for _day in range(35):
		_game_state.next_day()
	var disciple: DiscipleData = _disciple_manager.get_disciple_by_id("disciple_012")
	disciple.realm_id = "mortal"
	disciple.realm = "凡人"
	disciple.cultivation = 50
	disciple.at_bottleneck = true
	_disciple_manager.sync_disciple_state(disciple)
	_event_manager.daily_update({
		"sect_id": "sect_001",
		"date": {"year": _game_state.year, "month": _game_state.month, "day": _game_state.day},
	})
	_world_data_manager.mission_instances.assign([{"mission_id": "mission_001", "status": "running", "remaining_days": 3}])
	_world_data_manager.battle_instances.assign([{"battle_id": "battle_001", "status": "pending"}])
	_world_data_manager.expedition_teams.assign([{"team_id": "team_001", "disciple_ids": ["disciple_001"]}])
	_world_data_manager.game_settings["music_volume"] = 0.75
	_world_data_manager.ui_state = {"selected_tab": "history", "camera_zoom": 0.32}


func _contains_object(value: Variant) -> bool:
	if value is Object or value is Callable:
		return true
	if value is Array:
		for item in value:
			if _contains_object(item):
				return true
	if value is Dictionary:
		for item in value.values():
			if _contains_object(item):
				return true
	return false


func _cleanup_test_files() -> void:
	var directory := DirAccess.open("user://saves")
	if directory == null:
		return
	for path in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak", CORRUPT_SAVE_PATH]:
		var file_name: String = path.get_file()
		if directory.file_exists(file_name):
			directory.remove(file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
