extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")
const WorldSectReferenceValidator = preload("res://scripts/world/WorldSectReferenceValidator.gd")
const WorldSectBaseline = preload("res://scripts/world/WorldSectBaseline.gd")

var failures := PackedStringArray()

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_expect(str(ProjectSettings.get_setting("application/config/version")) == "1.0.0", "项目版本必须为 1.0.0")
	_expect(ResourceLoader.exists("res://scenes/main/Main.tscn"), "主场景必须存在")
	_expect(ResourceLoader.exists("res://scenes/world/GeneratedWorldMap.tscn"), "地图源场景必须存在")
	_expect(ResourceLoader.exists("res://scenes/world/GeneratedWorldMap.scn"), "运行时地图必须存在")
	var source_map := _load_map("res://scenes/world/GeneratedWorldMap.tscn")
	var runtime_map := _load_map("res://scenes/world/GeneratedWorldMap.scn")
	_expect(source_map != null and runtime_map != null, "两种地图格式都必须可加载")
	if source_map != null and runtime_map != null:
		print("[ReleaseChecklist] terrain source=%d runtime=%d nature source=%d runtime=%d" % [source_map.call("get_terrain_cell_count"), runtime_map.call("get_terrain_cell_count"), source_map.call("get_nature_instance_count"), runtime_map.call("get_nature_instance_count")])
		_expect(bool(source_map.call("is_baked_map_valid")) and bool(runtime_map.call("is_baked_map_valid")), "烘焙地图必须有效")
		_expect(int(source_map.call("get_terrain_cell_count")) == WorldMapSpec.GRID_SIZE.x * WorldMapSpec.GRID_SIZE.y, "地图格数必须为73984")
		_expect(int(source_map.call("get_terrain_cell_count")) == int(runtime_map.call("get_terrain_cell_count")), "tscn/scn 地形统计必须一致")
		_expect(int(source_map.call("get_nature_instance_count")) == int(runtime_map.call("get_nature_instance_count")), "tscn/scn 自然物统计必须一致")
		_expect(not (source_map.get("safe_land_source_ids") as Array).is_empty(), "安全陆地 source 不能为空")
		await _dispose_map(source_map)
		await _dispose_map(runtime_map)
	_expect(_generated_files_are_clean(), "生成目录不得残留 staging、tmp 或 bak")
	var world_data: Node = root.get_node("WorldDataManager")
	# 需要完整初始化领地、库存和市场等持久化容器，不能只初始化基础名册。
	root.get_node("GameState").new_game()
	var roster_errors := WorldSectRoster.validate()
	_expect(roster_errors.is_empty(), "五宗门名册必须有效")
	_expect(world_data.get_all_sects().size() == WorldSectRoster.expected_sect_count(), "必须保留五个初始宗门")
	_expect(world_data.get_ai_sects().size() == WorldSectRoster.expected_ai_sect_count(), "必须保留四个初始AI宗门")
	_expect(_has_expected_initial_roster(world_data.get_all_sects()), "初始宗门ID与顺序必须匹配五宗门名册")
	_expect(WorldSectBaseline.validate_sects(world_data.get_all_sects()).is_empty(), "五宗门元数据基线必须完全一致")
	_expect(WorldSectBaseline.validate_sect_resources(world_data.sect_resources).is_empty(), "五宗门初始资源基线必须完全一致")
	_expect(_has_exact_active_sect_keys(world_data.sect_resources), "宗门资源键必须与五宗门名册完全一致")
	_expect(_has_exact_ai_sect_keys(world_data.ai_states), "AI状态键必须与四个 AI 名册完全一致")
	_expect(WorldSectReferenceValidator.validate_world_state(world_data.export_world_state()).is_empty(), "世界状态不得包含悬空宗门引用")
	_expect(WorldSectReferenceValidator.find_removed_development_sect_references(world_data.export_world_state()).is_empty(), "世界状态不得残留退役宗门引用")
	_expect(world_data.get_all_resources().size() == 26, "必须保留基准的26个资源点")
	_expect(world_data.get_all_build_slots().size() == 6, "必须保留6个建设点")
	_expect(_resource_metadata_is_baseline(world_data.get_all_resources()), "资源元数据不得被紧凑地图改写")
	_expect(FileAccess.file_exists("res://export_presets.cfg"), "导出配置必须存在")
	_expect("Windows Desktop" in FileAccess.get_file_as_string("res://export_presets.cfg"), "必须存在 Windows Desktop 预设")
	_expect("tests/*" in FileAccess.get_file_as_string("res://export_presets.cfg") and "scripts/tools/*" in FileAccess.get_file_as_string("res://export_presets.cfg"), "导出必须排除测试与工具")
	_expect("1.0.0 Release Candidate" in FileAccess.get_file_as_string("res://PROJECT_STATUS.md"), "项目状态必须保持 RC")
	if failures.is_empty(): print("[ReleaseChecklist] PASS"); quit(0)
	else:
		for item in failures: push_error("[ReleaseChecklist][FAIL] " + item)
		print("[ReleaseChecklist] FAILED"); quit(1)
func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)


func _load_map(path: String) -> Node:
	var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return scene.instantiate() if scene != null else null


func _dispose_map(map: Node) -> void:
	root.add_child(map)
	await process_frame
	map.queue_free()
	await process_frame


func _generated_files_are_clean() -> bool:
	var scan: Dictionary = ReleaseFileScanner.scan_generated_directory("res://assets/generated")
	var stale_files: PackedStringArray = scan.get("findings", PackedStringArray())
	var scan_errors: PackedStringArray = scan.get("scan_errors", PackedStringArray())
	for stale_file in stale_files:
		push_error("[ReleaseChecklist] stale generated artifact: " + stale_file)
	for scan_error in scan_errors:
		push_error("[ReleaseChecklist] generated scan error: " + scan_error)
	return stale_files.is_empty() and scan_errors.is_empty()


func _resource_metadata_is_baseline(resources: Array) -> bool:
	var errors := WorldResourceBaseline.validate_resource_metadata(resources)
	for error_message in errors:
		push_error("[ReleaseChecklist] " + error_message)
	return errors.is_empty()


func _has_expected_initial_roster(sects: Array) -> bool:
	if sects.size() != WorldSectRoster.expected_sect_count():
		return false
	for index in range(sects.size()):
		if str((sects[index] as Dictionary).get("sect_id", "")) != WorldSectRoster.ACTIVE_SECT_IDS[index]:
			return false
	return true


func _has_exact_active_sect_keys(values: Dictionary) -> bool:
	return _has_exact_keys(values, WorldSectRoster.ACTIVE_SECT_IDS)


func _has_exact_ai_sect_keys(values: Dictionary) -> bool:
	return _has_exact_keys(values, WorldSectRoster.AI_SECT_IDS)


func _has_exact_keys(values: Dictionary, expected_ids: Array[String]) -> bool:
	if values.size() != expected_ids.size():
		return false
	for sect_id in expected_ids:
		if not values.has(sect_id):
			return false
	return true
