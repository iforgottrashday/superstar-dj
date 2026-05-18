extends Control
##
## Hex-grid world map for Global Siege.
##
## 18 regions, each rendered as a pointy-top hexagon in a 5-row offset layout
## (3-4-4-4-3). Clean uniform tiles, no continent silhouettes, no eyeballed
## polygon coordinates. Every hex is the same size and shape; the column
## auto-scales the whole grid via _to_canvas. Plenty of room for big text
## inside each hex.
##

signal region_clicked(region_id: String)

# Authoring canvas. Designed for the panel to dominate the screen — map only
# needs to be about as wide as the hex grid plus some breathing room.
const DESIGN_WIDTH := 480.0
const DESIGN_HEIGHT := 470.0

# Pointy-top hex: HEX_RADIUS is the distance from the center to any point.
const HEX_RADIUS := 48.0
const HEX_WIDTH := HEX_RADIUS * 1.7320508  # sqrt(3), flat-to-flat
const HEX_HEIGHT := HEX_RADIUS * 2.0       # point-to-point

# Hex centers in design space. Geographic-ish order: top row = north,
# bottom row = south. Empty corners (top-left, bottom-left) are intentional.
const HEX_CENTERS := {
	# Row 0 (peaks): North Crag, High Pass, Eagle Perch
	"north_crag":    Vector2(155, 60),
	"high_pass":     Vector2(238, 60),
	"eagle_perch":   Vector2(321, 60),
	# Row 1 (boreal forest): Wolf Pine, Birch Stand, Deep Woods, Old Oaks
	"wolf_pine":     Vector2(113, 130),
	"birch_stand":   Vector2(196, 130),
	"deep_woods":    Vector2(279, 130),
	"old_oaks":      Vector2(362, 130),
	# Row 2 (mixed): Wild Meadow, Fern Grove, Cave System, Boulder Field
	"wild_meadow":   Vector2(72, 200),
	"fern_grove":    Vector2(155, 200),
	"cave_system":   Vector2(238, 200),
	"boulder_field": Vector2(321, 200),
	# Row 3 (plains): Burnt Wood, Tall Grass, Salt Lick, Stone Meadow
	"burnt_wood":    Vector2(113, 270),
	"tall_grass":    Vector2(196, 270),
	"salt_lick":     Vector2(279, 270),
	"stone_meadow":  Vector2(362, 270),
	# Row 4 (wet): Mud Wallow, River Bend, Reed Marsh
	"mud_wallow":    Vector2(155, 340),
	"river_bend":    Vector2(238, 340),
	"reed_marsh":    Vector2(321, 340),
}

# Palette
const COLOR_PARCHMENT := Color(0.91, 0.83, 0.65)
const COLOR_STAIN := Color(0.40, 0.28, 0.12, 0.06)
const COLOR_VIGNETTE := Color(0.30, 0.20, 0.08, 0.20)
const COLOR_BORDER := Color(0.20, 0.12, 0.04)
const COLOR_BORDER_HOVER := Color(0.05, 0.02, 0.0)
const COLOR_RING := Color(0.65, 0.18, 0.10, 0.85)
const COLOR_NEUTRAL_FILL := Color(0.84, 0.76, 0.58)
const COLOR_LABEL := Color(0.18, 0.10, 0.03)
const COLOR_ARMY_LABEL := Color(0.96, 0.88, 0.70)
const COLOR_ARMY_LABEL_BG := Color(0.22, 0.13, 0.05, 1.0)
const COLOR_ARMY_LABEL_BORDER := Color(0.50, 0.32, 0.10, 1.0)
const COLOR_PLAYER_GLOW := Color(0.65, 0.15, 0.05)
const LABEL_FONT_SIZE := 14
const ARMY_FONT_SIZE := 17
const EMBLEM_FONT_SIZE := 56     # design-space size; scales with _map_scale
const EMBLEM_ALPHA := 0.22       # faint enough not to compete with the name

var _displayed_pulse: Dictionary = {}
var _rings: Array = []
var _hovered: String = ""
var _stains: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for region_id in HEX_CENTERS.keys():
		_displayed_pulse[region_id] = 0.0
	GameState.region_ownership_changed.connect(_on_ownership_changed)
	GameState.region_army_changed.connect(_on_army_changed)
	resized.connect(queue_redraw)
	_seed_stains()


