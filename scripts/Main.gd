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
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Margin/VBox/Label

var _trait_buttons: Dictionary = {} # trait_id -> Button
var _debuted: bool = false

func _ready() -> void:
	GameState.hype_changed.connect(_on_hype_changed)
	GameState.backlash_changed.connect(_on_backlash_changed)
	GameState.tick_advanced.connect(_on_tick)
	GameState.game_over.connect(_on_game_over)
	world_map.region_clicked.connect(_on_region_clicked)
	# Don't tick until the player picks a debut region.
	GameState.speed = 0.0
	_build_trait_shop()
	_refresh_hud()
	debut_panel.visible = true
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

func _debut_in(region_id: String) -> void:
	var r = GameState.regions_by_id[region_id]
	r.fanbase_pct = 0.05
	GameState.emit_signal("news_emitted",
		"You debut in %s. The first 50 people sign up to the mailing list." % r.name)
	debut_panel.visible = false
	_debuted = true
	GameState.speed = 1.0

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
