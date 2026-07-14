class_name ReleaseFileScanner
extends RefCounted

## 只读扫描器：用于拒绝生成目录中的陈旧事务残留，不删除任何文件。
static func find_stale_generated_files(root_path: String) -> PackedStringArray:
	var findings := PackedStringArray()
	_scan_directory(root_path, findings)
	return findings


static func _scan_directory(path: String, findings: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".tmp") or file_name.ends_with(".bak"):
			findings.append(path.path_join(file_name))
	for directory_name in directory.get_directories():
		var child_path := path.path_join(directory_name)
		if directory_name == ".world_bake_staging":
			if not _directory_is_empty(child_path):
				findings.append(child_path)
			continue
		_scan_directory(child_path, findings)


static func _directory_is_empty(path: String) -> bool:
	var directory := DirAccess.open(path)
	return directory != null and directory.get_files().is_empty() and directory.get_directories().is_empty()
