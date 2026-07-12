extends Node

signal transaction_completed(transaction: Dictionary)

const MAX_TRANSACTION_HISTORY: int = 500


func initialize_world_state() -> void:
	if not WorldDataManager.market_states.is_empty():
		return
	for sect in WorldDataManager.get_ai_sects():
		var market_id: String = "market_" + str(sect.get("sect_id", ""))
		var stock: Dictionary = {}
		var demand: Dictionary = {}
		for item in ItemRegistry.get_all():
			if item.id == "spirit_stone":
				continue
			stock[item.id] = _initial_stock(item)
			demand[item.id] = 0.9 + float(abs((market_id + item.id).hash()) % 31) / 100.0
		WorldDataManager.market_states[market_id] = {
			"market_id": market_id,
			"owner_sect_id": str(sect.get("sect_id", "")),
			"region": _region_for_sect_type(str(sect.get("sect_type", ""))),
			"stock": stock,
			"demand": demand,
			"event_modifiers": {},
			"trade_volume": 0,
			"last_update_date": {},
		}


func rebuild_runtime_state() -> void:
	initialize_world_state()
	for market_id in WorldDataManager.market_states:
		var state: Dictionary = WorldDataManager.market_states[market_id]
		state["stock"] = state.get("stock", {}).duplicate(true)
		state["demand"] = state.get("demand", {}).duplicate(true)
		state["event_modifiers"] = state.get("event_modifiers", {}).duplicate(true)
		WorldDataManager.market_states[market_id] = state


func daily_update(date: Dictionary) -> Dictionary:
	if int(date.get("day", 0)) != 30:
		return {"markets_updated": 0, "transactions": 0}
	for market_id in WorldDataManager.market_states:
		var state: Dictionary = WorldDataManager.market_states[market_id]
		var demand: Dictionary = state.get("demand", {})
		for item_id in demand:
			demand[item_id] = lerpf(float(demand[item_id]), 1.0, 0.25)
		var modifiers: Dictionary = state.get("event_modifiers", {})
		for item_id in modifiers:
			modifiers[item_id] = lerpf(float(modifiers[item_id]), 1.0, 0.5)
		state["demand"] = demand
		state["event_modifiers"] = modifiers
		state["last_update_date"] = date.duplicate(true)
		WorldDataManager.market_states[market_id] = state
	return {"markets_updated": WorldDataManager.market_states.size(), "transactions": WorldDataManager.market_transactions.size()}


func get_markets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in WorldDataManager.market_states.values(): result.append(state.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("market_id", "")) < str(b.get("market_id", "")))
	return result


func get_market(market_id: String) -> Dictionary:
	return WorldDataManager.market_states.get(market_id, {}).duplicate(true)


func get_price(market_id: String, trader_sect_id: String, item_id: String, is_buying: bool = true) -> int:
	var market: Dictionary = get_market(market_id)
	var item: ItemDefinition = ItemRegistry.get_by_id(item_id)
	if market.is_empty() or item == null or item_id == "spirit_stone":
		return 0
	var stock: int = int(market.get("stock", {}).get(item_id, 0))
	var scarcity: float = clampf(1.5 - float(stock) / 200.0, 0.55, 1.6)
	var demand: float = clampf(float(market.get("demand", {}).get(item_id, 1.0)), 0.5, 2.0)
	var event_modifier: float = clampf(float(market.get("event_modifiers", {}).get(item_id, 1.0)), 0.5, 3.0)
	var region_modifier: float = _region_modifier(str(market.get("region", "central")), item.category)
	var owner_id: String = str(market.get("owner_sect_id", ""))
	var relation: Dictionary = DiplomacyManager.get_relation(trader_sect_id, owner_id)
	var relation_modifier: float = clampf(1.0 - float(relation.get("value", 0)) * 0.002, 0.75, 1.25)
	if str(relation.get("status", "")) == "alliance": relation_modifier *= 0.9
	var buy_price: int = maxi(1, roundi(float(item.base_value) * scarcity * demand * event_modifier * region_modifier * relation_modifier))
	return buy_price if is_buying else maxi(1, roundi(float(buy_price) * 0.65))


