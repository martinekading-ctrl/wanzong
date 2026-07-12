class_name MissionRegistry
extends RefCounted

const MISSION_DIRECTORY := "res://configs/missions"
static var _definitions: Dictionary = {}


static func reload() -> void:
	_definitions.clear()
	_load()


static func get_by_id(mission_id: String) -> MissionDefinition:
	_ensure_loaded()
	return _definitions.get(mission_id) as MissionDefinition


static func get_all() -> Array[MissionDefinition]:
	_ensure_loaded()
	var result: Array[MissionDefinition] = []
	for definition in _definitions.values():
		result.append(definition as MissionDefinition)
	result.sort_custom(func(a: MissionDefinition, b: MissionDefinition) -> bool: return a.id < b.id)
	return result


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var types: Dictionary = {}
	for definition in get_all():
		if definition.id == "" or definition.display_name == "":
			errors.append("任务ID或名称为空。")
		if definition.min_team_size > definition.max_team_size:
			errors.append("%s队伍人数范围无效。" % definition.id)
		types[definition.mission_type] = true
	for required_type in ["gathering", "scouting", "escort", "hunt", "recruitment", "secret_realm"]:
		if not types.has(required_type):
			errors.append("缺少任务类型：" + required_type)
	return errors


static func _ensure_loaded() -> void:
	if _definitions.is_empty():
		_load()


static func _load() -> void:
	var directory := DirAccess.open(MISSION_DIRECTORY)
	if directory == null:
		push_error("任务配置目录不存在：" + MISSION_DIRECTORY)
		return
	var files := PackedStringArray(directory.get_files())
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var definition := load(MISSION_DIRECTORY.path_join(file_name)) as MissionDefinition
		if definition == null or definition.id == "" or _definitions.has(definition.id):
			push_warning("无效或重复任务配置：" + file_name)
			continue
		_definitions[definition.id] = definition
