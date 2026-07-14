extends SceneTree

var failures := PackedStringArray()
const WorldDataManagerScript := preload("res://scripts/managers/WorldDataManager.gd")


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
		var world_data := WorldDataManagerScript.new()
		world_data.init_world_data()
		for sect in world_data.get_all_sects():
			var position: Vector2 = source.call("find_nearest_land_world_position", sect.get("location", Vector2.ZERO))
			_expect(WorldMapSpec.is_world_position_in_bounds(position), "宗门必须在边界内")
			_expect(bool(source.call("_is_safe_land", Vector2i(position / Vector2(WorldMapSpec.TILE_SIZE)))), "宗门必须在安全陆地")
		for resource in world_data.get_all_resources():
			var position: Vector2 = source.call("find_nearest_land_world_position", resource.get("position", Vector2.ZERO))
			_expect(WorldMapSpec.is_world_position_in_bounds(position), "资源必须在边界内")
		_expect(world_data.get_all_sects().size() == 10, "必须保留10个宗门")
		_expect(world_data.get_all_resources().size() == 20, "必须保留20个资源点")
		source.free()
		runtime.free()
	if failures.is_empty():
		print("[Task0065CompactWorldMap] PASS")
		quit(0)
		return
	for failure in failures: push_error("[Task0065CompactWorldMap] " + failure)
	quit(1)


func _load_map(path: String) -> Node:
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return scene.instantiate() if scene != null else null


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
