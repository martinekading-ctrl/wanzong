extends Node

signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(path: String, message: String)
signal load_failed(path: String, message: String)

const CURRENT_SAVE_VERSION: int = 1
const MINIMUM_SAVE_VERSION: int = 0
const SAVE_DIRECTORY := "user://saves"
const BINARY_MAGIC := "WZSV"
const MANUAL_SLOT_COUNT: int = 3
const QUICK_SAVE_PATH := SAVE_DIRECTORY + "/quick.save"
const AUTOSAVE_PATH := SAVE_DIRECTORY + "/autosave.save"

var last_skipped_invalid_paths: Array[String] = []


func get_manual_slot_path(slot_index: int) -> String:
	if slot_index < 1 or slot_index > MANUAL_SLOT_COUNT:
		return ""
	return SAVE_DIRECTORY + "/manual_%d.save" % slot_index


func save_manual_slot(slot_index: int) -> Dictionary:
	var path: String = get_manual_slot_path(slot_index)
	if path == "":
		return _save_error(path, "手动存档槽编号无效。")
	return save_to_path(path)


func load_manual_slot(slot_index: int) -> Dictionary:
	var path: String = get_manual_slot_path(slot_index)
	if path == "":
		return _load_error(path, "手动存档槽编号无效。")
	return load_from_path(path)


func quick_save() -> Dictionary:
	return save_to_path(QUICK_SAVE_PATH)


func quick_load() -> Dictionary:
	return load_from_path(QUICK_SAVE_PATH)


func autosave() -> Dictionary:
	return save_to_path(AUTOSAVE_PATH)


func load_autosave() -> Dictionary:
	return load_from_path(AUTOSAVE_PATH)


func get_slot_summaries(validate_contents: bool = false) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_index in range(1, MANUAL_SLOT_COUNT + 1):
		summaries.append(_build_slot_summary("manual_%d" % slot_index, get_manual_slot_path(slot_index), validate_contents))
	summaries.append(_build_slot_summary("quick", QUICK_SAVE_PATH, validate_contents))
	summaries.append(_build_slot_summary("autosave", AUTOSAVE_PATH, validate_contents))
	return summaries


func get_latest_save_path() -> String:
	return str(get_latest_valid_save_info().get("path", ""))


func load_latest_save() -> Dictionary:
	var candidates := _get_valid_save_candidates()
	if candidates.is_empty():
		return _load_error("", "没有可继续的有效存档。")
	for candidate in candidates:
		var path: String = str(candidate["path"])
		var result := load_from_path(path)
		if bool(result.get("success", false)):
			result["skipped_invalid_paths"] = last_skipped_invalid_paths.duplicate()
			return result
		# 文件在检查后又被破坏时，继续尝试下一份候选，不让一次失败终止继续游戏。
		last_skipped_invalid_paths.append(path)
		push_warning("继续游戏已跳过无法读取的存档：" + path)
	return _load_error("", "所有可用存档均无法读取。")


func get_latest_valid_save_info() -> Dictionary:
	var candidates := _get_valid_save_candidates()
	if candidates.is_empty():
		return {"path": "", "skipped_invalid_paths": last_skipped_invalid_paths.duplicate()}
	var latest: Dictionary = candidates[0]
	latest["skipped_invalid_paths"] = last_skipped_invalid_paths.duplicate()
	return latest


func create_snapshot() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"metadata": {
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"project_version": str(ProjectSettings.get_setting("application/config/version", "development")),
		},
		"game_state": {
			"year": GameState.year,
			"month": GameState.month,
			"day": GameState.day,
			"world_seed": str(GameState.world_seed),
			"random_state": str(GameState.world_rng.state),
			"game_speed": GameState.game_speed,
			"player_sect_id": GameState.player_sect.id if GameState.player_sect != null else "",
			"last_daily_report": GameState.last_daily_report.duplicate(true),
		},
		"world_data": WorldDataManager.export_world_state(),
	}


