extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _diplomacy_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_diplomacy_manager = root.get_node("DiplomacyManager")
	_test_alliance_war_peace_and_truce()
	_test_non_aggression_and_vassalage()
	_test_pact_save_restore()
	await _test_pact_ui()
	if _failures.is_empty():
		print("[Task0052Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0052Test] " + failure)
	quit(1)


func _test_alliance_war_peace_and_truce() -> void:
	_game_state.new_game()
	_prepare_alliance_relation("sect_002")
	var alliance: Dictionary = _diplomacy_manager.propose_alliance("sect_001", "sect_002", {"_test_roll": 0.0})
	_expect(bool(alliance.get("accepted", false)), "满足关系与信任条件后应可结盟。")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "alliance", "联盟状态必须独立覆盖友好关系值。")
	_expect(_diplomacy_manager.get_active_pacts("alliance").size() == 1, "联盟应保存为独立有效契约。")
	_diplomacy_manager.change_relation_value("sect_001", "sect_002", -30, "联盟内分歧")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "alliance", "关系值变化不得自动解除有效联盟。")

	var war: Dictionary = _diplomacy_manager.declare_war("sect_001", "sect_002", "territory_conflict")
	_expect(bool(war.get("success", false)), "宗门应可正式宣战。")
	var relation: Dictionary = _diplomacy_manager.get_relation("sect_001", "sect_002")
	_expect(str(relation.get("status", "")) == "war" and int(relation.get("value", 0)) == -100, "宣战应设置战争状态、极低关系和最高紧张。")
	_expect(_diplomacy_manager.get_active_pacts("alliance").is_empty(), "宣战必须终止双方联盟。")
	_expect(_diplomacy_manager.get_active_pacts("war").size() == 1, "战争应有独立契约实例。")

	var peace: Dictionary = _diplomacy_manager.offer_peace("sect_001", "sect_002", {"_test_roll": 0.0})
	_expect(bool(peace.get("accepted", false)), "强制低判定时议和应成功。")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "truce", "议和后应进入停战状态。")
	_expect(_diplomacy_manager.get_active_pacts("war").is_empty() and _diplomacy_manager.get_active_pacts("truce").size() == 1, "议和应结束战争并生成限时停战。")
	var expiry_report: Dictionary = _diplomacy_manager.daily_update({"year": 1, "month": 4, "day": 1})
	_expect(expiry_report.get("expired_pacts", []).size() == 1, "九十日后停战契约应到期。")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "neutral", "停战到期后应按关系值恢复基础状态。")


func _test_non_aggression_and_vassalage() -> void:
	_game_state.new_game()
	var non_aggression: Dictionary = _diplomacy_manager.sign_non_aggression("sect_001", "sect_003", {"_test_roll": 0.0})
	_expect(bool(non_aggression.get("accepted", false)), "中立宗门应可签订互不侵犯。")
	_expect(_diplomacy_manager.get_active_pacts("non_aggression").size() == 1, "互不侵犯应作为限时契约保存。")
	_world_data_manager.update_sect_data("sect_001", "combat_power", 5000)
	var vassal: Dictionary = _diplomacy_manager.establish_vassal("sect_001", "sect_002", {"_test_roll": 0.0})
	_expect(bool(vassal.get("accepted", false)), "战力达到1.5倍并通过判定后应可建立附属。")
	var pact: Dictionary = vassal.get("pact", {})
	_expect(str(pact.get("overlord_sect_id", "")) == "sect_001" and str(pact.get("vassal_sect_id", "")) == "sect_002", "附属契约必须明确宗主与附属方。")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "vassal", "附属状态应覆盖基础关系状态。")
	_expect(str(_world_data_manager.ai_states["sect_002"].get("vassal_of", "")) == "sect_001", "AI状态应同步附属宗主。")
	var conflict: Dictionary = _diplomacy_manager.propose_alliance("sect_001", "sect_002", {"_test_roll": 0.0})
	_expect(str(conflict.get("code", "")) in ["alliance_requirements", "pact_conflict"], "附属关系下不得重复结盟。")


func _test_pact_save_restore() -> void:
	_game_state.new_game()
	_prepare_alliance_relation("sect_002")
	_diplomacy_manager.propose_alliance("sect_001", "sect_002", {"_test_roll": 0.0})
	_diplomacy_manager.sign_non_aggression("sect_001", "sect_003", {"_test_roll": 0.0})
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.diplomatic_pacts.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "外交契约应可存档恢复。")
	_expect(_diplomacy_manager.get_active_pacts().size() == 2, "读档后联盟和互不侵犯不得丢失。")
	_expect(str(_diplomacy_manager.get_relation("sect_001", "sect_002")["status"]) == "alliance", "读档重建应由有效契约恢复联盟状态。")


func _test_pact_ui() -> void:
	_game_state.new_game()
	var packed := load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene
	var overview: Control = packed.instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_diplomacy_button_pressed")
	await process_frame
	var pact_box: HBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/PactControlBox")
	_expect(pact_box.get_child_count() == 5, "外交界面应提供结盟、互不侵犯、附属、宣战、议和五个契约入口。")
	var peace_button: Button = pact_box.get_node("PeaceButton")
	_expect(peace_button.disabled, "非战争状态下议和按钮必须禁用。")
	overview.queue_free()
	await process_frame


func _prepare_alliance_relation(target_id: String) -> void:
	_diplomacy_manager.perform_action("sect_001", target_id, "small_gift", {"_test_roll": 0.0})
	_diplomacy_manager.perform_action("sect_001", target_id, "goodwill_visit", {"_test_roll": 0.0})
	_diplomacy_manager.change_relation_value("sect_001", target_id, 34, "结盟准备")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
