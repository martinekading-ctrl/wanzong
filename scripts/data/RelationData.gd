class_name RelationData
extends RefCounted

var relation_id: String = ""
var sect_a_id: String = ""
var sect_b_id: String = ""
var value: int = 0
var status: String = "neutral"
var trust: int = 50
var tension: int = 0
var treaties: Array[String] = []
var cooldowns: Dictionary = {}
var action_history: Array[Dictionary] = []
var last_changed_date: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"relation_id": relation_id,
		"sect_a_id": sect_a_id,
		"sect_b_id": sect_b_id,
		"value": value,
		"status": status,
		"trust": trust,
		"tension": tension,
		"treaties": treaties.duplicate(),
		"cooldowns": cooldowns.duplicate(true),
		"action_history": action_history.duplicate(true),
		"last_changed_date": last_changed_date.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> RelationData:
	var relation := RelationData.new()
	relation.relation_id = str(data.get("relation_id", ""))
	relation.sect_a_id = str(data.get("sect_a_id", ""))
	relation.sect_b_id = str(data.get("sect_b_id", ""))
	relation.value = clampi(int(data.get("value", 0)), -100, 100)
	relation.status = str(data.get("status", "neutral"))
	relation.trust = clampi(int(data.get("trust", 50)), 0, 100)
	relation.tension = clampi(int(data.get("tension", 0)), 0, 100)
	relation.treaties.assign(data.get("treaties", []))
	relation.cooldowns = data.get("cooldowns", {}).duplicate(true)
	relation.action_history.assign(data.get("action_history", []))
	relation.last_changed_date = data.get("last_changed_date", {}).duplicate(true)
	return relation

