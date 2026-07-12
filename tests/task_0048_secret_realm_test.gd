extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _mission_manager: Node
var _secret_realm_manager: Node
var _event_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_mission_manager = root.get_node("MissionManager")
	_secret_realm_manager = root.get_node("SecretRealmManager")
	_event_manager = root.get_node("EventManager")
	_test_definitions_and_map_links()
	_test_mission_event_and_clearance()
	_test_risk_and_save_restore()
	await _test_secret_realm_ui()
	if _failures.is_empty():
		print("[Task0048Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0048Test] " + failure)
	quit(1)


func _test_definitions_and_map_links() -> void:
	_game_state.new_game()
	_expect(SecretRealmRegistry.get_all().size() == 3, "应加载三个秘境配置。")
	_expect(SecretRealmRegistry.validate().is_empty(), "秘境配置校验应通过。")
	_expect(_secret_realm_manager.get_all_realms().size() == 3, "新游戏应初始化三个秘境状态。")
	var map_secret_ids: Array[int] = []
	for resource in _world_data_manager.get_all_resources():
		if str(resource.get("resource_type", "")) == "secret_realm":
			map_secret_ids.append(int(resource.get("resource_id", 0)))
	for realm in _secret_realm_manager.get_all_realms():
		_expect(int(realm.get("map_resource_id", 0)) in map_secret_ids, "秘境必须映射到现有地图入口。")
		_expect(str(realm.get("status", "")) == "discovered", "地图已显示的秘境入口初始应为已发现。")


func _test_mission_event_and_clearance() -> void:
	_game_state.new_game()
	var realm_id: String = "secret_realm_misty_valley"
	var start: Dictionary = _mission_manager.create_and_start_mission(
		"sect_001",
		["disciple_001", "disciple_002", "disciple_003"],
		"mission_secret_realm",
		{"_test_roll": 0.0, "secret_realm_id": realm_id}
	)
	_expect(bool(start.get("success", false)), "秘境队伍应能出发。")
	_expect(str(start.get("mission", {}).get("context", {}).get("secret_realm_id", "")) == realm_id, "任务实例应保存秘境目标。")
	for _day in range(8):
		_game_state.next_day()
	var state: Dictionary = _secret_realm_manager.get_realm_by_id(realm_id)
	_expect(int(state.get("exploration_count", 0)) == 1, "任务返回后应记录一次探索。")
	_expect(int(state.get("current_depth", 0)) == 0, "选择事件前不应提前推进秘境层数。")
	var event: Dictionary = _find_pending_event("secret_realm_misty_choice")
	_expect(not event.is_empty(), "成功的秘境任务应触发对应探索事件。")
	var grass_before: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_grass"])
	var resolved: Dictionary = _event_manager.resolve_event(str(event.get("instance_id", "")), "safe_path")
	_expect(bool(resolved.get("success", false)), "秘境事件选项应可处理。")
	state = _secret_realm_manager.get_realm_by_id(realm_id)
	_expect(int(state.get("current_depth", 0)) == 1 and str(state.get("status", "")) == "exploring", "事件选择应推进一层探索。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_grass"]) == grass_before + 20, "探索事件奖励应写入宗门仓库。")

	var second: Dictionary = _mission_manager.create_and_start_mission(
		"sect_001",
		["disciple_004", "disciple_005", "disciple_006"],
		"mission_secret_realm",
		{"_test_roll": 0.0, "secret_realm_id": realm_id}
	)
	_expect(bool(second.get("success", false)), "同一秘境未清关前应可再次探索。")
	for _day in range(8):
		_game_state.next_day()
	event = _find_pending_event("secret_realm_misty_choice")
	_expect(not event.is_empty(), "第二次成功探索仍应生成独立事件实例。")
	_event_manager.resolve_event(str(event.get("instance_id", "")), "safe_path")
	state = _secret_realm_manager.get_realm_by_id(realm_id)
	_expect(str(state.get("status", "")) == "cleared" and int(state.get("current_depth", 0)) == 2, "达到总层数后秘境应标记为已清关。")
	_expect(not _secret_realm_manager.can_explore(realm_id), "已清关秘境不得继续派遣。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("secret_realm").size() == 2, "每次探索选择应写入历史。")


func _test_risk_and_save_restore() -> void:
	_game_state.new_game()
	var health_before: int = int(_world_data_manager.get_disciple_by_id("disciple_001")["health"])
	var effect_result: Dictionary = _secret_realm_manager.apply_exploration_choice(
		{"sect_id": "sect_001", "secret_realm_id": "secret_realm_ancient_cave", "disciple_ids": ["disciple_001"]},
		{"progress": 1, "rewards": {"spirit_ore": 10}, "injury_chance": 1.0, "health_loss": 15}
	)
	_expect(bool(effect_result.get("success", false)), "探索选择规则应可独立结算。")
	_expect(int(_world_data_manager.get_disciple_by_id("disciple_001")["health"]) == health_before - 15, "高风险探索应通过弟子运行时数据写入非致命伤势。")
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.secret_realms.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "秘境状态快照应可恢复。")
	var restored: Dictionary = _secret_realm_manager.get_realm_by_id("secret_realm_ancient_cave")
	_expect(int(restored.get("current_depth", 0)) == 1, "存档恢复后秘境探索进度不得丢失。")


func _test_secret_realm_ui() -> void:
	_game_state.new_game()
	var packed := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = packed.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_mission_button_pressed")
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection")
	var mission_option: OptionButton = section.get_node("MissionControlBox/MissionOption")
	var realm_option: OptionButton = section.get_node("MissionControlBox/SecretRealmOption")
	for index in range(mission_option.item_count):
		if mission_option.get_item_text(index).contains("秘境探索"):
			mission_option.select(index)
			overview.call("_on_mission_option_selected", index)
			break
	_expect(realm_option.visible, "选择秘境任务时应显示秘境目标选择器。")
	_expect(realm_option.item_count == 3, "目标选择器应显示三个未清关秘境。")
	overview.queue_free()
	await process_frame


func _find_pending_event(definition_id: String) -> Dictionary:
	for event in _event_manager.get_pending_events():
		if str(event.get("definition_id", "")) == definition_id:
			return event
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
