extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _battle_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_battle_manager = root.get_node("BattleManager")
	_test_fixed_seed_reproduction_and_flow()
	_test_formation_defense_injuries_and_loot()
	_test_prepared_battle_save_restore()
	if _failures.is_empty():
		print("[Task0053Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0053Test] " + failure)
	quit(1)


func _test_fixed_seed_reproduction_and_flow() -> void:
	_game_state.new_game()
	var attacker_ids: Array[String] = ["disciple_001", "disciple_003", "disciple_008"]
	var defender_ids: Array[String] = _ai_ids("sect_002", 3)
	var first: Dictionary = _battle_manager.create_and_simulate("sect_001", attacker_ids, "sect_002", defender_ids, {"seed": 123456, "battle_type": "sparring"})
	_expect(bool(first.get("success", false)), "自动战斗应完整结算。")
	_expect(int(first.get("rounds", 0)) in range(1, 31), "战斗应在最多30回合内结束。")
	_expect(str(first.get("winner_sect_id", "")) in ["sect_001", "sect_002"], "战斗必须产生胜者。")
	_expect(first.get("battle_log", []).size() > int(first.get("rounds", 0)), "战报应记录初始化、回合行动、状态和结果。")
	for unit in first.get("attacker_units", []) + first.get("defender_units", []):
		for key in ["max_hp", "current_hp", "attack", "defense", "speed", "spiritual_power", "accuracy", "critical_rate", "resistance", "battle_position"]:
			_expect(unit.has(key), "战斗单位快照缺少字段：" + key)

	_game_state.new_game()
	var second: Dictionary = _battle_manager.create_and_simulate("sect_001", attacker_ids, "sect_002", _ai_ids("sect_002", 3), {"seed": 123456, "battle_type": "sparring"})
	_expect(first.get("winner_sect_id") == second.get("winner_sect_id"), "固定种子应复现相同胜者。")
	_expect(first.get("rounds") == second.get("rounds"), "固定种子应复现相同回合数。")
	_expect(first.get("battle_log") == second.get("battle_log"), "固定种子与相同快照应逐行复现战报。")


func _test_formation_defense_injuries_and_loot() -> void:
	_game_state.new_game()
	var defender_ids: Array[String] = _ai_ids("sect_002", 2)
	_world_data_manager.update_disciple_fields(defender_ids[0], {"battle_position": "front", "speed": 10, "attack": 8, "defense": 5, "hp": 80, "max_hp": 80})
	_world_data_manager.update_disciple_fields(defender_ids[1], {"battle_position": "back", "speed": 12, "attack": 10, "defense": 5, "hp": 80, "max_hp": 80})
	_world_data_manager.update_disciple_fields("disciple_008", {"battle_position": "front", "speed": 200, "attack": 300, "defense": 120, "hp": 500, "max_hp": 500, "spiritual_power": 220})
	var defender_stone: int = int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"])
	var player_stone: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"])
	var result: Dictionary = _battle_manager.create_and_simulate("sect_001", ["disciple_008"], "sect_002", defender_ids, {"seed": 77, "battle_type": "skirmish"})
	_expect(str(result.get("winner_sect_id", "")) == "sect_001", "显著更强的队伍应赢得战斗。")
	var first_action: String = ""
	for line in result.get("battle_log", []):
		if str(line).contains("造成") or str(line).contains("未命中"):
			first_action = str(line)
			break
	_expect(first_action.contains(str(_world_data_manager.get_disciple_by_id(defender_ids[0]).get("disciple_name", ""))), "攻击应优先选择前排目标。")
	_expect(not result.get("injuries", []).is_empty(), "战败与低生命单位应产生战后伤病。")
	_expect(not result.get("loot", {}).is_empty(), "非切磋战斗应结算战利品。")
	_expect(int(_world_data_manager.get_sect_resources("sect_002")["spirit_stone"]) < defender_stone, "战败方资源应实际减少。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_stone"]) > player_stone, "战利品应进入胜者仓库。")

	_game_state.new_game()
	_world_data_manager.building_instances.append({"instance_id": "array_test", "definition_id": "mountain_array", "sect_id": "sect_002", "level": 1, "target_level": 1, "status": "active", "remaining_days": 0, "build_slot_id": 0, "started_date": {}, "completed_date": {}, "operational": true, "maintenance_shortages": {}})
	var plain: Dictionary = _battle_manager.create_battle("sect_001", ["disciple_001"], "sect_002", [_ai_ids("sect_002", 1)[0]], {"seed": 1})
	var fortified: Dictionary = _battle_manager.create_battle("sect_001", ["disciple_002"], "sect_002", [_ai_ids("sect_002", 1)[0]], {"seed": 1, "defender_uses_sect_defense": true})
	var plain_defense: int = int(plain.get("battle", {}).get("defender_units", [])[0].get("defense", 0))
	var fortified_defense: int = int(fortified.get("battle", {}).get("defender_units", [])[0].get("defense", 0))
	_expect(fortified_defense > plain_defense, "守宗战应复用护山大阵防御修正。")


func _test_prepared_battle_save_restore() -> void:
	_game_state.new_game()
	var created: Dictionary = _battle_manager.create_battle("sect_001", ["disciple_001", "disciple_003"], "sect_002", _ai_ids("sect_002", 2), {"seed": 9090, "battle_type": "sparring"})
	var battle_id: String = str(created.get("battle", {}).get("battle_id", ""))
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.battle_instances.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "准备中的战斗应可存档恢复。")
	var result: Dictionary = _battle_manager.simulate_battle(battle_id)
	_expect(bool(result.get("success", false)) and int(result.get("seed", 0)) == 9090, "读档后应按保存的固定种子完成战斗。")
	_expect(str(_battle_manager.get_battle(battle_id).get("status", "")) == "completed", "结算后的战斗实例应保留完整结果。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("battle").size() == 1, "战斗结果应写入历史。")


func _ai_ids(sect_id: String, count: int) -> Array[String]:
	var result: Array[String] = []
	for disciple in _world_data_manager.get_disciples_by_sect_id(sect_id):
		result.append(str(disciple.get("disciple_id", "")))
		if result.size() >= count:
			break
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
