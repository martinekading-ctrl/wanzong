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
var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func new_game() -> void:
	year = 1
	month = 1
	day = 1
	world_seed = randi()
	world_rng.seed = world_seed
	game_speed = 1.0
	last_daily_report = {}
	WorldDataManager.reset_world_data()
	SectManager.reset()
	DiscipleManager.load_from_world_data()
	EventManager.reset()
	GameHistoryManager.reset()
	player_sect = SectManager.create_player_sect()
	AISimulationManager.initialize_from_world_data()
	ConstructionManager.rebuild_runtime_state()
	MissionManager.rebuild_runtime_state()
	SecretRealmManager.initialize_world_state()
	ResourceSiteManager.initialize_world_state()
	TerritoryManager.initialize_world_state()
	DiplomacyManager.initialize_world_state()
	BattleManager.rebuild_runtime_state()
	WarManager.rebuild_runtime_state()
	InventoryManager.initialize_world_state()
	CraftingManager.rebuild_runtime_state()
	MarketManager.initialize_world_state()


func random_int(minimum: int, maximum: int) -> int:
	return world_rng.randi_range(minimum, maximum)


func random_float() -> float:
	return world_rng.randf()


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
	var ai_summary: Dictionary = AISimulationManager.daily_update(date_before)
	var construction_summary: Dictionary = ConstructionManager.daily_update(date_before)
	var crafting_summary: Dictionary = CraftingManager.daily_update(date_before)
	var mission_summary: Dictionary = MissionManager.daily_update(date_before)
	var resource_site_summary: Dictionary = ResourceSiteManager.daily_update(date_before)
	var territory_summary: Dictionary = TerritoryManager.daily_update(date_before)
	var diplomacy_summary: Dictionary = DiplomacyManager.daily_update(date_before)
	var war_summary: Dictionary = WarManager.daily_update(date_before)
	var market_summary: Dictionary = MarketManager.daily_update(date_before)
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
		"ai_summary": ai_summary,
		"construction": construction_summary,
		"crafting": crafting_summary,
		"missions": mission_summary,
		"resource_sites": resource_site_summary,
		"territories": territory_summary,
		"diplomacy": diplomacy_summary,
		"wars": war_summary,
		"market": market_summary,
		"events": event_results,
		"warnings": economy_result.get("warnings", []),
	}
	GameHistoryManager.record_entry(
		"daily_settlement",
		"每日结算",
		"宗门完成了第%d年%d月%d日的日常结算。" % [
			int(date_before["year"]),
			int(date_before["month"]),
			int(date_before["day"]),
		],
		[player_sect.id],
		{
			"production": last_daily_report["production"],
			"expenses": last_daily_report["expenses"],
			"shortages": last_daily_report["shortages"],
			"ai_summary": last_daily_report["ai_summary"],
		},
		date_before
	)
	if day == 1:
		last_daily_report["autosave"] = SaveManager.autosave()
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