func buy_item(market_id: String, buyer_sect_id: String, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return _error("quantity_invalid", "交易数量无效。")
	var market: Dictionary = get_market(market_id)
	if market.is_empty() or not _can_trade(buyer_sect_id, str(market.get("owner_sect_id", ""))):
		return _error("trade_blocked", "当前外交状态不允许交易。")
	if int(market.get("stock", {}).get(item_id, 0)) < quantity:
		return _error("stock_insufficient", "市场库存不足。")
	var unit_price: int = get_price(market_id, buyer_sect_id, item_id, true)
	var total: int = unit_price * quantity
	if InventoryManager.get_item_count(buyer_sect_id, "spirit_stone") < total:
		return _error("funds_insufficient", "宗门灵石不足。")
	var owner_id: String = str(market.get("owner_sect_id", ""))
	if not InventoryManager.remove_item(buyer_sect_id, "spirit_stone", total):
		return _error("inventory_update", "交易物品写入失败。")
	if not InventoryManager.add_item(buyer_sect_id, item_id, quantity):
		InventoryManager.add_item(buyer_sect_id, "spirit_stone", total)
		return _error("inventory_update", "交易物品写入失败。")
	InventoryManager.add_item(owner_id, "spirit_stone", total)
	_update_market_after_trade(market_id, item_id, -quantity, quantity)
	return _record_transaction("buy", market_id, buyer_sect_id, owner_id, item_id, quantity, unit_price)


func sell_item(market_id: String, seller_sect_id: String, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0 or InventoryManager.get_item_count(seller_sect_id, item_id) < quantity:
		return _error("items_insufficient", "出售物品不足。")
	var market: Dictionary = get_market(market_id)
	var owner_id: String = str(market.get("owner_sect_id", ""))
	if market.is_empty() or not _can_trade(seller_sect_id, owner_id):
		return _error("trade_blocked", "当前外交状态不允许交易。")
	var unit_price: int = get_price(market_id, seller_sect_id, item_id, false)
	var total: int = unit_price * quantity
	if InventoryManager.get_item_count(owner_id, "spirit_stone") < total:
		return _error("market_funds", "市场所属宗门无力收购。")
	if not InventoryManager.remove_item(seller_sect_id, item_id, quantity):
		return _error("inventory_update", "出售扣除失败。")
	InventoryManager.remove_item(owner_id, "spirit_stone", total)
	InventoryManager.add_item(seller_sect_id, "spirit_stone", total)
	_update_market_after_trade(market_id, item_id, quantity, -quantity)
	return _record_transaction("sell", market_id, seller_sect_id, owner_id, item_id, quantity, unit_price)


func set_event_modifier(market_id: String, item_id: String, multiplier: float) -> bool:
	if not WorldDataManager.market_states.has(market_id) or ItemRegistry.get_by_id(item_id) == null:
		return false
	var state: Dictionary = WorldDataManager.market_states[market_id]
	var modifiers: Dictionary = state.get("event_modifiers", {})
	modifiers[item_id] = clampf(multiplier, 0.5, 3.0)
	state["event_modifiers"] = modifiers
	WorldDataManager.market_states[market_id] = state
	return true


func _update_market_after_trade(market_id: String, item_id: String, stock_delta: int, demand_delta: int) -> void:
	var state: Dictionary = WorldDataManager.market_states[market_id]
	var stock: Dictionary = state.get("stock", {})
	var demand: Dictionary = state.get("demand", {})
	stock[item_id] = maxi(0, int(stock.get(item_id, 0)) + stock_delta)
	demand[item_id] = clampf(float(demand.get(item_id, 1.0)) + float(demand_delta) * 0.01, 0.5, 2.0)
	state["stock"] = stock
	state["demand"] = demand
	state["trade_volume"] = int(state.get("trade_volume", 0)) + abs(stock_delta)
	WorldDataManager.market_states[market_id] = state


func _record_transaction(action: String, market_id: String, trader_id: String, owner_id: String, item_id: String, quantity: int, unit_price: int) -> Dictionary:
	var transaction: Dictionary = {"transaction_id": "trade_%06d" % (WorldDataManager.market_transactions.size() + 1), "action": action, "market_id": market_id, "trader_sect_id": trader_id, "market_owner_sect_id": owner_id, "item_id": item_id, "quantity": quantity, "unit_price": unit_price, "total_price": quantity * unit_price, "date": _current_date()}
	WorldDataManager.market_transactions.append(transaction)
	if WorldDataManager.market_transactions.size() > MAX_TRANSACTION_HISTORY:
		WorldDataManager.market_transactions.pop_front()
	GameHistoryManager.record_entry("market", "市场交易", "%s%s%s×%d。" % [str(WorldDataManager.get_sect_by_id(trader_id).get("sect_name", trader_id)), "购入" if action == "buy" else "出售", str(ItemRegistry.get_by_id(item_id).display_name), quantity], [trader_id, owner_id, market_id], transaction)
	transaction_completed.emit(transaction)
	var result: Dictionary = transaction.duplicate(true)
	result["success"] = true
	result["message"] = "交易完成。"
	return result


func _can_trade(left_id: String, right_id: String) -> bool:
	return str(DiplomacyManager.get_relation(left_id, right_id).get("status", "neutral")) not in ["war", "hostile"]


func _initial_stock(item: ItemDefinition) -> int:
	match item.category:
		"material": return 150
		"consumable": return 20
		"equipment": return 8
		_: return 5


func _region_for_sect_type(sect_type: String) -> String:
	return {"desert": "desert", "snow": "snow", "ocean": "coast", "alchemy": "herbal", "sword": "mountain"}.get(sect_type, "central")


func _region_modifier(region: String, category: String) -> float:
	if region == "herbal" and category in ["material", "consumable"]: return 0.85
	if region == "mountain" and category in ["material", "equipment"]: return 0.9
	if region in ["desert", "snow"] and category == "consumable": return 1.15
	return 1.0


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
