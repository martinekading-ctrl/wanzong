extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _territory_manager: Node
var _resource_site_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_territory_manager = root.get_node("TerritoryManager")
	_resource_site_manager = root.get_node("ResourceSiteManager")
	_test_initial_influence_and_boundaries()
	_test_control_points_and_garrison_influence()
	_test_ai_influence_neighbors_and_save()
	await _test_world_territory_rendering()
	if _failures.is_empty():
		print("[Task0050Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0050Test] " + failure)
	quit(1)


func _test_initial_influence_and_boundaries() -> void:
	_game_state.new_game()
	var territories: Array[Dictionary] = _territory_manager.get_all_territories()
	_expect(territories.size() == 10, "十个初始宗门都应拥有领地状态。")
	for territory in territories:
		_expect(int(territory.get("influence", 0)) > 0, "宗门影响力必须为正数。")
		_expect(territory.get("boundary_points", []).size() >= 12, "领地边界应由控制点生成多边形。")
		_expect(territory.get("control_positions", []).size() >= 1, "宗门驻地必须是首个控制点。")
	var player: Dictionary = _territory_manager.get_territory("sect_001")
	_expect(player.get("control_point_ids", []).is_empty(), "未占领资源点时仅由宗门驻地形成领地。")
	_expect(_territory_manager.get_dominant_sect_at_position(player.get("center", Vector2.ZERO)) == "sect_001", "宗门驻地应由自身影响力控制。")


func _test_control_points_and_garrison_influence() -> void:
	_game_state.new_game()
	var before: Dictionary = _territory_manager.get_territory("sect_001")
	var capture: Dictionary = _resource_site_manager.record_mission_result({
		"success": true,
		"sect_id": "sect_001",
		"mission_context": {"resource_site_id": 1, "capture_approach": "clear"},
	}, {"year": 1, "month": 1, "day": 1})
	_expect(bool(capture.get("captured", false)), "测试资源点应能成为实际控制点。")
	var after_capture: Dictionary = _territory_manager.get_territory("sect_001")
	_expect(1 in after_capture.get("control_point_ids", []), "占领资源点应加入领地控制点。")
	_expect(int(after_capture.get("influence", 0)) > int(before.get("influence", 0)), "资源点等级应增加宗门影响力。")
	var boundary := PackedVector2Array(after_capture.get("boundary_points", []))
	_expect(Geometry2D.is_point_in_polygon(_resource_site_manager.get_site_by_id(1).get("position", Vector2.ZERO), boundary), "实际控制点必须位于本宗领地边界内。")
	var influence_before_garrison: int = int(after_capture.get("influence", 0))
	var assigned: Dictionary = _resource_site_manager.assign_garrison(1, "sect_001", ["disciple_003"])
	_expect(bool(assigned.get("success", false)), "资源点应能指派驻守。")
	var after_garrison: Dictionary = _territory_manager.get_territory("sect_001")
	_expect(int(after_garrison.get("influence", 0)) > influence_before_garrison, "驻守弟子战力应增加控制影响力。")


func _test_ai_influence_neighbors_and_save() -> void:
	_game_state.new_game()
	var before: int = int(_territory_manager.get_territory("sect_002").get("influence", 0))
	_world_data_manager.ai_states["sect_002"]["influence"] = int(_world_data_manager.ai_states["sect_002"].get("influence", 0)) + 50
	_territory_manager.recalculate_all()
	var after: int = int(_territory_manager.get_territory("sect_002").get("influence", 0))
	_expect(after == before + 500, "AI战略影响力应通过统一公式进入领地计算。")
	for territory in _territory_manager.get_all_territories():
		var sect_id: String = str(territory.get("sect_id", ""))
		for neighbor_id in territory.get("neighbors", []):
			_expect(sect_id in _territory_manager.get_territory(str(neighbor_id)).get("neighbors", []), "邻接关系必须双向一致。")
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.territory_states.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "领地与影响力状态应可存档恢复。")
	_expect(_territory_manager.get_all_territories().size() == 10, "读档后应重算十个宗门领地。")
	var report: Dictionary = _game_state.next_day()
	_expect(int(report.get("territories", {}).get("sect_count", 0)) == 10, "每日统一推进应包含领地刷新摘要。")


func _test_world_territory_rendering() -> void:
	_game_state.new_game()
	var layer := Node2D.new()
	root.add_child(layer)
	for sect in _world_data_manager.get_all_sects():
		var area := TerritoryArea.new()
		area.setup(sect, _territory_manager.get_territory(str(sect.get("sect_id", ""))))
		layer.add_child(area)
	await process_frame
	_expect(layer.get_child_count() == 10, "世界地图应以十个轻量节点显示派生领地边界。")
	for child in layer.get_children():
		_expect((child as TerritoryArea).local_boundary_points.size() >= 12, "领地显示必须读取计算后的多边形边界。")
	layer.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
