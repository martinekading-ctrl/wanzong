extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data: Node
var _audio: Node
var _feedback: Node
var _save: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data = root.get_node("WorldDataManager")
	_audio = root.get_node("AudioManager")
	_feedback = root.get_node("FeedbackManager")
	_save = root.get_node("SaveManager")
	_test_audio_pipeline_and_settings()
	await _test_global_button_feedback()
	await _test_main_menu_art_and_settings()
	await _test_world_selection_audio()
	_audio.shutdown_audio()
	await process_frame
	if _failures.is_empty():
		print("[Task0061Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0061Test] " + failure)
	quit(1)


func _test_audio_pipeline_and_settings() -> void:
	_game_state.new_game()
	_expect(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("Effects") >= 0, "音频管理器应创建独立音乐与效果音总线。")
	_expect(_audio.play_ui("confirm") and str(_audio.last_sfx_id) == "confirm", "确认提示音应可由内存音源播放。")
	_expect(not _audio.play_ui("unknown"), "未知提示音应安全返回失败。")
	_expect(_audio.play_music("missing_track") and str(_audio.current_music_id) == "missing_track", "缺失背景音乐时应使用程序化环境乐安全降级。")
	_expect(_audio.set_volume("effects", 0.35), "效果音音量应可修改。")
	_expect(is_equal_approx(float(SettingsManager.get_volume("effects")), 0.35), "音量设置必须写入独立的全局用户设置。")
	var snapshot: Dictionary = _save.create_snapshot()
	_audio.set_volume("effects", 0.1)
	_expect(_save.apply_snapshot(snapshot), "音量设置应可随完整存档恢复。")
	_expect(is_equal_approx(_audio.get_volume("effects"), 0.1), "读档不得覆盖当前全局效果音音量。")


func _test_global_button_feedback() -> void:
	var button := Button.new()
	button.text = "反馈测试"
	root.add_child(button)
	await process_frame
	_audio.last_sfx_id = ""
	button.emit_signal("pressed")
	_expect(str(_audio.last_sfx_id) == "click", "动态创建的按钮也应自动获得点击音。")
	_expect(button.self_modulate != Color.WHITE, "按钮点击后应立即产生短促颜色反馈。")
	button.queue_free()
	await process_frame


func _test_main_menu_art_and_settings() -> void:
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var icon: TextureRect = menu.get_node("CenterContainer/MenuBox/SectIcon")
	var settings_button: Button = menu.get_node("CenterContainer/MenuBox/SettingsButton")
	var settings_panel: PanelContainer = menu.get_node("SettingsPanel")
	var effects_slider: HSlider = menu.get_node("SettingsPanel/SettingsBox/EffectsSlider")
	_expect(icon.texture != null and icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "主菜单应复用青玄宗正式像素图标并保持最近邻过滤。")
	settings_button.emit_signal("pressed")
	_expect(settings_panel.visible, "主菜单应能打开声音设置。")
	effects_slider.value = 42.0
	_expect(is_equal_approx(_audio.get_volume("effects"), 0.42), "声音设置滑块应实时更新效果音音量。")
	menu.queue_free()
	await process_frame


func _test_world_selection_audio() -> void:
	var sect_node := SectNode.new()
	root.add_child(sect_node)
	sect_node.setup({"sect_id": "sect_test", "sect_name": "测试宗门", "is_player": false, "position": Vector2.ZERO})
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_audio.last_sfx_id = ""
	sect_node.call("_input_event", root.get_viewport(), click, 0)
	_expect(str(_audio.last_sfx_id) == "select", "世界地图对象点击应播放选择提示音。")
	sect_node.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
