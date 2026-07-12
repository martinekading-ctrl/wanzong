class_name EventInstance
extends RefCounted

var instance_id: String = ""
var definition_id: String = ""
var status: String = "pending"
var created_date: Dictionary = {}
var context: Dictionary = {}
var selected_option_id: String = ""
var result: Dictionary = {}


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"status": status,
		"created_date": created_date.duplicate(true),
		"context": context.duplicate(true),
		"selected_option_id": selected_option_id,
		"result": result.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> EventInstance:
	var instance := EventInstance.new()
	instance.instance_id = str(data.get("instance_id", ""))
	instance.definition_id = str(data.get("definition_id", ""))
	instance.status = str(data.get("status", "pending"))
	instance.created_date = data.get("created_date", {}).duplicate(true)
	instance.context = data.get("context", {}).duplicate(true)
	instance.selected_option_id = str(data.get("selected_option_id", ""))
	instance.result = data.get("result", {}).duplicate(true)
	return instance
