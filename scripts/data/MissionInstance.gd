class_name MissionInstance
extends RefCounted

var instance_id: String = ""
var definition_id: String = ""
var sect_id: String = ""
var team_id: String = ""
var status: String = "active"
var remaining_days: int = 0
var started_date: Dictionary = {}
var completed_date: Dictionary = {}
var success_chance: float = 0.0
var test_roll: float = -1.0
var result: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"sect_id": sect_id,
		"team_id": team_id,
		"status": status,
		"remaining_days": remaining_days,
		"started_date": started_date.duplicate(true),
		"completed_date": completed_date.duplicate(true),
		"success_chance": success_chance,
		"test_roll": test_roll,
		"result": result.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> MissionInstance:
	var instance := MissionInstance.new()
	instance.instance_id = str(data.get("instance_id", ""))
	instance.definition_id = str(data.get("definition_id", ""))
	instance.sect_id = str(data.get("sect_id", ""))
	instance.team_id = str(data.get("team_id", ""))
	instance.status = str(data.get("status", "active"))
	instance.remaining_days = int(data.get("remaining_days", 0))
	instance.started_date = data.get("started_date", {}).duplicate(true)
	instance.completed_date = data.get("completed_date", {}).duplicate(true)
	instance.success_chance = float(data.get("success_chance", 0.0))
	instance.test_roll = float(data.get("test_roll", -1.0))
	instance.result = data.get("result", {}).duplicate(true)
	return instance
