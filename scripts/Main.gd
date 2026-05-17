extends Control
##
## Main scene controller. Three panels:
##   - Top: news ticker
##   - Center: world map (clickable polygons)
##   - Right: HUD (hype, backlash, tick, speed) + trait shop
##

@onready var world_map: Control = $HSplit/Left/WorldMap
@onready var hype_label: Label = $HSplit/Right/HUD/HypeLabel
@onready var backlash_label: Label = $HSplit/Right/HUD/BacklashLabel
@onready var tick_label: Label = $HSplit/Right/HUD/TickLabel
@onready var speed_label: Label = $HSplit/Right/HUD/SpeedLabel
@onready var traits_box: VBoxContainer = $HSplit/Right/Traits
@onready var debut_panel: PanelContainer = $DebutPanel
@onready var region_panel: PanelContainer = $RegionPanel
@onready var region_title: Label = $RegionPanel/Margin/VBox/Header/Title
@onready var region_close: Button = $RegionPanel/Margin/VBox/Header/CloseBtn
@onready var region_stats: Label = $RegionPanel/Margin/VBox/Stats
@onready var region_channels_box: VBoxContainer = $RegionPanel/Margin/VBox/ChannelsScroll/Channels
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Margin/VBox/Label

var _trait_buttons: Dictionary = {} # trait_id -> Button
var _debuted: bool = false
var _open_region_id: String = ""

func _ready() -> void:
	GameState.hype_changed.connect(_on_hype_changed)
	GameState.backlash_changed.connect(_on_backlash_changed)
	GameState.tick_advanced.connect(_on_tick)
	GameState.game_over.connect(_on_game_over)
	GameState.channels_changed.connect(_on_channels_changed)
	world_map.region_clicked.connect(_on_region_clicked)
	region_close.pressed.connect(_close_region_panel)
	# Don't tick until the player picks a debut region.
	GameState.speed = 0.0
	_build_trait_shop()
	_refresh_hud()
	debut_panel.visible = true
	region_panel.visible = false
	game_over_panel.visible = false

func _on_region_clicked(region_id: String) -> void:
	var r = GameState.regions_by_id.get(region_id)
	if r == null:
		return
	if not _debuted:
		if bool(r.closed):
			GameState.emit_signal("news_emitted",
				"Can't debut in %s — locked. Pick an unlocked region." % r.name)
			return
		_debut_in(region_id)
	else:
		_open_region_panel(region_id)

func _debut_in(region_id: String) -> void:
	var r = GameState.regions_by_id[region_id]
	r.fanbase_pct = 0.05
	GameState.emit_signal("news_emitted",
		"You debut in %s. The first 50 people sign up to the mailing list." % r.name)
	GameState.emit_signal("news_emitted",
		"TIP: Click any region on the map to open distribution channels.")
	debut_panel.visible = false
	_debuted = true
	GameState.speed = 1.0

func _open_region_panel(region_id: String) -> void:
	_open_region_id = region_id
	_rebuild_region_panel()
	region_panel.visible = true

func _close_region_panel() -> void:
	_open_region_id = ""
	region_panel.visible = false

func _on_channels_changed(region_id: String) -> void:
	if region_panel.visible and region_id == _open_region_id:
		_rebuild_region_panel()

func _rebuild_region_panel() -> void:
	var r = GameState.regions_by_id.get(_open_region_id)
	if r == null:
		return
	var lock_tag: String = "  🔒 LOCKED" if bool(r.closed) else ""
	region_title.text = String(r.name) + lock_tag
	region_stats.text = "Population: %.0fM   ·   Fanbase: %.0f%%   ·   Resistance: %.0f%%" % [
		float(r.population),
		float(r.fanbase_pct) * 100.0,
		float(r.culture_resistance) * 100.0,
	]
	for child in region_channels_box.get_children():
		child.queue_free()
	var active_by_id: Dictionary = {}
	for ch in GameState.region_channels.get(_open_region_id, []):
		active_by_id[String(ch["channel_id"])] = int(ch["ticks_remaining"])
	for channel_id in GameState.CHANNEL_CATALOG.keys():
		region_channels_box.add_child(_build_channel_row(channel_id, active_by_id))

