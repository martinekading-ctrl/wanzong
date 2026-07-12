class_name ResourceData
extends RefCounted

const RESOURCE_KEY_MAP: Dictionary = {
	"spirit_stone": "spirit_stone",
	"food": "food",
	"wood": "wood",
	"ore": "spirit_ore",
	"herb": "spirit_grass",
}

var sect_id: String = ""
var _local_resources: Dictionary = {
	"spirit_stone": 0,
	"food": 0,
	"wood": 0,
	"spirit_ore": 0,
	"spirit_grass": 0,
}

var spirit_stone: int:
	get:
		return get_amount("spirit_stone")
var food: int:
	get:
		return get_amount("food")
var wood: int:
	get:
		return get_amount("wood")
var ore: int:
	get:
		return get_amount("ore")
var herb: int:
	get:
		return get_amount("herb")


func bind_to_sect(target_sect_id: String) -> void:
	sect_id = target_sect_id


func get_amount(resource_key: String) -> int:
	var storage_key: String = _get_storage_key(resource_key)
	if storage_key == "":
		return 0
	if sect_id != "":
		return int(WorldDataManager.get_sect_resources(sect_id).get(storage_key, 0))
	return int(_local_resources.get(storage_key, 0))


func add(resource_key: String, amount: int) -> bool:
	if amount < 0:
		return remove(resource_key, -amount)
	return _change(resource_key, amount)


func remove(resource_key: String, amount: int) -> bool:
	if amount < 0:
		return add(resource_key, -amount)
	if not has_enough(resource_key, amount):
		return false
	return _change(resource_key, -amount)


func has_enough(resource_key: String, amount: int) -> bool:
	return amount >= 0 and get_amount(resource_key) >= amount


func to_dictionary() -> Dictionary:
	return {
		"spirit_stone": spirit_stone,
		"food": food,
		"wood": wood,
		"ore": ore,
		"herb": herb,
	}


func _change(resource_key: String, amount: int) -> bool:
	var storage_key: String = _get_storage_key(resource_key)
	if storage_key == "":
		push_warning("未知资源类型：" + resource_key)
		return false
	if sect_id != "":
		return WorldDataManager.update_sect_resource(sect_id, storage_key, amount)
	_local_resources[storage_key] = maxi(0, int(_local_resources.get(storage_key, 0)) + amount)
	return true


func _get_storage_key(resource_key: String) -> String:
	return str(RESOURCE_KEY_MAP.get(resource_key, ""))
