class_name DiplomaticActionRegistry
extends RefCounted

const DIRECTORY := "res://configs/diplomacy/actions"
static var _definitions: Dictionary = {}


static func reload() -> void:
	_definitions.clear()
	_load()


static func get_by_id(action_id: String) -> DiplomaticActionDefinition:
	_ensure_loaded()
	return _definitions.get(action_id) as DiplomaticActionDefinition


static func get_all() -> Array[DiplomaticActionDefinition]:
	_ensure_loaded()
	var result: Array[DiplomaticActionDefinition] = []
	for definition in _definitions.values():
		result.append(definition as DiplomaticActionDefinition)
	result.sort_custom(func(a: DiplomaticActionDefinition, b: DiplomaticActionDefinition) -> bool: return a.id < b.id)
	return result


static func _ensure_loaded() -> void:
	if _definitions.is_empty():
		_load()


static func _load() -> void:
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		push_error("外交行动配置目录不存在：" + DIRECTORY)
		return
	var files := PackedStringArray(directory.get_files())
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var definition := load(DIRECTORY.path_join(file_name)) as DiplomaticActionDefinition
		if definition == null or definition.id == "" or _definitions.has(definition.id):
			push_warning("无效或重复外交行动配置：" + file_name)
			continue
		_definitions[definition.id] = definition

