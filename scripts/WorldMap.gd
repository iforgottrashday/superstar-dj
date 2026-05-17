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

# Authoring space matches the world_map.png (640×480). All polygons below
# are pixel coordinates within that image, so they overlay actual continents.
const DESIGN_WIDTH := 640.0
const DESIGN_HEIGHT := 480.0

# Tight "claim zone" polygons — clearly INSIDE each continent's landmass
# with explicit gaps between regions. Trades coastline accuracy for
# clean, non-overlapping borders. The world-map image shows the actual
# continents; the polygons are gameplay zones placed on them.
var REGION_POLYGONS: Dictionary = {
	# ── Americas ──
	"north_america": PackedVector2Array([
		Vector2(60, 100), Vector2(115, 80), Vector2(170, 75),
		Vector2(212, 88), Vector2(228, 118), Vector2(232, 150),
		Vector2(226, 180), Vector2(215, 210), Vector2(200, 235),
		Vector2(175, 252), Vector2(140, 258), Vector2(105, 252),
		Vector2(78, 240), Vector2(60, 218), Vector2(50, 185),
		Vector2(50, 145), Vector2(55, 118),
	]),
	"mesoamerica": PackedVector2Array([
		Vector2(218, 258), Vector2(245, 256), Vector2(258, 265),
		Vector2(255, 278), Vector2(238, 285), Vector2(220, 280),
		Vector2(212, 270),
	]),
	"south_america": PackedVector2Array([
		Vector2(245, 292), Vector2(285, 290), Vector2(310, 298),
		Vector2(320, 320), Vector2(318, 350), Vector2(305, 382),
		Vector2(288, 412), Vector2(268, 432), Vector2(248, 442),
		Vector2(230, 432), Vector2(220, 408), Vector2(218, 378),
		Vector2(222, 345), Vector2(232, 318),
	]),
	# ── Europe ── (gaps of ~3px between adjacent regions)
	"england": PackedVector2Array([
		Vector2(272, 128), Vector2(286, 120), Vector2(298, 124),
		Vector2(302, 140), Vector2(296, 152), Vector2(286, 158),
		Vector2(274, 155), Vector2(270, 142),
	]),
	"france": PackedVector2Array([
		Vector2(285, 168), Vector2(305, 165), Vector2(318, 172),
		Vector2(320, 188), Vector2(315, 200), Vector2(302, 208),
		Vector2(290, 205), Vector2(283, 192), Vector2(283, 178),
	]),
	"iberia": PackedVector2Array([
		Vector2(265, 208), Vector2(290, 205), Vector2(298, 218),
		Vector2(292, 232), Vector2(275, 235), Vector2(262, 228),
		Vector2(260, 218),
	]),
	"hre": PackedVector2Array([
		Vector2(327, 162), Vector2(348, 158), Vector2(360, 168),
		Vector2(358, 182), Vector2(352, 195), Vector2(338, 200),
		Vector2(327, 192), Vector2(323, 178),
	]),
	"eastern_eu": PackedVector2Array([
		Vector2(370, 160), Vector2(395, 158), Vector2(408, 168),
		Vector2(408, 185), Vector2(395, 195), Vector2(375, 195),
		Vector2(365, 180), Vector2(365, 170),
	]),
	"russia": PackedVector2Array([
		Vector2(360, 92), Vector2(420, 82), Vector2(490, 80),
		Vector2(550, 82), Vector2(595, 90), Vector2(610, 115),
		Vector2(602, 138), Vector2(575, 145), Vector2(520, 148),
		Vector2(450, 148), Vector2(395, 148), Vector2(365, 138),
		Vector2(355, 118),
	]),
	# ── North Africa & Middle East ──
	"maghreb": PackedVector2Array([
		Vector2(270, 248), Vector2(320, 242), Vector2(370, 244),
		Vector2(400, 250), Vector2(398, 265), Vector2(360, 272),
		Vector2(310, 274), Vector2(275, 268),
	]),
	"egypt": PackedVector2Array([
		Vector2(405, 258), Vector2(440, 254), Vector2(458, 268),
		Vector2(455, 290), Vector2(438, 302), Vector2(412, 298),
		Vector2(402, 280),
	]),
	"byzantium": PackedVector2Array([
		Vector2(372, 205), Vector2(400, 200), Vector2(425, 208),
		Vector2(430, 222), Vector2(420, 235), Vector2(395, 240),
		Vector2(375, 232), Vector2(368, 218),
	]),
	"levant": PackedVector2Array([
		Vector2(438, 222), Vector2(458, 220), Vector2(465, 240),
		Vector2(462, 258), Vector2(450, 266), Vector2(438, 258),
		Vector2(434, 240),
	]),
	# ── Asia ──
	"persia": PackedVector2Array([
		Vector2(475, 215), Vector2(502, 212), Vector2(522, 222),
		Vector2(525, 240), Vector2(515, 255), Vector2(495, 260),
		Vector2(478, 252), Vector2(470, 235),
	]),
	"central_asia": PackedVector2Array([
		Vector2(430, 158), Vector2(478, 155), Vector2(515, 158),
		Vector2(528, 170), Vector2(525, 188), Vector2(500, 198),
		Vector2(460, 198), Vector2(432, 188), Vector2(425, 172),
	]),
	"india": PackedVector2Array([
		Vector2(520, 252), Vector2(548, 250), Vector2(572, 260),
		Vector2(578, 280), Vector2(568, 305), Vector2(552, 322),
		Vector2(535, 322), Vector2(520, 305), Vector2(512, 285),
		Vector2(512, 268),
	]),
	"china": PackedVector2Array([
		Vector2(558, 188), Vector2(590, 185), Vector2(615, 195),
		Vector2(622, 218), Vector2(620, 245), Vector2(608, 268),
		Vector2(590, 278), Vector2(572, 270), Vector2(560, 248),
		Vector2(555, 220),
	]),
	"mongolia": PackedVector2Array([
		Vector2(522, 135), Vector2(560, 130), Vector2(595, 132),
		Vector2(612, 142), Vector2(608, 160), Vector2(592, 168),
		Vector2(558, 168), Vector2(528, 160), Vector2(520, 148),
	]),
}

