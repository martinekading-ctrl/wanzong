extends Node

signal secret_realm_updated(realm_data: Dictionary)


func initialize_world_state() -> void:
	if WorldDataManager.secret_realms.is_empty():
		for definition in SecretRealmRegistry.get_all():
			WorldDataManager.secret_realms.append({
				"realm_id": definition.id,
				"map_resource_id": definition.map_resource_id,
				"discovered": true,
				"current_depth": 0,
				"exploration_count": 0,
				"status": "discovered",
				"last_explored_date": {},
				"last_mission_instance_id": "",
			})
	_validate_states()


func rebuild_runtime_state() -> void:
	if WorldDataManager.secret_realms.is_empty():
		initialize_world_state()
	else:
		_validate_states()


func get_all_realms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in WorldDataManager.secret_realms:
		result.append(_build_view(state))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("level", 0)) < int(b.get("level", 0)))
	return result


func get_available_realms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for realm in get_all_realms():
		if bool(realm.get("discovered", false)) and str(realm.get("status", "")) != "cleared":
			result.append(realm)
	return result


func get_realm_by_id(realm_id: String) -> Dictionary:
	var index: int = _find_state_index(realm_id)
	return _build_view(WorldDataManager.secret_realms[index]) if index >= 0 else {}


func get_default_target_id() -> String:
	var available: Array[Dictionary] = get_available_realms()
	return str(available[0].get("realm_id", "")) if not available.is_empty() else ""


func can_explore(realm_id: String) -> bool:
	var realm: Dictionary = get_realm_by_id(realm_id)
	return not realm.is_empty() and bool(realm.get("discovered", false)) and str(realm.get("status", "")) != "cleared"


func record_mission_result(result: Dictionary, date: Dictionary) -> Dictionary:
	var realm_id: String = str(result.get("secret_realm_id", ""))
	var index: int = _find_state_index(realm_id)
	if index < 0:
		return {"success": false, "message": "未找到秘境状态。"}
	var state: Dictionary = WorldDataManager.secret_realms[index]
	state["exploration_count"] = int(state.get("exploration_count", 0)) + 1
	state["last_explored_date"] = date.duplicate(true)
	state["last_mission_instance_id"] = str(result.get("instance_id", ""))
	WorldDataManager.secret_realms[index] = state
	secret_realm_updated.emit(_build_view(state))
	return {"success": true, "realm": _build_view(state)}


func apply_exploration_choice(context: Dictionary, effect: Dictionary) -> Dictionary:
	var realm_id: String = str(context.get("secret_realm_id", ""))
	var index: int = _find_state_index(realm_id)
	if index < 0:
		return {"success": false, "message": "秘境探索目标不存在。"}
	var state: Dictionary = WorldDataManager.secret_realms[index]
	var definition: SecretRealmDefinition = SecretRealmRegistry.get_by_id(realm_id)
	if definition == null:
		return {"success": false, "message": "秘境配置不存在。"}
	var progress: int = maxi(0, int(effect.get("progress", 0)))
	state["current_depth"] = mini(definition.total_depth, int(state.get("current_depth", 0)) + progress)
	state["status"] = "cleared" if int(state["current_depth"]) >= definition.total_depth else "exploring"
	WorldDataManager.secret_realms[index] = state
	var rewards: Dictionary = {}
	for resource_key in effect.get("rewards", {}):
		var amount: int = int(effect["rewards"][resource_key])
		if WorldDataManager.update_sect_resource(str(context.get("sect_id", "sect_001")), str(resource_key), amount):
			rewards[resource_key] = amount
	var injuries: Array[Dictionary] = _apply_choice_injuries(
		context.get("disciple_ids", []),
		float(effect.get("injury_chance", 0.0)),
		int(effect.get("health_loss", 0))
	)
	var view: Dictionary = _build_view(state)
	var result: Dictionary = {
		"success": true,
		"realm_id": realm_id,
		"progress": progress,
		"current_depth": view.get("current_depth", 0),
		"total_depth": view.get("total_depth", 0),
		"status": view.get("status", ""),
		"rewards": rewards,
		"injuries": injuries,
	}
	GameHistoryManager.record_entry(
		"secret_realm",
		"秘境探索",
		"%s探索推进至%d/%d层。" % [definition.display_name, int(result["current_depth"]), definition.total_depth],
		[str(context.get("sect_id", "sect_001")), realm_id] + context.get("disciple_ids", []),
		result
	)
	secret_realm_updated.emit(view)
	return result


func _apply_choice_injuries(disciple_ids: Array, chance: float, health_loss: int) -> Array[Dictionary]:
	var injuries: Array[Dictionary] = []
	if chance <= 0.0 or health_loss <= 0:
		return injuries
	for disciple_id in disciple_ids:
		if GameState.random_float() > chance:
			continue
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(str(disciple_id))
		if disciple == null:
			continue
		var before: int = disciple.health
		disciple.health = maxi(1, disciple.health - health_loss)
		DiscipleManager.sync_disciple_state(disciple)
		injuries.append({"disciple_id": disciple.id, "health_before": before, "health_after": disciple.health})
	return injuries


func _build_view(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	var definition: SecretRealmDefinition = SecretRealmRegistry.get_by_id(str(state.get("realm_id", "")))
	if definition != null:
		result["display_name"] = definition.display_name
		result["description"] = definition.description
		result["level"] = definition.level
		result["total_depth"] = definition.total_depth
		result["base_risk"] = definition.base_risk
		result["terrain"] = definition.terrain
		result["recommended_power"] = definition.recommended_power
	return result


func _validate_states() -> void:
	for definition in SecretRealmRegistry.get_all():
		if _find_state_index(definition.id) < 0:
			WorldDataManager.secret_realms.append({
				"realm_id": definition.id,
				"map_resource_id": definition.map_resource_id,
				"discovered": true,
				"current_depth": 0,
				"exploration_count": 0,
				"status": "discovered",
				"last_explored_date": {},
				"last_mission_instance_id": "",
			})


func _find_state_index(realm_id: String) -> int:
	for index in range(WorldDataManager.secret_realms.size()):
		if str(WorldDataManager.secret_realms[index].get("realm_id", "")) == realm_id:
			return index
	return -1
