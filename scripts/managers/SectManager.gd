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


func create_sect(sect_id: String) -> SectData:
	if sects.has(sect_id):
		return sects[sect_id] as SectData
	var world_sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	if world_sect.is_empty():
		push_warning("SectManager：未找到宗门数据：" + sect_id)
		return null
	var sect := SectData.new()
	sect.setup_from_world_data(world_sect)
	sects[sect.id] = sect
	return sect


func get_all_runtime_sects() -> Array[SectData]:
	var result: Array[SectData] = []
	for sect in sects.values():
		result.append(sect as SectData)
	return result


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


func get_sect_upgrade_preview(sect_id: String) -> Dictionary:
	var sect_data: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	if sect_data.is_empty():
		return {}
	var current_level: int = int(sect_data.get("territory_level", 1))
	var hall_level: int = 0
	for building in ConstructionManager.get_buildings_by_sect_id(sect_id):
		if str(building.get("definition_id", "")) == "sect_hall" and str(building.get("status", "")) == "active" and bool(building.get("operational", true)):
			hall_level = int(building.get("level", 0))
			break
	var costs: Dictionary = {
		"spirit_stone": current_level * 500,
		"wood": current_level * 200,
		"stone": current_level * 200,
	}
	return {
		"current_level": current_level,
		"next_level": current_level + 1,
		"hall_level": hall_level,
		"costs": costs,
		"can_upgrade": current_level < 5 and hall_level >= current_level and _has_resources(sect_id, costs),
	}


func upgrade_sect(sect_id: String) -> Dictionary:
	var preview: Dictionary = get_sect_upgrade_preview(sect_id)
	if preview.is_empty():
		return {"success": false, "message": "宗门不存在。"}
	if int(preview.get("current_level", 1)) >= 5:
		return {"success": false, "message": "宗门已达到当前最高等级。"}
	if int(preview.get("hall_level", 0)) < int(preview.get("current_level", 1)):
		return {"success": false, "message": "宗门大殿等级不足。"}
	var costs: Dictionary = preview["costs"]
	if not _has_resources(sect_id, costs):
		return {"success": false, "message": "宗门升级资源不足。", "costs": costs}
	for resource_key in costs:
		WorldDataManager.update_sect_resource(sect_id, str(resource_key), -int(costs[resource_key]))
	var next_level: int = int(preview["next_level"])
	WorldDataManager.update_sect_data(sect_id, "territory_level", next_level)
	var runtime_sect: SectData = get_sect(sect_id)
	if runtime_sect != null:
		runtime_sect.level = next_level
	GameHistoryManager.record_entry(
		"sect_upgrade", "宗门升级", "%s晋升至%d级宗门。" % [str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id)), next_level], [sect_id], {"level": next_level, "costs": costs}
	)
	return {"success": true, "message": "宗门已晋升至%d级。" % next_level, "level": next_level, "costs": costs}


func _has_resources(sect_id: String, costs: Dictionary) -> bool:
	var resources: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	for resource_key in costs:
		if int(resources.get(resource_key, 0)) < int(costs[resource_key]):
			return false
	return true
