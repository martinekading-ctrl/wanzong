extends Node

signal ai_daily_simulation_completed(summary: Dictionary)
signal ai_monthly_simulation_completed(summary: Dictionary)

const PERFORMANCE_WARNING_MS: int = 1000
const RECRUIT_SPIRIT_STONE_COST: int = 50
const RECRUIT_FOOD_COST: int = 100
const MAX_MONTHLY_BREAKTHROUGHS_PER_SECT: int = 1

var _ai_sect_ids: Array[String] = []


func initialize_from_world_data() -> void:
	_ai_sect_ids.clear()
	for sect_data in WorldDataManager.get_ai_sects():
		var sect_id: String = str(sect_data.get("sect_id", ""))
		if sect_id == "":
			continue
		_ai_sect_ids.append(sect_id)
		SectManager.create_sect(sect_id)
		if not WorldDataManager.ai_states.has(sect_id):
			WorldDataManager.ai_states[sect_id] = _create_default_state(sect_id)
	_ai_sect_ids.sort()


func daily_update(date: Dictionary) -> Dictionary:
	var started_at: int = Time.get_ticks_msec()
	var reports: Array[Dictionary] = []
	var total_disciples: int = 0
	var total_warnings: int = 0
	for sect_id in _ai_sect_ids:
		var state: Dictionary = WorldDataManager.ai_states.get(sect_id, {})
		if str(state.get("status", "active")) == "destroyed":
			continue
		var sect: SectData = SectManager.create_sect(sect_id)
		if sect == null:
			continue
		var simulation_result: Dictionary = _simulate_daily_sect(sect)
		var economy_result: Dictionary = simulation_result["economy"]
		var sect_result: Dictionary = simulation_result["sect"]
		var shortages: Dictionary = economy_result.get("shortages", {})
		if int(shortages.get("food", 0)) > 0 or int(shortages.get("spirit_stone", 0)) > 0:
			state["resource_shortage_days"] = int(state.get("resource_shortage_days", 0)) + 1
		else:
			state["resource_shortage_days"] = maxi(0, int(state.get("resource_shortage_days", 0)) - 1)
		state["last_update_date"] = date.duplicate(true)
		state["power_trend"] = int(sect_result.get("power_after", 0)) - int(sect_result.get("power_before", 0))
		WorldDataManager.ai_states[sect_id] = state
		total_disciples += int(simulation_result.get("disciple_count", 0))
		total_warnings += economy_result.get("warnings", []).size()
		reports.append({
			"sect_id": sect_id,
			"disciple_count": int(simulation_result.get("disciple_count", 0)),
			"production": economy_result.get("production", {}),
			"expenses": economy_result.get("expenses", {}),
			"shortages": shortages,
			"power_after": sect_result.get("power_after", 0),
		})

	var monthly_summary: Dictionary = {}
	if int(date.get("day", 0)) == GameState.DAYS_PER_MONTH:
		monthly_summary = monthly_update(date)
	var duration_ms: int = Time.get_ticks_msec() - started_at
	var summary: Dictionary = {
		"date": date.duplicate(true),
		"sects_updated": reports.size(),
		"disciples_updated": total_disciples,
		"warning_count": total_warnings,
		"sect_reports": reports,
		"monthly": monthly_summary,
		"duration_ms": duration_ms,
	}
	if duration_ms > PERFORMANCE_WARNING_MS:
		push_warning("[AIPerf][WARNING] 完整AI世界推进超过1秒：%d ms" % duration_ms)
	ai_daily_simulation_completed.emit(summary)
	return summary