# World-map background image (parchment style). Loaded at runtime so the
# script still parses if the file isn't present yet.
var bg_texture: Texture2D = null

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
const LABEL_FONT_SIZE := 11
const ARMY_FONT_SIZE := 14

var _displayed_pulse: Dictionary = {}
var _rings: Array = []
var _hovered: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	bg_texture = load("res://assets/world_map.png") as Texture2D
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
	# Background: fill any letterbox area with a dark sepia, then draw the
	# world map at the same uniform-scaled rect that the polygons use, so
	# every continent in the texture stays aligned with its polygon.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.07, 0.05), true)
	if bg_texture != null:
		var s: float = _map_scale()
		var off: Vector2 = _map_offset()
		var img_rect: Rect2 = Rect2(off, Vector2(DESIGN_WIDTH, DESIGN_HEIGHT) * s)
		draw_texture_rect(bg_texture, img_rect, false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), COLOR_OCEAN, true)

	# Region fills — only color claimed (non-neutral) regions, and only at
	# low opacity so the underlying map texture still reads through.
	for region_id in REGION_POLYGONS.keys():
		var pts: PackedVector2Array = _polygon_to_canvas(REGION_POLYGONS[region_id])
		var r = GameState.regions_by_id.get(region_id)
		var fill: Color = Color(0, 0, 0, 0)  # neutrals: no tint, show the map
		if r != null:
			var owner_id: String = String(r.owner)
			if owner_id != "neutral" and GameState.FACTION_CATALOG.has(owner_id):
				fill = GameState.FACTION_CATALOG[owner_id]["color"]
				fill.a = 0.45  # translucent wash so the map continent shows through
		var pulse_v: float = float(_displayed_pulse[region_id])
		if pulse_v > 0.0:
			fill = fill.lerp(Color(1.0, 1.0, 1.0, fill.a), pulse_v * 0.5)
		if region_id == _hovered:
			# A subtle dark overlay on hover so the player sees which region
			# the cursor is over without obliterating the map underneath.
			fill = fill.lerp(Color(0.10, 0.05, 0.02, 0.35), 0.4)
		if fill.a > 0.0:
			draw_colored_polygon(pts, fill)

	# Player-owned glow halo.
	for region_id in REGION_POLYGONS.keys():
		var r = GameState.regions_by_id.get(region_id)
		if r != null and String(r.owner) == GameState.player_faction and GameState.player_faction != "":
			draw_polyline(_closed_loop(_polygon_to_canvas(REGION_POLYGONS[region_id])), COLOR_PLAYER_GLOW, 4.0, true)

	# Region borders — ink-style outlines.
	for region_id in REGION_POLYGONS.keys():
		var border: Color = COLOR_BORDER
		var width: float = 2.5
		if region_id == _hovered:
			border = COLOR_BORDER_HOVER
			width = 4.0
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
