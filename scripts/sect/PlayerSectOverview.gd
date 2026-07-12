extends Control

const LEGACY_ASSIGNMENT_FILTERS: Array[String] = ["巡山", "采集", "闭关"]
const SORT_OPTIONS: Array[String] = ["默认", "境界", "战力", "忠诚", "年龄"]
@onready var title_label: Label = $MarginContainer/RootBox/TopBar/TitleLabel
@onready var date_label: Label = $MarginContainer/RootBox/TopBar/DateLabel
@onready var next_day_button: Button = $MarginContainer/RootBox/TopBar/NextDayButton
@onready var back_button: Button = $MarginContainer/RootBox/TopBar/BackButton
@onready var sect_name_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/SectNameLabel
@onready var master_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/MasterLabel
@onready var rank_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/RankLabel
@onready var disciple_count_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/DiscipleCountLabel
@onready var spirit_stone_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/SpiritStoneLabel
@onready var reputation_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/ReputationLabel
@onready var combat_power_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/CombatPowerLabel
@onready var description_label: Label = $MarginContainer/RootBox/SummaryPanel/SummaryBox/DescriptionLabel
@onready var resource_panel: PanelContainer = $MarginContainer/RootBox/ResourcePanel
@onready var resource_spirit_stone_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/SpiritStoneLabel
@onready var resource_food_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/FoodLabel
@onready var resource_wood_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/WoodLabel
@onready var resource_stone_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/StoneLabel
@onready var resource_spirit_grass_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/SpiritGrassLabel
@onready var resource_spirit_ore_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/SpiritOreLabel
@onready var resource_population_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/ResourceGrid/PopulationLabel
@onready var test_month_button: Button = $MarginContainer/RootBox/ResourcePanel/ResourceBox/SettlementBox/TestMonthButton
@onready var settlement_result_label: Label = $MarginContainer/RootBox/ResourcePanel/ResourceBox/SettlementBox/SettlementResultLabel
@onready var disciple_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/DiscipleButton
@onready var building_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/BuildingButton
@onready var resource_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/ResourceButton
@onready var history_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/HistoryButton
@onready var save_load_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/SaveLoadButton
@onready var mission_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/MissionButton
@onready var diplomacy_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/DiplomacyButton
@onready var battle_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/BattleButton
@onready var inventory_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ButtonBar/InventoryButton
@onready var pending_event_panel: PanelContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PendingEventPanel
@onready var event_title_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PendingEventPanel/EventBox/EventTitleLabel
@onready var event_description_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PendingEventPanel/EventBox/EventDescriptionLabel
@onready var event_option_box: HBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PendingEventPanel/EventBox/EventOptionBox
@onready var event_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PendingEventPanel/EventBox/EventResultLabel
@onready var placeholder_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/PlaceholderLabel
@onready var history_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/HistorySection
@onready var history_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/HistorySection/HistoryScroll/HistoryList
@onready var save_load_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection
@onready var manual_slot_1_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot1/SlotLabel
@onready var manual_slot_1_save: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot1/SaveButton
@onready var manual_slot_1_load: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot1/LoadButton
@onready var manual_slot_2_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot2/SlotLabel
@onready var manual_slot_2_save: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot2/SaveButton
@onready var manual_slot_2_load: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot2/LoadButton
@onready var manual_slot_3_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot3/SlotLabel
@onready var manual_slot_3_save: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot3/SaveButton
@onready var manual_slot_3_load: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/ManualSlot3/LoadButton
@onready var quick_slot_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/QuickSlot/SlotLabel
@onready var quick_save_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/QuickSlot/SaveButton
@onready var quick_load_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/QuickSlot/LoadButton
@onready var autosave_slot_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/AutosaveSlot/SlotLabel
@onready var autosave_load_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/AutosaveSlot/LoadButton
@onready var save_load_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/SaveLoadSection/SaveLoadResultLabel
@onready var building_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection
@onready var sect_level_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection/SectUpgradeBox/SectLevelLabel
@onready var sect_upgrade_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection/SectUpgradeBox/SectUpgradeButton
@onready var building_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection/BuildingScroll/BuildingList
@onready var building_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/BuildingSection/BuildingResultLabel
@onready var mission_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection
@onready var mission_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/MissionControlBox/MissionOption
@onready var secret_realm_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/MissionControlBox/SecretRealmOption
@onready var start_mission_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/MissionControlBox/StartMissionButton
@onready var selected_team_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/SelectedTeamLabel
@onready var available_disciple_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/MissionBody/AvailablePanel/AvailableScroll/AvailableDiscipleList
@onready var active_mission_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/MissionBody/ActivePanel/ActiveScroll/ActiveMissionList
@onready var mission_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/MissionSection/MissionResultLabel
@onready var resource_site_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection
@onready var resource_site_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/ControlBox/SiteOption
@onready var resource_site_clear_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/ControlBox/ClearButton
@onready var resource_site_negotiate_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/ControlBox/NegotiateButton
@onready var resource_site_assign_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/ControlBox/AssignButton
@onready var resource_site_withdraw_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/ControlBox/WithdrawButton
@onready var resource_site_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/SiteInfoLabel
@onready var resource_site_disciple_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/Body/DisciplePanel/DiscipleScroll/DiscipleList
@onready var owned_resource_site_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/Body/OwnedPanel/OwnedScroll/OwnedList
@onready var resource_site_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/ResourceSiteSection/ResultLabel
@onready var diplomacy_section: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection
@onready var diplomacy_target_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/ControlBox/TargetOption
@onready var diplomacy_action_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/ControlBox/ActionOption
@onready var diplomacy_execute_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/ControlBox/ExecuteButton
@onready var diplomacy_alliance_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/PactControlBox/AllianceButton
@onready var diplomacy_non_aggression_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/PactControlBox/NonAggressionButton
@onready var diplomacy_vassal_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/PactControlBox/VassalButton
@onready var diplomacy_war_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/PactControlBox/WarButton
@onready var diplomacy_peace_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/PactControlBox/PeaceButton
@onready var diplomacy_relation_info_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/RelationInfoLabel
@onready var diplomacy_relation_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/RelationScroll/RelationList
@onready var diplomacy_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiplomacySection/ResultLabel
@onready var inventory_section: HBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/InventorySection
@onready var inventory_item_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/InventorySection/ItemPanel/ItemScroll/ItemList
@onready var inventory_recipe_list: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/InventorySection/RecipePanel/RecipeScroll/RecipeList
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
@onready var assignment_box: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AssignmentBox
@onready var assignment_option: OptionButton = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AssignmentBox/AssignmentControlBox/AssignmentOption
@onready var apply_assignment_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AssignmentBox/AssignmentControlBox/ApplyAssignmentButton
@onready var assignment_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/AssignmentBox/AssignmentResultLabel
@onready var breakthrough_box: VBoxContainer = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BreakthroughBox
@onready var breakthrough_preview_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BreakthroughBox/BreakthroughPreviewLabel
@onready var breakthrough_button: Button = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BreakthroughBox/BreakthroughButton
@onready var breakthrough_result_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/BreakthroughBox/BreakthroughResultLabel
@onready var detail_description_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/DetailDescriptionLabel
@onready var detail_hint_label: Label = $MarginContainer/RootBox/FunctionPanel/FunctionBox/DiscipleSection/DiscipleBody/DiscipleDetailPanel/DiscipleDetailBox/DetailHintLabel

