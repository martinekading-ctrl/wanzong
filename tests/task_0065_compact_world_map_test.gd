extends SceneTree

var failures := PackedStringArray()
const WORLD_SCENE_PATH := "res://scenes/world/World.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(WorldMapSpec.GRID_SIZE == Vector2i(272, 272), "网格必须为272x272")
	_expect(WorldMapSpec.WORLD_SIZE == Vector2i(4352, 4352), "世界必须为4352x4352")
	_expect(WorldMapSpec.GRID_SIZE.x * WorldMapSpec.GRID_SIZE.y == 73984, "地形格数必须为73984")
	var source := _load_map("res://scenes/world/GeneratedWorldMap.tscn")
	var runtime := _load_map("res://scenes/world/GeneratedWorldMap.scn")
	_expect(source != null and runtime != null, "tscn 与 scn 必须可加载")
	if source != null and runtime != null:
		_expect(source.call("get_terrain_cell_count") == 73984, "tscn 格数必须正确")
		_expect(source.call("get_terrain_cell_count") == runtime.call("get_terrain_cell_count"), "tscn/scn 地形必须一致")
		_expect(source.call("get_nature_instance_count") == runtime.call("get_nature_instance_count"), "tscn/scn 自然物必须一致")
		_expect(int(source.call("get_nature_instance_count")) > 0 and int(source.call("get_nature_instance_count")) < 1668, "自然物必须减少且保留")
		var world_data: Node = root.get_node("WorldDataManager")
		world_data.call("init_world_data")
		for sect in world_data.get_all_sects():
			var position: Vector2 = source.call("find_nearest_land_world_position", sect.get("location", Vector2.ZERO))
			_expect(WorldMapSpec.is_world_position_in_bounds(position), "宗门必须在边界内")
			_expect(bool(source.call("is_safe_land_world_position", position)), "宗门必须在安全陆地")
		for resource in world_data.get_all_resources():
			var position: Vector2 = source.call("find_nearest_land_world_position", resource.get("position", Vector2.ZERO))
			_expect(WorldMapSpec.is_world_position_in_bounds(position), "资源必须在边界内")
		_expect(world_data.get_all_sects().size() == 10, "必须保留10个宗门")
		_expect(world_data.get_all_resources().size() == 26, "必须保留基准的26个资源点")
		source.free()
		runtime.free()
	await _test_actual_world_placement_stability()
	if failures.is_empty():
		print("[Task0065CompactWorldMap] PASS")
		quit(0)
		return
	for failure in failures: push_error("[Task0065CompactWorldMap] " + failure)
	quit(1)


func _load_map(path: String) -> Node:
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return scene.instantiate() if scene != null else null


func _test_actual_world_placement_stability() -> void:
	var scene := load(WORLD_SCENE_PATH) as PackedScene
	_expect(scene != null, "World.tscn must load for placement regression coverage")
	if scene == null:
		return
	var game_state: Node = root.get_node("GameState")
	var world_data: Node = root.get_node("WorldDataManager")
	game_state.call("new_game")
	var expected_positions: Dictionary = {}
	for entry_index in range(3):
		var world := scene.instantiate() as Node2D
		root.add_child(world)
		await process_frame
		var map_layer: Node = world.get_node("MapLayer")
		var map: Node = map_layer.get_child(0) if map_layer.get_child_count() > 0 else null
		_expect(map != null and map.has_method("find_nearest_available_land_world_position"), "actual World must load the generated map")
		if map != null:
			_validate_actual_placement(map, world_data, expected_positions, entry_index)
		world.queue_free()
		await process_frame
		await process_frame


func _validate_actual_placement(map: Node, world_data: Node, expected_positions: Dictionary, entry_index: int) -> void:
	var occupied_cells: Dictionary = {}
	var resources: Array = world_data.call("get_all_resources")
	var resolved_resource_positions: Array[Vector2] = []
	var metadata_errors := WorldResourceBaseline.validate_resource_metadata(resources)
	_expect(metadata_errors.is_empty(), "all 26 resource metadata entries must remain baseline values")
	for sect_data in world_data.call("get_all_sects"):
		var sect: Dictionary = sect_data
		var sect_id: String = str(sect.get("sect_id", ""))
		var position: Vector2 = sect.get("location", Vector2.INF)
		_assert_stable_world_position(map, occupied_cells, expected_positions, entry_index, "sect:" + sect_id, position)
	for resource_data in resources:
		var resource: Dictionary = resource_data
		var resource_id: int = int(resource.get("resource_id", -1))
		var position: Vector2 = resource.get("position", Vector2.INF)
		_assert_stable_world_position(map, occupied_cells, expected_positions, entry_index, "resource:%d" % resource_id, position)
		for sect_data in world_data.call("get_all_sects"):
			var sect: Dictionary = sect_data
			var sect_position: Vector2 = sect.get("location", Vector2.ZERO)
			_expect(position.distance_to(sect_position) >= float(16 * WorldMapSpec.TILE_SIZE.x), "resource %d must keep the shared minimum distance to sects" % resource_id)
		for previous_position in resolved_resource_positions:
			_expect(position.distance_to(previous_position) >= float(16 * WorldMapSpec.TILE_SIZE.x), "resource %d must keep the shared minimum distance to resources" % resource_id)
		resolved_resource_positions.append(position)


func _assert_stable_world_position(map: Node, occupied_cells: Dictionary, expected_positions: Dictionary, entry_index: int, key: String, position: Vector2) -> void:
	_expect(WorldMapSpec.is_world_position_in_bounds(position), key + " must remain in compact world bounds")
	_expect(bool(map.call("is_safe_land_world_position", position)), key + " must remain on safe land")
	var cell: Vector2i = map.call("world_position_to_cell", position)
	_expect(not occupied_cells.has(cell), key + " must not share a cell with another map object")
	occupied_cells[cell] = true
	if entry_index == 0:
		expected_positions[key] = position
	else:
		_expect(expected_positions.get(key, Vector2.INF) == position, key + " must not drift after repeat world entry")


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
