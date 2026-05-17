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
@onready var power_name_label: Label = $HSplit/Right/FactionPower/PowerName
@onready var power_btn: Button = $HSplit/Right/FactionPower/PowerBtn
@onready var power_blurb_label: Label = $HSplit/Right/FactionPower/PowerBlurb
@onready var tech_bar: HBoxContainer = $TechBar/Margin/HBox

@onready var debut_panel: PanelContainer = $DebutPanel
@onready var debut_title: Label = $DebutPanel/Margin/VBox/Title
@onready var debut_subtitle: Label = $DebutPanel/Margin/VBox/Subtitle

@onready var region_panel: PanelContainer = $HSplit/Right/RegionPanel
@onready var region_title: Label = $HSplit/Right/RegionPanel/Margin/VBox/Header/Title
@onready var region_close: Button = $HSplit/Right/RegionPanel/Margin/VBox/Header/CloseBtn
@onready var region_stats: Label = $HSplit/Right/RegionPanel/Margin/VBox/Stats
@onready var region_channels_box: VBoxContainer = $HSplit/Right/RegionPanel/Margin/VBox/ChannelsScroll/Channels
@onready var region_channels_label: Label = $HSplit/Right/RegionPanel/Margin/VBox/ChannelsLabel

@onready var event_panel: PanelContainer = $EventPanel
@onready var event_title: Label = $EventPanel/Margin/VBox/Title
@onready var event_text: Label = $EventPanel/Margin/VBox/Text
@onready var event_choices_box: VBoxContainer = $EventPanel/Margin/VBox/Choices

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
	GameState.pending_event_changed.connect(_on_pending_event_changed)
	GameState.faction_power_state_changed.connect(_refresh_power_button)
	world_map.region_clicked.connect(_on_region_clicked)
	region_close.pressed.connect(_close_region_panel)
	power_btn.pressed.connect(_on_faction_power_pressed)
	GameState.speed = 0.0
	_show_faction_picker()
	_build_tech_shop()
	_refresh_hud()
	_rebuild_region_panel()  # render the empty/placeholder state
	event_panel.visible = false
	game_over_panel.visible = false
	_refresh_power_button()

func _show_faction_picker() -> void:
	debut_title.text = "CHOOSE YOUR FACTION"
	debut_subtitle.text = ""
	# Build a button per playable faction.
	for child in debut_subtitle.get_parent().get_children():
		if child.has_meta("faction_btn"):
			child.queue_free()
	for faction_id in GameState.FACTION_CATALOG.keys():
		var def: Dictionary = GameState.FACTION_CATALOG[faction_id]
		# Skip non-playable factions: neutral + the antagonist coalitions that
		# spawn only via escalation (Crusader, Steppe Horde).
		if String(def["start_region"]) == "":
			continue
		var btn := Button.new()
		btn.set_meta("faction_btn", true)
		btn.text = String(def["name"]) + "  —  " + String(GameState.regions_by_id[String(def["start_region"])].name)
		btn.tooltip_text = String(def["blurb"])
		btn.add_theme_color_override("font_color", def["color"])
		btn.add_theme_font_size_override("font_size", 16)
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
	_refresh_power_button()

func _on_region_clicked(region_id: String) -> void:
	if _picking_faction:
		return
	_open_region_panel(region_id)

func _open_region_panel(region_id: String) -> void:
	_open_region_id = region_id
	_rebuild_region_panel()

func _close_region_panel() -> void:
	# Now a "deselect" — panel stays visible but shows the placeholder.
	_open_region_id = ""
	_rebuild_region_panel()

func _rebuild_region_panel() -> void:
	for child in region_channels_box.get_children():
		child.queue_free()
	if _open_region_id == "":
		region_title.text = "Select a region"
		region_title.remove_theme_color_override("font_color")
		region_stats.text = ""
		region_channels_label.text = ""
		region_close.visible = false
		var hint := Label.new()
		hint.text = "Click any region on the map to inspect or order an action."
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		region_channels_box.add_child(hint)
		return
	var r = GameState.regions_by_id.get(_open_region_id)
	if r == null:
		return
	region_close.visible = true
	var owner_id: String = String(r.owner)
	var owner_def: Dictionary = GameState.FACTION_CATALOG.get(owner_id, GameState.FACTION_CATALOG["neutral"])
	var fort_tag: String = "  🏰 fortified" if bool(r.fortified) else ""
	region_title.text = "%s%s" % [String(r.name), fort_tag]
	region_title.add_theme_color_override("font_color", owner_def["color"])
	region_stats.text = "Owner: %s   ·   Army: %d   ·   Pop: %.1fM" % [
		String(owner_def["name"]),
		int(r.army),
		float(r.population),
	]
	if owner_id == GameState.player_faction:
		region_channels_label.text = "DEPLOY FROM HERE"
		_build_outgoing_rows(r)
	else:
		region_channels_label.text = "ATTACK THIS PROVINCE"
		_build_incoming_attack_rows(r)

