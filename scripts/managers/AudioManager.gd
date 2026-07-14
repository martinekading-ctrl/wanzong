extends Node

const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"
const SAMPLE_RATE: int = 22050

var last_sfx_id: String = ""
var current_music_id: String = ""
var _music_player: AudioStreamPlayer
var _effects_player: AudioStreamPlayer
var _tone_cache: Dictionary = {}
var _music_cache: Dictionary = {}
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
	_set_bus_linear("Master", SettingsManager.get_volume("master"))
	_set_bus_linear(MUSIC_BUS, SettingsManager.get_volume("music"))
	_set_bus_linear(EFFECTS_BUS, SettingsManager.get_volume("effects"))


func set_volume(channel: String, value: float) -> bool:
	var clamped: float = clampf(value, 0.0, 1.0)
	match channel:
		"master":
			if not SettingsManager.set_volume("master", clamped): return false
			_set_bus_linear("Master", clamped)
		"music":
			if not SettingsManager.set_volume("music", clamped): return false
			_set_bus_linear(MUSIC_BUS, clamped)
		"effects":
			if not SettingsManager.set_volume("effects", clamped): return false
			_set_bus_linear(EFFECTS_BUS, clamped)
		_:
			return false
	return true


func get_volume(channel: String) -> float:
	return SettingsManager.get_volume(channel)


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
	if current_music_id == music_id and _music_player.playing:
		return true
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
	current_music_id = music_id
	if not _music_cache.has(music_id):
		var base_frequency: float = float({
			"main_menu": 110.0,
			"world": 98.0,
			"sect": 123.75,
			"battle_theme": 82.5,
		}.get(music_id, 110.0))
		_music_cache[music_id] = _create_ambient_loop(base_frequency)
	if DisplayServer.get_name() == "headless":
		return true
	_music_player.stream = _music_cache[music_id]
	_music_player.play()
	return true


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
	_music_cache.clear()


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


func _create_ambient_loop(base_frequency: float) -> AudioStreamWAV:
	const DURATION_SECONDS: float = 8.0
	var sample_count: int = int(SAMPLE_RATE * DURATION_SECONDS)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var time: float = float(index) / SAMPLE_RATE
		var slow_wave: float = 0.65 + 0.35 * sin(TAU * time / DURATION_SECONDS)
		var sample_value: float = (
			sin(TAU * base_frequency * time) * 0.55
			+ sin(TAU * base_frequency * 1.5 * time) * 0.3
			+ sin(TAU * base_frequency * 2.0 * time) * 0.15
		) * slow_wave
		bytes.encode_s16(index * 2, int(sample_value * 700.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = bytes
	return stream
