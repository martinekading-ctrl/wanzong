extends Node

signal tutorial_updated(state: Dictionary)

const STEP_ASSIGNMENT := "assignment"
const STEP_ADVANCE := "advance"
const STEP_BREAKTHROUGH := "breakthrough"
const STEP_BUILDING := "building"
const STEP_EXPLORATION := "exploration"

const STEPS: Array[Dictionary] = [
	{"id": STEP_ASSIGNMENT, "title": "安排第一名弟子", "description": "进入弟子名册，选择弟子并确认一项安排。"},
	{"id": STEP_ADVANCE, "title": "推进第一天", "description": "点击顶部的“推进一天”，观察资源与弟子状态结算。"},
	{"id": STEP_BREAKTHROUGH, "title": "完成第一次突破", "description": "培养达到瓶颈的弟子，并在详情中尝试突破。"},
	{"id": STEP_BUILDING, "title": "开工第一座建筑", "description": "进入建筑页，选择满足条件的建筑开始建设。"},
	{"id": STEP_EXPLORATION, "title": "开始第一次探索", "description": "进入任务页，组建队伍并派往一处秘境。"},
]

var _signals_connected: bool = false


func _ready() -> void:
	call_deferred("_connect_system_signals")


func initialize_world_state() -> void:
	if not WorldDataManager.ui_state.has("tutorial"):
		WorldDataManager.ui_state["tutorial"] = _default_state()
	_normalize_state()
	tutorial_updated.emit(get_state())


func rebuild_runtime_state() -> void:
	initialize_world_state()
	_connect_system_signals()


func get_state() -> Dictionary:
	initialize_world_state_if_needed()
	return WorldDataManager.ui_state.get("tutorial", _default_state()).duplicate(true)


func get_current_prompt() -> Dictionary:
	var state: Dictionary = get_state()
	var index: int = int(state.get("current_index", 0))
	if index >= STEPS.size():
		return {
			"id": "complete",
			"title": "新手引导完成",
			"description": "你已掌握宗门经营的五个基础操作。",
			"index": STEPS.size(),
			"total": STEPS.size(),
		}
	var prompt: Dictionary = STEPS[index].duplicate(true)
	prompt["index"] = index
	prompt["total"] = STEPS.size()
	return prompt


func complete_step(step_id: String) -> bool:
	initialize_world_state_if_needed()
	var state: Dictionary = WorldDataManager.ui_state["tutorial"]
	var completed: Array = state.get("completed_steps", [])
	if step_id in completed:
		return false
	var expected_index: int = int(state.get("current_index", 0))
	if expected_index >= STEPS.size() or str(STEPS[expected_index].get("id", "")) != step_id:
		return false
	completed.append(step_id)
	state["completed_steps"] = completed
	state["current_index"] = mini(expected_index + 1, STEPS.size())
	WorldDataManager.ui_state["tutorial"] = state
	AudioManager.play_ui("confirm")
	tutorial_updated.emit(state.duplicate(true))
	return true


func dismiss() -> void:
	_set_dismissed(true)


func show_tutorial() -> void:
	_set_dismissed(false)


func reset_tutorial() -> void:
	WorldDataManager.ui_state["tutorial"] = _default_state()
	tutorial_updated.emit(get_state())


func is_visible() -> bool:
	var state: Dictionary = get_state()
	return bool(state.get("enabled", true)) and not bool(state.get("dismissed", false))


func initialize_world_state_if_needed() -> void:
	if not WorldDataManager.ui_state.has("tutorial"):
		WorldDataManager.ui_state["tutorial"] = _default_state()


func _set_dismissed(value: bool) -> void:
	initialize_world_state_if_needed()
	var state: Dictionary = WorldDataManager.ui_state["tutorial"]
	state["dismissed"] = value
	WorldDataManager.ui_state["tutorial"] = state
	tutorial_updated.emit(state.duplicate(true))


func _default_state() -> Dictionary:
	return {"enabled": true, "dismissed": false, "completed_steps": [], "current_index": 0}


func _normalize_state() -> void:
	var state: Dictionary = WorldDataManager.ui_state["tutorial"]
	state["enabled"] = bool(state.get("enabled", true))
	state["dismissed"] = bool(state.get("dismissed", false))
	state["completed_steps"] = state.get("completed_steps", [])
	state["current_index"] = clampi(int(state.get("current_index", state["completed_steps"].size())), 0, STEPS.size())
	WorldDataManager.ui_state["tutorial"] = state


func _connect_system_signals() -> void:
	if _signals_connected:
		return
	WorldDataManager.disciple_data_updated.connect(_on_disciple_data_updated)
	GameState.day_advanced.connect(_on_day_advanced)
	BreakthroughManager.breakthrough_completed.connect(_on_breakthrough_completed)
	ConstructionManager.construction_started.connect(_on_construction_started)
	MissionManager.mission_started.connect(_on_mission_started)
	_signals_connected = true


func _on_disciple_data_updated(disciple_id: String, key: String, _value: Variant) -> void:
	if key != "assignment":
		return
	var disciple: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
	if str(disciple.get("sect_id", "")) == "sect_001":
		complete_step(STEP_ASSIGNMENT)


func _on_day_advanced(_year: int, _month: int, _day: int) -> void:
	complete_step(STEP_ADVANCE)


func _on_breakthrough_completed(result: Dictionary) -> void:
	if bool(result.get("attempted", false)):
		complete_step(STEP_BREAKTHROUGH)


func _on_construction_started(instance_data: Dictionary) -> void:
	if str(instance_data.get("sect_id", "")) == "sect_001":
		complete_step(STEP_BUILDING)


func _on_mission_started(instance_data: Dictionary) -> void:
	if str(instance_data.get("sect_id", "")) != "sect_001":
		return
	var definition: MissionDefinition = MissionRegistry.get_by_id(str(instance_data.get("definition_id", "")))
	if definition != null and definition.mission_type == "secret_realm":
		complete_step(STEP_EXPLORATION)
