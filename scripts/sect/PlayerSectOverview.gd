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
	placeholder_label.text = "弟子系统后续开放"


func _on_building_button_pressed() -> void:
	placeholder_label.text = "建筑系统后续开放"


func _on_resource_button_pressed() -> void:
	placeholder_label.text = "资源系统后续开放"
