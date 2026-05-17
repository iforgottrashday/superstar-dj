extends Control
##
## Medieval conquest map.
##
## Procedural: nothing is loaded from disk. The parchment background and
## the continent silhouettes are all drawn in code, sized to fill whatever
## space the Control gets. The polygons ARE the continents — what the
## player sees is what they click.
##

signal region_clicked(region_id: String)

# Wider authoring canvas so Europe / Asia / Americas all have breathing room.
const DESIGN_WIDTH := 1000.0
const DESIGN_HEIGHT := 700.0

# Stylized continent polygons. NOT a Mercator projection of Earth — these
# are gameplay zones laid out for clarity. Each region is large enough to
# fit its name + army badge with no crowding.
var REGION_POLYGONS: Dictionary = {
	# ── Americas (left column) ──
	"north_america": PackedVector2Array([
		Vector2(60, 100), Vector2(140, 85), Vector2(220, 82),
		Vector2(280, 100), Vector2(315, 130), Vector2(320, 175),
		Vector2(310, 220), Vector2(285, 260), Vector2(245, 295),
		Vector2(190, 315), Vector2(130, 312), Vector2(75, 295),
		Vector2(40, 260), Vector2(28, 215), Vector2(30, 165),
		Vector2(40, 125),
	]),
	"mesoamerica": PackedVector2Array([
		Vector2(140, 335), Vector2(195, 330), Vector2(220, 348),
		Vector2(218, 372), Vector2(185, 388), Vector2(145, 385),
		Vector2(125, 365),
	]),
	"south_america": PackedVector2Array([
		Vector2(95, 410), Vector2(170, 405), Vector2(225, 420),
		Vector2(260, 445), Vector2(280, 478), Vector2(282, 515),
		Vector2(275, 555), Vector2(250, 600), Vector2(215, 640),
		Vector2(175, 660), Vector2(135, 660), Vector2(100, 635),
		Vector2(75, 595), Vector2(68, 550), Vector2(72, 500),
		Vector2(80, 455),
	]),
	# ── Europe (middle-left column) ──
	"england": PackedVector2Array([
		Vector2(348, 215), Vector2(385, 208), Vector2(405, 228),
		Vector2(402, 255), Vector2(385, 275), Vector2(355, 278),
		Vector2(338, 258), Vector2(338, 232),
	]),
	"france": PackedVector2Array([
		Vector2(345, 295), Vector2(390, 290), Vector2(415, 315),
		Vector2(412, 355), Vector2(388, 380), Vector2(355, 380),
		Vector2(335, 360), Vector2(330, 325),
	]),
	"iberia": PackedVector2Array([
		Vector2(310, 395), Vector2(365, 392), Vector2(388, 415),
		Vector2(385, 450), Vector2(360, 470), Vector2(325, 470),
		Vector2(302, 448), Vector2(298, 418),
	]),
	"hre": PackedVector2Array([
		Vector2(430, 280), Vector2(485, 275), Vector2(510, 300),
		Vector2(508, 340), Vector2(485, 365), Vector2(445, 365),
		Vector2(425, 340), Vector2(422, 308),
	]),
	"eastern_eu": PackedVector2Array([
		Vector2(525, 280), Vector2(580, 275), Vector2(605, 300),
		Vector2(605, 340), Vector2(580, 365), Vector2(540, 365),
		Vector2(518, 340), Vector2(515, 308),
	]),
	"russia": PackedVector2Array([
		Vector2(430, 70), Vector2(510, 58), Vector2(610, 55),
		Vector2(710, 60), Vector2(790, 70), Vector2(825, 95),
		Vector2(825, 140), Vector2(805, 175), Vector2(770, 195),
		Vector2(690, 200), Vector2(595, 200), Vector2(510, 198),
		Vector2(445, 195), Vector2(420, 175), Vector2(415, 130),
		Vector2(420, 95),
	]),
	# ── North Africa & Middle East ──
	"maghreb": PackedVector2Array([
		Vector2(310, 495), Vector2(395, 490), Vector2(465, 500),
		Vector2(488, 520), Vector2(478, 555), Vector2(430, 575),
		Vector2(360, 580), Vector2(310, 568), Vector2(290, 540),
		Vector2(295, 512),
	]),
	"egypt": PackedVector2Array([
		Vector2(515, 510), Vector2(575, 505), Vector2(605, 528),
		Vector2(610, 568), Vector2(585, 595), Vector2(545, 605),
		Vector2(510, 590), Vector2(498, 555), Vector2(500, 528),
	]),
	"byzantium": PackedVector2Array([
		Vector2(500, 400), Vector2(555, 395), Vector2(585, 415),
		Vector2(585, 450), Vector2(560, 475), Vector2(525, 478),
		Vector2(498, 458), Vector2(490, 425),
	]),
	"levant": PackedVector2Array([
		Vector2(610, 415), Vector2(648, 412), Vector2(665, 435),
		Vector2(660, 475), Vector2(640, 495), Vector2(615, 495),
		Vector2(600, 470), Vector2(598, 440),
	]),
	# ── Asia ──
	"persia": PackedVector2Array([
		Vector2(685, 420), Vector2(740, 415), Vector2(770, 440),
		Vector2(772, 478), Vector2(745, 500), Vector2(705, 502),
		Vector2(680, 478), Vector2(670, 448),
	]),
	"central_asia": PackedVector2Array([
		Vector2(615, 225), Vector2(695, 220), Vector2(760, 225),
		Vector2(790, 250), Vector2(790, 295), Vector2(760, 325),
		Vector2(710, 335), Vector2(650, 330), Vector2(615, 305),
		Vector2(605, 270),
	]),
	"india": PackedVector2Array([
		Vector2(775, 530), Vector2(835, 525), Vector2(870, 555),
		Vector2(885, 595), Vector2(875, 632), Vector2(840, 660),
		Vector2(795, 668), Vector2(760, 645), Vector2(745, 605),
		Vector2(745, 568),
	]),
	"china": PackedVector2Array([
		Vector2(820, 310), Vector2(885, 305), Vector2(925, 330),
		Vector2(945, 370), Vector2(945, 425), Vector2(925, 470),
		Vector2(890, 495), Vector2(855, 500), Vector2(820, 485),
		Vector2(800, 445), Vector2(795, 395), Vector2(800, 350),
	]),
	"mongolia": PackedVector2Array([
		Vector2(810, 210), Vector2(870, 205), Vector2(920, 218),
		Vector2(945, 245), Vector2(935, 278), Vector2(895, 290),
		Vector2(845, 290), Vector2(815, 270), Vector2(800, 240),
	]),
}

