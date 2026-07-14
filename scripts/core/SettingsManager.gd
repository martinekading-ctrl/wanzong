extends Node

## 与世界存档分离的用户偏好。这里只保存已经实际提供的音量选项。
const SETTINGS_PATH := "user://settings.cfg"
const CURRENT_SETTINGS_VERSION := 1
const META_SECTION := "meta"
const SECTION := "audio"
const DEFAULT_AUDIO_SETTINGS := {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"effects_volume": 1.0,
}

var _settings: Dictionary = DEFAULT_AUDIO_SETTINGS.duplicate(true)
var _storage_path: String = SETTINGS_PATH


func _ready() -> void:
	load_settings()


func get_volume(channel: String) -> float:
	return float(_settings.get(channel + "_volume", 1.0))


func set_volume(channel: String, value: float) -> bool:
	var key := channel + "_volume"
	if not DEFAULT_AUDIO_SETTINGS.has(key):
		return false
	var previous: Variant = _settings[key]
	_settings[key] = clampf(value, 0.0, 1.0)
	if save_settings():
		return true
	_settings[key] = previous
	return false


func load_settings() -> bool:
	_settings = DEFAULT_AUDIO_SETTINGS.duplicate(true)
	if not FileAccess.file_exists(_storage_path):
		return true
	var config := ConfigFile.new()
	if config.load(_storage_path) != OK:
		push_warning("全局设置文件无效，已安全回退到默认音量。")
		return false
	var version: int = int(config.get_value(META_SECTION, "version", 0))
	if version > CURRENT_SETTINGS_VERSION:
		push_warning("全局设置版本高于当前客户端，已使用默认音量。")
		return false
	for key in DEFAULT_AUDIO_SETTINGS:
		var raw_value: Variant = config.get_value(SECTION, key, DEFAULT_AUDIO_SETTINGS[key])
		if raw_value is float or raw_value is int:
			_settings[key] = clampf(float(raw_value), 0.0, 1.0)
		else:
			push_warning("全局设置中的音量值无效，已使用默认值：" + str(key))
	return true


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(META_SECTION, "version", CURRENT_SETTINGS_VERSION)
	for key in DEFAULT_AUDIO_SETTINGS:
		config.set_value(SECTION, key, float(_settings[key]))
	var error := config.save(_storage_path)
	if error != OK:
		push_warning("无法保存全局音量设置：" + error_string(error))
		return false
	return true


func reset_to_defaults() -> void:
	_settings = DEFAULT_AUDIO_SETTINGS.duplicate(true)


## 仅供独立回归测试隔离 user:// 配置，不供游戏逻辑调用。
func set_storage_path_for_tests(path: String) -> void:
	_storage_path = path
	reset_to_defaults()
