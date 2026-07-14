extends SceneTree

const TEST_ROOT := "user://task_0065_release_scanner"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var nested_staging := TEST_ROOT.path_join("nested/.world_bake_staging/unfinished")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(nested_staging))
	_write(TEST_ROOT.path_join("root.tmp"))
	_write(TEST_ROOT.path_join("nested/old.bak"))
	_write(nested_staging.path_join("partial.tscn"))
	var findings := ReleaseFileScanner.find_stale_generated_files(TEST_ROOT)
	_expect(TEST_ROOT.path_join("root.tmp") in findings, "recursive scanner must find root tmp files")
	_expect(TEST_ROOT.path_join("nested/old.bak") in findings, "recursive scanner must find nested bak files")
	_expect(TEST_ROOT.path_join("nested/.world_bake_staging") in findings, "recursive scanner must reject non-empty nested staging directories")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join(".world_bake_staging")))
	_expect(ReleaseFileScanner.find_stale_generated_files(TEST_ROOT).is_empty(), "empty staging directory must be accepted")
	_write(TEST_ROOT.path_join("ordinary.res"))
	var clean_scan: Dictionary = ReleaseFileScanner.scan_generated_directory(TEST_ROOT)
	_expect((clean_scan.get("findings", PackedStringArray()) as PackedStringArray).is_empty(), "ordinary res files must not be false positives")
	_expect((clean_scan.get("scan_errors", PackedStringArray()) as PackedStringArray).is_empty(), "existing clean root must scan successfully")
	var missing_scan: Dictionary = ReleaseFileScanner.scan_generated_directory(TEST_ROOT.path_join("missing"))
	_expect(not (missing_scan.get("scan_errors", PackedStringArray()) as PackedStringArray).is_empty(), "missing scan root must fail closed")
	_cleanup()
	if failures.is_empty():
		print("[Task0065ReleaseChecklist] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[Task0065ReleaseChecklist] " + failure)
	quit(1)


func _write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("stale")
	file.close()


func _cleanup() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_ROOT)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("root.tmp")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("nested/old.bak")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("nested/.world_bake_staging/unfinished/partial.tscn")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("nested/.world_bake_staging/unfinished")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("nested/.world_bake_staging")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("nested")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join(".world_bake_staging")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT.path_join("ordinary.res")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