func apply_snapshot(raw_snapshot: Dictionary) -> bool:
	var migration: Dictionary = migrate_snapshot(raw_snapshot)
	if not bool(migration.get("success", false)):
		return false
	var snapshot: Dictionary = migration["snapshot"]
	var validation_error: String = validate_snapshot(snapshot)
	if validation_error != "":
		push_warning("存档校验失败：" + validation_error)
		return false
	var game_state_data: Dictionary = snapshot["game_state"]
	var world_data: Dictionary = snapshot["world_data"]
	var player_sect_id: String = str(game_state_data.get("player_sect_id", "sect_001"))
	var player_exists: bool = false
	for sect_data in world_data.get("sects", []):
		if str(sect_data.get("sect_id", "")) == player_sect_id and bool(sect_data.get("is_player", false)):
			player_exists = true
			break
	if not player_exists:
		push_warning("存档中的玩家宗门无效：" + player_sect_id)
		return false

	# 固定恢复顺序：世界仓库 → Data对象与索引 → GameState → 场景由调用方切换。
	if not WorldDataManager.restore_world_state(world_data):
		return false
	SectManager.reset()
	DiscipleManager.load_from_world_data()
	GameHistoryManager.restore_history(WorldDataManager.history_entries.duplicate(true))
	EventManager.rebuild_runtime_state()
	ConstructionManager.rebuild_runtime_state()
	MissionManager.rebuild_runtime_state()
	SecretRealmManager.rebuild_runtime_state()
	ResourceSiteManager.rebuild_runtime_state()
	TerritoryManager.rebuild_runtime_state()
	DiplomacyManager.rebuild_runtime_state()
	BattleManager.rebuild_runtime_state()
	WarManager.rebuild_runtime_state()
	InventoryManager.rebuild_runtime_state()
	CraftingManager.rebuild_runtime_state()
	MarketManager.rebuild_runtime_state()
	StoryGoalManager.rebuild_runtime_state()
	TutorialManager.rebuild_runtime_state()
	# game_settings 仍会被 WorldDataManager 读取，以兼容旧存档；音量已改由
	# user://settings.cfg 管理，因此读档不能覆盖玩家当前的全局偏好。
	AudioManager.apply_settings()
	GameState.year = int(game_state_data.get("year", 1))
	GameState.month = int(game_state_data.get("month", 1))
	GameState.day = int(game_state_data.get("day", 1))
	GameState.world_seed = str(game_state_data.get("world_seed", "0")).to_int()
	GameState.world_rng.seed = GameState.world_seed
	GameState.world_rng.state = str(game_state_data.get("random_state", str(GameState.world_rng.state))).to_int()
	GameState.game_speed = float(game_state_data.get("game_speed", 1.0))
	GameState.last_daily_report = game_state_data.get("last_daily_report", {}).duplicate(true)
	GameState.player_sect = SectManager.create_sect(player_sect_id)
	AISimulationManager.initialize_from_world_data()
	return GameState.player_sect != null


func save_to_path(path: String) -> Dictionary:
	var started_at: int = Time.get_ticks_msec()
	var snapshot: Dictionary = create_snapshot()
	if _contains_object(snapshot):
		return _save_error(path, "存档包含不可序列化对象。")
	var directory_path: String = path.get_base_dir()
	var absolute_directory: String = ProjectSettings.globalize_path(directory_path)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return _save_error(path, "无法创建存档目录。")
	var temporary_path: String = path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _save_error(path, "无法写入临时存档：%s" % error_string(FileAccess.get_open_error()))
	file.store_buffer(BINARY_MAGIC.to_ascii_buffer())
	file.store_32(CURRENT_SAVE_VERSION)
	file.store_var(_create_file_header(snapshot), false)
	file.store_var(snapshot, false)
	file.flush()
	file.close()
	var replace_error: Error = _atomic_replace(temporary_path, path)
	if replace_error != OK:
		return _save_error(path, "无法原子替换存档：%s" % error_string(replace_error))
	var duration_ms: int = Time.get_ticks_msec() - started_at
	if duration_ms > 3000:
		push_warning("[SavePerf][WARNING] 存档超过3秒：%d ms" % duration_ms)
	save_completed.emit(path)
	return {
		"success": true,
		"path": path,
		"duration_ms": duration_ms,
		"bytes": FileAccess.get_file_as_bytes(path).size(),
	}


