extends Node2D

# 当前页面容器，所有菜单和界面都会加载到这里。
@onready var current_page: Control = $CurrentPage


# 游戏启动后，先登记根节点，再立即显示主菜单。
func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_current_page_size()
	SceneManager.setup_main(self, current_page)
	SceneManager.go_to_main_menu()


# 窗口尺寸变化时，重新铺满 CurrentPage。
func _on_viewport_size_changed() -> void:
	_update_current_page_size()


# 因为 Main 是 Node2D，Control 子节点不会自动获得全屏尺寸，所以这里手动设置。
func _update_current_page_size() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	current_page.anchor_left = 0.0
	current_page.anchor_top = 0.0
	current_page.anchor_right = 0.0
	current_page.anchor_bottom = 0.0
	current_page.position = Vector2.ZERO
	current_page.size = viewport_size
	current_page.offset_left = 0.0
	current_page.offset_top = 0.0
	current_page.offset_right = viewport_size.x
	current_page.offset_bottom = viewport_size.y
	SceneManager.update_current_page_layout()
