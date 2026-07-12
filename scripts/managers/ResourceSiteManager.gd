extends Node

signal resource_site_updated(site_data: Dictionary)

const UNSECURED_DAYS_BEFORE_LOSS: int = 3
const MAX_GARRISON_SIZE: int = 3


func initialize_world_state() -> void:
	for index in range(WorldDataManager.resources.size()):
		var site: Dictionary = WorldDataManager.resources[index]
		var resource_type: String = str(site.get("resource_type", ""))
		var owner_id: String = str(site.get("owner_sect_id", ""))
		if owner_id == "0":
			owner_id = ""
		site["owner_sect_id"] = owner_id
		site["discovered_by"] = site.get("discovered_by", ["sect_001"]).duplicate()
		site["garrison_disciple_ids"] = site.get("garrison_disciple_ids", []).duplicate()
		site["garrison_team_id"] = str(site.get("garrison_team_id", ""))
		site["risk"] = float(site.get("risk", _default_risk(site)))
		site["distance"] = float(site.get("distance", _distance_from_sect(site, "sect_001")))
		site["status"] = str(site.get("status", "secret_realm" if resource_type == "secret_realm" else "unclaimed"))
		site["maintenance_shortage_days"] = int(site.get("maintenance_shortage_days", 0))
		site["unsecured_days"] = int(site.get("unsecured_days", 0))
		WorldDataManager.resources[index] = site


func rebuild_runtime_state() -> void:
	initialize_world_state()
	for site in WorldDataManager.resources:
		var resource_id: int = int(site.get("resource_id", 0))
		var owner_id: String = str(site.get("owner_sect_id", ""))
		for disciple_id in site.get("garrison_disciple_ids", []):
			_set_disciple_garrison(str(disciple_id), resource_id, owner_id != "")


