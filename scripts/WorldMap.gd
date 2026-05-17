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
	# ── Americas ──
	"north_america": PackedVector2Array([
		Vector2(60, 90), Vector2(160, 70), Vector2(260, 80),
		Vector2(310, 105), Vector2(325, 150), Vector2(320, 200),
		Vector2(300, 250), Vector2(265, 295), Vector2(215, 320),
		Vector2(155, 325), Vector2(100, 305), Vector2(60, 270),
		Vector2(35, 220), Vector2(30, 160), Vector2(40, 115),
	]),
	"mesoamerica": PackedVector2Array([
		Vector2(225, 335), Vector2(280, 330), Vector2(305, 350),
		Vector2(295, 380), Vector2(255, 390), Vector2(220, 380),
		Vector2(210, 358),
	]),
	"south_america": PackedVector2Array([
		Vector2(215, 395), Vector2(290, 390), Vector2(330, 410),
		Vector2(345, 440), Vector2(340, 485), Vector2(320, 535),
		Vector2(285, 580), Vector2(245, 615), Vector2(210, 630),
		Vector2(180, 605), Vector2(168, 555), Vector2(170, 500),
		Vector2(185, 450), Vector2(200, 415),
	]),
	# ── Europe ──
	"england": PackedVector2Array([
		Vector2(340, 130), Vector2(370, 122), Vector2(395, 135),
		Vector2(395, 165), Vector2(385, 185), Vector2(360, 190),
		Vector2(340, 178), Vector2(332, 152),
	]),
	"france": PackedVector2Array([
		Vector2(345, 205), Vector2(395, 200), Vector2(420, 220),
		Vector2(420, 255), Vector2(395, 280), Vector2(360, 285),
		Vector2(335, 270), Vector2(330, 240),
	]),
	"iberia": PackedVector2Array([
		Vector2(310, 295), Vector2(360, 290), Vector2(385, 310),
		Vector2(380, 345), Vector2(355, 365), Vector2(320, 365),
		Vector2(300, 345), Vector2(298, 320),
	]),
	"hre": PackedVector2Array([
		Vector2(430, 205), Vector2(485, 200), Vector2(505, 225),
		Vector2(505, 260), Vector2(485, 285), Vector2(450, 290),
		Vector2(425, 270), Vector2(420, 235),
	]),
	"eastern_eu": PackedVector2Array([
		Vector2(515, 205), Vector2(580, 200), Vector2(600, 225),
		Vector2(600, 260), Vector2(580, 285), Vector2(540, 290),
		Vector2(515, 270), Vector2(510, 235),
	]),
	"russia": PackedVector2Array([
		Vector2(340, 75), Vector2(450, 60), Vector2(580, 55),
		Vector2(710, 60), Vector2(830, 70), Vector2(900, 90),
		Vector2(920, 130), Vector2(905, 170), Vector2(850, 190),
		Vector2(750, 195), Vector2(640, 195), Vector2(540, 195),
		Vector2(450, 195), Vector2(390, 185), Vector2(345, 160),
		Vector2(335, 120),
	]),
	# ── North Africa & Middle East ──
	"maghreb": PackedVector2Array([
		Vector2(305, 400), Vector2(400, 395), Vector2(470, 405),
		Vector2(490, 425), Vector2(485, 460), Vector2(440, 475),
		Vector2(370, 478), Vector2(310, 470), Vector2(285, 445),
		Vector2(290, 415),
	]),
	"egypt": PackedVector2Array([
		Vector2(510, 405), Vector2(575, 400), Vector2(610, 425),
		Vector2(615, 465), Vector2(595, 500), Vector2(555, 515),
		Vector2(515, 505), Vector2(495, 470), Vector2(495, 435),
	]),
	"byzantium": PackedVector2Array([
		Vector2(495, 305), Vector2(555, 300), Vector2(585, 320),
		Vector2(590, 350), Vector2(570, 375), Vector2(530, 385),
		Vector2(495, 370), Vector2(480, 340),
	]),
	"levant": PackedVector2Array([
		Vector2(605, 325), Vector2(645, 320), Vector2(665, 345),
		Vector2(660, 385), Vector2(640, 405), Vector2(615, 405),
		Vector2(600, 380), Vector2(595, 350),
	]),
	# ── Asia ──
	"persia": PackedVector2Array([
		Vector2(680, 325), Vector2(740, 320), Vector2(770, 345),
		Vector2(770, 385), Vector2(745, 410), Vector2(700, 415),
		Vector2(675, 395), Vector2(665, 360),
	]),
	"central_asia": PackedVector2Array([
		Vector2(615, 215), Vector2(700, 210), Vector2(780, 215),
		Vector2(810, 240), Vector2(805, 280), Vector2(775, 305),
		Vector2(720, 310), Vector2(660, 305), Vector2(625, 285),
		Vector2(610, 250),
	]),
	"india": PackedVector2Array([
		Vector2(785, 360), Vector2(840, 355), Vector2(875, 380),
		Vector2(880, 420), Vector2(860, 460), Vector2(830, 490),
		Vector2(795, 500), Vector2(770, 480), Vector2(755, 445),
		Vector2(755, 405), Vector2(765, 375),
	]),
	"china": PackedVector2Array([
		Vector2(830, 240), Vector2(895, 235), Vector2(935, 260),
		Vector2(950, 300), Vector2(950, 345), Vector2(935, 385),
		Vector2(905, 415), Vector2(870, 425), Vector2(835, 410),
		Vector2(815, 380), Vector2(810, 335), Vector2(815, 280),
	]),
	"mongolia": PackedVector2Array([
		Vector2(820, 165), Vector2(880, 160), Vector2(925, 170),
		Vector2(940, 195), Vector2(930, 225), Vector2(895, 235),
		Vector2(845, 235), Vector2(815, 220), Vector2(810, 190),
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
