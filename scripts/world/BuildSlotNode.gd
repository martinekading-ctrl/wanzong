extends Area2D
class_name BuildSlotNode

# 点击建设点时，把建设点数据传给世界地图。
signal selected(slot_data: Dictionary)

# 建设点方块尺寸。
const SLOT_SIZE: Vector2 = Vector2(72, 56)

# 建设点编号。
var slot_id: int = 0

# 所属宗门编号。
var owner_sect_id: int = 0

# 是否为空地。
var is_empty: bool = true

# 当前建设点完整数据。
var slot_data: Dictionary = {}

# 空地文本。
var info_label: Label = null


# 初始化建设点。
func setup(data: Dictionary) -> void:
	slot_data = data
	slot_id = int(data["slot_id"])
	owner_sect_id = int(data["owner_sect_id"])
	position = data["position"]
	is_empty = bool(data["is_empty"])

	input_pickable = true
	_create_collision_shape()
	_create_info_label()
	queue_redraw()


# 绘制淡黄色半透明方块，表示可建设空地。
func _draw() -> void:
	var rect := Rect2(SLOT_SIZE * -0.5, SLOT_SIZE)
	draw_rect(rect, Color(1.0, 0.86, 0.30, 0.22), true)
	draw_rect(rect, Color(1.0, 0.92, 0.45, 0.75), false, 2.0)


# 鼠标点击建设点后，通知世界地图显示详情。
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(slot_data)
			get_viewport().set_input_as_handled()


# 创建点击范围。
func _create_collision_shape() -> void:
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = SLOT_SIZE

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rectangle_shape
	add_child(collision_shape)


# 创建空地文本。
func _create_info_label() -> void:
	info_label = Label.new()
	info_label.position = Vector2(-36, -10)
	info_label.custom_minimum_size = Vector2(72, 24)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.text = "空地"
	info_label.add_theme_font_size_override("font_size", 18)
	add_child(info_label)
