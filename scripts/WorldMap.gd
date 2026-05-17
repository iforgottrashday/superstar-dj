extends Control
##
## Medieval Eurasian world map for the conquest engine.
## Each region's fill color = its owning faction's color.
## Army strength is drawn as a number; fortified regions show a small marker.
##
## Polygon coordinates are authored against a fixed DESIGN_WIDTH × DESIGN_HEIGHT
## "world" space. At draw and hit-test time we map world coords to the actual
## Control size — so the map auto-scales to fit whatever space the column
## gives it (responds to splitter drag, window resize, etc).
##

signal region_clicked(region_id: String)

# Authoring space. All polygons below are coordinates in this rectangle.
const DESIGN_WIDTH := 880.0
const DESIGN_HEIGHT := 600.0

# Hand-drawn rough geographic shapes for medieval Eurasia.
# Mercator-style; gaps between regions read as seas / mountain ranges.
# Adjacency for combat is in regions.json, not polygon contact.
var REGION_POLYGONS: Dictionary = {
	"england": PackedVector2Array([
		Vector2(120, 175), Vector2(155, 165), Vector2(172, 195),
		Vector2(165, 225), Vector2(138, 235), Vector2(115, 215), Vector2(110, 195),
	]),
	"france": PackedVector2Array([
		Vector2(178, 230), Vector2(235, 222), Vector2(273, 245),
		Vector2(272, 290), Vector2(245, 310), Vector2(200, 308), Vector2(175, 285),
	]),
	"iberia": PackedVector2Array([
		Vector2(55, 295), Vector2(130, 290), Vector2(172, 308),
		Vector2(175, 345), Vector2(155, 370), Vector2(108, 380),
		Vector2(65, 370), Vector2(40, 340),
	]),
	"maghreb": PackedVector2Array([
		Vector2(50, 410), Vector2(200, 402), Vector2(305, 415),
		Vector2(370, 432), Vector2(375, 465), Vector2(320, 480),
		Vector2(215, 478), Vector2(105, 472), Vector2(50, 452),
	]),
	"hre": PackedVector2Array([
		Vector2(280, 225), Vector2(350, 220), Vector2(392, 245),
		Vector2(392, 290), Vector2(370, 320), Vector2(320, 320),
		Vector2(282, 308), Vector2(275, 260),
	]),
	"eastern_eu": PackedVector2Array([
		Vector2(395, 222), Vector2(485, 220), Vector2(528, 250),
		Vector2(530, 295), Vector2(500, 325), Vector2(450, 325),
		Vector2(408, 320), Vector2(395, 285),
	]),
	"russia": PackedVector2Array([
		Vector2(255, 75), Vector2(440, 68), Vector2(580, 75),
		Vector2(680, 85), Vector2(700, 135), Vector2(680, 175),
		Vector2(585, 195), Vector2(495, 200), Vector2(390, 200),
		Vector2(315, 195), Vector2(268, 165), Vector2(250, 110),
	]),
	"byzantium": PackedVector2Array([
		Vector2(410, 335), Vector2(475, 330), Vector2(530, 345),
		Vector2(568, 360), Vector2(560, 388), Vector2(525, 400),
		Vector2(475, 395), Vector2(430, 385), Vector2(410, 365),
	]),
	"levant": PackedVector2Array([
		Vector2(540, 370), Vector2(590, 365), Vector2(605, 395),
		Vector2(605, 440), Vector2(585, 460), Vector2(560, 460),
		Vector2(540, 430), Vector2(535, 395),
	]),
	"egypt": PackedVector2Array([
		Vector2(412, 472), Vector2(490, 465), Vector2(530, 485),
		Vector2(525, 525), Vector2(475, 545), Vector2(420, 542),
		Vector2(395, 515), Vector2(400, 488),
	]),
	"persia": PackedVector2Array([
		Vector2(585, 282), Vector2(680, 277), Vector2(730, 292),
		Vector2(738, 332), Vector2(718, 365), Vector2(660, 380),
		Vector2(610, 370), Vector2(585, 340),
	]),
	"central_asia": PackedVector2Array([
		Vector2(490, 205), Vector2(615, 200), Vector2(700, 200),
		Vector2(745, 225), Vector2(742, 270), Vector2(680, 277),
		Vector2(610, 275), Vector2(520, 252), Vector2(488, 225),
	]),
	"india": PackedVector2Array([
		Vector2(700, 390), Vector2(775, 385), Vector2(815, 405),
		Vector2(820, 445), Vector2(790, 490), Vector2(755, 520),
		Vector2(720, 510), Vector2(705, 470), Vector2(695, 425),
	]),
	"china": PackedVector2Array([
		Vector2(745, 215), Vector2(830, 215), Vector2(875, 230),
		Vector2(875, 360), Vector2(855, 400), Vector2(820, 410),
		Vector2(790, 400), Vector2(760, 375), Vector2(745, 270),
	]),
	"mongolia": PackedVector2Array([
		Vector2(680, 105), Vector2(760, 100), Vector2(840, 105),
		Vector2(875, 115), Vector2(875, 200), Vector2(745, 200),
		Vector2(700, 195), Vector2(700, 145),
	]),
}

