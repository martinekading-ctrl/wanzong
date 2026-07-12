extends Node

signal relation_changed(relation_data: Dictionary)
signal diplomatic_action_completed(result: Dictionary)

var _relation_index: Dictionary = {}
var _next_pact_number: int = 1


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
	_next_pact_number = 1
	for pact_data in WorldDataManager.diplomatic_pacts:
		var number_text: String = str(pact_data.get("pact_id", "")).trim_prefix("pact_")
		if number_text.is_valid_int():
			_next_pact_number = maxi(_next_pact_number, number_text.to_int() + 1)
	for index in range(WorldDataManager.relations.size()):
		var relation := RelationData.from_dictionary(WorldDataManager.relations[index])
		if relation.relation_id == "":
			relation.relation_id = _make_relation_id(relation.sect_a_id, relation.sect_b_id)
		WorldDataManager.relations[index] = relation.to_dictionary()
		_relation_index[relation.relation_id] = index
	if WorldDataManager.relations.is_empty() and WorldDataManager.get_all_sects().size() >= 2:
		initialize_world_state()
		return
	_refresh_all_relation_statuses()
	_sync_all_player_relation_caches()


func daily_update(date: Dictionary) -> Dictionary:
	var expired: Array[String] = []
	var ordinal: int = _date_ordinal(date)
	for index in range(WorldDataManager.diplomatic_pacts.size()):
		var pact := DiplomaticPactData.from_dictionary(WorldDataManager.diplomatic_pacts[index])
		if pact.status != "active" or pact.expires_on_ordinal <= 0 or ordinal < pact.expires_on_ordinal:
			continue
		pact.status = "expired"
		pact.ended_date = date.duplicate(true)
		WorldDataManager.diplomatic_pacts[index] = pact.to_dictionary()
		expired.append(pact.pact_id)
	_refresh_all_relation_statuses()
	_sync_all_player_relation_caches()
	return {"relation_count": WorldDataManager.relations.size(), "active_pacts": get_active_pacts().size(), "expired_pacts": expired, "date": date.duplicate(true)}


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
	relation.status = _derive_relation_status(relation)
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
	relation.status = _derive_relation_status(relation)
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


func propose_alliance(actor_sect_id: String, target_sect_id: String, options: Dictionary = {}) -> Dictionary:
	var relation := _get_relation_runtime(actor_sect_id, target_sect_id)
	if relation == null:
		return _error("relation_not_found", "未找到双方关系。")
	if relation.value < 50 or relation.trust < 60 or relation.tension > 30:
		return _error("alliance_requirements", "结盟需要关系值50、信任60且紧张不高于30。")
	if _has_active_pair_pact(actor_sect_id, target_sect_id, ["alliance", "war", "vassal"]):
		return _error("pact_conflict", "双方已有冲突或同类契约。")
	var acceptance: float = clampf(0.35 + float(relation.value) / 200.0 + float(relation.trust) / 300.0 - float(relation.tension) / 200.0, 0.05, 0.95)
	return _resolve_pact_proposal(actor_sect_id, target_sect_id, "alliance", acceptance, options)


func sign_non_aggression(actor_sect_id: String, target_sect_id: String, options: Dictionary = {}) -> Dictionary:
	var relation := _get_relation_runtime(actor_sect_id, target_sect_id)
	if relation == null or relation.value < 0 or relation.tension > 50:
		return _error("non_aggression_requirements", "互不侵犯需要非负关系且紧张不高于50。")
	if _has_active_pair_pact(actor_sect_id, target_sect_id, ["non_aggression", "alliance", "war"]):
		return _error("pact_conflict", "双方已有冲突或同类契约。")
	var acceptance: float = clampf(0.55 + float(relation.value) / 250.0 + float(relation.trust - 50) / 300.0, 0.05, 0.95)
	return _resolve_pact_proposal(actor_sect_id, target_sect_id, "non_aggression", acceptance, options, 180)


func establish_vassal(overlord_sect_id: String, vassal_sect_id: String, options: Dictionary = {}) -> Dictionary:
	var relation := _get_relation_runtime(overlord_sect_id, vassal_sect_id)
	if relation == null:
		return _error("relation_not_found", "未找到双方关系。")
	if _has_active_pair_pact(overlord_sect_id, vassal_sect_id, ["alliance", "war", "vassal"]):
		return _error("pact_conflict", "双方当前状态无法建立附属。")
	var overlord_power: float = maxf(1.0, float(WorldDataManager.get_sect_by_id(overlord_sect_id).get("combat_power", 1)))
	var vassal_power: float = maxf(1.0, float(WorldDataManager.get_sect_by_id(vassal_sect_id).get("combat_power", 1)))
	var ratio: float = overlord_power / vassal_power
	if ratio < 1.5:
		return _error("power_requirement", "宗门战力至少需要达到目标的1.5倍。")
	var acceptance: float = clampf(0.1 + (ratio - 1.0) * 0.25 + float(relation.value) / 300.0 - float(relation.tension) / 300.0, 0.05, 0.95)
	var result: Dictionary = _resolve_pact_proposal(overlord_sect_id, vassal_sect_id, "vassal", acceptance, options)
	if bool(result.get("accepted", false)):
		var pact_index: int = _find_pact_index(str(result.get("pact", {}).get("pact_id", "")))
		var pact := DiplomaticPactData.from_dictionary(WorldDataManager.diplomatic_pacts[pact_index])
		pact.overlord_sect_id = overlord_sect_id
		pact.vassal_sect_id = vassal_sect_id
		WorldDataManager.diplomatic_pacts[pact_index] = pact.to_dictionary()
		WorldDataManager.update_sect_data(vassal_sect_id, "vassal_of", overlord_sect_id)
		if WorldDataManager.ai_states.has(vassal_sect_id):
			WorldDataManager.ai_states[vassal_sect_id]["vassal_of"] = overlord_sect_id
		_refresh_relation_status(overlord_sect_id, vassal_sect_id)
		result["pact"] = pact.to_dictionary()
	return result