func _seed_stains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1453
	_stains.clear()
	for i in 40:
		_stains.append({
			"pos": Vector2(rng.randf() * DESIGN_WIDTH, rng.randf() * DESIGN_HEIGHT),
			"radius": rng.randf_range(20.0, 70.0),
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

# Generate a pointy-top hexagon polygon around `center` with `radius` in
# whatever coordinate space the caller is using (world or canvas).
func _hex_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle: float = PI / 3.0 * float(i) - PI / 2.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


# ─── drawing ────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Background image sits in a sibling TextureRect behind this Control.
	# We skip the opaque fill so that image shows through, but still draw the
	# translucent age-stains + edge vignette on top for atmosphere.
	var s: float = _map_scale()
	var off: Vector2 = _map_offset()
	for stain in _stains:
		draw_circle(stain["pos"] * s + off, float(stain["radius"]) * s,
			Color(COLOR_STAIN.r, COLOR_STAIN.g, COLOR_STAIN.b, float(stain["alpha"])))
	var vignette_w: float = 24.0
	draw_rect(Rect2(0, 0, size.x, vignette_w), COLOR_VIGNETTE, true)
	draw_rect(Rect2(0, size.y - vignette_w, size.x, vignette_w), COLOR_VIGNETTE, true)
	draw_rect(Rect2(0, 0, vignette_w, size.y), COLOR_VIGNETTE, true)
	draw_rect(Rect2(size.x - vignette_w, 0, vignette_w, size.y), COLOR_VIGNETTE, true)

	var hex_canvas_radius: float = HEX_RADIUS * s

	# Hex fills (faction-color wash for claimed, neutral for unclaimed).
	for region_id in HEX_CENTERS.keys():
		var center_canvas: Vector2 = _to_canvas(HEX_CENTERS[region_id])
		var pts: PackedVector2Array = _hex_polygon(center_canvas, hex_canvas_radius)
		var r = GameState.regions_by_id.get(region_id)
		var fill: Color = COLOR_NEUTRAL_FILL
		if r != null:
			var owner_id: String = String(r.owner)
			if owner_id != "neutral" and GameState.FACTION_CATALOG.has(owner_id):
				fill = GameState.FACTION_CATALOG[owner_id]["color"].lerp(Color(0.94, 0.87, 0.70), 0.5)
		var pulse_v: float = float(_displayed_pulse[region_id])
		if pulse_v > 0.0:
			fill = fill.lerp(Color(1.0, 1.0, 1.0), pulse_v * 0.45)
		if region_id == _hovered:
			fill = fill.lerp(Color(0.10, 0.05, 0.02), 0.18)
		draw_colored_polygon(pts, fill)

	# Faint faction emblem inside each owned hex. Drawn after the fill but
	# before the player-glow halo and labels so the emblem sits behind the
	# name/army badge as background flavor, not above them.
	var emblem_font: Font = ThemeDB.fallback_font
	var emblem_px: int = maxi(20, int(float(EMBLEM_FONT_SIZE) * s))
	for region_id in HEX_CENTERS.keys():
		var r = GameState.regions_by_id.get(region_id)
		if r == null:
			continue
		var owner_id: String = String(r.owner)
		if not GameState.FACTION_CATALOG.has(owner_id):
			continue
		var def: Dictionary = GameState.FACTION_CATALOG[owner_id]
		var emblem: String = String(def.get("emblem", ""))
		if emblem == "":
			continue
		var center_canvas: Vector2 = _to_canvas(HEX_CENTERS[region_id])
		var emblem_size: Vector2 = emblem_font.get_string_size(emblem,
			HORIZONTAL_ALIGNMENT_CENTER, -1, emblem_px)
		var emblem_color: Color = Color(1, 1, 1, EMBLEM_ALPHA)
		draw_string(emblem_font,
			center_canvas - Vector2(emblem_size.x * 0.5, -emblem_size.y * 0.25),
			emblem, HORIZONTAL_ALIGNMENT_CENTER, -1, emblem_px, emblem_color)

	# Player glow halo on owned hexes.
	for region_id in HEX_CENTERS.keys():
		var r = GameState.regions_by_id.get(region_id)
		if r != null and String(r.owner) == GameState.player_faction and GameState.player_faction != "":
			var center_canvas: Vector2 = _to_canvas(HEX_CENTERS[region_id])
			var pts: PackedVector2Array = _hex_polygon(center_canvas, hex_canvas_radius)
			draw_polyline(_closed_loop(pts), COLOR_PLAYER_GLOW, 4.5, true)

	# Hex borders.
	for region_id in HEX_CENTERS.keys():
		var center_canvas: Vector2 = _to_canvas(HEX_CENTERS[region_id])
		var pts: PackedVector2Array = _hex_polygon(center_canvas, hex_canvas_radius)
		var border: Color = COLOR_BORDER
		var width: float = 2.5
		if region_id == _hovered:
			border = COLOR_BORDER_HOVER
			width = 4.0
		draw_polyline(_closed_loop(pts), border, width, true)

	# Adjacency overlay — when the player hovers a hex, show its geographic
	# neighbors with a gold border and a connecting line. The hex layout
	# itself is decorative; this overlay is the gameplay truth.
	if _hovered != "":
		var hovered_r = GameState.regions_by_id.get(_hovered)
		if hovered_r != null:
			var adjacency_color: Color = Color(0.97, 0.80, 0.20, 0.95)
			var hov_center: Vector2 = _to_canvas(HEX_CENTERS[_hovered])
			for nid in hovered_r.neighbors:
				if HEX_CENTERS.has(nid):
					var n_center: Vector2 = _to_canvas(HEX_CENTERS[nid])
					# Connection line first (so it goes under the border).
					draw_line(hov_center, n_center, Color(adjacency_color.r, adjacency_color.g, adjacency_color.b, 0.6), 3.0, true)
					var n_pts: PackedVector2Array = _hex_polygon(n_center, hex_canvas_radius)
					draw_polyline(_closed_loop(n_pts), adjacency_color, 3.5, true)

	# Combat rings (centered on hex).
	for ring in _rings:
		var center: Vector2 = _to_canvas(HEX_CENTERS[ring["region_id"]])
		var t: float = float(ring["age"]) / float(ring["max_age"])
		var radius: float = lerpf(15.0, 80.0, t) * s
		var alpha: float = (1.0 - t) * 0.85
		var col: Color = ring.get("color", COLOR_RING)
		col.a = alpha
		draw_arc(center, radius, 0.0, TAU, 64, col, 2.5, true)

	# Labels + army badges (fixed font sizes for readability).
	var font: Font = ThemeDB.fallback_font
	var max_label_width: float = HEX_WIDTH * s * 0.92
	for region_id in HEX_CENTERS.keys():
		var center_canvas: Vector2 = _to_canvas(HEX_CENTERS[region_id])
		var r = GameState.regions_by_id.get(region_id)
		var label_text: String = String(r.name) if r != null else region_id
		var single_w: float = font.get_string_size(label_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE).x
		# Names like "Stone Meadow" / "Boulder Field" overflow the flat-to-flat
		# hex width on a single line. Wrap them onto two lines via the space.
		# Short names still render single-line, no behavior change for them.
		if single_w > max_label_width and " " in label_text:
			var first_baseline: Vector2 = Vector2(
				center_canvas.x - max_label_width * 0.5,
				center_canvas.y - 18.0)
			draw_multiline_string(font, first_baseline, label_text,
				HORIZONTAL_ALIGNMENT_CENTER, max_label_width, LABEL_FONT_SIZE,
				2, COLOR_LABEL)
		else:
			draw_string(font,
				center_canvas - Vector2(single_w * 0.5, 4.0),
				label_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE, COLOR_LABEL)
		if r != null:
			var army_text: String = str(int(r.army))
			if bool(r.fortified):
				army_text = "🏰" + army_text
			var atxt_size: Vector2 = font.get_string_size(army_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ARMY_FONT_SIZE)
			var badge_w: float = atxt_size.x + 10.0
			var badge_h: float = ARMY_FONT_SIZE + 4.0
			var badge_rect: Rect2 = Rect2(center_canvas.x - badge_w * 0.5, center_canvas.y + 4.0, badge_w, badge_h)
			draw_rect(badge_rect, COLOR_ARMY_LABEL_BG, true)
			draw_rect(badge_rect, COLOR_ARMY_LABEL_BORDER, false, 1.0)
			draw_string(font, Vector2(badge_rect.position.x + 5.0, badge_rect.position.y + ARMY_FONT_SIZE),
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
	# Inverse-transform the click into world space, then test against each
	# hex polygon. Cheap because there are only 18 hexes.
	var world_p: Vector2 = _from_canvas(p)
	for region_id in HEX_CENTERS.keys():
		var pts: PackedVector2Array = _hex_polygon(HEX_CENTERS[region_id], HEX_RADIUS)
		if Geometry2D.is_point_in_polygon(world_p, pts):
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