var current_selected_disciple_id: String = ""
var selected_mission_disciple_ids: Array[String] = []
var mission_definition_ids: Array[String] = []
var secret_realm_ids: Array[String] = []
var resource_site_ids: Array[int] = []
var selected_resource_disciple_ids: Array[String] = []
var diplomacy_target_ids: Array[String] = []
var diplomacy_action_ids: Array[String] = []
var inventory_message: String = ""


func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	next_day_button.pressed.connect(_on_next_day_button_pressed)
	disciple_button.pressed.connect(_on_disciple_button_pressed)
	building_button.pressed.connect(_on_building_button_pressed)
	resource_button.pressed.connect(_on_resource_button_pressed)
	history_button.pressed.connect(_on_history_button_pressed)
	save_load_button.pressed.connect(_on_save_load_button_pressed)
	mission_button.pressed.connect(_on_mission_button_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_button_pressed)
	battle_button.pressed.connect(SceneManager.go_to_battle_report)
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	start_mission_button.pressed.connect(_on_start_mission_pressed)
	mission_option.item_selected.connect(_on_mission_option_selected)
	resource_site_option.item_selected.connect(_on_resource_site_selected)
	resource_site_clear_button.pressed.connect(_on_resource_site_capture.bind("clear"))
	resource_site_negotiate_button.pressed.connect(_on_resource_site_capture.bind("negotiate"))
	resource_site_assign_button.pressed.connect(_on_resource_site_assign_garrison)
	resource_site_withdraw_button.pressed.connect(_on_resource_site_withdraw_garrison)
	diplomacy_target_option.item_selected.connect(_on_diplomacy_selection_changed)
	diplomacy_action_option.item_selected.connect(_on_diplomacy_selection_changed)
	diplomacy_execute_button.pressed.connect(_on_diplomacy_execute_pressed)
	diplomacy_alliance_button.pressed.connect(_on_diplomacy_pact_pressed.bind("alliance"))
	diplomacy_non_aggression_button.pressed.connect(_on_diplomacy_pact_pressed.bind("non_aggression"))
	diplomacy_vassal_button.pressed.connect(_on_diplomacy_pact_pressed.bind("vassal"))
	diplomacy_war_button.pressed.connect(_on_diplomacy_pact_pressed.bind("war"))
	diplomacy_peace_button.pressed.connect(_on_diplomacy_pact_pressed.bind("peace"))
	manual_slot_1_save.pressed.connect(_on_manual_save_pressed.bind(1))
	manual_slot_1_load.pressed.connect(_on_manual_load_pressed.bind(1))
	manual_slot_2_save.pressed.connect(_on_manual_save_pressed.bind(2))
	manual_slot_2_load.pressed.connect(_on_manual_load_pressed.bind(2))
	manual_slot_3_save.pressed.connect(_on_manual_save_pressed.bind(3))
	manual_slot_3_load.pressed.connect(_on_manual_load_pressed.bind(3))
	quick_save_button.pressed.connect(_on_quick_save_pressed)
	quick_load_button.pressed.connect(_on_quick_load_pressed)
	autosave_load_button.pressed.connect(_on_autosave_load_pressed)
	sect_upgrade_button.pressed.connect(_on_sect_upgrade_pressed)
	search_line_edit.text_changed.connect(_on_disciple_filter_changed)
	assignment_filter_option.item_selected.connect(_on_disciple_option_changed)
	sort_option.item_selected.connect(_on_disciple_option_changed)
	apply_assignment_button.pressed.connect(_on_apply_assignment_button_pressed)
	breakthrough_button.pressed.connect(_on_breakthrough_button_pressed)
	test_month_button.pressed.connect(_on_next_day_button_pressed)
	_setup_roster_options()
	_setup_assignment_options()
	_setup_mission_options()
	_setup_secret_realm_options()
	_refresh_player_sect_info()
	_refresh_resource_panel()
	_refresh_date_label()
	_refresh_daily_report(GameState.last_daily_report)
	_refresh_pending_event_panel()
	_refresh_save_slots()
	_clear_disciple_detail()


func _setup_roster_options() -> void:
	assignment_filter_option.clear()
	assignment_filter_option.add_item("全部")
	for filter_text in DiscipleManager.get_supported_assignments():
		assignment_filter_option.add_item(filter_text)
	for filter_text in LEGACY_ASSIGNMENT_FILTERS:
		assignment_filter_option.add_item(filter_text)
	assignment_filter_option.select(0)

	sort_option.clear()
	for option_text in SORT_OPTIONS:
		sort_option.add_item(option_text)
	sort_option.select(0)


func _setup_assignment_options() -> void:
	assignment_option.clear()
	for assignment_text in DiscipleManager.get_supported_assignments():
		assignment_option.add_item(assignment_text)
	assignment_option.select(0)


func _setup_mission_options() -> void:
	mission_option.clear()
	mission_definition_ids.clear()
	for definition in MissionRegistry.get_all():
		mission_definition_ids.append(definition.id)
		mission_option.add_item("%s（%d日，%d-%d人）" % [
			definition.display_name,
			definition.duration_days,
			definition.min_team_size,
			definition.max_team_size,
		])
	mission_option.select(0)
	_on_mission_option_selected(0)


func _setup_secret_realm_options() -> void:
	secret_realm_option.clear()
	secret_realm_ids.clear()
	for realm in SecretRealmManager.get_available_realms():
		secret_realm_ids.append(str(realm.get("realm_id", "")))
		secret_realm_option.add_item("%s｜%d/%d层｜建议战力%d" % [
			str(realm.get("display_name", "秘境")),
			int(realm.get("current_depth", 0)),
			int(realm.get("total_depth", 0)),
			int(realm.get("recommended_power", 0)),
		])
	secret_realm_option.select(0)


func _on_mission_option_selected(_index: int) -> void:
	if mission_option.selected < 0 or mission_option.selected >= mission_definition_ids.size():
		secret_realm_option.visible = false
		return
	var definition: MissionDefinition = MissionRegistry.get_by_id(mission_definition_ids[mission_option.selected])
	secret_realm_option.visible = definition != null and definition.mission_type == "secret_realm"


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
	reputation_label.text = "声望：" + str(player_sect["reputation"])
	combat_power_label.text = "战力：" + str(player_sect["combat_power"])
	var territory: Dictionary = TerritoryManager.get_territory(str(player_sect["sect_id"]))
	description_label.text = "介绍：%s\n影响力：%d｜控制点：%d｜邻接宗门：%d｜争议点：%d" % [
		str(player_sect["description"]),
		int(territory.get("influence", 0)),
		territory.get("control_point_ids", []).size(),
		territory.get("neighbors", []).size(),
		territory.get("contested_point_ids", []).size(),
	]
	var resource_data: Dictionary = WorldDataManager.get_sect_resources(str(player_sect["sect_id"]))
	spirit_stone_label.text = "灵石：" + str(resource_data.get("spirit_stone", "-"))


