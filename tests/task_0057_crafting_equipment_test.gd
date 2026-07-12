extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _crafting_manager: Node
var _inventory_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_crafting_manager = root.get_node("CraftingManager")
	_inventory_manager = root.get_node("InventoryManager")
	_test_requirements_success_and_failure()
	_test_forging_equipment_consumables_and_battle_stats()
	_test_active_job_save_restore()
	await _test_crafting_ui()
	if _failures.is_empty():
		print("[Task0057Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0057Test] " + failure)
	quit(1)


func _test_requirements_success_and_failure() -> void:
	_game_state.new_game()
	var grass_before: int = _inventory_manager.get_item_count("sect_001", "spirit_grass")
	var blocked: Dictionary = _crafting_manager.start_crafting("sect_001", "recipe_qi_gathering_pill", "disciple_006", {"_test_roll": 0.0})
	_expect(str(blocked.get("code", "")) == "building_requirement", "没有炼丹房时不得启动炼丹。")
	_expect(_inventory_manager.get_item_count("sect_001", "spirit_grass") == grass_before, "建筑门槛失败不得扣材料。")
	_add_building("alchemy_room", 1)
	var wrong_worker: Dictionary = _crafting_manager.start_crafting("sect_001", "recipe_qi_gathering_pill", "disciple_001", {"_test_roll": 0.0})
	_expect(str(wrong_worker.get("code", "")) == "worker_skill", "炼丹配方应要求丹道弟子。")
	var started: Dictionary = _crafting_manager.start_crafting("sect_001", "recipe_qi_gathering_pill", "disciple_006", {"seed": 100, "_test_roll": 0.0})
	_expect(bool(started.get("success", false)), "丹道弟子在炼丹房应可开始制作。")
	_expect(bool(_world_data_manager.get_disciple_by_id("disciple_006").get("is_deployed", false)), "制作期间负责弟子应被占用。")
	_expect(_inventory_manager.get_item_count("sect_001", "spirit_grass") == grass_before - 5, "启动制作时应扣除配方材料。")
	_crafting_manager.daily_update(_date(1))
	_expect(_inventory_manager.get_item_count("sect_001", "qi_gathering_pill") == 0, "制作时间未结束前不得提前产出。")
	var completion: Dictionary = _crafting_manager.daily_update(_date(2))
	_expect(bool(completion.get("completed", [])[0].get("crafted", false)), "强制成功炼丹应产出丹药。")
	_expect(_inventory_manager.get_item_count("sect_001", "qi_gathering_pill") == 1, "聚气丹应进入宗门背包。")
	_expect(not bool(_world_data_manager.get_disciple_by_id("disciple_006").get("is_deployed", true)), "制作结束后负责弟子应恢复可用。")

	var grass_pre_failure: int = _inventory_manager.get_item_count("sect_001", "spirit_grass")
	var stone_pre_failure: int = _inventory_manager.get_item_count("sect_001", "spirit_stone")
	started = _crafting_manager.start_crafting("sect_001", "recipe_healing_pill", "disciple_011", {"seed": 101, "_test_roll": 1.0})
	_expect(bool(started.get("success", false)), "第二名丹道弟子应可开始回春丹制作。")
	_crafting_manager.daily_update(_date(3))
	completion = _crafting_manager.daily_update(_date(4))
	_expect(not bool(completion.get("completed", [])[0].get("crafted", true)), "强制失败判定应生效。")
	_expect(_inventory_manager.get_item_count("sect_001", "spirit_grass") == grass_pre_failure - 8 + 2, "失败应返还四分之一灵草。")
	_expect(_inventory_manager.get_item_count("sect_001", "spirit_stone") == stone_pre_failure - 12 + 3, "失败应返还四分之一灵石。")


