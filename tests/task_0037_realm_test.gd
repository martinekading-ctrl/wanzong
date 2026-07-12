extends SceneTree

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_realm_configuration()
	_test_cultivation_bottleneck_and_persistence()
	await _test_player_sect_overview()
	if _failures.is_empty():
		print("[Task0037Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0037Test] " + failure)
	quit(1)


func _test_realm_configuration() -> void:
	RealmRegistry.reload()
	var definitions: Array[RealmDefinition] = RealmRegistry.get_all()
	_expect(definitions.size() == 14, "境界配置数量应为14，实际为%d。" % definitions.size())
	_expect(RealmRegistry.validate_chain().is_empty(), "境界配置链校验失败。")
	if definitions.is_empty():
		return
	_expect(definitions[0].id == "mortal", "首个境界必须为mortal。")
	_expect(definitions[-1].id == "foundation_perfect", "末境界必须为foundation_perfect。")
	_expect(definitions[-1].next_realm_id == "", "末境界不应存在下一境界。")


func _test_cultivation_bottleneck_and_persistence() -> void:
	var game_state: Node = root.get_node("GameState")
	var disciple_manager: Node = root.get_node("DiscipleManager")
	var world_data_manager: Node = root.get_node("WorldDataManager")
	game_state.new_game()
	for disciple in disciple_manager.disciples:
		disciple_manager.update_assignment(disciple.id, disciple_manager.ASSIGNMENT_IDLE)

	var target: DiscipleData = disciple_manager.get_disciple_by_id("disciple_012")
	_expect(target != null, "缺少用于测试的disciple_012。")
	if target == null:
		return
	target.realm_id = "mortal"
	target.realm = "凡人"
	target.cultivation = 48
	target.at_bottleneck = false
	target.talent = 50
	disciple_manager.update_assignment(target.id, disciple_manager.ASSIGNMENT_CULTIVATE)
	world_data_manager.update_disciple_data(target.id, "realm_id", target.realm_id)
	world_data_manager.update_disciple_data(target.id, "realm", target.realm)
	world_data_manager.update_disciple_data(target.id, "cultivation", target.cultivation)
	world_data_manager.update_disciple_data(target.id, "at_bottleneck", target.at_bottleneck)

	var spirit_stone_before: int = int(world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var first_report: Dictionary = game_state.next_day()
	var first_result: Dictionary = _find_result(first_report, target.id)
	_expect(target.cultivation == 50, "修为应截断在凡人上限50。")
	_expect(target.at_bottleneck, "达到修为上限后应进入瓶颈。")
	_expect(int(first_result.get("cultivation_gain", -1)) == 2, "实际修为增长应为2。")
	_expect(bool(first_result.get("reached_bottleneck", false)), "日报应标记新进入瓶颈。")
	_expect(
		int(world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == spirit_stone_before - 5,
		"首次结算应扣除3维护费和2修炼费。"
	)

	var second_report: Dictionary = game_state.next_day()
	var second_result: Dictionary = _find_result(second_report, target.id)
	_expect(target.cultivation == 50, "瓶颈后修为不得继续累积。")
	_expect(int(second_result.get("cultivation_gain", -1)) == 0, "瓶颈弟子每日修为增长应为0。")
	_expect(
		int(second_report.get("expenses", {}).get("cultivation", {}).get("paid", -1)) == 0,
		"瓶颈弟子不应消耗修炼灵石。"
	)

	disciple_manager.load_from_world_data()
	var reloaded: DiscipleData = disciple_manager.get_disciple_by_id(target.id)
	_expect(reloaded != null and reloaded.cultivation == 50, "重新加载后修为应保留。")
	_expect(reloaded != null and reloaded.at_bottleneck, "重新加载后瓶颈状态应保留。")
	if reloaded == null:
		return

	# 灵石不足时不允许出现负库存，也不能发放修为。
	reloaded.cultivation = 0
	reloaded.at_bottleneck = false
	world_data_manager.update_disciple_data(reloaded.id, "cultivation", 0)
	world_data_manager.update_disciple_data(reloaded.id, "at_bottleneck", false)
	var current_stones: int = int(world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	world_data_manager.update_sect_resource("sect_001", "spirit_stone", -current_stones)
	var shortage_report: Dictionary = game_state.next_day()
	var shortage_result: Dictionary = _find_result(shortage_report, reloaded.id)
	_expect(int(shortage_result.get("cultivation_gain", -1)) == 0, "灵石不足时修为增长应为0。")
	_expect(not bool(shortage_result.get("success", true)), "灵石不足时修炼应标记失败。")
	_expect(int(world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) == 0, "灵石库存不得为负数。")
	_expect(int(shortage_report.get("shortages", {}).get("spirit_stone", 0)) == 5, "灵石缺口应包含3维护费和2修炼费。")


func _find_result(report: Dictionary, disciple_id: String) -> Dictionary:
	for result in report.get("disciple_results", []):
		if str(result.get("disciple_id", "")) == disciple_id:
			return result
	return {}


func _test_player_sect_overview() -> void:
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var scene := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	_expect(scene != null, "无法加载玩家宗门详情场景。")
	if scene == null:
		return
	var overview: Control = scene.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_disciple_button_pressed")
	overview.call("_on_disciple_selected", "disciple_012")
	await process_frame
	var basic_info: Label = overview.get_node(
		"MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BasicInfoLabel"
	)
	_expect(basic_info.text.contains("修为进度："), "弟子详情未显示修为进度。")
	_expect(basic_info.text.contains("修炼状态："), "弟子详情未显示修炼状态。")
	overview.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
