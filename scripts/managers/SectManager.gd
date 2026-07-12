extends Node

var sects: Dictionary = {}


func reset() -> void:
	sects.clear()


func create_player_sect() -> SectData:
	WorldDataManager.init_world_data()
	var world_sect: Dictionary = WorldDataManager.get_player_sect()
	if world_sect.is_empty():
		push_error("SectManager：无法创建玩家宗门，缺少世界宗门数据。")
		return SectData.new()
	var player_sect := SectData.new()
	player_sect.setup_from_world_data(world_sect)
	sects[player_sect.id] = player_sect
	return player_sect


func get_sect(sect_id: String) -> SectData:
	return sects.get(sect_id) as SectData


func calculate_power(sect: SectData) -> int:
	if sect == null:
		return 0
	var disciple_power: int = 0
	for disciple in DiscipleManager.get_disciples_by_sect_id(sect.id):
		disciple_power += disciple.combat_power
	return maxi(0, sect.level * 100 + disciple_power)


# 每日直接重算宗门状态，禁止在旧战力上重复累加。
func daily_update(sect: SectData, _daily_context: Dictionary) -> Dictionary:
	if sect == null or sect.id == "":
		return {}
	var disciple_count_before: int = sect.disciples_count
	var power_before: int = sect.sect_power
	sect.disciples_count = DiscipleManager.get_disciples_by_sect_id(sect.id).size()
	sect.sect_power = calculate_power(sect)
	WorldDataManager.update_sect_data(sect.id, "disciple_count", sect.disciples_count)
	WorldDataManager.update_sect_data(sect.id, "combat_power", sect.sect_power)
	return {
		"disciple_count_before": disciple_count_before,
		"disciple_count_after": sect.disciples_count,
		"power_before": power_before,
		"power_after": sect.sect_power,
	}
