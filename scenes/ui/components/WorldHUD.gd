extends Control
class_name WorldHUD

## WorldHUD only owns display state and player-interface signals. World.gd keeps
## authoritative selection, camera, territory and save logic.

signal enter_sect_requested
signal sect_navigation_requested
signal world_navigation_requested
signal save_requested
signal zoom_requested(amount: float)
signal locate_player_requested
signal territory_visibility_requested(is_visible: bool)
signal full_map_requested

const UNAVAILABLE_NAVIGATION_TOOLTIP := "将在青玄宗经营垂直切片的后续步骤开放"

@onready var sect_name_label: Label = %SectNameLabel
@onready var date_label: Label = %DateLabel
@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var food_label: Label = %FoodLabel
@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var context_label: Label = %ContextLabel
@onready var title_label: Label = %TitleLabel
@onready var badge_label: Label = %BadgeLabel
@onready var primary_info_label: Label = %PrimaryInfoLabel
@onready var secondary_info_label: Label = %SecondaryInfoLabel
@onready var description_label: Label = %DescriptionLabel
@onready var primary_action_button: Button = %PrimaryActionButton
@onready var save_button: Button = %SaveButton
@onready var settings_button: Button = %SettingsButton
@onready var sect_button: Button = %SectButton
@onready var disciple_button: Button = %DiscipleButton
@onready var building_button: Button = %BuildingButton
@onready var world_button: Button = %WorldButton
@onready var diplomacy_button: Button = %DiplomacyButton
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var zoom_in_button: Button = %ZoomInButton
@onready var locate_button: Button = %LocateButton
@onready var territory_button: Button = %TerritoryButton
@onready var full_map_button: Button = %FullMapButton
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	primary_action_button.pressed.connect(func() -> void: enter_sect_requested.emit())
	sect_button.pressed.connect(func() -> void: sect_navigation_requested.emit())
	world_button.pressed.connect(func() -> void: world_navigation_requested.emit())
	save_button.pressed.connect(func() -> void: save_requested.emit())
	zoom_out_button.pressed.connect(func() -> void: zoom_requested.emit(-1.0))
	zoom_in_button.pressed.connect(func() -> void: zoom_requested.emit(1.0))
	locate_button.pressed.connect(func() -> void: locate_player_requested.emit())
	territory_button.toggled.connect(func(value: bool) -> void: territory_visibility_requested.emit(value))
	full_map_button.pressed.connect(func() -> void: full_map_requested.emit())
	_set_unavailable_navigation(disciple_button)
	_set_unavailable_navigation(building_button)
	_set_unavailable_navigation(diplomacy_button)
	settings_button.disabled = true
	settings_button.tooltip_text = "设置界面将在后续步骤开放"
	world_button.set_pressed_no_signal(true)
	set_primary_action_visible(false)
	set_hint("滚轮缩放；中键拖动地图；点击宗门、资源点或建设点查看详情")


func _set_unavailable_navigation(button: Button) -> void:
	button.disabled = true
	button.tooltip_text = UNAVAILABLE_NAVIGATION_TOOLTIP


func set_top_bar(sect_name: String, date_text: String, resource_data: Dictionary) -> void:
	sect_name_label.text = sect_name
	date_label.text = date_text
	spirit_stone_label.text = "灵石 %d" % int(resource_data.get("spirit_stone", 0))
	food_label.text = "粮食 %d" % int(resource_data.get("food", 0))
	wood_label.text = "木材 %d" % int(resource_data.get("wood", 0))
	stone_label.text = "石材 %d" % int(resource_data.get("stone", 0))


func set_details(display_data: Dictionary) -> void:
	context_label.text = str(display_data.get("context", ""))
	title_label.text = str(display_data.get("title", ""))
	badge_label.text = str(display_data.get("badge", ""))
	primary_info_label.text = str(display_data.get("primary", ""))
	secondary_info_label.text = str(display_data.get("secondary", ""))
	description_label.text = str(display_data.get("description", ""))
	set_primary_action_visible(bool(display_data.get("show_primary_action", false)))


func set_primary_action_visible(value: bool) -> void:
	primary_action_button.visible = value


func set_hint(value: String) -> void:
	hint_label.text = value


func set_territory_visible(value: bool) -> void:
	territory_button.set_pressed_no_signal(value)
	territory_button.tooltip_text = "隐藏宗门领地" if value else "显示宗门领地"


func set_save_result(success: bool, message: String) -> void:
	set_hint("存档完成" if success else "存档失败：%s" % message)
