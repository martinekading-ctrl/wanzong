extends Control

const ASSIGNMENT_FILTERS: Array[String] = ["全部", "空闲", "修炼", "巡山", "采集", "闭关"]
const SORT_OPTIONS: Array[String] = ["默认", "境界", "战力", "忠诚", "年龄"]
const REALM_ORDER: Dictionary = {
	"凡人": 0,
	"炼气一层": 1,
	"炼气二层": 2,
	"炼气三层": 3,
	"炼气四层": 4,
	"炼气五层": 5,
}

@onready var title_label: Label = $MarginContainer/RootBox/TopBar/TitleLabel
@onready var back_button: Button = $MarginContainer/RootBox/TopBar/BackButton
@onready var sect_name_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/SectNameLabel
@onready var master_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/MasterLabel
@onready var rank_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/RankLabel
@onready var disciple_count_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/DiscipleCountLabel
@onready var spirit_stone_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/SpiritStoneLabel
@onready var reputation_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/ReputationLabel
@onready var combat_power_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/CombatPowerLabel
@onready var description_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/DescriptionLabel
@onready var disciple_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/DiscipleButton
@onready var building_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/BuildingButton
@onready var resource_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/ResourceButton
@onready var placeholder_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PlaceholderLabel
@onready var disciple_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection
@onready var search_line_edit: LineEdit = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleTopBar/SearchLineEdit
@onready var assignment_filter_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleTopBar/AssignmentFilterOption
@onready var sort_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleTopBar/SortOption
@onready var disciple_list_container: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleListPanel/DiscipleListScroll/DiscipleListContainer
@onready var model_preview_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/ModelPreviewBox/ModelPreviewLabel
@onready var disciple_name_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/DiscipleNameLabel
@onready var basic_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BasicInfoLabel
@onready var attribute_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AttributeInfoLabel
@onready var battle_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BattleInfoLabel
@onready var appearance_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AppearanceInfoLabel
@onready var assignment_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AssignmentInfoLabel
@onready var detail_description_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/DetailDescriptionLabel
@onready var detail_hint_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/DetailHintLabel

var current_selected_disciple_id: String = ""


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	disciple_button.pressed.connect(_on_disciple_button_pressed)
	building_button.pressed.connect(_on_building_button_pressed)
	resource_button.pressed.connect(_on_resource_button_pressed)
	search_line_edit.text_changed.connect(_on_disciple_filter_changed)
	assignment_filter_option.item_selected.connect(_on_disciple_option_changed)
	sort_option.item_selected.connect(_on_disciple_option_changed)
	_setup_roster_options()
	_refresh_player_sect_info()
	_clear_disciple_detail()


func _setup_roster_options() -> void:
	assignment_filter_option.clear()
	for filter_text in ASSIGNMENT_FILTERS:
		assignment_filter_option.add_item(filter_text)
	assignment_filter_option.select(0)

	sort_option.clear()
	for option_text in SORT_OPTIONS:
		sort_option.add_item(option_text)
	sort_option.select(0)


func _refresh_player_sect_info() -> void:
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	if player_sect.is_empty():
		WorldDataManager.init_world_data()
		player_sect = WorldDataManager.get_player_sect()

	if player_sect.is_empty():
		title_label.text = "玩家宗门详情"
		sect_name_label.text = "宗门名称：未找到玩家宗门"
		master_label.text = "宗主：-"
		rank_label.text = "宗门品阶：-"
		disciple_count_label.text = "弟子数量：-"
		spirit_stone_label.text = "灵石：-"
		reputation_label.text = "声望：-"
		combat_power_label.text = "战力：-"
		description_label.text = "介绍：WorldDataManager 中没有可用的玩家宗门数据。"
		return

	title_label.text = "玩家宗门详情"
	sect_name_label.text = "宗门名称：" + str(player_sect["sect_name"])
	master_label.text = "宗主：" + str(player_sect["master_name"])
	rank_label.text = "宗门品阶：" + str(player_sect["realm_rank"])
	disciple_count_label.text = "弟子数量：" + str(player_sect["disciple_count"])
	spirit_stone_label.text = "灵石：" + str(player_sect["spirit_stone"])
	reputation_label.text = "声望：" + str(player_sect["reputation"])
	combat_power_label.text = "战力：" + str(player_sect["combat_power"])
	description_label.text = "介绍：" + str(player_sect["description"])


