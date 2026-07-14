extends SceneTree

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
		source_map.free()
		runtime_map.free()
	_expect(_generated_files_are_clean(), "生成目录不得残留 staging、tmp 或 bak")
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


func _generated_files_are_clean() -> bool:
	var directory := DirAccess.open("res://assets/generated")
	if directory == null:
		return false
	for file_name in directory.get_files():
		if file_name.ends_with(".tmp") or file_name.ends_with(".bak"):
			return false
	var staging := DirAccess.open("res://assets/generated/.world_bake_staging")
	return staging == null or staging.get_directories().is_empty()
