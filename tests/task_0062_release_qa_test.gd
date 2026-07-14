extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data = root.get_node("WorldDataManager")
	await _test_world_loading_and_repeat_entry()
	if "--world-only" in OS.get_cmdline_user_args():
		root.get_node("AudioManager").call("shutdown_audio")
		await process_frame
		print("[Task0062WorldOnly] PASS")
		quit(0)
		return
	_test_ten_year_simulation()
	root.get_node("AudioManager").call("shutdown_audio")
	await process_frame
	if _failures.is_empty():
		print("[Task0062Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0062Test] " + failure)
	quit(1)


func _test_world_loading_and_repeat_entry() -> void:
	_game_state.new_game()
	var source: String = FileAccess.get_file_as_string("res://scripts/world/World.gd")
	_expect("const USE_RUNTIME_WORLD_GENERATION := false" in source, "正式世界必须禁用运行时程序化生成。")
	_expect("PixelWorldPreview" not in source, "正式 World 脚本不得引用开发预览生成器。")
	_expect(ResourceLoader.exists("res://scenes/world/GeneratedWorldMap.scn"), "发布运行时二进制地图必须存在。")
	var scene := load("res://scenes/world/World.tscn") as PackedScene
	_expect(scene != null, "世界场景必须可加载。")
	if scene == null:
		return

	var baseline_children: int = root.get_child_count()
	var first_started: int = Time.get_ticks_msec()
	var first_world := scene.instantiate()
	root.add_child(first_world)
	var first_interactive_ms: int = Time.get_ticks_msec() - first_started
	var first_visual_ms: int = await _wait_for_visual_assets(first_world)
	_validate_world_instance(first_world)
	_expect(first_interactive_ms < 2500, "首次进入世界地图应在2.5秒内可交互。")
	_expect(first_visual_ms < 4000, "首次进入世界地图的正式图标应在4秒内加载完成。")
	var date_before: Array[int] = [_game_state.year, _game_state.month, _game_state.day]
	first_world.queue_free()
	await process_frame
	await process_frame

	var second_started: int = Time.get_ticks_msec()
	var second_world := scene.instantiate()
	root.add_child(second_world)
	var second_interactive_ms: int = Time.get_ticks_msec() - second_started
	var second_visual_ms: int = await _wait_for_visual_assets(second_world)
	_validate_world_instance(second_world)
	_expect(second_interactive_ms < 2000, "再次进入世界地图应在2秒内可交互。")
	_expect([_game_state.year, _game_state.month, _game_state.day] == date_before, "重复进入世界地图不得重置游戏日期。")
	second_world.queue_free()
	await process_frame
	await process_frame
	_expect(root.get_child_count() == baseline_children, "重复进入并退出世界地图后不得遗留场景节点。")
	print("[Task0062World] first_interactive_ms=%d first_visual_ms=%d second_interactive_ms=%d second_visual_ms=%d" % [
		first_interactive_ms,
		first_visual_ms,
		second_interactive_ms,
		second_visual_ms,
	])


func _wait_for_visual_assets(world: Node) -> int:
	var started_at: int = Time.get_ticks_msec()
	while not (world.get("pending_texture_paths") as Dictionary).is_empty():
		if Time.get_ticks_msec() - started_at > 8000:
			break
		await process_frame
	return Time.get_ticks_msec() - started_at


func _validate_world_instance(world: Node) -> void:
	var map_layer: Node = world.get_node("MapLayer")
	var map: Node = map_layer.get_child(0) if map_layer.get_child_count() > 0 else null
	_expect(map != null and map.name == "GeneratedWorldMap", "世界页必须显示正式烘焙地图。")
	if map == null:
		return
	var nature: Node = map.get_node("NatureObjects")
	_expect(nature.get_child_count() < 50, "自然物渲染节点必须少于50。")
	_expect(int(map.call("get_terrain_cell_count")) == WorldMapSpec.GRID_SIZE.x * WorldMapSpec.GRID_SIZE.y, "运行时烘焙地图格数必须符合统一规格。")
	_expect(int(map.call("get_nature_instance_count")) > 0 and int(map.call("get_nature_instance_count")) < 1668, "缩小后的自然物必须存在且少于旧地图。")
	_expect(_count_nodes(map) < 50, "运行时烘焙地图应保持少量批处理节点。")
	var resource_layer: Node = world.get_node("ResourceLayer")
	var sect_layer: Node = world.get_node("SectLayer")
	_expect(resource_layer.get_child_count() == _world_data.get_all_resources().size(), "资源点节点数量应与世界数据一致。")
	_expect(sect_layer.get_child_count() == _world_data.get_all_sects().size(), "宗门节点数量应与世界数据一致。")
	for node in resource_layer.get_children() + sect_layer.get_children():
		var cell := Vector2i(int(node.position.x / 16.0), int(node.position.y / 16.0))
		_expect(bool(map.call("_is_safe_land", cell)), "宗门和资源点必须落在安全陆地范围。")
	for resource_node in resource_layer.get_children():
		_expect(resource_node.get("resource_sprite") != null, "后台加载结束后资源点必须使用正式图片。")
	for sect_node in sect_layer.get_children():
		_expect(sect_node.get("icon_sprite") != null, "后台加载结束后宗门必须使用正式图片。")


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _test_ten_year_simulation() -> void:
	_game_state.new_game()
	var original_date: Array[int] = [_game_state.year, _game_state.month, _game_state.day]
	var result: Dictionary = BalanceSimulation.run(3600, true)
	_expect(int(result.get("days_completed", 0)) == 3600, "发布QA必须完整模拟十个游戏年。")
	_expect(int(result.get("negative_resource_count", -1)) == 0, "十年模拟中不得出现负资源。")
	_expect(int(result.get("maximum_day_ms", 10000)) < 2000, "十年模拟单日峰值不得超过两秒。")
	_expect(int(result.get("sect_count", 0)) >= WorldSectRoster.expected_sect_count() and int(result.get("active_ai_count", 0)) >= WorldSectRoster.expected_ai_sect_count(), "十年后AI世界仍须保持完整五宗门名册。")
	_expect(int(result.get("save_size_bytes", 1000000000)) < 64 * 1024 * 1024, "十年存档快照应小于64MB。")
	_expect(bool(result.get("restored", false)), "十年模拟后必须成功回滚测试快照。")
	_expect([_game_state.year, _game_state.month, _game_state.day] == original_date, "十年回滚后不得污染玩家日期。")
	print("[Task0062TenYear] %s" % result)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
