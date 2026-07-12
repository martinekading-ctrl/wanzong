extends Node

signal day_advanced(year: int, month: int, day: int)
signal daily_simulation_completed(report: Dictionary)

const DAYS_PER_MONTH: int = 30
const MONTHS_PER_YEAR: int = 12

var year: int = 1
var month: int = 1
var day: int = 1
var player_sect: SectData
var world_seed: int = 0
var game_speed: float = 1.0
var last_daily_report: Dictionary = {}


func new_game() -> void:
	year = 1
	month = 1
	day = 1
	world_seed = randi()
	game_speed = 1.0
	last_daily_report = {}
	WorldDataManager.reset_world_data()
	SectManager.reset()
	DiscipleManager.load_from_world_data()
	EventManager.reset()
	player_sect = SectManager.create_player_sect()


func next_day() -> Dictionary:
	if player_sect == null:
		push_warning("GameState：尚未开始新游戏。")
		return {}

	var date_before: Dictionary = _get_date_dictionary()
	var daily_actions: Array[Dictionary] = DiscipleManager.prepare_daily_actions(player_sect.id)
	var economy_result: Dictionary = EconomyManager.daily_update(player_sect, daily_actions)
	var disciple_results: Array[Dictionary] = economy_result.get("disciple_results", [])
	DiscipleManager.apply_daily_results(disciple_results)
	var sect_result: Dictionary = SectManager.daily_update(player_sect, economy_result)
	var event_results: Array[Dictionary] = EventManager.daily_update({
		"sect_id": player_sect.id,
		"date": date_before,
	})
	_advance_date()

	last_daily_report = {
		"date_before": date_before,
		"date_after": _get_date_dictionary(),
		"production": economy_result.get("production", {}),
		"expenses": economy_result.get("expenses", {}),
		"shortages": economy_result.get("shortages", {}),
		"disciple_results": disciple_results,
		"sect_result": sect_result,
		"events": event_results,
		"warnings": economy_result.get("warnings", []),
	}
	daily_simulation_completed.emit(last_daily_report)
	return last_daily_report


func _advance_date() -> void:
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		month += 1
	if month > MONTHS_PER_YEAR:
		month = 1
		year += 1
	day_advanced.emit(year, month, day)


func _get_date_dictionary() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
	}
