extends Node

# 世界地图上的宗门数据。
var sects: Array = []

# 世界地图上的资源点数据。
var resources: Array = []

# 玩家宗门可建设点数据。
var build_slots: Array = []

var disciples: Array = []

var is_initialized: bool = false


# 初始化世界数据。当前是固定原型数据，后续可以替换为存档或随机生成。
func init_world_data() -> void:
	if is_initialized:
		return

	sects = [
		_create_sect_data(
			"sect_001", "青玄宗", true, "orthodox", "玩家", "九品",
			12, 1000, 100, 350, Vector2(2048, 2048), "self",
			[], [1, 2, 3, 4, 5, 6],
			"初立山门的小型修仙宗门，未来可统御万宗。", 450
		),
		_create_sect_data(
			"sect_002", "凌霄剑派", false, "sword", "陆长风", "八品",
			86, 5600, 430, 2100, Vector2(720, 900), "neutral",
			[], [], "以剑修闻名的山门，门人擅长攻伐。"
		),
		_create_sect_data(
			"sect_003", "赤炉丹阁", false, "alchemy", "沈丹霞", "八品",
			64, 7200, 510, 1680, Vector2(1500, 780), "friendly",
			[], [], "精研丹火与药理，以灵丹妙药广结善缘。"
		),
		_create_sect_data(
			"sect_004", "血煞魔门", false, "demonic", "厉无咎", "七品",
			132, 9800, -260, 4200, Vector2(3050, 900), "hostile",
			[], [], "盘踞荒野的魔道宗门，行事狠厉且崇尚强者。"
		),
		_create_sect_data(
			"sect_005", "金莲寺", false, "buddhist", "慧明禅师", "七品",
			118, 8400, 760, 3150, Vector2(3500, 1700), "friendly",
			[], [], "以金莲佛法护佑一方，门人善守亦善度化。"
		),
		_create_sect_data(
			"sect_006", "寒月宫", false, "snow", "宫主苏寒月", "七品",
			97, 7600, 580, 3380, Vector2(2840, 2700), "neutral",
			[], [], "坐落北境雪原，传承寒月一脉的冰系术法。"
		),
		_create_sect_data(
			"sect_007", "黄沙门", false, "desert", "拓跋烈", "八品",
			73, 4900, 280, 2260, Vector2(3400, 3300), "neutral",
			[], [], "扎根大漠商道，擅长御沙与追踪之术。"
		),
		_create_sect_data(
			"sect_008", "沧海阁", false, "ocean", "洛沧澜", "七品",
			105, 9100, 690, 3520, Vector2(1900, 3250), "friendly",
			[], [], "立于东海群岛，门下修士精通水法与舟阵。"
		),
		_create_sect_data(
			"sect_009", "玄雷宗", false, "orthodox", "雷震岳", "六品",
			168, 12800, 820, 5860, Vector2(760, 3050), "neutral",
			[], [], "以玄雷淬体立宗，功法刚猛，声势显赫。"
		),
		_create_sect_data(
			"sect_010", "万兽山", false, "orthodox", "岳千峰", "五品",
			236, 18600, 960, 7450, Vector2(520, 1900), "hostile",
			[], [], "雄踞群山并与灵兽共修，是实力深厚的古老宗门。"
		),
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

	build_slots = [
		{"slot_id": 1, "owner_sect_id": "sect_001", "position": Vector2(1868, 1928), "is_empty": true},
		{"slot_id": 2, "owner_sect_id": "sect_001", "position": Vector2(2048, 1868), "is_empty": true},
		{"slot_id": 3, "owner_sect_id": "sect_001", "position": Vector2(2228, 1938), "is_empty": true},
		{"slot_id": 4, "owner_sect_id": "sect_001", "position": Vector2(1848, 2168), "is_empty": true},
		{"slot_id": 5, "owner_sect_id": "sect_001", "position": Vector2(2068, 2198), "is_empty": true},
		{"slot_id": 6, "owner_sect_id": "sect_001", "position": Vector2(2268, 2148), "is_empty": true},
	]

	disciples = [
		_create_disciple_data("disciple_001", "sect_001", "林青", "男", 18, "炼气三层", "木灵根", "上品", 72, 88, 76, "修炼", 165, "正常", "性情沉稳，擅长吐纳行气，是青玄宗年轻弟子中的中坚。"),
		_create_disciple_data("disciple_002", "sect_001", "许念", "女", 17, "炼气二层", "水灵根", "中品", 81, 84, 82, "采集", 118, "正常", "心思细腻，善于辨认灵草，对宗门事务颇为上心。"),
		_create_disciple_data("disciple_003", "sect_001", "周衡", "男", 22, "炼气四层", "金灵根", "上品", 66, 79, 68, "巡山", 218, "正常", "剑骨初成，行事果断，是巡守山门的可靠人选。"),
		_create_disciple_data("disciple_004", "sect_001", "沈月", "女", 19, "炼气三层", "冰灵根", "极品", 89, 91, 74, "闭关", 196, "闭关中", "灵根稀有，悟性出众，正在稳固自身寒气灵机。"),
		_create_disciple_data("disciple_005", "sect_001", "陆远", "男", 20, "炼气二层", "土灵根", "中品", 58, 82, 70, "空闲", 110, "正常", "根基扎实，做事耐心，适合承担长期细致的宗门任务。"),
		_create_disciple_data("disciple_006", "sect_001", "白芷", "女", 16, "炼气一层", "木灵根", "上品", 77, 86, 88, "采集", 86, "正常", "熟悉草木药性，入门虽晚但进境平稳。"),
		_create_disciple_data("disciple_007", "sect_001", "韩石", "男", 24, "炼气三层", "土灵根", "下品", 45, 93, 65, "巡山", 142, "正常", "体魄强健，忠诚可靠，常主动承担苦活。"),
		_create_disciple_data("disciple_008", "sect_001", "顾云", "男", 18, "炼气五层", "雷灵根", "极品", 84, 73, 60, "修炼", 286, "正常", "天赋锋芒毕露，但心性仍需磨砺。"),
		_create_disciple_data("disciple_009", "sect_001", "苏灵儿", "女", 15, "炼气一层", "水灵根", "中品", 92, 80, 91, "空闲", 72, "正常", "聪慧活泼，对术法变化极为敏感。"),
		_create_disciple_data("disciple_010", "sect_001", "赵铁山", "男", 26, "炼气四层", "金灵根", "中品", 52, 96, 71, "巡山", 205, "正常", "性格豪爽，护宗心重，是山门里的硬骨头。"),
		_create_disciple_data("disciple_011", "sect_001", "江晚", "女", 21, "炼气二层", "火灵根", "上品", 75, 78, 69, "修炼", 128, "受伤", "曾在外出采药时受伤，目前仍坚持温养灵力。"),
		_create_disciple_data("disciple_012", "sect_001", "叶寒", "男", 17, "凡人", "杂灵根", "下品", 61, 90, 83, "空闲", 35, "正常", "刚入宗不久，灵根驳杂但意志坚韧。"),
	]
	update_sect_data("sect_001", "disciple_count", disciples.size())

	is_initialized = true


func reset_world_data() -> void:
	is_initialized = false
	sects.clear()
	resources.clear()
	build_slots.clear()
	disciples.clear()
	init_world_data()


# 统一创建宗门数据，确保十个宗门拥有完全一致的字段结构。
func _create_sect_data(
	sect_id: String,
	sect_name: String,
	is_player: bool,
	sect_type: String,
	master_name: String,
	realm_rank: String,
	disciple_count: int,
	spirit_stone: int,
	reputation: int,
	combat_power: int,
	location: Vector2,
	relation_to_player: String,
	owned_resource_ids: Array,
	build_slot_ids: Array,
	description: String,
	territory_radius: float = 350.0
) -> Dictionary:
	return {
		"sect_id": sect_id,
		"sect_name": sect_name,
		"is_player": is_player,
		"sect_type": sect_type,
		"master_name": master_name,
		"realm_rank": realm_rank,
		"disciple_count": disciple_count,
		"spirit_stone": spirit_stone,
		"reputation": reputation,
		"combat_power": combat_power,
		"location": location,
		# 保留 position 别名，兼容现有地图节点和领地显示。
		"position": location,
		"relation_to_player": relation_to_player,
		"owned_resource_ids": owned_resource_ids,
		"build_slot_ids": build_slot_ids,
		"description": description,
		"territory_radius": territory_radius,
		"territory_level": 1,
	}


func _create_disciple_data(
	disciple_id: String,
	sect_id: String,
	disciple_name: String,
	gender: String,
	age: int,
	realm: String,
	spiritual_root: String,
	aptitude: String,
	comprehension: int,
	loyalty: int,
	mood: int,
	assignment: String,
	combat_power: int,
	status: String,
	description: String
) -> Dictionary:
	return {
		"disciple_id": disciple_id,
		"sect_id": sect_id,
		"disciple_name": disciple_name,
		"gender": gender,
		"age": age,
		"realm": realm,
		"spiritual_root": spiritual_root,
		"aptitude": aptitude,
		"comprehension": comprehension,
		"loyalty": loyalty,
		"mood": mood,
		"assignment": assignment,
		"combat_power": combat_power,
		"status": status,
		"description": description,
	}


# 获取全部宗门数据。
func get_all_sects() -> Array:
	return sects


# 获取全部资源点数据。
func get_all_resources() -> Array:
	return resources


# 获取全部建设点数据。
func get_all_build_slots() -> Array:
	return build_slots


func get_all_disciples() -> Array:
	return disciples


# 根据字符串宗门 ID 查找宗门数据。
func get_sect_by_id(sect_id: String) -> Dictionary:
	for sect_data in sects:
		if str(sect_data["sect_id"]) == sect_id:
			return sect_data

	return {}


# 更新单个宗门字段；位置字段会同步兼容用的 position/location 别名。
func update_sect_data(sect_id: String, key: String, value: Variant) -> bool:
	for sect_index in range(sects.size()):
		var sect_data: Dictionary = sects[sect_index]
		if str(sect_data["sect_id"]) != sect_id:
			continue

		sect_data[key] = value
		if key == "location":
			sect_data["position"] = value
		elif key == "position":
			sect_data["location"] = value
		sects[sect_index] = sect_data
		return true

	push_warning("更新宗门数据失败，未找到宗门：" + sect_id)
	return false


# 获取玩家宗门。
func get_player_sect() -> Dictionary:
	for sect_data in sects:
		if bool(sect_data.get("is_player", false)):
			return sect_data
	return {}


# 获取全部 AI 宗门。
func get_ai_sects() -> Array:
	var ai_sects: Array = []
	for sect_data in sects:
		if not bool(sect_data.get("is_player", false)):
			ai_sects.append(sect_data)
	return ai_sects


func get_disciples_by_sect_id(sect_id: String) -> Array:
	var result: Array = []
	for disciple_data in disciples:
		if str(disciple_data["sect_id"]) == sect_id:
			result.append(disciple_data)
	return result


func get_player_disciples() -> Array:
	var player_sect: Dictionary = get_player_sect()
	if player_sect.is_empty():
		return []
	return get_disciples_by_sect_id(str(player_sect["sect_id"]))


func get_disciple_by_id(disciple_id: String) -> Dictionary:
	for disciple_data in disciples:
		if str(disciple_data["disciple_id"]) == disciple_id:
			return disciple_data
	return {}


func update_disciple_data(disciple_id: String, key: String, value: Variant) -> bool:
	for disciple_index in range(disciples.size()):
		var disciple_data: Dictionary = disciples[disciple_index]
		if str(disciple_data["disciple_id"]) != disciple_id:
			continue

		disciple_data[key] = value
		disciples[disciple_index] = disciple_data
		return true

	push_warning("更新弟子数据失败，未找到弟子：" + disciple_id)
	return false


# 根据资源点编号查找资源点数据。
func get_resource_by_id(resource_id: int) -> Dictionary:
	for resource_data in resources:
		if int(resource_data["resource_id"]) == resource_id:
			return resource_data

	return {}


# 根据宗门 ID 获取建设点数据。
func get_build_slots_by_sect_id(sect_id: String) -> Array:
	var result: Array = []

	for slot_data in build_slots:
		if str(slot_data["owner_sect_id"]) == sect_id:
			result.append(slot_data)

	return result