# Parchment / medieval-cartography palette.
const COLOR_OCEAN := Color(0.78, 0.69, 0.52)
const COLOR_GRID := Color(0.65, 0.55, 0.40, 0.35)
const COLOR_BORDER := Color(0.22, 0.13, 0.05)
const COLOR_BORDER_HOVER := Color(0.10, 0.05, 0.02)
const COLOR_HOVER_OVERLAY := Color(0.0, 0.0, 0.0, 0.10)
const COLOR_RING := Color(0.60, 0.15, 0.10, 0.85)
const COLOR_NEUTRAL_FILL := Color(0.86, 0.78, 0.62)
const COLOR_LABEL := Color(0.18, 0.10, 0.03)
const COLOR_ARMY_LABEL := Color(0.95, 0.88, 0.70)
const COLOR_ARMY_LABEL_BG := Color(0.22, 0.13, 0.05, 1.0)
const COLOR_ARMY_LABEL_BORDER := Color(0.45, 0.30, 0.10, 1.0)
const COLOR_PLAYER_GLOW := Color(0.55, 0.10, 0.05)
const LABEL_FONT_SIZE := 15
const ARMY_FONT_SIZE := 18

var _displayed_pulse: Dictionary = {}
var _rings: Array = []
var _hovered: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for region_id in REGION_POLYGONS.keys():
		_displayed_pulse[region_id] = 0.0
	GameState.region_ownership_changed.connect(_on_ownership_changed)
	GameState.region_army_changed.connect(_on_army_changed)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	var dirty: bool = false
	for region_id in _displayed_pulse.keys():
		var p: float = float(_displayed_pulse[region_id])
		if p > 0.0:
			_displayed_pulse[region_id] = maxf(0.0, p - delta * 1.2)
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


# ─── world ⇄ canvas transform ───────────────────────────────────────────────

func _map_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(size.x / DESIGN_WIDTH, size.y / DESIGN_HEIGHT)

func _map_offset() -> Vector2:
	var s: float = _map_scale()
	return Vector2(
		(size.x - DESIGN_WIDTH * s) * 0.5,
		(size.y - DESIGN_HEIGHT * s) * 0.5,
	)

func _to_canvas(p: Vector2) -> Vector2:
	return p * _map_scale() + _map_offset()

func _from_canvas(p: Vector2) -> Vector2:
	var s: float = _map_scale()
	if s == 0.0:
		return Vector2.ZERO
	return (p - _map_offset()) / s

func _polygon_to_canvas(pts: PackedVector2Array) -> PackedVector2Array:
	var s: float = _map_scale()
	var off: Vector2 = _map_offset()
	var out: PackedVector2Array = PackedVector2Array()
	for p in pts:
		out.append(p * s + off)
	return out


