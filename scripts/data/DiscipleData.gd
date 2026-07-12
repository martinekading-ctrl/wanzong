class_name DiscipleData
extends RefCounted

const BREAKTHROUGH_REQUIREMENT: int = 100

var id: String = ""
var sect_id: String = ""
var name: String = ""
var age: int = 16
var gender: String = "男"
var realm: String = "凡人"
var cultivation: int = 0
var talent: int = 50
var potential: int = 50
var personality: String = "沉稳"
var health: int = 100
var loyalty: int = 50
var assignment: String = "空闲"


func cultivate(amount: int = 10) -> void:
	cultivation = maxi(0, cultivation + amount)


func breakthrough() -> bool:
	if cultivation < BREAKTHROUGH_REQUIREMENT:
		return false
	cultivation -= BREAKTHROUGH_REQUIREMENT
	realm = "炼气一层" if realm == "凡人" else realm
	return true


func to_world_dictionary() -> Dictionary:
	return {
		"disciple_id": id,
		"sect_id": sect_id,
		"disciple_name": name,
		"gender": gender,
		"age": age,
		"role": "外门弟子",
		"realm": realm,
		"spiritual_root": "杂灵根",
		"aptitude": _get_aptitude_name(),
		"comprehension": talent,
		"loyalty": loyalty,
		"mood": health,
		"assignment": assignment,
		"combat_power": maxi(10, cultivation + talent),
		"status": "正常",
		"description": "由弟子数据系统创建的宗门弟子。",
		"appearance_id": "male_disciple_01" if gender == "男" else "female_disciple_01",
		"portrait_id": "portrait_male_01" if gender == "男" else "portrait_female_01",
		"model_id": "model_male_01" if gender == "男" else "model_female_01",
		"battle_model_id": "battle_male_01" if gender == "男" else "battle_female_01",
		"color_scheme": "outer_gray",
		"tags": [personality],
		"is_deployed": false,
		"team_id": "",
		"battle_position": "middle",
		"weapon_type": "拳掌",
		"hp": health,
		"max_hp": 100,
		"attack": maxi(10, talent / 2),
		"defense": maxi(10, potential / 2),
		"speed": 40,
		"spiritual_power": cultivation,
		"battle_status": "正常",
		"cultivation": cultivation,
		"talent": talent,
		"potential": potential,
		"personality": personality,
		"health": health,
	}


func _get_aptitude_name() -> String:
	if potential >= 90:
		return "极品"
	if potential >= 70:
		return "上品"
	if potential >= 40:
		return "中品"
	return "下品"
