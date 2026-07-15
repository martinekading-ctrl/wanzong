extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")
const THEME_PATH := "res://assets/ui/wanzong_theme.tres"
const HUD_SCENE_PATH := "res://scenes/ui/components/WorldHUD.tscn"
const WORLD_SCENE_PATH := "res://scenes/world/World.tscn"
const UNAVAILABLE_NAVIGATION_TOOLTIP := "将在青玄宗经营垂直切片的后续步骤开放"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_theme_and_scene_contract()
	await _test_edge_anchored_layouts()
	await _test_world_data_and_interactions()
	_test_stable_world_data()
	if _failures.is_empty():
		print("[Task0067WorldHUDLayout] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0067WorldHUDLayout] " + failure)
	quit(1)


func _test_theme_and_scene_contract() -> void:
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "World HUD must use the existing global theme")
	if theme != null:
		for variation in ["WZWorldTopPanel", "WZWorldNavPanel", "WZWorldDetailsPanel", "WZWorldBottomPanel"]:
			_expect(theme.get_stylebox("panel", variation) is StyleBoxFlat, "Panel variation must use StyleBoxFlat: " + variation)
		for variation in ["WZWorldPrimaryButton", "WZWorldSecondaryButton", "WZWorldNavButton", "WZWorldNavButtonSelected", "WZWorldNavButtonDisabled"]:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				_expect(theme.get_stylebox(state, variation) is StyleBoxFlat, "Button state must use StyleBoxFlat: %s/%s" % [variation, state])
		for variation in ["WZWorldTitle", "WZWorldBody", "WZWorldMutedText", "WZWorldResourceText"]:
			_expect(theme.get_font_size("font_size", variation) > 0, "Label variation missing: " + variation)
	var theme_text := FileAccess.get_file_as_string(THEME_PATH)
	var hud_text := FileAccess.get_file_as_string(HUD_SCENE_PATH)
	_expect(not "assets/ui/world_map" in theme_text, "Theme must not reference discarded concept PNG assets")
	_expect(not "assets/ui/world_map" in hud_text, "WorldHUD must not reference discarded concept PNG assets")
	_expect(not "StyleBoxTexture" in theme_text, "World HUD theme baseline must not use StyleBoxTexture")


func _test_edge_anchored_layouts() -> void:
	var scene := load(HUD_SCENE_PATH) as PackedScene
	_expect(scene != null, "WorldHUD scene must load")
	if scene == null:
		return
	var holder := Control.new()
	root.add_child(holder)
	var hud := scene.instantiate() as Control
	holder.add_child(hud)
	await process_frame
	_expect(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "WorldHUD blank root must ignore pointer input")
	for node_path in ["TopBar", "LeftNavigation", "DetailsPanel", "BottomBar", "%SectNameLabel", "%PrimaryActionButton", "%ZoomOutButton", "%FullMapButton"]:
		_expect(hud.get_node_or_null(node_path) != null, "Required HUD node missing: " + node_path)
	var world_button := hud.get_node_or_null("%WorldButton") as Button
	_expect(world_button != null and world_button.button_pressed, "World navigation must be selected by default")
	for node_path in ["%DiscipleButton", "%BuildingButton", "%DiplomacyButton"]:
		var button := hud.get_node_or_null(node_path) as Button
		_expect(button != null and button.disabled, "Unfinished navigation must stay disabled: " + node_path)
		_expect(button != null and button.tooltip_text == UNAVAILABLE_NAVIGATION_TOOLTIP, "Disabled navigation tooltip must be explicit: " + node_path)
	for resolution in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		holder.size = resolution
		hud.call("_apply_responsive_layout")
		await process_frame
		await process_frame
		var top_bar := hud.get_node("TopBar") as Control
		var navigation := hud.get_node("LeftNavigation") as Control
		var details := hud.get_node("DetailsPanel") as Control
		var bottom_bar := hud.get_node("BottomBar") as Control
		for control in [top_bar, navigation, details, bottom_bar]:
			_assert_rect_within(control, resolution, "HUD layout bounds " + control.name)
		_expect(top_bar.size.y <= 80.0, "Top bar must stay within 80 px")
		_expect(bottom_bar.size.y <= 60.0, "Bottom bar must stay within 60 px")
		_expect(navigation.get_global_rect().get_center().x <= resolution.x * 0.15, "Left navigation must stay inside the left 15 percent")
		_expect(details.get_global_rect().size.x <= 360.5, "Details panel must not exceed 360 px")
		_expect(details.get_global_rect().size.x >= 299.5, "Details panel must remain readable")
		var center_rect := Rect2(resolution.x * 0.25, resolution.y * 0.2, resolution.x * 0.5, resolution.y * 0.6)
		for control in [top_bar, navigation, details, bottom_bar]:
			_expect(control.get_global_rect().intersection(center_rect).get_area() < 1.0, "Map center must remain clear: " + control.name)
	holder.queue_free()
	await process_frame


