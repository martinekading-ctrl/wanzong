extends Node

# 世界地图上的宗门数据。
var sects: Array = []

# 世界地图上的资源点数据。
var resources: Array = []


# 初始化世界数据。当前是固定原型数据，后续可以替换为存档或随机生成。
func init_world_data() -> void:
	sects = [
		{"sect_id": 1, "sect_name": "青云宗", "is_player": true, "position": Vector2(2048, 2048), "disciples_count": 20, "spirit_stones": 1000, "power": 5000},
		{"sect_id": 2, "sect_name": "玄天宗", "is_player": false, "position": Vector2(720, 900), "disciples_count": 16, "spirit_stones": 800, "power": 4200},
		{"sect_id": 3, "sect_name": "万剑宗", "is_player": false, "position": Vector2(1500, 780), "disciples_count": 28, "spirit_stones": 1300, "power": 6800},
		{"sect_id": 4, "sect_name": "赤阳宗", "is_player": false, "position": Vector2(3050, 900), "disciples_count": 24, "spirit_stones": 960, "power": 5900},
		{"sect_id": 5, "sect_name": "寒月宗", "is_player": false, "position": Vector2(3500, 1700), "disciples_count": 18, "spirit_stones": 740, "power": 4700},
		{"sect_id": 6, "sect_name": "天机宗", "is_player": false, "position": Vector2(2840, 2700), "disciples_count": 30, "spirit_stones": 1500, "power": 7300},
		{"sect_id": 7, "sect_name": "魔罗宗", "is_player": false, "position": Vector2(3400, 3300), "disciples_count": 36, "spirit_stones": 2100, "power": 8800},
		{"sect_id": 8, "sect_name": "灵兽宗", "is_player": false, "position": Vector2(1900, 3250), "disciples_count": 22, "spirit_stones": 900, "power": 5200},
		{"sect_id": 9, "sect_name": "丹霞宗", "is_player": false, "position": Vector2(760, 3050), "disciples_count": 14, "spirit_stones": 620, "power": 3900},
		{"sect_id": 10, "sect_name": "归墟宗", "is_player": false, "position": Vector2(520, 1900), "disciples_count": 32, "spirit_stones": 1700, "power": 7600},
	]

	resources = [
		{"resource_id": 1, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(350, 450), "level": 1, "amount": 1200, "owner_sect_id": 0},
		{"resource_id": 2, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(1050, 420), "level": 1, "amount": 1500, "owner_sect_id": 0},
		{"resource_id": 3, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(2350, 620), "level": 2, "amount": 2100, "owner_sect_id": 0},
		{"resource_id": 4, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(3720, 720), "level": 2, "amount": 1800, "owner_sect_id": 0},
		{"resource_id": 5, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(3600, 2400), "level": 3, "amount": 2600, "owner_sect_id": 0},
		{"resource_id": 6, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(2520, 3500), "level": 2, "amount": 2300, "owner_sect_id": 0},
		{"resource_id": 7, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(1200, 3600), "level": 1, "amount": 1600, "owner_sect_id": 0},
		{"resource_id": 8, "resource_name": "灵矿", "resource_type": "spirit_mine", "position": Vector2(420, 2550), "level": 2, "amount": 2000, "owner_sect_id": 0},
		{"resource_id": 9, "resource_name": "灵脉", "resource_type": "spirit_vein", "position": Vector2(410, 1250), "level": 1, "amount": 900, "owner_sect_id": 0},
		{"resource_id": 10, "resource_name": "灵脉", "resource_type": "spirit_vein", "position": Vector2(1900, 520), "level": 2, "amount": 1300, "owner_sect_id": 0},
		{"resource_id": 11, "resource_name": "灵脉", "resource_type": "spirit_vein", "position": Vector2(2600, 1280), "level": 2, "amount": 1700, "owner_sect_id": 0},
		{"resource_id": 12, "resource_name": "灵脉", "resource_type": "spirit_vein", "position": Vector2(3260, 2200), "level": 3, "amount": 2200, "owner_sect_id": 0},
		{"resource_id": 13, "resource_name": "灵脉", "resource_type": "spirit_vein", "position": Vector2(1450, 2650), "level": 2, "amount": 1500, "owner_sect_id": 0},
		{"resource_id": 14, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(350, 650), "level": 1, "amount": 600, "owner_sect_id": 0},
		{"resource_id": 15, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(980, 1350), "level": 1, "amount": 720, "owner_sect_id": 0},
		{"resource_id": 16, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(1600, 1250), "level": 2, "amount": 850, "owner_sect_id": 0},
		{"resource_id": 17, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(2300, 950), "level": 1, "amount": 780, "owner_sect_id": 0},
		{"resource_id": 18, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(3600, 1200), "level": 2, "amount": 960, "owner_sect_id": 0},
		{"resource_id": 19, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(3260, 2850), "level": 3, "amount": 1100, "owner_sect_id": 0},
		{"resource_id": 20, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(2800, 3600), "level": 2, "amount": 890, "owner_sect_id": 0},
		{"resource_id": 21, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(1500, 3400), "level": 1, "amount": 730, "owner_sect_id": 0},
		{"resource_id": 22, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(600, 3500), "level": 1, "amount": 690, "owner_sect_id": 0},
		{"resource_id": 23, "resource_name": "灵草地", "resource_type": "herb_field", "position": Vector2(350, 2300), "level": 2, "amount": 820, "owner_sect_id": 0},
		{"resource_id": 24, "resource_name": "秘境入口", "resource_type": "secret_realm", "position": Vector2(2500, 1650), "level": 2, "amount": 1, "owner_sect_id": 0},
		{"resource_id": 25, "resource_name": "秘境入口", "resource_type": "secret_realm", "position": Vector2(3800, 3000), "level": 3, "amount": 1, "owner_sect_id": 0},
		{"resource_id": 26, "resource_name": "秘境入口", "resource_type": "secret_realm", "position": Vector2(1100, 2200), "level": 1, "amount": 1, "owner_sect_id": 0},
	]


# 获取全部宗门数据。
func get_all_sects() -> Array:
	return sects


# 获取全部资源点数据。
func get_all_resources() -> Array:
	return resources


# 根据宗门编号查找宗门数据。
func get_sect_by_id(sect_id: int) -> Dictionary:
	for sect_data in sects:
		if int(sect_data["sect_id"]) == sect_id:
			return sect_data

	return {}


# 根据资源点编号查找资源点数据。
func get_resource_by_id(resource_id: int) -> Dictionary:
	for resource_data in resources:
		if int(resource_data["resource_id"]) == resource_id:
			return resource_data

	return {}
