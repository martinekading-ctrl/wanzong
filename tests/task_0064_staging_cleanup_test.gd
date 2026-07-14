extends SceneTree
const TX := preload("res://scripts/tools/WorldMapBakeTransaction.gd")
var failures := PackedStringArray()
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var stage := TX.STAGING_ROOT.path_join("task_0064_cleanup")
	var nested := stage.path_join("a/b")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(nested))
	var file := FileAccess.open(nested.path_join("data.bin"), FileAccess.WRITE); file.store_string("x"); file.close()
	_expect(TX.remove_staging_directory_recursive(stage) == OK and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(stage)), "staging 目录必须递归删除")
	var protected := "res://assets/generated/task_0064_keep.txt"
	var keep := FileAccess.open(protected, FileAccess.WRITE); keep.store_string("keep"); keep.close()
	for path in ["", TX.STAGING_ROOT, "res://assets/generated", protected, "user://bad", TX.STAGING_ROOT.path_join("../bad")]:
		_expect(TX.remove_staging_directory_recursive(path) != OK, "非法 staging 路径必须拒绝")
	_expect(FileAccess.file_exists(protected), "拒绝非法路径不得删除目标文件")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(protected))
	if failures.is_empty(): print("[Task0064StagingCleanup] PASS"); quit(0)
	else:
		for item in failures: push_error("[Task0064StagingCleanup] " + item)
		quit(1)
func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