func _refresh_resource_panel() -> void:
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	if player_sect.is_empty():
		_set_resource_labels({})
		return

	var sect_id: String = str(player_sect.get("sect_id", ""))
	var resource_data: Dictionary = WorldDataManager.get_sect_resources(sect_id)
	_set_resource_labels(resource_data)


func _set_resource_labels(resource_data: Dictionary) -> void:
	resource_spirit_stone_label.text = "灵石：" + str(resource_data.get("spirit_stone", "-"))
	resource_food_label.text = "粮食：" + str(resource_data.get("food", "-"))
	resource_wood_label.text = "木材：" + str(resource_data.get("wood", "-"))
	resource_stone_label.text = "石材：" + str(resource_data.get("stone", "-"))
	resource_spirit_grass_label.text = "灵草：" + str(resource_data.get("spirit_grass", "-"))
	resource_spirit_ore_label.text = "灵矿：" + str(resource_data.get("spirit_ore", "-"))
	resource_population_label.text = "人口：" + str(resource_data.get("population", "-"))


func _on_next_day_button_pressed() -> void:
	var report: Dictionary = GameState.next_day()
	if report.is_empty():
		settlement_result_label.text = "推进失败：尚未初始化玩家宗门。"
		return
	_refresh_all(report)


func _refresh_all(report: Dictionary = GameState.last_daily_report) -> void:
	_refresh_date_label()
	_refresh_player_sect_info()
	_refresh_resource_panel()
	_refresh_daily_report(report)
	_refresh_pending_event_panel()
	if disciple_section.visible:
		_refresh_disciple_roster()
	if history_section.visible:
		_refresh_history_list()
	if save_load_section.visible:
		_refresh_save_slots()
	if building_section.visible:
		_refresh_building_section()
	if mission_section.visible:
		_refresh_mission_section()
	if resource_site_section.visible:
		_refresh_resource_site_section()
	if diplomacy_section.visible:
		_refresh_diplomacy_section()
	if inventory_section.visible:
		_refresh_inventory_section()


func _refresh_date_label() -> void:
	date_label.text = "第%d年 %d月 %d日" % [GameState.year, GameState.month, GameState.day]


func _refresh_daily_report(report: Dictionary) -> void:
	if report.is_empty():
		settlement_result_label.text = "最近结算：尚未推进日期"
		return
	var production: Dictionary = report.get("production", {})
	var expenses: Dictionary = report.get("expenses", {})
	var shortages: Dictionary = report.get("shortages", {})
	var cultivation_success: int = 0
	var cultivation_failed: int = 0
	var cultivation_gain: int = 0
	var bottleneck_count: int = 0
	for result in report.get("disciple_results", []):
		if str(result.get("assignment", "")) != DiscipleManager.ASSIGNMENT_CULTIVATE:
			continue
		cultivation_gain += int(result.get("cultivation_gain", 0))
		if bool(result.get("at_bottleneck", false)):
			bottleneck_count += 1
		if bool(result.get("success", false)):
			cultivation_success += 1
		else:
			cultivation_failed += 1
	var maintenance: Dictionary = expenses.get("maintenance", {})
	var cultivation: Dictionary = expenses.get("cultivation", {})
	var food: Dictionary = expenses.get("food", {})
	var warning_text: String = "无"
	var warnings: Array = report.get("warnings", [])
	var new_events: Array = report.get("events", [])
	var ai_summary: Dictionary = report.get("ai_summary", {})
	var construction_summary: Dictionary = report.get("construction", {})
	var crafting_summary: Dictionary = report.get("crafting", {})
	var mission_summary: Dictionary = report.get("missions", {})
	var resource_site_summary: Dictionary = report.get("resource_sites", {})
	var territory_summary: Dictionary = report.get("territories", {})
	var diplomacy_summary: Dictionary = report.get("diplomacy", {})
	var war_summary: Dictionary = report.get("wars", {})
	if not warnings.is_empty():
		warning_text = "；".join(PackedStringArray(warnings))
	settlement_result_label.text = "\n".join(PackedStringArray([
		"最近结算：",
		"今日产出：%s" % _format_production(production),
		"今日灵石消耗：%d" % (int(maintenance.get("paid", 0)) + int(cultivation.get("paid", 0))),
		"今日食物消耗：%d" % int(food.get("paid", 0)),
		"资源缺口：灵石%d，食物%d" % [int(shortages.get("spirit_stone", 0)), int(shortages.get("food", 0))],
		"修炼成功：%d人；修炼失败：%d人" % [cultivation_success, cultivation_failed],
		"修为增长：%d；瓶颈弟子：%d人" % [cultivation_gain, bottleneck_count],
		"新触发事件：%d件" % new_events.size(),
		"AI世界：%d宗门，%d弟子，耗时%d毫秒" % [
			int(ai_summary.get("sects_updated", 0)),
			int(ai_summary.get("disciples_updated", 0)),
			int(ai_summary.get("duration_ms", 0)),
		],
		"建设进度：%d项推进，%d项完成" % [
			construction_summary.get("progressed", []).size(),
			construction_summary.get("completed", []).size(),
		],
		"制作进度：%d项推进，%d项完成" % [crafting_summary.get("progressed", []).size(), crafting_summary.get("completed", []).size()],
		"派遣任务：%d项推进，%d项完成" % [
			mission_summary.get("progressed", []).size(),
			mission_summary.get("completed", []).size(),
		],
		"资源据点：%d处产出，%d处失守" % [
			resource_site_summary.get("production", []).size(),
			resource_site_summary.get("lost_sites", []).size(),
		],
		"领地刷新：%d宗门，%d处争议点" % [
			int(territory_summary.get("sect_count", 0)),
			int(territory_summary.get("contested_points", 0)),
		],
		"外交关系：%d组｜有效契约：%d" % [int(diplomacy_summary.get("relation_count", 0)), int(diplomacy_summary.get("active_pacts", 0))],
		"战争行动：%d项推进，%d项结束" % [war_summary.get("progressed", []).size(), war_summary.get("completed", []).size()],
		"警告：" + warning_text,
	]))


func _format_production(production: Dictionary) -> String:
	if production.is_empty():
		return "无"
	var resource_names: Dictionary = {
		"food": "粮食",
		"wood": "木材",
		"ore": "灵矿",
		"herb": "灵草",
	}
	var parts: PackedStringArray = PackedStringArray()
	for resource_key in ["food", "wood", "ore", "herb"]:
		if production.has(resource_key):
			parts.append("%s+%d" % [resource_names[resource_key], int(production[resource_key])])
	return "，".join(parts)


