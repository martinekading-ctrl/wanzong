extends SceneTree

const SOURCE_PATH := "res://scenes/world/GeneratedWorldMap.tscn"
const RUNTIME_PATH := "res://scenes/world/GeneratedWorldMap.scn"


func _initialize() -> void:
	var started_at: int = Time.get_ticks_msec()
	var scene := load(SOURCE_PATH) as PackedScene
	if scene == null:
		push_error("无法读取烘焙地图源场景：" + SOURCE_PATH)
		quit(1)
		return
	var error: Error = ResourceSaver.save(scene, RUNTIME_PATH, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("生成运行时地图失败：" + error_string(error))
		quit(1)
		return
	print("[WorldPerf] Runtime map compiled: %d ms" % (Time.get_ticks_msec() - started_at))
	quit(0)
