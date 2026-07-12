extends Node

signal territories_recalculated(summary: Dictionary)

const MAP_MIN := Vector2.ZERO
const MAP_MAX := Vector2(6144.0, 6144.0)
const BASE_CONTROL_PADDING: float = 90.0


func initialize_world_state() -> void:
	recalculate_all()


func rebuild_runtime_state() -> void:
	recalculate_all()


func daily_update(date: Dictionary) -> Dictionary:
	var summary: Dictionary = recalculate_all()
	summary["date"] = date.duplicate(true)
	return summary


func recalculate_all() -> Dictionary:
	var new_states: Dictionary = {}
	for sect in WorldDataManager.get_all_sects():
		if not bool(sect.get("is_active", true)):
			continue
		var sect_id: String = str(sect.get("sect_id", ""))
		new_states[sect_id] = _calculate_state(sect)
	_calculate_neighbors_and_contests(new_states)
	WorldDataManager.territory_states = new_states
	for sect_id in new_states:
		WorldDataManager.update_sect_data(sect_id, "territory_radius", float(new_states[sect_id].get("display_radius", 180.0)))
	var summary: Dictionary = {
		"sect_count": new_states.size(),
		"contested_points": _count_contested_points(new_states),
	}
	territories_recalculated.emit(summary)
	return summary


func get_territory(sect_id: String) -> Dictionary:
	return WorldDataManager.territory_states.get(sect_id, {}).duplicate(true)


func get_all_territories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in WorldDataManager.territory_states.values():
		result.append(state.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("sect_id", "")) < str(b.get("sect_id", "")))
	return result


func get_dominant_sect_at_position(world_position: Vector2) -> String:
	var best_sect_id: String = ""
	var best_score: float = -INF
	for state in WorldDataManager.territory_states.values():
		var boundary: PackedVector2Array = _to_vector_array(state.get("boundary_points", []))
		if boundary.size() < 3 or not Geometry2D.is_point_in_polygon(world_position, boundary):
			continue
		var distance: float = world_position.distance_to(state.get("center", Vector2.ZERO))
		var score: float = float(state.get("influence", 0.0)) - distance * 0.1
		if score > best_score:
			best_score = score
			best_sect_id = str(state.get("sect_id", ""))
	return best_sect_id


func _calculate_state(sect: Dictionary) -> Dictionary:
	var sect_id: String = str(sect.get("sect_id", ""))
	var owned_sites: Array[Dictionary] = ResourceSiteManager.get_owned_sites(sect_id)
	var controlled_resource_ids: Array[int] = []
	var control_positions := PackedVector2Array([sect.get("location", Vector2.ZERO)])
	var resource_influence: int = 0
	var garrison_power: int = 0
	for site in owned_sites:
		controlled_resource_ids.append(int(site.get("resource_id", 0)))
		control_positions.append(site.get("position", Vector2.ZERO))
		resource_influence += int(site.get("level", 1)) * 75
		for disciple_id in site.get("garrison_disciple_ids", []):
			garrison_power += int(WorldDataManager.get_disciple_by_id(str(disciple_id)).get("combat_power", 0))
	var ai_bonus: int = int(WorldDataManager.ai_states.get(sect_id, {}).get("influence", 0)) * 10
	var influence: int = maxi(1,
		int(sect.get("combat_power", 0)) / 20
		+ int(sect.get("reputation", 0)) / 2
		+ int(sect.get("territory_level", 1)) * 100
		+ resource_influence
		+ garrison_power / 10
		+ ai_bonus
	)
	var display_radius: float = 160.0 + sqrt(float(influence)) * 10.0
	var padding: float = BASE_CONTROL_PADDING + sqrt(float(influence)) * 2.0
	return {
		"sect_id": sect_id,
		"influence": influence,
		"center": sect.get("location", Vector2.ZERO),
		"display_radius": display_radius,
		"control_point_ids": controlled_resource_ids,
		"control_positions": Array(control_positions),
		"boundary_points": Array(_build_boundary(control_positions, padding)),
		"neighbors": [],
		"contested_point_ids": [],
	}


func _build_boundary(control_positions: PackedVector2Array, padding: float) -> PackedVector2Array:
	var samples := PackedVector2Array()
	for position in control_positions:
		for step in range(12):
			var angle: float = TAU * float(step) / 12.0
			var point: Vector2 = position + Vector2.from_angle(angle) * padding
			point.x = clampf(point.x, MAP_MIN.x, MAP_MAX.x)
			point.y = clampf(point.y, MAP_MIN.y, MAP_MAX.y)
			samples.append(point)
	return Geometry2D.convex_hull(samples)


func _calculate_neighbors_and_contests(states: Dictionary) -> void:
	var ids: Array = states.keys()
	for left_index in range(ids.size()):
		var left_id: String = str(ids[left_index])
		var left: Dictionary = states[left_id]
		for right_index in range(left_index + 1, ids.size()):
			var right_id: String = str(ids[right_index])
			var right: Dictionary = states[right_id]
			var distance: float = (left.get("center", Vector2.ZERO) as Vector2).distance_to(right.get("center", Vector2.ZERO))
			if distance <= float(left.get("display_radius", 0.0)) + float(right.get("display_radius", 0.0)):
				left["neighbors"].append(right_id)
				right["neighbors"].append(left_id)
		states[left_id] = left
	for site in ResourceSiteManager.get_all_sites():
		var claimants: Array[String] = []
		var position: Vector2 = site.get("position", Vector2.ZERO)
		for sect_id in states:
			var boundary: PackedVector2Array = _to_vector_array(states[sect_id].get("boundary_points", []))
			if boundary.size() >= 3 and Geometry2D.is_point_in_polygon(position, boundary):
				claimants.append(str(sect_id))
		if claimants.size() < 2:
			continue
		for sect_id in claimants:
			states[sect_id]["contested_point_ids"].append(int(site.get("resource_id", 0)))


func _count_contested_points(states: Dictionary) -> int:
	var ids: Dictionary = {}
	for state in states.values():
		for resource_id in state.get("contested_point_ids", []):
			ids[int(resource_id)] = true
	return ids.size()


func _to_vector_array(values: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		result.append(value as Vector2)
	return result
