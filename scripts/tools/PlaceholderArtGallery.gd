extends Control

@export var gallery_title := "占位美术总览"
@export var category_prefixes := PackedStringArray()
@export_range(1, 400, 1) var max_items := 180

@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var asset_grid: GridContainer = %AssetGrid


func _ready() -> void:
	title_label.text = gallery_title
	var manifest_path := "res://assets/placeholder_art/manifest/placeholder_art_manifest.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not (parsed is Dictionary):
		status_label.text = "占位美术 manifest 无法读取"
		return
	var shown := 0
	for record_value in (parsed as Dictionary).get("assets", []):
		if not (record_value is Dictionary):
			continue
		var record := record_value as Dictionary
		if not _matches_category(str(record.get("category", ""))):
			continue
		var texture := load(str(record.get("path", ""))) as Texture2D
		if texture == null:
			continue
		asset_grid.add_child(_make_asset_card(record, texture))
		shown += 1
		if shown >= max_items:
			break
	status_label.text = "展示 %d 项 · 固定种子 %d · 全部为可替换 placeholder" % [shown, int((parsed as Dictionary).get("seed", 0))]


func _matches_category(category: String) -> bool:
	if category_prefixes.is_empty():
		return true
	for prefix in category_prefixes:
		if category.begins_with(prefix):
			return true
	return false


func _make_asset_card(record: Dictionary, texture: Texture2D) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156, 150)
	panel.theme_type_variation = &"WZCardPanel"
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(112, 112)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.tooltip_text = str(record.get("path", ""))
	box.add_child(preview)
	var label := Label.new()
	label.text = str(record.get("asset_id", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = str(record.get("path", ""))
	box.add_child(label)
	return panel
