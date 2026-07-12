extends Node

signal crafting_started(job_data: Dictionary)
signal crafting_completed(result: Dictionary)

var _next_job_number: int = 1


func rebuild_runtime_state() -> void:
	_next_job_number = 1
	for job_data in WorldDataManager.crafting_jobs:
		var job := CraftingJobData.from_dictionary(job_data)
		var number_text: String = job.job_id.trim_prefix("craft_job_")
		if number_text.is_valid_int():
			_next_job_number = maxi(_next_job_number, number_text.to_int() + 1)
		if job.status == "crafting":
			_set_worker_deployed(job.disciple_id, job.job_id, true)


func start_crafting(sect_id: String, recipe_id: String, disciple_id: String, options: Dictionary = {}) -> Dictionary:
	var recipe: RecipeDefinition = RecipeRegistry.get_by_id(recipe_id)
	if recipe == null:
		return _error("recipe_not_found", "配方不存在。")
	var worker: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
	if worker.is_empty() or str(worker.get("sect_id", "")) != sect_id or bool(worker.get("is_deployed", false)):
		return _error("worker_unavailable", "负责弟子当前不可用。")
	for required_tag in recipe.required_disciple_tags:
		if required_tag not in worker.get("tags", []):
			return _error("worker_skill", "负责弟子缺少必要标签：" + required_tag)
	var building_level: int = _get_operational_building_level(sect_id, recipe.required_building_id)
	if building_level < recipe.required_building_level:
		return _error("building_requirement", "缺少符合等级要求的制作建筑。")
	if not InventoryManager.consume_items(sect_id, recipe.ingredients):
		return _error("ingredients_insufficient", "制作材料不足。")
	var job := CraftingJobData.new()
	job.job_id = "craft_job_%05d" % _next_job_number
	_next_job_number += 1
	job.sect_id = sect_id
	job.recipe_id = recipe_id
	job.disciple_id = disciple_id
	job.remaining_days = maxi(1, recipe.duration_days)
	job.success_chance = clampf(recipe.base_success_rate + float(worker.get("talent", worker.get("comprehension", 50))) / 500.0 + float(building_level - recipe.required_building_level) * 0.03, 0.05, 0.98)
	job.seed = int(options.get("seed", GameState.random_int(1, 2147483646)))
	if OS.is_debug_build() and options.has("_test_roll"):
		job.test_roll = clampf(float(options["_test_roll"]), 0.0, 1.0)
	job.started_date = _current_date()
	job.consumed_items = recipe.ingredients.duplicate(true)
	WorldDataManager.crafting_jobs.append(job.to_dictionary())
	_set_worker_deployed(disciple_id, job.job_id, true)
	crafting_started.emit(job.to_dictionary())
	return {"success": true, "message": "%s已开始，预计%d日完成。" % [recipe.display_name, job.remaining_days], "job": job.to_dictionary()}


func daily_update(date: Dictionary) -> Dictionary:
	var progressed: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	for index in range(WorldDataManager.crafting_jobs.size()):
		var job := CraftingJobData.from_dictionary(WorldDataManager.crafting_jobs[index])
		if job.status != "crafting":
			continue
		job.remaining_days = maxi(0, job.remaining_days - 1)
		if job.remaining_days == 0:
			completed.append(_complete_job(job, date))
		WorldDataManager.crafting_jobs[index] = job.to_dictionary()
		progressed.append(job.to_dictionary())
	return {"progressed": progressed, "completed": completed}