func _build_channel_row(channel_id: String, active_by_id: Dictionary) -> Control:
	var def: Dictionary = GameState.CHANNEL_CATALOG[channel_id]
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var top := HBoxContainer.new()
	vbox.add_child(top)
	# Channel color swatch.
	var swatch := ColorRect.new()
	swatch.color = def["color"]
	swatch.custom_minimum_size = Vector2(10, 18)
	top.add_child(swatch)
	var name_label := Label.new()
	name_label.text = "  " + String(def["name"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var btn := Button.new()
	var trait_gate: String = String(def["requires_trait"])
	var trait_missing: bool = trait_gate != "" and not GameState.owned_traits.has(trait_gate)
	var cost: int = int(def["cost"])
	var duration: int = int(def["duration_ticks"])
	if active_by_id.has(channel_id):
		if duration < 0:
			btn.text = "✓ Permanent"
			btn.disabled = true
		else:
			btn.text = "✓ Refresh (%d ticks left) — %d hype" % [int(active_by_id[channel_id]), cost]
			btn.disabled = GameState.hype < cost
			btn.pressed.connect(_on_activate_channel.bind(channel_id))
	else:
		var duration_label: String = "permanent" if duration < 0 else ("%d ticks" % duration)
		btn.text = "Activate — %d hype (%s)" % [cost, duration_label]
		btn.disabled = trait_missing or GameState.hype < cost
		if trait_missing:
			btn.text = "🔒 Needs %s" % GameState.TRAIT_CATALOG[trait_gate]["name"]
		else:
			btn.pressed.connect(_on_activate_channel.bind(channel_id))
	top.add_child(btn)
	var blurb := Label.new()
	blurb.text = String(def["blurb"])
	blurb.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(blurb)
	return row

func _on_activate_channel(channel_id: String) -> void:
	GameState.activate_channel(_open_region_id, channel_id)
	# channels_changed signal will trigger rebuild.
	_refresh_hud()

func _build_trait_shop() -> void:
	for child in traits_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "TRAITS"
	traits_box.add_child(title)
	for trait_id in GameState.TRAIT_CATALOG.keys():
		var def: Dictionary = GameState.TRAIT_CATALOG[trait_id]
		var btn := Button.new()
		btn.text = "%s — %d hype" % [def["name"], int(def["cost"])]
		btn.tooltip_text = String(def["blurb"])
		btn.pressed.connect(_on_buy_trait.bind(trait_id))
		traits_box.add_child(btn)
		_trait_buttons[trait_id] = btn

func _on_buy_trait(trait_id: String) -> void:
	if GameState.buy_trait(trait_id):
		var btn: Button = _trait_buttons[trait_id]
		btn.disabled = true
		btn.text = "✔ " + btn.text
	_refresh_hud()

func _on_hype_changed(_total: int) -> void:
	_refresh_hud()
	if region_panel.visible:
		_rebuild_region_panel()

func _on_backlash_changed(_total: float) -> void:
	_refresh_hud()

func _on_tick(_t: int) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	hype_label.text = "Hype: %d" % GameState.hype
	backlash_label.text = "Backlash: %.0f / 100" % GameState.backlash
	tick_label.text = "Day: %d   World fans: %.1f%%" % [GameState.tick, GameState.global_fanbase_pct() * 100.0]
	if GameState.speed == 0.0:
		speed_label.text = "Speed: paused"
	else:
		speed_label.text = "Speed: %.0fx" % GameState.speed
	# Re-enable trait buttons whose cost is now affordable.
	for trait_id in _trait_buttons.keys():
		var btn: Button = _trait_buttons[trait_id]
		if GameState.owned_traits.has(trait_id):
			continue
		var cost: int = int(GameState.TRAIT_CATALOG[trait_id]["cost"])
		btn.disabled = GameState.hype < cost

func _unhandled_input(event: InputEvent) -> void:
	if not _debuted:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				GameState.speed = 0.0 if GameState.speed > 0.0 else 1.0
			KEY_1:
				GameState.speed = 1.0
			KEY_2:
				GameState.speed = 2.0
			KEY_3:
				GameState.speed = 4.0
		_refresh_hud()

func _on_game_over(reason: String, won: bool) -> void:
	GameState.speed = 0.0
	game_over_label.text = ("🏆  YOU WON\n\n" if won else "💀  GAME OVER\n\n") + reason
	game_over_panel.visible = true
