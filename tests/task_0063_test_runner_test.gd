extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runner_source := FileAccess.get_file_as_string("res://scripts/tools/RunAllTests.gd")
	var workflow_source := FileAccess.get_file_as_string("res://.github/workflows/godot-ci.yml")
	if "quit(1)" not in runner_source or "OS.execute" not in runner_source:
		push_error("[Task0063TestRunner] 统一测试入口必须传播失败退出码。")
		quit(1)
		return
	if "pull_request:" not in workflow_source or "branches: [master]" not in workflow_source or "RunAllTests.gd" not in workflow_source:
		push_error("[Task0063TestRunner] CI 必须覆盖 master PR 并调用统一测试入口。")
		quit(1)
		return
	print("[Task0063TestRunner] PASS")
	quit(0)
