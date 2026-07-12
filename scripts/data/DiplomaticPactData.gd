class_name DiplomaticPactData
extends RefCounted

var pact_id: String = ""
var pact_type: String = ""
var member_ids: Array[String] = []
var overlord_sect_id: String = ""
var vassal_sect_id: String = ""
var status: String = "active"
var started_date: Dictionary = {}
var ended_date: Dictionary = {}
var expires_on_ordinal: int = 0
var terms: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"pact_id": pact_id,
		"pact_type": pact_type,
		"member_ids": member_ids.duplicate(),
		"overlord_sect_id": overlord_sect_id,
		"vassal_sect_id": vassal_sect_id,
		"status": status,
		"started_date": started_date.duplicate(true),
		"ended_date": ended_date.duplicate(true),
		"expires_on_ordinal": expires_on_ordinal,
		"terms": terms.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> DiplomaticPactData:
	var pact := DiplomaticPactData.new()
	pact.pact_id = str(data.get("pact_id", ""))
	pact.pact_type = str(data.get("pact_type", ""))
	pact.member_ids.assign(data.get("member_ids", []))
	pact.overlord_sect_id = str(data.get("overlord_sect_id", ""))
	pact.vassal_sect_id = str(data.get("vassal_sect_id", ""))
	pact.status = str(data.get("status", "active"))
	pact.started_date = data.get("started_date", {}).duplicate(true)
	pact.ended_date = data.get("ended_date", {}).duplicate(true)
	pact.expires_on_ordinal = int(data.get("expires_on_ordinal", 0))
	pact.terms = data.get("terms", {}).duplicate(true)
	return pact

