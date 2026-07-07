extends Area2D
class_name ResourceNode

# 点击资源点时，把资源点数据发给世界地图。
signal selected(resource_data: Dictionary)

# 资源点图标大小。
const NODE_RADIUS: float = 22.0

# 资源点编号。
var resource_id: int = 0

# 资源点名称。
var resource_name: String = ""

# 资源点类型。
var resource_type: String = ""

# 资源储量。
var amount: int = 0

# 当前归属宗门编号，-1 表示无主。
var owner_sect_id: int = -1

# 资源点等级。
var level: int = 1

# 当前资源点完整数据。
var resource_data: Dictionary = {}

# 名称和等级文本。
var info_label: Label = null


# 初始化资源点节点。
func setup(data: Dictionary) -> void:
	resource_data = data
	resource_id = int(data["resource_id"])
	resource_name = str(data["resource_name"])
	resource_type = str(data["resource_type"])
	amount = int(data["amount"])
	owner_sect_id = int(data["owner_sect_id"])
	position = data["position"]
	level = int(data["level"])

	input_pickable = true
	_create_collision_shape()
	_create_info_label()
	queue_redraw()


# 绘制资源点图标，不同资源类型使用不同颜色。
func _draw() -> void:
	var fill_color: Color = _get_resource_color()

	if resource_type == "secret_realm":
		draw_rect(Rect2(Vector2(-NODE_RADIUS, -NODE_RADIUS), Vector2(NODE_RADIUS * 2.0, NODE_RADIUS * 2.0)), fill_color, true)
		draw_rect(Rect2(Vector2(-NODE_RADIUS, -NODE_RADIUS), Vector2(NODE_RADIUS * 2.0, NODE_RADIUS * 2.0)), Color(1.0, 0.95, 0.60), false, 3.0)
	else:
		draw_circle(Vector2.ZERO, NODE_RADIUS, fill_color)
		draw_arc(Vector2.ZERO, NODE_RADIUS, 0.0, TAU, 40, Color(0.85, 0.90, 0.86), 3.0)


# 鼠标点击资源点后，通知世界地图显示详情。
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(resource_data)
			get_viewport().set_input_as_handled()


# 创建点击范围。
func _create_collision_shape() -> void:
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = NODE_RADIUS + 12.0

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = circle_shape
	add_child(collision_shape)


# 创建资源点名称和等级文本。
func _create_info_label() -> void:
	info_label = Label.new()
	info_label.position = Vector2(-70, 30)
	info_label.custom_minimum_size = Vector2(140, 34)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.text = resource_name + " Lv" + str(level)
	info_label.add_theme_font_size_override("font_size", 18)
	add_child(info_label)


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
