class_name BuildingRegistry
extends RefCounted

const BUILDING_DIRECTORY := "res://configs/buildings"

static var _definitions: Dictionary = {}


static func reload() -> void:
	_definitions.clear()
	_load_definitions()


static func get_by_id(building_id: String) -> BuildingDefinition:
	_ensure_loaded()
	return _definitions.get(building_id) as BuildingDefinition


static func get_all() -> Array[BuildingDefinition]:
	_ensure_loaded()
	var result: Array[BuildingDefinition] = []
	for definition in _definitions.values():
		result.append(definition as BuildingDefinition)
	result.sort_custom(func(a: BuildingDefinition, b: BuildingDefinition) -> bool: return a.id < b.id)
	return result


static func validate() -> PackedStringArray:
	_ensure_loaded()
	var errors := PackedStringArray()
	for definition in get_all():
		if definition.id == "" or definition.display_name == "":
			errors.append("建筑ID或名称为空。")
		if definition.construction_days <= 0:
			errors.append("%s建设时间无效。" % definition.id)
		for prerequisite in definition.prerequisites:
			if not _definitions.has(prerequisite):
				errors.append("%s前置建筑不存在：%s" % [definition.id, prerequisite])
	return errors


static func _ensure_loaded() -> void:
	if _definitions.is_empty():
		_load_definitions()


static func _load_definitions() -> void:
	var directory := DirAccess.open(BUILDING_DIRECTORY)
	if directory == null:
		push_error("建筑配置目录不存在：" + BUILDING_DIRECTORY)
		return
	var file_names := PackedStringArray(directory.get_files())
	file_names.sort()
	for file_name in file_names:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var definition := load(BUILDING_DIRECTORY.path_join(file_name)) as BuildingDefinition
		if definition == null or definition.id == "":
			push_warning("无法读取建筑配置：" + file_name)
			continue
		if _definitions.has(definition.id):
			push_warning("建筑ID重复：" + definition.id)
			continue
		_definitions[definition.id] = definition