func load_from_path(path: String) -> Dictionary:
	var started_at: int = Time.get_ticks_msec()
	if not FileAccess.file_exists(path):
		return _load_error(path, "存档不存在。")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _load_error(path, "无法读取存档：%s" % error_string(FileAccess.get_open_error()))
	var decoded: Variant = _read_snapshot_from_file(file)
	file.close()
	if not (decoded is Dictionary) or not apply_snapshot(decoded):
		return _load_error(path, "存档内容校验或恢复失败。")
	var duration_ms: int = Time.get_ticks_msec() - started_at
	if duration_ms > 5000:
		push_warning("[SavePerf][WARNING] 读档超过5秒：%d ms" % duration_ms)
	load_completed.emit(path)
	return {"success": true, "path": path, "duration_ms": duration_ms, "save_version": int(decoded.get("save_version", 0))}


func validate_snapshot(snapshot: Dictionary) -> String:
	var version: int = int(snapshot.get("save_version", -1))
	if version < MINIMUM_SAVE_VERSION:
		return "缺少有效save_version。"
	if version > CURRENT_SAVE_VERSION:
		return "存档版本高于当前游戏版本。"
	if not (snapshot.get("game_state") is Dictionary):
		return "缺少game_state。"
	if not (snapshot.get("world_data") is Dictionary):
		return "缺少world_data。"
	var world_data: Dictionary = snapshot["world_data"]
	for required_key in ["sects", "disciples", "sect_resources", "event_instances", "history_entries", "ai_states"]:
		if not world_data.has(required_key):
			return "world_data缺少%s。" % required_key
	return ""


func migrate_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	if raw_snapshot.is_empty():
		return {"success": false, "message": "空存档。"}
	var snapshot: Dictionary = raw_snapshot.duplicate(true)
	var version: int = int(snapshot.get("save_version", 0))
	if version > CURRENT_SAVE_VERSION:
		return {"success": false, "message": "不支持未来版本存档。"}
	while version < CURRENT_SAVE_VERSION:
		match version:
			0:
				snapshot = _migrate_v0_to_v1(snapshot)
				version = 1
			_:
				return {"success": false, "message": "缺少版本迁移函数。"}
	snapshot = _migrate_world_map_layout(snapshot)
	snapshot["save_version"] = CURRENT_SAVE_VERSION
	return {"success": true, "snapshot": snapshot}


func get_save_metadata(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() >= 8 and file.get_buffer(4).get_string_from_ascii() == BINARY_MAGIC:
		file.get_32()
		var first_value: Variant = file.get_var(false)
		file.close()
		if first_value is Dictionary and bool(first_value.get("header_format", false)):
			return {
				"save_version": int(first_value.get("save_version", 0)),
				"metadata": first_value.get("metadata", {}),
				"game_state": first_value.get("game_state", {}),
			}
		if first_value is Dictionary:
			return {
				"save_version": int(first_value.get("save_version", 0)),
				"metadata": first_value.get("metadata", {}),
				"game_state": first_value.get("game_state", {}),
			}
		return {}
	file.seek(0)
	var decoded: Variant = _read_snapshot_from_file(file)
	file.close()
	if not (decoded is Dictionary):
		return {}
	return {
		"save_version": int(decoded.get("save_version", 0)),
		"metadata": decoded.get("metadata", {}),
		"game_state": decoded.get("game_state", {}),
	}


## 只读验证：不调用 apply_snapshot，不会污染当前游戏状态。
func inspect_save_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false, "path": path, "message": "存档不存在。"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"valid": false, "path": path, "message": "无法读取存档。"}
	var decoded: Variant = _read_snapshot_from_file(file)
	file.close()
	if not (decoded is Dictionary):
		return {"valid": false, "path": path, "message": "存档格式无效或已损坏。"}
	var migration: Dictionary = migrate_snapshot(decoded)
	if not bool(migration.get("success", false)):
		return {"valid": false, "path": path, "message": str(migration.get("message", "存档版本无效。"))}
	var validation_error: String = validate_snapshot(migration["snapshot"])
	if validation_error != "":
		return {"valid": false, "path": path, "message": validation_error}
	return {
		"valid": true,
		"path": path,
		"metadata": get_save_metadata(path),
		"modified_time": FileAccess.get_modified_time(path),
	}


