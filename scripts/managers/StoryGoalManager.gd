extends Node

signal goal_completed(goal_data: Dictionary)


func initialize_world_state() -> void:
	for definition in StoryGoalRegistry.get_all():
		if not WorldDataManager.story_goals.has(definition.id):
			WorldDataManager.story_goals[definition.id] = {
				"goal_id": definition.id,
				"status": "active",
				"completed_date": {},
				"reward_claimed": false,
			}


func rebuild_runtime_state() -> void:
	initialize_world_state()


func daily_update(date: Dictionary) -> Dictionary:
	var completed: Array[Dictionary] = []
	for definition in StoryGoalRegistry.get_all():
		var state: Dictionary = WorldDataManager.story_goals.get(definition.id, {})
		if str(state.get("status", "active")) == "completed" or not _conditions_met(definition.conditions):
			continue
		state["status"] = "completed"
		state["completed_date"] = date.duplicate(true)
		state["reward_claimed"] = InventoryManager.add_items("sect_001", definition.rewards)
		WorldDataManager.story_goals[definition.id] = state
		var view: Dictionary = get_goal_view(definition.id)
		completed.append(view)
		GameHistoryManager.record_entry(
			"story_goal",
			"目标完成",
			"完成长期目标：%s。" % definition.display_name,
			["sect_001", definition.id],
			view,
			date
		)
		goal_completed.emit(view)
	return {"completed": completed, "active_count": get_active_goals().size()}


func get_goal_view(goal_id: String) -> Dictionary:
	var definition: StoryGoalDefinition = StoryGoalRegistry.get_by_id(goal_id)
	if definition == null:
		return {}
	var result: Dictionary = WorldDataManager.story_goals.get(goal_id, {}).duplicate(true)
	result["display_name"] = definition.display_name
	result["description"] = definition.description
	result["order"] = definition.order
	result["conditions"] = definition.conditions.duplicate(true)
	result["rewards"] = definition.rewards.duplicate(true)
	result["progress"] = _condition_progress(definition.conditions)
	return result


func get_all_goals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in StoryGoalRegistry.get_all():
		result.append(get_goal_view(definition.id))
	return result


func get_active_goals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for goal in get_all_goals():
		if str(goal.get("status", "active")) == "active":
			result.append(goal)
	return result


func _conditions_met(conditions: Array[Dictionary]) -> bool:
	for condition in conditions:
		var current: int = _condition_value(condition)
		if current < int(condition.get("value", 0)):
			return false
	return true


func _condition_progress(conditions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for condition in conditions:
		result.append({"type": str(condition.get("type", "")), "current": _condition_value(condition), "required": int(condition.get("value", 0))})
	return result


func _condition_value(condition: Dictionary) -> int:
	match str(condition.get("type", "")):
		"sect_field":
			return int(WorldDataManager.get_player_sect().get(str(condition.get("key", "")), 0))
		"owned_resources":
			return ResourceSiteManager.get_owned_sites("sect_001").size()
		"disciple_count":
			return WorldDataManager.get_player_disciples().size()
		"cleared_realms":
			var count: int = 0
			for realm in SecretRealmManager.get_all_realms():
				if str(realm.get("status", "")) == "cleared":
					count += 1
			return count
		"influence":
			return int(TerritoryManager.get_territory("sect_001").get("influence", 0))
		"active_pacts":
			var count: int = 0
			for pact in DiplomacyManager.get_pacts_for_sect("sect_001"):
				if str(pact.get("pact_type", "")) in condition.get("types", []):
					count += 1
			return count
	return 0
