@tool
extends Node

const PREVIEW_SCENE_PATH := "res://scenes/prototype/PixelWorldPreview.tscn"
const GENERATED_SCENE_PATH := "res://scenes/world/GeneratedWorldMap.tscn"
const GENERATED_SCRIPT_PATH := "res://scripts/world/GeneratedWorldMap.gd"
const SAFE_TERRAINS: Array[String] = [
	"grass", "frost_grass", "forest", "dirt", "snow", "wasteland",
]
const TREE_ICON_SIZE := 28
const PINE_ICON_SIZE := 30
const BAMBOO_ICON_SIZE := 28
const ROCK_ICON_SIZE := 24
const HILL_ICON_SIZE := 34
const MOUNTAIN_ICON_SIZE := 38
const SNOW_MOUNTAIN_ICON_SIZE := 42
const SPECIAL_TREE_ICON_SIZE := 34

@export var bake_world_now: bool = false:
	set(value):
		bake_world_now = false
		if value and Engine.is_editor_hint() and not _is_baking:
			call_deferred("bake_world")

var _is_baking: bool = false


func bake_world() -> Error:
	if _is_baking:
		return ERR_BUSY
	_is_baking = true
	var started_at: int = Time.get_ticks_msec()
	var preview_scene := load(PREVIEW_SCENE_PATH) as PackedScene
	if preview_scene == null:
		_is_baking = false
		return ERR_FILE_NOT_FOUND
	var preview: Node2D = preview_scene.instantiate()
	preview.set("preview_mode", false)
	add_child(preview)
	await preview.ready
	var preview_terrain := preview.get_node("TerrainLayer") as TileMapLayer
	if preview_terrain.get_used_cells().is_empty():
		preview.call("generate_for_bake")

	var generated_root := Node2D.new()
	generated_root.name = "GeneratedWorldMap"
	generated_root.set_script(load(GENERATED_SCRIPT_PATH))
	var terrain_copy := preview.get_node("TerrainLayer").duplicate() as TileMapLayer
	terrain_copy.name = "TerrainLayer"
	generated_root.add_child(terrain_copy)
	terrain_copy.owner = generated_root
	generated_root.set("safe_land_source_ids", _collect_safe_source_ids(preview))
	_add_baked_nature(preview, generated_root)

	var packed_scene := PackedScene.new()
	var pack_error: Error = packed_scene.pack(generated_root)
	var save_error: Error = pack_error
	if pack_error == OK:
		save_error = ResourceSaver.save(packed_scene, GENERATED_SCENE_PATH)
	preview.queue_free()
	generated_root.free()
	_is_baking = false
	print("[WorldPerf] bake_world: %d ms, result=%s" % [Time.get_ticks_msec() - started_at, error_string(save_error)])
	return save_error


func _collect_safe_source_ids(preview: Node) -> Array[int]:
	var result: Array[int] = []
	var terrain_sources: Dictionary = preview.get("terrain_sources")
	for terrain_name in SAFE_TERRAINS:
		for source_id in terrain_sources.get(terrain_name, []):
			result.append(int(source_id))
	return result


func _add_baked_nature(preview: Node, generated_root: Node2D) -> void:
	var nature_root := Node2D.new()
	nature_root.name = "NatureObjects"
	generated_root.add_child(nature_root)
	nature_root.owner = generated_root
	for marker in preview.get("tree_markers"):
		var textures: Array = _get_tree_textures(preview, str(marker["kind"]))
		var icon_size: int = _get_tree_size(preview, str(marker["kind"]))
		_add_sprite(nature_root, textures, preview.call("_cell_center", marker["cell"]) + marker["offset"], icon_size, int(marker["variant"]), generated_root)
	_add_marker_sprites(preview, nature_root, "mountain_markers", "mountain_rock_textures", MOUNTAIN_ICON_SIZE, generated_root)
	_add_marker_sprites(preview, nature_root, "snow_markers", "mountain_snow_textures", SNOW_MOUNTAIN_ICON_SIZE, generated_root)
	_add_marker_sprites(preview, nature_root, "wasteland_markers", "dead_tree_textures", SPECIAL_TREE_ICON_SIZE, generated_root)
	_add_marker_sprites(preview, nature_root, "rock_markers", "rock_textures", ROCK_ICON_SIZE, generated_root)
	_add_marker_sprites(preview, nature_root, "hill_markers", "hill_textures", HILL_ICON_SIZE, generated_root)


func _add_marker_sprites(preview: Node, parent: Node2D, marker_property: String, texture_property: String, icon_size: int, owner: Node) -> void:
	var textures: Array = preview.get(texture_property)
	for cell in preview.get(marker_property):
		_add_sprite(parent, textures, preview.call("_cell_center", cell), icon_size, int(preview.call("_cell_hash", cell.x, cell.y)), owner)


func _add_sprite(parent: Node2D, textures: Array, anchor_position: Vector2, icon_size: int, variant: int, owner: Node) -> void:
	if textures.is_empty():
		return
	var texture := textures[absi(variant) % textures.size()] as Texture2D
	if texture == null:
		return
	var scale_factor: float = float(icon_size) / maxf(texture.get_width(), texture.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = anchor_position - Vector2(0.0, texture.get_height() * scale_factor * 0.5)
	parent.add_child(sprite)
	sprite.owner = owner


func _get_tree_textures(preview: Node, kind: String) -> Array:
	match kind:
		"pine": return preview.get("tree_pine_textures")
		"bamboo": return preview.get("bamboo_textures")
		"dead": return preview.get("dead_tree_textures")
		"spirit": return preview.get("spirit_tree_textures")
		_: return preview.get("tree_green_textures")


func _get_tree_size(preview: Node, kind: String) -> int:
	match kind:
		"pine": return PINE_ICON_SIZE
		"bamboo": return BAMBOO_ICON_SIZE
		"dead", "spirit": return SPECIAL_TREE_ICON_SIZE
		_: return TREE_ICON_SIZE
