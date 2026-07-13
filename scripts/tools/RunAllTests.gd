extends SceneTree

const TEST_DIRECTORY := "res://tests"
const SLOW_TESTS: Array[String] = ["task_0062_release_qa_test.gd"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var include_slow: bool = "--include-slow" in OS.get_cmdline_user_args()
	var test_files := _get_test_files(include_slow)
	var failures: int = 0
	for test_file in test_files:
		_cleanup_test_state()
		var output: Array[String] = []
		var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", ProjectSettings.globalize_path(TEST_DIRECTORY.path_join(test_file))])
		if test_file == "task_0062_release_qa_test.gd" and not include_slow:
			arguments.append("--world-only")
		var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
		print("[RunAllTests] %s exit=%d" % [test_file, exit_code])
		for line in output:
			print(line)
		if exit_code != 0:
			failures += 1
	_cleanup_test_state()
	if failures == 0:
		print("[RunAllTests] PASS (%d tests)" % test_files.size())
		quit(0)
		return
	push_error("[RunAllTests] FAILED: %d test(s)" % failures)
	quit(1)


func _get_test_files(include_slow: bool) -> PackedStringArray:
	var directory := DirAccess.open(TEST_DIRECTORY)
	var files := PackedStringArray()
	if directory == null:
		return files
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if not directory.current_is_dir() and name.begins_with("task_") and name.ends_with("_test.gd"):
			if include_slow or name not in SLOW_TESTS:
				files.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	files.sort()
	return files


func _cleanup_test_state() -> void:
	_remove_contents("user://saves")
	for path in [
		"user://task_0063_settings.cfg",
		"user://task_0063_bake_target.bin",
		"user://task_0063_bake_stage_a.bin",
		"user://task_0063_bake_stage_b.bin",
		"user://task_0063_bake_runtime.bin",
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_contents(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if not directory.current_is_dir():
			directory.remove(name)
		name = directory.get_next()
	directory.list_dir_end()
