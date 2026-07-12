extends Node

signal day_advanced(year: int, month: int, day: int)

const DAYS_PER_MONTH: int = 30
const MONTHS_PER_YEAR: int = 12

var year: int = 1
var month: int = 1
var day: int = 1
var player_sect: SectData
var world_seed: int = 0
var game_speed: float = 1.0


func new_game() -> void:
	year = 1
	month = 1
	day = 1
	world_seed = randi()
	game_speed = 1.0
	WorldDataManager.reset_world_data()
	SectManager.reset()
	DiscipleManager.load_from_world_data()
	player_sect = SectManager.create_player_sect()


func next_day() -> Dictionary:
	if player_sect == null:
		push_warning("GameState：尚未开始新游戏。")
		return {}
	var economy_result: Dictionary = EconomyManager.daily_update(player_sect)
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		month += 1
	if month > MONTHS_PER_YEAR:
		month = 1
		year += 1
	day_advanced.emit(year, month, day)
	return economy_result