func monthly_update(date: Dictionary) -> Dictionary:
	var decisions: Array[Dictionary] = []
	for sect_id in _ai_sect_ids:
		var state: Dictionary = WorldDataManager.ai_states.get(sect_id, {})
		if str(state.get("status", "active")) == "destroyed":
			continue
		var previous_status: String = str(state.get("status", "active"))
		var scores: Dictionary = calculate_strategy_scores(sect_id)
		state["strategy_scores"] = scores
		state["current_goal"] = _select_highest_goal(scores)
		WorldDataManager.ai_states[sect_id] = state
		var assignment_result: Dictionary = _rebalance_assignments(sect_id, state)
		var recruitment_result: Dictionary = _try_recruit_disciple(sect_id, state)
		var breakthrough_result: Dictionary = _attempt_monthly_breakthroughs(sect_id)
		var strategic_action: Dictionary = _perform_strategic_action(sect_id, state)
		state["monthly_cycle_count"] = int(state.get("monthly_cycle_count", 0)) + 1
		state["development_points"] = int(state.get("development_points", 0)) + 1
		state["status"] = _evaluate_world_status(sect_id, state)
		WorldDataManager.ai_states[sect_id] = state
		if str(state["status"]) != previous_status:
			_record_status_change(sect_id, previous_status, str(state["status"]), date)
		decisions.append({
			"sect_id": sect_id,
			"goal": state["current_goal"],
			"scores": scores,
			"assignments": assignment_result,
			"recruitment": recruitment_result,
			"breakthroughs": breakthrough_result,
			"strategic_action": strategic_action,
			"status": state["status"],
		})
	var summary: Dictionary = {
		"date": date.duplicate(true),
		"sects_updated": decisions.size(),
		"decisions": decisions,
	}
	GameHistoryManager.record_entry(
		"ai_monthly_summary",
		"AI宗门月度演化",
		"%d个AI宗门完成月度运营调整。" % decisions.size(),
		_ai_sect_ids,
		summary,
		date
	)
	ai_monthly_simulation_completed.emit(summary)
	return summary


func get_ai_sect_ids() -> Array[String]:
	return _ai_sect_ids.duplicate()


