extends Control

# 开始游戏按钮。
@onready var start_button: Button = $CenterContainer/MenuBox/StartButton
@onready var version_label: Label = $VersionLabel
@onready var continue_button: Button = $CenterContainer/MenuBox/ContinueButton
@onready var continue_hint_label: Label = $CenterContainer/MenuBox/ContinueHintLabel
@onready var settings_button: Button = $CenterContainer/MenuBox/SettingsButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/SettingsBox/MasterSlider
@onready var music_slider: HSlider = $SettingsPanel/SettingsBox/MusicSlider
@onready var effects_slider: HSlider = $SettingsPanel/SettingsBox/EffectsSlider
@onready var close_settings_button: Button = $SettingsPanel/SettingsBox/CloseButton

# 退出游戏按钮。
@onready var quit_button: Button = $CenterContainer/MenuBox/QuitButton


# 场景准备好后，绑定按钮点击事件。
func _ready() -> void:
	_refresh_build_info()
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	close_settings_button.pressed.connect(_on_close_settings_pressed)
	master_slider.value_changed.connect(_on_volume_changed.bind("master"))
	music_slider.value_changed.connect(_on_volume_changed.bind("music"))
	effects_slider.value_changed.connect(_on_volume_changed.bind("effects"))
	quit_button.pressed.connect(_on_quit_button_pressed)
	_refresh_audio_settings()
	_refresh_continue_state()


func _refresh_build_info() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var stage := str(ProjectSettings.get_setting("wanzong/build/stage", "Development"))
	version_label.text = "v%s · %s\n开发中版本：UI、场景与美术尚未完成" % [version, stage]


# 点击“开始游戏”后，进入俯视大地图。
func _on_start_button_pressed() -> void:
	GameState.new_game()
	SceneManager.go_to_world_map()


func _on_continue_button_pressed() -> void:
	var result: Dictionary = SaveManager.load_latest_save()
	if not bool(result.get("success", false)):
		continue_hint_label.text = str(result.get("message", "读档失败"))
		_refresh_continue_state()
		return
	SceneManager.go_to_world_map()


func _refresh_continue_state() -> void:
	var latest_info: Dictionary = SaveManager.get_latest_valid_save_info()
	var latest_path: String = str(latest_info.get("path", ""))
	continue_button.disabled = latest_path == ""
	if latest_path == "":
		continue_hint_label.text = "暂无可读取的有效存档"
		return
	var metadata: Dictionary = SaveManager.get_save_metadata(latest_path)
	var game_state_data: Dictionary = metadata.get("game_state", {})
	var skipped_count: int = (latest_info.get("skipped_invalid_paths", []) as Array).size()
	continue_hint_label.text = ("已跳过%d份损坏存档，" % skipped_count if skipped_count > 0 else "") + "最近进度：第%d年%d月%d日" % [
		int(game_state_data.get("year", 1)),
		int(game_state_data.get("month", 1)),
		int(game_state_data.get("day", 1)),
	]


func _on_settings_button_pressed() -> void:
	_refresh_audio_settings()
	settings_panel.visible = true


func _on_close_settings_pressed() -> void:
	settings_panel.visible = false


func _refresh_audio_settings() -> void:
	master_slider.set_value_no_signal(AudioManager.get_volume("master") * 100.0)
	music_slider.set_value_no_signal(AudioManager.get_volume("music") * 100.0)
	effects_slider.set_value_no_signal(AudioManager.get_volume("effects") * 100.0)


func _on_volume_changed(value: float, channel: String) -> void:
	AudioManager.set_volume(channel, value / 100.0)


# 点击“退出游戏”后，关闭游戏。
func _on_quit_button_pressed() -> void:
	SceneManager.quit_game()
