class_name WorldSectReferenceValidator
extends RefCounted

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")

## 只读检查世界状态中的宗门引用，避免被移除的开发宗门残留在存档或运行时数据中。
static func validate_world_state(world_state: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var valid_ids: Dictionary = {}
	for sect_data in world_state.get("sects", []):
		var sect: Dictionary = sect_data
		var sect_id := str(sect.get("sect_id", ""))
		if sect_id == "":
			errors.append("sects contains an empty sect_id")
		elif valid_ids.has(sect_id):
			errors.append("sects contains duplicate sect_id: " + sect_id)
		else:
			valid_ids[sect_id] = true
	for retired_id in WorldSectRoster.REMOVED_DEVELOPMENT_SECT_IDS:
		if valid_ids.has(retired_id):
			errors.append("sects contains removed development sect: " + retired_id)
	_validate_dictionary_keys(world_state.get("sect_resources", {}), "sect_resources", valid_ids, errors)
	_validate_dictionary_keys(world_state.get("ai_states", {}), "ai_states", valid_ids, errors)
	_validate_dictionary_keys(world_state.get("territory_states", {}), "territory_states", valid_ids, errors)
	_validate_dictionary_keys(world_state.get("sect_inventories", {}), "sect_inventories", valid_ids, errors)
	_validate_market_states(world_state.get("market_states", {}), valid_ids, errors)
	_validate_story_goals(world_state.get("story_goals", {}), valid_ids, errors)
	for index in range((world_state.get("disciples", []) as Array).size()):
		_validate_id(str((world_state["disciples"][index] as Dictionary).get("sect_id", "")), "disciples[%d].sect_id" % index, valid_ids, errors)
	for index in range((world_state.get("relations", []) as Array).size()):
		var relation: Dictionary = world_state["relations"][index]
		_validate_record_ids(relation, index, "relations", ["from_sect_id", "to_sect_id", "sect_id", "target_sect_id"], valid_ids, errors)
	for index in range((world_state.get("diplomatic_pacts", []) as Array).size()):
		_validate_record_ids(world_state["diplomatic_pacts"][index], index, "diplomatic_pacts", ["sect_id", "other_sect_id", "from_sect_id", "to_sect_id"], valid_ids, errors)
	for index in range((world_state.get("war_campaigns", []) as Array).size()):
		_validate_record_ids(world_state["war_campaigns"][index], index, "war_campaigns", ["attacker_sect_id", "defender_sect_id", "sect_id", "target_sect_id"], valid_ids, errors)
	return errors


static func _validate_dictionary_keys(values: Variant, path: String, valid_ids: Dictionary, errors: PackedStringArray) -> void:
	if not values is Dictionary:
		errors.append(path + " must be a Dictionary")
		return
	for sect_id in (values as Dictionary).keys():
		_validate_id(str(sect_id), path + "." + str(sect_id), valid_ids, errors)


static func _validate_record_ids(record_value: Variant, index: int, path: String, fields: Array[String], valid_ids: Dictionary, errors: PackedStringArray) -> void:
	if not record_value is Dictionary:
		errors.append("%s[%d] must be a Dictionary" % [path, index])
		return
	var record: Dictionary = record_value
	for field in fields:
		if record.has(field):
			_validate_id(str(record[field]), "%s[%d].%s" % [path, index, field], valid_ids, errors)


static func _validate_market_states(values: Variant, valid_ids: Dictionary, errors: PackedStringArray) -> void:
	if not values is Dictionary:
		errors.append("market_states must be a Dictionary")
		return
	for market_id in (values as Dictionary).keys():
		var market: Dictionary = (values as Dictionary)[market_id]
		var owner_id := str(market.get("owner_sect_id", str(market_id).trim_prefix("market_")))
		_validate_id(owner_id, "market_states.%s.owner_sect_id" % str(market_id), valid_ids, errors)


static func _validate_story_goals(values: Variant, valid_ids: Dictionary, errors: PackedStringArray) -> void:
	if not values is Dictionary:
		errors.append("story_goals must be a Dictionary")
		return
	for goal_id in (values as Dictionary).keys():
		var goal: Dictionary = (values as Dictionary)[goal_id]
		for field in ["sect_id", "owner_sect_id", "target_sect_id"]:
			if goal.has(field):
				_validate_id(str(goal[field]), "story_goals.%s.%s" % [str(goal_id), field], valid_ids, errors)


static func _validate_id(sect_id: String, path: String, valid_ids: Dictionary, errors: PackedStringArray) -> void:
	if sect_id == "":
		return
	if not valid_ids.has(sect_id):
		errors.append(path + " references invalid sect id: " + sect_id)