func _create_file_header(snapshot: Dictionary) -> Dictionary:
	var state: Dictionary = snapshot.get("game_state", {})
	return {
		"header_format": true,
		"save_version": int(snapshot.get("save_version", CURRENT_SAVE_VERSION)),
		"metadata": snapshot.get("metadata", {}).duplicate(true),
		"game_state": {
			"year": int(state.get("year", 1)),
			"month": int(state.get("month", 1)),
			"day": int(state.get("day", 1)),
			"player_sect_id": str(state.get("player_sect_id", "sect_001")),
		},
	}


func _build_slot_summary(slot_id: String, path: String, validate_contents: bool = false) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	var inspection: Dictionary = inspect_save_path(path) if exists and validate_contents else {}
	var metadata: Dictionary = inspection.get("metadata", {}) if validate_contents else get_save_metadata(path) if exists else {}
	return {
		"slot_id": slot_id,
		"path": path,
		"exists": exists,
		"modified_time": FileAccess.get_modified_time(path) if exists else 0,
		"metadata": metadata.get("metadata", {}),
		"game_state": metadata.get("game_state", {}),
		"valid": bool(inspection.get("valid", false)) if validate_contents else exists,
		"validation_message": str(inspection.get("message", "")),
	}


func _get_valid_save_candidates() -> Array[Dictionary]:
	last_skipped_invalid_paths.clear()
	var candidates: Array[Dictionary] = []
	for summary in get_slot_summaries(true):
		if not bool(summary.get("exists", false)):
			continue
		if not bool(summary.get("valid", false)):
			var invalid_path: String = str(summary.get("path", ""))
			last_skipped_invalid_paths.append(invalid_path)
			push_warning("继续游戏已跳过损坏或不兼容的存档：" + invalid_path)
			continue
		candidates.append(summary)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("modified_time", 0)) > int(right.get("modified_time", 0))
	)
	return candidates


func _read_snapshot_from_file(file: FileAccess) -> Variant:
	if file.get_length() < 4:
		return null
	var magic: String = file.get_buffer(4).get_string_from_ascii()
	if magic == BINARY_MAGIC:
		if file.get_length() < 8:
			return null
		var header_version: int = file.get_32()
		if header_version > CURRENT_SAVE_VERSION:
			return null
		var first_value: Variant = file.get_var(false)
		if first_value is Dictionary and bool(first_value.get("header_format", false)):
			return file.get_var(false)
		return first_value
	# 兼容早期可能存在的JSON原型存档。
	file.seek(0)
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return _decode_json_value(parser.data)


func _migrate_v0_to_v1(old_snapshot: Dictionary) -> Dictionary:
	var game_state_data: Dictionary = old_snapshot.get("game_state", {})
	if game_state_data.is_empty():
		game_state_data = {
			"year": int(old_snapshot.get("year", 1)),
			"month": int(old_snapshot.get("month", 1)),
			"day": int(old_snapshot.get("day", 1)),
			"world_seed": str(old_snapshot.get("world_seed", 0)),
			"random_state": str(GameState.world_rng.state),
			"game_speed": float(old_snapshot.get("game_speed", 1.0)),
			"player_sect_id": str(old_snapshot.get("player_sect_id", "sect_001")),
			"last_daily_report": {},
		}
	return {
		"save_version": 1,
		"metadata": old_snapshot.get("metadata", {"migrated_from": 0}),
		"game_state": game_state_data,
		"world_data": old_snapshot.get("world_data", WorldDataManager.export_world_state()),
	}


