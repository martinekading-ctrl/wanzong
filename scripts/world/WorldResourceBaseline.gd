class_name WorldResourceBaseline
extends RefCounted

## 只用于验证初始资源元数据没有被地图缩放逻辑改写；不参与运行时玩法数据。
const METADATA: Array[Dictionary] = [
	{"resource_id": 1, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 1, "amount": 1200, "owner_sect_id": 0},
	{"resource_id": 2, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 1, "amount": 1500, "owner_sect_id": 0},
	{"resource_id": 3, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 2, "amount": 2100, "owner_sect_id": 0},
	{"resource_id": 4, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 2, "amount": 1800, "owner_sect_id": 0},
	{"resource_id": 5, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 3, "amount": 2600, "owner_sect_id": 0},
	{"resource_id": 6, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 2, "amount": 2300, "owner_sect_id": 0},
	{"resource_id": 7, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 1, "amount": 1600, "owner_sect_id": 0},
	{"resource_id": 8, "resource_name": "灵矿", "resource_type": "spirit_mine", "level": 2, "amount": 2000, "owner_sect_id": 0},
	{"resource_id": 9, "resource_name": "灵脉", "resource_type": "spirit_vein", "level": 1, "amount": 900, "owner_sect_id": 0},
	{"resource_id": 10, "resource_name": "灵脉", "resource_type": "spirit_vein", "level": 2, "amount": 1300, "owner_sect_id": 0},
	{"resource_id": 11, "resource_name": "灵脉", "resource_type": "spirit_vein", "level": 2, "amount": 1700, "owner_sect_id": 0},
	{"resource_id": 12, "resource_name": "灵脉", "resource_type": "spirit_vein", "level": 3, "amount": 2200, "owner_sect_id": 0},
	{"resource_id": 13, "resource_name": "灵脉", "resource_type": "spirit_vein", "level": 2, "amount": 1500, "owner_sect_id": 0},
	{"resource_id": 14, "resource_name": "灵草地", "resource_type": "herb_field", "level": 1, "amount": 600, "owner_sect_id": 0},
	{"resource_id": 15, "resource_name": "灵草地", "resource_type": "herb_field", "level": 1, "amount": 720, "owner_sect_id": 0},
	{"resource_id": 16, "resource_name": "灵草地", "resource_type": "herb_field", "level": 2, "amount": 850, "owner_sect_id": 0},
	{"resource_id": 17, "resource_name": "灵草地", "resource_type": "herb_field", "level": 1, "amount": 780, "owner_sect_id": 0},
	{"resource_id": 18, "resource_name": "灵草地", "resource_type": "herb_field", "level": 2, "amount": 960, "owner_sect_id": 0},
	{"resource_id": 19, "resource_name": "灵草地", "resource_type": "herb_field", "level": 3, "amount": 1100, "owner_sect_id": 0},
	{"resource_id": 20, "resource_name": "灵草地", "resource_type": "herb_field", "level": 2, "amount": 890, "owner_sect_id": 0},
	{"resource_id": 21, "resource_name": "灵草地", "resource_type": "herb_field", "level": 1, "amount": 730, "owner_sect_id": 0},
	{"resource_id": 22, "resource_name": "灵草地", "resource_type": "herb_field", "level": 1, "amount": 690, "owner_sect_id": 0},
	{"resource_id": 23, "resource_name": "灵草地", "resource_type": "herb_field", "level": 2, "amount": 820, "owner_sect_id": 0},
	{"resource_id": 24, "resource_name": "秘境入口", "resource_type": "secret_realm", "level": 2, "amount": 1, "owner_sect_id": 0},
	{"resource_id": 25, "resource_name": "秘境入口", "resource_type": "secret_realm", "level": 3, "amount": 1, "owner_sect_id": 0},
	{"resource_id": 26, "resource_name": "秘境入口", "resource_type": "secret_realm", "level": 1, "amount": 1, "owner_sect_id": 0},
]


static func validate_resource_metadata(resources: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if resources.size() != METADATA.size():
		errors.append("resource count mismatch: expected %d, got %d" % [METADATA.size(), resources.size()])
		return errors
	for index in range(METADATA.size()):
		var expected: Dictionary = METADATA[index]
		var actual: Dictionary = resources[index]
		for key in expected:
			var matches: bool = false
			if key in ["resource_id", "level", "amount", "owner_sect_id"]:
				matches = int(actual.get(key, -1)) == int(expected[key])
			else:
				matches = str(actual.get(key, "")) == str(expected[key])
			if not matches:
				errors.append("resource %d metadata mismatch for %s" % [index + 1, key])
	return errors