# AI允许省略逐弟子日报字典，但生产、维护、口粮、修炼和健康仍复用玩家侧常量与公式。
func _simulate_daily_sect(sect: SectData) -> Dictionary:
	var disciples: Array[DiscipleData] = DiscipleManager.get_disciples_by_sect_id(sect.id)
	var production: Dictionary = {}
	var cultivation_disciples: Array[DiscipleData] = []
	for disciple in disciples:
		match disciple.assignment:
			DiscipleManager.ASSIGNMENT_FARM:
				production["food"] = int(production.get("food", 0)) + DiscipleManager.get_daily_production_amount(disciple, disciple.assignment)
			DiscipleManager.ASSIGNMENT_LOGGING:
				production["wood"] = int(production.get("wood", 0)) + DiscipleManager.get_daily_production_amount(disciple, disciple.assignment)
			DiscipleManager.ASSIGNMENT_MINING:
				production["ore"] = int(production.get("ore", 0)) + DiscipleManager.get_daily_production_amount(disciple, disciple.assignment)
			DiscipleManager.ASSIGNMENT_HERB:
				production["herb"] = int(production.get("herb", 0)) + DiscipleManager.get_daily_production_amount(disciple, disciple.assignment)
			DiscipleManager.ASSIGNMENT_CULTIVATE:
				if not disciple.at_bottleneck and RealmRegistry.get_by_id(disciple.realm_id) != null:
					cultivation_disciples.append(disciple)
	for resource_key in production:
		sect.add_resource(str(resource_key), int(production[resource_key]))

	var warnings: Array[String] = []
	var maintenance_required: int = EconomyManager.DAILY_SECT_MAINTENANCE_COST
	var maintenance_paid: int = mini(maintenance_required, sect.resources.get_amount("spirit_stone"))
	if maintenance_paid > 0:
		sect.consume_resource("spirit_stone", maintenance_paid)
	if maintenance_paid < maintenance_required:
		warnings.append("宗门维护灵石不足。")

	var food_required: int = disciples.size() * EconomyManager.DAILY_FOOD_COST_PER_DISCIPLE
	var food_paid: int = mini(food_required, sect.resources.get_amount("food"))
	if food_paid > 0:
		sect.consume_resource("food", food_paid)
	if food_paid < food_required:
		warnings.append("弟子口粮不足。")

	var cultivation_required: int = cultivation_disciples.size() * EconomyManager.DAILY_CULTIVATION_COST_PER_DISCIPLE
	var cultivation_paid: int = mini(cultivation_required, sect.resources.get_amount("spirit_stone"))
	cultivation_paid -= cultivation_paid % EconomyManager.DAILY_CULTIVATION_COST_PER_DISCIPLE
	if cultivation_paid > 0:
		sect.consume_resource("spirit_stone", cultivation_paid)
	var cultivation_paid_count: int = int(cultivation_paid / EconomyManager.DAILY_CULTIVATION_COST_PER_DISCIPLE)
	if cultivation_paid < cultivation_required:
		warnings.append("弟子修炼灵石不足。")

	var cultivation_index: int = 0
	for disciple_index in range(disciples.size()):
		var disciple: DiscipleData = disciples[disciple_index]
		var health_before: int = disciple.health
		var cultivation_before: int = disciple.cultivation
		if disciple.assignment == DiscipleManager.ASSIGNMENT_IDLE:
			disciple.health = clampi(disciple.health + DiscipleManager.IDLE_HEALTH_RECOVERY, 0, 100)
		if disciple_index >= food_paid:
			disciple.health = clampi(disciple.health - EconomyManager.FOOD_SHORTAGE_HEALTH_PENALTY, 0, 100)
		if disciple.assignment == DiscipleManager.ASSIGNMENT_CULTIVATE and not disciple.at_bottleneck:
			if cultivation_index < cultivation_paid_count:
				var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
				var gained: int = disciple.cultivate(DiscipleManager.get_daily_cultivation_gain(disciple), definition)
				disciple.combat_power = maxi(10, disciple.combat_power + gained)
			cultivation_index += 1
		if disciple.health != health_before or disciple.cultivation != cultivation_before:
			WorldDataManager.update_disciple_fields(disciple.id, {
				"cultivation": disciple.cultivation,
				"spiritual_power": disciple.cultivation,
				"at_bottleneck": disciple.at_bottleneck,
				"health": disciple.health,
				"combat_power": disciple.combat_power,
			})

	var economy_result: Dictionary = {
		"production": production,
		"expenses": {
			"maintenance": _create_expense(maintenance_required, maintenance_paid),
			"food": _create_expense(food_required, food_paid),
			"cultivation": _create_expense(cultivation_required, cultivation_paid),
		},
		"shortages": {
			"spirit_stone": maintenance_required - maintenance_paid + cultivation_required - cultivation_paid,
			"food": food_required - food_paid,
		},
		"warnings": warnings,
	}
	var sect_result: Dictionary = SectManager.daily_update(sect, economy_result)
	return {
		"disciple_count": disciples.size(),
		"economy": economy_result,
		"sect": sect_result,
	}


func _create_expense(required: int, paid: int) -> Dictionary:
	return {"required": required, "paid": paid, "shortage": maxi(0, required - paid)}


func calculate_strategy_scores(sect_id: String) -> Dictionary:
	var state: Dictionary = WorldDataManager.ai_states.get(sect_id, {})
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	var disciple_count: int = maxi(1, WorldDataManager.get_disciples_by_sect_id(sect_id).size())
	var food_days: float = float(resources.get("food", 0)) / float(disciple_count)
	var stone_days: float = float(resources.get("spirit_stone", 0)) / float(disciple_count)
	var shortage_pressure: float = float(state.get("resource_shortage_days", 0)) * 4.0
	var scores: Dictionary = {
		"survival": shortage_pressure + maxf(0.0, 30.0 - food_days) + maxf(0.0, 10.0 - stone_days),
		"development": minf(50.0, float(resources.get("wood", 0)) / 30.0 + float(resources.get("stone", 0)) / 30.0) + float(state.get("development_points", 0)),
		"military": minf(60.0, float(sect.get("combat_power", 0)) / 150.0) + float(resources.get("spirit_stone", 0)) / 500.0,
		"diplomacy": 20.0 + maxf(0.0, 300.0 - float(sect.get("reputation", 0))) / 20.0,
		"resource_need": maxf(0.0, 45.0 - food_days) + maxf(0.0, 20.0 - stone_days),
	}
	match str(state.get("personality", "balanced")):
		"aggressive", "ruthless":
			scores["military"] = float(scores["military"]) + 25.0
		"mercantile":
			scores["development"] = float(scores["development"]) + 20.0
			scores["diplomacy"] = float(scores["diplomacy"]) + 10.0
		"cautious", "isolationist":
			scores["survival"] = float(scores["survival"]) + 15.0
		"opportunistic":
			scores["resource_need"] = float(scores["resource_need"]) + 15.0
	return scores


