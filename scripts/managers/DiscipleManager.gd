extends Node

var disciples: Array[DiscipleData] = []
var _next_disciple_number: int = 1


func reset() -> void:
	disciples.clear()
	_next_disciple_number = 1


func create_disciple(
	sect_id: String = "sect_001",
	disciple_name: String = "新入门弟子",
	gender: String = "男"
) -> DiscipleData:
	WorldDataManager.init_world_data()
	_update_next_disciple_number()
	var disciple := DiscipleData.new()
	disciple.id = "disciple_%03d" % _next_disciple_number
	_next_disciple_number += 1
	disciple.sect_id = sect_id
	disciple.name = disciple_name
	disciple.gender = gender
	disciples.append(disciple)
	WorldDataManager.disciples.append(disciple.to_world_dictionary())
	_sync_disciple_count(sect_id)
	return disciple


func remove_disciple(disciple_id: String) -> bool:
	var removed_sect_id: String = ""
	for index in range(disciples.size()):
		if disciples[index].id != disciple_id:
			continue
		removed_sect_id = disciples[index].sect_id
		disciples.remove_at(index)
		break
	if removed_sect_id == "":
		return false
	for index in range(WorldDataManager.disciples.size() - 1, -1, -1):
		if str(WorldDataManager.disciples[index].get("disciple_id", "")) == disciple_id:
			WorldDataManager.disciples.remove_at(index)
			break
	_sync_disciple_count(removed_sect_id)
	return true


func cultivate_all(amount: int = 10) -> void:
	for disciple in disciples:
		disciple.cultivate(amount)
		WorldDataManager.update_disciple_data(disciple.id, "cultivation", disciple.cultivation)


func load_from_world_data() -> void:
	reset()
	for world_disciple in WorldDataManager.get_all_disciples():
		var disciple := DiscipleData.new()
		disciple.id = str(world_disciple.get("disciple_id", ""))
		disciple.sect_id = str(world_disciple.get("sect_id", ""))
		disciple.name = str(world_disciple.get("disciple_name", "未命名弟子"))
		disciple.age = int(world_disciple.get("age", 16))
		disciple.gender = str(world_disciple.get("gender", "男"))
		disciple.realm = str(world_disciple.get("realm", "凡人"))
		disciple.cultivation = int(world_disciple.get("cultivation", 0))
		disciple.talent = int(world_disciple.get("talent", world_disciple.get("comprehension", 50)))
		disciple.potential = int(world_disciple.get("potential", 50))
		disciple.personality = str(world_disciple.get("personality", "沉稳"))
		disciple.health = int(world_disciple.get("health", 100))
		disciple.loyalty = int(world_disciple.get("loyalty", 50))
		disciples.append(disciple)
	_update_next_disciple_number()


func _sync_disciple_count(sect_id: String) -> void:
	var count: int = WorldDataManager.get_disciples_by_sect_id(sect_id).size()
	WorldDataManager.update_sect_data(sect_id, "disciple_count", count)
	var sect: SectData = SectManager.get_sect(sect_id)
	if sect != null:
		sect.disciples_count = count


func _update_next_disciple_number() -> void:
	var highest_number: int = 0
	for world_disciple in WorldDataManager.get_all_disciples():
		var disciple_id: String = str(world_disciple.get("disciple_id", ""))
		var number_text: String = disciple_id.trim_prefix("disciple_")
		if number_text.is_valid_int():
			highest_number = maxi(highest_number, number_text.to_int())
	_next_disciple_number = highest_number + 1
