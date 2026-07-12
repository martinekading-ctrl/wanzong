extends Node


func calculate_sect_monthly_change(sect_id: String) -> Dictionary:
	var resource_change: Dictionary = {}
	var disciples: Array = WorldDataManager.get_disciples_by_sect_id(sect_id)

	for disciple_data in disciples:
		match str(disciple_data.get("assignment", "空闲")):
			"修炼":
				_add_resource_change(resource_change, "spirit_stone", -10)
			"采集":
				_add_resource_change(resource_change, "wood", 4)
				_add_resource_change(resource_change, "stone", 2)
				_add_resource_change(resource_change, "spirit_grass", 1)
			"闭关":
				_add_resource_change(resource_change, "spirit_stone", -20)

	return resource_change


func _add_resource_change(resource_change: Dictionary, resource_key: String, amount: int) -> void:
	resource_change[resource_key] = int(resource_change.get(resource_key, 0)) + amount
