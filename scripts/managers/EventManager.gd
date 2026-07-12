extends Node

signal event_triggered(event_data: Dictionary)
signal event_resolved(result: Dictionary)

const EVENT_DIRECTORY := "res://configs/events"

var _definitions: Dictionary = {}
var _next_instance_number: int = 1


func _ready() -> void:
	reload_definitions()


func reset() -> void:
	_next_instance_number = 1
	WorldDataManager.event_instances.clear()
	WorldDataManager.triggered_event_ids.clear()


func rebuild_runtime_state() -> void:
	var highest_number: int = 0
	for instance in WorldDataManager.event_instances:
		var number_text: String = str(instance.get("instance_id", "")).trim_prefix("event_instance_")
		if number_text.is_valid_int():
			highest_number = maxi(highest_number, number_text.to_int())
	_next_instance_number = highest_number + 1


func reload_definitions() -> void:
	_definitions.clear()
	var directory := DirAccess.open(EVENT_DIRECTORY)
	if directory == null:
		push_error("事件配置目录不存在：" + EVENT_DIRECTORY)
		return
	var file_names := PackedStringArray(directory.get_files())
	file_names.sort()
	for file_name in file_names:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var definition := load(EVENT_DIRECTORY.path_join(file_name)) as EventDefinition
		if definition == null or definition.id == "":
			push_warning("无法读取事件配置：" + file_name)
			continue
		if _definitions.has(definition.id):
			push_warning("事件ID重复：" + definition.id)
			continue
		_definitions[definition.id] = definition


func get_all_definitions() -> Array[EventDefinition]:
	var definitions: Array[EventDefinition] = []
	for definition in _definitions.values():
		definitions.append(definition as EventDefinition)
	definitions.sort_custom(func(a: EventDefinition, b: EventDefinition) -> bool: return a.id < b.id)
	return definitions


func get_definition(event_id: String) -> EventDefinition:
	return _definitions.get(event_id) as EventDefinition


func daily_update(context: Dictionary = {}) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	for definition in get_all_definitions():
		if definition.trigger_once and definition.id in WorldDataManager.triggered_event_ids:
			continue
		if _has_pending_instance(definition.id):
			continue
		var trigger_result: Dictionary = _evaluate_trigger(definition, context)
		if not bool(trigger_result.get("matched", false)):
			continue
		var event_context: Dictionary = context.duplicate(true)
		for key in trigger_result.get("context", {}):
			event_context[key] = trigger_result["context"][key]
		if not _conditions_match(definition.conditions, event_context):
			continue
		var instance: EventInstance = _create_instance(definition, event_context)
		var event_data: Dictionary = _build_event_view(instance, definition)
		triggered.append(event_data)
		event_triggered.emit(event_data)
	return triggered


func get_pending_events() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for instance_data in WorldDataManager.event_instances:
		if str(instance_data.get("status", "")) != "pending":
			continue
		var definition: EventDefinition = get_definition(str(instance_data.get("definition_id", "")))
		if definition != null:
			pending.append(_build_event_view(EventInstance.from_dictionary(instance_data), definition))
	return pending


func resolve_event(instance_id: String, option_id: String) -> Dictionary:
	var index: int = _find_instance_index(instance_id)
	if index < 0:
		return _resolution_error(instance_id, "instance_not_found", "未找到事件实例。")
	var instance := EventInstance.from_dictionary(WorldDataManager.event_instances[index])
	if instance.status != "pending":
		return _resolution_error(instance_id, "already_resolved", "事件已经处理。")
	var definition: EventDefinition = get_definition(instance.definition_id)
	if definition == null:
		return _resolution_error(instance_id, "definition_not_found", "事件配置缺失。")
	var option: Dictionary = _find_option(definition, option_id)
	if option.is_empty():
		return _resolution_error(instance_id, "option_not_found", "事件选项不存在。")
	var sect_id: String = str(instance.context.get("sect_id", "sect_001"))
	var costs: Dictionary = option.get("costs", {})
	var missing: Dictionary = _get_missing_resources(sect_id, costs)
	if not missing.is_empty():
		var error := _resolution_error(instance_id, "resources_insufficient", "事件选项资源不足。")
		error["missing_resources"] = missing
		return error
	if not _apply_resource_costs(sect_id, costs):
		return _resolution_error(instance_id, "resource_update_failed", "事件成本扣除失败。")

	var effect_results: Array[Dictionary] = []
	for effect in option.get("effects", []):
		effect_results.append(_apply_effect(effect, instance.context))
	var result: Dictionary = {
		"success": true,
		"code": "resolved",
		"instance_id": instance.instance_id,
		"definition_id": definition.id,
		"option_id": option_id,
		"message": str(option.get("result_text", "事件已处理。")),
		"costs": costs.duplicate(true),
		"effects": effect_results,
	}
	instance.status = "resolved"
	instance.selected_option_id = option_id
	instance.result = result.duplicate(true)
	WorldDataManager.event_instances[index] = instance.to_dictionary()
	GameHistoryManager.record_entry(
		"major_event",
		definition.title,
		str(result.get("message", "")),
		_get_event_entity_ids(instance.context),
		result
	)
	event_resolved.emit(result)
	return result