func _test_world_data_and_interactions() -> void:
	var game_state: Node = root.get_node("GameState")
	var world_data: Node = root.get_node("WorldDataManager")
	game_state.call("new_game")
	var scene := load(WORLD_SCENE_PATH) as PackedScene
	_expect(scene != null, "World scene must load")
	if scene == null:
		return
	var world := scene.instantiate() as Node2D
	root.add_child(world)
	await process_frame
	await process_frame
	var hud := world.get_node_or_null("UILayer/WorldHUD") as WorldHUD
	_expect(hud != null, "World must contain WorldHUD")
	_expect(world.get_node_or_null("UILayer/InfoPanel") == null, "Legacy InfoPanel must be absent")
	_expect(not (world.get_node("TerritoryLayer") as Node2D).visible, "TerritoryLayer must be hidden by default")
	if hud == null:
		world.queue_free()
		return
	var overview_text := (hud.get_node("%PrimaryInfoLabel") as Label).text + (hud.get_node("%SecondaryInfoLabel") as Label).text
	_expect("5" in overview_text and "26" in overview_text and "6" in overview_text, "World overview must show the real 5/26/6 counts")
	var player_sect_data: Dictionary = world_data.call("get_player_sect")
	var player_node := world.get_node("SectLayer").get_child(0) as SectNode
	world.call("_on_sect_selected", player_sect_data, player_node)
	_expect((hud.get_node("%PrimaryActionButton") as Button).visible, "Player sect must show Enter Sect action")
	var ai_sect_data: Dictionary = world_data.call("get_all_sects")[1]
	var ai_node := world.get_node("SectLayer").get_child(1) as SectNode
	world.call("_on_sect_selected", ai_sect_data, ai_node)
	_expect(not (hud.get_node("%PrimaryActionButton") as Button).visible, "AI sect must hide Enter Sect action")
	var resource_data: Dictionary = world_data.call("get_all_resources")[0]
	var resource_node := world.get_node("ResourceLayer").get_child(0) as ResourceNode
	world.call("_on_resource_selected", resource_data, resource_node)
	var resource_detail_text := (hud.get_node("%PrimaryInfoLabel") as Label).text + (hud.get_node("%SecondaryInfoLabel") as Label).text + (hud.get_node("%DescriptionLabel") as Label).text
	_expect(not "resource_id" in resource_detail_text, "Resource details must not expose resource_id")
	world.call("_on_world_hud_territory_visibility_requested", true)
	_expect((world.get_node("TerritoryLayer") as Node2D).visible, "Territory switch must show the existing layer")
	world.call("_on_world_hud_territory_visibility_requested", false)
	_expect(not (world.get_node("TerritoryLayer") as Node2D).visible, "Territory switch must hide the existing layer")
	world.queue_free()
	await process_frame


func _test_stable_world_data() -> void:
	var world_data: Node = root.get_node("WorldDataManager")
	var save_manager: Node = root.get_node("SaveManager")
	var save_snapshot: Dictionary = save_manager.call("create_snapshot")
	_expect(int(save_snapshot.get("save_version", 0)) == 1, "Save version must remain 1")
	_expect(WorldSectRoster.ROSTER_VERSION == 2, "World sect roster version must remain 2")
	_expect((world_data.call("get_all_sects") as Array).size() == 5, "World must preserve five sects")
	_expect((world_data.call("get_ai_sects") as Array).size() == 4, "World must preserve four AI sects")
	_expect((world_data.call("get_all_resources") as Array).size() == 26, "World must preserve twenty-six resource nodes")
	_expect((world_data.call("get_all_build_slots") as Array).size() == 6, "World must preserve six build slots")


func _assert_rect_within(control: Control, resolution: Vector2, label: String) -> void:
	if control == null:
		_expect(false, label + " control missing")
		return
	var rect := control.get_global_rect()
	_expect(rect.position.x >= -0.5 and rect.position.y >= -0.5, label + " must not overflow left/top")
	_expect(rect.end.x <= resolution.x + 0.5 and rect.end.y <= resolution.y + 0.5, label + " must not overflow right/bottom")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
