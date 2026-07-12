extends Node

signal construction_started(instance_data: Dictionary)
signal construction_completed(instance_data: Dictionary)

const MAX_CONCURRENT_CONSTRUCTION_PER_SECT: int = 1

var _next_instance_number: int = 1


func rebuild_runtime_state() -> void:
	var highest_number: int = 0
	for instance in WorldDataManager.building_instances:
		var number_text: String = str(instance.get("instance_id", "")).trim_prefix("building_instance_")
		if number_text.is_valid_int():
			highest_number = maxi(highest_number, number_text.to_int())
	_next_instance_number = highest_number + 1


func start_construction(sect_id: String, building_id: String) -> Dictionary:
	var definition: BuildingDefinition = BuildingRegistry.get_by_id(building_id)
	if definition == null:
		return _error("building_not_found", "建筑配置不存在。")
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	if sect.is_empty() or not bool(sect.get("is_active", true)):
		return _error("sect_not_found", "宗门不存在或已失效。")
	if _count_constructing(sect_id) >= MAX_CONCURRENT_CONSTRUCTION_PER_SECT:
		return _error("construction_limit", "当前已有建筑正在施工。")
	if not _prerequisites_met(sect_id, definition):
		return _error("prerequisite_missing", "尚未满足前置建筑要求。")

	var existing_index: int = _find_instance_index_by_definition(sect_id, building_id)
	var target_level: int = 1
	var build_slot_id: int = -1
	if existing_index >= 0:
		var existing: Dictionary = WorldDataManager.building_instances[existing_index]
		if str(existing.get("status", "")) != "active":
			return _error("already_constructing", "该建筑尚未建成。")
		target_level = int(existing.get("level", 1)) + 1
		if target_level > definition.max_level:
			return _error("max_level", "建筑已达到最高等级。")
		build_slot_id = int(existing.get("build_slot_id", -1))
	else:
		build_slot_id = _find_available_build_slot(sect_id)
		if bool(sect.get("is_player", false)) and build_slot_id < 0:
			return _error("no_build_slot", "没有可用建设点。")

	var costs: Dictionary = get_construction_costs(definition, target_level)
	var missing: Dictionary = _get_missing_resources(sect_id, costs)
	if not missing.is_empty():
		var result: Dictionary = _error("resources_insufficient", "建设资源不足。")
		result["missing_resources"] = missing
		result["costs"] = costs
		return result
	if not _deduct_costs(sect_id, costs):
		return _error("resource_update_failed", "建设资源扣除失败。")

	var instance: BuildingInstance
	if existing_index >= 0:
		instance = BuildingInstance.from_dictionary(WorldDataManager.building_instances[existing_index])
	else:
		instance = BuildingInstance.new()
		instance.instance_id = "building_instance_%05d" % _next_instance_number
		_next_instance_number += 1
		instance.definition_id = building_id
		instance.sect_id = sect_id
		instance.level = 0
		instance.build_slot_id = build_slot_id
	instance.target_level = target_level
	instance.status = "constructing"
	instance.remaining_days = get_construction_days(definition, target_level)
	instance.started_date = _current_date()
	instance.completed_date = {}
	if existing_index >= 0:
		WorldDataManager.building_instances[existing_index] = instance.to_dictionary()
	else:
		WorldDataManager.building_instances.append(instance.to_dictionary())
		if build_slot_id >= 0:
			WorldDataManager.update_build_slot(build_slot_id, {
				"is_empty": false,
				"building_instance_id": instance.instance_id,
			})
	var view: Dictionary = _build_instance_view(instance)
	view["costs"] = costs
	construction_started.emit(view)
	return {"success": true, "code": "started", "message": "%s开始建设。" % definition.display_name, "instance": view, "costs": costs}


