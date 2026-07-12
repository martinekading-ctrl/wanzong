extends Node

const ASSIGNMENT_IDLE := "空闲"
const ASSIGNMENT_CULTIVATE := "修炼"
const ASSIGNMENT_FARM := "灵田"
const ASSIGNMENT_LOGGING := "伐木"
const ASSIGNMENT_MINING := "采矿"
const ASSIGNMENT_HERB := "采药"

const DAILY_FOOD_COST: int = 1
const IDLE_HEALTH_RECOVERY: int = 2
const CULTIVATION_BASE_GAIN: int = 5
const MINIMUM_PRODUCTION: int = 1

var disciples: Array[DiscipleData] = []
var _next_disciple_number: int = 1
var _disciples_by_sect: Dictionary = {}
var _disciple_by_id: Dictionary = {}


func reset() -> void:
	disciples.clear()
	_disciples_by_sect.clear()
	_disciple_by_id.clear()
	_next_disciple_number = 1


func create_disciple(
	sect_id: String = "sect_001",
	disciple_name: String = "新入门弟子",
	gender: String = "男"
) -> DiscipleData:
	WorldDataManager.init_world_data()
	_update_next_disciple_number()
	var disciple := DiscipleData.new()
	disciple.id = "disciple_%03d" % _next_disciple_number
	_next_disciple_number += 1
	disciple.sect_id = sect_id
	disciple.name = disciple_name
	disciple.gender = gender
	disciple.assignment = ASSIGNMENT_IDLE
	disciples.append(disciple)
	_disciple_by_id[disciple.id] = disciple
	if not _disciples_by_sect.has(sect_id):
		_disciples_by_sect[sect_id] = []
	_disciples_by_sect[sect_id].append(disciple)
	if not WorldDataManager.add_disciple_data(disciple.to_world_dictionary()):
		disciples.erase(disciple)
		_disciple_by_id.erase(disciple.id)
		_disciples_by_sect[sect_id].erase(disciple)
		return null
	_sync_disciple_count(sect_id)
	return disciple


func remove_disciple(disciple_id: String) -> bool:
	var removed_sect_id: String = ""
	for index in range(disciples.size()):
		if disciples[index].id != disciple_id:
			continue
		removed_sect_id = disciples[index].sect_id
		_disciple_by_id.erase(disciples[index].id)
		if _disciples_by_sect.has(removed_sect_id):
			_disciples_by_sect[removed_sect_id].erase(disciples[index])
		disciples.remove_at(index)
		break
	if removed_sect_id == "":
		return false
	WorldDataManager.remove_disciple_data(disciple_id)
	_sync_disciple_count(removed_sect_id)
	return true


func cultivate_all(amount: int = 10) -> void:
	for disciple in disciples:
		var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
		disciple.cultivate(amount, definition)
		sync_disciple_state(disciple)


func update_assignment(disciple_id: String, assignment: String) -> bool:
	if assignment not in get_supported_assignments():
		push_warning("不支持的弟子分工：" + assignment)
		return false
	var disciple: DiscipleData = get_disciple_by_id(disciple_id)
	if disciple == null:
		push_warning("未找到弟子：" + disciple_id)
		return false
	disciple.assignment = assignment
	return WorldDataManager.update_disciple_data(disciple_id, "assignment", assignment)


func get_disciple_by_id(disciple_id: String) -> DiscipleData:
	return _disciple_by_id.get(disciple_id) as DiscipleData


func get_disciples_by_sect_id(sect_id: String) -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for disciple in _disciples_by_sect.get(sect_id, []):
		result.append(disciple as DiscipleData)
	return result


func transfer_disciple(disciple_id: String, new_sect_id: String) -> bool:
	var disciple: DiscipleData = get_disciple_by_id(disciple_id)
	if disciple == null or WorldDataManager.get_sect_by_id(new_sect_id).is_empty():
		return false
	var old_sect_id: String = disciple.sect_id
	if old_sect_id == new_sect_id:
		return true
	if not WorldDataManager.transfer_disciple_data(disciple_id, new_sect_id):
		return false
	if _disciples_by_sect.has(old_sect_id):
		_disciples_by_sect[old_sect_id].erase(disciple)
	if not _disciples_by_sect.has(new_sect_id):
		_disciples_by_sect[new_sect_id] = []
	_disciples_by_sect[new_sect_id].append(disciple)
	disciple.sect_id = new_sect_id
	_sync_disciple_count(old_sect_id)
	_sync_disciple_count(new_sect_id)
	return true


func get_supported_assignments() -> Array[String]:
	return [
		ASSIGNMENT_IDLE,
		ASSIGNMENT_CULTIVATE,
		ASSIGNMENT_FARM,
		ASSIGNMENT_LOGGING,
		ASSIGNMENT_MINING,
		ASSIGNMENT_HERB,
	]