func declare_war(attacker_sect_id: String, defender_sect_id: String, reason: String = "territory_conflict") -> Dictionary:
	var relation := _get_relation_runtime(attacker_sect_id, defender_sect_id)
	if relation == null:
		return _error("relation_not_found", "未找到双方关系。")
	if _has_active_pair_pact(attacker_sect_id, defender_sect_id, ["war"]):
		return _error("already_at_war", "双方已经处于战争状态。")
	_end_pair_pacts(attacker_sect_id, defender_sect_id, ["alliance", "non_aggression", "truce"], "broken_by_war")
	var pact: DiplomaticPactData = _create_pact("war", [attacker_sect_id, defender_sect_id], 0, {"attacker": attacker_sect_id, "defender": defender_sect_id, "reason": reason})
	relation.value = -100
	relation.trust = 0
	relation.tension = 100
	relation.treaties.append(pact.pact_id)
	relation.status = "war"
	_store_relation(relation)
	var result: Dictionary = {"success": true, "accepted": true, "pact": pact.to_dictionary(), "message": "%s向%s宣战。" % [_sect_name(attacker_sect_id), _sect_name(defender_sect_id)]}
	_record_pact_history("宣战", result["message"], [attacker_sect_id, defender_sect_id], result)
	return result


func offer_peace(actor_sect_id: String, target_sect_id: String, options: Dictionary = {}) -> Dictionary:
	var war: Dictionary = _get_active_pair_pact(actor_sect_id, target_sect_id, ["war"])
	if war.is_empty():
		return _error("not_at_war", "双方并未处于战争状态。")
	var relation := _get_relation_runtime(actor_sect_id, target_sect_id)
	var acceptance: float = clampf(0.45 + float(relation.trust) / 400.0 - float(relation.tension) / 500.0, 0.1, 0.8)
	var roll: float = _get_roll(options)
	if roll > acceptance:
		return {"success": true, "accepted": false, "acceptance": acceptance, "roll": roll, "message": "%s拒绝议和。" % _sect_name(target_sect_id)}
	_end_pact(str(war.get("pact_id", "")), "peace")
	var truce: DiplomaticPactData = _create_pact("truce", [actor_sect_id, target_sect_id], 90, {"from_war": str(war.get("pact_id", ""))})
	relation.value = -20
	relation.tension = 30
	relation.treaties.append(truce.pact_id)
	relation.status = "truce"
	_store_relation(relation)
	var result: Dictionary = {"success": true, "accepted": true, "acceptance": acceptance, "roll": roll, "pact": truce.to_dictionary(), "message": "%s与%s达成停战。" % [_sect_name(actor_sect_id), _sect_name(target_sect_id)]}
	_record_pact_history("议和", result["message"], [actor_sect_id, target_sect_id], result)
	return result


