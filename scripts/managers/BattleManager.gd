extends Node

signal battle_created(battle_data: Dictionary)
signal battle_completed(result: Dictionary)

const MAX_TEAM_SIZE: int = 6
const MAX_ROUNDS: int = 30

var _next_battle_number: int = 1


func rebuild_runtime_state() -> void:
	_next_battle_number = 1
	for battle in WorldDataManager.battle_instances:
		var number_text: String = str(battle.get("battle_id", "")).trim_prefix("battle_")
		if number_text.is_valid_int():
			_next_battle_number = maxi(_next_battle_number, number_text.to_int() + 1)


func create_battle(attacker_sect_id: String, attacker_disciple_ids: Array, defender_sect_id: String, defender_disciple_ids: Array, options: Dictionary = {}) -> Dictionary:
	if attacker_sect_id == defender_sect_id:
		return _error("same_sect", "同一宗门不能互相战斗。")
	var attacker_units: Array[Dictionary] = _build_team(attacker_sect_id, attacker_disciple_ids, false)
	var defender_units: Array[Dictionary] = _build_team(defender_sect_id, defender_disciple_ids, bool(options.get("defender_uses_sect_defense", false)))
	if attacker_units.is_empty() or defender_units.is_empty():
		return _error("empty_team", "交战双方至少各需一名有效弟子。")
	if attacker_units.size() > MAX_TEAM_SIZE or defender_units.size() > MAX_TEAM_SIZE:
		return _error("team_size", "每支战斗队伍最多%d人。" % MAX_TEAM_SIZE)
	var battle := BattleInstanceData.new()
	battle.battle_id = "battle_%05d" % _next_battle_number
	_next_battle_number += 1
	battle.battle_type = str(options.get("battle_type", "skirmish"))
	battle.attacker_sect_id = attacker_sect_id
	battle.defender_sect_id = defender_sect_id
	battle.attacker_units = attacker_units
	battle.defender_units = defender_units
	battle.seed = int(options.get("seed", GameState.random_int(1, 2147483646)))
	battle.created_date = _current_date()
	battle.options = options.duplicate(true)
	battle.options.erase("seed")
	WorldDataManager.battle_instances.append(battle.to_dictionary())
	var view: Dictionary = battle.to_dictionary()
	battle_created.emit(view)
	return {"success": true, "battle": view}


