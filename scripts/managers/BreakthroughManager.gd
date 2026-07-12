extends Node

signal breakthrough_completed(result: Dictionary)

const MIN_SUCCESS_RATE: float = 0.05
const MAX_SUCCESS_RATE: float = 0.95


# UI只能请求突破并显示此方法返回的结构化结果，不直接修改弟子或资源数据。
func attempt_breakthrough(disciple_id: String, modifiers: Dictionary = {}) -> Dictionary:
	var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
	if disciple == null:
		return _reject(disciple_id, "disciple_not_found", "未找到该弟子。")
	var current: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
	if current == null:
		return _reject(disciple_id, "realm_not_found", "当前境界配置缺失。")
	if not disciple.at_bottleneck or disciple.cultivation < current.cultivation_required:
		return _reject(disciple_id, "not_at_bottleneck", "修为尚未达到突破瓶颈。")
	if current.next_realm_id == "":
		return _reject(disciple_id, "no_next_realm", "当前已是已配置的最高境界。")
	var next: RealmDefinition = RealmRegistry.get_by_id(current.next_realm_id)
	if next == null:
		return _reject(disciple_id, "next_realm_not_found", "下一境界配置缺失。")
	if disciple.health < current.minimum_health:
		return _reject(
			disciple_id,
			"health_too_low",
			"健康不足，突破至少需要%d点健康。" % current.minimum_health
		)
	var missing_resources: Dictionary = _get_missing_resources(disciple.sect_id, current.costs)
	if not missing_resources.is_empty():
		var rejected: Dictionary = _reject(disciple_id, "resources_insufficient", "突破资源不足。")
		rejected["missing_resources"] = missing_resources
		rejected["costs"] = current.costs.duplicate(true)
		return rejected

	var chance: float = calculate_success_rate(disciple, current, modifiers)
	var roll: float = randf()
	# 仅供自动回归使用；发布构建不接受外部强制随机值。
	if OS.is_debug_build() and modifiers.has("_test_roll"):
		roll = clampf(float(modifiers["_test_roll"]), 0.0, 1.0)
	if not _deduct_costs(disciple.sect_id, current.costs):
		return _reject(disciple_id, "resource_update_failed", "突破资源扣除失败。")

	var result: Dictionary
	if roll <= chance:
		result = _apply_success(disciple, current, next, chance, roll)
	else:
		result = _apply_failure(disciple, current, chance, roll)
	result["costs"] = current.costs.duplicate(true)
	_record_history(disciple, result)
	DiscipleManager.sync_disciple_state(disciple)
	breakthrough_completed.emit(result)
	return result


func calculate_success_rate(
	disciple: DiscipleData,
	definition: RealmDefinition,
	modifiers: Dictionary = {}
) -> float:
	if disciple == null or definition == null:
		return 0.0
	var talent_bonus: float = (float(disciple.talent) - 50.0) * 0.002
	var potential_bonus: float = (float(disciple.potential) - 50.0) * 0.0015
	var health_bonus: float = (float(disciple.health) - float(definition.minimum_health)) * 0.00125
	var external_bonus: float = (
		float(modifiers.get("pill_bonus", 0.0))
		+ float(modifiers.get("building_bonus", 0.0))
		+ float(modifiers.get("other_bonus", 0.0))
	)
	return clampf(
		definition.breakthrough_base_rate + talent_bonus + potential_bonus + health_bonus + external_bonus,
		MIN_SUCCESS_RATE,
		MAX_SUCCESS_RATE
	)


func get_breakthrough_preview(disciple_id: String) -> Dictionary:
	var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
	if disciple == null:
		return {}
	var current: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
	if current == null:
		return {}
	var next: RealmDefinition = RealmRegistry.get_by_id(current.next_realm_id)
	return {
		"disciple_id": disciple.id,
		"current_realm": current.display_name,
		"next_realm": next.display_name if next != null else "无",
		"at_bottleneck": disciple.at_bottleneck,
		"health": disciple.health,
		"minimum_health": current.minimum_health,
		"costs": current.costs.duplicate(true),
		"missing_resources": _get_missing_resources(disciple.sect_id, current.costs),
		"success_rate": calculate_success_rate(disciple, current),
	}


