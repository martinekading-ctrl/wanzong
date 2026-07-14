extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = root.get_node("SaveManager")
	var migrated: Dictionary = manager.migrate_snapshot(_legacy_snapshot())
	_expect(bool(migrated.get("success", false)), "v1 snapshot must migrate")
	var world_data: Dictionary = migrated.get("snapshot", {}).get("world_data", {})
	_expect(int(world_data.get("world_map_layout_version", 0)) == 2, "layout version must become v2")
	_expect(int(world_data.get("world_sect_roster_version", 0)) == WorldSectRoster.ROSTER_VERSION, "world roster version must become v2")
	_expect(_near(_sect(world_data)["location"], Vector2(2176, 2176)), "center sect must use 4096 to 4352 scale")
	_expect(_sect(world_data)["location"] == _sect(world_data)["position"], "sect location and position must match")
	_expect(_near((world_data["resources"][0] as Dictionary)["position"], Vector2(4352, 0)), "resource must migrate and clamp")
	_expect(_near((world_data["build_slots"][0] as Dictionary)["position"], Vector2(1088, 1088)), "build slot must migrate")
	_expect(_near((world_data["war_campaigns"][0] as Dictionary)["target_position"], Vector2(3264, 3264)), "war target must migrate")
	_expect(_near((world_data["territory_states"]["sect_001"] as Dictionary)["center"], Vector2(2176, 2176)), "territory center must migrate")
	_expect(_near((world_data["territory_states"]["sect_001"] as Dictionary)["control_positions"][0], Vector2.ZERO), "territory control positions must migrate")
	_expect(_near((world_data["territory_states"]["sect_001"] as Dictionary)["boundary_points"][0], Vector2(4352, 4352)), "territory boundary positions must migrate")
	_expect((world_data["battle_instances"][0] as Dictionary)["ui_preview_position"] == Vector2(5000, 5000), "non-world battle UI vectors must remain unchanged")
	_expect((world_data["ui_state"] as Dictionary)["map_panel_position"] == Vector2(320, 180), "UI vectors must remain unchanged")
	var twice: Dictionary = manager.migrate_snapshot(migrated["snapshot"])
	_expect(twice.get("snapshot", {}) == migrated.get("snapshot", {}), "v2 migration must be idempotent")
	var already_v2 := _legacy_snapshot()
	already_v2["world_data"]["world_map_layout_version"] = WorldMapSpec.MAP_LAYOUT_VERSION
	already_v2["world_data"]["world_sect_roster_version"] = WorldSectRoster.ROSTER_VERSION
	var unchanged: Dictionary = manager.migrate_snapshot(already_v2)
	_expect(unchanged.get("snapshot", {}) == already_v2, "explicit v2 snapshots must remain unchanged")
	if failures.is_empty(): print("[Task0065WorldMapMigration] PASS"); quit(0)
	else:
		for failure in failures: push_error("[Task0065WorldMapMigration] " + failure)
		quit(1)


func _legacy_snapshot() -> Dictionary:
	return {"save_version": 1, "game_state": {}, "world_data": {"sects": [{"sect_id":"sect_001", "location":Vector2(2048,2048), "position":Vector2(2048,2048)}], "resources":[{"resource_id":1,"position":Vector2(5000,0)}], "build_slots":[{"slot_id":1,"position":Vector2(1024,1024)}], "war_campaigns":[{"target_position":Vector2(3072,3072)}], "territory_states":{"sect_001":{"center":Vector2(2048,2048),"control_positions":[Vector2(0,0)],"boundary_points":[Vector2(4096,4096)]}}, "battle_instances":[{"ui_preview_position":Vector2(5000,5000)}], "ui_state":{"map_panel_position":Vector2(320,180)}, "disciples":[], "sect_resources":{}, "event_instances":[], "history_entries":[], "ai_states":[]}}


func _sect(world_data: Dictionary) -> Dictionary: return world_data["sects"][0]
func _near(left: Vector2, right: Vector2) -> bool: return left.distance_to(right) < 0.01
func _expect(condition: bool, message: String) -> void: if not condition: failures.append(message)
