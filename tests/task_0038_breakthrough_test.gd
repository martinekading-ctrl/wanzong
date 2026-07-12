extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _disciple_manager: Node
var _world_data_manager: Node
var _breakthrough_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_disciple_manager = root.get_node("DiscipleManager")
	_world_data_manager = root.get_node("WorldDataManager")
	_breakthrough_manager = root.get_node("BreakthroughManager")
	_test_rejections_do_not_charge_resources()
	_test_success_updates_state_and_history()
	_test_failure_has_nonlethal_consequences()
	await _test_breakthrough_ui()
	if _failures.is_empty():
		print("[Task0038Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0038Test] " + failure)
	quit(1)


func _test_rejections_do_not_charge_resources() -> void:
	var disciple: DiscipleData = _prepare_mortal_disciple(false)
	var stones_before: int = _get_spirit_stones()
	var no_bottleneck: Dictionary = _breakthrough_manager.attempt_breakthrough(disciple.id)
	_expect(str(no_bottleneck.get("code", "")) == "not_at_bottleneck", "非瓶颈弟子应被拒绝。")
	_expect(_get_spirit_stones() == stones_before, "前置检查失败不应扣除资源。")

	disciple = _prepare_mortal_disciple(true)
	disciple.health = 20
	_disciple_manager.sync_disciple_state(disciple)
	var low_health: Dictionary = _breakthrough_manager.attempt_breakthrough(disciple.id)
	_expect(str(low_health.get("code", "")) == "health_too_low", "健康不足应被拒绝。")

	disciple = _prepare_mortal_disciple(true)
	_world_data_manager.update_sect_resource("sect_001", "spirit_stone", -_get_spirit_stones())
	var no_resource: Dictionary = _breakthrough_manager.attempt_breakthrough(disciple.id)
	_expect(str(no_resource.get("code", "")) == "resources_insufficient", "资源不足应被拒绝。")
	_expect(_get_spirit_stones() == 0, "资源不足检查不得产生负库存。")

	disciple = _prepare_mortal_disciple(true)
	disciple.realm_id = "foundation_perfect"
	disciple.realm = "筑基圆满"
	disciple.cultivation = 1200
	disciple.at_bottleneck = true
	_disciple_manager.sync_disciple_state(disciple)
	var highest: Dictionary = _breakthrough_manager.attempt_breakthrough(disciple.id)
	_expect(str(highest.get("code", "")) == "no_next_realm", "最高境界应禁止继续突破。")


func _test_success_updates_state_and_history() -> void:
	var disciple: DiscipleData = _prepare_mortal_disciple(true)
	var stones_before: int = _get_spirit_stones()
	var combat_before: int = disciple.combat_power
	var max_hp_before: int = int(_world_data_manager.get_disciple_by_id(disciple.id).get("max_hp", 100))
	var result: Dictionary = _breakthrough_manager.attempt_breakthrough(
		disciple.id,
		{"_test_roll": 0.0}
	)
	_expect(bool(result.get("attempted", false)), "成功测试必须实际发起突破。")
	_expect(bool(result.get("success", false)), "强制低判定值时应突破成功。")
	_expect(disciple.realm_id == "qi_01" and disciple.realm == "炼气一层", "成功后应进入炼气一层。")
	_expect(disciple.cultivation == 0 and not disciple.at_bottleneck, "成功后修为归零并解除瓶颈。")
	_expect(disciple.combat_power > combat_before, "成功后战力应提高。")
	_expect(int(_world_data_manager.get_disciple_by_id(disciple.id).get("max_hp", 0)) > max_hp_before, "成功后生命上限应按境界倍率提高。")
	_expect(_get_spirit_stones() == stones_before - 10, "凡人突破应扣除10灵石。")
	_expect(disciple.breakthrough_history.size() == 1, "成功结果应写入弟子突破历史。")
	_expect(result.has("history_entry"), "结构化结果应包含历史条目。")

	_disciple_manager.load_from_world_data()
	var reloaded: DiscipleData = _disciple_manager.get_disciple_by_id(disciple.id)
	_expect(reloaded != null and reloaded.realm_id == "qi_01", "重新加载后境界应保留。")
	_expect(reloaded != null and reloaded.breakthrough_history.size() == 1, "重新加载后突破历史应保留。")


func _test_failure_has_nonlethal_consequences() -> void:
	var disciple: DiscipleData = _prepare_mortal_disciple(true)
	var stones_before: int = _get_spirit_stones()
	var hp_before: int = int(_world_data_manager.get_disciple_by_id(disciple.id).get("hp", 100))
	var result: Dictionary = _breakthrough_manager.attempt_breakthrough(
		disciple.id,
		{"_test_roll": 1.0}
	)
	_expect(bool(result.get("attempted", false)), "失败测试必须实际发起突破。")
	_expect(not bool(result.get("success", true)), "强制高判定值时应突破失败。")
	_expect(disciple.realm_id == "mortal", "失败后境界不得改变。")
	_expect(disciple.cultivation == 45, "失败后应损失10%的当前境界修为上限。")
	_expect(disciple.health == 90, "失败后应损失10点健康。")
	_expect(disciple.health > 0, "第一版突破失败不得死亡。")
	_expect(int(_world_data_manager.get_disciple_by_id(disciple.id).get("hp", 0)) < hp_before, "失败后生命值应随健康受损。")
	_expect(not disciple.at_bottleneck, "失败损失修为后应退出瓶颈。")
	_expect(_get_spirit_stones() == stones_before - 10, "突破失败也应扣除资源。")
	_expect(disciple.breakthrough_history.size() == 1, "失败结果也应写入历史。")


func _test_breakthrough_ui() -> void:
	var disciple: DiscipleData = _prepare_mortal_disciple(true)
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	_expect(scene != null, "无法加载玩家宗门详情场景。")
	if scene == null:
		return
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_disciple_button_pressed")
	overview.call("_on_disciple_selected", disciple.id)
	await process_frame
	var box: VBoxContainer = overview.get_node(
		"MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BreakthroughBox"
	)
	var preview: Label = box.get_node("BreakthroughPreviewLabel")
	var button: Button = box.get_node("BreakthroughButton")
	_expect(box.visible, "选择弟子后应显示突破区域。")
	_expect(preview.text.contains("下一境界：炼气一层"), "突破预览应显示下一境界。")
	_expect(not button.disabled, "满足条件时发起突破按钮应可用。")
	overview.queue_free()
	await process_frame


func _prepare_mortal_disciple(at_bottleneck: bool) -> DiscipleData:
	_game_state.new_game()
	var disciple: DiscipleData = _disciple_manager.get_disciple_by_id("disciple_012")
	if disciple == null:
		_failures.append("缺少用于测试的disciple_012。")
		return null
	disciple.realm_id = "mortal"
	disciple.realm = "凡人"
	disciple.cultivation = 50 if at_bottleneck else 0
	disciple.at_bottleneck = at_bottleneck
	disciple.health = 100
	disciple.talent = 50
	disciple.potential = 50
	disciple.combat_power = 90
	disciple.breakthrough_history.clear()
	_disciple_manager.sync_disciple_state(disciple)
	return disciple


func _get_spirit_stones() -> int:
	return int(_world_data_manager.get_sect_resources("sect_001").get("spirit_stone", 0))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
