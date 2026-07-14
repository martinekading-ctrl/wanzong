class_name ReleaseFileScanner
extends RefCounted

## 只读扫描器：用于拒绝生成目录中的陈旧事务残留，不删除任何文件。
static func find_stale_generated_files(root_path: String) -> PackedStringArray:
	return scan_generated_directory(root_path).get("findings", PackedStringArray())


## 返回 findings 与 scan_errors；发布清单必须对扫描失败采取 fail-closed 策略。
static func scan_generated_directory(root_path: String) -> Dictionary:
	var findings := PackedStringArray()
	var scan_errors := PackedStringArray()
	_scan_directory(root_path, findings, scan_errors)
	return {"findings": findings, "scan_errors": scan_errors}


static func _scan_directory(path: String, findings: PackedStringArray, scan_errors: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		scan_errors.append("cannot scan generated directory: " + path)
		return
	# get_directories() may omit dot-prefixed directories on some platforms.
	# Probe staging explicitly so release validation is identical on Windows and Linux CI.
	var staging_path := path.path_join(".world_bake_staging")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_path)) and not _directory_is_empty(staging_path):
		findings.append(staging_path)
	for file_name in directory.get_files():
		if file_name.ends_with(".tmp") or file_name.ends_with(".bak"):
			findings.append(path.path_join(file_name))
	for directory_name in directory.get_directories():
		var child_path := path.path_join(directory_name)
		if directory_name == ".world_bake_staging":
			continue
		_scan_directory(child_path, findings, scan_errors)


static func _directory_is_empty(path: String) -> bool:
	var directory := DirAccess.open(path)
	return directory != null and directory.get_files().is_empty() and directory.get_directories().is_empty()