func _apply_success(
	disciple: DiscipleData,
	current: RealmDefinition,
	next: RealmDefinition,
	chance: float,
	roll: float
) -> Dictionary:
	var combat_before: int = disciple.combat_power
	var current_multiplier: float = float(current.stat_multipliers.get("combat_power", 1.0))
	var next_multiplier: float = float(next.stat_multipliers.get("combat_power", current_multiplier))
	var multiplier_ratio: float = next_multiplier / maxf(0.01, current_multiplier)
	var world_disciple: Dictionary = WorldDataManager.get_disciple_by_id(disciple.id)
	var hp_before: int = int(world_disciple.get("hp", 100))
	var max_hp_before: int = int(world_disciple.get("max_hp", 100))
	var current_health_multiplier: float = float(current.stat_multipliers.get("health", 1.0))
	var next_health_multiplier: float = float(next.stat_multipliers.get("health", current_health_multiplier))
	var health_multiplier_ratio: float = next_health_multiplier / maxf(0.01, current_health_multiplier)
	var max_hp_after: int = maxi(max_hp_before + 1, roundi(float(max_hp_before) * health_multiplier_ratio))
	var hp_after: int = clampi(roundi(float(hp_before) * health_multiplier_ratio), 1, max_hp_after)
	disciple.realm_id = next.id
	disciple.realm = next.display_name
	disciple.cultivation = 0
	disciple.at_bottleneck = false
	disciple.combat_power = maxi(combat_before + 1, roundi(float(combat_before) * multiplier_ratio))
	WorldDataManager.update_disciple_data(disciple.id, "hp", hp_after)
	WorldDataManager.update_disciple_data(disciple.id, "max_hp", max_hp_after)
	return {
		"attempted": true,
		"success": true,
		"code": "success",
		"message": "突破成功，进入%s。" % next.display_name,
		"disciple_id": disciple.id,
		"from_realm_id": current.id,
		"from_realm": current.display_name,
		"to_realm_id": next.id,
		"to_realm": next.display_name,
		"chance": chance,
		"roll": roll,
		"changes": {
			"cultivation_before": current.cultivation_required,
			"cultivation_after": 0,
			"combat_power_before": combat_before,
			"combat_power_after": disciple.combat_power,
			"health_before": disciple.health,
			"health_after": disciple.health,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"max_hp_before": max_hp_before,
			"max_hp_after": max_hp_after,
		},
	}


func _apply_failure(
	disciple: DiscipleData,
	current: RealmDefinition,
	chance: float,
	roll: float
) -> Dictionary:
	var cultivation_before: int = disciple.cultivation
	var health_before: int = disciple.health
	var cultivation_loss: int = maxi(
		1,
		roundi(float(current.cultivation_required) * current.failure_cultivation_loss_rate)
	)
	disciple.cultivation = maxi(0, disciple.cultivation - cultivation_loss)
	disciple.health = maxi(1, disciple.health - current.failure_health_penalty)
	disciple.at_bottleneck = false
	var world_disciple: Dictionary = WorldDataManager.get_disciple_by_id(disciple.id)
	var hp_before: int = int(world_disciple.get("hp", 100))
	var max_hp: int = int(world_disciple.get("max_hp", 100))
	var hp_after: int = clampi(roundi(float(max_hp) * float(disciple.health) / 100.0), 1, max_hp)
	WorldDataManager.update_disciple_data(disciple.id, "hp", hp_after)
	return {
		"attempted": true,
		"success": false,
		"code": "failed",
		"message": "突破失败，修为受损且需要重新积累。",
		"disciple_id": disciple.id,
		"from_realm_id": current.id,
		"from_realm": current.display_name,
		"to_realm_id": current.next_realm_id,
		"to_realm": "",
		"chance": chance,
		"roll": roll,
		"changes": {
			"cultivation_before": cultivation_before,
			"cultivation_after": disciple.cultivation,
			"combat_power_before": disciple.combat_power,
			"combat_power_after": disciple.combat_power,
			"health_before": health_before,
			"health_after": disciple.health,
			"hp_before": hp_before,
			"hp_after": hp_after,
		},
	}


func _get_missing_resources(sect_id: String, costs: Dictionary) -> Dictionary:
	var storage: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var missing: Dictionary = {}
	for resource_key in costs:
		var required: int = int(costs[resource_key])
		var available: int = int(storage.get(resource_key, 0))
		if available < required:
			missing[resource_key] = required - available
	return missing


func _deduct_costs(sect_id: String, costs: Dictionary) -> bool:
	var applied: Dictionary = {}
	for resource_key in costs:
		var amount: int = int(costs[resource_key])
		if amount <= 0:
			continue
		if not WorldDataManager.update_sect_resource(sect_id, str(resource_key), -amount):
			for applied_key in applied:
				WorldDataManager.update_sect_resource(sect_id, str(applied_key), int(applied[applied_key]))
			return false
		applied[resource_key] = amount
	return true


func _record_history(disciple: DiscipleData, result: Dictionary) -> void:
	var entry: Dictionary = {
		"category": "disciple_breakthrough",
		"disciple_id": disciple.id,
		"year": GameState.year,
		"month": GameState.month,
		"day": GameState.day,
		"success": bool(result.get("success", false)),
		"from_realm_id": str(result.get("from_realm_id", "")),
		"to_realm_id": str(result.get("to_realm_id", "")),
		"message": str(result.get("message", "")),
	}
	disciple.breakthrough_history.append(entry)
	result["history_entry"] = entry.duplicate(true)


func _reject(disciple_id: String, code: String, message: String) -> Dictionary:
	return {
		"attempted": false,
		"success": false,
		"code": code,
		"message": message,
		"disciple_id": disciple_id,
		"costs": {},
		"changes": {},
	}