func _evaluate_trigger(definition: EventDefinition, context: Dictionary) -> Dictionary:
	var trigger: Dictionary = definition.trigger
	var trigger_type: String = str(trigger.get("type", ""))
	match trigger_type:
		"daily_probability":
			var roll: float = GameState.random_float()
			var test_rolls: Dictionary = context.get("_test_rolls", {})
			if OS.is_debug_build() and test_rolls.has(definition.id):
				roll = float(test_rolls[definition.id])
			return {"matched": roll <= float(trigger.get("chance", 0.0)), "context": {"trigger_roll": roll}}
		"fixed_date":
			var date: Dictionary = context.get("date", {})
			return {"matched": (
				int(date.get("year", -1)) == int(trigger.get("year", -2))
				and int(date.get("month", -1)) == int(trigger.get("month", -2))
				and int(date.get("day", -1)) == int(trigger.get("day", -2))
			), "context": {}}
		"resource_threshold":
			var sect_id: String = str(context.get("sect_id", "sect_001"))
			var key: String = str(trigger.get("resource_key", ""))
			var value: int = int(WorldDataManager.get_sect_resources(sect_id).get(key, 0))
			return {"matched": _compare(value, str(trigger.get("operator", "<=")), trigger.get("value", 0)), "context": {"resource_key": key, "resource_value": value}}
		"disciple_state":
			return _evaluate_disciple_trigger(trigger, context)
		"sect_relation":
			var target_id: String = str(trigger.get("sect_id", ""))
			var relation: Dictionary = DiplomacyManager.get_relation("sect_001", target_id)
			return {"matched": str(relation.get("status", "")) == str(trigger.get("relation", "")), "context": {"entity_id": target_id, "relation_value": int(relation.get("value", 0))}}
		"mission_result":
			var mission: Dictionary = context.get("mission_result", {})
			var mission_context: Dictionary = mission.duplicate(true)
			mission_context["mission_id"] = str(mission.get("mission_id", ""))
			return {"matched": str(mission.get("result", "")) == str(trigger.get("result", "")), "context": mission_context}
	return {"matched": false, "context": {}}


func _evaluate_disciple_trigger(trigger: Dictionary, context: Dictionary) -> Dictionary:
	var sect_id: String = str(context.get("sect_id", "sect_001"))
	var field: String = str(trigger.get("field", ""))
	var expected: Variant = trigger.get("value")
	var operator: String = str(trigger.get("operator", "=="))
	var minimum_count: int = int(trigger.get("minimum_count", 1))
	var matches: Array[String] = []
	for disciple in WorldDataManager.get_disciples_by_sect_id(sect_id):
		if _compare(disciple.get(field), operator, expected):
			matches.append(str(disciple.get("disciple_id", "")))
	return {"matched": matches.size() >= minimum_count, "context": {"entity_id": matches[0] if not matches.is_empty() else "", "matching_disciple_ids": matches}}


func _conditions_match(conditions: Array[Dictionary], context: Dictionary) -> bool:
	for condition in conditions:
		var condition_type: String = str(condition.get("type", ""))
		match condition_type:
			"resource":
				var storage: Dictionary = WorldDataManager.get_sect_resources(str(context.get("sect_id", "sect_001")))
				if not _compare(storage.get(str(condition.get("key", "")), 0), str(condition.get("operator", ">=")), condition.get("value", 0)):
					return false
			"context":
				if not _compare(context.get(str(condition.get("key", ""))), str(condition.get("operator", "==")), condition.get("value")):
					return false
	return true


