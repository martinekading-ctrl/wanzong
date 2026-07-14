class_name ReleaseFileScanner
extends RefCounted

## 只读扫描器：用于拒绝生成目录中的陈旧事务残留，不删除任何文件。
static var _directory_open_override: Callable = Callable()


static func find_stale_generated_files(root_path: String) -> PackedStringArray:
	return scan_generated_directory(root_path).get("findings", PackedStringArray())


## 返回 findings 与 scan_errors；发布清单必须对扫描失败采取 fail-closed 策略。
static func scan_generated_directory(root_path: String) -> Dictionary:
	var findings := PackedStringArray()
	var scan_errors := PackedStringArray()
	_scan_directory(root_path, findings, scan_errors)
	return {"findings": findings, "scan_errors": scan_errors}


## 仅用于回归测试，模拟目录在扫描时无法打开的 fail-closed 路径。
static func set_directory_open_override_for_testing(override: Callable) -> void:
	_directory_open_override = override


static func clear_directory_open_override_for_testing() -> void:
	_directory_open_override = Callable()


static func _scan_directory(path: String, findings: PackedStringArray, scan_errors: PackedStringArray) -> void:
	var directory := _open_directory(path)
	if directory == null:
		scan_errors.append("cannot scan generated directory: " + path)
		return
	directory.include_hidden = true

	# Probe staging explicitly so hidden dot-directories are never skipped on Linux.
	var staging_path := path.path_join(".world_bake_staging")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_path)):
		var staging_result := _inspect_staging_directory(staging_path, scan_errors)
		if staging_result == "non_empty":
			findings.append(staging_path)

	for file_name in directory.get_files():
		if file_name.ends_with(".tmp") or file_name.ends_with(".bak"):
			findings.append(path.path_join(file_name))
	for directory_name in directory.get_directories():
		if directory_name == ".world_bake_staging":
			continue
		_scan_directory(path.path_join(directory_name), findings, scan_errors)


static func _inspect_staging_directory(path: String, scan_errors: PackedStringArray) -> String:
	var directory := _open_directory(path)
	if directory == null:
		scan_errors.append("cannot scan generated staging directory: " + path)
		return "scan_error"
	directory.include_hidden = true
	if directory.get_files().is_empty() and directory.get_directories().is_empty():
		return "empty"
	return "non_empty"


static func _open_directory(path: String) -> DirAccess:
	if _directory_open_override.is_valid():
		return _directory_open_override.call(path) as DirAccess
	return DirAccess.open(path)
