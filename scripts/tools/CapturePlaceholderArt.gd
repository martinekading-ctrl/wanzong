extends SceneTree

var output_directory := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_directory = argument.trim_prefix("--output-dir=")
	if output_directory.is_empty():
		push_error("CapturePlaceholderArt requires --output-dir=<absolute path>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_directory)
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").call("new_game")
	await _capture_scene("main_menu", "res://scenes/ui/MainMenu.tscn", Vector2i(1920, 1080))
	await _capture_scene("settings", "res://scenes/ui/MainMenu.tscn", Vector2i(1920, 1080), "_on_settings_button_pressed")
	await _capture_world("world_full_1920", Vector2i(1920, 1080), true)
	await _capture_world("world_near_1920", Vector2i(1920, 1080), false)
	await _capture_world("world_full_1280", Vector2i(1280, 720), true)
	await _capture_world("world_full_2560", Vector2i(2560, 1440), true)
	await _capture_scene("qingxuan_sect", "res://scenes/sect/PlayerSectOverview.tscn", Vector2i(1920, 1080))
	await _capture_scene("disciple", "res://scenes/sect/PlayerSectOverview.tscn", Vector2i(1920, 1080), "_on_disciple_button_pressed")
	await _capture_scene("building", "res://scenes/sect/PlayerSectOverview.tscn", Vector2i(1920, 1080), "_on_building_button_pressed")
	await _capture_scene("diplomacy", "res://scenes/sect/PlayerSectOverview.tscn", Vector2i(1920, 1080), "_on_diplomacy_button_pressed")
	await _capture_scene("save_load", "res://scenes/sect/PlayerSectOverview.tscn", Vector2i(1920, 1080), "_on_save_load_button_pressed")
	await _capture_scene("battle", "res://scenes/battle/BattleReport.tscn", Vector2i(1920, 1080))
	await _capture_scene("placeholder_art_gallery", "res://scenes/tools/PlaceholderArtGallery.tscn", Vector2i(1920, 1080))
	await _capture_scene("character_gallery", "res://scenes/tools/CharacterGallery.tscn", Vector2i(1920, 1080))
	await _capture_scene("world_visual_preview", "res://scenes/tools/WorldVisualPreview.tscn", Vector2i(1920, 1080))
	print("[CapturePlaceholderArt] PASS output=" + output_directory)
	quit(0)


func _capture_scene(label: String, scene_path: String, resolution: Vector2i, action := "") -> void:
	root.size = resolution
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Capture scene missing: " + scene_path)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	_fit_control(instance)
	await _settle()
	if not action.is_empty() and instance.has_method(action):
		instance.call(action)
		await _settle()
	await _save(label)
	instance.queue_free()
	await process_frame


func _capture_world(label: String, resolution: Vector2i, full_map: bool) -> void:
	root.size = resolution
	var world := (load("res://scenes/world/World.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _settle(12)
	var camera := world.get_node("WorldCamera") as Camera2D
	if full_map:
		camera.call("show_full_map")
	else:
		var world_data: Node = root.get_node("WorldDataManager")
		camera.call("focus_on", (world_data.call("get_player_sect") as Dictionary).get("location", Vector2(2176, 2176)))
		for _index in range(5):
			camera.call("zoom_by", 1.0)
	await _settle()
	await _save(label)
	world.queue_free()
	await process_frame


func _fit_control(instance: Node) -> void:
	var control := instance as Control
	if control == null:
		return
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _settle(frame_count := 6) -> void:
	for _index in range(frame_count):
		await process_frame


func _save(label: String) -> void:
	var image := root.get_texture().get_image()
	var path := output_directory.path_join(label + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Screenshot save failed: " + path)
