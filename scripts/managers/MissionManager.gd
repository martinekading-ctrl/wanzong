extends Node

signal mission_started(instance_data: Dictionary)
signal mission_completed(result: Dictionary)

var _next_team_number: int = 1
var _next_mission_number: int = 1


func rebuild_runtime_state() -> void:
	_next_team_number = _next_number_from_records(WorldDataManager.expedition_teams, "team_id", "expedition_team_")
	_next_mission_number = _next_number_from_records(WorldDataManager.mission_instances, "instance_id", "mission_instance_")


func create_team(sect_id: String, disciple_ids: Array) -> Dictionary:
	var normalized_ids: Array[String] = []
	for raw_id in disciple_ids:
		var disciple_id: String = str(raw_id)
		if disciple_id == "" or disciple_id in normalized_ids:
			continue
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
		if disciple == null or disciple.sect_id != sect_id or disciple.is_deployed or _is_disciple_reserved(disciple_id):
			return _error("disciple_unavailable", "弟子不可用于当前队伍：" + disciple_id)
		if disciple.health <= 0:
			return _error("disciple_injured", "弟子健康不足：" + disciple_id)
		normalized_ids.append(disciple_id)
	if normalized_ids.is_empty():
		return _error("empty_team", "队伍至少需要一名弟子。")
	var team := ExpeditionTeam.new()
	team.team_id = "expedition_team_%05d" % _next_team_number
	_next_team_number += 1
	team.sect_id = sect_id
	team.disciple_ids = normalized_ids
	WorldDataManager.expedition_teams.append(team.to_dictionary())
	return {"success": true, "team": team.to_dictionary()}


func start_mission(team_id: String, mission_id: String, options: Dictionary = {}) -> Dictionary:
	var team_index: int = _find_team_index(team_id)
	if team_index < 0:
		return _error("team_not_found", "未找到派遣队伍。")
	var team := ExpeditionTeam.from_dictionary(WorldDataManager.expedition_teams[team_index])
	if team.status != "ready":
		return _error("team_unavailable", "队伍当前不可派遣。")
	var definition: MissionDefinition = MissionRegistry.get_by_id(mission_id)
	if definition == null:
		return _error("mission_not_found", "任务配置不存在。")
	if team.disciple_ids.size() < definition.min_team_size or team.disciple_ids.size() > definition.max_team_size:
		return _error("team_size", "队伍人数不符合任务要求。")
	if _count_active_missions(team.sect_id) >= ModifierManager.get_mission_capacity(team.sect_id):
		return _error("mission_capacity", "宗门同时进行的任务已达上限。")
	var missing: Dictionary = _get_missing_resources(team.sect_id, definition.costs)
	if not missing.is_empty():
		var missing_result: Dictionary = _error("resources_insufficient", "任务资源不足。")
		missing_result["missing_resources"] = missing
		return missing_result
	if not _deduct_resources(team.sect_id, definition.costs):
		return _error("resource_update_failed", "任务成本扣除失败。")

	var instance := MissionInstance.new()
	instance.instance_id = "mission_instance_%05d" % _next_mission_number
	_next_mission_number += 1
	instance.definition_id = mission_id
	instance.sect_id = team.sect_id
	instance.team_id = team.team_id
	instance.remaining_days = definition.duration_days
	instance.started_date = _current_date()
	instance.success_chance = calculate_success_chance(team, definition, options)
	if OS.is_debug_build() and options.has("_test_roll"):
		instance.test_roll = clampf(float(options["_test_roll"]), 0.0, 1.0)
	team.status = "deployed"
	team.mission_instance_id = instance.instance_id
	WorldDataManager.expedition_teams[team_index] = team.to_dictionary()
	_set_team_deployed(team, true)
	WorldDataManager.mission_instances.append(instance.to_dictionary())
	var view: Dictionary = _build_mission_view(instance)
	mission_started.emit(view)
	return {"success": true, "message": "%s已出发。" % definition.display_name, "mission": view, "costs": definition.costs.duplicate(true)}


func create_and_start_mission(sect_id: String, disciple_ids: Array, mission_id: String, options: Dictionary = {}) -> Dictionary:
	var team_result: Dictionary = create_team(sect_id, disciple_ids)
	if not bool(team_result.get("success", false)):
		return team_result
	var team_id: String = str(team_result.get("team", {}).get("team_id", ""))
	var start_result: Dictionary = start_mission(team_id, mission_id, options)
	if not bool(start_result.get("success", false)):
		disband_team(team_id)
	return start_result


