extends PanelContainer

@onready var progress_label: Label = $Content/ProgressLabel
@onready var title_label: Label = $Content/TitleLabel
@onready var description_label: Label = $Content/DescriptionLabel
@onready var dismiss_button: Button = $Content/ButtonBar/DismissButton
@onready var reset_button: Button = $Content/ButtonBar/ResetButton


func _ready() -> void:
	dismiss_button.pressed.connect(TutorialManager.dismiss)
	reset_button.pressed.connect(TutorialManager.reset_tutorial)
	TutorialManager.tutorial_updated.connect(_on_tutorial_updated)
	_refresh()


func _on_tutorial_updated(_state: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	visible = TutorialManager.is_visible()
	if not visible:
		return
	var prompt: Dictionary = TutorialManager.get_current_prompt()
	var index: int = int(prompt.get("index", 0))
	var total: int = int(prompt.get("total", 5))
	progress_label.text = "新手引导 %d/%d" % [mini(index + 1, total), total]
	title_label.text = str(prompt.get("title", "新手引导"))
	description_label.text = str(prompt.get("description", ""))
