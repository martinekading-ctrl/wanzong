class_name SectData
extends RefCounted

var id: String = ""
var name: String = ""
var level: int = 1
var resources: ResourceData = ResourceData.new()
var sect_power: int = 0
var reputation: int = 0
var territory: float = 0.0
var disciples_count: int = 0
var buildings: Array = []

var spirit_stone: int:
	get:
		return resources.spirit_stone
var food: int:
	get:
		return resources.food
var wood: int:
	get:
		return resources.wood
var ore: int:
	get:
		return resources.ore
var herbs: int:
	get:
		return resources.herb


func setup_from_world_data(sect_data: Dictionary) -> void:
	id = str(sect_data.get("sect_id", ""))
	name = str(sect_data.get("sect_name", "未命名宗门"))
	level = int(sect_data.get("territory_level", 1))
	sect_power = int(sect_data.get("combat_power", 0))
	reputation = int(sect_data.get("reputation", 0))
	territory = float(sect_data.get("territory_radius", 0.0))
	disciples_count = int(sect_data.get("disciple_count", 0))
	resources.bind_to_sect(id)


func add_resource(resource_key: String, amount: int) -> bool:
	return resources.add(resource_key, amount)


func consume_resource(resource_key: String, amount: int) -> bool:
	return resources.remove(resource_key, amount)


func increase_power(amount: int) -> void:
	sect_power = maxi(0, sect_power + amount)
	if id != "":
		WorldDataManager.update_sect_data(id, "combat_power", sect_power)
