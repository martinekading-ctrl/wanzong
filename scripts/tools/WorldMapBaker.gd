@tool
extends Node

const PREVIEW_SCENE_PATH := "res://scenes/prototype/PixelWorldPreview.tscn"
const GENERATED_SCENE_PATH := "res://scenes/world/GeneratedWorldMap.tscn"
const GENERATED_SCRIPT_PATH := "res://scripts/world/GeneratedWorldMap.gd"
const GENERATED_TILESET_PATH := "res://assets/generated/world_terrain_tileset.tres"
const GENERATED_NATURE_DIRECTORY := "res://assets/generated/nature_batches"
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
	var tile_set_save_error: Error = _save_external_tile_set(terrain_copy)
	if tile_set_save_error != OK:
		preview.queue_free()
		generated_root.free()
		_is_baking = false
		return tile_set_save_error
	generated_root.add_child(terrain_copy)
	terrain_copy.owner = generated_root
	generated_root.set("safe_land_source_ids", _collect_safe_source_ids(preview))
	_add_baked_nature(preview, generated_root)
	if not _validate_baked_nature(generated_root):
		preview.queue_free()
		generated_root.free()
		_is_baking = false
		push_error("自然物MultiMesh变换无效；请在非headless编辑器中重新烘焙。")
		return ERR_INVALID_DATA

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


func _save_external_tile_set(terrain_layer: TileMapLayer) -> Error:
	if terrain_layer.tile_set == null:
		return ERR_INVALID_DATA
	var save_error: Error = ResourceSaver.save(terrain_layer.tile_set, GENERATED_TILESET_PATH)
	if save_error != OK:
		return save_error
	terrain_layer.tile_set = load(GENERATED_TILESET_PATH) as TileSet
	return OK if terrain_layer.tile_set != null else ERR_CANT_OPEN


func _add_baked_nature(preview: Node, generated_root: Node2D) -> void:
	var nature_root := Node2D.new()
	nature_root.name = "NatureObjects"
	generated_root.add_child(nature_root)
	nature_root.owner = generated_root
	var batches: Dictionary = {}
	for marker in preview.get("tree_markers"):
		var textures: Array = _get_tree_textures(preview, str(marker["kind"]))
		var icon_size: int = _get_tree_size(preview, str(marker["kind"]))
		_collect_instance(batches, textures, preview.call("_cell_center", marker["cell"]) + marker["offset"], icon_size, int(marker["variant"]))
	_collect_marker_instances(preview, batches, "mountain_markers", "mountain_rock_textures", MOUNTAIN_ICON_SIZE)
	_collect_marker_instances(preview, batches, "snow_markers", "mountain_snow_textures", SNOW_MOUNTAIN_ICON_SIZE)
	_collect_marker_instances(preview, batches, "wasteland_markers", "dead_tree_textures", SPECIAL_TREE_ICON_SIZE)
	_collect_marker_instances(preview, batches, "rock_markers", "rock_textures", ROCK_ICON_SIZE)
	_collect_marker_instances(preview, batches, "hill_markers", "hill_textures", HILL_ICON_SIZE)
	_create_multimesh_batches(nature_root, batches, generated_root)


func _collect_marker_instances(preview: Node, batches: Dictionary, marker_property: String, texture_property: String, icon_size: int) -> void:
	var textures: Array = preview.get(texture_property)
	for cell in preview.get(marker_property):
		_collect_instance(batches, textures, preview.call("_cell_center", cell), icon_size, int(preview.call("_cell_hash", cell.x, cell.y)))


func _collect_instance(batches: Dictionary, textures: Array, anchor_position: Vector2, icon_size: int, variant: int) -> void:
	if textures.is_empty():
		return
	var texture := textures[absi(variant) % textures.size()] as Texture2D
	if texture == null:
		return
	var scale_factor: float = float(icon_size) / maxf(texture.get_width(), texture.get_height())
	var draw_position: Vector2 = anchor_position - Vector2(0.0, texture.get_height() * scale_factor * 0.5)
	var texture_key: String = texture.resource_path
	if texture_key == "":
		texture_key = str(texture.get_rid())
	if not batches.has(texture_key):
		batches[texture_key] = {"texture": texture, "transforms": []}
	var batch_data: Dictionary = batches[texture_key]
	var transforms: Array = batch_data["transforms"]
	transforms.append(Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, draw_position))


func _create_multimesh_batches(parent: Node2D, batches: Dictionary, owner: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_NATURE_DIRECTORY))
	var sorted_keys: Array = batches.keys()
	sorted_keys.sort()
	for batch_index in range(sorted_keys.size()):
		var batch_data: Dictionary = batches[sorted_keys[batch_index]]
		var transforms: Array = batch_data["transforms"]
		if transforms.is_empty():
			continue
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
		var quad_mesh := QuadMesh.new()
		var texture := batch_data["texture"] as Texture2D
		quad_mesh.size = texture.get_size()
		multi_mesh.mesh = quad_mesh
		multi_mesh.instance_count = transforms.size()
		var batch := MultiMeshInstance2D.new()
		batch.name = "NatureBatch%02d" % (batch_index + 1)
		batch.texture = texture
		batch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		batch.multimesh = multi_mesh
		parent.add_child(batch)
		batch.owner = owner
		for instance_index in range(transforms.size()):
			multi_mesh.set_instance_transform_2d(instance_index, transforms[instance_index])
		var batch_resource_path: String = GENERATED_NATURE_DIRECTORY.path_join(
			"world_nature_batch_%02d.res" % (batch_index + 1)
		)
		var save_error: Error = ResourceSaver.save(multi_mesh, batch_resource_path)
		if save_error == OK:
			batch.multimesh = load(batch_resource_path) as MultiMesh
		else:
			push_warning("自然物批次资源保存失败：" + batch_resource_path)
			batch.multimesh = multi_mesh


func _validate_baked_nature(generated_root: Node2D) -> bool:
	var nature_root: Node = generated_root.get_node_or_null("NatureObjects")
	if nature_root == null or nature_root.get_child_count() == 0:
		return false
	for child in nature_root.get_children():
		var batch := child as MultiMeshInstance2D
		if batch == null or batch.multimesh == null or batch.multimesh.instance_count == 0:
			return false
		if batch.multimesh.buffer.is_empty():
			return false
	return true


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
