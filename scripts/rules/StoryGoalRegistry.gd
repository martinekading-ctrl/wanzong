class_name StoryGoalRegistry
extends RefCounted

const DIRECTORY := "res://configs/goals"
static var _definitions: Dictionary = {}

static func reload() -> void:
	_definitions.clear(); _load()

static func get_by_id(goal_id: String) -> StoryGoalDefinition:
	_ensure_loaded(); return _definitions.get(goal_id) as StoryGoalDefinition

static func get_all() -> Array[StoryGoalDefinition]:
	_ensure_loaded()
	var result: Array[StoryGoalDefinition] = []
	for value in _definitions.values(): result.append(value as StoryGoalDefinition)
	result.sort_custom(func(a: StoryGoalDefinition, b: StoryGoalDefinition) -> bool: return a.order < b.order)
	return result

static func _ensure_loaded() -> void:
	if _definitions.is_empty(): _load()

static func _load() -> void:
	var directory := DirAccess.open(DIRECTORY)
	if directory == null: push_error("目标配置目录不存在：" + DIRECTORY); return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "tres": continue
		var definition := load(DIRECTORY.path_join(file_name)) as StoryGoalDefinition
		if definition != null and definition.id != "": _definitions[definition.id] = definition

