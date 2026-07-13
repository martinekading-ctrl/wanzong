extends Node

var hooked_button_count: int = 0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_hook_existing_buttons")


func pulse(item: CanvasItem, color: Color = Color(1.0, 0.86, 0.45, 1.0)) -> void:
	if not is_instance_valid(item):
		return
	item.self_modulate = color
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "self_modulate", Color.WHITE, 0.16)


func confirm(item: CanvasItem = null) -> void:
	AudioManager.play_ui("confirm")
	if item != null:
		pulse(item, Color(0.65, 1.0, 0.68, 1.0))


func error(item: CanvasItem = null) -> void:
	AudioManager.play_ui("error")
	if item != null:
		pulse(item, Color(1.0, 0.55, 0.55, 1.0))


func _hook_existing_buttons() -> void:
	_hook_node_recursive(get_tree().root)


func _hook_node_recursive(node: Node) -> void:
	_hook_button(node as BaseButton)
	for child in node.get_children():
		_hook_node_recursive(child)


func _on_node_added(node: Node) -> void:
	_hook_button(node as BaseButton)


func _hook_button(button: BaseButton) -> void:
	if button == null or button.has_meta("feedback_hooked"):
		return
	button.set_meta("feedback_hooked", true)
	button.pressed.connect(_on_button_pressed.bind(button))
	hooked_button_count += 1


func _on_button_pressed(button: BaseButton) -> void:
	AudioManager.play_ui("click")
	pulse(button)