# ─── drawing ────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Ocean + parchment grid use raw Control size (full background).
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_OCEAN, true)
	for gx in range(0, int(size.x) + 1, 80):
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), COLOR_GRID, 1.0)
	for gy in range(0, int(size.y) + 1, 80):
		draw_line(Vector2(0, gy), Vector2(size.x, gy), COLOR_GRID, 1.0)

	# Region fills, tinted by owner faction over parchment.
	for region_id in REGION_POLYGONS.keys():
		var pts: PackedVector2Array = _polygon_to_canvas(REGION_POLYGONS[region_id])
		var r = GameState.regions_by_id.get(region_id)
		var fill: Color = COLOR_NEUTRAL_FILL
		if r != null:
			var owner_id: String = String(r.owner)
			if owner_id != "neutral" and GameState.FACTION_CATALOG.has(owner_id):
				fill = GameState.FACTION_CATALOG[owner_id]["color"].lerp(Color(0.94, 0.87, 0.70), 0.55)
		var pulse_v: float = float(_displayed_pulse[region_id])
		if pulse_v > 0.0:
			fill = fill.lerp(Color(1.0, 1.0, 1.0), pulse_v * 0.45)
		if region_id == _hovered:
			fill = fill.lerp(Color(0.20, 0.10, 0.02), 0.15)
		draw_colored_polygon(pts, fill)

	# Player-owned glow halo.
	for region_id in REGION_POLYGONS.keys():
		var r = GameState.regions_by_id.get(region_id)
		if r != null and String(r.owner) == GameState.player_faction and GameState.player_faction != "":
			draw_polyline(_closed_loop(_polygon_to_canvas(REGION_POLYGONS[region_id])), COLOR_PLAYER_GLOW, 4.0, true)

	# Region borders.
	for region_id in REGION_POLYGONS.keys():
		var border: Color = COLOR_BORDER
		var width: float = 2.0
		if region_id == _hovered:
			border = COLOR_BORDER_HOVER
			width = 3.5
		draw_polyline(_closed_loop(_polygon_to_canvas(REGION_POLYGONS[region_id])), border, width, true)

	# Combat rings (expanding rings after a battle). Scale ring radius too so
	# they're proportional to the map.
	var s: float = _map_scale()
	for ring in _rings:
		var pts: PackedVector2Array = REGION_POLYGONS[ring["region_id"]]
		var center: Vector2 = _to_canvas(_centroid(pts))
		var t: float = float(ring["age"]) / float(ring["max_age"])
		var radius: float = lerpf(15.0, 90.0, t) * s
		var alpha: float = (1.0 - t) * 0.85
		var col: Color = ring.get("color", COLOR_RING)
		col.a = alpha
		draw_arc(center, radius, 0.0, TAU, 64, col, 2.5, true)

	# Labels: region name + army strength badge. Font sizes stay constant
	# (don't scale with the map) so they remain readable at any size.
	var font: Font = ThemeDB.fallback_font
	for region_id in REGION_POLYGONS.keys():
		var pts: PackedVector2Array = REGION_POLYGONS[region_id]
		var center: Vector2 = _to_canvas(_centroid(pts))
		var r = GameState.regions_by_id.get(region_id)
		var label_text: String = String(r.name) if r != null else region_id
		var label_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
		draw_string(font, center - Vector2(label_size.x * 0.5, 4.0), label_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE, COLOR_LABEL)
		if r != null:
			var army_text: String = str(int(r.army))
			if bool(r.fortified):
				army_text = "🏰 " + army_text
			var atxt_size: Vector2 = font.get_string_size(army_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ARMY_FONT_SIZE)
			var badge_w: float = atxt_size.x + 12.0
			var badge_h: float = ARMY_FONT_SIZE + 6.0
			var badge_rect: Rect2 = Rect2(center.x - badge_w * 0.5, center.y + 10.0, badge_w, badge_h)
			draw_rect(badge_rect, COLOR_ARMY_LABEL_BG, true)
			draw_rect(badge_rect, COLOR_ARMY_LABEL_BORDER, false, 1.0)
			draw_string(font, Vector2(badge_rect.position.x + 6.0, badge_rect.position.y + ARMY_FONT_SIZE),
				army_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ARMY_FONT_SIZE, COLOR_ARMY_LABEL)


# ─── input ──────────────────────────────────────────────────────────────────

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
				_displayed_pulse[picked] = 1.0
				queue_redraw()
				emit_signal("region_clicked", picked)

func _region_at(p: Vector2) -> String:
	# Inverse-transform the click into world space, then test against the
	# original polygons.
	var world_p: Vector2 = _from_canvas(p)
	for region_id in REGION_POLYGONS.keys():
		if Geometry2D.is_point_in_polygon(world_p, REGION_POLYGONS[region_id]):
			return region_id
	return ""


# ─── signals ────────────────────────────────────────────────────────────────

func _on_ownership_changed(region_id: String, _new_owner: String) -> void:
	_displayed_pulse[region_id] = 1.0
	var ring_color: Color = COLOR_RING
	var r = GameState.regions_by_id.get(region_id)
	if r != null and GameState.FACTION_CATALOG.has(String(r.owner)):
		ring_color = GameState.FACTION_CATALOG[String(r.owner)]["color"]
	_rings.append({"region_id": region_id, "age": 0.0, "max_age": 1.5, "color": ring_color})
	queue_redraw()

func _on_army_changed(_region_id: String) -> void:
	queue_redraw()


# ─── geometry helpers ───────────────────────────────────────────────────────

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
