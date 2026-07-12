extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _battle_manager: Node
var _world_data_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_battle_manager = root.get_node("BattleManager")
	_world_data_manager = root.get_node("WorldDataManager")
	await _test_empty_and_sparring_report()
	await _test_report_navigation_and_entry()
	if _failures.is_empty():
		print("[Task0054Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0054Test] " + failure)
	quit(1)


func _test_empty_and_sparring_report() -> void:
	_game_state.new_game()
	var packed := load("res://scenes/battle/BattleReport.tscn") as PackedScene
	_expect(packed != null, "战报场景必须可加载。")
	var report: Control = packed.instantiate()
	root.add_child(report)
	await process_frame
	var target_option: OptionButton = report.get_node("Margin/RootBox/ControlBar/TargetOption")
	var summary: Label = report.get_node("Margin/RootBox/SummaryLabel")
	var log_label: Label = report.get_node("Margin/RootBox/LogPanel/LogScroll/LogLabel")
	_expect(target_option.item_count == 9, "切磋目标应包含九个AI宗门。")
	_expect(summary.text.contains("暂无战报"), "没有战斗时应显示明确空状态。")
	report.call("_on_spar_pressed")
	await process_frame
	_expect(_battle_manager.get_all_battles().size() == 1, "模拟切磋应创建真实战斗实例。")
	_expect(summary.text.contains("胜者：") and summary.text.contains("回合："), "战报摘要应显示胜者与回合数。")
	_expect(log_label.text.contains("战斗开始") and log_label.text.contains("战斗结束"), "战报滚动区应展示完整文本战斗流程。")
	var attacker_list: VBoxContainer = report.get_node("Margin/RootBox/TeamBox/AttackerPanel/AttackerList")
	var defender_list: VBoxContainer = report.get_node("Margin/RootBox/TeamBox/DefenderPanel/DefenderList")
	_expect(attacker_list.get_child_count() == 4 and defender_list.get_child_count() == 4, "双方列表应显示标题和三名参战弟子。")
	_expect(_battle_manager.get_all_battles()[0].get("result", {}).get("loot", {}).is_empty(), "切磋模式不得产生战利品。")
	report.queue_free()
	await process_frame


func _test_report_navigation_and_entry() -> void:
	_game_state.new_game()
	var ai_ids: Array[String] = []
	for disciple in _world_data_manager.get_disciples_by_sect_id("sect_002").slice(0, 2):
		ai_ids.append(str(disciple.get("disciple_id", "")))
	_battle_manager.create_and_simulate("sect_001", ["disciple_001", "disciple_002"], "sect_002", ai_ids, {"seed": 11, "battle_type": "sparring"})
	_battle_manager.create_and_simulate("sect_001", ["disciple_003", "disciple_004"], "sect_002", ai_ids, {"seed": 22, "battle_type": "sparring"})
	var report: Control = (load("res://scenes/battle/BattleReport.tscn") as PackedScene).instantiate()
	root.add_child(report)
	await process_frame
	var summary: Label = report.get_node("Margin/RootBox/SummaryLabel")
	var previous: Button = report.get_node("Margin/RootBox/ControlBar/PreviousButton")
	var next: Button = report.get_node("Margin/RootBox/ControlBar/NextButton")
	_expect(summary.text.contains("battle_00002"), "进入战报页应默认显示最新战报。")
	_expect(not previous.disabled and next.disabled, "最新战报应可向前翻阅。")
	report.call("_on_previous_pressed")
	_expect(summary.text.contains("battle_00001"), "上一份按钮应切换至前一战报。")
	_expect(previous.disabled and not next.disabled, "最早战报应只允许向后翻阅。")
	var overview: Control = (load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene).instantiate()
	root.add_child(overview)
	await process_frame
	var battle_button: Button = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/BattleButton")
	_expect(battle_button.text == "战报", "宗门详情应提供战报入口。")
	_expect(str(root.get_node("SceneManager").BATTLE_REPORT_SCENE) == "res://scenes/battle/BattleReport.tscn", "SceneManager应注册战报场景。")
	overview.queue_free()
	report.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
