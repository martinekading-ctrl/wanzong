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
	return maxi(0, sect.sect_power + sect.disciples_count * 10 + sect.level * 100)
