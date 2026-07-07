extends Node2D
class_name TerritoryArea

# 当前领地所属宗门数据。
var sect_data: Dictionary = {}

# 领地半径。
var territory_radius: float = 0.0


# 初始化领地显示。
func setup(data: Dictionary) -> void:
	sect_data = data
	position = data["position"]
	territory_radius = float(data["territory_radius"])
	queue_redraw()


# 绘制半透明领地范围，只负责显示，不参与点击和逻辑。
func _draw() -> void:
	var is_player: bool = bool(sect_data.get("is_player", false))
	var fill_color: Color = Color(0.20, 0.90, 0.35, 0.16) if is_player else Color(0.25, 0.55, 1.0, 0.12)
	var border_color: Color = Color(0.45, 1.0, 0.55, 0.45) if is_player else Color(0.45, 0.70, 1.0, 0.35)

	draw_circle(Vector2.ZERO, territory_radius, fill_color)
	draw_arc(Vector2.ZERO, territory_radius, 0.0, TAU, 96, border_color, 3.0)