func _on_back_button_pressed() -> void:
	SceneManager.go_to_world_map()


func _on_disciple_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = true
	_refresh_disciple_roster()


func _on_building_button_pressed() -> void:
	_show_placeholder("建筑系统后续开放")


func _on_resource_button_pressed() -> void:
	_show_placeholder("资源系统后续开放")


func _show_placeholder(message: String) -> void:
	placeholder_label.visible = true
	placeholder_label.text = message
	disciple_section.visible = false


func _on_disciple_filter_changed(_new_text: String) -> void:
	_refresh_disciple_roster()


func _on_disciple_option_changed(_index: int) -> void:
	_refresh_disciple_roster()


func _refresh_disciple_roster() -> void:
	_clear_disciple_list()
	var visible_disciples: Array = _get_visible_disciples()
	var selected_still_visible: bool = false

	for disciple_data in visible_disciples:
		var disciple_id: String = str(disciple_data["disciple_id"])
		if disciple_id == current_selected_disciple_id:
			selected_still_visible = true

		var disciple_button_item := Button.new()
		disciple_button_item.text = _get_disciple_row_text(disciple_data)
		disciple_button_item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		disciple_button_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if disciple_id == current_selected_disciple_id:
			disciple_button_item.text = "▶ " + disciple_button_item.text
			disciple_button_item.modulate = Color(1.0, 0.92, 0.62)
		disciple_button_item.pressed.connect(_on_disciple_selected.bind(disciple_id))
		disciple_list_container.add_child(disciple_button_item)

	if current_selected_disciple_id == "" or not selected_still_visible:
		_clear_disciple_detail()
	else:
		var selected_disciple: Dictionary = WorldDataManager.get_disciple_by_id(current_selected_disciple_id)
		if selected_disciple.is_empty():
			_clear_disciple_detail()
		else:
			_show_disciple_detail(selected_disciple)


func _get_visible_disciples() -> Array:
	var result: Array = []
	var search_text: String = search_line_edit.text.strip_edges()
	var assignment_filter: String = assignment_filter_option.get_item_text(assignment_filter_option.selected)

	for disciple_data in WorldDataManager.get_player_disciples():
		var disciple_name: String = str(disciple_data["disciple_name"])
		if search_text != "" and not disciple_name.contains(search_text):
			continue
		if assignment_filter != "全部" and str(disciple_data["assignment"]) != assignment_filter:
			continue
		result.append(disciple_data)

	_sort_disciples(result)
	return result


func _sort_disciples(disciples: Array) -> void:
	var sort_text: String = sort_option.get_item_text(sort_option.selected)
	if sort_text == "战力":
		disciples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["combat_power"]) > int(b["combat_power"])
		)
	elif sort_text == "忠诚":
		disciples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["loyalty"]) > int(b["loyalty"])
		)
	elif sort_text == "年龄":
		disciples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["age"]) < int(b["age"])
		)
	elif sort_text == "境界":
		disciples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _get_realm_rank(str(a["realm"])) > _get_realm_rank(str(b["realm"]))
		)


func _get_realm_rank(realm: String) -> int:
	return int(REALM_ORDER.get(realm, -1))


func _clear_disciple_list() -> void:
	for child in disciple_list_container.get_children():
		disciple_list_container.remove_child(child)
		child.queue_free()


func _get_disciple_row_text(disciple_data: Dictionary) -> String:
	return "%s｜%s｜%s｜%s｜%s｜%s｜战力 %s｜%s" % [
		str(disciple_data["disciple_name"]),
		str(disciple_data["role"]),
		str(disciple_data["realm"]),
		str(disciple_data["spiritual_root"]),
		str(disciple_data["aptitude"]),
		str(disciple_data["assignment"]),
		str(disciple_data["combat_power"]),
		str(disciple_data["status"]),
	]


