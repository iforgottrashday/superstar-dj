extends Control
##
## Main scene controller for the conquest engine.
##
## Flow:
##   1. Faction picker (replaces the old debut modal) — pick from 5 playable
##      factions, see their start region and bonuses.
##   2. Tick loop runs. Click any region to open the RegionPanel.
##      - Your region: shows "Send army to <neighbor>" buttons for adjacent enemies.
##      - Enemy/neutral region: shows "Attack from <your-adjacent-region>" buttons.
##   3. Tech shop on the right replaces the old trait shop.
##

@onready var world_map: Control = $HSplit/Left/WorldMap
@onready var hype_label: Label = $HSplit/Right/HUD/HypeLabel
@onready var backlash_label: Label = $HSplit/Right/HUD/BacklashLabel
@onready var tick_label: Label = $HSplit/Right/HUD/TickLabel
@onready var speed_label: Label = $HSplit/Right/HUD/SpeedLabel
@onready var traits_box: VBoxContainer = $HSplit/Right/Traits

@onready var debut_panel: PanelContainer = $DebutPanel
@onready var debut_title: Label = $DebutPanel/Margin/VBox/Title
@onready var debut_subtitle: Label = $DebutPanel/Margin/VBox/Subtitle

@onready var region_panel: PanelContainer = $RegionPanel
@onready var region_title: Label = $RegionPanel/Margin/VBox/Header/Title
@onready var region_close: Button = $RegionPanel/Margin/VBox/Header/CloseBtn
@onready var region_stats: Label = $RegionPanel/Margin/VBox/Stats
@onready var region_channels_box: VBoxContainer = $RegionPanel/Margin/VBox/ChannelsScroll/Channels
@onready var region_channels_label: Label = $RegionPanel/Margin/VBox/ChannelsLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Margin/VBox/Label

var _tech_buttons: Dictionary = {}    # tech_id -> Button
var _picking_faction: bool = true
var _open_region_id: String = ""

func _ready() -> void:
	GameState.tick_advanced.connect(_on_tick)
	GameState.game_over.connect(_on_game_over)
	GameState.region_ownership_changed.connect(_on_region_ownership_changed)
	GameState.region_army_changed.connect(_on_region_army_changed)
	world_map.region_clicked.connect(_on_region_clicked)
	region_close.pressed.connect(_close_region_panel)
	GameState.speed = 0.0
	_show_faction_picker()
	_build_tech_shop()
	_refresh_hud()
	region_panel.visible = false
	game_over_panel.visible = false

func _show_faction_picker() -> void:
	debut_title.text = "CHOOSE YOUR FACTION"
	debut_subtitle.text = ""
	# Build a button per playable faction.
	for child in debut_subtitle.get_parent().get_children():
		if child.has_meta("faction_btn"):
			child.queue_free()
	for faction_id in GameState.FACTION_CATALOG.keys():
		if faction_id == "neutral":
			continue
		var def: Dictionary = GameState.FACTION_CATALOG[faction_id]
		var btn := Button.new()
		btn.set_meta("faction_btn", true)
		btn.text = String(def["name"]) + "  —  " + String(GameState.regions_by_id[String(def["start_region"])].name)
		btn.tooltip_text = String(def["blurb"])
		btn.add_theme_color_override("font_color", def["color"])
		btn.pressed.connect(_on_faction_picked.bind(faction_id))
		debut_subtitle.get_parent().add_child(btn)
	debut_panel.visible = true

func _on_faction_picked(faction_id: String) -> void:
	GameState.player_faction = faction_id
	debut_panel.visible = false
	_picking_faction = false
	GameState.speed = 1.0
	var def: Dictionary = GameState.FACTION_CATALOG[faction_id]
	GameState.emit_signal("news_emitted",
		"You take the throne of the %s. Banners unfurl over %s." % [
			String(def["name"]),
			GameState.regions_by_id[String(def["start_region"])].name,
		])
	GameState.emit_signal("news_emitted",
		"TIP: Click any region to inspect or order an attack. Adjacent regions only.")
	world_map.queue_redraw()
	_refresh_hud()

func _on_region_clicked(region_id: String) -> void:
	if _picking_faction:
		return
	_open_region_panel(region_id)

func _open_region_panel(region_id: String) -> void:
	_open_region_id = region_id
	_rebuild_region_panel()
	region_panel.visible = true

func _close_region_panel() -> void:
	_open_region_id = ""
	region_panel.visible = false

func _rebuild_region_panel() -> void:
	var r = GameState.regions_by_id.get(_open_region_id)
	if r == null:
		return
	var owner_id: String = String(r.owner)
	var owner_def: Dictionary = GameState.FACTION_CATALOG.get(owner_id, GameState.FACTION_CATALOG["neutral"])
	var fort_tag: String = "  🏰 fortified" if bool(r.fortified) else ""
	region_title.text = "%s%s" % [String(r.name), fort_tag]
	region_title.add_theme_color_override("font_color", owner_def["color"])
	region_stats.text = "Owner: %s   ·   Army: %d   ·   Population: %.1fM" % [
		String(owner_def["name"]),
		int(r.army),
		float(r.population),
	]
	for child in region_channels_box.get_children():
		child.queue_free()
	if owner_id == GameState.player_faction:
		region_channels_label.text = "DEPLOY FROM HERE"
		_build_outgoing_attack_rows(r)
	else:
		region_channels_label.text = "ATTACK THIS PROVINCE"
		_build_incoming_attack_rows(r)

