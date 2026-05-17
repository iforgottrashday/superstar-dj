extends Control
##
## World map view. Custom-drawn (no images) so it stays self-contained.
## Each region is a hand-defined polygon; fanbase_pct drives the fill color.
##
## Animations driven from _process:
##   - smooth color lerp toward each region's actual fanbase_pct
##   - hover highlight on the region under the cursor
##   - pulse + expanding ring when a region crosses a milestone (50% / 90%)
##

signal region_clicked(region_id: String)

# Designed against an 880×680 canvas. The Control stretches with the panel,
# but polygons are absolute — close enough for v0.5.
const REGION_POLYGONS := {
	"na_west": PackedVector2Array([
		Vector2(40, 100), Vector2(200, 95), Vector2(215, 175),
		Vector2(180, 240), Vector2(40, 220),
	]),
	"na_east": PackedVector2Array([
		Vector2(200, 95), Vector2(320, 105), Vector2(325, 220),
		Vector2(215, 245), Vector2(215, 175),
	]),
	"latam": PackedVector2Array([
		Vector2(215, 245), Vector2(325, 245), Vector2(335, 330),
		Vector2(290, 425), Vector2(245, 425), Vector2(215, 340),
	]),
	"uk": PackedVector2Array([
		Vector2(375, 145), Vector2(410, 145),
		Vector2(410, 180), Vector2(375, 180),
	]),
	"eu_west": PackedVector2Array([
		Vector2(415, 175), Vector2(495, 175),
		Vector2(495, 235), Vector2(415, 235),
	]),
	"eu_east": PackedVector2Array([
		Vector2(495, 105), Vector2(700, 110), Vector2(705, 230),
		Vector2(495, 230), Vector2(495, 175),
	]),
	"africa_north": PackedVector2Array([
		Vector2(420, 240), Vector2(590, 240),
		Vector2(590, 305), Vector2(435, 305),
	]),
	"africa_sub": PackedVector2Array([
		Vector2(450, 310), Vector2(610, 310), Vector2(610, 420),
		Vector2(510, 440), Vector2(455, 395),
	]),
	"mideast": PackedVector2Array([
		Vector2(595, 235), Vector2(680, 235),
		Vector2(680, 310), Vector2(595, 310),
	]),
	"asia_central": PackedVector2Array([
		Vector2(700, 165), Vector2(790, 165),
		Vector2(790, 225), Vector2(700, 225),
	]),
	"asia_south": PackedVector2Array([
		Vector2(685, 230), Vector2(785, 230),
		Vector2(785, 320), Vector2(700, 325),
	]),
	"asia_east": PackedVector2Array([
		Vector2(790, 110), Vector2(875, 105),
		Vector2(875, 240), Vector2(790, 240),
	]),
	"asia_se": PackedVector2Array([
		Vector2(790, 245), Vector2(875, 245), Vector2(875, 320),
		Vector2(845, 420), Vector2(790, 425), Vector2(785, 325),
	]),
	"nkorea": PackedVector2Array([
		Vector2(830, 175), Vector2(855, 175),
		Vector2(855, 200), Vector2(830, 200),
	]),
	"antarctica": PackedVector2Array([
		Vector2(50, 580), Vector2(830, 580),
		Vector2(830, 615), Vector2(50, 625),
	]),
}

const REGION_LABELS := {
	"na_west": "W. N. America",
	"na_east": "E. N. America",
	"latam": "Latin America",
	"uk": "UK",
	"eu_west": "W. Europe",
	"eu_east": "E. Europe & Russia",
	"africa_north": "N. Africa",
	"africa_sub": "Sub-Saharan",
	"mideast": "Middle East",
	"asia_central": "Central Asia",
	"asia_south": "South Asia",
	"asia_east": "East Asia",
	"asia_se": "SE Asia & Oceania",
	"nkorea": "NK",
	"antarctica": "Antarctica",
}

const COLOR_OCEAN := Color(0.04, 0.03, 0.10)
const COLOR_GRID := Color(0.08, 0.06, 0.16)
const COLOR_DIM := Color(0.16, 0.12, 0.26)
const COLOR_BRIGHT := Color(1.0, 0.18, 0.57)        # neon pink (your tracks are everywhere)
const COLOR_BORDER := Color(0.45, 0.32, 0.62)
const COLOR_LOCKED_BORDER := Color(0.78, 0.55, 0.18) # warm amber for closed regions
const COLOR_HOVER_OVERLAY := Color(1.0, 1.0, 1.0, 0.18)
const COLOR_RING := Color(1.0, 0.18, 0.57, 0.8)
const LABEL_FONT_SIZE := 11
const PCT_FONT_SIZE := 10

# Per-region animation state.
var _displayed_pct: Dictionary = {}    # region_id -> float (smoothed toward actual fanbase_pct)
var _pulse: Dictionary = {}            # region_id -> 0..1 (decaying)
var _rings: Array = []                 # [{region_id, age, max_age}]
var _hovered: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(880, 680)
	for region_id in REGION_POLYGONS.keys():
		_displayed_pct[region_id] = 0.0
		_pulse[region_id] = 0.0
	GameState.region_milestone.connect(_on_milestone)
	GameState.channels_changed.connect(_on_channels_changed)

