extends SceneTree

const RUNNER := preload("res://scripts/tools/RunAllTests.gd")

var _failures := PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner := RUNNER.new()
	var fast: Array[Dictionary] = runner._build_test_plan(false)
	var slow: Array[Dictionary] = runner._build_test_plan(true)
	_expect(fast.size() > 0, "测试计划不能为空。")
	_expect(fast.filter(func(item): return item["test_file"] == runner.WORLD_ONLY_TEST).size() == 1, "快速计划必须且只能包含一次世界测试。")
	var fast_args: PackedStringArray = runner._build_test_arguments(runner.WORLD_ONLY_TEST, false)
	var slow_args: PackedStringArray = runner._build_test_arguments(runner.WORLD_ONLY_TEST, true)
	_expect("--" in fast_args and "--world-only" in fast_args and fast_args.find("--") < fast_args.find("--world-only"), "快速世界测试必须传递 Godot 用户参数分隔符。")
	_expect("--world-only" not in slow_args, "慢速世界测试不得使用 world-only。")
	runner.free()
	if _failures.is_empty(): print("[Task0064TestRunnerCoverage] PASS"); quit(0)
	else:
		for failure in _failures: push_error("[Task0064TestRunnerCoverage] " + failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