# ── Palette (procedural parchment + ink) ────────────────────────────────────
const COLOR_PARCHMENT := Color(0.91, 0.83, 0.65)      # cream
const COLOR_PARCHMENT_DARK := Color(0.76, 0.66, 0.45) # aged darker
const COLOR_STAIN := Color(0.40, 0.28, 0.12, 0.06)    # subtle aged spots
const COLOR_VIGNETTE := Color(0.30, 0.20, 0.08, 0.20) # darker border tint
const COLOR_BORDER := Color(0.20, 0.12, 0.04)         # sepia ink
const COLOR_BORDER_HOVER := Color(0.05, 0.02, 0.0)    # darker on hover
const COLOR_RING := Color(0.65, 0.18, 0.10, 0.85)
const COLOR_NEUTRAL_FILL := Color(0.84, 0.76, 0.58)
const COLOR_LABEL := Color(0.18, 0.10, 0.03)
const COLOR_ARMY_LABEL := Color(0.96, 0.88, 0.70)
const COLOR_ARMY_LABEL_BG := Color(0.22, 0.13, 0.05, 1.0)
const COLOR_ARMY_LABEL_BORDER := Color(0.50, 0.32, 0.10, 1.0)
const COLOR_PLAYER_GLOW := Color(0.65, 0.15, 0.05)
const LABEL_FONT_SIZE := 12
const ARMY_FONT_SIZE := 15