func _test_forging_equipment_consumables_and_battle_stats() -> void:
	_game_state.new_game()
	_add_building("forge", 1)
	var started: Dictionary = _crafting_manager.start_crafting("sect_001", "recipe_iron_sword", "disciple_001", {"seed": 200, "_test_roll": 0.0})
	_expect(bool(started.get("success", false)), "炼器坊应可启动玄铁剑锻造。")
	for day in range(3): _crafting_manager.daily_update(_date(day + 1))
	_expect(_inventory_manager.get_item_count("sect_001", "iron_sword") == 1, "锻造成功后装备应进入背包。")
	var base_attack: int = int(_world_data_manager.get_disciple_by_id("disciple_001")["attack"])
	var equipped: Dictionary = _crafting_manager.equip_item("sect_001", "disciple_001", "iron_sword")
	_expect(bool(equipped.get("success", false)), "弟子应可穿戴背包中的装备。")
	_expect(str(_world_data_manager.get_disciple_by_id("disciple_001").get("equipment", {}).get("weapon", "")) == "iron_sword", "装备槽应保存物品ID。")
	var ai_id: String = str(_world_data_manager.get_disciples_by_sect_id("sect_002")[0]["disciple_id"])
	var battle: Dictionary = root.get_node("BattleManager").create_battle("sect_001", ["disciple_001"], "sect_002", [ai_id], {"seed": 1})
	_expect(int(battle.get("battle", {}).get("attacker_units", [])[0].get("attack", 0)) == base_attack + 18, "玄铁剑应在战斗快照中增加18攻击。")

	_inventory_manager.add_item("sect_001", "healing_pill", 1)
	_world_data_manager.update_disciple_data("disciple_011", "health", 40)
	root.get_node("DiscipleManager").load_from_world_data()
	var heal: Dictionary = _crafting_manager.use_consumable("sect_001", "disciple_011", "healing_pill")
	_expect(bool(heal.get("success", false)) and int(_world_data_manager.get_disciple_by_id("disciple_011")["health"]) == 65, "回春丹应消耗一枚并恢复25健康。")
	_inventory_manager.add_item("sect_001", "qi_gathering_pill", 1)
	var cultivation_before: int = int(_world_data_manager.get_disciple_by_id("disciple_001")["cultivation"])
	var cultivate: Dictionary = _crafting_manager.use_consumable("sect_001", "disciple_001", "qi_gathering_pill")
	_expect(bool(cultivate.get("success", false)) and int(_world_data_manager.get_disciple_by_id("disciple_001")["cultivation"]) >= cultivation_before, "聚气丹应通过统一修炼数据增加修为。")


func _test_active_job_save_restore() -> void:
	_game_state.new_game()
	_add_building("alchemy_room", 1)
	var started: Dictionary = _crafting_manager.start_crafting("sect_001", "recipe_qi_gathering_pill", "disciple_006", {"seed": 300, "_test_roll": 0.0})
	var job_id: String = str(started.get("job", {}).get("job_id", ""))
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.crafting_jobs.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "进行中的制作任务应可存档恢复。")
	_expect(_crafting_manager.get_jobs("sect_001", true).size() == 1 and str(_crafting_manager.get_jobs("sect_001", true)[0].get("job_id", "")) == job_id, "读档后制作进度不得丢失。")
	_expect(bool(_world_data_manager.get_disciple_by_id("disciple_006").get("is_deployed", false)), "读档后制作弟子占用状态应重建。")


func _test_crafting_ui() -> void:
	_game_state.new_game()
	_add_building("alchemy_room", 1)
	var overview: Control = (load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene).instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_inventory_button_pressed")
	var recipe_list: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/InventorySection/RecipePanel/RecipeScroll/RecipeList")
	var craft_button: Button = null
	for child in recipe_list.get_children():
		if child is Button and child.text.contains("聚气丹"):
			craft_button = child
			break
	_expect(craft_button != null and not craft_button.disabled, "材料、建筑和弟子满足时聚气丹按钮应可用。")
	craft_button.pressed.emit()
	await process_frame
	_expect(_crafting_manager.get_jobs("sect_001", true).size() == 1, "配方按钮应启动真实制作任务。")
	_expect(recipe_list.get_child_count() == 7, "制作中任务应追加在配方列表下方。")
	overview.queue_free()
	await process_frame


func _add_building(building_id: String, level: int) -> void:
	_world_data_manager.building_instances.append({"instance_id": "test_" + building_id, "definition_id": building_id, "sect_id": "sect_001", "level": level, "target_level": level, "status": "active", "remaining_days": 0, "build_slot_id": 0, "started_date": {}, "completed_date": {}, "operational": true, "maintenance_shortages": {}})


func _date(day: int) -> Dictionary:
	return {"year": 1, "month": 1, "day": day}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