func _create_instance(definition: EventDefinition, context: Dictionary) -> EventInstance:
	var instance := EventInstance.new()
	instance.instance_id = "event_instance_%05d" % _next_instance_number
	_next_instance_number += 1
	instance.definition_id = definition.id
	instance.created_date = context.get("date", {}).duplicate(true)
	instance.context = context.duplicate(true)
	WorldDataManager.event_instances.append(instance.to_dictionary())
	if definition.trigger_once:
		WorldDataManager.triggered_event_ids.append(definition.id)
	return instance


func _build_event_view(instance: EventInstance, definition: EventDefinition) -> Dictionary:
	return {
		"instance_id": instance.instance_id,
		"definition_id": definition.id,
		"title": definition.title,
		"description": definition.description,
		"category": definition.category,
		"status": instance.status,
		"created_date": instance.created_date.duplicate(true),
		"context": instance.context.duplicate(true),
		"options": definition.options.duplicate(true),
	}


func _apply_effect(effect: Dictionary, context: Dictionary) -> Dictionary:
	var effect_type: String = str(effect.get("type", ""))
	var result: Dictionary = {"type": effect_type, "success": false}
	match effect_type:
		"resource_delta":
			result["success"] = WorldDataManager.update_sect_resource(str(context.get("sect_id", "sect_001")), str(effect.get("key", "")), int(effect.get("amount", 0)))
		"sect_field_delta":
			var sect_id: String = str(context.get("sect_id", "sect_001"))
			var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
			var key: String = str(effect.get("key", ""))
			result["success"] = WorldDataManager.update_sect_data(sect_id, key, int(sect.get(key, 0)) + int(effect.get("amount", 0)))
		"disciple_field_delta":
			var disciple_id: String = str(context.get("entity_id", ""))
			var disciple: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
			var key: String = str(effect.get("key", ""))
			var value: int = int(disciple.get(key, 0)) + int(effect.get("amount", 0))
			if key in ["health", "loyalty", "mood"]:
				value = clampi(value, 1 if key == "health" else 0, 100)
			result["success"] = WorldDataManager.update_disciple_data(disciple_id, key, value)
			var runtime: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
			if runtime != null:
				if key == "health":
					runtime.health = value
				elif key == "loyalty":
					runtime.loyalty = value
				DiscipleManager.sync_disciple_state(runtime)
		"secret_realm_exploration":
			var exploration_result: Dictionary = SecretRealmManager.apply_exploration_choice(context, effect)
			result["success"] = bool(exploration_result.get("success", false))
			result["exploration_result"] = exploration_result
	result["effect"] = effect.duplicate(true)
	return result


func _get_missing_resources(sect_id: String, costs: Dictionary) -> Dictionary:
	var storage: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var missing: Dictionary = {}
	for key in costs:
		if int(storage.get(key, 0)) < int(costs[key]):
			missing[key] = int(costs[key]) - int(storage.get(key, 0))
	return missing


func _apply_resource_costs(sect_id: String, costs: Dictionary) -> bool:
	var applied: Dictionary = {}
	for key in costs:
		var amount: int = int(costs[key])
		if not WorldDataManager.update_sect_resource(sect_id, str(key), -amount):
			for applied_key in applied:
				WorldDataManager.update_sect_resource(sect_id, str(applied_key), int(applied[applied_key]))
			return false
		applied[key] = amount
	return true


func _find_option(definition: EventDefinition, option_id: String) -> Dictionary:
	for option in definition.options:
		if str(option.get("id", "")) == option_id:
			return option
	return {}


func _find_instance_index(instance_id: String) -> int:
	for index in range(WorldDataManager.event_instances.size()):
		if str(WorldDataManager.event_instances[index].get("instance_id", "")) == instance_id:
			return index
	return -1


func _has_pending_instance(definition_id: String) -> bool:
	for instance in WorldDataManager.event_instances:
		if str(instance.get("definition_id", "")) == definition_id and str(instance.get("status", "")) == "pending":
			return true
	return false


func _compare(left: Variant, operator: String, right: Variant) -> bool:
	match operator:
		"==": return left == right
		"!=": return left != right
		">": return float(left) > float(right)
		">=": return float(left) >= float(right)
		"<": return float(left) < float(right)
		"<=": return float(left) <= float(right)
	return false


func _resolution_error(instance_id: String, code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message, "instance_id": instance_id}


func _get_event_entity_ids(context: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key in ["sect_id", "entity_id", "mission_id"]:
		var entity_id: String = str(context.get(key, ""))
		if entity_id != "" and entity_id not in ids:
			ids.append(entity_id)
	return ids
