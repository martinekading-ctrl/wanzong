extends Node


func get_effect_totals(sect_id: String) -> Dictionary:
	var totals: Dictionary = {}
	for instance in ConstructionManager.get_buildings_by_sect_id(sect_id):
		if str(instance.get("status", "")) != "active" or not bool(instance.get("operational", true)):
			continue
		var definition: BuildingDefinition = BuildingRegistry.get_by_id(str(instance.get("definition_id", "")))
		if definition == null:
			continue
		var level: int = int(instance.get("level", 1))
		for effect in definition.effects:
			var key: String = str(effect.get("key", ""))
			if key == "":
				continue
			if not totals.has(key):
				totals[key] = {"add": 0.0, "multiply": 0.0}
			var operation: String = str(effect.get("operation", "add"))
			var value: float = float(effect.get("value", 0.0)) * float(level)
			totals[key][operation] = float(totals[key].get(operation, 0.0)) + value
	return totals


func apply_numeric_modifier(sect_id: String, key: String, base_value: float) -> float:
	var effect: Dictionary = get_effect_totals(sect_id).get(key, {})
	return maxf(0.0, (base_value + float(effect.get("add", 0.0))) * (1.0 + float(effect.get("multiply", 0.0))))


func get_additive_value(sect_id: String, key: String) -> float:
	return float(get_effect_totals(sect_id).get(key, {}).get("add", 0.0))


func get_multiplier_bonus(sect_id: String, key: String) -> float:
	return float(get_effect_totals(sect_id).get(key, {}).get("multiply", 0.0))


func get_disciple_capacity(sect_id: String) -> int:
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	return maxi(
		0,
		int(sect.get("base_disciple_capacity", 20))
		+ roundi(get_additive_value(sect_id, "disciple_capacity"))
	)


func get_mission_capacity(sect_id: String) -> int:
	return maxi(1, 1 + roundi(get_additive_value(sect_id, "mission_capacity")))


func get_sect_defense(sect_id: String, base_defense: int) -> int:
	return roundi(apply_numeric_modifier(sect_id, "sect_defense", float(base_defense)))
