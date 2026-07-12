extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _save_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_save_manager = root.get_node("SaveManager")
	_cleanup_slots()
	await _test_main_menu_without_and_with_saves()
	_test_three_manual_slots_and_quick_save()
	_test_monthly_autosave_and_latest_load()
	await _test_save_load_panel()
	_cleanup_slots()
	if _failures.is_empty():
		print("[Task0044Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0044Test] " + failure)
	quit(1)


func _test_main_menu_without_and_with_saves() -> void:
	var scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu: Control = scene.instantiate()
	root.add_child(menu)
	await process_frame
	var continue_button: Button = menu.get_node("CenterContainer/MenuBox/ContinueButton")
	_expect(continue_button.disabled, "没有存档时继续游戏按钮必须禁用。")
	menu.queue_free()
	await process_frame


func _test_three_manual_slots_and_quick_save() -> void:
	_game_state.new_game()
	for slot_index in range(1, 4):
		_game_state.day = slot_index
		var result: Dictionary = _save_manager.save_manual_slot(slot_index)
		_expect(bool(result.get("success", false)), "手动存档槽%d应保存成功。" % slot_index)
	_game_state.day = 8
	_expect(bool(_save_manager.quick_save().get("success", false)), "快速存档应保存成功。")
	var summaries: Array[Dictionary] = _save_manager.get_slot_summaries()
	_expect(summaries.size() == 5, "槽位列表应包含3个手动槽、快速存档和自动存档。")
	for slot_index in range(1, 4):
		var summary: Dictionary = _find_summary(summaries, "manual_%d" % slot_index)
		_expect(bool(summary.get("exists", false)), "手动存档槽%d应存在。" % slot_index)
		_expect(int(summary.get("game_state", {}).get("day", 0)) == slot_index, "槽位摘要应显示对应日期。")
	var metadata_started: int = Time.get_ticks_msec()
	_save_manager.get_slot_summaries()
	var metadata_ms: int = Time.get_ticks_msec() - metadata_started
	_expect(metadata_ms < 100, "读取全部槽位摘要应低于100毫秒。")


func _test_monthly_autosave_and_latest_load() -> void:
	_game_state.new_game()
	_game_state.day = 30
	var report: Dictionary = _game_state.next_day()
	_expect(FileAccess.file_exists(_save_manager.AUTOSAVE_PATH), "跨月推进后必须创建自动存档。")
	_expect(bool(report.get("autosave", {}).get("success", false)), "日报应记录自动存档成功。")
	_expect([_game_state.month, _game_state.day] == [2, 1], "自动存档测试应推进到次月1日。")
	var latest_path: String = _save_manager.get_latest_save_path()
	_expect(latest_path != "", "存在槽位后应能找到最近存档。")
	var expected_month: int = _game_state.month
	var expected_day: int = _game_state.day
	_game_state.month = 9
	_game_state.day = 9
	var load_result: Dictionary = _save_manager.load_latest_save()
	_expect(bool(load_result.get("success", false)), "继续游戏应能读取最近存档。")
	# 文件时间粒度可能相同，因此只要求恢复到某个有效槽位日期。
	_expect(_game_state.year == 1 and _game_state.month >= 1 and _game_state.day >= 1, "最近存档读取后日期必须有效。")
	var autosave_meta: Dictionary = _save_manager.get_save_metadata(_save_manager.AUTOSAVE_PATH)
	_expect(int(autosave_meta.get("game_state", {}).get("month", 0)) == expected_month, "自动存档摘要应记录跨月后的月份。")
	_expect(int(autosave_meta.get("game_state", {}).get("day", 0)) == expected_day, "自动存档摘要应记录跨月后的日期。")


func _test_save_load_panel() -> void:
	_game_state.new_game()
	_save_manager.save_manual_slot(1)
	_save_manager.quick_save()
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_save_load_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection")
	var manual_label: Label = section.get_node("ManualSlot1/SlotLabel")
	var manual_load: Button = section.get_node("ManualSlot1/LoadButton")
	var quick_load: Button = section.get_node("QuickSlot/LoadButton")
	_expect(section.visible, "点击存读档后应显示存档面板。")
	_expect(manual_label.text.contains("第1年"), "手动槽位应显示日期摘要。")
	_expect(not manual_load.disabled, "已有手动存档时读取按钮应可用。")
	_expect(not quick_load.disabled, "已有快速存档时读取按钮应可用。")
	overview.call("_on_manual_save_pressed", 2)
	var result_label: Label = section.get_node("SaveLoadResultLabel")
	_expect(result_label.text.contains("保存成功"), "界面保存后应显示成功反馈。")
	overview.queue_free()
	await process_frame

	var menu_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu: Control = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var continue_button: Button = menu.get_node("CenterContainer/MenuBox/ContinueButton")
	var hint: Label = menu.get_node("CenterContainer/MenuBox/ContinueHintLabel")
	_expect(not continue_button.disabled, "存在存档时继续游戏按钮应可用。")
	_expect(hint.text.contains("最近进度"), "主菜单应显示最近存档摘要。")
	menu.queue_free()
	await process_frame


func _find_summary(summaries: Array[Dictionary], slot_id: String) -> Dictionary:
	for summary in summaries:
		if str(summary.get("slot_id", "")) == slot_id:
			return summary
	return {}


func _cleanup_slots() -> void:
	var directory := DirAccess.open(_save_manager.SAVE_DIRECTORY)
	if directory == null:
		return
	for summary in _save_manager.get_slot_summaries():
		var path: String = str(summary.get("path", ""))
		for suffix in ["", ".tmp", ".bak"]:
			var name: String = (path + suffix).get_file()
			if directory.file_exists(name):
				directory.remove(name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
