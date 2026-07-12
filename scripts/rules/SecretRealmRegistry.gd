class_name SecretRealmRegistry
extends RefCounted

const DIRECTORY := "res://configs/secret_realms"
static var _definitions: Dictionary = {}


static func reload() -> void:
	_definitions.clear()
	_load()


static func get_by_id(realm_id: String) -> SecretRealmDefinition:
	_ensure_loaded()
	return _definitions.get(realm_id) as SecretRealmDefinition


static func get_all() -> Array[SecretRealmDefinition]:
	_ensure_loaded()
	var result: Array[SecretRealmDefinition] = []
	for definition in _definitions.values():
		result.append(definition as SecretRealmDefinition)
	result.sort_custom(func(a: SecretRealmDefinition, b: SecretRealmDefinition) -> bool: return a.level < b.level)
	return result


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var resource_ids: Dictionary = {}
	for definition in get_all():
		if definition.id == "" or definition.display_name == "":
			errors.append("秘境ID或名称为空。")
		if definition.map_resource_id <= 0 or resource_ids.has(definition.map_resource_id):
			errors.append("秘境地图资源ID无效或重复：%s" % definition.id)
		resource_ids[definition.map_resource_id] = true
	return errors


static func _ensure_loaded() -> void:
	if _definitions.is_empty():
		_load()


static func _load() -> void:
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		push_error("秘境配置目录不存在：" + DIRECTORY)
		return
	var files := PackedStringArray(directory.get_files())
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var definition := load(DIRECTORY.path_join(file_name)) as SecretRealmDefinition
		if definition == null or definition.id == "" or _definitions.has(definition.id):
			push_warning("无效或重复秘境配置：" + file_name)
			continue
		_definitions[definition.id] = definition

