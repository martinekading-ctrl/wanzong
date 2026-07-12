extends Node

signal history_entry_added(entry: Dictionary)

const MAX_HISTORY_ENTRIES: int = 1000

var _next_history_number: int = 1


func reset() -> void:
	WorldDataManager.history_entries.clear()
	_next_history_number = 1


func record_entry(
	category: String,
	title: String,
	message: String,
	entity_ids: Array = [],
	data: Dictionary = {},
	date: Dictionary = {}
) -> Dictionary:
	var entry_date: Dictionary = date.duplicate(true)
	if entry_date.is_empty():
		entry_date = {"year": GameState.year, "month": GameState.month, "day": GameState.day}
	var normalized_entity_ids: Array[String] = []
	for entity_id in entity_ids:
		normalized_entity_ids.append(str(entity_id))
	var entry: Dictionary = {
		"history_id": "history_%06d" % _next_history_number,
		"year": int(entry_date.get("year", 1)),
		"month": int(entry_date.get("month", 1)),
		"day": int(entry_date.get("day", 1)),
		"category": category,
		"title": title,
		"message": message,
		"entity_ids": normalized_entity_ids,
		"data": data.duplicate(true),
	}
	_next_history_number += 1
	WorldDataManager.history_entries.append(entry)
	_trim_to_memory_budget()
	history_entry_added.emit(entry.duplicate(true))
	return entry


func get_all_entries() -> Array[Dictionary]:
	return WorldDataManager.history_entries.duplicate(true)


func query_entries(filters: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in WorldDataManager.history_entries:
		if filters.has("year") and int(entry.get("year", 0)) != int(filters["year"]):
			continue
		if filters.has("month") and int(entry.get("month", 0)) != int(filters["month"]):
			continue
		if filters.has("day") and int(entry.get("day", 0)) != int(filters["day"]):
			continue
		if filters.has("category") and str(entry.get("category", "")) != str(filters["category"]):
			continue
		if filters.has("entity_id") and str(filters["entity_id"]) not in entry.get("entity_ids", []):
			continue
		result.append(entry.duplicate(true))
	return result


func get_entries_by_date(year: int, month: int, day: int) -> Array[Dictionary]:
	return query_entries({"year": year, "month": month, "day": day})


func get_entries_by_category(category: String) -> Array[Dictionary]:
	return query_entries({"category": category})


func get_entries_by_entity(entity_id: String) -> Array[Dictionary]:
	return query_entries({"entity_id": entity_id})


# SaveManager后续只需序列化此纯数据数组，不包含Node、Resource或Callable。
func serialize_history() -> Array[Dictionary]:
	return get_all_entries()


func restore_history(entries: Array) -> void:
	WorldDataManager.history_entries.clear()
	var highest_number: int = 0
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		WorldDataManager.history_entries.append(entry)
		var id_text: String = str(entry.get("history_id", "")).trim_prefix("history_")
		if id_text.is_valid_int():
			highest_number = maxi(highest_number, id_text.to_int())
	_next_history_number = highest_number + 1
	_trim_to_memory_budget()


func _trim_to_memory_budget() -> void:
	var overflow: int = WorldDataManager.history_entries.size() - MAX_HISTORY_ENTRIES
	for _index in range(maxi(0, overflow)):
		WorldDataManager.history_entries.remove_at(0)
