extends SceneTree

const WorldSectRoster = preload("res://scripts/world/WorldSectRoster.gd")
const MANIFEST_PATH := "res://assets/placeholder_art/manifest/placeholder_art_manifest.json"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_manifest()
	_test_manifest(manifest)
	_test_required_assets()
	_test_theme()
	_test_scenes()
	_test_image_contracts(manifest)
	_test_data_invariants()
	if _failures.is_empty():
		print("[Task0068PlaceholderArtPass] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[Task0068PlaceholderArtPass] " + failure)
	quit(1)


func _load_manifest() -> Dictionary:
	_expect(FileAccess.file_exists(MANIFEST_PATH), "manifest must exist")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "manifest must parse as a dictionary")
	return parsed as Dictionary if parsed is Dictionary else {}


func _test_manifest(manifest: Dictionary) -> void:
	_expect(bool(manifest.get("placeholder", false)), "manifest must mark all content as placeholder")
	_expect(int(manifest.get("seed", 0)) == 20260715, "generator seed must remain 20260715")
	var assets: Array = manifest.get("assets", [])
	_expect(int(manifest.get("asset_count", 0)) == assets.size(), "manifest asset_count must match assets")
	_expect(assets.size() >= 900, "full placeholder pass must contain at least 900 asset records")
	var seen := {}
	for record_value in assets:
		if not (record_value is Dictionary):
			_expect(false, "manifest asset record must be a dictionary")
			continue
		var record := record_value as Dictionary
		var path := str(record.get("path", ""))
		_expect(path.begins_with("res://assets/placeholder_art/"), "asset path must stay in task directory: " + path)
		_expect(not seen.has(path), "manifest path must be unique: " + path)
		seen[path] = true
		_expect(FileAccess.file_exists(path), "manifest file missing: " + path)


func _test_required_assets() -> void:
	var required := [
		"res://assets/placeholder_art/ui/panels/panel_screen_background.png",
		"res://assets/placeholder_art/ui/buttons/primary_normal.png",
		"res://assets/placeholder_art/ui/buttons/primary_hover.png",
		"res://assets/placeholder_art/ui/buttons/primary_pressed.png",
		"res://assets/placeholder_art/ui/buttons/primary_disabled.png",
		"res://assets/placeholder_art/ui/buttons/primary_focus.png",
		"res://assets/placeholder_art/icons/resources/spirit_stone_24.png",
		"res://assets/placeholder_art/icons/navigation/world_32.png",
		"res://assets/placeholder_art/icons/systems/save_48.png",
		"res://assets/placeholder_art/sects/emblems/qingxuan_emblem.png",
		"res://assets/placeholder_art/world/landmarks/qingxuan_headquarters.png",
		"res://assets/placeholder_art/sects/backgrounds/qingxuan_sect_background.png",
		"res://assets/placeholder_art/sects/buildings/main_hall_map.png",
		"res://assets/placeholder_art/characters/portraits/qingxuan_master_portrait_256.png",
		"res://assets/placeholder_art/characters/sprite_sheets/qingxuan_master_sheet.png",
		"res://assets/placeholder_art/world/terrain/grass_medium_01.png",
		"res://assets/placeholder_art/world/nature/tree_medium_01.png",
		"res://assets/placeholder_art/world/effects/sword_slash_sheet.png",
	]
	for path in required:
		_expect(FileAccess.file_exists(path), "required placeholder missing: " + path)
	for sect in ["qingxuan", "lingxiao", "chilu", "xuesha", "jinlian"]:
		_expect(FileAccess.file_exists("res://assets/placeholder_art/sects/emblems/%s_emblem.png" % sect), "sect emblem missing: " + sect)
		_expect(FileAccess.file_exists("res://assets/placeholder_art/world/landmarks/%s_headquarters.png" % sect), "sect headquarters missing: " + sect)