func _refresh_pending_event_panel(result_message: String = "") -> void:
	for child in event_option_box.get_children():
		event_option_box.remove_child(child)
		child.queue_free()
	var pending_events: Array[Dictionary] = EventManager.get_pending_events()
	if pending_events.is_empty():
		pending_event_panel.visible = result_message != ""
		event_title_label.text = "事件结果" if result_message != "" else ""
		event_description_label.text = ""
		event_result_label.text = result_message
		return
	var event_data: Dictionary = pending_events[0]
	pending_event_panel.visible = true
	event_title_label.text = "待处理事件：" + str(event_data.get("title", "未命名事件"))
	event_description_label.text = str(event_data.get("description", ""))
	event_result_label.text = result_message
	for option in event_data.get("options", []):
		var option_button := Button.new()
		option_button.text = str(option.get("label", "选择"))
		option_button.pressed.connect(_on_event_option_pressed.bind(
			str(event_data.get("instance_id", "")),
			str(option.get("id", ""))
		))
		event_option_box.add_child(option_button)


func _on_event_option_pressed(instance_id: String, option_id: String) -> void:
	var result: Dictionary = EventManager.resolve_event(instance_id, option_id)
	var result_message: String = str(result.get("message", "事件处理失败。"))
	_refresh_player_sect_info()
	_refresh_resource_panel()
	if disciple_section.visible:
		_refresh_disciple_roster()
	_refresh_pending_event_panel(result_message)


func _on_back_button_pressed() -> void:
	SceneManager.go_to_world_map()


func _on_disciple_button_pressed() -> void:
	placeholder_label.visible = false
	history_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false
	disciple_section.visible = true
	_refresh_disciple_roster()


func _on_building_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = false
	history_section.visible = false
	save_load_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false
	building_section.visible = true
	building_result_label.text = ""
	_refresh_building_section()


func _on_resource_button_pressed() -> void:
	_refresh_resource_panel()
	placeholder_label.visible = false
	disciple_section.visible = false
	history_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false
	resource_site_section.visible = true
	resource_site_result_label.text = ""
	_refresh_resource_site_section()


func _show_placeholder(message: String) -> void:
	placeholder_label.visible = true
	placeholder_label.text = message
	disciple_section.visible = false
	history_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false


func _on_history_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false
	history_section.visible = true
	_refresh_history_list()


func _refresh_history_list() -> void:
	for child in history_list.get_children():
		history_list.remove_child(child)
		child.queue_free()
	var entries: Array[Dictionary] = GameHistoryManager.get_all_entries()
	entries.reverse()
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无历史记录。"
		history_list.add_child(empty_label)
		return
	for entry in entries.slice(0, mini(entries.size(), 100)):
		var entry_label := Label.new()
		entry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry_label.text = "第%d年%d月%d日｜%s｜%s" % [
			int(entry.get("year", 1)),
			int(entry.get("month", 1)),
			int(entry.get("day", 1)),
			str(entry.get("title", "记录")),
			str(entry.get("message", "")),
		]
		history_list.add_child(entry_label)


func _on_mission_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = false
	history_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false
	mission_section.visible = true
	mission_result_label.text = ""
	_refresh_mission_section()


func _refresh_mission_section() -> void:
	_setup_secret_realm_options()
	_on_mission_option_selected(mission_option.selected)
	_clear_dynamic_children(available_disciple_list)
	_clear_dynamic_children(active_mission_list)
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	var sect_id: String = str(player_sect.get("sect_id", ""))
	var valid_selected_ids: Array[String] = []
	for disciple_id in selected_mission_disciple_ids:
		var selected_disciple: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
		if not selected_disciple.is_empty() and not bool(selected_disciple.get("is_deployed", false)):
			valid_selected_ids.append(disciple_id)
	selected_mission_disciple_ids = valid_selected_ids

	for disciple_data in WorldDataManager.get_disciples_by_sect_id(sect_id):
		var disciple_id: String = str(disciple_data.get("disciple_id", ""))
		var check_box := CheckBox.new()
		check_box.text = "%s｜%s｜战力%d%s" % [
			str(disciple_data.get("disciple_name", disciple_id)),
			str(disciple_data.get("realm", "未知")),
			int(disciple_data.get("combat_power", 0)),
			"｜派遣中" if bool(disciple_data.get("is_deployed", false)) else "",
		]
		check_box.button_pressed = disciple_id in selected_mission_disciple_ids
		check_box.disabled = bool(disciple_data.get("is_deployed", false))
		check_box.toggled.connect(_on_mission_disciple_toggled.bind(disciple_id))
		available_disciple_list.add_child(check_box)

	var active_missions: Array[Dictionary] = MissionManager.get_active_missions(sect_id)
	if active_missions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无进行中的任务。"
		active_mission_list.add_child(empty_label)
	else:
		for mission_data in active_missions:
			var mission_label := Label.new()
			mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mission_label.text = "%s｜剩余%d日｜成功率%.1f%%" % [
				str(mission_data.get("display_name", "任务")),
				int(mission_data.get("remaining_days", 0)),
				float(mission_data.get("success_chance", 0.0)) * 100.0,
			]
			active_mission_list.add_child(mission_label)
	selected_team_label.text = "已选弟子：%d｜任务容量：%d（进行中%d）" % [
		selected_mission_disciple_ids.size(),
		ModifierManager.get_mission_capacity(sect_id),
		active_missions.size(),
	]


func _on_mission_disciple_toggled(selected: bool, disciple_id: String) -> void:
	if selected and disciple_id not in selected_mission_disciple_ids:
		selected_mission_disciple_ids.append(disciple_id)
	elif not selected:
		selected_mission_disciple_ids.erase(disciple_id)
	selected_team_label.text = "已选弟子：%d" % selected_mission_disciple_ids.size()


func _on_start_mission_pressed() -> void:
	if mission_option.selected < 0 or mission_option.selected >= mission_definition_ids.size():
		mission_result_label.text = "请选择任务。"
		return
	if selected_mission_disciple_ids.is_empty():
		mission_result_label.text = "请至少选择一名可用弟子。"
		return
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	var result: Dictionary = MissionManager.create_and_start_mission(
		str(player_sect.get("sect_id", "")),
		selected_mission_disciple_ids,
		mission_definition_ids[mission_option.selected],
		_get_selected_mission_context()
	)
	mission_result_label.text = str(result.get("message", "任务派遣失败。"))
	if bool(result.get("success", false)):
		selected_mission_disciple_ids.clear()
	_refresh_resource_panel()
	_refresh_mission_section()


func _get_selected_mission_context() -> Dictionary:
	if not secret_realm_option.visible:
		return {}
	if secret_realm_option.selected < 0 or secret_realm_option.selected >= secret_realm_ids.size():
		return {}
	return {"secret_realm_id": secret_realm_ids[secret_realm_option.selected]}


func _clear_dynamic_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_resource_site_section() -> void:
	var previous_id: int = _get_selected_resource_site_id()
	resource_site_option.clear()
	resource_site_ids.clear()
	var sites: Array[Dictionary] = ResourceSiteManager.get_discovered_sites("sect_001")
	for site in sites:
		var resource_id: int = int(site.get("resource_id", 0))
		resource_site_ids.append(resource_id)
		resource_site_option.add_item("#%d %s Lv%d｜%s" % [
			resource_id,
			str(site.get("resource_name", "资源点")),
			int(site.get("level", 1)),
			_resource_site_status_text(str(site.get("status", "unclaimed"))),
		])
	var selected_index: int = 0
	if previous_id in resource_site_ids:
		selected_index = resource_site_ids.find(previous_id)
	resource_site_option.select(selected_index)
	_refresh_resource_site_detail()
	_refresh_owned_resource_sites()


