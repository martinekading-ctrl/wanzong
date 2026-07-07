extends Camera2D

# 地图尺寸，由 WorldMap 设置。
var map_size: Vector2 = Vector2(4000, 4000)

# 镜头移动速度。
var move_speed: float = 900.0

# 镜头最小缩放，数值越小视野越大。
var min_zoom: float = 0.35

# 镜头最大缩放，数值越大视野越近。
var max_zoom: float = 1.8

# 每次滚轮缩放幅度。
var zoom_step: float = 0.12

# 初始缩放，进入地图时先看到完整原型布局。
var start_zoom: float = 0.45

# 鼠标是否正在拖动镜头。
var is_dragging: bool = false


# 镜头启动时，先放在地图中心。
func _ready() -> void:
	position = map_size * 0.5
	zoom = Vector2(start_zoom, start_zoom)
	_clamp_camera_position()


# 每帧检查键盘输入，支持 WASD 和方向键。
func _process(delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		position += direction.normalized() * move_speed * delta / zoom.x
		_clamp_camera_position()


# 处理滚轮缩放和鼠标拖动镜头。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom.x + zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom.x - zoom_step)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed

	if event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom.x
		_clamp_camera_position()


# 设置镜头缩放，并限制缩放范围。
func _set_zoom(new_zoom: float) -> void:
	var clamped_zoom: float = clampf(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(clamped_zoom, clamped_zoom)
	_clamp_camera_position()


# 限制镜头不要离开地图太远。
func _clamp_camera_position() -> void:
	var margin: float = 300.0
	position.x = clampf(position.x, -margin, map_size.x + margin)
	position.y = clampf(position.y, -margin, map_size.y + margin)
