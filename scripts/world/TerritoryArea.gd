extends Node2D
class_name TerritoryArea

# 当前领地所属宗门数据。
var sect_data: Dictionary = {}

# 领地半径。
var territory_radius: float = 0.0
var local_boundary_points := PackedVector2Array()


# 初始化领地显示。
func setup(data: Dictionary, territory_state: Dictionary = {}) -> void:
	sect_data = data
	position = data["position"]
	territory_radius = float(territory_state.get("display_radius", data["territory_radius"]))
	for world_point in territory_state.get("boundary_points", []):
		local_boundary_points.append((world_point as Vector2) - position)
	queue_redraw()


# 绘制半透明领地范围，只负责显示，不参与点击和逻辑。
func _draw() -> void:
	var is_player: bool = bool(sect_data.get("is_player", false))
	var fill_color: Color = Color(0.20, 0.90, 0.35, 0.16) if is_player else Color(0.25, 0.55, 1.0, 0.12)
	var border_color: Color = Color(0.45, 1.0, 0.55, 0.45) if is_player else Color(0.45, 0.70, 1.0, 0.35)

	if local_boundary_points.size() >= 3:
		draw_colored_polygon(local_boundary_points, fill_color)
		var border_points: PackedVector2Array = local_boundary_points.duplicate()
		border_points.append(local_boundary_points[0])
		draw_polyline(border_points, border_color, 2.0, true)
	else:
		draw_circle(Vector2.ZERO, territory_radius, fill_color)
		draw_arc(Vector2.ZERO, territory_radius, 0.0, TAU, 96, border_color, 2.0)