func _refresh_resource_site_detail() -> void:
	_clear_dynamic_children(resource_site_disciple_list)
	var resource_id: int = _get_selected_resource_site_id()
	var site: Dictionary = ResourceSiteManager.get_site_by_id(resource_id)
	if site.is_empty():
		resource_site_info_label.text = "暂无可管理资源点。"
		return
	var garrison_ids: Array = site.get("garrison_disciple_ids", [])
	var valid_selection: Array[String] = []
	for disciple_id in selected_resource_disciple_ids:
		var data: Dictionary = WorldDataManager.get_disciple_by_id(disciple_id)
		if not data.is_empty() and (not bool(data.get("is_deployed", false)) or disciple_id in garrison_ids):
			valid_selection.append(disciple_id)
	selected_resource_disciple_ids = valid_selection
	for disciple_data in WorldDataManager.get_player_disciples():
		var disciple_id: String = str(disciple_data.get("disciple_id", ""))
		var is_current_garrison: bool = disciple_id in garrison_ids
		var check_box := CheckBox.new()
		check_box.text = "%s｜战力%d%s" % [
			str(disciple_data.get("disciple_name", disciple_id)),
			int(disciple_data.get("combat_power", 0)),
			"｜当前驻守" if is_current_garrison else ("｜派遣中" if bool(disciple_data.get("is_deployed", false)) else ""),
		]
		check_box.button_pressed = disciple_id in selected_resource_disciple_ids
		check_box.disabled = bool(disciple_data.get("is_deployed", false)) and not is_current_garrison
		check_box.toggled.connect(_on_resource_disciple_toggled.bind(disciple_id))
		resource_site_disciple_list.add_child(check_box)
	var owner_id: String = str(site.get("owner_sect_id", ""))
	resource_site_info_label.text = "储量%d｜距离%.0f｜风险%.0f%%｜归属%s｜驻守%d人｜维护缺口%d日" % [
		int(site.get("amount", 0)),
		float(site.get("distance", 0.0)),
		float(site.get("risk", 0.0)) * 100.0,
		"无主" if owner_id == "" else str(WorldDataManager.get_sect_by_id(owner_id).get("sect_name", owner_id)),
		garrison_ids.size(),
		int(site.get("maintenance_shortage_days", 0)),
	]
	var unclaimed: bool = owner_id == ""
	resource_site_clear_button.disabled = not unclaimed
	resource_site_negotiate_button.disabled = not unclaimed
	resource_site_assign_button.disabled = owner_id != "sect_001"
	resource_site_withdraw_button.disabled = owner_id != "sect_001" or garrison_ids.is_empty()


func _refresh_owned_resource_sites() -> void:
	_clear_dynamic_children(owned_resource_site_list)
	var owned_sites: Array[Dictionary] = ResourceSiteManager.get_owned_sites("sect_001")
	if owned_sites.is_empty():
		var empty_label := Label.new()
		empty_label.text = "尚未占领资源点。"
		owned_resource_site_list.add_child(empty_label)
		return
	for site in owned_sites:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "#%d %s｜%s｜储量%d｜驻守%d人" % [
			int(site.get("resource_id", 0)),
			str(site.get("resource_name", "资源点")),
			_resource_site_status_text(str(site.get("status", ""))),
			int(site.get("amount", 0)),
			site.get("garrison_disciple_ids", []).size(),
		]
		owned_resource_site_list.add_child(label)


func _on_resource_site_selected(_index: int) -> void:
	selected_resource_disciple_ids.clear()
	_refresh_resource_site_detail()


func _on_resource_disciple_toggled(selected: bool, disciple_id: String) -> void:
	if selected and disciple_id not in selected_resource_disciple_ids:
		selected_resource_disciple_ids.append(disciple_id)
	elif not selected:
		selected_resource_disciple_ids.erase(disciple_id)


func _on_resource_site_capture(approach: String) -> void:
	if selected_resource_disciple_ids.is_empty():
		resource_site_result_label.text = "请先选择执行占领任务的弟子。"
		return
	var result: Dictionary = ResourceSiteManager.start_capture(
		_get_selected_resource_site_id(), "sect_001", selected_resource_disciple_ids, approach
	)
	resource_site_result_label.text = str(result.get("message", "占领任务派遣失败。"))
	if bool(result.get("success", false)):
		selected_resource_disciple_ids.clear()
	_refresh_resource_site_section()


func _on_resource_site_assign_garrison() -> void:
	var result: Dictionary = ResourceSiteManager.assign_garrison(
		_get_selected_resource_site_id(), "sect_001", selected_resource_disciple_ids
	)
	resource_site_result_label.text = str(result.get("message", "驻守指派失败。"))
	if bool(result.get("success", false)):
		selected_resource_disciple_ids.clear()
	_refresh_resource_site_section()


func _on_resource_site_withdraw_garrison() -> void:
	var success: bool = ResourceSiteManager.withdraw_garrison(_get_selected_resource_site_id(), "sect_001")
	resource_site_result_label.text = "驻守队伍已撤回。" if success else "驻守撤回失败。"
	selected_resource_disciple_ids.clear()
	_refresh_resource_site_section()


func _get_selected_resource_site_id() -> int:
	if resource_site_option.selected < 0 or resource_site_option.selected >= resource_site_ids.size():
		return 0
	return resource_site_ids[resource_site_option.selected]


func _resource_site_status_text(status: String) -> String:
	return {
		"unclaimed": "无主",
		"occupied_unsecured": "待驻守",
		"occupied": "生产中",
		"depleted": "已枯竭",
	}.get(status, status)


func _on_diplomacy_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = false
	history_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	inventory_section.visible = false
	diplomacy_section.visible = true
	diplomacy_result_label.text = ""
	_setup_diplomacy_options()
	_refresh_diplomacy_section()


func _setup_diplomacy_options() -> void:
	var previous_target: String = _get_selected_diplomacy_target()
	diplomacy_target_option.clear()
	diplomacy_target_ids.clear()
	for sect in WorldDataManager.get_ai_sects():
		var sect_id: String = str(sect.get("sect_id", ""))
		diplomacy_target_ids.append(sect_id)
		diplomacy_target_option.add_item(str(sect.get("sect_name", sect_id)))
	if previous_target in diplomacy_target_ids:
		diplomacy_target_option.select(diplomacy_target_ids.find(previous_target))
	else:
		diplomacy_target_option.select(0)
	diplomacy_action_option.clear()
	diplomacy_action_ids.clear()
	for definition in DiplomaticActionRegistry.get_all():
		diplomacy_action_ids.append(definition.id)
		diplomacy_action_option.add_item(definition.display_name)
	diplomacy_action_option.select(0)