func simulate_battle(battle_id: String) -> Dictionary:
	var index: int = _find_battle_index(battle_id)
	if index < 0:
		return _error("battle_not_found", "未找到战斗实例。")
	var battle := BattleInstanceData.from_dictionary(WorldDataManager.battle_instances[index])
	if battle.status == "completed":
		return battle.result.duplicate(true)
	if battle.status != "prepared":
		return _error("battle_state", "战斗状态不可结算。")
	var rng := RandomNumberGenerator.new()
	rng.seed = battle.seed
	var attackers: Array[BattleUnitData] = _restore_units(battle.attacker_units)
	var defenders: Array[BattleUnitData] = _restore_units(battle.defender_units)
	battle.status = "resolving"
	battle.battle_log.append("战斗开始：%s 对阵 %s，随机种子 %d。" % [_sect_name(battle.attacker_sect_id), _sect_name(battle.defender_sect_id), battle.seed])
	for round_number in range(1, MAX_ROUNDS + 1):
		battle.current_round = round_number
		battle.battle_log.append("第%d回合" % round_number)
		var turn_order: Array[Dictionary] = _build_turn_order(attackers, defenders)
		for turn in turn_order:
			var actor: BattleUnitData = turn["unit"]
			if not actor.is_alive():
				continue
			var enemies: Array[BattleUnitData] = defenders if str(turn["side"]) == "attacker" else attackers
			var target: BattleUnitData = _choose_target(enemies, rng)
			if target == null:
				break
			_resolve_attack(actor, target, round_number, rng, battle.battle_log)
		if not _has_living_units(attackers) or not _has_living_units(defenders):
			break
		_settle_round_status(attackers, battle.battle_log)
		_settle_round_status(defenders, battle.battle_log)
	var attacker_score: int = _remaining_hp(attackers)
	var defender_score: int = _remaining_hp(defenders)
	var attacker_won: bool = defender_score <= 0 or (attacker_score > 0 and attacker_score > defender_score)
	if attacker_score == defender_score:
		attacker_won = _team_total_power(attackers) >= _team_total_power(defenders)
	battle.winner_sect_id = battle.attacker_sect_id if attacker_won else battle.defender_sect_id
	battle.loser_sect_id = battle.defender_sect_id if attacker_won else battle.attacker_sect_id
	battle.attacker_units = _serialize_units(attackers)
	battle.defender_units = _serialize_units(defenders)
	battle.injuries = _apply_post_battle_injuries(attackers + defenders)
	battle.loot = _apply_loot(battle)
	battle.status = "completed"
	battle.completed_date = _current_date()
	battle.battle_log.append("战斗结束：%s获胜。" % _sect_name(battle.winner_sect_id))
	battle.result = {
		"success": true,
		"battle_id": battle.battle_id,
		"battle_type": battle.battle_type,
		"seed": battle.seed,
		"rounds": battle.current_round,
		"winner_sect_id": battle.winner_sect_id,
		"loser_sect_id": battle.loser_sect_id,
		"attacker_units": battle.attacker_units.duplicate(true),
		"defender_units": battle.defender_units.duplicate(true),
		"injuries": battle.injuries.duplicate(true),
		"loot": battle.loot.duplicate(true),
		"battle_log": battle.battle_log.duplicate(),
	}
	WorldDataManager.battle_instances[index] = battle.to_dictionary()
	GameHistoryManager.record_entry("battle", "战斗结算", "%s战胜%s。" % [_sect_name(battle.winner_sect_id), _sect_name(battle.loser_sect_id)], [battle.battle_id, battle.winner_sect_id, battle.loser_sect_id], battle.result, battle.completed_date)
	battle_completed.emit(battle.result)
	return battle.result.duplicate(true)


func create_and_simulate(attacker_sect_id: String, attacker_disciple_ids: Array, defender_sect_id: String, defender_disciple_ids: Array, options: Dictionary = {}) -> Dictionary:
	var created: Dictionary = create_battle(attacker_sect_id, attacker_disciple_ids, defender_sect_id, defender_disciple_ids, options)
	if not bool(created.get("success", false)):
		return created
	return simulate_battle(str(created.get("battle", {}).get("battle_id", "")))


func get_battle(battle_id: String) -> Dictionary:
	var index: int = _find_battle_index(battle_id)
	return WorldDataManager.battle_instances[index].duplicate(true) if index >= 0 else {}


func get_all_battles() -> Array[Dictionary]:
	return WorldDataManager.battle_instances.duplicate(true)


