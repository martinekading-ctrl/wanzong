extends Control

# 开始游戏按钮。
@onready var start_button: Button = $CenterContainer/MenuBox/StartButton
@onready var continue_button: Button = $CenterContainer/MenuBox/ContinueButton
@onready var continue_hint_label: Label = $CenterContainer/MenuBox/ContinueHintLabel

# 退出游戏按钮。
@onready var quit_button: Button = $CenterContainer/MenuBox/QuitButton


# 场景准备好后，绑定按钮点击事件。
func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	_refresh_continue_state()


# 点击“开始游戏”后，进入俯视大地图。
func _on_start_button_pressed() -> void:
	GameState.new_game()
	SceneManager.go_to_world_map()


func _on_continue_button_pressed() -> void:
	var result: Dictionary = SaveManager.load_latest_save()
	if not bool(result.get("success", false)):
		continue_hint_label.text = str(result.get("message", "读档失败"))
		_refresh_continue_state()
		return
	SceneManager.go_to_world_map()


func _refresh_continue_state() -> void:
	var latest_path: String = SaveManager.get_latest_save_path()
	continue_button.disabled = latest_path == ""
	if latest_path == "":
		continue_hint_label.text = "暂无可读取存档"
		return
	var metadata: Dictionary = SaveManager.get_save_metadata(latest_path)
	var game_state_data: Dictionary = metadata.get("game_state", {})
	continue_hint_label.text = "最近进度：第%d年%d月%d日" % [
		int(game_state_data.get("year", 1)),
		int(game_state_data.get("month", 1)),
		int(game_state_data.get("day", 1)),
	]


# 点击“退出游戏”后，关闭游戏。
func _on_quit_button_pressed() -> void:
	SceneManager.quit_game()