func _refresh_diplomacy_section() -> void:
	_clear_dynamic_children(diplomacy_relation_list)
	var target_id: String = _get_selected_diplomacy_target()
	var relation: Dictionary = DiplomacyManager.get_relation("sect_001", target_id)
	var definition: DiplomaticActionDefinition = _get_selected_diplomacy_action()
	var acceptance: float = DiplomacyManager.calculate_acceptance("sect_001", target_id, definition) if definition != null and not relation.is_empty() else 0.0
	diplomacy_relation_info_label.text = "当前目标：%s｜关系值%d｜状态%s｜信任%d｜紧张%d｜行动预计接受率%.1f%%" % [
		str(WorldDataManager.get_sect_by_id(target_id).get("sect_name", target_id)),
		int(relation.get("value", 0)),
		_diplomacy_status_text(str(relation.get("status", "neutral"))),
		int(relation.get("trust", 0)),
		int(relation.get("tension", 0)),
		acceptance * 100.0,
	]
	var status: String = str(relation.get("status", "neutral"))
	diplomacy_alliance_button.disabled = status in ["alliance", "vassal", "war"] or int(relation.get("value", 0)) < 50 or int(relation.get("trust", 0)) < 60
	diplomacy_non_aggression_button.disabled = status in ["alliance", "vassal", "war", "truce"] or int(relation.get("value", 0)) < 0
	diplomacy_vassal_button.disabled = status in ["alliance", "vassal", "war"]
	diplomacy_war_button.disabled = status == "war"
	diplomacy_peace_button.disabled = status != "war"
	for relation_view in DiplomacyManager.get_relations_for_sect("sect_001"):
		var other_id: String = str(relation_view.get("other_sect_id", ""))
		var label := Label.new()
		label.text = "%s｜%s｜关系%d｜信任%d｜紧张%d" % [
			str(WorldDataManager.get_sect_by_id(other_id).get("sect_name", other_id)),
			_diplomacy_status_text(str(relation_view.get("status", "neutral"))),
			int(relation_view.get("value", 0)),
			int(relation_view.get("trust", 0)),
			int(relation_view.get("tension", 0)),
		]
		diplomacy_relation_list.add_child(label)


func _on_diplomacy_selection_changed(_index: int) -> void:
	if diplomacy_section.visible:
		_refresh_diplomacy_section()


func _on_diplomacy_execute_pressed() -> void:
	var definition: DiplomaticActionDefinition = _get_selected_diplomacy_action()
	if definition == null:
		diplomacy_result_label.text = "请选择外交行动。"
		return
	var result: Dictionary = DiplomacyManager.perform_action("sect_001", _get_selected_diplomacy_target(), definition.id)
	diplomacy_result_label.text = str(result.get("message", "外交行动执行失败。"))
	_refresh_resource_panel()
	_refresh_diplomacy_section()


func _on_diplomacy_pact_pressed(pact_action: String) -> void:
	var target_id: String = _get_selected_diplomacy_target()
	var result: Dictionary = {}
	match pact_action:
		"alliance": result = DiplomacyManager.propose_alliance("sect_001", target_id)
		"non_aggression": result = DiplomacyManager.sign_non_aggression("sect_001", target_id)
		"vassal": result = DiplomacyManager.establish_vassal("sect_001", target_id)
		"war": result = DiplomacyManager.declare_war("sect_001", target_id, "player_declaration")
		"peace": result = DiplomacyManager.offer_peace("sect_001", target_id)
	diplomacy_result_label.text = str(result.get("message", "外交契约操作失败。"))
	_refresh_diplomacy_section()


func _get_selected_diplomacy_target() -> String:
	if diplomacy_target_option.selected < 0 or diplomacy_target_option.selected >= diplomacy_target_ids.size():
		return ""
	return diplomacy_target_ids[diplomacy_target_option.selected]


func _get_selected_diplomacy_action() -> DiplomaticActionDefinition:
	if diplomacy_action_option.selected < 0 or diplomacy_action_option.selected >= diplomacy_action_ids.size():
		return null
	return DiplomaticActionRegistry.get_by_id(diplomacy_action_ids[diplomacy_action_option.selected])


func _diplomacy_status_text(status: String) -> String:
	return {
		"self": "自身",
		"friendly": "友好",
		"neutral": "中立",
		"tense": "紧张",
		"hostile": "敌对",
		"alliance": "联盟",
		"vassal": "附属",
		"war": "战争",
		"truce": "停战",
	}.get(status, status)


func _on_inventory_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = false
	history_section.visible = false
	save_load_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = true
	inventory_message = ""
	_refresh_inventory_section()


func _refresh_inventory_section() -> void:
	_clear_dynamic_children(inventory_item_list)
	_clear_dynamic_children(inventory_recipe_list)
	var item_title := Label.new()
	item_title.text = "宗门物品"
	item_title.add_theme_font_size_override("font_size", 20)
	inventory_item_list.add_child(item_title)
	for definition in ItemRegistry.get_all():
		var label := Label.new()
		label.text = "%s｜%s｜数量%d｜基础价值%d" % [
			definition.display_name,
			_item_category_text(definition.category),
			InventoryManager.get_item_count("sect_001", definition.id),
			definition.base_value,
		]
		inventory_item_list.add_child(label)
	var recipe_title := Label.new()
	recipe_title.text = "已知配方与制作｜" + (inventory_message if inventory_message != "" else "选择配方开始制作")
	recipe_title.add_theme_font_size_override("font_size", 20)
	inventory_recipe_list.add_child(recipe_title)
	for recipe in RecipeRegistry.get_all():
		var recipe_button := Button.new()
		recipe_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		recipe_button.text = "%s｜%s｜材料：%s｜产物：%s｜%d日｜当前材料%s" % [
			recipe.display_name,
			_craft_type_text(recipe.craft_type),
			_format_item_requirements(recipe.ingredients),
			_format_item_requirements(recipe.outputs),
			recipe.duration_days,
			"充足" if InventoryManager.has_items("sect_001", recipe.ingredients) else "不足",
		]
		recipe_button.disabled = not InventoryManager.has_items("sect_001", recipe.ingredients) or _find_crafting_worker(recipe).is_empty()
		recipe_button.pressed.connect(_on_recipe_craft_pressed.bind(recipe.id))
		inventory_recipe_list.add_child(recipe_button)
	for job in CraftingManager.get_jobs("sect_001", true):
		var job_label := Label.new()
		var recipe: RecipeDefinition = RecipeRegistry.get_by_id(str(job.get("recipe_id", "")))
		job_label.text = "制作中：%s｜负责弟子%s｜剩余%d日｜成功率%.1f%%" % [
			recipe.display_name if recipe != null else str(job.get("recipe_id", "")),
			str(WorldDataManager.get_disciple_by_id(str(job.get("disciple_id", ""))).get("disciple_name", "")),
			int(job.get("remaining_days", 0)),
			float(job.get("success_chance", 0.0)) * 100.0,
		]
		inventory_recipe_list.add_child(job_label)


