extends SceneTree

const TEST_SETTINGS_PATH := "user://task_0063_settings.cfg"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings: Node = root.get_node("SettingsManager")
	var audio: Node = root.get_node("AudioManager")
	var game_state: Node = root.get_node("GameState")
	settings.set_storage_path_for_tests(TEST_SETTINGS_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	settings.load_settings()
	_expect(audio.call("set_volume", "master", 0.6), "主音量应可保存。")
	_expect(audio.call("set_volume", "music", 0.25), "音乐音量应可保存。")
	_expect(audio.call("set_volume", "effects", 0.4), "效果音音量应可保存。")
	game_state.call("new_game")
	_expect(is_equal_approx(float(audio.call("get_volume", "master")), 0.6), "新游戏不得重置主音量。")
	_expect(is_equal_approx(float(audio.call("get_volume", "music")), 0.25), "新游戏不得重置音乐音量。")
	_expect(is_equal_approx(float(audio.call("get_volume", "effects")), 0.4), "新游戏不得重置效果音音量。")
	settings.reset_to_defaults()
	settings.load_settings()
	_expect(is_equal_approx(settings.get_volume("master"), 0.6), "重新读取设置后主音量应保留。")
	_expect(is_equal_approx(settings.get_volume("music"), 0.25), "重新读取设置后音乐音量应保留。")
	_expect(is_equal_approx(settings.get_volume("effects"), 0.4), "重新读取设置后效果音音量应保留。")
	var corrupt := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
	corrupt.store_string("not a valid config")
	corrupt.close()
	settings.load_settings()
	_expect(is_equal_approx(settings.get_volume("master"), 1.0), "损坏设置应安全回退为默认主音量。")
	_expect(is_equal_approx(settings.get_volume("music"), 1.0), "损坏设置应安全回退为默认音乐音量。")
	_expect(is_equal_approx(settings.get_volume("effects"), 1.0), "损坏设置应安全回退为默认效果音音量。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	settings.set_storage_path_for_tests("user://settings.cfg")
	settings.load_settings()
	audio.call("apply_settings")
	if _failures.is_empty():
		print("[Task0063Settings] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0063Settings] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
