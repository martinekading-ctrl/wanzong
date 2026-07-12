extends Node

signal relation_changed(relation_data: Dictionary)
signal diplomatic_action_completed(result: Dictionary)

var _relation_index: Dictionary = {}


func initialize_world_state() -> void:
	if WorldDataManager.relations.is_empty():
		var sects: Array = WorldDataManager.get_all_sects()
		for left_index in range(sects.size()):
			for right_index in range(left_index + 1, sects.size()):
				var relation := RelationData.new()
				relation.sect_a_id = str(sects[left_index].get("sect_id", ""))
				relation.sect_b_id = str(sects[right_index].get("sect_id", ""))
				relation.relation_id = _make_relation_id(relation.sect_a_id, relation.sect_b_id)
				relation.value = _initial_value(sects[left_index], sects[right_index])
				relation.status = _derive_basic_status(relation.value)
				WorldDataManager.relations.append(relation.to_dictionary())
	rebuild_runtime_state()


func rebuild_runtime_state() -> void:
	_relation_index.clear()
	for index in range(WorldDataManager.relations.size()):
		var relation := RelationData.from_dictionary(WorldDataManager.relations[index])
		if relation.relation_id == "":
			relation.relation_id = _make_relation_id(relation.sect_a_id, relation.sect_b_id)
		WorldDataManager.relations[index] = relation.to_dictionary()
		_relation_index[relation.relation_id] = index
	if WorldDataManager.relations.is_empty() and WorldDataManager.get_all_sects().size() >= 2:
		initialize_world_state()
		return
	_sync_all_player_relation_caches()


func daily_update(date: Dictionary) -> Dictionary:
	return {"relation_count": WorldDataManager.relations.size(), "date": date.duplicate(true)}


func get_relation(sect_a_id: String, sect_b_id: String) -> Dictionary:
	if sect_a_id == sect_b_id:
		return {"sect_a_id": sect_a_id, "sect_b_id": sect_b_id, "value": 100, "status": "self", "trust": 100, "tension": 0}
	var key: String = _make_relation_id(sect_a_id, sect_b_id)
	if not _relation_index.has(key):
		return {}
	return WorldDataManager.relations[int(_relation_index[key])].duplicate(true)


