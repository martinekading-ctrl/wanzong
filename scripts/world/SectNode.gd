extends Area2D
class_name SectNode

# 点击宗门时，把宗门数据发给地图场景。
signal selected(sect_data: Dictionary)

# 宗门显示半径。
const NODE_RADIUS: float = 34.0

# 当前宗门数据。
var sect_data: Dictionary = {}

# 名字和战力文本。
var info_label: Label = null


# 初始化宗门节点。
func setup(data: Dictionary) -> void:
	sect_data = data
	position = data["position"]
	input_pickable = true
	_create_collision_shape()
	_create_info_label()
	queue_redraw()


# 绘制宗门据点图标，玩家宗门使用绿色，AI 宗门使用蓝色。
func _draw() -> void:
	var is_player: bool = bool(sect_data.get("is_player", false))
	var fill_color: Color = Color(0.20, 0.85, 0.35) if is_player else Color(0.25, 0.55, 0.95)
	var border_color: Color = Color(0.75, 1.0, 0.78) if is_player else Color(0.70, 0.86, 1.0)

	draw_circle(Vector2.ZERO, NODE_RADIUS, fill_color)
	draw_arc(Vector2.ZERO, NODE_RADIUS, 0.0, TAU, 48, border_color, 4.0)

	if is_player:
		draw_circle(Vector2.ZERO, 12.0, Color(0.78, 1.0, 0.55))
	else:
		draw_rect(Rect2(Vector2(-10, -10), Vector2(20, 20)), Color(0.75, 0.90, 1.0), true)


# 鼠标点击宗门后，通知地图场景显示详情。
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(sect_data)
			get_viewport().set_input_as_handled()


# 创建点击碰撞范围。
func _create_collision_shape() -> void:
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = NODE_RADIUS + 10.0

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = circle_shape
	add_child(collision_shape)


# 创建宗门名字和战力文本。
func _create_info_label() -> void:
	info_label = Label.new()
	info_label.position = Vector2(-90, 42)
	info_label.custom_minimum_size = Vector2(180, 52)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.text = str(sect_data["sect_name"]) + "\n战力：" + str(sect_data["power"])
	info_label.add_theme_font_size_override("font_size", 22)
	add_child(info_label)
