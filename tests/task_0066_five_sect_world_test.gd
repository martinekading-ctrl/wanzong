extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")
const WorldSectReferenceValidator = preload("res://scripts/world/WorldSectReferenceValidator.gd")
const WORLD_SCENE_PATH := "res://scenes/world/World.tscn"
const LEGACY_SAVE_PATH := "user://task_0066_legacy_ten_sect.save"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_roster_and_initial_world_state()
	await _test_actual_world_placement()
	_test_save_roster_compatibility()
	if _failures.is_empty():
		print("[Task0066FiveSectWorld] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0066FiveSectWorld] " + failure)
	quit(1)


func _test_roster_and_initial_world_state() -> void:
	var game_state: Node = root.get_node("GameState")
	var world_data: Node = root.get_node("WorldDataManager")
	game_state.call("new_game")
	_expect(WorldSectRoster.validate().is_empty(), "五宗门名册必须有效")
	_expect(WorldSectRoster.ROSTER_VERSION == 2, "宗门名册版本必须为2")
	_expect(WorldSectRoster.expected_sect_count() == 5, "初始宗门必须为五个")
	_expect(WorldSectRoster.expected_ai_sect_count() == 4, "初始AI宗门必须为四个")
	var sects: Array = world_data.call("get_all_sects")
	_expect(sects.size() == 5, "WorldDataManager 必须只创建五个初始宗门")
	for index in range(sects.size()):
		var sect: Dictionary = sects[index]
		_expect(str(sect.get("sect_id", "")) == WorldSectRoster.ACTIVE_SECT_IDS[index], "宗门ID顺序必须与名册一致")
	_expect(bool(sects[0].get("is_player", false)), "sect_001 必须是玩家宗门")
	_expect(str(sects[0].get("sect_type", "")) == "orthodox", "青玄宗必须保持正道类型")
	_expect(str(sects[1].get("sect_type", "")) == "sword", "凌霄剑派必须保持剑修类型")
	_expect(str(sects[2].get("sect_type", "")) == "alchemy", "赤炉丹阁必须保持丹修类型")
	_expect(str(sects[3].get("sect_type", "")) == "demonic", "血煞魔门必须保持魔宗类型")
	_expect(str(sects[4].get("sect_type", "")) == "buddhist", "金莲寺必须保持佛修类型")
	_expect((world_data.call("get_all_resources") as Array).size() == 26, "资源点数量必须保持26")
	_expect((world_data.call("get_all_build_slots") as Array).size() == 6, "建设点数量必须保持6")
	_expect((world_data.ai_states as Dictionary).size() == 4, "AI状态必须只包含四个初始AI宗门")
	for ai_id in WorldSectRoster.AI_SECT_IDS:
		_expect((world_data.ai_states as Dictionary).has(ai_id), "缺少AI状态：" + ai_id)
	for disciple_data in world_data.call("get_all_disciples"):
		var disciple: Dictionary = disciple_data
		_expect(not str(disciple.get("sect_id", "")) in WorldSectRoster.REMOVED_DEVELOPMENT_SECT_IDS, "AI弟子不能引用已移除宗门")
	var state: Dictionary = world_data.call("export_world_state")
	_expect(int(state.get("world_sect_roster_version", 0)) == 2, "导出的世界状态必须记录名册版本")
	_expect(WorldSectReferenceValidator.validate_world_state(state).is_empty(), "初始世界状态不得含悬空宗门引用")


