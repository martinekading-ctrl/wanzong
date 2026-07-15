extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")
const ASSET_ROOT := "res://assets/ui/world_map"
const MANIFEST_PATH := ASSET_ROOT + "/manifest/ui_asset_manifest.json"
const THEME_PATH := "res://assets/ui/wanzong_theme.tres"
const HUD_SCENE_PATH := "res://scenes/ui/components/WorldHUD.tscn"
const WORLD_SCENE_PATH := "res://scenes/world/World.tscn"

var required_images := PackedStringArray([
	"res://assets/ui/world_map/emblems/emblem_qingxuan.png",
	"res://assets/ui/world_map/panels/panel_top_resource.png",
	"res://assets/ui/world_map/panels/panel_top_sect.png",
	"res://assets/ui/world_map/panels/panel_navigation.png",
	"res://assets/ui/world_map/panels/panel_details.png",
	"res://assets/ui/world_map/panels/panel_details_group.png",
	"res://assets/ui/world_map/panels/panel_bottom_bar.png",
	"res://assets/ui/world_map/panels/panel_tool_group.png",
	"res://assets/ui/world_map/buttons/button_primary_normal.png",
	"res://assets/ui/world_map/buttons/button_primary_hover.png",
	"res://assets/ui/world_map/buttons/button_primary_pressed.png",
	"res://assets/ui/world_map/buttons/button_primary_disabled.png",
	"res://assets/ui/world_map/buttons/button_nav_normal.png",
	"res://assets/ui/world_map/buttons/button_nav_hover.png",
	"res://assets/ui/world_map/buttons/button_nav_selected.png",
	"res://assets/ui/world_map/buttons/button_nav_disabled.png",
	"res://assets/ui/world_map/decorations/divider_horizontal.png",
	"res://assets/ui/world_map/decorations/jade_diamond.png",
])

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_processed_assets_and_manifest()
	await _test_theme_and_hud_structure()
	await _test_world_hud_integration()
	_test_data_invariants()
	if _failures.is_empty():
		print("[Task0067WorldUIAssets] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0067WorldUIAssets] " + failure)
	quit(1)


