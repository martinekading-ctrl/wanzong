extends Control

@onready var back_button: Button = $Margin/RootBox/TopBar/BackButton
@onready var target_option: OptionButton = $Margin/RootBox/ControlBar/TargetOption
@onready var spar_button: Button = $Margin/RootBox/ControlBar/SparButton
@onready var previous_button: Button = $Margin/RootBox/ControlBar/PreviousButton
@onready var next_button: Button = $Margin/RootBox/ControlBar/NextButton
@onready var summary_label: Label = $Margin/RootBox/SummaryLabel
@onready var attacker_list: VBoxContainer = $Margin/RootBox/TeamBox/AttackerPanel/AttackerList
@onready var defender_list: VBoxContainer = $Margin/RootBox/TeamBox/DefenderPanel/DefenderList
@onready var log_label: Label = $Margin/RootBox/LogPanel/LogScroll/LogLabel
@onready var result_label: Label = $Margin/RootBox/ResultLabel

var target_sect_ids: Array[String] = []
var battle_ids: Array[String] = []
var current_battle_index: int = -1


func _ready() -> void:
	back_button.pressed.connect(SceneManager.go_to_player_sect_overview)
	spar_button.pressed.connect(_on_spar_pressed)
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	_setup_targets()
	_refresh_battle_catalog(true)


func _setup_targets() -> void:
	target_option.clear()
	target_sect_ids.clear()
	for sect in WorldDataManager.get_ai_sects():
		target_sect_ids.append(str(sect.get("sect_id", "")))
		target_option.add_item(str(sect.get("sect_name", "宗门")))
	target_option.select(0)


func _refresh_battle_catalog(select_latest: bool = false) -> void:
	battle_ids.clear()
	for battle in BattleManager.get_all_battles():
		battle_ids.append(str(battle.get("battle_id", "")))
	if battle_ids.is_empty():
		current_battle_index = -1
		_show_empty()
		return
	if select_latest or current_battle_index < 0:
		current_battle_index = battle_ids.size() - 1
	else:
		current_battle_index = clampi(current_battle_index, 0, battle_ids.size() - 1)
	_show_battle(BattleManager.get_battle(battle_ids[current_battle_index]))


func _on_spar_pressed() -> void:
	if target_option.selected < 0 or target_option.selected >= target_sect_ids.size():
		result_label.text = "没有可切磋的宗门。"
		return
	var player_ids: Array[String] = _select_team("sect_001", 3)
	var target_id: String = target_sect_ids[target_option.selected]
	var target_ids: Array[String] = _select_team(target_id, 3)
	var result: Dictionary = BattleManager.create_and_simulate("sect_001", player_ids, target_id, target_ids, {"battle_type": "sparring"})
	result_label.text = "切磋已完成。" if bool(result.get("success", false)) else str(result.get("message", "切磋失败。"))
	_refresh_battle_catalog(true)


func _select_team(sect_id: String, count: int) -> Array[String]:
	var candidates: Array = WorldDataManager.get_disciples_by_sect_id(sect_id).duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("combat_power", 0)) > int(b.get("combat_power", 0)))
	var result: Array[String] = []
	for disciple in candidates:
		if int(disciple.get("health", 0)) <= 0:
			continue
		result.append(str(disciple.get("disciple_id", "")))
		if result.size() >= count:
			break
	return result


func _on_previous_pressed() -> void:
	if current_battle_index > 0:
		current_battle_index -= 1
		_show_battle(BattleManager.get_battle(battle_ids[current_battle_index]))


func _on_next_pressed() -> void:
	if current_battle_index >= 0 and current_battle_index < battle_ids.size() - 1:
		current_battle_index += 1
		_show_battle(BattleManager.get_battle(battle_ids[current_battle_index]))


func _show_battle(battle: Dictionary) -> void:
	_clear_list(attacker_list)
	_clear_list(defender_list)
	var result: Dictionary = battle.get("result", {})
	var completed: bool = str(battle.get("status", "")) == "completed"
	summary_label.text = "战斗ID：%s｜类型：%s｜种子：%d｜状态：%s\n%s" % [
		str(battle.get("battle_id", "")),
		_battle_type_text(str(battle.get("battle_type", ""))),
		int(battle.get("seed", 0)),
		"已完成" if completed else "准备中",
		("胜者：%s｜回合：%d｜伤病：%d｜战利品：%s" % [
			_sect_name(str(result.get("winner_sect_id", ""))),
			int(result.get("rounds", 0)),
			result.get("injuries", []).size(),
			_format_loot(result.get("loot", {})),
		]) if completed else "尚未结算",
	]
	_add_team_rows(attacker_list, "进攻方：" + _sect_name(str(battle.get("attacker_sect_id", ""))), battle.get("attacker_units", []))
	_add_team_rows(defender_list, "防守方：" + _sect_name(str(battle.get("defender_sect_id", ""))), battle.get("defender_units", []))
	log_label.text = "\n".join(PackedStringArray(result.get("battle_log", battle.get("battle_log", []))))
	previous_button.disabled = current_battle_index <= 0
	next_button.disabled = current_battle_index < 0 or current_battle_index >= battle_ids.size() - 1


func _add_team_rows(container: VBoxContainer, title: String, units: Array) -> void:
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	container.add_child(title_label)
	for unit in units:
		var label := Label.new()
		label.text = "%s｜%s排｜生命%d/%d｜攻%d 防%d 速%d 灵%d" % [
			str(unit.get("display_name", unit.get("disciple_id", ""))),
			_position_text(str(unit.get("battle_position", "middle"))),
			int(unit.get("current_hp", 0)),
			int(unit.get("max_hp", 0)),
			int(unit.get("attack", 0)),
			int(unit.get("defense", 0)),
			int(unit.get("speed", 0)),
			int(unit.get("spiritual_power", 0)),
		]
		container.add_child(label)


func _show_empty() -> void:
	_clear_list(attacker_list)
	_clear_list(defender_list)
	summary_label.text = "暂无战报，可选择一个宗门进行模拟切磋。"
	log_label.text = ""
	previous_button.disabled = true
	next_button.disabled = true


func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _sect_name(sect_id: String) -> String:
	return str(WorldDataManager.get_sect_by_id(sect_id).get("sect_name", sect_id))


func _format_loot(loot: Dictionary) -> String:
	if loot.is_empty(): return "无"
	var parts := PackedStringArray()
	for key in loot: parts.append("%s+%d" % [str(key), int(loot[key])])
	return "，".join(parts)


func _position_text(value: String) -> String:
	return {"front": "前", "middle": "中", "back": "后"}.get(value, value)


func _battle_type_text(value: String) -> String:
	return {"sparring": "切磋", "skirmish": "遭遇战", "war": "宗门战争", "siege": "攻防战"}.get(value, value)
