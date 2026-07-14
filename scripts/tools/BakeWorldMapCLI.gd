extends SceneTree

const WorldMapBakerScript := preload("res://scripts/tools/WorldMapBaker.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var baker := WorldMapBakerScript.new()
	root.add_child(baker)
	var result: Error = await baker.bake_world()
	baker.queue_free()
	await process_frame
	if result == OK:
		print("[BakeWorldMapCLI] PASS")
		quit(0)
		return
	push_error("[BakeWorldMapCLI] FAILED: %s" % error_string(result))
	quit(1)