func daily_update(date: Dictionary) -> Dictionary:
	var progressed: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	for index in range(WorldDataManager.building_instances.size()):
		var instance := BuildingInstance.from_dictionary(WorldDataManager.building_instances[index])
		if instance.status != "constructing":
			continue
		instance.remaining_days = maxi(0, instance.remaining_days - 1)
		if instance.remaining_days == 0:
			instance.status = "active"
			instance.level = instance.target_level
			instance.completed_date = date.duplicate(true)
			_register_completed_building(instance)
			var completed_view: Dictionary = _build_instance_view(instance)
			completed.append(completed_view)
			construction_completed.emit(completed_view)
			GameHistoryManager.record_entry(
				"building_completed",
				"建筑完成",
				"%s的%s已建成，当前等级%d。" % [
					str(WorldDataManager.get_sect_by_id(instance.sect_id).get("sect_name", instance.sect_id)),
					str(completed_view.get("display_name", instance.definition_id)),
					instance.level,
				],
				[instance.sect_id, instance.instance_id],
				completed_view,
				date
			)
		WorldDataManager.building_instances[index] = instance.to_dictionary()
		progressed.append(_build_instance_view(instance))
	return {"progressed": progressed, "completed": completed}


func get_buildings_by_sect_id(sect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_data in WorldDataManager.get_building_instances_by_sect_id(sect_id):
		result.append(_build_instance_view(BuildingInstance.from_dictionary(instance_data)))
	return result


func get_construction_costs(definition: BuildingDefinition, target_level: int) -> Dictionary:
	var multiplier: float = 1.0 + 0.5 * float(maxi(0, target_level - 1))
	var costs: Dictionary = {}
	for resource_key in definition.construction_costs:
		costs[resource_key] = ceili(float(definition.construction_costs[resource_key]) * multiplier)
	return costs


func get_construction_days(definition: BuildingDefinition, target_level: int) -> int:
	return maxi(1, ceili(float(definition.construction_days) * (1.0 + 0.25 * float(maxi(0, target_level - 1)))))


func _register_completed_building(instance: BuildingInstance) -> void:
	var sect: Dictionary = WorldDataManager.get_sect_by_id(instance.sect_id)
	var building_ids: Array = sect.get("buildings", []).duplicate()
	if instance.instance_id not in building_ids:
		building_ids.append(instance.instance_id)
	WorldDataManager.update_sect_data(instance.sect_id, "buildings", building_ids)


func _build_instance_view(instance: BuildingInstance) -> Dictionary:
	var definition: BuildingDefinition = BuildingRegistry.get_by_id(instance.definition_id)
	var data: Dictionary = instance.to_dictionary()
	data["display_name"] = definition.display_name if definition != null else instance.definition_id
	data["description"] = definition.description if definition != null else ""
	return data


func _count_constructing(sect_id: String) -> int:
	var count: int = 0
	for instance in WorldDataManager.get_building_instances_by_sect_id(sect_id):
		if str(instance.get("status", "")) == "constructing":
			count += 1
	return count


func _find_instance_index_by_definition(sect_id: String, building_id: String) -> int:
	for index in range(WorldDataManager.building_instances.size()):
		var instance: Dictionary = WorldDataManager.building_instances[index]
		if str(instance.get("sect_id", "")) == sect_id and str(instance.get("definition_id", "")) == building_id:
			return index
	return -1


func _prerequisites_met(sect_id: String, definition: BuildingDefinition) -> bool:
	for prerequisite_id in definition.prerequisites:
		var index: int = _find_instance_index_by_definition(sect_id, prerequisite_id)
		if index < 0 or str(WorldDataManager.building_instances[index].get("status", "")) != "active":
			return false
	return true


func _find_available_build_slot(sect_id: String) -> int:
	for slot in WorldDataManager.get_build_slots_by_sect_id(sect_id):
		if bool(slot.get("is_empty", true)):
			return int(slot.get("slot_id", -1))
	return -1


func _get_missing_resources(sect_id: String, costs: Dictionary) -> Dictionary:
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var missing: Dictionary = {}
	for resource_key in costs:
		var required: int = int(costs[resource_key])
		var available: int = int(resources.get(resource_key, 0))
		if available < required:
			missing[resource_key] = required - available
	return missing


func _deduct_costs(sect_id: String, costs: Dictionary) -> bool:
	var applied: Dictionary = {}
	for resource_key in costs:
		var amount: int = int(costs[resource_key])
		if not WorldDataManager.update_sect_resource(sect_id, str(resource_key), -amount):
			for applied_key in applied:
				WorldDataManager.update_sect_resource(sect_id, str(applied_key), int(applied[applied_key]))
			return false
		applied[resource_key] = amount
	return true


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
