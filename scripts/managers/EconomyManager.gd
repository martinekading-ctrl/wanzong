extends Node

const DAILY_FOOD_COST_PER_DISCIPLE := 1
const DAILY_SECT_MAINTENANCE_COST := 3
const DAILY_CULTIVATION_COST_PER_DISCIPLE := 2
const FOOD_SHORTAGE_HEALTH_PENALTY := 5


# 按“产出→维护费→口粮→修炼”的顺序统一结算，不推进日期。
func daily_update(sect: SectData, daily_actions: Array[Dictionary]) -> Dictionary:
	if sect == null or sect.id == "":
		push_warning("EconomyManager：没有可结算的玩家宗门。")
		return _create_empty_result(daily_actions)

	var warnings: Array[String] = []
	var production: Dictionary = _apply_production(sect, daily_actions)
	var maintenance: Dictionary = _pay_resource(
		sect,
		"spirit_stone",
		DAILY_SECT_MAINTENANCE_COST
	)
	if int(maintenance["shortage"]) > 0:
		warnings.append("宗门灵石不足，维护费尚缺%d。" % int(maintenance["shortage"]))

	var food_expense: Dictionary = _settle_food(sect, daily_actions, warnings)
	var cultivation_expense: Dictionary = _settle_cultivation(sect, daily_actions, warnings)
	return {
		"production": production,
		"expenses": {
			"maintenance": maintenance,
			"food": food_expense,
			"cultivation": cultivation_expense,
		},
		"shortages": {
			"spirit_stone": int(maintenance["shortage"]) + int(cultivation_expense["shortage"]),
			"food": int(food_expense["shortage"]),
		},
		"disciple_results": daily_actions,
		"warnings": warnings,
	}


func _apply_production(sect: SectData, daily_actions: Array[Dictionary]) -> Dictionary:
	var production: Dictionary = {}
	for action in daily_actions:
		var resource_type: String = str(action.get("resource_type", ""))
		var amount: int = int(action.get("resource_amount", 0))
		if resource_type == "" or amount <= 0:
			continue
		var before_amount: int = sect.resources.get_amount(resource_type)
		if not sect.add_resource(resource_type, amount):
			action["success"] = false
			action["message"] = "资源产出写入失败。"
			continue
		var actual_amount: int = sect.resources.get_amount(resource_type) - before_amount
		action["resource_amount"] = actual_amount
		production[resource_type] = int(production.get(resource_type, 0)) + actual_amount
	return production


func _settle_food(
	sect: SectData,
	daily_actions: Array[Dictionary],
	warnings: Array[String]
) -> Dictionary:
	var required: int = daily_actions.size() * DAILY_FOOD_COST_PER_DISCIPLE
	var expense: Dictionary = _pay_resource(sect, "food", required)
	var fed_count: int = int(expense["paid"])
	for index in range(daily_actions.size()):
		var cost: Dictionary = daily_actions[index]["cost"]
		if index < fed_count:
			cost["food"] = DAILY_FOOD_COST_PER_DISCIPLE
		else:
			cost["food"] = 0
			daily_actions[index]["health_change"] = (
				int(daily_actions[index]["health_change"])
				- FOOD_SHORTAGE_HEALTH_PENALTY
			)
	if int(expense["shortage"]) > 0:
		warnings.append("宗门食物不足，%d名弟子未获得口粮。" % int(expense["shortage"]))
	return expense


func _settle_cultivation(
	sect: SectData,
	daily_actions: Array[Dictionary],
	warnings: Array[String]
) -> Dictionary:
	var cultivation_count: int = 0
	var paid: int = 0
	var failed_count: int = 0
	for action in daily_actions:
		if str(action.get("assignment", "")) != DiscipleManager.ASSIGNMENT_CULTIVATE:
			continue
		# 瓶颈或配置错误的行动在弟子系统中已标记失败，不应继续收费。
		if not bool(action.get("success", true)) or int(action.get("cultivation_gain", 0)) <= 0:
			action["cost"]["spirit_stone"] = 0
			continue
		cultivation_count += 1
		if sect.resources.has_enough("spirit_stone", DAILY_CULTIVATION_COST_PER_DISCIPLE):
			sect.consume_resource("spirit_stone", DAILY_CULTIVATION_COST_PER_DISCIPLE)
			action["cost"]["spirit_stone"] = DAILY_CULTIVATION_COST_PER_DISCIPLE
			action["message"] = "修炼完成。"
			paid += DAILY_CULTIVATION_COST_PER_DISCIPLE
		else:
			action["cost"]["spirit_stone"] = 0
			action["cultivation_gain"] = 0
			action["success"] = false
			action["message"] = "灵石不足，修炼失败。"
			failed_count += 1
	var required: int = cultivation_count * DAILY_CULTIVATION_COST_PER_DISCIPLE
	var expense: Dictionary = _create_expense(required, paid)
	if failed_count > 0:
		warnings.append("宗门灵石不足，%d名弟子修炼失败。" % failed_count)
	return expense


func _pay_resource(sect: SectData, resource_key: String, required: int) -> Dictionary:
	var paid: int = mini(required, sect.resources.get_amount(resource_key))
	if paid > 0:
		sect.consume_resource(resource_key, paid)
	return _create_expense(required, paid)


func _create_expense(required: int, paid: int) -> Dictionary:
	return {
		"required": required,
		"paid": paid,
		"shortage": maxi(0, required - paid),
	}


func _create_empty_result(daily_actions: Array[Dictionary]) -> Dictionary:
	return {
		"production": {},
		"expenses": {
			"maintenance": _create_expense(0, 0),
			"food": _create_expense(0, 0),
			"cultivation": _create_expense(0, 0),
		},
		"shortages": {"spirit_stone": 0, "food": 0},
		"disciple_results": daily_actions,
		"warnings": ["没有可结算的玩家宗门。"],
	}
