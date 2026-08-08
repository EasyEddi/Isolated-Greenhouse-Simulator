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
	if icon_kind.begins_with("species:"):
		_draw_species(center, scale, icon_kind.trim_prefix("species:"))
		return
	if icon_kind.begins_with("soil:"):
		_draw_bag(center, scale, false, PlantCatalog.care_item_accent(icon_kind))
		return
	if icon_kind.begins_with("feed:"):
		_draw_bag(center, scale, true, PlantCatalog.care_item_accent(icon_kind))
		return
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


func _draw_bag(center: Vector2, scale: float, feed: bool, accent: Color = Color.TRANSPARENT) -> void:
	var base := accent if accent.a > 0.01 else (Color("#6ca968") if feed else Color("#8c684b"))
	var points := PackedVector2Array([
		center + Vector2(-14, -17) * scale,
		center + Vector2(13, -17) * scale,
		center + Vector2(17, -7) * scale,
		center + Vector2(14, 18) * scale,
		center + Vector2(-15, 18) * scale,
		center + Vector2(-18, -6) * scale,
	])
	draw_colored_polygon(points, base)
	draw_rect(Rect2(center + Vector2(-11, -7) * scale, Vector2(22, 16) * scale), base.lightened(0.56), true)
	if feed:
		draw_circle(center + Vector2(0, 1) * scale, 5 * scale, base.darkened(0.18))
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 5) * scale, center + Vector2(0, -5) * scale, center + Vector2(8, 5) * scale]), base.darkened(0.24))


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


