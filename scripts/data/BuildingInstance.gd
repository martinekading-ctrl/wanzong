class_name BuildingInstance
extends RefCounted

var instance_id: String = ""
var definition_id: String = ""
var sect_id: String = ""
var level: int = 1
var target_level: int = 1
var status: String = "constructing"
var remaining_days: int = 0
var build_slot_id: int = -1
var started_date: Dictionary = {}
var completed_date: Dictionary = {}
var operational: bool = false
var maintenance_shortages: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"sect_id": sect_id,
		"level": level,
		"target_level": target_level,
		"status": status,
		"remaining_days": remaining_days,
		"build_slot_id": build_slot_id,
		"started_date": started_date.duplicate(true),
		"completed_date": completed_date.duplicate(true),
		"operational": operational,
		"maintenance_shortages": maintenance_shortages.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> BuildingInstance:
	var instance := BuildingInstance.new()
	instance.instance_id = str(data.get("instance_id", ""))
	instance.definition_id = str(data.get("definition_id", ""))
	instance.sect_id = str(data.get("sect_id", ""))
	instance.level = int(data.get("level", 1))
	instance.target_level = int(data.get("target_level", instance.level))
	instance.status = str(data.get("status", "constructing"))
	instance.remaining_days = int(data.get("remaining_days", 0))
	instance.build_slot_id = int(data.get("build_slot_id", -1))
	instance.started_date = data.get("started_date", {}).duplicate(true)
	instance.completed_date = data.get("completed_date", {}).duplicate(true)
	instance.operational = bool(data.get("operational", instance.status == "active"))
	instance.maintenance_shortages = data.get("maintenance_shortages", {}).duplicate(true)
	return instance
