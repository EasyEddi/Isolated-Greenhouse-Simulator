class_name GreenhouseIcon
extends Control

@export var icon_kind: String = "leaf":
	set(value):
		icon_kind = value
		queue_redraw()
@export var icon_color := Color("#9ee6a6"):
	set(value):
		icon_color = value
		queue_redraw()
@export var secondary_color := Color("#4e9a72"):
	set(value):
		secondary_color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(38, 38)


func _draw() -> void:
	var center := size * 0.5
	var scale := minf(size.x, size.y) / 48.0
	match icon_kind:
		"leaf", "offshoot":
			_draw_leaf(center, scale)
		"water":
			_draw_water(center, scale)
		"trowel":
			_draw_trowel(center, scale)
		"cut":
			_draw_secateurs(center, scale)
		"soil":
			_draw_bag(center, scale, false)
		"feed":
			_draw_bag(center, scale, true)
		"starter":
			_draw_starter(center, scale)
		"cart":
			_draw_cart(center, scale)
		"equipment":
			_draw_trowel(center, scale)
		_:
			_draw_leaf(center, scale)


func _draw_leaf(center: Vector2, scale: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-17, 12) * scale,
		center + Vector2(-15, -1) * scale,
		center + Vector2(-7, -13) * scale,
		center + Vector2(7, -19) * scale,
		center + Vector2(18, -17) * scale,
		center + Vector2(19, -7) * scale,
		center + Vector2(13, 6) * scale,
		center + Vector2(1, 15) * scale,
	])
	draw_colored_polygon(points, icon_color)
	var facet := PackedVector2Array([
		center + Vector2(-17, 12) * scale,
		center + Vector2(-7, -13) * scale,
		center + Vector2(2, 5) * scale,
	])
	draw_colored_polygon(facet, secondary_color)
	draw_polyline(PackedVector2Array([center + Vector2(-19, 19) * scale, center + Vector2(3, 3) * scale, center + Vector2(17, -14) * scale]), Color("#d7f2b5"), 2.1 * scale, true)
	draw_polyline(PackedVector2Array([center + Vector2(-6, 10) * scale, center + Vector2(-9, -4) * scale]), secondary_color.lightened(0.18), 1.2 * scale, true)
	draw_polyline(PackedVector2Array([center + Vector2(1, 4) * scale, center + Vector2(13, 5) * scale]), secondary_color.lightened(0.18), 1.2 * scale, true)
	draw_polyline(PackedVector2Array([center + Vector2(4, 0) * scale, center + Vector2(6, -12) * scale]), secondary_color.lightened(0.18), 1.2 * scale, true)


func _draw_water(center: Vector2, scale: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -20) * scale,
		center + Vector2(-13, 0) * scale,
		center + Vector2(-12, 12) * scale,
		center + Vector2(-5, 18) * scale,
		center + Vector2(6, 17) * scale,
		center + Vector2(13, 9) * scale,
		center + Vector2(12, 0) * scale,
	])
	draw_colored_polygon(points, Color("#79cad8"))
	draw_arc(center + Vector2(1, 5) * scale, 9 * scale, 0.2, 2.2, 18, Color("#c8eef0"), 2 * scale, true)


func _draw_trowel(center: Vector2, scale: float) -> void:
	draw_line(center + Vector2(-12, 15) * scale, center + Vector2(8, -8) * scale, Color("#9f7144"), 5 * scale, true)
	draw_line(center + Vector2(5, -5) * scale, center + Vector2(14, -14) * scale, Color("#c5d0cb"), 8 * scale, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-18, 18) * scale, center + Vector2(-9, 3) * scale, center + Vector2(-2, 10) * scale]), Color("#b8c6c0"))


func _draw_secateurs(center: Vector2, scale: float) -> void:
	draw_arc(center + Vector2(-9, 11) * scale, 7 * scale, 0, TAU, 18, Color("#c97854"), 4 * scale, true)
	draw_arc(center + Vector2(9, 11) * scale, 7 * scale, 0, TAU, 18, Color("#c97854"), 4 * scale, true)
	draw_line(center + Vector2(-5, 6) * scale, center + Vector2(12, -16) * scale, Color("#d3ded7"), 4 * scale, true)
	draw_line(center + Vector2(5, 6) * scale, center + Vector2(-11, -14) * scale, Color("#aabbb4"), 4 * scale, true)
	draw_circle(center + Vector2(0, 3) * scale, 3 * scale, Color("#3d514d"))


func _draw_bag(center: Vector2, scale: float, feed: bool) -> void:
	var base := Color("#6ca968") if feed else Color("#8c684b")
	var points := PackedVector2Array([
		center + Vector2(-14, -17) * scale,
		center + Vector2(13, -17) * scale,
		center + Vector2(17, -7) * scale,
		center + Vector2(14, 18) * scale,
		center + Vector2(-15, 18) * scale,
		center + Vector2(-18, -6) * scale,
	])
	draw_colored_polygon(points, base)
	draw_rect(Rect2(center + Vector2(-11, -7) * scale, Vector2(22, 16) * scale), Color("#d8d2b5"), true)
	if feed:
		draw_circle(center + Vector2(0, 1) * scale, 5 * scale, Color("#6ca968"))
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 5) * scale, center + Vector2(0, -5) * scale, center + Vector2(8, 5) * scale]), Color("#6a4b35"))


func _draw_starter(center: Vector2, scale: float) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 7) * scale, center + Vector2(13, 7) * scale, center + Vector2(9, 19) * scale, center + Vector2(-9, 19) * scale]), Color("#ad6748"))
	draw_line(center + Vector2(0, 8) * scale, center + Vector2(0, -10) * scale, Color("#5d8f56"), 3 * scale, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7) * scale, center + Vector2(-15, -14) * scale, center + Vector2(-9, 0) * scale]), icon_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -10) * scale, center + Vector2(14, -17) * scale, center + Vector2(8, -2) * scale]), secondary_color)


func _draw_cart(center: Vector2, scale: float) -> void:
	var line := Color("#d5e5dc")
	draw_polyline(PackedVector2Array([center + Vector2(-19, -15) * scale, center + Vector2(-13, -15) * scale, center + Vector2(-7, 8) * scale, center + Vector2(13, 8) * scale, center + Vector2(18, -7) * scale, center + Vector2(-10, -7) * scale]), line, 3.2 * scale, true)
	draw_circle(center + Vector2(-3, 16) * scale, 3.5 * scale, icon_color)
	draw_circle(center + Vector2(12, 16) * scale, 3.5 * scale, icon_color)
