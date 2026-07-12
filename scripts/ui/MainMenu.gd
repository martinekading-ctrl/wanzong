extends Control

# 开始游戏按钮。
@onready var start_button: Button = $CenterContainer/MenuBox/StartButton

# 退出游戏按钮。
@onready var quit_button: Button = $CenterContainer/MenuBox/QuitButton


# 场景准备好后，绑定按钮点击事件。
func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)


# 点击“开始游戏”后，进入俯视大地图。
func _on_start_button_pressed() -> void:
	GameState.new_game()
	SceneManager.go_to_world_map()


# 点击“退出游戏”后，关闭游戏。
func _on_quit_button_pressed() -> void:
	SceneManager.quit_game()
