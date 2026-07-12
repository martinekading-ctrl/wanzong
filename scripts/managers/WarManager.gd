extends Node

signal campaign_started(campaign_data: Dictionary)
signal campaign_completed(result: Dictionary)

const MAX_FORCE_SIZE: int = 6
const SHORTAGE_DAYS_BEFORE_RETREAT: int = 3

var _next_campaign_number: int = 1


func rebuild_runtime_state() -> void:
	_next_campaign_number = 1
	for campaign_data in WorldDataManager.war_campaigns:
		var campaign := WarCampaignData.from_dictionary(campaign_data)
		var number_text: String = campaign.campaign_id.trim_prefix("campaign_")
		if number_text.is_valid_int():
			_next_campaign_number = maxi(_next_campaign_number, number_text.to_int() + 1)
		if campaign.phase in ["marching", "battle"]:
			_set_force_deployed(campaign.attacker_disciple_ids, campaign.campaign_id, true)
			if campaign.target_type == "sect":
				_set_force_deployed(campaign.defender_disciple_ids, campaign.campaign_id, true)


func start_resource_campaign(attacker_sect_id: String, resource_id: int, attacker_disciple_ids: Array, options: Dictionary = {}) -> Dictionary:
	var site: Dictionary = ResourceSiteManager.get_site_by_id(resource_id)
	var defender_sect_id: String = str(site.get("owner_sect_id", ""))
	if site.is_empty() or defender_sect_id == "" or defender_sect_id == attacker_sect_id:
		return _error("target_invalid", "资源点不是有效的敌方目标。")
	if str(DiplomacyManager.get_relation(attacker_sect_id, defender_sect_id).get("status", "")) != "war":
		return _error("not_at_war", "只有战争状态下才能争夺资源点。")
	var defender_ids: Array = site.get("garrison_disciple_ids", []).duplicate()
	if defender_ids.is_empty():
		defender_ids = _select_force(defender_sect_id, 3, false)
	return _start_campaign(attacker_sect_id, defender_sect_id, "resource_site", str(resource_id), attacker_disciple_ids, defender_ids, site.get("position", Vector2.ZERO), options)


func start_sect_siege(attacker_sect_id: String, defender_sect_id: String, attacker_disciple_ids: Array, options: Dictionary = {}) -> Dictionary:
	if str(DiplomacyManager.get_relation(attacker_sect_id, defender_sect_id).get("status", "")) != "war":
		return _error("not_at_war", "只有战争状态下才能进攻宗门。")
	var defender_ids: Array[String] = _select_force(defender_sect_id, 6, true)
	var target_position: Vector2 = WorldDataManager.get_sect_by_id(defender_sect_id).get("location", Vector2.ZERO)
	return _start_campaign(attacker_sect_id, defender_sect_id, "sect", defender_sect_id, attacker_disciple_ids, defender_ids, target_position, options)


func daily_update(date: Dictionary) -> Dictionary:
	var progressed: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	for index in range(WorldDataManager.war_campaigns.size()):
		var campaign := WarCampaignData.from_dictionary(WorldDataManager.war_campaigns[index])
		if campaign.phase != "marching":
			continue
		var supplied: bool = _consume_daily_supply(campaign)
		if supplied:
			campaign.supply_shortage_days = 0
			campaign.remaining_march_days = maxi(0, campaign.remaining_march_days - 1)
		else:
			campaign.supply_shortage_days += 1
		if campaign.supply_shortage_days >= SHORTAGE_DAYS_BEFORE_RETREAT:
			var retreat_result: Dictionary = _complete_retreat(campaign, date, "补给连续三日不足")
			completed.append(retreat_result)
		elif campaign.remaining_march_days == 0:
			var battle_result: Dictionary = _resolve_campaign_battle(campaign, date)
			completed.append(battle_result)
		WorldDataManager.war_campaigns[index] = campaign.to_dictionary()
		progressed.append(campaign.to_dictionary())
	return {"progressed": progressed, "completed": completed}


func retreat_campaign(campaign_id: String) -> Dictionary:
	var index: int = _find_campaign_index(campaign_id)
	if index < 0:
		return _error("campaign_not_found", "未找到战争行动。")
	var campaign := WarCampaignData.from_dictionary(WorldDataManager.war_campaigns[index])
	if campaign.phase != "marching":
		return _error("cannot_retreat", "当前阶段无法撤退。")
	var result: Dictionary = _complete_retreat(campaign, _current_date(), "主动撤退")
	WorldDataManager.war_campaigns[index] = campaign.to_dictionary()
	return result


