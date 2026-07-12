extends Node

signal inventory_changed(sect_id: String, item_id: String, amount_after: int)


func initialize_world_state() -> void:
	for sect in WorldDataManager.get_all_sects():
		var sect_id: String = str(sect.get("sect_id", ""))
		if not WorldDataManager.sect_inventories.has(sect_id):
			WorldDataManager.sect_inventories[sect_id] = {}


func rebuild_runtime_state() -> void:
	initialize_world_state()
	for sect_id in WorldDataManager.sect_inventories:
		var inventory: Dictionary = WorldDataManager.sect_inventories[sect_id]
		var sanitized: Dictionary = {}
		for item_id in inventory:
			var definition: ItemDefinition = ItemRegistry.get_by_id(str(item_id))
			if definition == null or definition.resource_key != "":
				continue
			sanitized[item_id] = clampi(int(inventory[item_id]), 0, definition.stack_limit)
		WorldDataManager.sect_inventories[sect_id] = sanitized


func get_item_count(sect_id: String, item_id: String) -> int:
	var definition: ItemDefinition = ItemRegistry.get_by_id(item_id)
	if definition == null:
		return 0
	if definition.resource_key != "":
		return int(WorldDataManager.get_sect_resources(sect_id).get(definition.resource_key, 0))
	return int(WorldDataManager.sect_inventories.get(sect_id, {}).get(item_id, 0))


func get_inventory(sect_id: String, include_zero: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for definition in ItemRegistry.get_all():
		var count: int = get_item_count(sect_id, definition.id)
		if include_zero or count > 0:
			result[definition.id] = count
	return result


func add_item(sect_id: String, item_id: String, amount: int) -> bool:
	if amount < 0:
		return remove_item(sect_id, item_id, -amount)
	if amount == 0:
		return true
	var definition: ItemDefinition = ItemRegistry.get_by_id(item_id)
	if definition == null or WorldDataManager.get_sect_by_id(sect_id).is_empty():
		return false
	if definition.resource_key != "":
		var success: bool = WorldDataManager.update_sect_resource(sect_id, definition.resource_key, amount)
		if success: inventory_changed.emit(sect_id, item_id, get_item_count(sect_id, item_id))
		return success
	var inventory: Dictionary = WorldDataManager.sect_inventories.get(sect_id, {})
	var current: int = int(inventory.get(item_id, 0))
	if current + amount > definition.stack_limit:
		return false
	inventory[item_id] = current + amount
	WorldDataManager.sect_inventories[sect_id] = inventory
	inventory_changed.emit(sect_id, item_id, current + amount)
	return true


func remove_item(sect_id: String, item_id: String, amount: int) -> bool:
	if amount <= 0 or get_item_count(sect_id, item_id) < amount:
		return false
	var definition: ItemDefinition = ItemRegistry.get_by_id(item_id)
	if definition == null:
		return false
	if definition.resource_key != "":
		var success: bool = WorldDataManager.update_sect_resource(sect_id, definition.resource_key, -amount)
		if success: inventory_changed.emit(sect_id, item_id, get_item_count(sect_id, item_id))
		return success
	var inventory: Dictionary = WorldDataManager.sect_inventories.get(sect_id, {})
	inventory[item_id] = int(inventory.get(item_id, 0)) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	WorldDataManager.sect_inventories[sect_id] = inventory
	inventory_changed.emit(sect_id, item_id, get_item_count(sect_id, item_id))
	return true


func has_items(sect_id: String, requirements: Dictionary) -> bool:
	for item_id in requirements:
		if get_item_count(sect_id, str(item_id)) < int(requirements[item_id]):
			return false
	return true


func consume_items(sect_id: String, requirements: Dictionary) -> bool:
	if not has_items(sect_id, requirements):
		return false
	var consumed: Dictionary = {}
	for item_id in requirements:
		var amount: int = int(requirements[item_id])
		if not remove_item(sect_id, str(item_id), amount):
			for rollback_id in consumed:
				add_item(sect_id, str(rollback_id), int(consumed[rollback_id]))
			return false
		consumed[item_id] = amount
	return true


func add_items(sect_id: String, items: Dictionary) -> bool:
	var added: Dictionary = {}
	for item_id in items:
		var amount: int = int(items[item_id])
		if not add_item(sect_id, str(item_id), amount):
			for rollback_id in added:
				remove_item(sect_id, str(rollback_id), int(added[rollback_id]))
			return false
		added[item_id] = amount
	return true


func transfer_item(from_sect_id: String, to_sect_id: String, item_id: String, amount: int) -> bool:
	if amount <= 0 or not remove_item(from_sect_id, item_id, amount):
		return false
	if add_item(to_sect_id, item_id, amount):
		return true
	add_item(from_sect_id, item_id, amount)
	return false
