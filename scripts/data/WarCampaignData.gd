class_name WarCampaignData
extends RefCounted

var campaign_id: String = ""
var attacker_sect_id: String = ""
var defender_sect_id: String = ""
var target_type: String = "resource_site"
var target_id: String = ""
var attacker_disciple_ids: Array[String] = []
var defender_disciple_ids: Array[String] = []
var phase: String = "marching"
var remaining_march_days: int = 1
var daily_food_cost: int = 0
var daily_spirit_stone_cost: int = 0
var supply_shortage_days: int = 0
var seed: int = 0
var battle_id: String = ""
var winner_sect_id: String = ""
var started_date: Dictionary = {}
var completed_date: Dictionary = {}
var result: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"campaign_id": campaign_id,
		"attacker_sect_id": attacker_sect_id,
		"defender_sect_id": defender_sect_id,
		"target_type": target_type,
		"target_id": target_id,
		"attacker_disciple_ids": attacker_disciple_ids.duplicate(),
		"defender_disciple_ids": defender_disciple_ids.duplicate(),
		"phase": phase,
		"remaining_march_days": remaining_march_days,
		"daily_food_cost": daily_food_cost,
		"daily_spirit_stone_cost": daily_spirit_stone_cost,
		"supply_shortage_days": supply_shortage_days,
		"seed": seed,
		"battle_id": battle_id,
		"winner_sect_id": winner_sect_id,
		"started_date": started_date.duplicate(true),
		"completed_date": completed_date.duplicate(true),
		"result": result.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> WarCampaignData:
	var campaign := WarCampaignData.new()
	campaign.campaign_id = str(data.get("campaign_id", ""))
	campaign.attacker_sect_id = str(data.get("attacker_sect_id", ""))
	campaign.defender_sect_id = str(data.get("defender_sect_id", ""))
	campaign.target_type = str(data.get("target_type", "resource_site"))
	campaign.target_id = str(data.get("target_id", ""))
	campaign.attacker_disciple_ids.assign(data.get("attacker_disciple_ids", []))
	campaign.defender_disciple_ids.assign(data.get("defender_disciple_ids", []))
	campaign.phase = str(data.get("phase", "marching"))
	campaign.remaining_march_days = int(data.get("remaining_march_days", 1))
	campaign.daily_food_cost = int(data.get("daily_food_cost", 0))
	campaign.daily_spirit_stone_cost = int(data.get("daily_spirit_stone_cost", 0))
	campaign.supply_shortage_days = int(data.get("supply_shortage_days", 0))
	campaign.seed = int(data.get("seed", 0))
	campaign.battle_id = str(data.get("battle_id", ""))
	campaign.winner_sect_id = str(data.get("winner_sect_id", ""))
	campaign.started_date = data.get("started_date", {}).duplicate(true)
	campaign.completed_date = data.get("completed_date", {}).duplicate(true)
	campaign.result = data.get("result", {}).duplicate(true)
	return campaign

