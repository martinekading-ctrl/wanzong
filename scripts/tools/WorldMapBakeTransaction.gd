@tool
class_name WorldMapBakeTransaction
extends RefCounted

const STAGING_ROOT := "res://assets/generated/.world_bake_staging"

## 把已验证的临时资源整体提交到正式路径；任一写入失败都会恢复之前的文件。
static func commit_files(staged_to_target: Dictionary, fail_after: int = -1) -> Error:
	var entries: Array[Dictionary] = []
	for staged_path in staged_to_target:
		var target_path: String = str(staged_to_target[staged_path])
		if not FileAccess.file_exists(str(staged_path)):
			return ERR_FILE_NOT_FOUND
		entries.append({"staged": str(staged_path), "target": target_path})
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["target"]) < str(right["target"])
	)
	var backups: Array[Dictionary] = []
	for entry in entries:
		var target: String = str(entry["target"])
		backups.append({
			"target": target,
			"existed": FileAccess.file_exists(target),
			"backup": target + ".bak",
			"temporary": target + ".tmp",
		})
	for index in range(entries.size()):
		if fail_after >= 0 and index >= fail_after:
			_restore_backups(backups)
			return ERR_CANT_CREATE
		var target: String = str(entries[index]["target"])
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
		if directory_error != OK:
			_restore_backups(backups)
			return directory_error
		var output := FileAccess.open(target + ".tmp", FileAccess.WRITE)
		if output == null:
			_restore_backups(backups)
			return ERR_CANT_CREATE
		var staged_bytes := FileAccess.get_file_as_bytes(str(entries[index]["staged"]))
		output.store_buffer(staged_bytes)
		output.flush()
		output.close()
		if FileAccess.get_md5(target + ".tmp") != FileAccess.get_md5(str(entries[index]["staged"])):
			_restore_backups(backups)
			return ERR_FILE_CORRUPT
	for backup in backups:
		var directory := DirAccess.open(str(backup["target"]).get_base_dir())
		if directory == null: _restore_backups(backups); return ERR_CANT_OPEN
		var target_name := str(backup["target"]).get_file()
		if bool(backup["existed"]) and directory.rename(target_name, target_name + ".bak") != OK:
			_restore_backups(backups); return ERR_CANT_CREATE
		if directory.rename(target_name + ".tmp", target_name) != OK:
			_restore_backups(backups); return ERR_CANT_CREATE
	for backup in backups:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(backup["backup"])))
	return OK


static func _restore_backups(backups: Array[Dictionary]) -> void:
	for backup in backups:
		var target: String = str(backup["target"])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(backup["temporary"])))
		var directory := DirAccess.open(target.get_base_dir())
		if directory != null and FileAccess.file_exists(str(backup["backup"])):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
			directory.rename(str(backup["backup"]).get_file(), target.get_file())
		elif not bool(backup["existed"]): DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


static func remove_staging_directory_recursive(path: String) -> Error:
	if path.is_empty() or not path.begins_with(STAGING_ROOT + "/") or path == STAGING_ROOT or ".." in path or path.begins_with("user://"):
		return ERR_INVALID_PARAMETER
	var directory := DirAccess.open(path)
	if directory == null: return OK
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		var error := remove_staging_directory_recursive(child) if directory.current_is_dir() else directory.remove(name)
		if error != OK: directory.list_dir_end(); return error
		name = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
