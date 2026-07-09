extends Area2D
class_name BuildSlotNode

# 点击建设点时，把建设点数据传给世界地图。
signal selected(slot_data: Dictionary)

# 建设点像素方块尺寸。
const SLOT_SIZE: Vector2 = Vector2(14, 14)

# 建设点编号。
var slot_id: int = 0

# 所属宗门编号。
var owner_sect_id: String = ""

# 是否为空地。
var is_empty: bool = true

# 当前建设点完整数据。
var slot_data: Dictionary = {}

# 空地文本。
var info_label: Label = null

# 建设点仅在玩家宗门上下文中显示，选中时提供轻微高亮。
var is_selected: bool = false

const SELECT_COLOR: Color = Color(1.0, 0.92, 0.48, 0.85)


# 初始化建设点。
func setup(data: Dictionary) -> void:
	slot_data = data
	slot_id = int(data["slot_id"])
	owner_sect_id = str(data["owner_sect_id"])
	position = data["position"]
	is_empty = bool(data["is_empty"])

	input_pickable = true
	_create_collision_shape()
	_create_info_label()
	queue_redraw()


# 绘制黄色像素方块，表示可建设空地。
func _draw() -> void:
	var rect := Rect2(SLOT_SIZE * -0.5, SLOT_SIZE)
	draw_rect(rect, Color(0.30, 0.24, 0.08), true)
	draw_rect(rect.grow(-2.0), Color(1.0, 0.86, 0.30), true)
	if is_selected:
		draw_rect(rect.grow(3.0), SELECT_COLOR, false, 2.0)


# 鼠标点击建设点后，通知世界地图显示详情。
func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(slot_data)
			get_viewport().set_input_as_handled()


# 创建点击范围。
func _create_collision_shape() -> void:
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = Vector2(24, 24)

	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = rectangle_shape
	add_child(collision_shape)


# 创建空地文本。
func _create_info_label() -> void:
	info_label = Label.new()
	info_label.visible = false


# 由 World 统一设置选中状态。
func set_selected(value: bool) -> void:
	is_selected = value
	queue_redraw()
