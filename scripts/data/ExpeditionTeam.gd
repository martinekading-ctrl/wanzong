class_name ExpeditionTeam
extends RefCounted

var team_id: String = ""
var sect_id: String = ""
var disciple_ids: Array[String] = []
var status: String = "ready"
var mission_instance_id: String = ""


func to_dictionary() -> Dictionary:
	return {
		"team_id": team_id,
		"sect_id": sect_id,
		"disciple_ids": disciple_ids.duplicate(),
		"status": status,
		"mission_instance_id": mission_instance_id,
	}


static func from_dictionary(data: Dictionary) -> ExpeditionTeam:
	var team := ExpeditionTeam.new()
	team.team_id = str(data.get("team_id", ""))
	team.sect_id = str(data.get("sect_id", ""))
	team.disciple_ids.assign(data.get("disciple_ids", []))
	team.status = str(data.get("status", "ready"))
	team.mission_instance_id = str(data.get("mission_instance_id", ""))
	return team
