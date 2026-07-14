extends SceneTree

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save: Node = root.get_node("SaveManager")
	var game_state: Node = root.get_node("GameState")
	_cleanup_saves(save)
	game_state.call("new_game")
	var manual_path: String = save.get_manual_slot_path(1)
	_expect(bool(save.save_to_path(manual_path).get("success", false)), "较早手动存档应创建成功。")
	await create_timer(0.02).timeout
	_expect(bool(save.autosave().get("success", false)), "较新自动存档应创建成功。")
	var autosave_path: String = save.AUTOSAVE_PATH
	var corrupted := FileAccess.open(autosave_path, FileAccess.WRITE)
	corrupted.store_string("corrupted autosave")
	corrupted.close()
	var date_before: Array[int] = [int(game_state.get("year")), int(game_state.get("month")), int(game_state.get("day"))]
	var info: Dictionary = save.get_latest_valid_save_info()
	_expect(str(info.get("path", "")) == manual_path, "损坏的最新自动存档应回退到较早手动存档。")
	_expect([int(game_state.get("year")), int(game_state.get("month")), int(game_state.get("day"))] == date_before, "只读有效性检查不得污染当前游戏状态。")
	var loaded: Dictionary = save.load_latest_save()
	_expect(bool(loaded.get("success", false)), "继续游戏应成功读取回退的有效存档。")
	_expect(str(loaded.get("path", "")) == manual_path, "继续游戏必须读取较早有效存档。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manual_path))
	var json_file := FileAccess.open(manual_path, FileAccess.WRITE)
	json_file.store_string(JSON.stringify(save.create_snapshot()))
	json_file.close()
	_expect(bool(save.inspect_save_path(manual_path).get("valid", false)), "早期 JSON 存档应继续兼容。")
	var future: Dictionary = save.create_snapshot()
	future["save_version"] = 999
	var future_path: String = save.get_manual_slot_path(2)
	var future_file := FileAccess.open(future_path, FileAccess.WRITE)
	future_file.store_string(JSON.stringify(future))
	future_file.close()
	_expect(not bool(save.inspect_save_path(future_path).get("valid", true)), "未来版本存档必须被拒绝。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manual_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(future_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(autosave_path))
	_expect(str(save.get_latest_save_path()) == "", "没有有效存档时不应返回继续路径。")
	_cleanup_saves(save)
	if _failures.is_empty():
		print("[Task0063SaveFallback] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0063SaveFallback] " + failure)
	quit(1)


func _cleanup_saves(save: Node) -> void:
	for path in [save.get_manual_slot_path(1), save.get_manual_slot_path(2), save.get_manual_slot_path(3), save.QUICK_SAVE_PATH, save.AUTOSAVE_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