func set_vassal(sect_id: String, overlord_sect_id: String) -> bool:
	if not WorldDataManager.ai_states.has(sect_id) or WorldDataManager.get_sect_by_id(overlord_sect_id).is_empty():
		return false
	var state: Dictionary = WorldDataManager.ai_states[sect_id]
	state["vassal_of"] = overlord_sect_id
	state["status"] = "vassal"
	WorldDataManager.ai_states[sect_id] = state
	GameHistoryManager.record_entry(
		"ai_world_change", "宗门附属", "%s成为%s的附属宗门。" % [
			str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id)),
			str(WorldDataManager.get_sect_by_id(overlord_sect_id).get("sect_name", overlord_sect_id)),
		], [sect_id, overlord_sect_id]
	)
	return true


func eliminate_sect(sect_id: String, reason: String = "宗门失去延续能力。") -> bool:
	if not WorldDataManager.ai_states.has(sect_id):
		return false
	var state: Dictionary = WorldDataManager.ai_states[sect_id]
	state["status"] = "destroyed"
	state["destroyed_reason"] = reason
	WorldDataManager.ai_states[sect_id] = state
	WorldDataManager.update_sect_data(sect_id, "is_active", false)
	GameHistoryManager.record_entry(
		"ai_world_change", "宗门覆灭", "%s：%s" % [str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id)), reason], [sect_id]
	)
	return true


func split_ai_sect(parent_sect_id: String) -> Dictionary:
	var parent: Dictionary = WorldDataManager.get_sect_by_id(parent_sect_id)
	if parent.is_empty() or bool(parent.get("is_player", false)):
		return {"success": false, "reason": "invalid_parent"}
	var parent_disciples: Array[DiscipleData] = DiscipleManager.get_disciples_by_sect_id(parent_sect_id)
	if parent_disciples.size() < 20:
		return {"success": false, "reason": "not_enough_disciples"}
	var new_sect_id: String = WorldDataManager.get_next_generated_sect_id()
	var transferred_count: int = maxi(10, int(parent_disciples.size() * 0.1))
	var new_location: Vector2 = Vector2(parent.get("location", Vector2.ZERO)) + Vector2(120.0, 80.0)
	var new_sect: Dictionary = parent.duplicate(true)
	new_sect["sect_id"] = new_sect_id
	new_sect["sect_name"] = str(parent.get("sect_name", "宗门")) + "分宗"
	new_sect["master_name"] = "分宗执事"
	new_sect["is_player"] = false
	new_sect["disciple_count"] = transferred_count
	new_sect["combat_power"] = 0
	new_sect["location"] = new_location
	new_sect["position"] = new_location
	new_sect["territory_radius"] = maxf(120.0, float(parent.get("territory_radius", 350.0)) * 0.4)
	new_sect["is_active"] = true
	var parent_resources: Dictionary = WorldDataManager.get_sect_resources(parent_sect_id)
	var child_resources: Dictionary = {}
	for resource_key in parent_resources:
		var transferred_amount: int = int(float(parent_resources[resource_key]) * 0.2)
		WorldDataManager.update_sect_resource(parent_sect_id, str(resource_key), -transferred_amount)
		child_resources[resource_key] = transferred_amount
	var child_state: Dictionary = _create_default_state(new_sect_id)
	child_state["personality"] = str(WorldDataManager.ai_states.get(parent_sect_id, {}).get("personality", "balanced"))
	child_state["parent_sect_id"] = parent_sect_id
	if not WorldDataManager.add_ai_sect_data(new_sect, child_resources, child_state):
		for resource_key in child_resources:
			WorldDataManager.update_sect_resource(parent_sect_id, str(resource_key), int(child_resources[resource_key]))
		return {"success": false, "reason": "data_add_failed"}
	_ai_sect_ids.append(new_sect_id)
	_ai_sect_ids.sort()
	SectManager.create_sect(new_sect_id)
	for index in range(transferred_count):
		DiscipleManager.transfer_disciple(parent_disciples[parent_disciples.size() - 1 - index].id, new_sect_id)
	SectManager.daily_update(SectManager.create_sect(parent_sect_id), {})
	SectManager.daily_update(SectManager.create_sect(new_sect_id), {})
	GameHistoryManager.record_entry(
		"ai_world_change", "宗门分裂", "%s分出了新的宗门%s。" % [str(parent.get("sect_name", parent_sect_id)), str(new_sect["sect_name"])], [parent_sect_id, new_sect_id]
	)
	return {"success": true, "parent_sect_id": parent_sect_id, "new_sect_id": new_sect_id, "transferred_disciples": transferred_count}