var _displayed_pulse: Dictionary = {}
var _rings: Array = []
var _hovered: String = ""

# Pre-computed aged-paper stain positions so the texture is stable across
# frames (otherwise the spots would randomize every redraw).
var _stains: Array = []  # each: {pos, radius, alpha}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for region_id in REGION_POLYGONS.keys():
		_displayed_pulse[region_id] = 0.0
	GameState.region_ownership_changed.connect(_on_ownership_changed)
	GameState.region_army_changed.connect(_on_army_changed)
	resized.connect(queue_redraw)
	_seed_stains()


func _seed_stains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1453  # year of Constantinople's fall, why not
	_stains.clear()
	for i in 60:
		_stains.append({
			"pos": Vector2(rng.randf() * DESIGN_WIDTH, rng.randf() * DESIGN_HEIGHT),
			"radius": rng.randf_range(25.0, 90.0),
			"alpha": rng.randf_range(0.03, 0.10),
		})


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
	# Parchment background filling the WHOLE control (no letterbox of empty
	# space) — a base cream wash with aged stains and a vignette.
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_PARCHMENT, true)
	var s: float = _map_scale()
	var off: Vector2 = _map_offset()
	for stain in _stains:
		draw_circle(stain["pos"] * s + off, float(stain["radius"]) * s,
			Color(COLOR_STAIN.r, COLOR_STAIN.g, COLOR_STAIN.b, float(stain["alpha"])))
	# Subtle vignette: darken the outer 30px ring.
	var vignette_w: float = 30.0
	draw_rect(Rect2(0, 0, size.x, vignette_w), COLOR_VIGNETTE, true)  # top
	draw_rect(Rect2(0, size.y - vignette_w, size.x, vignette_w), COLOR_VIGNETTE, true)  # bottom
	draw_rect(Rect2(0, 0, vignette_w, size.y), COLOR_VIGNETTE, true)  # left
	draw_rect(Rect2(size.x - vignette_w, 0, vignette_w, size.y), COLOR_VIGNETTE, true)  # right

	# Region fills. Neutrals get the lighter parchment tone (subtle land
	# indicator); claimed regions get a translucent faction wash.
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

	# Region borders — clean ink outlines.
	for region_id in REGION_POLYGONS.keys():
		var border: Color = COLOR_BORDER
		var width: float = 2.5
		if region_id == _hovered:
			border = COLOR_BORDER_HOVER
			width = 4.0
		draw_polyline(_closed_loop(_polygon_to_canvas(REGION_POLYGONS[region_id])), border, width, true)

	# Combat rings.
	for ring in _rings:
		var pts: PackedVector2Array = REGION_POLYGONS[ring["region_id"]]
		var center: Vector2 = _to_canvas(_centroid(pts))
		var t: float = float(ring["age"]) / float(ring["max_age"])
		var radius: float = lerpf(15.0, 110.0, t) * s
		var alpha: float = (1.0 - t) * 0.85
		var col: Color = ring.get("color", COLOR_RING)
		col.a = alpha
		draw_arc(center, radius, 0.0, TAU, 64, col, 2.5, true)

	# Labels + army badges.
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
				army_text = "🏰" + army_text
			var atxt_size: Vector2 = font.get_string_size(army_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ARMY_FONT_SIZE)
			var badge_w: float = atxt_size.x + 8.0
			var badge_h: float = ARMY_FONT_SIZE + 4.0
			var badge_rect: Rect2 = Rect2(center.x - badge_w * 0.5, center.y + 4.0, badge_w, badge_h)
			draw_rect(badge_rect, COLOR_ARMY_LABEL_BG, true)
			draw_rect(badge_rect, COLOR_ARMY_LABEL_BORDER, false, 1.0)
			draw_string(font, Vector2(badge_rect.position.x + 4.0, badge_rect.position.y + ARMY_FONT_SIZE),
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