func _test_actual_world_placement() -> void:
	var scene := load(WORLD_SCENE_PATH) as PackedScene
	_expect(scene != null, "World.tscn 必须可加载")
	if scene == null:
		return
	var expected_positions: Dictionary = {}
	for entry_index in range(3):
		var world := scene.instantiate() as Node2D
		root.add_child(world)
		await process_frame
		_expect(str(world.call("get_loaded_world_map_path")) == "res://scenes/world/GeneratedWorldMap.scn", "正式世界必须加载 GeneratedWorldMap.scn")
		_expect(not bool(world.call("is_using_simple_world_fallback")), "正式世界不得回退到简化地图")
		_expect(bool(world.call("is_world_initialization_successful")), "世界初始化必须完整成功")
		_expect(world.get_node("SectLayer").get_child_count() == 5, "场景中的宗门节点必须恰好为五个")
		_expect(world.get_node("ResourceLayer").get_child_count() == 26, "场景中的资源节点必须恰好为二十六个")
		_expect(world.get_node("BuildSlotLayer").get_child_count() == 6, "场景中的建设点必须恰好为六个")
		var map: Node = world.get_node("MapLayer").get_child(0)
		var world_data: Node = root.get_node("WorldDataManager")
		var occupied: Dictionary = {}
		for sect_data in world_data.call("get_all_sects"):
			var sect: Dictionary = sect_data
			var sect_id := str(sect.get("sect_id", ""))
			var position: Vector2 = sect.get("location", Vector2.INF)
			_expect(WorldMapSpec.is_world_position_in_bounds(position), sect_id + " 必须位于世界范围内")
			_expect(bool(map.call("is_safe_land_world_position", position)), sect_id + " 必须落在安全陆地")
			var cell := Vector2i(floori(position.x / WorldMapSpec.TILE_SIZE.x), floori(position.y / WorldMapSpec.TILE_SIZE.y))
			_expect(not occupied.has(cell), sect_id + " 不得与其他宗门共享地图格")
			occupied[cell] = true
			if entry_index == 0:
				expected_positions[sect_id] = position
			else:
				_expect(expected_positions.get(sect_id, Vector2.INF) == position, sect_id + " 重复进入地图时不得漂移")
		var player_position: Vector2 = expected_positions.get(WorldSectRoster.PLAYER_SECT_ID, Vector2.ZERO)
		_expect(player_position.x > WorldMapSpec.WORLD_SIZE.x * 0.35 and player_position.x < WorldMapSpec.WORLD_SIZE.x * 0.65, "玩家宗门必须位于地图中央区域")
		_expect(player_position.y > WorldMapSpec.WORLD_SIZE.y * 0.35 and player_position.y < WorldMapSpec.WORLD_SIZE.y * 0.70, "玩家宗门必须位于地图中央区域")
		_assert_quadrant(expected_positions, "sect_002", false, false)
		_assert_quadrant(expected_positions, "sect_003", true, false)
		_assert_quadrant(expected_positions, "sect_004", true, true)
		_assert_quadrant(expected_positions, "sect_005", false, true)
		world.queue_free()
		await process_frame
		await process_frame


func _assert_quadrant(positions: Dictionary, sect_id: String, east: bool, south: bool) -> void:
	var position: Vector2 = positions.get(sect_id, Vector2.ZERO)
	var mid_x := float(WorldMapSpec.WORLD_SIZE.x) * 0.5
	var mid_y := float(WorldMapSpec.WORLD_SIZE.y) * 0.5
	_expect((position.x > mid_x) == east and (position.y > mid_y) == south, sect_id + " 必须位于指定象限")