func get_daily_cultivation_gain(disciple: DiscipleData) -> int:
	return CULTIVATION_BASE_GAIN + int(disciple.talent / 25.0)


func get_daily_production_amount(disciple: DiscipleData, assignment: String) -> int:
	match assignment:
		ASSIGNMENT_FARM:
			return maxi(MINIMUM_PRODUCTION, 8 + int(disciple.talent / 20.0) + _get_daily_variation(-1, 2))
		ASSIGNMENT_LOGGING:
			return maxi(MINIMUM_PRODUCTION, 6 + int(disciple.potential / 25.0) + _get_daily_variation(-1, 2))
		ASSIGNMENT_MINING:
			return maxi(MINIMUM_PRODUCTION, 4 + int(disciple.talent / 30.0) + _get_daily_variation(-1, 1))
		ASSIGNMENT_HERB:
			return maxi(MINIMUM_PRODUCTION, 4 + int(disciple.talent / 25.0) + _get_daily_variation(-1, 2))
	return 0


# 只生成每日行动计划，不在此阶段修改资源或弟子状态。
func prepare_daily_actions(sect_id: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for disciple in get_disciples_by_sect_id(sect_id):
		var assignment: String = _normalize_assignment(disciple.assignment)
		var action: Dictionary = _create_base_daily_result(disciple, assignment)
		match assignment:
			ASSIGNMENT_IDLE:
				action["health_change"] = IDLE_HEALTH_RECOVERY
				action["message"] = "休息恢复健康。"
			ASSIGNMENT_CULTIVATE:
				var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
				if definition == null:
					action["success"] = false
					action["message"] = "境界配置缺失，无法修炼。"
				elif disciple.at_bottleneck:
					action["success"] = false
					action["at_bottleneck"] = true
					action["message"] = "已达修炼瓶颈，等待突破。"
				else:
					action["cultivation_gain"] = get_daily_cultivation_gain(disciple)
					action["cost"]["spirit_stone"] = EconomyManager.DAILY_CULTIVATION_COST_PER_DISCIPLE
					action["message"] = "等待分配修炼灵石。"
			ASSIGNMENT_FARM:
				_set_production(action, "food", get_daily_production_amount(disciple, assignment))
			ASSIGNMENT_LOGGING:
				_set_production(action, "wood", get_daily_production_amount(disciple, assignment))
			ASSIGNMENT_MINING:
				_set_production(action, "ore", get_daily_production_amount(disciple, assignment))
			ASSIGNMENT_HERB:
				_set_production(action, "herb", get_daily_production_amount(disciple, assignment))
		actions.append(action)
	return actions


# 经济系统完成支付后，只应用实际获批的修为与健康变化。
func apply_daily_results(results: Array[Dictionary]) -> void:
	for result in results:
		var disciple_id: String = str(result.get("disciple_id", ""))
		var disciple: DiscipleData = get_disciple_by_id(disciple_id)
		if disciple == null:
			continue
		var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
		var requested_gain: int = int(result.get("cultivation_gain", 0))
		var cultivation_before: int = disciple.cultivation
		var was_at_bottleneck: bool = disciple.at_bottleneck
		var actual_gain: int = disciple.cultivate(requested_gain, definition)
		result["cultivation_requested"] = requested_gain
		result["cultivation_gain"] = actual_gain
		result["cultivation_before"] = cultivation_before
		result["cultivation_after"] = disciple.cultivation
		result["cultivation_required"] = definition.cultivation_required if definition != null else 0
		result["at_bottleneck"] = disciple.at_bottleneck
		result["reached_bottleneck"] = disciple.at_bottleneck and not was_at_bottleneck
		result["realm_id"] = disciple.realm_id
		result["realm"] = disciple.realm
		if actual_gain < requested_gain and disciple.at_bottleneck:
			result["message"] = "修为达到上限，已进入突破瓶颈。"
		disciple.health = clampi(disciple.health + int(result.get("health_change", 0)), 0, 100)
		disciple.combat_power = maxi(10, disciple.combat_power + actual_gain)
		WorldDataManager.update_disciple_fields(disciple.id, {
			"realm_id": disciple.realm_id,
			"realm": disciple.realm,
			"cultivation": disciple.cultivation,
			"spiritual_power": disciple.cultivation,
			"at_bottleneck": disciple.at_bottleneck,
			"health": disciple.health,
			"combat_power": disciple.combat_power,
		})


func load_from_world_data() -> void:
	reset()
	for world_disciple in WorldDataManager.get_all_disciples():
		var disciple := DiscipleData.new()
		disciple.id = str(world_disciple.get("disciple_id", ""))
		disciple.sect_id = str(world_disciple.get("sect_id", ""))
		disciple.name = str(world_disciple.get("disciple_name", "未命名弟子"))
		disciple.age = int(world_disciple.get("age", 16))
		disciple.gender = str(world_disciple.get("gender", "男"))
		var legacy_realm: String = str(world_disciple.get("realm", "凡人"))
		disciple.realm_id = str(world_disciple.get(
			"realm_id",
			RealmRegistry.get_id_by_display_name(legacy_realm)
		))
		var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
		if definition == null:
			disciple.realm_id = "mortal"
			definition = RealmRegistry.get_by_id(disciple.realm_id)
		disciple.realm = definition.display_name if definition != null else legacy_realm
		var stored_cultivation: int = int(world_disciple.get(
			"cultivation",
			world_disciple.get("spiritual_power", 0)
		))
		disciple.cultivation = clampi(stored_cultivation, 0, definition.cultivation_required) if definition != null else maxi(0, stored_cultivation)
		disciple.at_bottleneck = bool(world_disciple.get("at_bottleneck", false)) or (
			definition != null and disciple.cultivation >= definition.cultivation_required
		)
		disciple.talent = int(world_disciple.get("talent", world_disciple.get("comprehension", 50)))
		disciple.potential = int(world_disciple.get("potential", 50))
		disciple.personality = str(world_disciple.get("personality", "沉稳"))
		disciple.health = int(world_disciple.get("health", 100))
		disciple.loyalty = int(world_disciple.get("loyalty", 50))
		disciple.assignment = str(world_disciple.get("assignment", ASSIGNMENT_IDLE))
		disciple.combat_power = int(world_disciple.get(
			"combat_power",
			maxi(10, disciple.talent + disciple.cultivation)
		))
		disciple.breakthrough_history.assign(world_disciple.get("breakthrough_history", []))
		disciples.append(disciple)
		_disciple_by_id[disciple.id] = disciple
		if not _disciples_by_sect.has(disciple.sect_id):
			_disciples_by_sect[disciple.sect_id] = []
		_disciples_by_sect[disciple.sect_id].append(disciple)
		sync_disciple_state(disciple)
	_update_next_disciple_number()


func _sync_disciple_count(sect_id: String) -> void:
	var count: int = WorldDataManager.get_disciples_by_sect_id(sect_id).size()
	WorldDataManager.update_sect_data(sect_id, "disciple_count", count)
	var sect: SectData = SectManager.get_sect(sect_id)
	if sect != null:
		sect.disciples_count = count


func _update_next_disciple_number() -> void:
	var highest_number: int = 0
	for world_disciple in WorldDataManager.get_all_disciples():
		var disciple_id: String = str(world_disciple.get("disciple_id", ""))
		var number_text: String = disciple_id.trim_prefix("disciple_")
		if number_text.is_valid_int():
			highest_number = maxi(highest_number, number_text.to_int())
	_next_disciple_number = highest_number + 1


func _create_base_daily_result(disciple: DiscipleData, assignment: String) -> Dictionary:
	var definition: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
	return {
		"disciple_id": disciple.id,
		"disciple_name": disciple.name,
		"assignment": assignment,
		"resource_type": "",
		"resource_amount": 0,
		"cultivation_gain": 0,
		"cultivation_before": disciple.cultivation,
		"cultivation_after": disciple.cultivation,
		"cultivation_required": definition.cultivation_required if definition != null else 0,
		"realm_id": disciple.realm_id,
		"realm": disciple.realm,
		"at_bottleneck": disciple.at_bottleneck,
		"reached_bottleneck": false,
		"health_change": 0,
		"cost": {
			"spirit_stone": 0,
			"food": DAILY_FOOD_COST,
		},
		"success": true,
		"message": "",
	}


func _set_production(action: Dictionary, resource_type: String, amount: int) -> void:
	action["resource_type"] = resource_type
	action["resource_amount"] = maxi(MINIMUM_PRODUCTION, amount)
	action["message"] = "完成今日生产。"


func _normalize_assignment(assignment: String) -> String:
	# 兼容 Task-0033 时期的旧分工值，不建立第二个分工字段。
	match assignment:
		"采集":
			return ASSIGNMENT_HERB
		"闭关":
			return ASSIGNMENT_CULTIVATE
		"巡山":
			return ASSIGNMENT_IDLE
		_:
			return assignment if assignment in get_supported_assignments() else ASSIGNMENT_IDLE


func _get_daily_variation(min_value: int, max_value: int) -> int:
	return GameState.random_int(min_value, max_value)


func sync_disciple_state(disciple: DiscipleData) -> void:
	if disciple == null:
		return
	WorldDataManager.update_disciple_fields(disciple.id, {
		"realm_id": disciple.realm_id,
		"realm": disciple.realm,
		"cultivation": disciple.cultivation,
		"spiritual_power": disciple.cultivation,
		"at_bottleneck": disciple.at_bottleneck,
		"health": disciple.health,
		"loyalty": disciple.loyalty,
		"combat_power": disciple.combat_power,
		"breakthrough_history": disciple.breakthrough_history.duplicate(true),
	})
