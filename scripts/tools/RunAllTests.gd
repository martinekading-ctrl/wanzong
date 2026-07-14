extends SceneTree

const TEST_DIRECTORY := "res://tests"
const WORLD_ONLY_TEST := "task_0062_release_qa_test.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var include_slow: bool = "--include-slow" in OS.get_cmdline_user_args()
	var plan := _build_test_plan(include_slow)
	if plan.is_empty():
		push_error("[RunAllTests] FAILED: no test files found")
		quit(1)
		return
	var failures: int = 0
	for item in plan:
		var test_file: String = str(item["test_file"])
		_cleanup_test_state()
		var output: Array[String] = []
		var arguments: PackedStringArray = item["arguments"]
		var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
		print("[RunAllTests] %s exit=%d" % [test_file, exit_code])
		for line in output:
			print(line)
		if exit_code != 0:
			failures += 1
	_cleanup_test_state()
	if failures == 0:
		print("[RunAllTests] PASS (%d tests)" % plan.size())
		quit(0)
		return
	push_error("[RunAllTests] FAILED: %d test(s)" % failures)
	quit(1)


func _get_test_files() -> PackedStringArray:
	var directory := DirAccess.open(TEST_DIRECTORY)
	var files := PackedStringArray()
	if directory == null:
		return files
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if not directory.current_is_dir() and name.begins_with("task_") and name.ends_with("_test.gd"):
			files.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	files.sort()
	return files


func _build_test_plan(include_slow: bool) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for test_file in _get_test_files():
		plan.append({
			"test_file": test_file,
			"arguments": _build_test_arguments(test_file, include_slow),
		})
	return plan


func _build_test_arguments(test_file: String, include_slow: bool) -> PackedStringArray:
	var arguments := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", ProjectSettings.globalize_path(TEST_DIRECTORY.path_join(test_file))])
	if test_file == WORLD_ONLY_TEST and not include_slow:
		arguments.append("--")
		arguments.append("--world-only")
	return arguments


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