func _build_outgoing_rows(from_r) -> void:
	# Show one row per adjacent region. Owned neighbors get a "Reinforce" button
	# (transfer troops, no combat); non-owned get an "Attack" button.
	var any_targets: bool = false
	for nid in from_r.neighbors:
		var n = GameState.regions_by_id.get(nid)
		if n == null:
			continue
		any_targets = true
		region_channels_box.add_child(_build_attack_row(from_r, n))
	if not any_targets:
		var l := Label.new()
		l.text = "No adjacent regions."
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
	# A row showing the "from → to" pair with a send-amount slider and an action
	# button. If `to_r` is player-owned the button reinforces (no combat); if
	# `to_r` is enemy/neutral the button attacks.
	var is_reinforce: bool = String(to_r.owner) == GameState.player_faction
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
	var target_label: String = "yours" if is_reinforce else "def %d%s" % [
		int(to_r.army),
		"  🏰" if bool(to_r.fortified) else "",
	]
	if is_reinforce:
		target_label = "yours, garrison %d" % int(to_r.army)
	label.text = "%s (army %d)\n→ %s (%s)" % [
		String(from_r.name),
		int(from_r.army),
		String(to_r.name),
		target_label,
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	header.add_child(label)
	# Slider sets send size; default 70% of source army for attacks, 50% for moves.
	var default_pct: float = 0.5 if is_reinforce else 0.7
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = int(from_r.army)
	slider.value = int(int(from_r.army) * default_pct)
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
	btn.text = "Reinforce" if is_reinforce else "Attack"
	btn.pressed.connect(func():
		_on_player_send(from_r, to_r, int(slider.value))
	)
	vbox.add_child(btn)
	return row

func _on_player_send(from_r, to_r, send: int) -> void:
	if send <= 0:
		return
	if send > int(from_r.army):
		send = int(from_r.army)
	if String(to_r.owner) == GameState.player_faction:
		# Reinforce — straight transfer, no combat.
		from_r.army = int(from_r.army) - send
		to_r.army = int(to_r.army) + send
		GameState.emit_signal("region_army_changed", from_r.id)
		GameState.emit_signal("region_army_changed", to_r.id)
		GameState.emit_signal("news_emitted",
			"%d troops march from %s to %s." % [send, String(from_r.name), String(to_r.name)])
	else:
		SimTick.resolve_player_attack(GameState, from_r, to_r, send)
	_rebuild_region_panel()
	_refresh_hud()

func _on_region_ownership_changed(region_id: String, _new_owner: String) -> void:
	if region_panel.visible and region_id == _open_region_id:
		_rebuild_region_panel()
	_refresh_hud()

func _on_region_army_changed(_region_id: String) -> void:
	# Don't rebuild on every army tick — it would reset the player's slider
	# every second during recruitment. The panel will refresh after the next
	# user action (sending troops, clicking another region, or closing/reopening).
	pass

func _build_tech_shop() -> void:
	# tech_bar is the bottom strip — preserve its static "TECHNOLOGY" Label,
	# only clear and rebuild the Button children.
	for child in tech_bar.get_children():
		if child is Button:
			child.queue_free()
	_tech_buttons.clear()
	for tech_id in GameState.TECH_CATALOG.keys():
		var def: Dictionary = GameState.TECH_CATALOG[tech_id]
		var btn := Button.new()
		btn.text = "%s — %d g" % [String(def["name"]), int(def["cost"])]
		btn.tooltip_text = String(def["blurb"])
		btn.custom_minimum_size = Vector2(200, 50)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_buy_tech.bind(tech_id))
		tech_bar.add_child(btn)
		_tech_buttons[tech_id] = btn

func _on_buy_tech(tech_id: String) -> void:
	if GameState.buy_tech(tech_id):
		var btn: Button = _tech_buttons[tech_id]
		btn.disabled = true
		btn.text = "✓ " + btn.text
	_refresh_hud()

func _on_tick(_t: int) -> void:
	_refresh_hud()
	_refresh_power_button()


# ─── Event modal ───

func _on_pending_event_changed() -> void:
	if GameState.pending_event == null:
		event_panel.visible = false
		return
	var ev: Dictionary = GameState.pending_event
	event_title.text = String(ev["title"])
	event_text.text = String(ev["text"])
	for child in event_choices_box.get_children():
		child.queue_free()
	var choices: Array = ev["choices"]
	for i in choices.size():
		var c: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = String(c["label"])
		btn.add_theme_font_size_override("font_size", 14)
		var requires_gold: int = int(c.get("requires_gold", 0))
		if requires_gold > 0 and GameState.treasury < requires_gold:
			btn.disabled = true
			btn.text += "   (need %d gold)" % requires_gold
		btn.pressed.connect(_on_event_choice.bind(i))
		event_choices_box.add_child(btn)
	event_panel.visible = true

func _on_event_choice(i: int) -> void:
	GameState.resolve_event_choice(i)
	_refresh_hud()


# ─── Faction power button ───

func _refresh_power_button() -> void:
	if GameState.player_faction == "" or GameState.player_faction == "neutral":
		power_name_label.text = "—"
		power_btn.text = "—"
		power_btn.disabled = true
		power_blurb_label.text = ""
		return
	power_name_label.text = GameState.faction_power_name()
	power_blurb_label.text = GameState.faction_power_blurb()
	var cd: int = GameState.faction_power_cooldown()
	if GameState.player_faction == "song" and GameState.gunpowder_used:
		power_btn.text = "Already used"
		power_btn.disabled = true
	elif cd <= 0:
		power_btn.text = "Use power"
		power_btn.disabled = false
	else:
		power_btn.text = "Ready in %d turns" % cd
		power_btn.disabled = true

func _on_faction_power_pressed() -> void:
	GameState.use_faction_power()
	_refresh_power_button()
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
	hype_label.text = "%s\nGold: %d" % [String(faction_def["name"]), GameState.treasury]
	backlash_label.text = "Provinces: %d / %d\nTotal army: %d" % [owned, total, army]
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
	if _picking_faction or GameState.pending_event != null:
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
