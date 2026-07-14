extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")
const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const STATUS_PATH := "res://PROJECT_STATUS.md"
const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const BASELINE_DOCUMENT_PATH := "res://docs/development/Task-0067_PreAlpha垂直切片基线.md"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_current_version_metadata()
	_test_status_and_vertical_slice_document()
	await _test_main_menu_version_label()
	_test_data_version_guards()
	if _failures.is_empty():
		print("[Task0067PreAlphaBaseline] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0067PreAlphaBaseline] " + failure)
	quit(1)


func _test_current_version_metadata() -> void:
	_expect(str(ProjectSettings.get_setting("application/config/version", "")) == "0.5.0", "application/config/version 必须为 0.5.0")
	_expect(str(ProjectSettings.get_setting("wanzong/build/stage", "")) == "Pre-Alpha", "wanzong/build/stage 必须为 Pre-Alpha")
	_expect(str(ProjectSettings.get_setting("wanzong/build/channel", "")) == "development", "wanzong/build/channel 必须为 development")
	var export_presets := FileAccess.get_file_as_string(EXPORT_PRESETS_PATH)
	_expect("application/file_version=\"0.5.0.0\"" in export_presets, "Windows file_version 必须为 0.5.0.0")
	_expect("application/product_version=\"0.5.0.0\"" in export_presets, "Windows product_version 必须为 0.5.0.0")


func _test_status_and_vertical_slice_document() -> void:
	var project_status := FileAccess.get_file_as_string(STATUS_PATH)
	_expect("0.5.0 Pre-Alpha" in project_status, "PROJECT_STATUS 必须包含 0.5.0 Pre-Alpha")
	_expect(not "1.0.0 Release Candidate" in project_status, "PROJECT_STATUS 不得仍包含当前 RC 声明")
	_expect(FileAccess.file_exists(BASELINE_DOCUMENT_PATH), "Task-0067 垂直切片基线文档必须存在")
	var baseline_document := FileAccess.get_file_as_string(BASELINE_DOCUMENT_PATH)
	_expect("启动游戏 → 主菜单 → 新游戏" in baseline_document and "继续游戏" in baseline_document, "垂直切片文档必须包含完整流程")
	_expect("UI 开发原则" in baseline_document and "场景开发原则" in baseline_document and "美术方向" in baseline_document, "垂直切片文档必须包含 UI、场景与美术章节")


func _test_main_menu_version_label() -> void:
	var scene := ResourceLoader.load(MAIN_MENU_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_expect(scene != null, "MainMenu.tscn 必须可以加载")
	if scene == null:
		return
	var main_menu := scene.instantiate() as Control
	_expect(main_menu != null, "MainMenu 根节点必须可以实例化")
	if main_menu == null:
		return
	_expect(main_menu.has_node("VersionLabel"), "MainMenu 根节点必须包含 VersionLabel")
	_expect(main_menu.has_node("CenterContainer/MenuBox/StartButton"), "开始游戏按钮必须保留")
	_expect(main_menu.has_node("CenterContainer/MenuBox/ContinueButton"), "继续游戏按钮必须保留")
	_expect(main_menu.has_node("CenterContainer/MenuBox/SettingsButton"), "设置按钮必须保留")
	_expect(main_menu.has_node("CenterContainer/MenuBox/QuitButton"), "退出按钮必须保留")
	root.add_child(main_menu)
	await process_frame
	var version_label := main_menu.get_node_or_null("VersionLabel") as Label
	_expect(version_label != null, "VersionLabel 必须为 Label")
	if version_label != null:
		_expect("v0.5.0" in version_label.text, "VersionLabel 必须显示 v0.5.0")
		_expect("Pre-Alpha" in version_label.text, "VersionLabel 必须显示 Pre-Alpha")
		_expect(not "1.0.0" in version_label.text, "VersionLabel 不得显示 1.0.0")
		_expect(not "Release Candidate" in version_label.text, "VersionLabel 不得显示 Release Candidate")
	main_menu.queue_free()
	await process_frame


func _test_data_version_guards() -> void:
	var save_manager := root.get_node_or_null("SaveManager")
	_expect(save_manager != null, "SaveManager 自动加载必须存在")
	if save_manager != null:
		var save_constants: Dictionary = save_manager.get_script().get_script_constant_map()
		_expect(int(save_constants.get("CURRENT_SAVE_VERSION", -1)) == 1, "SaveManager.CURRENT_SAVE_VERSION 必须保持 1")
		_expect(int(save_constants.get("MINIMUM_SAVE_VERSION", -1)) == 0, "SaveManager.MINIMUM_SAVE_VERSION 必须保持 0")
	_expect(WorldSectRoster.ROSTER_VERSION == 2, "WorldSectRoster.ROSTER_VERSION 必须保持 2")
	_expect(WorldSectRoster.expected_sect_count() == 5, "正式初始宗门数量必须保持 5")
	_expect(WorldSectRoster.expected_ai_sect_count() == 4, "AI 宗门数量必须保持 4")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