func get_jobs(sect_id: String, active_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in WorldDataManager.crafting_jobs:
		if str(job.get("sect_id", "")) != sect_id:
			continue
		if active_only and str(job.get("status", "")) != "crafting":
			continue
		result.append(job.duplicate(true))
	return result


func use_consumable(sect_id: String, disciple_id: String, item_id: String) -> Dictionary:
	var definition: ItemDefinition = ItemRegistry.get_by_id(item_id)
	var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
	if definition == null or definition.category != "consumable" or disciple == null or disciple.sect_id != sect_id:
		return _error("item_invalid", "物品或使用目标无效。")
	if not InventoryManager.remove_item(sect_id, item_id, 1):
		return _error("item_missing", "背包中没有该物品。")
	var applied: Array[Dictionary] = []
	for effect in definition.effects:
		var effect_type: String = str(effect.get("type", ""))
		var amount: int = int(effect.get("amount", 0))
		if effect_type == "health":
			var before: int = disciple.health
			disciple.health = clampi(disciple.health + amount, 1, 100)
			applied.append({"type": effect_type, "before": before, "after": disciple.health})
		elif effect_type == "cultivation":
			var realm: RealmDefinition = RealmRegistry.get_by_id(disciple.realm_id)
			var gained: int = disciple.cultivate(amount, realm)
			applied.append({"type": effect_type, "amount": gained})
	DiscipleManager.sync_disciple_state(disciple)
	return {"success": true, "item_id": item_id, "disciple_id": disciple_id, "effects": applied}


func equip_item(sect_id: String, disciple_id: String, item_id: String) -> Dictionary:
	var definition: ItemDefinition = ItemRegistry.get_by_id(item_id)
	var disciple_data: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
	if definition == null or definition.category != "equipment" or disciple_data.is_empty() or str(disciple_data.get("sect_id", "")) != sect_id:
		return _error("equipment_invalid", "装备或弟子无效。")
	if not InventoryManager.remove_item(sect_id, item_id, 1):
		return _error("item_missing", "背包中没有该装备。")
	var equipment: Dictionary = disciple_data.get("equipment", {}).duplicate(true)
	var old_item_id: String = str(equipment.get(definition.equipment_slot, ""))
	if old_item_id != "" and not InventoryManager.add_item(sect_id, old_item_id, 1):
		InventoryManager.add_item(sect_id, item_id, 1)
		return _error("inventory_full", "无法卸下原装备。")
	equipment[definition.equipment_slot] = item_id
	WorldDataManager.update_disciple_data(disciple_id, "equipment", equipment)
	return {"success": true, "disciple_id": disciple_id, "slot": definition.equipment_slot, "item_id": item_id, "replaced_item_id": old_item_id}


func unequip_item(sect_id: String, disciple_id: String, slot: String) -> bool:
	var disciple_data: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
	var equipment: Dictionary = disciple_data.get("equipment", {}).duplicate(true)
	var item_id: String = str(equipment.get(slot, ""))
	if item_id == "" or not InventoryManager.add_item(sect_id, item_id, 1):
		return false
	equipment.erase(slot)
	return WorldDataManager.update_disciple_data(disciple_id, "equipment", equipment)


func _complete_job(job: CraftingJobData, date: Dictionary) -> Dictionary:
	var recipe: RecipeDefinition = RecipeRegistry.get_by_id(job.recipe_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = job.seed
	var roll: float = job.test_roll if job.test_roll >= 0.0 else rng.randf()
	var succeeded: bool = recipe != null and roll <= job.success_chance
	var outputs: Dictionary = {}
	var refunds: Dictionary = {}
	if succeeded:
		if InventoryManager.add_items(job.sect_id, recipe.outputs):
			outputs = recipe.outputs.duplicate(true)
		else:
			succeeded = false
	if not succeeded:
		for item_id in job.consumed_items:
			var refund: int = int(job.consumed_items[item_id]) / 4
			if refund > 0:
				InventoryManager.add_item(job.sect_id, str(item_id), refund)
				refunds[item_id] = refund
	job.status = "completed"
	job.completed_date = date.duplicate(true)
	job.result = {"success": true, "crafted": succeeded, "job_id": job.job_id, "recipe_id": job.recipe_id, "disciple_id": job.disciple_id, "roll": roll, "success_chance": job.success_chance, "outputs": outputs, "refunds": refunds}
	_set_worker_deployed(job.disciple_id, job.job_id, false)
	GameHistoryManager.record_entry("crafting", "制作完成", "%s%s。" % [recipe.display_name if recipe != null else job.recipe_id, "制作成功" if succeeded else "制作失败"], [job.sect_id, job.disciple_id, job.job_id], job.result, date)
	crafting_completed.emit(job.result)
	return job.result


func _get_operational_building_level(sect_id: String, building_id: String) -> int:
	if building_id == "":
		return 1
	var level: int = 0
	for building in ConstructionManager.get_buildings_by_sect_id(sect_id):
		if str(building.get("definition_id", "")) == building_id and str(building.get("status", "")) == "active" and bool(building.get("operational", false)):
			level = maxi(level, int(building.get("level", 1)))
	return level


func _set_worker_deployed(disciple_id: String, job_id: String, deployed: bool) -> void:
	var disciple: DiscipleData = DiscipleManager.get_disciple_by_id(disciple_id)
	if disciple == null:
		return
	if not deployed and disciple.team_id != job_id:
		return
	disciple.is_deployed = deployed
	disciple.team_id = job_id if deployed else ""
	DiscipleManager.sync_disciple_state(disciple)


func _current_date() -> Dictionary:
	return {"year": GameState.year, "month": GameState.month, "day": GameState.day}


func _error(code: String, message: String) -> Dictionary:
	return {"success": false, "code": code, "message": message}