func _on_recipe_craft_pressed(recipe_id: String) -> void:
	var recipe: RecipeDefinition = RecipeRegistry.get_by_id(recipe_id)
	var worker: Dictionary = _find_crafting_worker(recipe)
	if worker.is_empty():
		inventory_message = "没有符合条件的可用弟子。"
	else:
		var result: Dictionary = CraftingManager.start_crafting("sect_001", recipe_id, str(worker.get("disciple_id", "")))
		inventory_message = str(result.get("message", "制作启动失败。"))
	_refresh_resource_panel()
	_refresh_inventory_section()


func _find_crafting_worker(recipe: RecipeDefinition) -> Dictionary:
	if recipe == null:
		return {}
	for disciple in WorldDataManager.get_player_disciples():
		if bool(disciple.get("is_deployed", false)) or int(disciple.get("health", 0)) <= 0:
			continue
		var matches: bool = true
		for required_tag in recipe.required_disciple_tags:
			if required_tag not in disciple.get("tags", []):
				matches = false
				break
		if matches:
			return disciple
	return {}


func _format_item_requirements(items: Dictionary) -> String:
	var parts := PackedStringArray()
	for item_id in items:
		var definition: ItemDefinition = ItemRegistry.get_by_id(str(item_id))
		parts.append("%s×%d" % [definition.display_name if definition != null else str(item_id), int(items[item_id])])
	return "、".join(parts)


func _item_category_text(category: String) -> String:
	return {"material": "材料", "consumable": "消耗品", "equipment": "装备", "advanced_material": "高级材料"}.get(category, category)


func _craft_type_text(craft_type: String) -> String:
	return {"alchemy": "炼丹", "forging": "炼器", "array": "阵法"}.get(craft_type, craft_type)


func _on_save_load_button_pressed() -> void:
	placeholder_label.visible = false
	disciple_section.visible = false
	history_section.visible = false
	building_section.visible = false
	mission_section.visible = false
	resource_site_section.visible = false
	diplomacy_section.visible = false
	inventory_section.visible = false
	save_load_section.visible = true
	save_load_result_label.text = ""
	_refresh_save_slots()


func _on_manual_save_pressed(slot_index: int) -> void:
	_show_save_result(SaveManager.save_manual_slot(slot_index), "存档槽%d保存成功。" % slot_index)
	_refresh_save_slots()


func _on_manual_load_pressed(slot_index: int) -> void:
	_handle_load_result(SaveManager.load_manual_slot(slot_index))


func _on_quick_save_pressed() -> void:
	_show_save_result(SaveManager.quick_save(), "快速存档成功。")
	_refresh_save_slots()


func _on_quick_load_pressed() -> void:
	_handle_load_result(SaveManager.quick_load())


func _on_autosave_load_pressed() -> void:
	_handle_load_result(SaveManager.load_autosave())


func _show_save_result(result: Dictionary, success_message: String) -> void:
	save_load_result_label.text = success_message if bool(result.get("success", false)) else str(result.get("message", "操作失败。"))