func disband_team(team_id: String) -> bool:
	var index: int = _find_team_index(team_id)
	if index < 0 or str(WorldDataManager.expedition_teams[index].get("status", "")) != "ready":
		return false
	WorldDataManager.expedition_teams.remove_at(index)
	return true


func daily_update(date: Dictionary) -> Dictionary:
	var progressed: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	for index in range(WorldDataManager.mission_instances.size()):
		var instance := MissionInstance.from_dictionary(WorldDataManager.mission_instances[index])
		if instance.status != "active":
			continue
		instance.remaining_days = maxi(0, instance.remaining_days - 1)
		if instance.remaining_days == 0:
			var result: Dictionary = _resolve_mission(instance, date)
			instance.status = "completed"
			instance.completed_date = date.duplicate(true)
			instance.result = result.duplicate(true)
			completed.append(result)
			mission_completed.emit(result)
		WorldDataManager.mission_instances[index] = instance.to_dictionary()
		progressed.append(_build_mission_view(instance))
	return {"progressed": progressed, "completed": completed}


func calculate_success_chance(team: ExpeditionTeam, definition: MissionDefinition, options: Dictionary = {}) -> float:
	var total_power: int = 0
	var total_talent: int = 0
	var total_realm_order: int = 0
	var valid_count: int = 0
	for disciple_id in team.disciple_ids:
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
		if disciple == null:
			continue
		total_power += disciple.combat_power
		total_talent += disciple.talent + disciple.potential
		var realm: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
		total_realm_order += realm.order if realm != null else 0
		valid_count += 1
	if valid_count == 0:
		return 0.05
	var power_bonus: float = minf(0.25, float(total_power) / 8000.0)
	var aptitude_bonus: float = minf(0.15, float(total_talent) / float(valid_count) / 1000.0)
	var realm_bonus: float = minf(0.15, float(total_realm_order) / float(valid_count) * 0.015)
	var terrain_bonus: float = float(options.get("terrain_bonus", 0.0))
	return clampf(definition.base_success_rate - definition.difficulty + power_bonus + aptitude_bonus + realm_bonus + terrain_bonus, 0.05, 0.95)


