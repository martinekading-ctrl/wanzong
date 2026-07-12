class_name BattleInstanceData
extends RefCounted

var battle_id: String = ""
var battle_type: String = "skirmish"
var attacker_sect_id: String = ""
var defender_sect_id: String = ""
var attacker_units: Array[Dictionary] = []
var defender_units: Array[Dictionary] = []
var seed: int = 0
var status: String = "prepared"
var current_round: int = 0
var winner_sect_id: String = ""
var loser_sect_id: String = ""
var created_date: Dictionary = {}
var completed_date: Dictionary = {}
var battle_log: Array[String] = []
var injuries: Array[Dictionary] = []
var loot: Dictionary = {}
var result: Dictionary = {}
var options: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"battle_id": battle_id,
		"battle_type": battle_type,
		"attacker_sect_id": attacker_sect_id,
		"defender_sect_id": defender_sect_id,
		"attacker_units": attacker_units.duplicate(true),
		"defender_units": defender_units.duplicate(true),
		"seed": seed,
		"status": status,
		"current_round": current_round,
		"winner_sect_id": winner_sect_id,
		"loser_sect_id": loser_sect_id,
		"created_date": created_date.duplicate(true),
		"completed_date": completed_date.duplicate(true),
		"battle_log": battle_log.duplicate(),
		"injuries": injuries.duplicate(true),
		"loot": loot.duplicate(true),
		"result": result.duplicate(true),
		"options": options.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> BattleInstanceData:
	var battle := BattleInstanceData.new()
	battle.battle_id = str(data.get("battle_id", ""))
	battle.battle_type = str(data.get("battle_type", "skirmish"))
	battle.attacker_sect_id = str(data.get("attacker_sect_id", ""))
	battle.defender_sect_id = str(data.get("defender_sect_id", ""))
	battle.attacker_units.assign(data.get("attacker_units", []))
	battle.defender_units.assign(data.get("defender_units", []))
	battle.seed = int(data.get("seed", 0))
	battle.status = str(data.get("status", "prepared"))
	battle.current_round = int(data.get("current_round", 0))
	battle.winner_sect_id = str(data.get("winner_sect_id", ""))
	battle.loser_sect_id = str(data.get("loser_sect_id", ""))
	battle.created_date = data.get("created_date", {}).duplicate(true)
	battle.completed_date = data.get("completed_date", {}).duplicate(true)
	battle.battle_log.assign(data.get("battle_log", []))
	battle.injuries.assign(data.get("injuries", []))
	battle.loot = data.get("loot", {}).duplicate(true)
	battle.result = data.get("result", {}).duplicate(true)
	battle.options = data.get("options", {}).duplicate(true)
	return battle
