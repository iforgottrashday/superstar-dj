class_name HexBadge
extends Control
##
## Pointy-top hex badge with a procedural faction glyph centered inside.
## We avoid emoji fonts entirely — Godot's SystemFont emoji fallback is
## flaky on Android — by drawing simple vector shapes per faction.
## Used in the species-picker rows and reusable from WorldMap to overlay
## the same glyph on owned hexes.
##

var fill_color: Color = Color(0.05, 0.03, 0.01, 0.85)
var border_color: Color = Color(1, 1, 1, 1)
var border_width: float = 3.0
var faction_id: String = ""
var glyph_color: Color = Color(1, 1, 1, 1)

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
	if faction_id != "":
		draw_faction_glyph(self, faction_id, center, radius * 0.78, glyph_color)


static var _texture_cache: Dictionary = {}

static func _glyph_texture(faction: String) -> Texture2D:
	# Cached lookup for res://assets/glyphs/<faction>.png. Returns null when
	# the file doesn't exist, letting draw_faction_glyph fall through to its
	# procedural shape branch. Cache stores null too so we don't re-probe.
	if _texture_cache.has(faction):
		return _texture_cache[faction]
	var path: String = "res://assets/glyphs/%s.png" % faction
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_texture_cache[faction] = tex
	return tex


static func draw_faction_glyph(
		canvas: CanvasItem, faction: String, center: Vector2,
		radius: float, color: Color) -> void:
	# Prefer hand-drawn art when present at res://assets/glyphs/<faction>.png.
	# Expected: 512x512 PNG, white silhouette on transparent, ~10% padding.
	# We draw with `color` as the modulate so the same source file tints to
	# faction color in the picker and to faint white on the in-map watermark.
	var tex: Texture2D = _glyph_texture(faction)
	if tex != null:
		var draw_size := Vector2(radius * 2.0, radius * 2.0)
		var dest := Rect2(center - draw_size * 0.5, draw_size)
		canvas.draw_texture_rect(tex, dest, false, color)
		return
	# Procedural fallback — guarantees something renders for every faction
	# even before art files exist.
	match faction:
		"wolves":
			# Crescent moon (the howl).
			var pts := PackedVector2Array()
			var rr: float = radius * 0.95
			for i in 24:
				var a: float = lerpf(-PI * 0.55, PI * 0.55, float(i) / 23.0)
				pts.append(center + Vector2(cos(a), sin(a)) * rr)
			var inner_offset := Vector2(rr * 0.45, 0)
			var inner_r: float = rr * 0.82
			for i in 24:
				var a: float = lerpf(PI * 0.55, -PI * 0.55, float(i) / 23.0)
				pts.append(center + inner_offset + Vector2(cos(a), sin(a)) * inner_r)
			canvas.draw_colored_polygon(pts, color)
		"bears":
			# Mountain triangle (strength, den).
			var tri := PackedVector2Array([
				center + Vector2(0, -radius * 0.85),
				center + Vector2(radius * 0.85, radius * 0.55),
				center + Vector2(-radius * 0.85, radius * 0.55),
			])
			canvas.draw_colored_polygon(tri, color)
		"lions":
			# 8-point star (pride, sun).
			var star := PackedVector2Array()
			for i in 16:
				var a: float = float(i) * PI / 8.0 - PI / 2.0
				var r: float = radius if i % 2 == 0 else radius * 0.45
				star.append(center + Vector2(cos(a), sin(a)) * r)
			canvas.draw_colored_polygon(star, color)
		"eagles":
			# Up-pointing chevron (wings).
			var w: float = max(2.0, radius * 0.20)
			canvas.draw_line(
				center + Vector2(-radius * 0.85, radius * 0.35),
				center + Vector2(0, -radius * 0.45), color, w, true)
			canvas.draw_line(
				center + Vector2(radius * 0.85, radius * 0.35),
				center + Vector2(0, -radius * 0.45), color, w, true)
			# A second, tighter chevron below for emphasis.
			canvas.draw_line(
				center + Vector2(-radius * 0.55, radius * 0.65),
				center + Vector2(0, radius * 0.05), color, w, true)
			canvas.draw_line(
				center + Vector2(radius * 0.55, radius * 0.65),
				center + Vector2(0, radius * 0.05), color, w, true)
		"crocs":
			# Zigzag teeth.
			var w: float = max(2.0, radius * 0.20)
			var teeth := PackedVector2Array([
				center + Vector2(-radius * 0.85, radius * 0.15),
				center + Vector2(-radius * 0.42, -radius * 0.45),
				center + Vector2(0, radius * 0.15),
				center + Vector2(radius * 0.42, -radius * 0.45),
				center + Vector2(radius * 0.85, radius * 0.15),
			])
			for i in teeth.size() - 1:
				canvas.draw_line(teeth[i], teeth[i + 1], color, w, true)
		"hunters":
			# Crosshair (target).
			var w: float = max(2.0, radius * 0.14)
			canvas.draw_circle(center, radius * 0.22, color)
			canvas.draw_arc(center, radius * 0.55, 0.0, TAU, 48, color, w, true)
			canvas.draw_line(
				center + Vector2(-radius * 0.95, 0),
				center + Vector2(-radius * 0.4, 0), color, w, true)
			canvas.draw_line(
				center + Vector2(radius * 0.95, 0),
				center + Vector2(radius * 0.4, 0), color, w, true)
			canvas.draw_line(
				center + Vector2(0, -radius * 0.95),
				center + Vector2(0, -radius * 0.4), color, w, true)
			canvas.draw_line(
				center + Vector2(0, radius * 0.95),
				center + Vector2(0, radius * 0.4), color, w, true)
		"wild_dogs":
			# Diamond / rhombus (scavenger pack convergence).
			var diamond := PackedVector2Array([
				center + Vector2(0, -radius * 0.9),
				center + Vector2(radius * 0.65, 0),
				center + Vector2(0, radius * 0.9),
				center + Vector2(-radius * 0.65, 0),
			])
			canvas.draw_colored_polygon(diamond, color)
		_:
			# Neutral / unknown — draw nothing.
			pass
