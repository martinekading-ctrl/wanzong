extends Area2D
class_name SectNode

# 点击宗门时，把宗门数据发给地图场景。
signal selected(sect_data: Dictionary)

# 当前宗门数据。
var sect_data: Dictionary = {}
var sect_id: String = ""
var sect_name: String = ""
var is_player: bool = false

# 名字和战力文本。
var info_label: Label = null

# 当前宗门图标，存在时不再绘制旧占位图。
var icon_texture: Texture2D = null
var icon_size: int = 72
var icon_sprite: Sprite2D = null
var base_icon_scale: Vector2 = Vector2.ONE

# 悬停和选中状态只控制当前宗门的视觉反馈。
var is_hovered: bool = false
var is_selected: bool = false

const HOVER_SCALE: float = 1.08
const SELECT_RING_COLOR: Color = Color(0.92, 0.76, 0.35, 0.62)


# 初始化宗门节点。
func setup(data: Dictionary, texture: Texture2D = null, display_size: int = 72) -> void:
	set_sect_data(data)
	icon_texture = texture
	icon_size = display_size
	position = data["position"]
	input_pickable = true
	_create_collision_shape()
	_create_icon()
	_create_info_label()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


# 更新当前宗门数据，并缓存地图交互常用字段。
func set_sect_data(data: Dictionary) -> void:
	sect_data = data
	sect_id = str(data.get("sect_id", ""))
	sect_name = str(data.get("sect_name", ""))
	is_player = bool(data.get("is_player", false))


# 绘制 32 x 32 像素山门，玩家宗门使用金绿配色。
func _draw() -> void:
	if is_selected:
		draw_arc(
			Vector2(0, -5),
			icon_size * 0.30,
			0.0,
			TAU,
			32,
			SELECT_RING_COLOR,
			2.0,
			true
		)

	if icon_texture != null:
		return

	var visual_scale: float = HOVER_SCALE if is_hovered else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	var roof_color: Color = Color("#d9be57") if is_player else (
		Color("#4f86bd") if abs(sect_id.hash()) % 2 == 0 else Color("#a95656")
	)
	var wall_color: Color = Color("#d8ca9f") if is_player else Color("#b9b4a5")

	draw_rect(Rect2(Vector2(-15, 11), Vector2(30, 5)), Color("#293337"), true)
	draw_rect(Rect2(Vector2(-11, -2), Vector2(22, 14)), wall_color, true)
	draw_rect(Rect2(Vector2(-14, -6), Vector2(28, 5)), roof_color.darkened(0.18), true)
	draw_rect(Rect2(Vector2(-9, -11), Vector2(18, 6)), roof_color, true)
	draw_rect(Rect2(Vector2(-3, 3), Vector2(6, 9)), Color("#493a2c"), true)

	if is_player:
		draw_rect(Rect2(Vector2(8, -16), Vector2(2, 8)), Color("#eee2a0"), true)
		draw_rect(Rect2(Vector2(10, -16), Vector2(6, 5)), Color("#62a94f"), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 鼠标点击宗门后，通知地图场景显示详情。
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_play_select_sound()
			selected.emit(sect_data)
			get_viewport().set_input_as_handled()


func _play_select_sound() -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null:
		audio_manager.call("play_ui", "select")


# 创建点击碰撞范围。
func _create_collision_shape() -> void:
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = Vector2(icon_size, icon_size)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.position = Vector2(0, -icon_size * 0.5)
	collision_shape.shape = rectangle_shape
	add_child(collision_shape)


# 创建宗门图片，保持比例并让图片底部中心对齐宗门坐标。
func _create_icon() -> void:
	if icon_texture == null:
		return

	var texture_size: Vector2 = icon_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var icon: Sprite2D = Sprite2D.new()
	icon.texture = icon_texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var uniform_scale: float = min(
		float(icon_size) / texture_size.x,
		float(icon_size) / texture_size.y
	)
	base_icon_scale = Vector2.ONE * uniform_scale
	icon.scale = base_icon_scale
	icon.position = Vector2(0, -icon_size * 0.5)
	add_child(icon)
	icon_sprite = icon


func set_icon_texture(texture: Texture2D, display_size: int = 72) -> void:
	if icon_sprite != null:
		remove_child(icon_sprite)
		icon_sprite.free()
		icon_sprite = null
	icon_texture = texture
	icon_size = display_size
	_create_icon()
	_update_visual_state()


# 创建宗门名字和战力文本。
func _create_info_label() -> void:
	info_label = Label.new()
	info_label.position = Vector2(-60, 4)
	info_label.custom_minimum_size = Vector2(120, 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.text = sect_name
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.visible = false
	add_child(info_label)


# 鼠标进入时显示名称，并围绕图标中心轻微放大。
func _on_mouse_entered() -> void:
	set_hovered(true)


# 鼠标离开时恢复尺寸；已选中的宗门继续显示名称。
func _on_mouse_exited() -> void:
	set_hovered(false)


# 统一设置悬停状态，便于测试与后续复用。
func set_hovered(value: bool) -> void:
	is_hovered = value
	_update_visual_state()


# 由 World 统一设置选中状态，保证地图上只有一个宗门被选中。
func set_selected(value: bool) -> void:
	is_selected = value
	_update_visual_state()


# 集中更新名称和缩放，避免悬停时改变宗门坐标。
func _update_visual_state() -> void:
	_update_label_visible()
	if icon_sprite != null:
		icon_sprite.scale = base_icon_scale * (HOVER_SCALE if is_hovered else 1.0)
	queue_redraw()


# 悬停或选中时显示宗门名称，默认保持隐藏。
func _update_label_visible() -> void:
	if info_label != null:
		info_label.visible = is_hovered or is_selected
