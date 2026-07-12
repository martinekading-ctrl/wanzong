class_name SaveManager
extends RefCounted


func create_snapshot() -> Dictionary:
	return {
		"year": GameState.year,
		"month": GameState.month,
		"day": GameState.day,
		"world_seed": GameState.world_seed,
		"game_speed": GameState.game_speed,
		"player_sect_id": GameState.player_sect.id if GameState.player_sect != null else "",
	}


func apply_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	GameState.year = int(snapshot.get("year", 1))
	GameState.month = int(snapshot.get("month", 1))
	GameState.day = int(snapshot.get("day", 1))
	GameState.world_seed = int(snapshot.get("world_seed", 0))
	GameState.game_speed = float(snapshot.get("game_speed", 1.0))
	return true
