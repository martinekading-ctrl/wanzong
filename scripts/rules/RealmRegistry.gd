class_name RealmRegistry
extends RefCounted

const REALM_DIRECTORY := "res://configs/realms"

static var _definitions: Dictionary = {}
static var _ordered_definitions: Array[RealmDefinition] = []


static func get_by_id(realm_id: String) -> RealmDefinition:
	_ensure_loaded()
	return _definitions.get(realm_id) as RealmDefinition


static func get_all() -> Array[RealmDefinition]:
	_ensure_loaded()
	return _ordered_definitions.duplicate()


static func get_id_by_display_name(display_name: String) -> String:
	_ensure_loaded()
	for definition in _ordered_definitions:
		if definition.display_name == display_name:
			return definition.id
	return "mortal"


static func reload() -> void:
	_definitions.clear()
	_ordered_definitions.clear()
	_load_definitions()


static func validate_chain() -> PackedStringArray:
	_ensure_loaded()
	var errors := PackedStringArray()
	var seen_orders: Dictionary = {}
	for definition in _ordered_definitions:
		if definition.id == "":
			errors.append("存在空境界ID。")
		if definition.cultivation_required <= 0:
			errors.append("%s的修为上限无效。" % definition.id)
		if seen_orders.has(definition.order):
			errors.append("境界顺序重复：%d" % definition.order)
		seen_orders[definition.order] = true
		if definition.next_realm_id != "" and not _definitions.has(definition.next_realm_id):
			errors.append("%s指向不存在的下一境界%s。" % [definition.id, definition.next_realm_id])
	return errors


static func _ensure_loaded() -> void:
	if _definitions.is_empty():
		_load_definitions()


static func _load_definitions() -> void:
	var directory := DirAccess.open(REALM_DIRECTORY)
	if directory == null:
		push_error("境界配置目录不存在：" + REALM_DIRECTORY)
		return
	var file_names := PackedStringArray(directory.get_files())
	file_names.sort()
	for file_name in file_names:
		if file_name.get_extension().to_lower() != "tres":
			continue
		var definition := load(REALM_DIRECTORY.path_join(file_name)) as RealmDefinition
		if definition == null or definition.id == "":
			push_warning("无法读取境界配置：" + file_name)
			continue
		if _definitions.has(definition.id):
			push_warning("境界ID重复：" + definition.id)
			continue
		_definitions[definition.id] = definition
		_ordered_definitions.append(definition)
	_ordered_definitions.sort_custom(
		func(a: RealmDefinition, b: RealmDefinition) -> bool:
			return a.order < b.order
	)
