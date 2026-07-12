class_name BattleUnitData
extends RefCounted

var unit_id: String = ""
var disciple_id: String = ""
var sect_id: String = ""
var display_name: String = ""
var battle_position: String = "middle"
var max_hp: int = 100
var current_hp: int = 100
var attack: int = 10
var defense: int = 10
var speed: int = 10
var spiritual_power: int = 10
var accuracy: float = 0.85
var critical_rate: float = 0.05
var resistance: float = 0.0
var status_effects: Array[Dictionary] = []


func is_alive() -> bool:
	return current_hp > 0


func to_dictionary() -> Dictionary:
	return {
		"unit_id": unit_id,
		"disciple_id": disciple_id,
		"sect_id": sect_id,
		"display_name": display_name,
		"battle_position": battle_position,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"spiritual_power": spiritual_power,
		"accuracy": accuracy,
		"critical_rate": critical_rate,
		"resistance": resistance,
		"status_effects": status_effects.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> BattleUnitData:
	var unit := BattleUnitData.new()
	unit.unit_id = str(data.get("unit_id", ""))
	unit.disciple_id = str(data.get("disciple_id", ""))
	unit.sect_id = str(data.get("sect_id", ""))
	unit.display_name = str(data.get("display_name", unit.disciple_id))
	unit.battle_position = str(data.get("battle_position", "middle"))
	unit.max_hp = maxi(1, int(data.get("max_hp", 100)))
	unit.current_hp = clampi(int(data.get("current_hp", unit.max_hp)), 0, unit.max_hp)
	unit.attack = maxi(1, int(data.get("attack", 10)))
	unit.defense = maxi(0, int(data.get("defense", 10)))
	unit.speed = maxi(1, int(data.get("speed", 10)))
	unit.spiritual_power = maxi(0, int(data.get("spiritual_power", 10)))
	unit.accuracy = clampf(float(data.get("accuracy", 0.85)), 0.1, 1.0)
	unit.critical_rate = clampf(float(data.get("critical_rate", 0.05)), 0.0, 0.8)
	unit.resistance = clampf(float(data.get("resistance", 0.0)), 0.0, 0.8)
	unit.status_effects.assign(data.get("status_effects", []))
	return unit

