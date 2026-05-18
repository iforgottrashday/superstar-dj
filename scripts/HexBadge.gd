extends Control
##
## Pointy-top hex badge with a centered glyph (emoji). Used in the species
## picker rows so each faction has a "logo tile" matching the in-game hex
## map tiles. Properties are plain vars set from script before the badge
## is added to the tree; _draw redraws whenever size or values change.
##

var fill_color: Color = Color(0.05, 0.03, 0.01, 0.85)
var border_color: Color = Color(1, 1, 1, 1)
var border_width: float = 3.0
var glyph: String = ""

func _draw() -> void:
	var radius: float = min(size.x, size.y) * 0.5 - border_width
	if radius <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = PI / 3.0 * float(i) - PI / 2.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, fill_color)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, border_color, border_width, true)
	if glyph != "":
		var font: Font = ThemeDB.fallback_font
		var font_px: int = int(radius * 0.95)
		var sz: Vector2 = font.get_string_size(glyph,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_px)
		draw_string(font,
			center - Vector2(sz.x * 0.5, -sz.y * 0.32),
			glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_px)