func _build_outgoing_attack_rows(from_r) -> void:
	# Show one row per adjacent non-player region (target options from this region).
	var any_targets: bool = false
	for nid in from_r.neighbors:
		var n = GameState.regions_by_id.get(nid)
		if n == null:
			continue
		if String(n.owner) == GameState.player_faction:
			continue
		any_targets = true
		region_channels_box.add_child(_build_attack_row(from_r, n))
	if not any_targets:
		var l := Label.new()
		l.text = "No adjacent enemies. Pick a frontier region or expand."
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		region_channels_box.add_child(l)

func _build_incoming_attack_rows(to_r) -> void:
	# Show one row per adjacent player-owned region (sources to launch from).
	var any_sources: bool = false
	for nid in to_r.neighbors:
		var n = GameState.regions_by_id.get(nid)
		if n == null:
			continue
		if String(n.owner) != GameState.player_faction:
			continue
		any_sources = true
		region_channels_box.add_child(_build_attack_row(n, to_r))
	if not any_sources:
		var l := Label.new()
		l.text = "You have no adjacent provinces. Conquer your way over first."
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		region_channels_box.add_child(l)

func _build_attack_row(from_r, to_r) -> Control:
	# A row showing the "from → to" pair with a send-amount slider and Attack button.
	var row := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	row.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var label := Label.new()
	label.text = "%s (army %d) → %s (def %d%s)" % [
		String(from_r.name),
		int(from_r.army),
		String(to_r.name),
		int(to_r.army),
		"  🏰" if bool(to_r.fortified) else "",
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	# Slider sets attack size; default 70% of source army.
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = int(from_r.army)
	slider.value = int(int(from_r.army) * 0.7)
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(slider)
	var amount_label := Label.new()
	amount_label.text = "Send %d troops (keeping %d)" % [int(slider.value), int(from_r.army) - int(slider.value)]
	vbox.add_child(amount_label)
	slider.value_changed.connect(func(v: float):
		amount_label.text = "Send %d troops (keeping %d)" % [int(v), int(from_r.army) - int(v)]
	)
	var btn := Button.new()
	btn.text = "Attack"
	btn.pressed.connect(func():
		_on_player_attack(from_r, to_r, int(slider.value))
	)
	vbox.add_child(btn)
	return row

func _on_player_attack(from_r, to_r, send: int) -> void:
	if send <= 0:
		return
	if send > int(from_r.army):
		send = int(from_r.army)
	SimTick.resolve_player_attack(GameState, from_r, to_r, send)
	# Refresh panel in case the player wants another attack.
	_rebuild_region_panel()
	_refresh_hud()

func _on_region_ownership_changed(region_id: String, _new_owner: String) -> void:
	if region_panel.visible and region_id == _open_region_id:
		_rebuild_region_panel()
	_refresh_hud()

func _on_region_army_changed(_region_id: String) -> void:
	# Light rebuild — only matters when panel is open on the affected region.
	if region_panel.visible:
		_rebuild_region_panel()

func _build_tech_shop() -> void:
	for child in traits_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "TECHNOLOGY"
	traits_box.add_child(title)
	for tech_id in GameState.TECH_CATALOG.keys():
		var def: Dictionary = GameState.TECH_CATALOG[tech_id]
		var btn := Button.new()
		btn.text = "%s — %d gold" % [String(def["name"]), int(def["cost"])]
		btn.tooltip_text = String(def["blurb"])
		btn.pressed.connect(_on_buy_tech.bind(tech_id))
		traits_box.add_child(btn)
		_tech_buttons[tech_id] = btn

func _on_buy_tech(tech_id: String) -> void:
	if GameState.buy_tech(tech_id):
		var btn: Button = _tech_buttons[tech_id]
		btn.disabled = true
		btn.text = "✓ " + btn.text
	_refresh_hud()

func _on_tick(_t: int) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	if GameState.player_faction == "":
		hype_label.text = "—"
		backlash_label.text = ""
		tick_label.text = ""
		speed_label.text = ""
		return
	var faction_def: Dictionary = GameState.FACTION_CATALOG[GameState.player_faction]
	var owned: int = GameState.owned_regions(GameState.player_faction).size()
	var total: int = GameState.regions.size()
	var army: int = GameState.total_army(GameState.player_faction)
	hype_label.text = "%s   ·   Gold: %d" % [String(faction_def["name"]), GameState.treasury]
	backlash_label.text = "Provinces: %d / %d   ·   Total army: %d" % [owned, total, army]
	tick_label.text = "Year %d" % GameState.tick
	if GameState.speed == 0.0:
		speed_label.text = "Speed: paused"
	else:
		speed_label.text = "Speed: %.0fx" % GameState.speed
	# Tech buttons.
	for tech_id in _tech_buttons.keys():
		var btn: Button = _tech_buttons[tech_id]
		if GameState.owned_techs.has(tech_id):
			continue
		var cost: int = int(GameState.TECH_CATALOG[tech_id]["cost"])
		btn.disabled = GameState.treasury < cost

func _unhandled_input(event: InputEvent) -> void:
	if _picking_faction:
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
	game_over_label.text = ("⚔  THE WORLD IS YOURS\n\n" if won else "✠  YOUR LINE ENDS\n\n") + reason
	game_over_panel.visible = true
