extends Area2D
class_name ResourceNode

# 点击资源点时，把资源点数据发给世界地图。
signal selected(resource_data: Dictionary)

# 资源点编号。
var resource_id: int = 0

# 资源点名称。
var resource_name: String = ""

# 资源点类型。
var resource_type: String = ""

# 资源储量。
var amount: int = 0

# 当前归属宗门ID，空字符串表示无主。
var owner_sect_id: String = ""

# 资源点等级。
var level: int = 1

# 当前资源点完整数据。
var resource_data: Dictionary = {}

# 名称和等级文本。
var info_label: Label = null

# 可选的资源点美术图标；为空时继续使用 _draw() 的旧代码绘制。
var resource_sprite: Sprite2D = null
var base_sprite_scale: Vector2 = Vector2.ONE
var icon_display_size: float = 36.0

# 悬停和选中状态只改变视觉，不影响资源数据与点击信号。
var is_hovered: bool = false
var is_selected: bool = false

const HOVER_SCALE: float = 1.12
const SELECT_RING_COLOR: Color = Color(0.36, 0.72, 1.0, 0.62)


# 初始化资源点节点。
func setup(data: Dictionary, texture: Texture2D = null, display_size: float = 36.0) -> void:
	resource_data = data
	resource_id = int(data["resource_id"])
	resource_name = str(data["resource_name"])
	resource_type = str(data["resource_type"])
	amount = int(data["amount"])
	owner_sect_id = str(data["owner_sect_id"])
	position = data["position"]
	level = int(data["level"])
	icon_display_size = display_size

	input_pickable = true
	_create_collision_shape(display_size)
	_create_info_label()
	set_resource_texture(texture, display_size)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


# 设置资源点美术图标，按最长边等比缩放并使用最近邻过滤。
func set_resource_texture(texture: Texture2D, display_size: float) -> void:
	if resource_sprite != null:
		resource_sprite.queue_free()
		resource_sprite = null

	if texture == null:
		queue_redraw()
		return

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		push_warning("资源点图片尺寸无效：" + resource_name)
		queue_redraw()
		return

	resource_sprite = Sprite2D.new()
	resource_sprite.texture = texture
	resource_sprite.centered = true
	resource_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_sprite_scale = Vector2.ONE * (display_size / maxf(texture_size.x, texture_size.y))
	resource_sprite.scale = base_sprite_scale
	add_child(resource_sprite)
	_update_visual_state()


# 绘制四类修仙像素资源图标。
func _draw() -> void:
	if is_selected:
		draw_arc(
			Vector2.ZERO,
			icon_display_size * 0.58,
			0.0,
			TAU,
			28,
			SELECT_RING_COLOR,
			2.0,
			true
		)

	if resource_sprite != null:
		return

	var visual_scale: float = HOVER_SCALE if is_hovered else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	if resource_type == "spirit_mine":
		var purple := Color("#9a68b8")
		draw_rect(Rect2(Vector2(-9, 4), Vector2(18, 6)), Color("#493a55"), true)
		draw_rect(Rect2(Vector2(-4, -9), Vector2(8, 15)), purple, true)
		draw_rect(Rect2(Vector2(1, -7), Vector2(3, 9)), purple.lightened(0.22), true)
	elif resource_type == "herb_field":
		var herb := Color("#72b95c")
		draw_rect(Rect2(Vector2(-1, -9), Vector2(3, 18)), Color("#315b32"), true)
		draw_rect(Rect2(Vector2(-10, -6), Vector2(9, 6)), herb, true)
		draw_rect(Rect2(Vector2(2, -1), Vector2(10, 6)), herb.lightened(0.12), true)
	elif resource_type == "secret_realm":
		var gold := Color("#d6b64c")
		draw_rect(Rect2(Vector2(-9, -11), Vector2(18, 22)), Color("#4f4229"), true)
		draw_rect(Rect2(Vector2(-6, -8), Vector2(12, 19)), gold, true)
		draw_rect(Rect2(Vector2(-2, -3), Vector2(4, 14)), Color("#453a27"), true)
	else:
		var spirit_blue := Color("#667fd1")
		draw_rect(Rect2(Vector2(-7, -7), Vector2(14, 14)), Color("#353f68"), true)
		draw_rect(Rect2(Vector2(-4, -10), Vector2(8, 20)), spirit_blue, true)
		draw_rect(Rect2(Vector2(-10, -4), Vector2(20, 8)), spirit_blue.lightened(0.16), true)
		draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), Color("#b2a0e8"), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 鼠标点击资源点后，通知世界地图显示详情。
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_play_select_sound()
			selected.emit(resource_data)
			get_viewport().set_input_as_handled()


func _play_select_sound() -> void:
	var audio_manager: Node = get_tree().root.get_node_or_null("AudioManager")
	if audio_manager != null:
		audio_manager.call("play_ui", "select")


# 创建点击范围。
func _create_collision_shape(display_size: float) -> void:
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = maxf(20.0, display_size * 0.5)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = circle_shape
	add_child(collision_shape)


# 创建资源点名称和等级文本。
func _create_info_label() -> void:
	info_label = Label.new()
	info_label.position = Vector2(-80, icon_display_size * 0.55 + 4.0)
	info_label.custom_minimum_size = Vector2(160, 22)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.text = resource_name + " Lv" + str(level)
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.visible = false
	add_child(info_label)


# 鼠标进入时显示名称与等级，并轻微放大资源图标。
func _on_mouse_entered() -> void:
	set_hovered(true)


# 鼠标移开后恢复；已选中资源点继续显示名称。
func _on_mouse_exited() -> void:
	set_hovered(false)


func set_hovered(value: bool) -> void:
	is_hovered = value
	_update_visual_state()


# 由 World 统一设置选中状态。
func set_selected(value: bool) -> void:
	is_selected = value
	_update_visual_state()


func _update_visual_state() -> void:
	_update_label_visible()
	if resource_sprite != null:
		resource_sprite.scale = base_sprite_scale * (HOVER_SCALE if is_hovered else 1.0)
	queue_redraw()


func _update_label_visible() -> void:
	if info_label != null:
		info_label.visible = is_hovered or is_selected


# 根据资源类型返回显示颜色。
func _get_resource_color() -> Color:
	if resource_type == "spirit_mine":
		return Color(0.55, 0.55, 0.55)
	if resource_type == "spirit_vein":
		return Color(0.62, 0.35, 0.95)
	if resource_type == "herb_field":
		return Color(0.25, 0.85, 0.35)
	if resource_type == "secret_realm":
		return Color(0.95, 0.72, 0.18)

	return Color.WHITE