func _on_disciple_selected(disciple_id: String) -> void:
	current_selected_disciple_id = disciple_id
	var disciple_data: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
	if disciple_data.is_empty():
		_clear_disciple_detail()
		return

	_show_disciple_detail(disciple_data)
	_refresh_disciple_roster()


func _clear_disciple_detail() -> void:
	current_selected_disciple_id = ""
	model_preview_label.text = "人物模型预览\n共享模板后续接入"
	disciple_name_label.text = "请选择弟子"
	basic_info_label.text = ""
	attribute_info_label.text = ""
	battle_info_label.text = ""
	appearance_info_label.text = ""
	assignment_info_label.text = ""
	detail_description_label.text = ""
	detail_hint_label.text = "普通弟子使用共享外观模板；世界地图不直接生成全部弟子小人。"


func _show_disciple_detail(disciple_data: Dictionary) -> void:
	model_preview_label.text = "人物模型预览\n共享模板后续接入"
	disciple_name_label.text = str(disciple_data["disciple_name"])
	basic_info_label.text = "\n".join(PackedStringArray([
		"基础信息：",
		"性别：" + str(disciple_data["gender"]),
		"年龄：" + str(disciple_data["age"]),
		"职位：" + str(disciple_data["role"]),
		"修为：" + str(disciple_data["realm"]),
		"灵根：" + str(disciple_data["spiritual_root"]),
		"资质：" + str(disciple_data["aptitude"]),
		"状态：" + str(disciple_data["status"]),
		"标签：" + _format_tags(disciple_data.get("tags", [])),
	]))
	attribute_info_label.text = "\n".join(PackedStringArray([
		"属性：",
		"悟性：" + str(disciple_data["comprehension"]),
		"忠诚：" + str(disciple_data["loyalty"]),
		"心情：" + str(disciple_data["mood"]),
		"当前安排：" + str(disciple_data["assignment"]),
	]))
	battle_info_label.text = "\n".join(PackedStringArray([
		"战斗预留：",
		"战力：" + str(disciple_data["combat_power"]),
		"生命：" + str(disciple_data["hp"]) + " / " + str(disciple_data["max_hp"]),
		"攻击：" + str(disciple_data["attack"]),
		"防御：" + str(disciple_data["defense"]),
		"速度：" + str(disciple_data["speed"]),
		"灵力：" + str(disciple_data["spiritual_power"]),
		"武器：" + str(disciple_data["weapon_type"]),
		"站位：" + str(disciple_data["battle_position"]),
		"是否派遣：" + ("是" if bool(disciple_data["is_deployed"]) else "否"),
		"队伍：" + (str(disciple_data["team_id"]) if str(disciple_data["team_id"]) != "" else "无"),
		"战斗状态：" + str(disciple_data["battle_status"]),
	]))
	appearance_info_label.text = "\n".join(PackedStringArray([
		"共享外观模板：",
		"appearance_id：" + str(disciple_data["appearance_id"]),
		"portrait_id：" + str(disciple_data["portrait_id"]),
		"model_id：" + str(disciple_data["model_id"]),
		"battle_model_id：" + str(disciple_data["battle_model_id"]),
		"color_scheme：" + str(disciple_data["color_scheme"]),
	]))
	assignment_info_label.text = "当前安排：" + str(disciple_data["assignment"])
	detail_description_label.text = "介绍：" + str(disciple_data["description"])
	detail_hint_label.text = "本页只展示弟子名册、共享模板 ID 与战斗预留字段；不生成头像、不创建战斗单位。"


func _format_tags(tags: Variant) -> String:
	if not (tags is Array):
		return ""
	var tag_texts: PackedStringArray = PackedStringArray()
	for tag in tags:
		tag_texts.append(str(tag))
	var result: String = ""
	for tag_index in range(tag_texts.size()):
		if tag_index > 0:
			result += "、"
		result += tag_texts[tag_index]
	return result