func _test_theme() -> void:
	var theme := load("res://assets/ui/wanzong_theme.tres") as Theme
	_expect(theme != null, "global theme must load")
	if theme == null:
		return
	for variation in ["WZPrimaryButton", "WZSecondaryButton", "WZGhostButton", "WZDangerButton", "WZNavButton", "WZNavButtonSelected"]:
		_expect(theme.get_stylebox("normal", variation) != null, "button theme variation missing: " + variation)
	for variation in ["WZPanel", "WZHUDPanel", "WZDialogPanel", "WZCardPanel", "WZTooltipPanel"]:
		_expect(theme.get_stylebox("panel", variation) != null, "panel theme variation missing: " + variation)
	for variation in ["WZScreenTitle", "WZSectionTitle", "WZBody", "WZMutedText", "WZResourceText"]:
		_expect(theme.get_color("font_color", variation).a > 0.0, "label theme variation missing: " + variation)


func _test_scenes() -> void:
	var scenes := [
		"res://scenes/ui/MainMenu.tscn",
		"res://scenes/world/World.tscn",
		"res://scenes/sect/PlayerSectOverview.tscn",
		"res://scenes/battle/BattleReport.tscn",
		"res://scenes/ui/TutorialOverlay.tscn",
		"res://scenes/tools/PlaceholderArtGallery.tscn",
		"res://scenes/tools/WorldVisualPreview.tscn",
		"res://scenes/tools/CharacterGallery.tscn",
	]
	for path in scenes:
		var packed := load(path) as PackedScene
		_expect(packed != null, "scene must load: " + path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_expect(instance != null, "scene must instantiate: " + path)
		if instance != null:
			instance.free()


func _test_image_contracts(manifest: Dictionary) -> void:
	for record_value in manifest.get("assets", []):
		if not (record_value is Dictionary):
			continue
		var record := record_value as Dictionary
		var path := str(record.get("path", ""))
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(path))
		_expect(error == OK, "PNG must load: " + path)
		if error != OK:
			continue
		_expect(image.get_width() == int(record.get("width", 0)) and image.get_height() == int(record.get("height", 0)), "PNG dimensions must match manifest: " + path)
		if bool(record.get("transparent", false)):
			_expect(image.detect_alpha() != Image.ALPHA_NONE, "transparent PNG must contain alpha: " + path)
		if str(record.get("category", "")) == "world_terrain":
			_expect(image.get_size() == Vector2i(16, 16), "terrain tile must be 16x16: " + path)
		if bool(record.get("sprite_sheet", false)):
			var frame: Array = record.get("frame_size", [])
			_expect(frame.size() == 2 and image.get_width() % int(frame[0]) == 0 and image.get_height() % int(frame[1]) == 0, "sprite sheet must divide by frame size: " + path)


func _test_data_invariants() -> void:
	var game_state: Node = root.get_node("GameState")
	var save_manager: Node = root.get_node("SaveManager")
	var world_data: Node = root.get_node("WorldDataManager")
	game_state.call("new_game")
	var save_constants: Dictionary = save_manager.get_script().get_script_constant_map()
	_expect(int(save_constants.get("CURRENT_SAVE_VERSION", -1)) == 1, "CURRENT_SAVE_VERSION must remain 1")
	_expect(int(save_constants.get("MINIMUM_SAVE_VERSION", -1)) == 0, "MINIMUM_SAVE_VERSION must remain 0")
	_expect(WorldSectRoster.ROSTER_VERSION == 2, "ROSTER_VERSION must remain 2")
	_expect((world_data.call("get_all_sects") as Array).size() == 5, "world must retain five sects")
	_expect((world_data.call("get_ai_sects") as Array).size() == 4, "world must retain four AI sects")
	_expect((world_data.call("get_all_resources") as Array).size() == 26, "world must retain 26 resource nodes")
	_expect((world_data.call("get_all_build_slots") as Array).size() == 6, "world must retain six build slots")
	var generated := load("res://scenes/world/GeneratedWorldMap.scn") as PackedScene
	_expect(generated != null, "generated world runtime scene must load")
	if generated != null:
		var map := generated.instantiate()
		_expect(int(map.call("get_terrain_cell_count")) == 73984, "terrain cell count must remain 73984")
		map.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