func get_relations_for_sect(sect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relation in WorldDataManager.relations:
		if str(relation.get("sect_a_id", "")) == sect_id or str(relation.get("sect_b_id", "")) == sect_id:
			var view: Dictionary = relation.duplicate(true)
			view["other_sect_id"] = str(relation.get("sect_b_id", "")) if str(relation.get("sect_a_id", "")) == sect_id else str(relation.get("sect_a_id", ""))
			result.append(view)
	return result


func change_relation_value(sect_a_id: String, sect_b_id: String, amount: int, reason: String = "", date: Dictionary = {}) -> Dictionary:
	var index: int = _find_relation_index(sect_a_id, sect_b_id)
	if index < 0:
		return _error("relation_not_found", "未找到宗门关系。")
	var relation := RelationData.from_dictionary(WorldDataManager.relations[index])
	relation.value = clampi(relation.value + amount, -100, 100)
	relation.status = _derive_basic_status(relation.value)
	relation.last_changed_date = date.duplicate(true) if not date.is_empty() else _current_date()
	if reason != "":
		relation.action_history.append({"type": "relation_change", "amount": amount, "reason": reason, "date": relation.last_changed_date.duplicate(true)})
		relation.action_history = relation.action_history.slice(maxi(0, relation.action_history.size() - 20))
	WorldDataManager.relations[index] = relation.to_dictionary()
	_sync_player_relation_cache(relation)
	relation_changed.emit(relation.to_dictionary())
	return {"success": true, "relation": relation.to_dictionary()}


func perform_action(actor_sect_id: String, target_sect_id: String, action_id: String, options: Dictionary = {}) -> Dictionary:
	if actor_sect_id == target_sect_id:
		return _error("same_sect", "不能对自身执行外交行动。")
	var definition: DiplomaticActionDefinition = DiplomaticActionRegistry.get_by_id(action_id)
	if definition == null:
		return _error("action_not_found", "外交行动配置不存在。")
	var index: int = _find_relation_index(actor_sect_id, target_sect_id)
	if index < 0:
		return _error("relation_not_found", "未找到双方关系。")
	var relation := RelationData.from_dictionary(WorldDataManager.relations[index])
	if relation.value < definition.minimum_relation or relation.value > definition.maximum_relation:
		return _error("relation_requirement", "当前关系不满足行动条件。")
	var cooldown_key: String = actor_sect_id + ":" + action_id
	var current_day: int = _date_ordinal(_current_date())
	if current_day < int(relation.cooldowns.get(cooldown_key, 0)):
		return _error("action_cooldown", "该外交行动仍在冷却中。")
	var missing_actor: Dictionary = _missing_resources(actor_sect_id, definition.actor_costs)
	var missing_target: Dictionary = _missing_resources(target_sect_id, definition.target_costs)
	if not missing_actor.is_empty() or not missing_target.is_empty():
		var missing_result: Dictionary = _error("resources_insufficient", "一方资源不足，行动无法执行。")
		missing_result["actor_missing"] = missing_actor
		missing_result["target_missing"] = missing_target
		return missing_result
	var acceptance: float = calculate_acceptance(actor_sect_id, target_sect_id, definition, relation)
	var roll: float = float(options.get("_test_roll", GameState.random_float())) if OS.is_debug_build() else GameState.random_float()
	var accepted: bool = roll <= acceptance
	var date: Dictionary = _current_date()
	if accepted:
		_apply_exchange(actor_sect_id, target_sect_id, definition)
		relation.value = clampi(relation.value + definition.relation_delta, -100, 100)
		relation.trust = clampi(relation.trust + definition.trust_delta, 0, 100)
		relation.tension = clampi(relation.tension + definition.tension_delta, 0, 100)
	else:
		relation.value = clampi(relation.value - 2, -100, 100)
		relation.tension = clampi(relation.tension + 2, 0, 100)
	relation.status = _derive_basic_status(relation.value)
	relation.cooldowns[cooldown_key] = current_day + definition.cooldown_days
	relation.last_changed_date = date.duplicate(true)
	var action_record: Dictionary = {
		"type": "diplomatic_action",
		"action_id": action_id,
		"actor_sect_id": actor_sect_id,
		"target_sect_id": target_sect_id,
		"accepted": accepted,
		"acceptance": acceptance,
		"roll": roll,
		"date": date.duplicate(true),
	}
	relation.action_history.append(action_record)
	relation.action_history = relation.action_history.slice(maxi(0, relation.action_history.size() - 20))
	WorldDataManager.relations[index] = relation.to_dictionary()
	_sync_player_relation_cache(relation)
	var result: Dictionary = action_record.duplicate(true)
	result["success"] = true
	result["relation"] = relation.to_dictionary()
	result["message"] = "%s接受了%s。" % [str(WorldDataManager.get_sect_by_id(target_sect_id).get("sect_name", target_sect_id)), definition.display_name] if accepted else "%s拒绝了%s。" % [str(WorldDataManager.get_sect_by_id(target_sect_id).get("sect_name", target_sect_id)), definition.display_name]
	GameHistoryManager.record_entry("diplomacy", "外交行动", str(result["message"]), [actor_sect_id, target_sect_id], result, date)
	relation_changed.emit(relation.to_dictionary())
	diplomatic_action_completed.emit(result)
	return result


func calculate_acceptance(actor_sect_id: String, target_sect_id: String, definition: DiplomaticActionDefinition, relation: RelationData = null) -> float:
	if relation == null:
		relation = RelationData.from_dictionary(get_relation(actor_sect_id, target_sect_id))
	var score: float = definition.base_acceptance + float(relation.value) / 250.0 + float(relation.trust - 50) / 500.0 - float(relation.tension) / 300.0
	if definition.id == "demand_tribute":
		var actor_power: float = maxf(1.0, float(WorldDataManager.get_sect_by_id(actor_sect_id).get("combat_power", 1)))
		var target_power: float = maxf(1.0, float(WorldDataManager.get_sect_by_id(target_sect_id).get("combat_power", 1)))
		score += clampf((actor_power / target_power - 1.0) * 0.25, -0.3, 0.4)
	return clampf(score, 0.05, 0.95)


func _apply_exchange(actor_sect_id: String, target_sect_id: String, definition: DiplomaticActionDefinition) -> void:
	for key in definition.actor_costs:
		var amount: int = int(definition.actor_costs[key])
		WorldDataManager.update_sect_resource(actor_sect_id, str(key), -amount)
		if definition.actor_costs_to_target:
			WorldDataManager.update_sect_resource(target_sect_id, str(key), amount)
	for key in definition.target_costs:
		var amount: int = int(definition.target_costs[key])
		WorldDataManager.update_sect_resource(target_sect_id, str(key), -amount)
		if definition.target_costs_to_actor:
			WorldDataManager.update_sect_resource(actor_sect_id, str(key), amount)


func _missing_resources(sect_id: String, costs: Dictionary) -> Dictionary:
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var missing: Dictionary = {}
	for key in costs:
		if int(resources.get(key, 0)) < int(costs[key]):
			missing[key] = int(costs[key]) - int(resources.get(key, 0))
	return missing


func _sync_all_player_relation_caches() -> void:
	for relation_data in WorldDataManager.relations:
		_sync_player_relation_cache(RelationData.from_dictionary(relation_data))


func _sync_player_relation_cache(relation: RelationData) -> void:
	var other_id: String = ""
	if relation.sect_a_id == "sect_001":
		other_id = relation.sect_b_id
	elif relation.sect_b_id == "sect_001":
		other_id = relation.sect_a_id
	if other_id != "":
		WorldDataManager.update_sect_data(other_id, "relation_to_player", relation.status)


func _initial_value(sect_a: Dictionary, sect_b: Dictionary) -> int:
	var other: Dictionary = sect_b if bool(sect_a.get("is_player", false)) else sect_a
	if bool(sect_a.get("is_player", false)) or bool(sect_b.get("is_player", false)):
		match str(other.get("relation_to_player", "neutral")):
			"friendly": return 35
			"hostile": return -70
			_: return 0
	return int((_make_relation_id(str(sect_a.get("sect_id", "")), str(sect_b.get("sect_id", ""))).hash() % 21) - 10)


func _derive_basic_status(value: int) -> String:
	if value >= 30:
		return "friendly"
	if value <= -70:
		return "hostile"
	if value <= -30:
		return "tense"
	return "neutral"


func _find_relation_index(sect_a_id: String, sect_b_id: String) -> int:
	return int(_relation_index.get(_make_relation_id(sect_a_id, sect_b_id), -1))


func _make_relation_id(sect_a_id: String, sect_b_id: String) -> String:
	var ids: Array[String] = [sect_a_id, sect_b_id]
	ids.sort()
	return ids[0] + "__" + ids[1]


func _date_ordinal(date: Dictionary) -> int:
	return (int(date.get("year", 1)) - 1) * 360 + (int(date.get("month", 1)) - 1) * 30 + int(date.get("day", 1))


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