func _test_processed_assets_and_manifest() -> void:
	for asset_path in required_images:
		var texture := load(asset_path) as Texture2D
		_expect(texture != null, "Processed asset must load as Texture2D: " + asset_path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
		_expect(image != null and not image.is_empty(), "Processed asset image must exist: " + asset_path)
		if image == null or image.is_empty():
			continue
		var has_transparent_pixel := image.get_pixel(0, 0).a < 0.1
		var has_opaque_pixel := image.get_pixel(image.get_width() / 2, image.get_height() / 2).a > 0.9
		_expect(has_transparent_pixel and has_opaque_pixel, "Processed asset must contain transparent and opaque alpha: " + asset_path)
		_expect(image.get_pixel(0, 0).a < 0.1, "Processed asset corner must be transparent: " + asset_path)
		_expect(image.get_width() > 0 and image.get_height() > 0, "Processed asset dimensions must be positive: " + asset_path)
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest = JSON.parse_string(manifest_text)
	_expect(manifest is Dictionary, "UI asset manifest must be valid JSON")
	if not manifest is Dictionary:
		return
	var manifest_data: Dictionary = manifest
	_expect((manifest_data.get("source_mapping", {}) as Dictionary).size() == 10, "Manifest must map all ten source images")
	_expect((manifest_data.get("assets", []) as Array).size() >= required_images.size(), "Manifest must describe every required processed asset")
	for asset_data_variant in manifest_data.get("assets", []):
		var asset_data: Dictionary = asset_data_variant
		if not asset_data.has("nine_slice_margins"):
			continue
		var size: Array = asset_data.get("processed_size", [])
		var margins: Dictionary = asset_data.get("nine_slice_margins", {})
		_expect(size.size() == 2, "Nine-slice asset must record dimensions")
		if size.size() != 2:
			continue
		_expect(int(margins.get("left", 0)) + int(margins.get("right", 0)) < int(size[0]), "Nine-slice horizontal margins must be legal")
		_expect(int(margins.get("top", 0)) + int(margins.get("bottom", 0)) < int(size[1]), "Nine-slice vertical margins must be legal")


func _test_theme_and_hud_structure() -> void:
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "World UI must extend the existing global theme")
	if theme != null:
		for variation in ["WZWorldTopPanel", "WZWorldTopResourcePanel", "WZWorldNavigationPanel", "WZWorldDetailsPanel", "WZWorldDetailsGroup", "WZWorldBottomPanel"]:
			_expect(theme.get_stylebox("panel", variation) != null, "Panel variation missing: " + variation)
		for variation in ["WZPrimaryTextureButton", "WZNavigationButton", "WZNavigationButtonSelected", "WZNavigationButtonDisabled"]:
			_expect(theme.get_stylebox("normal", variation) != null, "Button variation missing: " + variation)
		for variation in ["WZWorldSectionTitle", "WZWorldBody", "WZWorldMutedText", "WZWorldResourceText"]:
			_expect(theme.get_font_size("font_size", variation) > 0, "Label variation missing: " + variation)
	var scene := load(HUD_SCENE_PATH) as PackedScene
	_expect(scene != null, "WorldHUD scene must load")
	if scene == null:
		return
	var holder := Control.new()
	holder.size = Vector2(1920, 1080)
	root.add_child(holder)
	var hud := scene.instantiate() as Control
	holder.add_child(hud)
	await process_frame
	for node_path in ["TopBar", "LeftNavigation", "DetailsPanel", "BottomBar", "%SectNameLabel", "%SpiritStoneLabel", "%PrimaryActionButton", "%ZoomOutButton", "%FullMapButton"]:
		_expect(hud.get_node_or_null(node_path) != null, "WorldHUD required node missing: " + node_path)
	_expect((hud.get_node("%WorldButton") as Button).button_pressed, "World navigation must be selected by default")
	for node_path in ["%DiscipleButton", "%BuildingButton", "%DiplomacyButton"]:
		var button := hud.get_node(node_path) as Button
		_expect(button.disabled, "Unfinished navigation must stay disabled: " + node_path)
		_expect(button.tooltip_text == "将在青玄宗经营垂直切片的后续步骤开放", "Disabled navigation tooltip must be explicit")
	for resolution in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		holder.size = resolution
		await process_frame
		for node_path in ["TopBar", "LeftNavigation", "DetailsPanel", "BottomBar"]:
			_assert_rect_within(hud.get_node(node_path) as Control, resolution, "HUD layout bounds " + node_path)
	holder.queue_free()
	await process_frame


func _test_world_hud_integration() -> void:
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
	var player_sect_data: Dictionary = world_data.call("get_player_sect")
	var player_node := world.get_node("SectLayer").get_child(0) as SectNode
	world.call("_on_sect_selected", player_sect_data, player_node)
	_expect((hud.get_node("%PrimaryActionButton") as Button).visible, "Player sect must show Enter Sect action")
	_expect("青玄宗" in (hud.get_node("%TitleLabel") as Label).text, "Player sect selection must update HUD title")
	var ai_sect_data: Dictionary = world_data.call("get_all_sects")[1]
	var ai_node := world.get_node("SectLayer").get_child(1) as SectNode
	world.call("_on_sect_selected", ai_sect_data, ai_node)
	_expect(not (hud.get_node("%PrimaryActionButton") as Button).visible, "AI sect must hide Enter Sect action")
	var resource_data: Dictionary = world_data.call("get_all_resources")[0]
	var resource_node := world.get_node("ResourceLayer").get_child(0) as ResourceNode
	world.call("_on_resource_selected", resource_data, resource_node)
	var resource_detail_text := (hud.get_node("%PrimaryInfoLabel") as Label).text + (hud.get_node("%SecondaryInfoLabel") as Label).text + (hud.get_node("%DescriptionLabel") as Label).text
	_expect(not "resource_id" in resource_detail_text, "Resource HUD must not expose internal resource_id")
	world.queue_free()
	await process_frame


func _test_data_invariants() -> void:
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
