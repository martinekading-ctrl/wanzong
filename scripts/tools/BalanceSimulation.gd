class_name BalanceSimulation
extends RefCounted


static func run(days: int, restore_after: bool = true) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"error": "scene_tree_unavailable", "days_completed": 0}
	var save_manager: Node = tree.root.get_node("SaveManager")
	var game_state: Node = tree.root.get_node("GameState")
	var world_data: Node = tree.root.get_node("WorldDataManager")
	var ai_simulation: Node = tree.root.get_node("AISimulationManager")
	var history_manager: Node = tree.root.get_node("GameHistoryManager")
	var snapshot: Dictionary = save_manager.create_snapshot()
	var started_at: int = Time.get_ticks_msec()
	var maximum_day_ms: int = 0
	var negative_resource_count: int = 0
	var days_completed: int = 0
	for _day_index in range(maxi(0, days)):
		var day_started: int = Time.get_ticks_msec()
		var report: Dictionary = game_state.next_day()
		maximum_day_ms = maxi(maximum_day_ms, Time.get_ticks_msec() - day_started)
		if report.is_empty(): break
		days_completed += 1
		for resources in world_data.sect_resources.values():
			for amount in resources.values():
				if int(amount) < 0: negative_resource_count += 1
	var result: Dictionary = {
		"days_requested": days,
		"days_completed": days_completed,
		"elapsed_ms": Time.get_ticks_msec() - started_at,
		"maximum_day_ms": maximum_day_ms,
		"sect_count": world_data.get_all_sects().size(),
		"active_ai_count": ai_simulation.get_ai_sect_ids().size(),
		"disciple_count": world_data.get_all_disciples().size(),
		"negative_resource_count": negative_resource_count,
		"history_count": history_manager.get_all_entries().size(),
		"save_size_bytes": var_to_bytes(save_manager.create_snapshot()).size(),
	}
	if restore_after:
		result["restored"] = save_manager.apply_snapshot(snapshot)
	return result
