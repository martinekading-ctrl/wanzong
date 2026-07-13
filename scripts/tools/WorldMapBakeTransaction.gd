@tool
class_name WorldMapBakeTransaction
extends RefCounted

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
			"bytes": FileAccess.get_file_as_bytes(target) if FileAccess.file_exists(target) else PackedByteArray(),
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
		var output := FileAccess.open(target, FileAccess.WRITE)
		if output == null:
			_restore_backups(backups)
			return ERR_CANT_CREATE
		output.store_buffer(FileAccess.get_file_as_bytes(str(entries[index]["staged"])))
		output.close()
	return OK


static func _restore_backups(backups: Array[Dictionary]) -> void:
	for backup in backups:
		var target: String = str(backup["target"])
		if bool(backup["existed"]):
			var output := FileAccess.open(target, FileAccess.WRITE)
			if output != null:
				output.store_buffer(backup["bytes"])
				output.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
