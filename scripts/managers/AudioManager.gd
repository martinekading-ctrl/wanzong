extends Node

const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"
const SAMPLE_RATE: int = 22050

var last_sfx_id: String = ""
var current_music_id: String = ""
var _music_player: AudioStreamPlayer
var _effects_player: AudioStreamPlayer
var _tone_cache: Dictionary = {}
var _created_buses: Array[String] = []


func _ready() -> void:
	if _ensure_bus(MUSIC_BUS):
		_created_buses.append(MUSIC_BUS)
	if _ensure_bus(EFFECTS_BUS):
		_created_buses.append(EFFECTS_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	_effects_player = AudioStreamPlayer.new()
	_effects_player.name = "EffectsPlayer"
	_effects_player.bus = EFFECTS_BUS
	add_child(_effects_player)
	call_deferred("_connect_game_signals")
	apply_settings()


func _exit_tree() -> void:
	shutdown_audio()
	for bus_name in _created_buses:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.remove_bus(index)
	_created_buses.clear()


func apply_settings() -> void:
	var settings: Dictionary = WorldDataManager.game_settings
	_set_bus_linear("Master", float(settings.get("master_volume", 1.0)))
	_set_bus_linear(MUSIC_BUS, float(settings.get("music_volume", 1.0)))
	_set_bus_linear(EFFECTS_BUS, float(settings.get("effects_volume", 1.0)))


func set_volume(channel: String, value: float) -> bool:
	var clamped: float = clampf(value, 0.0, 1.0)
	match channel:
		"master":
			WorldDataManager.game_settings["master_volume"] = clamped
			_set_bus_linear("Master", clamped)
		"music":
			WorldDataManager.game_settings["music_volume"] = clamped
			_set_bus_linear(MUSIC_BUS, clamped)
		"effects":
			WorldDataManager.game_settings["effects_volume"] = clamped
			_set_bus_linear(EFFECTS_BUS, clamped)
		_:
			return false
	return true


func get_volume(channel: String) -> float:
	return float(WorldDataManager.game_settings.get(channel + "_volume", 1.0))


func play_ui(sfx_id: String) -> bool:
	if _effects_player == null:
		return false
	var tone: Array = {
		"click": [520.0, 0.045],
		"select": [660.0, 0.07],
		"confirm": [820.0, 0.11],
		"error": [190.0, 0.14],
		"battle": [120.0, 0.20],
	}.get(sfx_id, [])
	if tone.is_empty():
		return false
	last_sfx_id = sfx_id
	if not _tone_cache.has(sfx_id):
		_tone_cache[sfx_id] = _create_tone(float(tone[0]), float(tone[1]))
	# 无头测试使用 Dummy 音频后端，启动播放会在进程立即退出时留下虚假的 playback 泄漏。
	if DisplayServer.get_name() == "headless":
		return true
	_effects_player.stream = _tone_cache[sfx_id]
	_effects_player.play()
	return true


func play_music(music_id: String) -> bool:
	if _music_player == null or music_id == "":
		return false
	for extension in ["ogg", "wav", "mp3"]:
		var path: String = "res://assets/audio/bgm/%s.%s" % [music_id, extension]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream == null:
				continue
			current_music_id = music_id
			_music_player.stream = stream
			_music_player.play()
			return true
	return false


func stop_music() -> void:
	current_music_id = ""
	if _music_player != null:
		_music_player.stop()


func shutdown_audio() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	if _effects_player != null:
		_effects_player.stop()
		_effects_player.stream = null
	_tone_cache.clear()


func _connect_game_signals() -> void:
	BattleManager.battle_completed.connect(func(_result: Dictionary) -> void: play_ui("battle"))
	EventManager.event_resolved.connect(func(result: Dictionary) -> void: play_ui("confirm" if bool(result.get("success", false)) else "error"))


func _ensure_bus(bus_name: String) -> bool:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return false
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	return true


func _set_bus_linear(bus_name: String, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func _create_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(SAMPLE_RATE * duration))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var progress: float = float(index) / float(sample_count)
		var envelope: float = pow(1.0 - progress, 2.0)
		var sample: int = int(sin(TAU * frequency * float(index) / SAMPLE_RATE) * envelope * 5000.0)
		bytes.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
