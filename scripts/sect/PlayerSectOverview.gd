extends Control

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
@onready var disciple_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleButton
@onready var building_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingButton
@onready var resource_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceButton
@onready var placeholder_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PlaceholderLabel
@onready var disciple_content: HBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleContent
@onready var disciple_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleContent/DiscipleListPanel/DiscipleListBox/DiscipleScroll/DiscipleList
@onready var disciple_detail_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleContent/DiscipleDetailPanel/DiscipleDetailBox/DiscipleDetailLabel


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	disciple_button.pressed.connect(_on_disciple_button_pressed)
	building_button.pressed.connect(_on_building_button_pressed)
	resource_button.pressed.connect(_on_resource_button_pressed)
	_refresh_player_sect_info()


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
	_show_disciple_panel()


func _on_building_button_pressed() -> void:
	_show_placeholder("建筑系统后续开放")


func _on_resource_button_pressed() -> void:
	_show_placeholder("资源系统后续开放")


func _show_placeholder(message: String) -> void:
	placeholder_label.visible = true
	placeholder_label.text = message
	disciple_content.visible = false


func _show_disciple_panel() -> void:
	placeholder_label.visible = false
	disciple_content.visible = true
	_clear_disciple_list()

	var player_disciples: Array = WorldDataManager.get_player_disciples()
	if player_disciples.is_empty():
		disciple_detail_label.text = "当前玩家宗门没有弟子数据。"
		return

	for disciple_data in player_disciples:
		var disciple_button_item := Button.new()
		disciple_button_item.text = _get_disciple_list_text(disciple_data)
		disciple_button_item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		disciple_button_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		disciple_button_item.pressed.connect(
			_on_disciple_selected.bind(str(disciple_data["disciple_id"]))
		)
		disciple_list.add_child(disciple_button_item)

	_show_disciple_detail(player_disciples[0])


func _clear_disciple_list() -> void:
	for child in disciple_list.get_children():
		child.queue_free()


func _get_disciple_list_text(disciple_data: Dictionary) -> String:
	return "%s｜%s｜%s｜%s｜忠诚 %s｜%s" % [
		str(disciple_data["disciple_name"]),
		str(disciple_data["realm"]),
		str(disciple_data["spiritual_root"]),
		str(disciple_data["aptitude"]),
		str(disciple_data["loyalty"]),
		str(disciple_data["assignment"]),
	]


func _on_disciple_selected(disciple_id: String) -> void:
	var disciple_data: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
	if disciple_data.is_empty():
		disciple_detail_label.text = "没有找到这个弟子。"
		return

	_show_disciple_detail(disciple_data)


func _show_disciple_detail(disciple_data: Dictionary) -> void:
	disciple_detail_label.text = "\n".join(PackedStringArray([
		"姓名：" + str(disciple_data["disciple_name"]),
		"性别：" + str(disciple_data["gender"]),
		"年龄：" + str(disciple_data["age"]),
		"修为：" + str(disciple_data["realm"]),
		"灵根：" + str(disciple_data["spiritual_root"]),
		"资质：" + str(disciple_data["aptitude"]),
		"悟性：" + str(disciple_data["comprehension"]),
		"忠诚：" + str(disciple_data["loyalty"]),
		"心情：" + str(disciple_data["mood"]),
		"当前安排：" + str(disciple_data["assignment"]),
		"战力：" + str(disciple_data["combat_power"]),
		"状态：" + str(disciple_data["status"]),
		"介绍：" + str(disciple_data["description"]),
	]))