## 地图布局版本独立于存档格式版本。仅迁移明确的世界坐标字段，
## 不会递归缩放任意 Vector2，避免污染战斗或 UI 等非地图数据。
func _migrate_world_map_layout(snapshot: Dictionary) -> Dictionary:
	var migrated: Dictionary = snapshot.duplicate(true)
	var world_data: Dictionary = migrated.get("world_data", {})
	if world_data.is_empty():
		return migrated
	var layout_version: int = int(world_data.get("world_map_layout_version", WorldMapSpec.OLD_MAP_LAYOUT_VERSION))
	if layout_version >= WorldMapSpec.MAP_LAYOUT_VERSION:
		return migrated
	world_data["sects"] = _migrate_position_array(world_data.get("sects", []), ["location", "position"])
	world_data["resources"] = _migrate_position_array(world_data.get("resources", []), ["position"])
	world_data["build_slots"] = _migrate_position_array(world_data.get("build_slots", []), ["position"])
	world_data["war_campaigns"] = _migrate_position_array(world_data.get("war_campaigns", []), ["target_position"])
	world_data["territory_states"] = _migrate_territory_state_positions(world_data.get("territory_states", {}))
	world_data["world_map_layout_version"] = WorldMapSpec.MAP_LAYOUT_VERSION
	migrated["world_data"] = world_data
	return migrated


func _migrate_position_array(raw_values: Variant, position_keys: Array[String]) -> Array:
	var migrated_values: Array = []
	for raw_value in raw_values as Array:
		var value: Dictionary = (raw_value as Dictionary).duplicate(true)
		for key in position_keys:
			if value.get(key) is Vector2:
				value[key] = _migrate_world_position(value[key] as Vector2)
		migrated_values.append(value)
	return migrated_values


func _migrate_territory_state_positions(raw_states: Variant) -> Dictionary:
	var migrated_states: Dictionary = (raw_states as Dictionary).duplicate(true)
	for sect_id in migrated_states:
		var state: Dictionary = (migrated_states[sect_id] as Dictionary).duplicate(true)
		if state.get("center") is Vector2:
			state["center"] = _migrate_world_position(state["center"] as Vector2)
		for key in ["control_positions", "boundary_points"]:
			var updated: Array = []
			for position in state.get(key, []):
				updated.append(_migrate_world_position(position as Vector2) if position is Vector2 else position)
			state[key] = updated
		migrated_states[sect_id] = state
	return migrated_states


func _migrate_world_position(position: Vector2) -> Vector2:
	# Task-0064 及更早版本的 world_data 统一使用 4096 逻辑坐标。
	# 一份旧存档只能使用这一种比例，禁止按单个坐标值猜测来源。
	return WorldMapSpec.compact_from_legacy_source_position(position)


func _atomic_replace(temporary_path: String, target_path: String) -> Error:
	var directory_path: String = target_path.get_base_dir()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return ERR_CANT_OPEN
	var target_name: String = target_path.get_file()
	var temporary_name: String = temporary_path.get_file()
	var backup_name: String = target_name + ".bak"
	if directory.file_exists(backup_name):
		directory.remove(backup_name)
	var had_existing: bool = directory.file_exists(target_name)
	if had_existing:
		var backup_error: Error = directory.rename(target_name, backup_name)
		if backup_error != OK:
			return backup_error
	var replace_error: Error = directory.rename(temporary_name, target_name)
	if replace_error != OK:
		if had_existing:
			directory.rename(backup_name, target_name)
		return replace_error
	if had_existing and directory.file_exists(backup_name):
		directory.remove(backup_name)
	return OK


func _decode_json_value(value: Variant) -> Variant:
	if value is Array:
		var decoded_array: Array = []
		for item in value:
			decoded_array.append(_decode_json_value(item))
		return decoded_array
	if value is Dictionary:
		if str(value.get("__variant_type", "")) == "Vector2":
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		var decoded_dictionary: Dictionary = {}
		for key in value:
			decoded_dictionary[key] = _decode_json_value(value[key])
		return decoded_dictionary
	return value
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


func _save_error(path: String, message: String) -> Dictionary:
	push_warning(message)
	save_failed.emit(path, message)
	return {"success": false, "path": path, "message": message}


func _load_error(path: String, message: String) -> Dictionary:
	push_warning(message)
	load_failed.emit(path, message)
	return {"success": false, "path": path, "message": message}
