extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data: Node
var _tutorial: Node
var _breakthrough: Node
var _construction: Node
var _mission: Node
var _save: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data = root.get_node("WorldDataManager")
	_tutorial = root.get_node("TutorialManager")
	_breakthrough = root.get_node("BreakthroughManager")
	_construction = root.get_node("ConstructionManager")
	_mission = root.get_node("MissionManager")
	_save = root.get_node("SaveManager")
	_test_global_theme()
	_test_tutorial_progress_and_persistence()
	await _test_tutorial_ui()
	if _failures.is_empty():
		print("[Task0060Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0060Test] " + failure)
	quit(1)


func _test_global_theme() -> void:
	var theme_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	var theme: Theme = load(theme_path) as Theme
	_expect(theme_path == "res://assets/ui/wanzong_theme.tres" and theme != null, "项目必须注册可加载的正式全局主题。")
	_expect(theme.has_stylebox("normal", "Button") and theme.has_stylebox("panel", "PanelContainer"), "正式主题应统一按钮与面板样式。")


func _test_tutorial_progress_and_persistence() -> void:
	_game_state.new_game()
	_tutorial.rebuild_runtime_state()
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "assignment", "新游戏教程应从弟子分工开始。")
	_expect(_world_data.update_disciple_data("disciple_001", "assignment", "采集"), "测试弟子安排应更新成功。")
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "advance", "完成分工后应提示推进日期。")
	_game_state.next_day()
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "breakthrough", "推进日期后应提示弟子突破。")
	_breakthrough.breakthrough_completed.emit({"attempted": true, "success": false, "disciple_id": "disciple_001"})
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "building", "完成首次突破尝试后应提示建设。")
	_construction.construction_started.emit({"sect_id": "sect_001", "definition_id": "spirit_field"})
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "exploration", "建筑开工后应提示秘境探索。")
	_mission.mission_started.emit({"sect_id": "sect_001", "definition_id": "mission_secret_realm"})
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "complete", "五项基础操作完成后教程应结束。")
	var snapshot: Dictionary = _save.create_snapshot()
	_tutorial.reset_tutorial()
	_expect(_save.apply_snapshot(snapshot), "教程进度应可随完整存档恢复。")
	_expect(str(_tutorial.get_current_prompt().get("id", "")) == "complete", "读档后已完成的教程不得重置。")


func _test_tutorial_ui() -> void:
	_game_state.new_game()
	var overview := (load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene).instantiate()
	root.add_child(overview)
	await process_frame
	var overlay: PanelContainer = overview.get_node("TutorialOverlay")
	var tutorial_button: Button = overview.get_node("MarginContainer/RootBox/TopBar/TutorialButton")
	_expect(overlay.visible and "1/5" in str(overlay.get_node("Content/ProgressLabel").text), "宗门页应显示首步教程提示。")
	_tutorial.dismiss()
	_expect(not overlay.visible, "教程应可暂时隐藏。")
	tutorial_button.emit_signal("pressed")
	_expect(overlay.visible, "隐藏后应可通过教程按钮重新打开。")
	overview.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