func _rebalance_assignments(sect_id: String, state: Dictionary) -> Dictionary:
	var disciples: Array[DiscipleData] = DiscipleManager.get_disciples_by_sect_id(sect_id)
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	var count: int = disciples.size()
	if count == 0:
		return {"changed": 0, "distribution": {}}
	var food_ratio: float = 0.45 if int(resources.get("food", 0)) < count * 20 else 0.25
	var wood_ratio: float = 0.15 if int(resources.get("wood", 0)) < count * 5 else 0.1
	var mining_ratio: float = 0.12
	var herb_ratio: float = 0.12
	var training_allowed: bool = int(resources.get("spirit_stone", 0)) >= count * 5
	var training_bias: float = 0.15 if str(state.get("current_goal", "")) == "military" else 0.0
	if str(state.get("current_goal", "")) in ["survival", "resource_need"]:
		food_ratio = minf(0.6, food_ratio + 0.15)
	var changed: int = 0
	var distribution: Dictionary = {}
	for index in range(count):
		var normalized: float = float(index) / float(count)
		var assignment: String
		if normalized < food_ratio:
			assignment = DiscipleManager.ASSIGNMENT_FARM
		elif normalized < food_ratio + wood_ratio:
			assignment = DiscipleManager.ASSIGNMENT_LOGGING
		elif normalized < food_ratio + wood_ratio + mining_ratio:
			assignment = DiscipleManager.ASSIGNMENT_MINING
		elif normalized < food_ratio + wood_ratio + mining_ratio + herb_ratio:
			assignment = DiscipleManager.ASSIGNMENT_HERB
		elif training_allowed and normalized >= food_ratio + wood_ratio + mining_ratio + herb_ratio - training_bias:
			assignment = DiscipleManager.ASSIGNMENT_CULTIVATE
		else:
			assignment = DiscipleManager.ASSIGNMENT_IDLE
		if disciples[index].assignment != assignment:
			DiscipleManager.update_assignment(disciples[index].id, assignment)
			changed += 1
		distribution[assignment] = int(distribution.get(assignment, 0)) + 1
	return {"changed": changed, "distribution": distribution}


func _try_recruit_disciple(sect_id: String, state: Dictionary) -> Dictionary:
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	if int(resources.get("spirit_stone", 0)) < RECRUIT_SPIRIT_STONE_COST:
		return {"success": false, "reason": "spirit_stone"}
	if int(resources.get("food", 0)) < RECRUIT_FOOD_COST:
		return {"success": false, "reason": "food"}
	if int(state.get("resource_shortage_days", 0)) > 5:
		return {"success": false, "reason": "shortage"}
	WorldDataManager.update_sect_resource(sect_id, "spirit_stone", -RECRUIT_SPIRIT_STONE_COST)
	WorldDataManager.update_sect_resource(sect_id, "food", -RECRUIT_FOOD_COST)
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	var new_count: int = WorldDataManager.get_disciples_by_sect_id(sect_id).size() + 1
	var disciple: DiscipleData = DiscipleManager.create_disciple(
		sect_id,
		"%s新晋弟子%03d" % [str(sect.get("sect_name", "宗门")), new_count],
		"男" if new_count % 2 == 0 else "女"
	)
	return {
		"success": disciple != null,
		"disciple_id": disciple.id if disciple != null else "",
		"costs": {"spirit_stone": RECRUIT_SPIRIT_STONE_COST, "food": RECRUIT_FOOD_COST},
	}


