extends Camera2D

# 地图尺寸，由 World 设置。
var map_size: Vector2 = Vector2(WorldMapSpec.WORLD_SIZE)

# 地图左上角坐标，扩大地图后允许世界范围向原地图四周延伸。
var map_origin: Vector2 = Vector2.ZERO

# 镜头移动速度。
var move_speed: float = 900.0

# 扩大后的像素地图允许进一步缩小查看全局。
var min_zoom: float = 0.31

# 镜头最大缩放，数值越大视野越近。
var max_zoom: float = 1.8

# 每次滚轮缩放幅度。
var zoom_step: float = 0.12

# 初始视野拉远，方便观察主大陆与外围岛屿。
var start_zoom: float = 0.32

# 鼠标是否正在拖动镜头。
var is_dragging: bool = false


# 镜头启动时，先放在地图中心。
func _ready() -> void:
	position = map_origin + map_size * 0.5
	get_viewport().size_changed.connect(_on_viewport_size_changed)
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


# 处理滚轮缩放和鼠标中键拖动镜头。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(zoom.x + zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(zoom.x - zoom_step)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed

	if event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom.x
		_clamp_camera_position()


# 设置镜头缩放，并限制缩放范围。
func _set_zoom(new_zoom: float) -> void:
	var clamped_zoom: float = clampf(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(clamped_zoom, clamped_zoom)
	_clamp_camera_position()


## Public HUD entry point: uses the same clamped zoom implementation as wheel input.
func zoom_by(direction: float) -> void:
	_set_zoom(zoom.x + zoom_step * direction)


## Public HUD entry point: center on a real world location without bypassing bounds checks.
func focus_on(world_position: Vector2) -> void:
	position = world_position
	_clamp_camera_position()


## Public HUD entry point: reset to the actual overview zoom and map centre.
func show_full_map() -> void:
	_set_zoom(min_zoom)
	position = map_origin + map_size * 0.5
	_clamp_camera_position()


# 窗口尺寸变化后重新限制镜头位置。
func _on_viewport_size_changed() -> void:
	_clamp_camera_position()


# 按当前视野大小限制镜头位置，任何缩放下都不会露出地图外。
func _clamp_camera_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view_size: Vector2 = viewport_size / (zoom * 2.0)
	var map_end: Vector2 = map_origin + map_size

	if half_view_size.x * 2.0 >= map_size.x:
		position.x = map_origin.x + map_size.x * 0.5
	else:
		position.x = clampf(position.x, map_origin.x + half_view_size.x, map_end.x - half_view_size.x)

	if half_view_size.y * 2.0 >= map_size.y:
		position.y = map_origin.y + map_size.y * 0.5
	else:
		position.y = clampf(position.y, map_origin.y + half_view_size.y, map_end.y - half_view_size.y)
