class_name RegionRegistry
extends RefCounted

const DIRECTORY := "res://configs/regions"
static var _definitions: Dictionary = {}

static func get_all() -> Array[RegionDefinition]:
	if _definitions.is_empty(): _load()
	var result: Array[RegionDefinition] = []
	for value in _definitions.values(): result.append(value as RegionDefinition)
	result.sort_custom(func(a: RegionDefinition, b: RegionDefinition) -> bool: return a.id < b.id)
	return result

static func get_by_id(region_id: String) -> RegionDefinition:
	if _definitions.is_empty(): _load()
	return _definitions.get(region_id) as RegionDefinition

static func _load() -> void:
	var directory := DirAccess.open(DIRECTORY)
	if directory == null: push_error("区域配置目录不存在：" + DIRECTORY); return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "tres": continue
		var definition := load(DIRECTORY.path_join(file_name)) as RegionDefinition
		if definition != null and definition.id != "": _definitions[definition.id] = definition