func _build_team(sect_id: String, disciple_ids: Array, use_sect_defense: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var unique_ids: Array[String] = []
	for raw_id in disciple_ids:
		var disciple_id: String = str(raw_id)
		if disciple_id == "" or disciple_id in unique_ids:
			continue
		var data: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
		if data.is_empty() or str(data.get("sect_id", "")) != sect_id:
			continue
		unique_ids.append(disciple_id)
		var unit := BattleUnitData.new()
		unit.unit_id = sect_id + ":" + disciple_id
		unit.disciple_id = disciple_id
		unit.sect_id = sect_id
		unit.display_name = str(data.get("disciple_name", disciple_id))
		unit.battle_position = str(data.get("battle_position", "middle"))
		unit.max_hp = maxi(1, int(data.get("max_hp", data.get("hp", 100))))
		unit.current_hp = clampi(int(data.get("hp", unit.max_hp)), 1, unit.max_hp)
		unit.attack = maxi(1, int(data.get("attack", 10)))
		unit.defense = maxi(0, int(data.get("defense", 10)))
		if use_sect_defense:
			unit.defense = ModifierManager.get_sect_defense(sect_id, unit.defense)
		unit.speed = maxi(1, int(data.get("speed", 10)))
		unit.spiritual_power = maxi(0, int(data.get("spiritual_power", 0)))
		for equipped_item_id in data.get("equipment", {}).values():
			var equipment: ItemDefinition = ItemRegistry.get_by_id(str(equipped_item_id))
			if equipment == null or equipment.category != "equipment":
				continue
			unit.attack += int(equipment.stat_modifiers.get("attack", 0))
			unit.defense += int(equipment.stat_modifiers.get("defense", 0))
			unit.speed += int(equipment.stat_modifiers.get("speed", 0))
			unit.spiritual_power += int(equipment.stat_modifiers.get("spiritual_power", 0))
			var hp_bonus: int = int(equipment.stat_modifiers.get("max_hp", 0))
			unit.max_hp += hp_bonus
			unit.current_hp += hp_bonus
		unit.accuracy = clampf(0.78 + float(unit.speed) / 500.0, 0.75, 0.95)
		unit.critical_rate = clampf(0.05 + float(data.get("talent", data.get("comprehension", 50))) / 1000.0, 0.05, 0.2)
		unit.resistance = clampf(float(unit.defense) / 500.0, 0.0, 0.5)
		for equipped_item_id in data.get("equipment", {}).values():
			var equipment: ItemDefinition = ItemRegistry.get_by_id(str(equipped_item_id))
			if equipment != null:
				unit.resistance = clampf(unit.resistance + float(equipment.stat_modifiers.get("resistance", 0.0)), 0.0, 0.8)
		result.append(unit.to_dictionary())
	return result


func _restore_units(data: Array[Dictionary]) -> Array[BattleUnitData]:
	var result: Array[BattleUnitData] = []
	for unit_data in data:
		result.append(BattleUnitData.from_dictionary(unit_data))
	return result


func _serialize_units(units: Array[BattleUnitData]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in units:
		result.append(unit.to_dictionary())
	return result


func _build_turn_order(attackers: Array[BattleUnitData], defenders: Array[BattleUnitData]) -> Array[Dictionary]:
	var turns: Array[Dictionary] = []
	for unit in attackers:
		if unit.is_alive(): turns.append({"side": "attacker", "unit": unit})
	for unit in defenders:
		if unit.is_alive(): turns.append({"side": "defender", "unit": unit})
	turns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: BattleUnitData = a["unit"]
		var right: BattleUnitData = b["unit"]
		return left.speed > right.speed if left.speed != right.speed else left.unit_id < right.unit_id
	)
	return turns


func _choose_target(enemies: Array[BattleUnitData], rng: RandomNumberGenerator) -> BattleUnitData:
	for position in ["front", "middle", "back"]:
		var candidates: Array[BattleUnitData] = []
		for enemy in enemies:
			if enemy.is_alive() and enemy.battle_position == position:
				candidates.append(enemy)
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
	for enemy in enemies:
		if enemy.is_alive(): return enemy
	return null


func _resolve_attack(actor: BattleUnitData, target: BattleUnitData, round_number: int, rng: RandomNumberGenerator, log: Array[String]) -> void:
	var hit_chance: float = clampf(actor.accuracy - float(target.speed) / 1200.0, 0.55, 0.98)
	if rng.randf() > hit_chance:
		log.append("%s攻击%s未命中。" % [actor.display_name, target.display_name])
		return
	var uses_skill: bool = actor.spiritual_power > 0 and round_number % 3 == 0
	var raw_damage: float = float(actor.attack)
	if uses_skill:
		raw_damage += float(actor.spiritual_power) * 0.45
		raw_damage *= 1.0 - target.resistance
	var critical: bool = rng.randf() <= actor.critical_rate
	if critical:
		raw_damage *= 1.5
	var damage: int = maxi(1, roundi(raw_damage - float(target.defense) * (0.35 if uses_skill else 0.55)))
	target.current_hp = maxi(0, target.current_hp - damage)
	log.append("%s%s对%s造成%d伤害%s，剩余生命%d。" % [actor.display_name, "施展术法" if uses_skill else "", target.display_name, damage, "（暴击）" if critical else "", target.current_hp])


func _settle_round_status(units: Array[BattleUnitData], log: Array[String]) -> void:
	for unit in units:
		if not unit.is_alive() or unit.current_hp * 100 >= unit.max_hp * 30:
			continue
		var has_wounded: bool = false
		for effect in unit.status_effects:
			if str(effect.get("id", "")) == "wounded": has_wounded = true
		if not has_wounded:
			unit.status_effects.append({"id": "wounded", "attack_multiplier": 0.9})
			unit.attack = maxi(1, roundi(float(unit.attack) * 0.9))
			log.append("%s身受重伤，攻击下降。" % unit.display_name)


func _apply_post_battle_injuries(units: Array[BattleUnitData]) -> Array[Dictionary]:
	var injuries: Array[Dictionary] = []
	for unit in units:
		var health_percent: int = maxi(1, roundi(float(unit.current_hp) / float(unit.max_hp) * 100.0))
		var old_data: Dictionary = WorldDataManager.get_disciple_by_id(unit.disciple_id)
		var old_health: int = int(old_data.get("health", 100))
		var new_health: int = mini(old_health, health_percent)
		WorldDataManager.update_disciple_data(unit.disciple_id, "health", new_health)
		WorldDataManager.update_disciple_data(unit.disciple_id, "hp", maxi(1, unit.current_hp))
		var wounded: bool = health_percent < 60
		WorldDataManager.update_disciple_data(unit.disciple_id, "battle_status", "受伤" if wounded else "正常")
		WorldDataManager.update_disciple_data(unit.disciple_id, "status", "受伤" if wounded else "正常")
		var runtime: DiscipleData = DiscipleManager.get_disciple_by_id(unit.disciple_id)
		if runtime != null:
			runtime.health = new_health
			DiscipleManager.sync_disciple_state(runtime)
		if wounded:
			injuries.append({"disciple_id": unit.disciple_id, "health_before": old_health, "health_after": new_health, "knocked_out": unit.current_hp <= 0})
	return injuries


func _apply_loot(battle: BattleInstanceData) -> Dictionary:
	if battle.battle_type == "sparring" or not bool(battle.options.get("allow_loot", true)):
		return {}
	var loser_resources: Dictionary = WorldDataManager.get_sect_resources(battle.loser_sect_id)
	var loot: Dictionary = {}
	for key in ["spirit_stone", "spirit_grass", "spirit_ore"]:
		var amount: int = mini(200 if key == "spirit_stone" else 30, int(loser_resources.get(key, 0)) / 20)
		if amount <= 0: continue
		WorldDataManager.update_sect_resource(battle.loser_sect_id, key, -amount)
		WorldDataManager.update_sect_resource(battle.winner_sect_id, key, amount)
		loot[key] = amount
	return loot


func _has_living_units(units: Array[BattleUnitData]) -> bool:
	for unit in units:
		if unit.is_alive(): return true
	return false


func _remaining_hp(units: Array[BattleUnitData]) -> int:
	var total: int = 0
	for unit in units: total += unit.current_hp
	return total


func _team_total_power(units: Array[BattleUnitData]) -> int:
	var total: int = 0
	for unit in units: total += unit.attack + unit.defense + unit.spiritual_power
	return total


func _find_battle_index(battle_id: String) -> int:
	for index in range(WorldDataManager.battle_instances.size()):
		if str(WorldDataManager.battle_instances[index].get("battle_id", "")) == battle_id: return index
	return -1


func _sect_name(sect_id: String) -> String:
	return str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id))


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