func _process(delta: float) -> void:
	var dirty: bool = false
	for region_id in _displayed_pct.keys():
		var r = GameState.regions_by_id.get(region_id)
		if r == null:
			continue
		var target: float = float(r.fanbase_pct)
		var current: float = float(_displayed_pct[region_id])
		var next_val: float = lerpf(current, target, delta * 2.0)
		if abs(next_val - current) > 0.001 or abs(next_val - target) > 0.001:
			_displayed_pct[region_id] = next_val
			dirty = true
		var p: float = float(_pulse[region_id])
		if p > 0.0:
			_pulse[region_id] = maxf(0.0, p - delta * 1.2)
			dirty = true
	if not _rings.is_empty():
		var kept: Array = []
		for ring in _rings:
			ring["age"] = float(ring["age"]) + delta
			if float(ring["age"]) < float(ring["max_age"]):
				kept.append(ring)
		_rings = kept
		dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	# Ocean + subtle grid.
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_OCEAN, true)
	for gx in range(0, int(size.x) + 1, 80):
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), COLOR_GRID, 1.0)
	for gy in range(0, int(size.y) + 1, 80):
		draw_line(Vector2(0, gy), Vector2(size.x, gy), COLOR_GRID, 1.0)

	# Region fills.
	for region_id in REGION_POLYGONS.keys():
		var pts: PackedVector2Array = REGION_POLYGONS[region_id]
		var pct: float = float(_displayed_pct[region_id])
		var fill: Color = COLOR_DIM.lerp(COLOR_BRIGHT, pct)
		var pulse_v: float = float(_pulse[region_id])
		if pulse_v > 0.0:
			fill = fill.lerp(Color.WHITE, pulse_v * 0.55)
		if region_id == _hovered:
			fill = fill.lerp(Color.WHITE, 0.18)
		draw_colored_polygon(pts, fill)

	# Borders (drawn after fills so they sit on top).
	for region_id in REGION_POLYGONS.keys():
		var pts: PackedVector2Array = REGION_POLYGONS[region_id]
		var r = GameState.regions_by_id.get(region_id)
		var border: Color = COLOR_LOCKED_BORDER if (r != null and bool(r.closed)) else COLOR_BORDER
		var width: float = 2.5 if region_id == _hovered else 1.5
		draw_polyline(_closed_loop(pts), border, width, true)

	# Milestone rings.
	for ring in _rings:
		var pts: PackedVector2Array = REGION_POLYGONS[ring["region_id"]]
		var center: Vector2 = _centroid(pts)
		var t: float = float(ring["age"]) / float(ring["max_age"])
		var radius: float = lerpf(15.0, 110.0, t)
		var alpha: float = (1.0 - t) * 0.9
		var col: Color = COLOR_RING
		col.a = alpha
		draw_arc(center, radius, 0.0, TAU, 64, col, 2.5, true)

	# Labels + percentages.
	var font: Font = ThemeDB.fallback_font
	for region_id in REGION_LABELS.keys():
		var pts: PackedVector2Array = REGION_POLYGONS[region_id]
		var center: Vector2 = _centroid(pts)
		var label_text: String = REGION_LABELS[region_id]
		var r = GameState.regions_by_id.get(region_id)
		if r != null and bool(r.closed):
			label_text = "🔒 " + label_text
		var label_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
		draw_string(font, center - Vector2(label_size.x * 0.5, 0), label_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE, Color(1, 1, 1, 0.92))
		var pct_text: String = "%d%%" % int(float(_displayed_pct[region_id]) * 100.0)
		var pct_size: Vector2 = font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, PCT_FONT_SIZE)
		draw_string(font, center - Vector2(pct_size.x * 0.5, -14.0), pct_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, PCT_FONT_SIZE, Color(1, 1, 1, 0.7))
		# Active channel dots — one per active channel, color from CHANNEL_CATALOG.
		var active: Array = GameState.region_channels.get(region_id, [])
		if active.size() > 0:
			var dot_radius: float = 3.0
			var spacing: float = 9.0
			var total_w: float = (active.size() - 1) * spacing
			var dot_y: float = center.y + 26.0
			var dot_x_start: float = center.x - total_w * 0.5
			for i in active.size():
				var ch_id: String = String(active[i]["channel_id"])
				var ch_def: Dictionary = GameState.CHANNEL_CATALOG[ch_id]
				draw_circle(Vector2(dot_x_start + i * spacing, dot_y), dot_radius, ch_def["color"])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover: String = _region_at(event.position)
		if new_hover != _hovered:
			_hovered = new_hover
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var picked: String = _region_at(mb.position)
			if picked != "":
				_pulse[picked] = 1.0
				queue_redraw()
				emit_signal("region_clicked", picked)

func _region_at(p: Vector2) -> String:
	for region_id in REGION_POLYGONS.keys():
		if Geometry2D.is_point_in_polygon(p, REGION_POLYGONS[region_id]):
			return region_id
	return ""

func _on_milestone(region_id: String, _threshold: float) -> void:
	_pulse[region_id] = 1.0
	_rings.append({"region_id": region_id, "age": 0.0, "max_age": 1.8})
	queue_redraw()

func _on_channels_changed(_region_id: String) -> void:
	queue_redraw()

func _closed_loop(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append_array(pts)
	if pts.size() > 0:
		out.append(pts[0])
	return out

func _centroid(pts: PackedVector2Array) -> Vector2:
	if pts.size() == 0:
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for p in pts:
		sum += p
	return sum / float(pts.size())
