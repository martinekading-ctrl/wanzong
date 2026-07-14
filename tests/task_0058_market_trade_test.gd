extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")

var _failures := PackedStringArray()
var _game_state: Node
var _world_data_manager: Node
var _market_manager: Node
var _inventory_manager: Node
var _diplomacy_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_state = root.get_node("GameState")
	_world_data_manager = root.get_node("WorldDataManager")
	_market_manager = root.get_node("MarketManager")
	_inventory_manager = root.get_node("InventoryManager")
	_diplomacy_manager = root.get_node("DiplomacyManager")
	_test_market_catalog_and_dynamic_prices()
	_test_buy_sell_feedback_and_diplomatic_block()
	_test_monthly_update_and_save_restore()
	await _test_market_ui()
	if _failures.is_empty():
		print("[Task0058Test] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0058Test] " + failure)
	quit(1)


func _test_market_catalog_and_dynamic_prices() -> void:
	_game_state.new_game()
	_expect(_market_manager.get_markets().size() == WorldSectRoster.expected_ai_sect_count(), "全部AI宗门应各自拥有区域市场。")
	var market_id: String = "market_sect_002"
	var base_price: int = _market_manager.get_price(market_id, "sect_001", "healing_pill", true)
	_expect(base_price > 0, "市场物品应产生正数价格。")
	var state: Dictionary = _world_data_manager.market_states[market_id]
	state["stock"]["healing_pill"] = 1
	_world_data_manager.market_states[market_id] = state
	var scarce_price: int = _market_manager.get_price(market_id, "sect_001", "healing_pill", true)
	_expect(scarce_price > base_price, "库存稀缺应提高价格。")
	_market_manager.set_event_modifier(market_id, "healing_pill", 2.0)
	var event_price: int = _market_manager.get_price(market_id, "sect_001", "healing_pill", true)
	_expect(event_price > scarce_price, "事件价格修正应参与最终价格。")
	_diplomacy_manager.change_relation_value("sect_001", "sect_002", 60, "贸易友好")
	var friendly_price: int = _market_manager.get_price(market_id, "sect_001", "healing_pill", true)
	_expect(friendly_price < event_price, "友好关系应降低购买价格。")
	_expect(_market_manager.get_price(market_id, "sect_001", "healing_pill", false) < friendly_price, "市场收购价应低于卖出价。")


func _test_buy_sell_feedback_and_diplomatic_block() -> void:
	_game_state.new_game()
	var market_id: String = "market_sect_002"
	var player_stone: int = _inventory_manager.get_item_count("sect_001", "spirit_stone")
	var owner_stone: int = _inventory_manager.get_item_count("sect_002", "spirit_stone")
	var stock_before: int = int(_market_manager.get_market(market_id)["stock"]["healing_pill"])
	var demand_before: float = float(_market_manager.get_market(market_id)["demand"]["healing_pill"])
	var buy: Dictionary = _market_manager.buy_item(market_id, "sect_001", "healing_pill", 2)
	_expect(bool(buy.get("success", false)), "资源充足时应可购买物品。")
	_expect(_inventory_manager.get_item_count("sect_001", "healing_pill") == 2, "购买物品应进入玩家背包。")
	_expect(_inventory_manager.get_item_count("sect_001", "spirit_stone") == player_stone - int(buy.get("total_price", 0)), "购买应扣除真实灵石。")
	_expect(_inventory_manager.get_item_count("sect_002", "spirit_stone") == owner_stone + int(buy.get("total_price", 0)), "市场所属宗门应收到货款。")
	var after_buy: Dictionary = _market_manager.get_market(market_id)
	_expect(int(after_buy["stock"]["healing_pill"]) == stock_before - 2 and float(after_buy["demand"]["healing_pill"]) > demand_before, "购买应降低库存并提高需求。")
	var sell: Dictionary = _market_manager.sell_item(market_id, "sect_001", "healing_pill", 1)
	_expect(bool(sell.get("success", false)) and _inventory_manager.get_item_count("sect_001", "healing_pill") == 1, "玩家应可向市场出售持有物品。")
	_expect(_world_data_manager.market_transactions.size() == 2, "买卖都应写入交易历史。")
	_expect(root.get_node("GameHistoryManager").get_entries_by_category("market").size() == 2, "交易应写入全局历史。")
	_diplomacy_manager.declare_war("sect_001", "sect_002", "trade_block_test")
	var blocked: Dictionary = _market_manager.buy_item(market_id, "sect_001", "food", 1)
	_expect(str(blocked.get("code", "")) == "trade_blocked", "战争状态必须禁止双方市场交易。")


func _test_monthly_update_and_save_restore() -> void:
	_game_state.new_game()
	var market_id: String = "market_sect_003"
	var state: Dictionary = _world_data_manager.market_states[market_id]
	state["demand"]["spirit_ore"] = 1.8
	state["event_modifiers"]["spirit_ore"] = 2.0
	_world_data_manager.market_states[market_id] = state
	var report: Dictionary = _market_manager.daily_update({"year": 1, "month": 1, "day": 30})
	var updated: Dictionary = _market_manager.get_market(market_id)
	_expect(int(report.get("markets_updated", 0)) == WorldSectRoster.expected_ai_sect_count(), "月末应刷新全部市场。")
	_expect(float(updated["demand"]["spirit_ore"]) < 1.8 and float(updated["event_modifiers"]["spirit_ore"]) < 2.0, "需求与事件修正应逐月回归常态。")
	var snapshot: Dictionary = root.get_node("SaveManager").create_snapshot()
	_world_data_manager.market_states.clear()
	_expect(root.get_node("SaveManager").apply_snapshot(snapshot), "市场状态和交易历史应可存档恢复。")
	_expect(_market_manager.get_markets().size() == WorldSectRoster.expected_ai_sect_count() and _market_manager.get_market(market_id).has("stock"), "读档后市场库存不得丢失。")


func _test_market_ui() -> void:
	_game_state.new_game()
	var overview: Control = (load("res://scenes/sect/PlayerSectOverview.tscn") as PackedScene).instantiate()
	root.add_child(overview)
	await process_frame
	overview.call("_on_market_button_pressed")
	await process_frame
	var section: VBoxContainer = overview.get_node("MarginContainer/RootBox/FunctionPanel/FunctionBox/MarketSection")
	var option: OptionButton = section.get_node("ControlBox/MarketOption")
	var list: VBoxContainer = section.get_node("ItemScroll/ItemList")
	_expect(section.visible and option.item_count == WorldSectRoster.expected_ai_sect_count(), "市场界面应展示全部区域市场。")
	_expect(list.get_child_count() == 11, "市场应显示标题和10种非灵石商品。")
	var first_row: HBoxContainer = list.get_child(1)
	_expect(first_row.get_child_count() == 3, "每种商品应包含价格信息、购买和出售按钮。")
	overview.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