func get_campaign(campaign_id: String) -> Dictionary:
	var index: int = _find_campaign_index(campaign_id)
	return WorldDataManager.war_campaigns[index].duplicate(true) if index >= 0 else {}


func get_active_campaigns(sect_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for campaign in WorldDataManager.war_campaigns:
		if str(campaign.get("phase", "")) not in ["marching", "battle"]:
			continue
		if sect_id != "" and sect_id not in [str(campaign.get("attacker_sect_id", "")), str(campaign.get("defender_sect_id", ""))]:
			continue
		result.append(campaign.duplicate(true))
	return result


func _start_campaign(attacker_sect_id: String, defender_sect_id: String, target_type: String, target_id: String, raw_attacker_ids: Array, raw_defender_ids: Array, target_position: Vector2, options: Dictionary) -> Dictionary:
	var attacker_ids: Array[String] = _validate_force(attacker_sect_id, raw_attacker_ids, false)
	var defender_ids: Array[String] = _validate_force(defender_sect_id, raw_defender_ids, target_type == "resource_site")
	if attacker_ids.is_empty() or defender_ids.is_empty() or attacker_ids.size() > MAX_FORCE_SIZE or defender_ids.size() > MAX_FORCE_SIZE:
		return _error("force_invalid", "双方需要1至%d名可用弟子。" % MAX_FORCE_SIZE)
	var origin: Vector2 = WorldDataManager.get_sect_by_id(attacker_sect_id).get("location", Vector2.ZERO)
	var campaign := WarCampaignData.new()
	campaign.campaign_id = "campaign_%05d" % _next_campaign_number
	_next_campaign_number += 1
	campaign.attacker_sect_id = attacker_sect_id
	campaign.defender_sect_id = defender_sect_id
	campaign.target_type = target_type
	campaign.target_id = target_id
	campaign.attacker_disciple_ids = attacker_ids
	campaign.defender_disciple_ids = defender_ids
	campaign.remaining_march_days = clampi(ceili(origin.distance_to(target_position) / 900.0), 1, 10)
	campaign.daily_food_cost = attacker_ids.size() * 2
	campaign.daily_spirit_stone_cost = maxi(1, attacker_ids.size())
	campaign.seed = int(options.get("seed", GameState.random_int(1, 2147483646)))
	campaign.started_date = _current_date()
	WorldDataManager.war_campaigns.append(campaign.to_dictionary())
	_set_force_deployed(attacker_ids, campaign.campaign_id, true)
	if target_type == "sect":
		_set_force_deployed(defender_ids, campaign.campaign_id, true)
	campaign_started.emit(campaign.to_dictionary())
	return {"success": true, "message": "战争队伍已出发，预计行军%d日。" % campaign.remaining_march_days, "campaign": campaign.to_dictionary()}


func _resolve_campaign_battle(campaign: WarCampaignData, date: Dictionary) -> Dictionary:
	campaign.phase = "battle"
	var battle_result: Dictionary = BattleManager.create_and_simulate(
		campaign.attacker_sect_id,
		campaign.attacker_disciple_ids,
		campaign.defender_sect_id,
		campaign.defender_disciple_ids,
		{
			"seed": campaign.seed,
			"battle_type": "siege" if campaign.target_type == "sect" else "war",
			"defender_uses_sect_defense": campaign.target_type == "sect",
		}
	)
	campaign.battle_id = str(battle_result.get("battle_id", ""))
	campaign.winner_sect_id = str(battle_result.get("winner_sect_id", ""))
	_set_force_deployed(campaign.attacker_disciple_ids, campaign.campaign_id, false)
	if campaign.target_type == "sect":
		_set_force_deployed(campaign.defender_disciple_ids, campaign.campaign_id, false)
	var territory_transfer: Dictionary = {}
	if campaign.winner_sect_id == campaign.attacker_sect_id:
		if campaign.target_type == "resource_site":
			var survivors: Array[String] = _living_force(campaign.attacker_disciple_ids, 3)
			territory_transfer = ResourceSiteManager.transfer_site_control(int(campaign.target_id), campaign.attacker_sect_id, survivors, date, "war_victory")
		else:
			_apply_siege_defeat(campaign.defender_sect_id)
	campaign.phase = "resolved"
	campaign.completed_date = date.duplicate(true)
	campaign.result = {
		"success": true,
		"campaign_id": campaign.campaign_id,
		"battle_id": campaign.battle_id,
		"winner_sect_id": campaign.winner_sect_id,
		"target_type": campaign.target_type,
		"target_id": campaign.target_id,
		"battle_result": battle_result,
		"territory_transfer": territory_transfer,
		"retreated": false,
	}
	GameHistoryManager.record_entry("war_campaign", "战争行动", "%s的战争行动已结束，%s获胜。" % [_sect_name(campaign.attacker_sect_id), _sect_name(campaign.winner_sect_id)], [campaign.campaign_id, campaign.attacker_sect_id, campaign.defender_sect_id], campaign.result, date)
	campaign_completed.emit(campaign.result)
	return campaign.result


func _complete_retreat(campaign: WarCampaignData, date: Dictionary, reason: String) -> Dictionary:
	_set_force_deployed(campaign.attacker_disciple_ids, campaign.campaign_id, false)
	if campaign.target_type == "sect":
		_set_force_deployed(campaign.defender_disciple_ids, campaign.campaign_id, false)
	campaign.phase = "retreated"
	campaign.completed_date = date.duplicate(true)
	campaign.result = {"success": true, "campaign_id": campaign.campaign_id, "retreated": true, "reason": reason}
	GameHistoryManager.record_entry("war_campaign", "战争撤退", "%s因%s而撤退。" % [_sect_name(campaign.attacker_sect_id), reason], [campaign.campaign_id, campaign.attacker_sect_id], campaign.result, date)
	campaign_completed.emit(campaign.result)
	return campaign.result


func _consume_daily_supply(campaign: WarCampaignData) -> bool:
	var resources: Dictionary = WorldDataManager.get_sect_resources(campaign.attacker_sect_id)
	if int(resources.get("food", 0)) < campaign.daily_food_cost or int(resources.get("spirit_stone", 0)) < campaign.daily_spirit_stone_cost:
		return false
	WorldDataManager.update_sect_resource(campaign.attacker_sect_id, "food", -campaign.daily_food_cost)
	WorldDataManager.update_sect_resource(campaign.attacker_sect_id, "spirit_stone", -campaign.daily_spirit_stone_cost)
	return true


func _apply_siege_defeat(defender_sect_id: String) -> void:
	var sect: Dictionary = WorldDataManager.get_sect_by_id(defender_sect_id)
	WorldDataManager.update_sect_data(defender_sect_id, "reputation", maxi(0, int(sect.get("reputation", 0)) - 20))
	WorldDataManager.update_sect_data(defender_sect_id, "combat_power", maxi(1, roundi(float(sect.get("combat_power", 1)) * 0.9)))


func _validate_force(sect_id: String, raw_ids: Array, allow_already_deployed: bool) -> Array[String]:
	var result: Array[String] = []
	for raw_id in raw_ids:
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(str(raw_id))
		if disciple == null or disciple.sect_id != sect_id or disciple.health <= 0:
			continue
		if disciple.is_deployed and not allow_already_deployed:
			continue
		if disciple.id not in result:
			result.append(disciple.id)
	return result


func _select_force(sect_id: String, count: int, include_deployed: bool) -> Array[String]:
	var candidates: Array = WorldDataManager.get_disciples_by_sect_id(sect_id).duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("combat_power", 0)) > int(b.get("combat_power", 0)))
	var result: Array[String] = []
	for data in candidates:
		if int(data.get("health", 0)) <= 0 or (bool(data.get("is_deployed", false)) and not include_deployed):
			continue
		result.append(str(data.get("disciple_id", "")))
		if result.size() >= count: break
	return result


func _living_force(disciple_ids: Array[String], limit: int) -> Array[String]:
	var result: Array[String] = []
	for disciple_id in disciple_ids:
		if int(WorldDataManager.get_disciple_by_id(disciple_id).get("health", 0)) > 0:
			result.append(disciple_id)
		if result.size() >= limit: break
	return result


func _set_force_deployed(disciple_ids: Array[String], campaign_id: String, deployed: bool) -> void:
	for disciple_id in disciple_ids:
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
		if disciple == null: continue
		if not deployed and disciple.team_id != campaign_id: continue
		disciple.is_deployed = deployed
		disciple.team_id = campaign_id if deployed else ""
		DiscipleManager.sync_disciple_state(disciple)


func _find_campaign_index(campaign_id: String) -> int:
	for index in range(WorldDataManager.war_campaigns.size()):
		if str(WorldDataManager.war_campaigns[index].get("campaign_id", "")) == campaign_id: return index
	return -1


func _sect_name(sect_id: String) -> String:
	return str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id))


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
