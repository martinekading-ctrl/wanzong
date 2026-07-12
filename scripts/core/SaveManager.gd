extends Node

signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(path: String, message: String)
signal load_failed(path: String, message: String)

const CURRENT_SAVE_VERSION: int = 1
const MINIMUM_SAVE_VERSION: int = 0
const SAVE_DIRECTORY := "user://saves"
const BINARY_MAGIC := "WZSV"


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
	snapshot["save_version"] = CURRENT_SAVE_VERSION
	return {"success": true, "snapshot": snapshot}


func get_save_metadata(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var decoded: Variant = _read_snapshot_from_file(file)
	file.close()
	if not (decoded is Dictionary):
		return {}
	return {
		"save_version": int(decoded.get("save_version", 0)),
		"metadata": decoded.get("metadata", {}),
		"game_state": decoded.get("game_state", {}),
	}


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
		return file.get_var(false)
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
