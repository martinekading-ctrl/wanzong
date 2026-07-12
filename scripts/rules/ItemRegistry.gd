class_name ItemRegistry
extends RefCounted

const DIRECTORY := "res://configs/items"
static var _definitions: Dictionary = {}


static func reload() -> void:
	_definitions.clear()
	_load()


static func get_by_id(item_id: String) -> ItemDefinition:
	_ensure_loaded()
	return _definitions.get(item_id) as ItemDefinition


static func get_all() -> Array[ItemDefinition]:
	_ensure_loaded()
	var result: Array[ItemDefinition] = []
	for definition in _definitions.values(): result.append(definition as ItemDefinition)
	result.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool: return a.id < b.id)
	return result


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in get_all():
		if definition.id == "" or definition.display_name == "" or definition.stack_limit <= 0:
			errors.append("无效物品配置：" + definition.id)
	return errors


static func _ensure_loaded() -> void:
	if _definitions.is_empty(): _load()


static func _load() -> void:
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		push_error("物品配置目录不存在：" + DIRECTORY)
		return
	var files := PackedStringArray(directory.get_files())
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres": continue
		var definition := load(DIRECTORY.path_join(file_name)) as ItemDefinition
		if definition == null or definition.id == "" or _definitions.has(definition.id):
			push_warning("无效或重复物品配置：" + file_name)
			continue
		_definitions[definition.id] = definition