func get_all_sites(include_secret_realms: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in WorldDataManager.resources:
		if not include_secret_realms and str(site.get("resource_type", "")) == "secret_realm":
			continue
		result.append(site.duplicate(true))
	return result


func get_discovered_sites(sect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in get_all_sites():
		if sect_id in site.get("discovered_by", []):
			result.append(site)
	return result


func get_owned_sites(sect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in get_all_sites():
		if str(site.get("owner_sect_id", "")) == sect_id:
			result.append(site)
	return result


func get_site_by_id(resource_id: int) -> Dictionary:
	var index: int = _find_site_index(resource_id)
	return WorldDataManager.resources[index].duplicate(true) if index >= 0 else {}


func discover_site(resource_id: int, sect_id: String) -> bool:
	var index: int = _find_site_index(resource_id)
	if index < 0:
		return false
	var site: Dictionary = WorldDataManager.resources[index]
	var discovered_by: Array = site.get("discovered_by", []).duplicate()
	if sect_id not in discovered_by:
		discovered_by.append(sect_id)
		site["discovered_by"] = discovered_by
		WorldDataManager.resources[index] = site
		resource_site_updated.emit(site.duplicate(true))
	return true


func start_capture(resource_id: int, sect_id: String, disciple_ids: Array, approach: String = "clear", options: Dictionary = {}) -> Dictionary:
	var site: Dictionary = get_site_by_id(resource_id)
	if site.is_empty() or str(site.get("resource_type", "")) == "secret_realm":
		return _error("site_not_found", "资源点不存在或不可占领。")
	if sect_id not in site.get("discovered_by", []):
		return _error("site_undiscovered", "宗门尚未发现该资源点。")
	if str(site.get("owner_sect_id", "")) != "":
		return _error("site_owned", "资源点已有归属。")
	if approach not in ["clear", "negotiate"]:
		return _error("approach_invalid", "占领方式无效。")
	var mission_id: String = "mission_hunt" if approach == "clear" else "mission_scouting"
	var mission_options: Dictionary = options.duplicate(true)
	mission_options["resource_site_id"] = resource_id
	mission_options["capture_approach"] = approach
	mission_options["terrain_bonus"] = float(mission_options.get("terrain_bonus", 0.0)) - float(site.get("risk", 0.0)) * 0.2
	return MissionManager.create_and_start_mission(sect_id, disciple_ids, mission_id, mission_options)


func record_mission_result(result: Dictionary, date: Dictionary) -> Dictionary:
	var context: Dictionary = result.get("mission_context", {})
	var resource_id: int = int(context.get("resource_site_id", 0))
	if resource_id <= 0:
		return {}
	var index: int = _find_site_index(resource_id)
	if index < 0:
		return _error("site_not_found", "占领目标已不存在。")
	if not bool(result.get("success", false)):
		return {"success": false, "captured": false, "resource_id": resource_id}
	var site: Dictionary = WorldDataManager.resources[index]
	var sect_id: String = str(result.get("sect_id", ""))
	site["owner_sect_id"] = sect_id
	site["status"] = "occupied_unsecured"
	site["unsecured_days"] = 0
	site["maintenance_shortage_days"] = 0
	site["distance"] = _distance_from_sect(site, sect_id)
	WorldDataManager.resources[index] = site
	_add_owned_resource_id(sect_id, resource_id)
	var capture_result: Dictionary = {
		"success": true,
		"captured": true,
		"resource_id": resource_id,
		"sect_id": sect_id,
		"approach": str(context.get("capture_approach", "clear")),
	}
	GameHistoryManager.record_entry(
		"resource_capture",
		"占领资源点",
		"%s占领了%s。" % [str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id)), str(site.get("resource_name", "资源点"))],
		[sect_id, "resource_%d" % resource_id],
		capture_result,
		date
	)
	resource_site_updated.emit(site.duplicate(true))
	TerritoryManager.recalculate_all()
	return capture_result


func assign_garrison(resource_id: int, sect_id: String, disciple_ids: Array) -> Dictionary:
	var index: int = _find_site_index(resource_id)
	if index < 0:
		return _error("site_not_found", "未找到资源点。")
	var site: Dictionary = WorldDataManager.resources[index]
	if str(site.get("owner_sect_id", "")) != sect_id:
		return _error("not_owner", "只有资源点所属宗门可以驻守。")
	var normalized: Array[String] = []
	for raw_id in disciple_ids:
		var disciple_id: String = str(raw_id)
		if disciple_id == "" or disciple_id in normalized:
			continue
		var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
		var current_garrison_team_id: String = str(site.get("garrison_team_id", ""))
		if disciple == null or disciple.sect_id != sect_id or (disciple.is_deployed and disciple.team_id != current_garrison_team_id):
			return _error("disciple_unavailable", "驻守弟子不可用：" + disciple_id)
		normalized.append(disciple_id)
	if normalized.is_empty() or normalized.size() > MAX_GARRISON_SIZE:
		return _error("garrison_size", "驻守队伍需要1至%d名弟子。" % MAX_GARRISON_SIZE)
	_release_site_garrison(site)
	site["garrison_disciple_ids"] = normalized
	site["garrison_team_id"] = "garrison_resource_%03d" % resource_id
	site["status"] = "occupied"
	site["unsecured_days"] = 0
	WorldDataManager.resources[index] = site
	for disciple_id in normalized:
		_set_disciple_garrison(disciple_id, resource_id, true)
	resource_site_updated.emit(site.duplicate(true))
	TerritoryManager.recalculate_all()
	return {"success": true, "message": "驻守队伍已指派。", "site": site.duplicate(true)}


func withdraw_garrison(resource_id: int, sect_id: String) -> bool:
	var index: int = _find_site_index(resource_id)
	if index < 0:
		return false
	var site: Dictionary = WorldDataManager.resources[index]
	if str(site.get("owner_sect_id", "")) != sect_id:
		return false
	_release_site_garrison(site)
	site["garrison_disciple_ids"] = []
	site["garrison_team_id"] = ""
	site["status"] = "occupied_unsecured"
	site["unsecured_days"] = 0
	WorldDataManager.resources[index] = site
	resource_site_updated.emit(site.duplicate(true))
	TerritoryManager.recalculate_all()
	return true


func daily_update(date: Dictionary) -> Dictionary:
	var production: Array[Dictionary] = []
	var lost_sites: Array[Dictionary] = []
	for index in range(WorldDataManager.resources.size()):
		var site: Dictionary = WorldDataManager.resources[index]
		var owner_id: String = str(site.get("owner_sect_id", ""))
		if owner_id == "" or str(site.get("resource_type", "")) == "secret_realm":
			continue
		var garrison: Array = site.get("garrison_disciple_ids", [])
		var maintenance: int = maxi(1, ceili(float(site.get("distance", 0.0)) / 1500.0))
		var food: int = int(WorldDataManager.get_sect_resources(owner_id).get("food", 0))
		if garrison.is_empty() or food < maintenance:
			site["unsecured_days"] = int(site.get("unsecured_days", 0)) + 1
			if food < maintenance:
				site["maintenance_shortage_days"] = int(site.get("maintenance_shortage_days", 0)) + 1
			if int(site["unsecured_days"]) >= UNSECURED_DAYS_BEFORE_LOSS:
				lost_sites.append(_lose_site(site, date))
				continue
			site["status"] = "occupied_unsecured"
			WorldDataManager.resources[index] = site
			continue
		WorldDataManager.update_sect_resource(owner_id, "food", -maintenance)
		site["unsecured_days"] = 0
		site["maintenance_shortage_days"] = 0
		site["status"] = "occupied"
		var yield_data: Dictionary = _calculate_daily_yield(site)
		var reserve_cost: int = 0
		for resource_key in yield_data:
			var amount: int = int(yield_data[resource_key])
			WorldDataManager.update_sect_resource(owner_id, str(resource_key), amount)
			reserve_cost += amount
		site["amount"] = maxi(0, int(site.get("amount", 0)) - reserve_cost)
		if int(site["amount"]) == 0:
			site["status"] = "depleted"
		WorldDataManager.resources[index] = site
		production.append({"resource_id": int(site.get("resource_id", 0)), "sect_id": owner_id, "yield": yield_data, "maintenance_food": maintenance})
	return {"production": production, "lost_sites": lost_sites}


func _calculate_daily_yield(site: Dictionary) -> Dictionary:
	var level: int = maxi(1, int(site.get("level", 1)))
	var remaining: int = int(site.get("amount", 0))
	if remaining <= 0:
		return {}
	var key: String = ""
	var base_amount: int = 0
	match str(site.get("resource_type", "")):
		"spirit_mine":
			key = "spirit_ore"
			base_amount = level * 5
		"spirit_vein":
			key = "spirit_stone"
			base_amount = level * 8
		"herb_field":
			key = "spirit_grass"
			base_amount = level * 6
	return {key: mini(base_amount, remaining)} if key != "" else {}


func _lose_site(site: Dictionary, date: Dictionary) -> Dictionary:
	var resource_id: int = int(site.get("resource_id", 0))
	var owner_id: String = str(site.get("owner_sect_id", ""))
	_release_site_garrison(site)
	site["owner_sect_id"] = ""
	site["garrison_disciple_ids"] = []
	site["garrison_team_id"] = ""
	site["status"] = "unclaimed"
	site["unsecured_days"] = 0
	var index: int = _find_site_index(resource_id)
	WorldDataManager.resources[index] = site
	_remove_owned_resource_id(owner_id, resource_id)
	var result: Dictionary = {"resource_id": resource_id, "former_owner": owner_id, "reason": "unsecured"}
	GameHistoryManager.record_entry("resource_lost", "资源点失守", "%s因长期无人驻守而失守。" % str(site.get("resource_name", "资源点")), [owner_id, "resource_%d" % resource_id], result, date)
	resource_site_updated.emit(site.duplicate(true))
	TerritoryManager.recalculate_all()
	return result


func _release_site_garrison(site: Dictionary) -> void:
	for disciple_id in site.get("garrison_disciple_ids", []):
		_set_disciple_garrison(str(disciple_id), int(site.get("resource_id", 0)), false)


func _set_disciple_garrison(disciple_id: String, resource_id: int, deployed: bool) -> void:
	var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
	if disciple == null:
		return
	disciple.is_deployed = deployed
	disciple.team_id = "garrison_resource_%03d" % resource_id if deployed else ""
	DiscipleManager.sync_disciple_state(disciple)


func _add_owned_resource_id(sect_id: String, resource_id: int) -> void:
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	var owned: Array = sect.get("owned_resource_ids", []).duplicate()
	if resource_id not in owned:
		owned.append(resource_id)
		WorldDataManager.update_sect_data(sect_id, "owned_resource_ids", owned)


func _remove_owned_resource_id(sect_id: String, resource_id: int) -> void:
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	var owned: Array = sect.get("owned_resource_ids", []).duplicate()
	owned.erase(resource_id)
	WorldDataManager.update_sect_data(sect_id, "owned_resource_ids", owned)


func _distance_from_sect(site: Dictionary, sect_id: String) -> float:
	var sect: Dictionary = WorldDataManager.get_sect_by_id(sect_id)
	var sect_position: Vector2 = sect.get("location", Vector2.ZERO)
	var site_position: Vector2 = site.get("position", Vector2.ZERO)
	return sect_position.distance_to(site_position)


func _default_risk(site: Dictionary) -> float:
	return clampf(0.1 + float(site.get("level", 1)) * 0.1, 0.1, 0.7)


func _find_site_index(resource_id: int) -> int:
	for index in range(WorldDataManager.resources.size()):
		if int(WorldDataManager.resources[index].get("resource_id", 0)) == resource_id:
			return index
	return -1


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
