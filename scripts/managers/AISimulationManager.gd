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
		if str(state.get("status", "active")) != "active":
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
		if str(state.get("status", "active")) != "active":
			continue
		var assignment_result: Dictionary = _rebalance_assignments(sect_id)
		var recruitment_result: Dictionary = _try_recruit_disciple(sect_id, state)
		var breakthrough_result: Dictionary = _attempt_monthly_breakthroughs(sect_id)
		state["monthly_cycle_count"] = int(state.get("monthly_cycle_count", 0)) + 1
		state["development_points"] = int(state.get("development_points", 0)) + 1
		WorldDataManager.ai_states[sect_id] = state
		decisions.append({
			"sect_id": sect_id,
			"assignments": assignment_result,
			"recruitment": recruitment_result,
			"breakthroughs": breakthrough_result,
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


func _rebalance_assignments(sect_id: String) -> Dictionary:
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
		elif training_allowed:
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