func get_active_pacts(pact_type: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pact in WorldDataManager.diplomatic_pacts:
		if str(pact.get("status", "")) == "active" and (pact_type == "" or str(pact.get("pact_type", "")) == pact_type):
			result.append(pact.duplicate(true))
	return result


func get_pacts_for_sect(sect_id: String, active_only: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pact in WorldDataManager.diplomatic_pacts:
		if sect_id not in pact.get("member_ids", []):
			continue
		if active_only and str(pact.get("status", "")) != "active":
			continue
		result.append(pact.duplicate(true))
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


func _resolve_pact_proposal(actor_sect_id: String, target_sect_id: String, pact_type: String, acceptance: float, options: Dictionary, duration_days: int = 0) -> Dictionary:
	var roll: float = _get_roll(options)
	if roll > acceptance:
		var rejected: Dictionary = {"success": true, "accepted": false, "acceptance": acceptance, "roll": roll, "message": "%s拒绝了%s提议。" % [_sect_name(target_sect_id), _pact_type_name(pact_type)]}
		_record_pact_history("外交提议", rejected["message"], [actor_sect_id, target_sect_id], rejected)
		return rejected
	var pact: DiplomaticPactData = _create_pact(pact_type, [actor_sect_id, target_sect_id], duration_days)
	var relation := _get_relation_runtime(actor_sect_id, target_sect_id)
	relation.treaties.append(pact.pact_id)
	relation.status = pact_type if pact_type != "non_aggression" else _derive_basic_status(relation.value)
	_store_relation(relation)
	var accepted: Dictionary = {"success": true, "accepted": true, "acceptance": acceptance, "roll": roll, "pact": pact.to_dictionary(), "message": "%s与%s建立%s。" % [_sect_name(actor_sect_id), _sect_name(target_sect_id), _pact_type_name(pact_type)]}
	_record_pact_history("外交契约", accepted["message"], [actor_sect_id, target_sect_id], accepted)
	return accepted


func _create_pact(pact_type: String, member_ids: Array[String], duration_days: int = 0, terms: Dictionary = {}) -> DiplomaticPactData:
	var pact := DiplomaticPactData.new()
	pact.pact_id = "pact_%05d" % _next_pact_number
	_next_pact_number += 1
	pact.pact_type = pact_type
	pact.member_ids = member_ids.duplicate()
	pact.started_date = _current_date()
	pact.expires_on_ordinal = _date_ordinal(pact.started_date) + duration_days if duration_days > 0 else 0
	pact.terms = terms.duplicate(true)
	WorldDataManager.diplomatic_pacts.append(pact.to_dictionary())
	return pact


func _end_pair_pacts(sect_a_id: String, sect_b_id: String, types: Array[String], reason: String) -> void:
	for pact in get_active_pacts():
		if str(pact.get("pact_type", "")) in types and sect_a_id in pact.get("member_ids", []) and sect_b_id in pact.get("member_ids", []):
			_end_pact(str(pact.get("pact_id", "")), reason)


func _end_pact(pact_id: String, reason: String) -> bool:
	var index: int = _find_pact_index(pact_id)
	if index < 0:
		return false
	var pact := DiplomaticPactData.from_dictionary(WorldDataManager.diplomatic_pacts[index])
	if pact.status != "active":
		return false
	pact.status = reason
	pact.ended_date = _current_date()
	WorldDataManager.diplomatic_pacts[index] = pact.to_dictionary()
	return true


func _get_active_pair_pact(sect_a_id: String, sect_b_id: String, types: Array[String]) -> Dictionary:
	for pact in get_active_pacts():
		if str(pact.get("pact_type", "")) in types and sect_a_id in pact.get("member_ids", []) and sect_b_id in pact.get("member_ids", []):
			return pact
	return {}


func _has_active_pair_pact(sect_a_id: String, sect_b_id: String, types: Array[String]) -> bool:
	return not _get_active_pair_pact(sect_a_id, sect_b_id, types).is_empty()


func _derive_relation_status(relation: RelationData) -> String:
	var priority: Array[String] = ["war", "vassal", "alliance", "truce"]
	for pact_type in priority:
		if _has_active_pair_pact(relation.sect_a_id, relation.sect_b_id, [pact_type]):
			return pact_type
	return _derive_basic_status(relation.value)


func _refresh_all_relation_statuses() -> void:
	for index in range(WorldDataManager.relations.size()):
		var relation := RelationData.from_dictionary(WorldDataManager.relations[index])
		relation.status = _derive_relation_status(relation)
		WorldDataManager.relations[index] = relation.to_dictionary()


func _refresh_relation_status(sect_a_id: String, sect_b_id: String) -> void:
	var relation := _get_relation_runtime(sect_a_id, sect_b_id)
	if relation == null:
		return
	relation.status = _derive_relation_status(relation)
	_store_relation(relation)


func _get_relation_runtime(sect_a_id: String, sect_b_id: String) -> RelationData:
	var data: Dictionary = get_relation(sect_a_id, sect_b_id)
	return RelationData.from_dictionary(data) if not data.is_empty() else null


func _store_relation(relation: RelationData) -> void:
	var index: int = _find_relation_index(relation.sect_a_id, relation.sect_b_id)
	if index < 0:
		return
	WorldDataManager.relations[index] = relation.to_dictionary()
	_sync_player_relation_cache(relation)
	relation_changed.emit(relation.to_dictionary())


func _find_pact_index(pact_id: String) -> int:
	for index in range(WorldDataManager.diplomatic_pacts.size()):
		if str(WorldDataManager.diplomatic_pacts[index].get("pact_id", "")) == pact_id:
			return index
	return -1


func _get_roll(options: Dictionary) -> float:
	return clampf(float(options.get("_test_roll", GameState.random_float())), 0.0, 1.0) if OS.is_debug_build() else GameState.random_float()


func _record_pact_history(title: String, message: String, entity_ids: Array, data: Dictionary) -> void:
	GameHistoryManager.record_entry("diplomacy", title, message, entity_ids, data, _current_date())


func _sect_name(sect_id: String) -> String:
	return str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id))


func _pact_type_name(pact_type: String) -> String:
	return {"alliance": "联盟", "non_aggression": "互不侵犯", "vassal": "附属关系", "war": "战争", "truce": "停战"}.get(pact_type, pact_type)


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
