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

# Polygon coordinates aligned (eyeballed) against the 640×480 world_map.png.
# Expect to iterate — pixel-perfect alignment requires actually measuring on
# the image, this pass is from looking at the image and estimating.
var REGION_POLYGONS: Dictionary = {
	# ── Americas ──
	"north_america": PackedVector2Array([
		Vector2(35, 95), Vector2(120, 75), Vector2(180, 80),
		Vector2(215, 115), Vector2(215, 175), Vector2(180, 225),
		Vector2(120, 245), Vector2(60, 230), Vector2(28, 175), Vector2(20, 130),
	]),
	"mesoamerica": PackedVector2Array([
		Vector2(125, 240), Vector2(175, 232), Vector2(195, 250),
		Vector2(185, 275), Vector2(150, 280), Vector2(125, 262),
	]),
	"south_america": PackedVector2Array([
		Vector2(155, 285), Vector2(210, 280), Vector2(230, 315),
		Vector2(225, 365), Vector2(195, 415), Vector2(170, 440),
		Vector2(148, 415), Vector2(135, 355), Vector2(140, 320),
	]),
	# ── Europe ──
	"england": PackedVector2Array([
		Vector2(288, 125), Vector2(310, 122), Vector2(315, 145),
		Vector2(308, 160), Vector2(288, 162), Vector2(282, 142),
	]),
	"france": PackedVector2Array([
		Vector2(308, 165), Vector2(342, 162), Vector2(350, 188),
		Vector2(340, 210), Vector2(312, 210), Vector2(305, 185),
	]),
	"iberia": PackedVector2Array([
		Vector2(280, 195), Vector2(310, 200), Vector2(315, 225),
		Vector2(295, 240), Vector2(275, 232),
	]),
	"hre": PackedVector2Array([
		Vector2(346, 155), Vector2(382, 152), Vector2(388, 180),
		Vector2(375, 205), Vector2(348, 205), Vector2(342, 178),
	]),
	"eastern_eu": PackedVector2Array([
		Vector2(388, 152), Vector2(425, 152), Vector2(432, 180),
		Vector2(420, 205), Vector2(390, 205), Vector2(385, 178),
	]),
	"russia": PackedVector2Array([
		Vector2(355, 75), Vector2(450, 60), Vector2(540, 65),
		Vector2(605, 75), Vector2(620, 115), Vector2(595, 145),
		Vector2(525, 152), Vector2(440, 150), Vector2(385, 148),
		Vector2(355, 130), Vector2(348, 100),
	]),
	# ── North Africa & Middle East ──
	"maghreb": PackedVector2Array([
		Vector2(280, 240), Vector2(370, 232), Vector2(405, 240),
		Vector2(400, 268), Vector2(310, 275), Vector2(278, 260),
	]),
	"egypt": PackedVector2Array([
		Vector2(412, 255), Vector2(458, 250), Vector2(472, 275),
		Vector2(460, 305), Vector2(420, 302), Vector2(408, 280),
	]),
	"byzantium": PackedVector2Array([
		Vector2(385, 205), Vector2(430, 200), Vector2(450, 220),
		Vector2(435, 240), Vector2(395, 240), Vector2(382, 222),
	]),
	"levant": PackedVector2Array([
		Vector2(438, 215), Vector2(465, 215), Vector2(475, 240),
		Vector2(465, 268), Vector2(450, 268), Vector2(438, 245),
	]),
	# ── Asia ──
	"persia": PackedVector2Array([
		Vector2(478, 215), Vector2(520, 212), Vector2(532, 235),
		Vector2(518, 262), Vector2(485, 262), Vector2(472, 238),
	]),
	"central_asia": PackedVector2Array([
		Vector2(440, 152), Vector2(540, 150), Vector2(555, 180),
		Vector2(545, 205), Vector2(470, 208), Vector2(440, 180),
	]),
	"india": PackedVector2Array([
		Vector2(515, 245), Vector2(560, 245), Vector2(580, 275),
		Vector2(568, 310), Vector2(540, 335), Vector2(518, 320),
		Vector2(508, 278),
	]),
	"china": PackedVector2Array([
		Vector2(550, 180), Vector2(615, 178), Vector2(625, 215),
		Vector2(620, 260), Vector2(598, 282), Vector2(565, 282),
		Vector2(548, 245), Vector2(545, 210),
	]),
	"mongolia": PackedVector2Array([
		Vector2(510, 125), Vector2(575, 120), Vector2(615, 122),
		Vector2(620, 150), Vector2(600, 175), Vector2(550, 175),
		Vector2(515, 170),
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
const LABEL_FONT_SIZE := 15
const ARMY_FONT_SIZE := 18

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
