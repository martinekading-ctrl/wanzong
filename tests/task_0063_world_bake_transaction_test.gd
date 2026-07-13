extends SceneTree

const TRANSACTION := preload("res://scripts/tools/WorldMapBakeTransaction.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var target := "user://task_0063_bake_target.bin"
	var staged_a := "user://task_0063_bake_stage_a.bin"
	var staged_b := "user://task_0063_bake_stage_b.bin"
	_write(target, "official-map")
	_write(staged_a, "new-map")
	_write(staged_b, "new-runtime")
	var original_hash := FileAccess.get_md5(target)
	var result: Error = TRANSACTION.commit_files({staged_a: target, staged_b: "user://task_0063_bake_runtime.bin"}, 1)
	_expect(result != OK, "注入失败点必须使烘焙提交失败。")
	_expect(FileAccess.get_md5(target) == original_hash, "提交失败不得改变正式地图文件。")
	_expect(not FileAccess.file_exists("user://task_0063_bake_runtime.bin"), "提交失败不得遗留新的正式运行时地图。")
	_expect(TRANSACTION.commit_files({staged_a: target, staged_b: "user://task_0063_bake_runtime.bin"}) == OK, "完整临时资源应可一次提交。")
	_expect(FileAccess.get_file_as_string(target) == "new-map", "成功提交应替换正式地图文件。")
	for path in [target, staged_a, staged_b, "user://task_0063_bake_runtime.bin"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("[Task0063WorldBakeTransaction] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0063WorldBakeTransaction] " + failure)
	quit(1)


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
