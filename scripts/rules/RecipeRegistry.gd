class_name RecipeRegistry
extends RefCounted

const DIRECTORY := "res://configs/recipes"
static var _definitions: Dictionary = {}


static func reload() -> void:
	_definitions.clear()
	_load()


static func get_by_id(recipe_id: String) -> RecipeDefinition:
	_ensure_loaded()
	return _definitions.get(recipe_id) as RecipeDefinition


static func get_all() -> Array[RecipeDefinition]:
	_ensure_loaded()
	var result: Array[RecipeDefinition] = []
	for definition in _definitions.values(): result.append(definition as RecipeDefinition)
	result.sort_custom(func(a: RecipeDefinition, b: RecipeDefinition) -> bool: return a.id < b.id)
	return result


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for recipe in get_all():
		if recipe.id == "" or recipe.ingredients.is_empty() or recipe.outputs.is_empty():
			errors.append("无效配方：" + recipe.id)
		for item_id in recipe.ingredients.keys() + recipe.outputs.keys():
			if ItemRegistry.get_by_id(str(item_id)) == null:
				errors.append("%s引用未知物品：%s" % [recipe.id, item_id])
	return errors


static func _ensure_loaded() -> void:
	if _definitions.is_empty(): _load()


static func _load() -> void:
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		push_error("配方目录不存在：" + DIRECTORY)
		return
	var files := PackedStringArray(directory.get_files())
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "tres": continue
		var definition := load(DIRECTORY.path_join(file_name)) as RecipeDefinition
		if definition == null or definition.id == "" or _definitions.has(definition.id):
			push_warning("无效或重复配方：" + file_name)
			continue
		_definitions[definition.id] = definition