func _draw_species(center: Vector2, scale: float, species_id: String) -> void:
	var stem_color := secondary_color.darkened(0.12)
	var pot_color := Color("#ad6748")
	var soil_color := Color("#4a3323")
	var pot_top := center + Vector2(0, 9) * scale
	draw_rect(Rect2(center + Vector2(-12, 8) * scale, Vector2(24, 4) * scale), soil_color, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13, 10) * scale,
		center + Vector2(13, 10) * scale,
		center + Vector2(9, 20) * scale,
		center + Vector2(-9, 20) * scale,
	]), pot_color)
	match species_id:
		"snake_plant":
			for spec in [[-8.0, -23.0, -3.0], [-3.0, -31.0, 0.0], [3.0, -28.0, 2.0], [8.0, -20.0, 4.0], [0.0, -22.0, -2.0]]:
				var base := pot_top + Vector2(float(spec[0]), 0) * scale
				var tip := center + Vector2(float(spec[2]), float(spec[1])) * scale
				var side := Vector2(2.6, 0) * scale
				draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), icon_color if int(spec[0]) % 2 else secondary_color)
		"aloe_vera":
			for index in range(7):
				var angle := lerpf(-2.55, -0.58, float(index) / 6.0)
				var direction := Vector2(cos(angle), sin(angle))
				_draw_mini_leaf(pot_top, direction, 20.0, 3.2, icon_color if index % 2 else secondary_color, scale)
		"echeveria":
			var rosette_center := center + Vector2(0, 1) * scale
			for ring in range(3):
				for index in range(7):
					var angle := TAU * float(index) / 7.0 + ring * 0.32
					var direction := Vector2(cos(angle), sin(angle))
					_draw_mini_leaf(rosette_center, direction, 7.0 + ring * 3.5, 3.2, icon_color.lightened(0.08 * ring), scale)
		"sunflower":
			draw_line(pot_top, center + Vector2(0, -16) * scale, stem_color, 3.0 * scale, true)
			for index in range(10):
				var angle := TAU * float(index) / 10.0
				var petal_center := center + Vector2(cos(angle), sin(angle)) * 9.0 * scale + Vector2(0, -17) * scale
				draw_circle(petal_center, 4.2 * scale, Color("#e5b843"))
			draw_circle(center + Vector2(0, -17) * scale, 6.5 * scale, Color("#6c4728"))
		"lavender":
			for index in range(5):
				var x := -8.0 + index * 4.0
				draw_line(pot_top + Vector2(x * 0.35, 0) * scale, center + Vector2(x, -19 - abs(index - 2) * 2) * scale, stem_color, 1.8 * scale, true)
				for bud in range(4):
					draw_circle(center + Vector2(x + (1 if bud % 2 else -1), -18 + bud * 3 - abs(index - 2) * 2) * scale, 2.3 * scale, Color("#9a73ad"))
		"lily", "peace_lily":
			for index in range(4):
				var direction := Vector2(-0.85 + index * 0.56, -1.0).normalized()
				_draw_mini_leaf(pot_top, direction, 17.0 + index * 1.5, 4.3, icon_color, scale)
			draw_line(pot_top, center + Vector2(2, -19) * scale, stem_color, 2.0 * scale, true)
			if species_id == "peace_lily":
				_draw_mini_leaf(center + Vector2(2, -16) * scale, Vector2(0.75, -0.66), 10.0, 4.5, Color("#edf0dd"), scale)
			else:
				for index in range(6):
					var angle := TAU * float(index) / 6.0
					_draw_mini_leaf(center + Vector2(2, -19) * scale, Vector2(cos(angle), sin(angle)), 8.0, 2.8, Color("#efcad5"), scale)
		"boston_fern":
			for frond in range(7):
				var direction := Vector2(-0.90 + frond * 0.30, -1.0).normalized()
				var end := pot_top + direction * (18.0 + (frond % 3) * 3.0) * scale
				draw_line(pot_top, end, stem_color, 1.6 * scale, true)
				for leaflet in range(3, 9):
					var t := float(leaflet) / 10.0
					var point := pot_top.lerp(end, t)
					var side := direction.orthogonal()
					_draw_mini_leaf(point, side, 4.2, 1.5, icon_color, scale)
					_draw_mini_leaf(point, -side, 4.2, 1.5, secondary_color, scale)
		"golden_pothos":
			var vine := PackedVector2Array([
				pot_top,
				center + Vector2(-4, -3) * scale,
				center + Vector2(7, -12) * scale,
				center + Vector2(13, -4) * scale,
			])
			draw_polyline(vine, stem_color, 2.2 * scale, true)
			for spec in [[-4.0, -3.0, -0.8], [7.0, -12.0, -2.2], [13.0, -4.0, -0.3]]:
				_draw_mini_leaf(center + Vector2(float(spec[0]), float(spec[1])) * scale, Vector2(cos(float(spec[2])), sin(float(spec[2]))), 9.0, 4.6, icon_color, scale)
		"mint":
			for index in range(3):
				var x := -6.0 + index * 6.0
				var top := center + Vector2(x, -18 - index * 2) * scale
				draw_line(pot_top + Vector2(x * 0.25, 0) * scale, top, stem_color, 2.0 * scale, true)
				for level in range(3):
					var point := pot_top.lerp(top, 0.28 + level * 0.24)
					_draw_mini_leaf(point, Vector2(-0.85, -0.25), 7.0, 3.4, icon_color, scale)
					_draw_mini_leaf(point, Vector2(0.85, -0.25), 7.0, 3.4, secondary_color, scale)
		_:
			for index in range(5):
				var direction := Vector2(-0.88 + index * 0.44, -1.0).normalized()
				draw_line(pot_top, pot_top + direction * 11.0 * scale, stem_color, 2.0 * scale, true)
				_draw_mini_leaf(pot_top + direction * 10.0 * scale, direction, 12.0 + (index % 2) * 3.0, 5.4, icon_color if index % 2 else secondary_color, scale)


func _draw_mini_leaf(base: Vector2, direction: Vector2, length: float, width: float, color: Color, scale: float) -> void:
	var normalized := direction.normalized()
	var side := normalized.orthogonal() * width * scale
	var middle := base + normalized * length * 0.46 * scale
	var tip := base + normalized * length * scale
	draw_colored_polygon(PackedVector2Array([base, middle + side, tip, middle - side]), color)
