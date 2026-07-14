class_name WorldSectReferenceValidator
extends RefCounted

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")

## 存档宗门引用的单一校验入口。这里仅检查真实持久化字段，绝不把通用 ID
## （例如资源 ID、市场 ID、任务 ID）误当成宗门 ID。
static func validate_world_state(world_state: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var valid_ids := _collect_sect_ids(world_state, errors)
	if valid_ids.is_empty():
		return errors
	_validate_exact_keys(world_state.get("sect_resources", {}), "sect_resources", WorldSectRoster.ACTIVE_SECT_IDS, errors)
	_validate_exact_keys(world_state.get("ai_states", {}), "ai_states", WorldSectRoster.AI_SECT_IDS, errors)
	_validate_exact_keys(world_state.get("territory_states", {}), "territory_states", WorldSectRoster.ACTIVE_SECT_IDS, errors)
	_validate_exact_keys(world_state.get("sect_inventories", {}), "sect_inventories", WorldSectRoster.ACTIVE_SECT_IDS, errors)
	_validate_references(world_state, valid_ids, errors, false)
	return errors


## 迁移前专用扫描：与正式验证共用同一遍历表，只把 removed IDs 作为目标。
static func find_removed_development_sect_references(world_state: Dictionary) -> PackedStringArray:
	var findings := PackedStringArray()
	var removed := {}
	for sect_id in WorldSectRoster.REMOVED_DEVELOPMENT_SECT_IDS:
		removed[sect_id] = true
	_validate_references(world_state, removed, findings, true)
	return findings


static func _collect_sect_ids(world_state: Dictionary, errors: PackedStringArray) -> Dictionary:
	var ids := {}
	var player_count := 0
	for index in range((world_state.get("sects", []) as Array).size()):
		var record: Variant = world_state["sects"][index]
		if not record is Dictionary:
			errors.append("sects[%d] must be a Dictionary" % index)
			continue
		var sect_id := str((record as Dictionary).get("sect_id", ""))
		if sect_id == "":
			errors.append("sects[%d].sect_id is required" % index)
		elif ids.has(sect_id):
			errors.append("sects contains duplicate sect_id: " + sect_id)
		else:
			ids[sect_id] = true
		if bool((record as Dictionary).get("is_player", false)):
			player_count += 1
			if sect_id != WorldSectRoster.PLAYER_SECT_ID:
				errors.append("sects[%d].is_player must be %s" % [index, WorldSectRoster.PLAYER_SECT_ID])
	if ids.size() != WorldSectRoster.expected_sect_count():
		errors.append("sects must contain exactly five active initial sects")
	for sect_id in WorldSectRoster.ACTIVE_SECT_IDS:
		if not ids.has(sect_id):
			errors.append("sects missing active sect: " + sect_id)
	for sect_id in WorldSectRoster.REMOVED_DEVELOPMENT_SECT_IDS:
		if ids.has(sect_id):
			errors.append("sects contains removed development sect: " + sect_id)
	if player_count != 1:
		errors.append("sects must contain exactly one player sect")
	return ids


static func _validate_exact_keys(value: Variant, path: String, expected_ids: Array[String], errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append(path + " must be a Dictionary")
		return
	var values: Dictionary = value
	var expected := {}
	for sect_id in expected_ids:
		expected[sect_id] = true
	for key in values.keys():
		if not expected.has(str(key)):
			errors.append("%s.%s is not an active expected key" % [path, str(key)])
	for sect_id in expected_ids:
		if not values.has(sect_id):
			errors.append("%s missing key: %s" % [path, sect_id])


static func _validate_references(world_state: Dictionary, ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	# Dictionary keys owned by sects.
	_validate_array_records(world_state.get("sects", []), "sects", ["sect_id"], ids, messages, removed_only)
	_validate_sect_dictionary_keys(world_state.get("sect_resources", {}), "sect_resources", ids, messages, removed_only)
	_validate_sect_dictionary_keys(world_state.get("ai_states", {}), "ai_states", ids, messages, removed_only)
	_validate_sect_dictionary_keys(world_state.get("territory_states", {}), "territory_states", ids, messages, removed_only)
	_validate_sect_dictionary_keys(world_state.get("sect_inventories", {}), "sect_inventories", ids, messages, removed_only)
	_validate_keyed_records(world_state.get("territory_states", {}), "territory_states", ["sect_id", "owner_sect_id", "controller_sect_id", "occupier_sect_id"], ids, messages, removed_only)
	_validate_keyed_records(world_state.get("ai_states", {}), "ai_states", ["sect_id", "target_sect_id", "vassal_of", "ally_sect_id", "enemy_sect_id"], ids, messages, removed_only)
	_validate_keyed_records(world_state.get("market_states", {}), "market_states", ["owner_sect_id"], ids, messages, removed_only)
	_validate_keyed_records(world_state.get("story_goals", {}), "story_goals", ["sect_id", "owner_sect_id", "target_sect_id"], ids, messages, removed_only)
	_validate_array_records(world_state.get("disciples", []), "disciples", ["sect_id"], ids, messages, removed_only)
	_validate_relations(world_state.get("relations", []), ids, messages, removed_only)
	_validate_pacts(world_state.get("diplomatic_pacts", []), ids, messages, removed_only)
	_validate_array_records(world_state.get("war_campaigns", []), "war_campaigns", ["attacker_sect_id", "defender_sect_id", "winner_sect_id", "owner_sect_id", "target_sect_id"], ids, messages, removed_only)
	_validate_array_records(world_state.get("market_transactions", []), "market_transactions", ["trader_sect_id", "market_owner_sect_id", "buyer_sect_id", "seller_sect_id", "owner_sect_id"], ids, messages, removed_only)
	_validate_array_records(world_state.get("mission_instances", []), "mission_instances", ["sect_id", "owner_sect_id", "issuer_sect_id", "receiver_sect_id"], ids, messages, removed_only)
	_validate_array_records(world_state.get("event_instances", []), "event_instances", ["sect_id", "owner_sect_id", "actor_sect_id", "target_sect_id"], ids, messages, removed_only)
	_validate_array_records(world_state.get("crafting_jobs", []), "crafting_jobs", ["sect_id", "owner_sect_id"], ids, messages, removed_only)
	_validate_history(world_state.get("history_entries", []), ids, messages, removed_only)


## 仅用于明确以 sect_id 为键的容器；市场、任务与资源的普通 ID 不会进入这里。
static func _validate_sect_dictionary_keys(value: Variant, path: String, ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if not value is Dictionary:
		return
	for key in (value as Dictionary).keys():
		_validate_id(str(key), path + "." + str(key), ids, messages, removed_only)


static func _validate_keyed_records(value: Variant, path: String, fields: Array[String], ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if not value is Dictionary:
		return
	for key in (value as Dictionary).keys():
		var record: Variant = (value as Dictionary)[key]
		if record is Dictionary:
			_validate_record(record, "%s.%s" % [path, str(key)], fields, ids, messages, removed_only)


static func _validate_array_records(value: Variant, path: String, fields: Array[String], ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if not value is Array:
		return
	for index in range((value as Array).size()):
		var record: Variant = (value as Array)[index]
		if record is Dictionary:
			_validate_record(record, "%s[%d]" % [path, index], fields, ids, messages, removed_only)


static func _validate_record(record: Dictionary, path: String, fields: Array[String], ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	for field in fields:
		if record.has(field):
			_validate_id(str(record[field]), path + "." + field, ids, messages, removed_only)


static func _validate_relations(value: Variant, ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if not value is Array:
		return
	var pairs := {}
	for index in range((value as Array).size()):
		var relation: Variant = (value as Array)[index]
		if not relation is Dictionary:
			continue
		var path := "relations[%d]" % index
		var a := str((relation as Dictionary).get("sect_a_id", ""))
		var b := str((relation as Dictionary).get("sect_b_id", ""))
		_validate_id(a, path + ".sect_a_id", ids, messages, removed_only)
		_validate_id(b, path + ".sect_b_id", ids, messages, removed_only)
		if not removed_only:
			if a == "" or b == "": messages.append(path + " requires sect_a_id and sect_b_id")
			elif a == b: messages.append(path + " cannot relate a sect to itself")
			else:
				var pair := [a, b]; pair.sort()
				var pair_key := str(pair[0]) + "|" + str(pair[1])
				if pairs.has(pair_key): messages.append(path + " duplicates relation pair: " + pair_key)
				pairs[pair_key] = true
		for action_index in range(((relation as Dictionary).get("action_history", []) as Array).size()):
			var action: Variant = (relation as Dictionary).get("action_history", [])[action_index]
			if action is Dictionary:
				_validate_record(action, path + ".action_history[%d]" % action_index, ["actor_sect_id", "target_sect_id", "attacker_sect_id", "defender_sect_id"], ids, messages, removed_only)


static func _validate_pacts(value: Variant, ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if not value is Array:
		return
	for index in range((value as Array).size()):
		var pact: Variant = (value as Array)[index]
		if not pact is Dictionary:
			continue
		var path := "diplomatic_pacts[%d]" % index
		var members: Variant = (pact as Dictionary).get("member_ids", [])
		var distinct := {}
		if members is Array:
			for member_index in range((members as Array).size()):
				var member_id := str((members as Array)[member_index])
				_validate_id(member_id, path + ".member_ids[%d]" % member_index, ids, messages, removed_only)
				if not removed_only and member_id != "" and distinct.has(member_id):
					messages.append(path + ".member_ids contains duplicate sect id: " + member_id)
				distinct[member_id] = true
		if not removed_only and (not members is Array or distinct.size() < 2):
			messages.append(path + ".member_ids requires at least two distinct sect ids")
		_validate_record(pact, path, ["overlord_sect_id", "vassal_sect_id"], ids, messages, removed_only)
		var terms: Variant = (pact as Dictionary).get("terms", {})
		if terms is Dictionary:
			_validate_record(terms, path + ".terms", ["attacker", "defender", "attacker_sect_id", "defender_sect_id", "overlord_sect_id", "vassal_sect_id", "actor_sect_id", "target_sect_id"], ids, messages, removed_only)


static func _validate_history(value: Variant, ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if not value is Array:
		return
	for index in range((value as Array).size()):
		var entry: Variant = (value as Array)[index]
		if not entry is Dictionary:
			continue
		var path := "history_entries[%d]" % index
		_validate_record(entry, path, ["sect_id", "owner_sect_id", "actor_sect_id", "target_sect_id"], ids, messages, removed_only)
		if str((entry as Dictionary).get("entity_type", "")) == "sect":
			for entity_index in range(((entry as Dictionary).get("entity_ids", []) as Array).size()):
				_validate_id(str((entry as Dictionary).get("entity_ids", [])[entity_index]), path + ".entity_ids[%d]" % entity_index, ids, messages, removed_only)


static func _validate_id(sect_id: String, path: String, ids: Dictionary, messages: PackedStringArray, removed_only: bool) -> void:
	if sect_id == "":
		return
	if removed_only:
		if ids.has(sect_id): messages.append(path + " references removed development sect id: " + sect_id)
	elif not ids.has(sect_id):
		messages.append(path + " references invalid sect id: " + sect_id)
