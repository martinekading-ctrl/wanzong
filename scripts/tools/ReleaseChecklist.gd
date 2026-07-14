extends SceneTree

var failures := PackedStringArray()

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	_expect(str(ProjectSettings.get_setting("application/config/version")) == "1.0.0", "项目版本必须为 1.0.0")
	_expect(ResourceLoader.exists("res://scenes/main/Main.tscn"), "主场景必须存在")
	_expect(ResourceLoader.exists("res://scenes/world/GeneratedWorldMap.scn"), "运行时地图必须存在")
	var scene := ResourceLoader.load("res://scenes/world/GeneratedWorldMap.scn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var map := scene.instantiate() if scene != null else null
	_expect(map != null and map.has_method("is_baked_map_valid") and bool(map.call("is_baked_map_valid")), "烘焙地图必须有效")
	if map != null:
		_expect(not (map.get("safe_land_source_ids") as Array).is_empty(), "安全陆地 source 不能为空")
		map.free()
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