func _attempt_monthly_breakthroughs(sect_id: String) -> Dictionary:
	var attempted: int = 0
	var succeeded: int = 0
	for disciple in DiscipleManager.get_disciples_by_sect_id(sect_id):
		if attempted >= MAX_MONTHLY_BREAKTHROUGHS_PER_SECT:
			break
		if not disciple.at_bottleneck:
			continue
		var result: Dictionary = BreakthroughManager.attempt_breakthrough(disciple.id)
		if bool(result.get("attempted", false)):
			attempted += 1
			if bool(result.get("success", false)):
				succeeded += 1
	return {"attempted": attempted, "succeeded": succeeded}


func _create_default_state(sect_id: String) -> Dictionary:
	return {
		"sect_id": sect_id,
		"personality": "balanced",
		"current_goal": "stability",
		"status": "active",
		"development_points": 0,
		"monthly_cycle_count": 0,
		"resource_shortage_days": 0,
		"power_trend": 0,
		"influence": 1,
		"buildings": {},
		"relations": {},
		"last_update_date": {},
	}


func _select_highest_goal(scores: Dictionary) -> String:
	var selected_goal: String = "survival"
	var selected_score: float = -INF
	for goal in ["survival", "development", "military", "diplomacy", "resource_need"]:
		var score: float = float(scores.get(goal, 0.0))
		if score > selected_score:
			selected_goal = goal
			selected_score = score
	return selected_goal


func _perform_strategic_action(sect_id: String, state: Dictionary) -> Dictionary:
	var goal: String = str(state.get("current_goal", "stability"))
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	if goal in ["development", "military"]:
		var costs: Dictionary = {"spirit_stone": 100, "wood": 80, "stone": 60}
		var can_expand: bool = true
		for key in costs:
			if int(resources.get(key, 0)) < int(costs[key]):
				can_expand = false
				break
		if can_expand:
			for key in costs:
				WorldDataManager.update_sect_resource(sect_id, str(key), -int(costs[key]))
			var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
			var territory_after: float = float(sect.get("territory_radius", 350.0)) + 10.0
			WorldDataManager.update_sect_data(sect_id, "territory_radius", territory_after)
			state["influence"] = int(state.get("influence", 1)) + 1
			return {"type": "expand", "success": true, "costs": costs, "territory_after": territory_after}
	if goal == "diplomacy":
		var relations: Dictionary = state.get("relations", {})
		var player_relation: int = clampi(int(relations.get("sect_001", 0)) + 2, -100, 100)
		relations["sect_001"] = player_relation
		state["relations"] = relations
		return {"type": "improve_relation", "success": true, "target": "sect_001", "value": player_relation}
	return {"type": goal, "success": true}


func _evaluate_world_status(sect_id: String, state: Dictionary) -> String:
	if str(state.get("vassal_of", "")) != "":
		return "vassal"
	if WorldDataManager.get_disciples_by_sect_id(sect_id).is_empty():
		return "destroyed"
	if int(state.get("resource_shortage_days", 0)) >= 20:
		return "declining"
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	if int(state.get("power_trend", 0)) > 0 and int(resources.get("food", 0)) > 1000 and int(resources.get("spirit_stone", 0)) > 500:
		return "rising"
	return "active"


func _record_status_change(sect_id: String, before: String, after: String, date: Dictionary) -> void:
	GameHistoryManager.record_entry(
		"ai_world_change", "宗门状态变化", "%s由%s转为%s。" % [str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id)), before, after], [sect_id], {"before": before, "after": after}, date
	)
