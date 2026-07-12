extends SceneTree

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _inventory_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_inventory_manager = root.get_node("InventoryManager")
	_test_registries_and_unique_resource_source()
	_test_inventory_transactions_transfer_and_limits()
	_test_save_restore()
	await _test_inventory_ui()
	if _failures.is_empty():
		print("[Task0056Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0056Test] " + failure)
	quit(1)


func _test_registries_and_unique_resource_source() -> void:
	_game_state.new_game()
	_expect(ItemRegistry.get_all().size() == 11, "第一批应加载11种物品。")
	_expect(ItemRegistry.validate().is_empty(), "物品配置校验应通过。")
	_expect(RecipeRegistry.get_all().size() == 5, "第一批应加载5张配方。")
	_expect(RecipeRegistry.validate().is_empty(), "配方引用的物品必须全部有效。")
	_expect(_world_data_manager.sect_inventories.size() == 10, "十个宗门都应拥有独立背包容器。")
	var grass_before: int = int(_world_data_manager.get_sect_resources("sect_001")["spirit_grass"])
	_expect(_inventory_manager.get_item_count("sect_001", "spirit_grass") == grass_before, "基础灵草物品必须读取sect_resources。")
	_expect(_inventory_manager.add_item("sect_001", "spirit_grass", 7), "基础资源应可通过统一背包接口增加。")
	_expect(int(_world_data_manager.get_sect_resources("sect_001")["spirit_grass"]) == grass_before + 7, "增加灵草必须写回唯一资源仓库。")
	_expect(not _world_data_manager.sect_inventories["sect_001"].has("spirit_grass"), "基础经济资源不得在背包字典重复保存。")


func _test_inventory_transactions_transfer_and_limits() -> void:
	_game_state.new_game()
	_expect(_inventory_manager.add_item("sect_001", "healing_pill", 5), "非经济物品应进入背包。")
	_expect(_inventory_manager.get_item_count("sect_001", "healing_pill") == 5, "丹药数量应可读取。")
	_expect(_inventory_manager.remove_item("sect_001", "healing_pill", 2), "丹药应可移除。")
	_expect(_inventory_manager.get_item_count("sect_001", "healing_pill") == 3, "移除后数量应同步。")
	var resources_before: Dictionary = _world_data_manager.get_sect_resources("sect_001")
	var missing_recipe: Dictionary = {"spirit_grass": 999999, "spirit_stone": 10}
	_expect(not _inventory_manager.consume_items("sect_001", missing_recipe), "材料不足时事务性消耗必须失败。")
	_expect(_world_data_manager.get_sect_resources("sect_001") == resources_before, "事务失败不得部分扣除材料。")
	var recipe: RecipeDefinition = RecipeRegistry.get_by_id("recipe_qi_gathering_pill")
	_expect(_inventory_manager.has_items("sect_001", recipe.ingredients), "初始资源应满足基础聚气丹配方。")
	_expect(_inventory_manager.consume_items("sect_001", recipe.ingredients), "配方材料应可事务性扣除。")
	_expect(_inventory_manager.add_items("sect_001", recipe.outputs), "配方产物应可事务性加入。")
	_expect(_inventory_manager.get_item_count("sect_001", "qi_gathering_pill") == 1, "聚气丹产物应进入背包。")
	_expect(_inventory_manager.transfer_item("sect_001", "sect_002", "qi_gathering_pill", 1), "物品应可在宗门之间转移。")
	_expect(_inventory_manager.get_item_count("sect_001", "qi_gathering_pill") == 0 and _inventory_manager.get_item_count("sect_002", "qi_gathering_pill") == 1, "跨宗门转移应保持总量。")
	_expect(not _inventory_manager.add_item("sect_001", "formation_core", 100), "超过堆叠上限时应拒绝整笔加入。")
	_expect(not _inventory_manager.add_item("sect_001", "unknown_item", 1), "未知物品不得进入背包。")


func _test_save_restore() -> void:
	_game_state.new_game()
	_inventory_manager.add_item("sect_001", "iron_sword", 2)
	_inventory_manager.add_item("sect_001", "healing_pill", 4)
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.sect_inventories.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "宗门背包应可存档恢复。")
	_expect(_inventory_manager.get_item_count("sect_001", "iron_sword") == 2 and _inventory_manager.get_item_count("sect_001", "healing_pill") == 4, "读档后装备和丹药数量不得丢失。")
	_expect(_world_data_manager.sect_inventories.size() == 10, "旧档或缺失宗门背包应在恢复时补全。")


func _test_inventory_ui() -> void:
	_game_state.new_game()
	var overview: Control = (load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene).instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_inventory_button_pressed")
	await process_frame
	var section: HBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/InventorySection")
	var item_list: VBoxContainer = section.get_node("ItemPanel/ItemScroll/ItemList")
	var recipe_list: VBoxContainer = section.get_node("RecipePanel/RecipeScroll/RecipeList")
	_expect(section.visible, "点击背包按钮应显示宗门物品与配方。")
	_expect(item_list.get_child_count() == 12, "物品列表应显示标题和11种物品。")
	_expect(recipe_list.get_child_count() == 6, "配方列表应显示标题和5张配方。")
	overview.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