func _test_save_roster_compatibility() -> void:
	var game_state: Node = root.get_node("GameState")
	var world_data: Node = root.get_node("WorldDataManager")
	var save_manager: Node = root.get_node("SaveManager")
	game_state.call("new_game")
	var snapshot: Dictionary = save_manager.call("create_snapshot")
	var world_state: Dictionary = snapshot.get("world_data", {})
	_expect(int(world_state.get("world_sect_roster_version", 0)) == WorldSectRoster.ROSTER_VERSION, "新存档必须记录五宗门名册版本")
	_expect((world_state.get("sects", []) as Array).size() == 5, "新存档必须保存五个初始宗门")
	_expect(bool(save_manager.call("apply_snapshot", snapshot)), "名册版本2存档必须可以恢复")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["relations"].append({"sect_a_id": "sect_001", "sect_b_id": "sect_999"})), "relations[", "关系孤儿引用")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["diplomatic_pacts"].append({"member_ids": ["sect_001", "sect_999"], "terms": {"attacker": "sect_999"}})), "diplomatic_pacts[", "契约孤儿引用")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["war_campaigns"].append({"attacker_sect_id": "sect_999", "defender_sect_id": "sect_001"})), "war_campaigns[", "战争孤儿引用")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["market_transactions"].append({"trader_sect_id": "sect_999", "market_owner_sect_id": "sect_002"})), "market_transactions[", "交易孤儿引用")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["ai_states"]["sect_999"] = {}), "ai_states.sect_999", "AI 键错误")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["sect_resources"].erase("sect_005")), "sect_resources missing key", "资源键错误")
	_assert_rejected_without_mutation(save_manager, world_data, game_state, _with_world_mutation(snapshot, func(world: Dictionary) -> void: world["mission_instances"].append({"sect_id": "sect_006"})), "早期十宗门", "已退役宗门引用")

	var before_ids: Array[String] = []
	for sect_data in world_data.call("get_all_sects"):
		before_ids.append(str((sect_data as Dictionary).get("sect_id", "")))
	var legacy_snapshot: Dictionary = snapshot.duplicate(true)
	var legacy_world: Dictionary = legacy_snapshot["world_data"]
	legacy_world.erase("world_sect_roster_version")
	var legacy_sects: Array = legacy_world["sects"]
	legacy_sects.append({"sect_id": "sect_006", "is_player": false})
	legacy_world["sects"] = legacy_sects
	legacy_snapshot["world_data"] = legacy_world
	_expect(not bool(save_manager.call("apply_snapshot", legacy_snapshot)), "早期十宗门开发存档必须被拒绝")
	_expect(str(save_manager.get("last_snapshot_error")) == "该存档来自早期十宗门开发版本，无法用于当前五宗门世界。请开始新游戏。", "拒绝早期存档必须给出清晰中文原因")
	var after_ids: Array[String] = []
	for sect_data in world_data.call("get_all_sects"):
		after_ids.append(str((sect_data as Dictionary).get("sect_id", "")))
	_expect(after_ids == before_ids, "拒绝旧存档不得改写当前世界数据")
	var file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.WRITE)
	_expect(file != null, "必须能写入临时旧存档测试文件")
	if file != null:
		file.store_buffer("WZSV".to_ascii_buffer())
		file.store_32(1)
		file.store_var({"header_format": true}, false)
		file.store_var(legacy_snapshot, false)
		file.close()
		var inspection: Dictionary = save_manager.call("inspect_save_path", LEGACY_SAVE_PATH)
		_expect(not bool(inspection.get("valid", true)), "旧存档检查必须拒绝")
		_expect(str(inspection.get("message", "")) == "该存档来自早期十宗门开发版本，无法用于当前五宗门世界。请开始新游戏。", "旧存档检查必须保留清晰原因")
		var loaded: Dictionary = save_manager.call("load_from_path", LEGACY_SAVE_PATH)
		_expect(not bool(loaded.get("success", true)), "旧存档加载必须拒绝")
		_expect(str(loaded.get("message", "")) == "该存档来自早期十宗门开发版本，无法用于当前五宗门世界。请开始新游戏。", "旧存档加载必须保留清晰原因")
		DirAccess.remove_absolute(LEGACY_SAVE_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _with_world_mutation(snapshot: Dictionary, mutation: Callable) -> Dictionary:
	var variant: Dictionary = snapshot.duplicate(true)
	var world: Dictionary = variant["world_data"]
	mutation.call(world)
	variant["world_data"] = world
	return variant


func _assert_rejected_without_mutation(save_manager: Node, world_data: Node, game_state: Node, snapshot: Dictionary, expected_text: String, label: String) -> void:
	var before_world: Dictionary = world_data.call("export_world_state")
	var before_game := {"year": game_state.year, "month": game_state.month, "day": game_state.day, "seed": game_state.world_seed}
	_expect(not bool(save_manager.call("apply_snapshot", snapshot)), label + " 必须拒绝")
	_expect(expected_text in str(save_manager.get("last_snapshot_error")), label + " 必须报告具体路径或旧存档原因")
	_expect(world_data.call("export_world_state") == before_world, label + " 被拒绝后不得污染 WorldDataManager")
	_expect({"year": game_state.year, "month": game_state.month, "day": game_state.day, "seed": game_state.world_seed} == before_game, label + " 被拒绝后不得污染 GameState")
