class_name WorldSectBaseline
extends RefCounted

## 仅用于测试与发布检查的开局基线，不参与运行时生成。
const METADATA_BY_ID := {
	"sect_001": {"sect_id":"sect_001", "sect_name":"青玄宗", "is_player":true, "sect_type":"orthodox", "master_name":"玩家", "realm_rank":"九品", "disciple_count":12, "reputation":100, "combat_power":350, "relation_to_player":"self", "description":"初立山门的小型修仙宗门，未来可统御万宗。", "territory_radius":289.228479833201},
	"sect_002": {"sect_id":"sect_002", "sect_name":"凌霄剑派", "is_player":false, "sect_type":"sword", "master_name":"陆长风", "realm_rank":"八品", "disciple_count":86, "reputation":430, "combat_power":2100, "relation_to_player":"neutral", "description":"以剑修闻名的山门，门人擅长攻伐。", "territory_radius":410.998007960223},
	"sect_003": {"sect_id":"sect_003", "sect_name":"赤炉丹阁", "is_player":false, "sect_type":"alchemy", "master_name":"沈丹霞", "realm_rank":"八品", "disciple_count":64, "reputation":510, "combat_power":1680, "relation_to_player":"friendly", "description":"精研丹火与药理，以灵丹妙药广结善缘。", "territory_radius":404.744765010408},
	"sect_004": {"sect_id":"sect_004", "sect_name":"血煞魔门", "is_player":false, "sect_type":"demonic", "master_name":"厉无咎", "realm_rank":"七品", "disciple_count":132, "reputation":-260, "combat_power":4200, "relation_to_player":"hostile", "description":"盘踞荒野的魔道宗门，行事狠厉且崇尚强者。", "territory_radius":404.948974278318},
	"sect_005": {"sect_id":"sect_005", "sect_name":"金莲寺", "is_player":false, "sect_type":"buddhist", "master_name":"慧明禅师", "realm_rank":"七品", "disciple_count":118, "reputation":760, "combat_power":3150, "relation_to_player":"friendly", "description":"以金莲佛法护佑一方，门人善守亦善度化。", "territory_radius":467.733651068582},
}
const RESOURCES_BY_ID := {
	"sect_001": {"spirit_stone":1000,"food":5000,"wood":300,"stone":200,"spirit_grass":50,"spirit_ore":20,"population":500},
	"sect_002": {"spirit_stone":5000,"food":10000,"wood":800,"stone":600,"spirit_grass":200,"spirit_ore":100,"population":1200},
	"sect_003": {"spirit_stone":7200,"food":8600,"wood":520,"stone":430,"spirit_grass":680,"spirit_ore":80,"population":960},
	"sect_004": {"spirit_stone":9800,"food":13200,"wood":1100,"stone":900,"spirit_grass":160,"spirit_ore":420,"population":1750},
	"sect_005": {"spirit_stone":8400,"food":15000,"wood":700,"stone":760,"spirit_grass":360,"spirit_ore":140,"population":1680},
}

static func validate_sects(sects: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var actual := {}
	for index in range(sects.size()):
		if not sects[index] is Dictionary:
			errors.append("sects[%d] must be a Dictionary" % index)
			continue
		var sect: Dictionary = sects[index]
		var sect_id := str(sect.get("sect_id", ""))
		if actual.has(sect_id): errors.append("sects contains duplicate sect_id: " + sect_id)
		actual[sect_id] = sect
	for sect_id in METADATA_BY_ID:
		if not actual.has(sect_id):
			errors.append("sects missing baseline sect: " + sect_id)
			continue
		for field in (METADATA_BY_ID[sect_id] as Dictionary):
			var expected: Variant = (METADATA_BY_ID[sect_id] as Dictionary)[field]
			var value: Variant = (actual[sect_id] as Dictionary).get(field)
			if not _values_match(value, expected):
				errors.append("sects.%s.%s expected %s actual %s" % [sect_id, field, str(expected), str(value)])
	for sect_id in actual:
		if not METADATA_BY_ID.has(sect_id): errors.append("sects contains extra sect: " + str(sect_id))
	return errors

static func _values_match(actual: Variant, expected: Variant) -> bool:
	if actual is float and expected is float:
		return is_equal_approx(actual, expected)
	return actual == expected

static func validate_sect_resources(sect_resources: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for sect_id in RESOURCES_BY_ID:
		if not sect_resources.has(sect_id):
			errors.append("sect_resources missing baseline sect: " + sect_id)
			continue
		var actual: Dictionary = sect_resources[sect_id]
		for field in (RESOURCES_BY_ID[sect_id] as Dictionary):
			var expected: Variant = (RESOURCES_BY_ID[sect_id] as Dictionary)[field]
			var value: Variant = actual.get(field)
			if value != expected:
				errors.append("sect_resources.%s.%s expected %s actual %s" % [sect_id, field, str(expected), str(value)])
	for sect_id in sect_resources:
		if not RESOURCES_BY_ID.has(str(sect_id)): errors.append("sect_resources contains extra sect: " + str(sect_id))
	return errors