func _handle_load_result(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		save_load_result_label.text = str(result.get("message", "读档失败。"))
		return
	SceneManager.go_to_world_map()


func _refresh_save_slots() -> void:
	var summaries: Array[Dictionary] = SaveManager.get_slot_summaries()
	var summary_by_id: Dictionary = {}
	for summary in summaries:
		summary_by_id[str(summary.get("slot_id", ""))] = summary
	_update_slot_row(manual_slot_1_label, manual_slot_1_load, "存档槽1", summary_by_id.get("manual_1", {}))
	_update_slot_row(manual_slot_2_label, manual_slot_2_load, "存档槽2", summary_by_id.get("manual_2", {}))
	_update_slot_row(manual_slot_3_label, manual_slot_3_load, "存档槽3", summary_by_id.get("manual_3", {}))
	_update_slot_row(quick_slot_label, quick_load_button, "快速存档", summary_by_id.get("quick", {}))
	_update_slot_row(autosave_slot_label, autosave_load_button, "自动存档", summary_by_id.get("autosave", {}))


func _update_slot_row(label: Label, load_button: Button, prefix: String, summary: Dictionary) -> void:
	var exists: bool = bool(summary.get("exists", false))
	load_button.disabled = not exists
	if not exists:
		label.text = prefix + "：空"
		return
	var state: Dictionary = summary.get("game_state", {})
	label.text = "%s：第%d年%d月%d日" % [
		prefix,
		int(state.get("year", 1)),
		int(state.get("month", 1)),
		int(state.get("day", 1)),
	]


func _refresh_building_section() -> void:
	for child in building_list.get_children():
		building_list.remove_child(child)
		child.queue_free()
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	if player_sect.is_empty():
		return
	var sect_id: String = str(player_sect["sect_id"])
	var upgrade_preview: Dictionary = SectManager.get_sect_upgrade_preview(sect_id)
	sect_level_label.text = "宗门等级：%d｜大殿等级：%d｜升级消耗：%s" % [
		int(upgrade_preview.get("current_level", 1)),
		int(upgrade_preview.get("hall_level", 0)),
		_format_building_costs(upgrade_preview.get("costs", {})),
	]
	sect_upgrade_button.disabled = not bool(upgrade_preview.get("can_upgrade", false))
	var instance_by_definition: Dictionary = {}
	for instance in ConstructionManager.get_buildings_by_sect_id(sect_id):
		instance_by_definition[str(instance.get("definition_id", ""))] = instance
	for definition in BuildingRegistry.get_all():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var instance: Dictionary = instance_by_definition.get(definition.id, {})
		var target_level: int = 1
		var status_text: String = "未建设"
		if not instance.is_empty():
			target_level = int(instance.get("level", 0)) + 1
			if str(instance.get("status", "")) == "constructing":
				status_text = "建设中，剩余%d日" % int(instance.get("remaining_days", 0))
				target_level = int(instance.get("target_level", 1))
			else:
				status_text = "等级%d%s" % [
					int(instance.get("level", 1)),
					"" if bool(instance.get("operational", true)) else "（维护不足，已停运）",
				]
		var costs: Dictionary = ConstructionManager.get_construction_costs(definition, target_level)
		info.text = "%s｜%s｜%d日｜%s" % [
			definition.display_name,
			status_text,
			ConstructionManager.get_construction_days(definition, target_level),
			_format_building_costs(costs),
		]
		var action_button := Button.new()
		action_button.text = "升级" if not instance.is_empty() and str(instance.get("status", "")) == "active" else "建设"
		action_button.disabled = str(instance.get("status", "")) == "constructing" or target_level > definition.max_level
		action_button.pressed.connect(_on_building_action_pressed.bind(definition.id))
		row.add_child(info)
		row.add_child(action_button)
		building_list.add_child(row)


func _on_building_action_pressed(building_id: String) -> void:
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	var result: Dictionary = ConstructionManager.start_construction(str(player_sect.get("sect_id", "")), building_id)
	building_result_label.text = str(result.get("message", "建设请求失败。"))
	_refresh_resource_panel()
	_refresh_building_section()


func _on_sect_upgrade_pressed() -> void:
	var player_sect: Dictionary = WorldDataManager.get_player_sect()
	var result: Dictionary = SectManager.upgrade_sect(str(player_sect.get("sect_id", "")))
	building_result_label.text = str(result.get("message", "宗门升级失败。"))
	_refresh_player_sect_info()
	_refresh_resource_panel()
	_refresh_building_section()


func _format_building_costs(costs: Dictionary) -> String:
	var names: Dictionary = {
		"spirit_stone": "灵石", "food": "粮食", "wood": "木材", "stone": "石材",
		"spirit_grass": "灵草", "spirit_ore": "灵矿",
	}
	var parts := PackedStringArray()
	for resource_key in costs:
		parts.append("%s%d" % [str(names.get(resource_key, resource_key)), int(costs[resource_key])])
	return "、".join(parts)


func _on_disciple_filter_changed(_new_text: String) -> void:
	_refresh_disciple_roster()


func _on_disciple_option_changed(_index: int) -> void:
	_refresh_disciple_roster()


func _on_apply_assignment_button_pressed() -> void:
	if current_selected_disciple_id == "":
		assignment_box.visible = true
		assignment_result_label.text = "请先选择弟子"
		return

	var selected_assignment: String = _get_selected_assignment_text()
	var updated_disciple_id: String = current_selected_disciple_id
	var update_success: bool = DiscipleManager.update_assignment(updated_disciple_id, selected_assignment)

	if not update_success:
		assignment_result_label.text = "安排更新失败"
		return

	var selected_still_visible: bool = _is_disciple_visible_in_current_filter(updated_disciple_id)
	_refresh_disciple_roster()

	if selected_still_visible:
		assignment_result_label.text = "安排已更新"
	else:
		detail_hint_label.text = "安排已更新；当前筛选条件下该弟子已隐藏。"


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


func _is_disciple_visible_in_current_filter(disciple_id: String) -> bool:
	for disciple_data in _get_visible_disciples():
		if str(disciple_data["disciple_id"]) == disciple_id:
			return true
	return false


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
	var definition: RealmDefinition = RealmRegistry.get_by_id(
		RealmRegistry.get_id_by_display_name(realm)
	)
	return definition.order if definition != null else -1


func _clear_disciple_list() -> void:
	for child in disciple_list_container.get_children():
		disciple_list_container.remove_child(child)
		child.queue_free()


func _get_disciple_row_text(disciple_data: Dictionary) -> String:
	var realm_text: String = str(disciple_data["realm"])
	if bool(disciple_data.get("at_bottleneck", false)):
		realm_text += "（瓶颈）"
	return "%s｜%s｜%s｜%s｜%s｜%s｜战力 %s｜%s" % [
		str(disciple_data["disciple_name"]),
		str(disciple_data["role"]),
		realm_text,
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
	assignment_box.visible = false
	assignment_result_label.text = ""
	breakthrough_box.visible = false
	breakthrough_preview_label.text = ""
	breakthrough_result_label.text = ""
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
	var realm_id: String = str(disciple_data.get(
		"realm_id",
		RealmRegistry.get_id_by_display_name(str(disciple_data.get("realm", "凡人")))
	))
	var definition: RealmDefinition = RealmRegistry.get_by_id(realm_id)
	var cultivation_required: int = definition.cultivation_required if definition != null else 0
	var cultivation_value: int = int(disciple_data.get("cultivation", 0))
	var bottleneck_text: String = "瓶颈，等待突破" if bool(disciple_data.get("at_bottleneck", false)) else "修炼中"
	assignment_box.visible = true
	breakthrough_box.visible = true
	assignment_result_label.text = ""
	breakthrough_result_label.text = ""
	_select_assignment_option(str(disciple_data["assignment"]))
	model_preview_label.text = "人物模型预览\n共享模板后续接入"
	disciple_name_label.text = str(disciple_data["disciple_name"])
	basic_info_label.text = "\n".join(PackedStringArray([
		"基础信息：",
		"性别：" + str(disciple_data["gender"]),
		"年龄：" + str(disciple_data["age"]),
		"职位：" + str(disciple_data["role"]),
		"修为：" + str(disciple_data["realm"]),
		"修为进度：%d / %d" % [cultivation_value, cultivation_required],
		"修炼状态：" + bottleneck_text,
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
	_refresh_breakthrough_preview(str(disciple_data["disciple_id"]))
	detail_description_label.text = "介绍：" + str(disciple_data["description"])
	detail_hint_label.text = "本页只展示弟子名册、共享模板 ID 与战斗预留字段；不生成头像、不创建战斗单位。"


func _select_assignment_option(assignment: String) -> void:
	var selected_index: int = 0
	for index in range(assignment_option.item_count):
		if assignment_option.get_item_text(index) == assignment:
			selected_index = index
			break
	assignment_option.select(selected_index)


func _get_selected_assignment_text() -> String:
	if assignment_option.selected < 0:
		return DiscipleManager.ASSIGNMENT_IDLE
	return assignment_option.get_item_text(assignment_option.selected)


func _on_breakthrough_button_pressed() -> void:
	if current_selected_disciple_id == "":
		breakthrough_result_label.text = "请先选择弟子。"
		return
	var result: Dictionary = BreakthroughManager.attempt_breakthrough(current_selected_disciple_id)
	_refresh_resource_panel()
	_refresh_disciple_roster()
	var chance_text: String = ""
	if bool(result.get("attempted", false)):
		chance_text = "（成功率%.1f%%，判定%.1f%%）" % [
			float(result.get("chance", 0.0)) * 100.0,
			float(result.get("roll", 0.0)) * 100.0,
		]
	breakthrough_result_label.text = str(result.get("message", "突破请求失败。")) + chance_text


func _refresh_breakthrough_preview(disciple_id: String) -> void:
	var preview: Dictionary = BreakthroughManager.get_breakthrough_preview(disciple_id)
	if preview.is_empty():
		breakthrough_preview_label.text = "无法读取突破条件。"
		breakthrough_button.disabled = true
		return
	var missing: Dictionary = preview.get("missing_resources", {})
	var has_next_realm: bool = str(preview.get("next_realm", "无")) != "无"
	var health_ready: bool = int(preview.get("health", 0)) >= int(preview.get("minimum_health", 0))
	var ready: bool = (
		bool(preview.get("at_bottleneck", false))
		and has_next_realm
		and health_ready
		and missing.is_empty()
	)
	breakthrough_button.disabled = not ready
	breakthrough_preview_label.text = "下一境界：%s｜成功率：%.1f%%\n消耗：%s｜健康要求：%d（当前%d）%s" % [
		str(preview.get("next_realm", "无")),
		float(preview.get("success_rate", 0.0)) * 100.0,
		_format_breakthrough_costs(preview.get("costs", {})),
		int(preview.get("minimum_health", 0)),
		int(preview.get("health", 0)),
		"｜资源不足" if not missing.is_empty() else "",
	]


func _format_breakthrough_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "无"
	var names: Dictionary = {
		"spirit_stone": "灵石",
		"spirit_grass": "灵草",
		"spirit_ore": "灵矿",
		"food": "粮食",
		"wood": "木材",
		"stone": "石材",
	}
	var parts := PackedStringArray()
	for resource_key in costs:
		parts.append("%s%d" % [str(names.get(resource_key, resource_key)), int(costs[resource_key])])
	return "、".join(parts)


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