func get_active_missions(sect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_data in WorldDataManager.mission_instances:
		if str(instance_data.get("sect_id", "")) == sect_id and str(instance_data.get("status", "")) == "active":
			result.append(_build_mission_view(MissionInstance.from_dictionary(instance_data)))
	return result


func get_all_missions(sect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_data in WorldDataManager.mission_instances:
		if str(instance_data.get("sect_id", "")) == sect_id:
			result.append(_build_mission_view(MissionInstance.from_dictionary(instance_data)))
	return result


func _resolve_mission(instance: MissionInstance, date: Dictionary) -> Dictionary:
	var definition: MissionDefinition = MissionRegistry.get_by_id(instance.definition_id)
	var team_index: int = _find_team_index(instance.team_id)
	if definition == null or team_index < 0:
		push_warning("任务结算状态损坏：%s" % instance.instance_id)
		return {
			"instance_id": instance.instance_id,
			"definition_id": instance.definition_id,
			"sect_id": instance.sect_id,
			"success": false,
			"message": "任务配置或队伍数据缺失，无法完成结算。",
		}
	var team := ExpeditionTeam.from_dictionary(WorldDataManager.expedition_teams[team_index])
	var roll: float = instance.test_roll if instance.test_roll >= 0.0 else GameState.random_float()
	var success: bool = roll <= instance.success_chance
	var rewards: Dictionary = {}
	var injuries: Array[Dictionary] = []
	var effect_results: Array[Dictionary] = []
	var discoveries: Array = []
	if success:
		for resource_key in definition.rewards:
			var amount: int = int(definition.rewards[resource_key])
			WorldDataManager.update_sect_resource(instance.sect_id, str(resource_key), amount)
			rewards[resource_key] = amount
		for effect in definition.result_effects:
			effect_results.append(_apply_result_effect(instance.sect_id, effect))
		discoveries = definition.discoveries.duplicate(true)
	else:
		injuries = _apply_failure_injuries(team, definition.risk)
	team.status = "returned"
	team.mission_instance_id = ""
	WorldDataManager.expedition_teams[team_index] = team.to_dictionary()
	_set_team_deployed(team, false)
	var result: Dictionary = {
		"instance_id": instance.instance_id,
		"definition_id": definition.id,
		"mission_type": definition.mission_type,
		"display_name": definition.display_name,
		"sect_id": instance.sect_id,
		"team_id": team.team_id,
		"disciple_ids": team.disciple_ids.duplicate(),
		"success": success,
		"success_chance": instance.success_chance,
		"roll": roll,
		"rewards": rewards,
		"injuries": injuries,
		"effects": effect_results,
		"discoveries": discoveries,
		"relation_changes": [],
		"message": "%s成功完成。" % definition.display_name if success else "%s执行失败，队伍带伤返回。" % definition.display_name,
	}
	GameHistoryManager.record_entry(
		"mission_result", "任务结果", str(result["message"]), [instance.sect_id, instance.instance_id] + team.disciple_ids, result, date
	)
	EventManager.daily_update({"sect_id": instance.sect_id, "date": date, "mission_result": {"mission_id": definition.id, "result": "success" if success else "failed", "instance_id": instance.instance_id}})
	return result


func _apply_failure_injuries(team: ExpeditionTeam, risk: float) -> Array[Dictionary]:
	var injuries: Array[Dictionary] = []
	for index in range(team.disciple_ids.size()):
		if index > 0 and GameState.random_float() > risk:
			continue
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(team.disciple_ids[index])
		if disciple == null:
			continue
		var health_before: int = disciple.health
		var loss: int = maxi(5, roundi(risk * 30.0))
		disciple.health = maxi(1, disciple.health - loss)
		DiscipleManager.sync_disciple_state(disciple)
		injuries.append({"disciple_id": disciple.id, "health_before": health_before, "health_after": disciple.health})
	return injuries


func _apply_result_effect(sect_id: String, effect: Dictionary) -> Dictionary:
	var effect_type: String = str(effect.get("type", ""))
	var success: bool = false
	match effect_type:
		"sect_field_delta":
			var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
			var key: String = str(effect.get("key", ""))
			success = WorldDataManager.update_sect_data(sect_id, key, int(sect.get(key, 0)) + int(effect.get("amount", 0)))
		"recruit_disciple":
			var amount: int = int(effect.get("amount", 1))
			success = true
			for _index in range(amount):
				if DiscipleManager.create_disciple(sect_id, "寻访所得弟子") == null:
					success = false
	return {"type": effect_type, "success": success, "effect": effect.duplicate(true)}


func _set_team_deployed(team: ExpeditionTeam, deployed: bool) -> void:
	for disciple_id in team.disciple_ids:
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
		if disciple == null:
			continue
		disciple.is_deployed = deployed
		disciple.team_id = team.team_id if deployed else ""
		DiscipleManager.sync_disciple_state(disciple)


func _build_mission_view(instance: MissionInstance) -> Dictionary:
	var definition: MissionDefinition = MissionRegistry.get_by_id(instance.definition_id)
	var data: Dictionary = instance.to_dictionary()
	data["display_name"] = definition.display_name if definition != null else instance.definition_id
	data["mission_type"] = definition.mission_type if definition != null else ""
	return data


func _count_active_missions(sect_id: String) -> int:
	return get_active_missions(sect_id).size()


func _is_disciple_reserved(disciple_id: String) -> bool:
	for team in WorldDataManager.expedition_teams:
		if str(team.get("status", "")) in ["ready", "deployed"] and disciple_id in team.get("disciple_ids", []):
			return true
	return false


func _find_team_index(team_id: String) -> int:
	for index in range(WorldDataManager.expedition_teams.size()):
		if str(WorldDataManager.expedition_teams[index].get("team_id", "")) == team_id:
			return index
	return -1


func _get_missing_resources(sect_id: String, costs: Dictionary) -> Dictionary:
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var missing: Dictionary = {}
	for key in costs:
		if int(resources.get(key, 0)) < int(costs[key]):
			missing[key] = int(costs[key]) - int(resources.get(key, 0))
	return missing


func _deduct_resources(sect_id: String, costs: Dictionary) -> bool:
	var applied: Dictionary = {}
	for key in costs:
		if not WorldDataManager.update_sect_resource(sect_id, str(key), -int(costs[key])):
			for applied_key in applied:
				WorldDataManager.update_sect_resource(sect_id, str(applied_key), int(applied[applied_key]))
			return false
		applied[key] = int(costs[key])
	return true


func _next_number_from_records(records: Array, key: String, prefix: String) -> int:
	var highest: int = 0
	for record in records:
		var text: String = str(record.get(key, "")).trim_prefix(prefix)
		if text.is_valid_int():
			highest = maxi(highest, text.to_int())
	return highest + 1


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
