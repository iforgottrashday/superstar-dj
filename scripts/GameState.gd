extends Node
##
## Global game state for the conquest engine.
## Player picks a faction; all factions vie for control of medieval Eurasia.
##

signal tick_advanced(tick: int)
signal news_emitted(headline: String)
@warning_ignore("unused_signal")
signal region_ownership_changed(region_id: String, new_owner: String)
@warning_ignore("unused_signal")
signal region_army_changed(region_id: String)
signal game_over(reason: String, won: bool)

const TICK_SECONDS := 1.0

var tick: int = 0
var speed: float = 0.0  # 0 until faction selected
var player_faction: String = ""

var regions: Array = []
var regions_by_id: Dictionary = {}

# Tech the player has researched. Each tech id maps to its definition below.
var owned_techs: Dictionary = {}

# Playable + AI factions. The player picks one; the rest are AI-driven.
# Each has color, start region, combat bonuses, and AI personality.
const FACTION_CATALOG := {
	"mongol": {
		"name": "Mongol Horde",
		"color": Color(0.82, 0.20, 0.18),
		"start_region": "mongolia",
		"attack_bonus": 0.35,
		"defense_bonus": -0.10,
		"production_bonus": 0.20,
		"aggression": 1.0,
		"blurb": "Steppe horse archers. Massive attack bonus, weak holding cities. Best at rapid expansion across open country.",
	},
	"hre": {
		"name": "Holy Roman Empire",
		"color": Color(0.92, 0.78, 0.20),
		"start_region": "hre",
		"attack_bonus": 0.0,
		"defense_bonus": 0.30,
		"production_bonus": 0.10,
		"aggression": 0.4,
		"blurb": "Heavy infantry and stone castles. Strong defense, slow offense. Surrounded by potential allies and rivals.",
	},
	"byzantium": {
		"name": "Byzantine Empire",
		"color": Color(0.50, 0.20, 0.65),
		"start_region": "byzantium",
		"attack_bonus": 0.10,
		"defense_bonus": 0.25,
		"production_bonus": 0.15,
		"aggression": 0.5,
		"blurb": "Greek fire, walled Constantinople. Balanced and rich, but surrounded on every front.",
	},
	"mamluk": {
		"name": "Mamluk Sultanate",
		"color": Color(0.12, 0.62, 0.42),
		"start_region": "egypt",
		"attack_bonus": 0.15,
		"defense_bonus": 0.20,
		"production_bonus": 0.10,
		"aggression": 0.6,
		"blurb": "Slave-soldier cavalry. Stopped the Mongols at Ain Jalut. Strong all-rounder, two starting provinces.",
	},
	"china": {
		"name": "Song Dynasty",
		"color": Color(0.92, 0.50, 0.12),
		"start_region": "china",
		"attack_bonus": 0.0,
		"defense_bonus": 0.25,
		"production_bonus": 0.40,
		"aggression": 0.3,
		"blurb": "Gunpowder pioneers. Largest population on the map — production juggernaut. Hemmed in by the steppe.",
	},
	"neutral": {
		"name": "Independent",
		"color": Color(0.55, 0.55, 0.58),
		"start_region": "",
		"attack_bonus": 0.0,
		"defense_bonus": 0.10,
		"production_bonus": 0.0,
		"aggression": 0.0,
		"blurb": "",
	},
}

# Tech upgrades the player can research. Bonuses stack with faction modifiers.
const TECH_CATALOG := {
	"composite_bow": {
		"name": "Composite Bow",
		"cost": 80,
		"effects": {"attack_bonus": 0.10},
		"blurb": "Sinew-and-horn bows. Attack +10% globally.",
	},
	"castle_network": {
		"name": "Castle Network",
		"cost": 120,
		"effects": {"defense_bonus": 0.15, "fortify_owned": true},
		"blurb": "Fortify every region you currently own. Permanent defense +15%.",
	},
	"trebuchet": {
		"name": "Trebuchet",
		"cost": 100,
		"effects": {"siege_bonus": 0.40},
		"blurb": "Counterweight siege engines. Attack vs fortified regions +40%.",
	},
	"steppe_logistics": {
		"name": "Steppe Logistics",
		"cost": 90,
		"effects": {"production_bonus": 0.15},
		"blurb": "Long-distance grain caravans and remount stations. Army production +15%.",
	},
	"greek_fire": {
		"name": "Greek Fire",
		"cost": 140,
		"effects": {"defense_bonus": 0.20, "naval_block": true},
		"blurb": "Liquid fire defending coastal walls. Defense +20%. England + Japan stop being safe.",
	},
}

# Player's accumulated war-treasury, earned by winning battles + holding land.
var treasury: int = 0


func _ready() -> void:
	_load_regions()
	set_process(true)


func _process(delta: float) -> void:
	if speed <= 0.0:
		return
	_accum += delta * speed
	while _accum >= TICK_SECONDS:
		_accum -= TICK_SECONDS
		advance_tick()


var _accum: float = 0.0


func _load_regions() -> void:
	var path := "res://data/regions.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Could not open " + path)
		return
	var raw := f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("regions.json is not an array")
		return
	regions.clear()
	regions_by_id.clear()
	for entry in parsed:
		var r := Region.new()
		r.from_dict(entry)
		regions.append(r)
		regions_by_id[r.id] = r


func advance_tick() -> void:
	tick += 1
	SimTick.step(self)
	emit_signal("tick_advanced", tick)


func owned_regions(faction_id: String) -> Array:
	var out: Array = []
	for r in regions:
		if String(r.owner) == faction_id:
			out.append(r)
	return out


func total_army(faction_id: String) -> int:
	var sum: int = 0
	for r in regions:
		if String(r.owner) == faction_id:
			sum += int(r.army)
	return sum


func set_region_owner(region_id: String, new_owner: String) -> void:
	var r = regions_by_id.get(region_id)
	if r == null:
		return
	r.owner = new_owner
	emit_signal("region_ownership_changed", region_id, new_owner)


func change_army(region_id: String, delta: int) -> void:
	var r = regions_by_id.get(region_id)
	if r == null:
		return
	r.army = max(0, int(r.army) + delta)
	emit_signal("region_army_changed", region_id)


func add_treasury(amount: int) -> void:
	treasury += amount


func buy_tech(tech_id: String) -> bool:
	if owned_techs.has(tech_id):
		return false
	if not TECH_CATALOG.has(tech_id):
		return false
	var def: Dictionary = TECH_CATALOG[tech_id]
	var cost: int = int(def["cost"])
	if treasury < cost:
		return false
	treasury -= cost
	owned_techs[tech_id] = true
	# Castle Network is a one-shot effect — fortify everything you own now.
	if bool(def["effects"].get("fortify_owned", false)):
		for r in owned_regions(player_faction):
			r.fortified = true
			emit_signal("region_army_changed", r.id)  # piggyback to redraw
	emit_signal("news_emitted", "RESEARCHED: " + String(def["name"]))
	return true


func player_attack_bonus() -> float:
	var bonus: float = float(FACTION_CATALOG[player_faction]["attack_bonus"])
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("attack_bonus", 0.0))
	return bonus


func player_defense_bonus() -> float:
	var bonus: float = float(FACTION_CATALOG[player_faction]["defense_bonus"])
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("defense_bonus", 0.0))
	return bonus


func player_siege_bonus() -> float:
	var bonus: float = 0.0
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("siege_bonus", 0.0))
	return bonus


func player_production_bonus() -> float:
	var bonus: float = float(FACTION_CATALOG[player_faction]["production_bonus"])
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("production_bonus", 0.0))
	return bonus


func check_victory() -> void:
	var owned_count: int = owned_regions(player_faction).size()
	var total: int = regions.size()
	if owned_count == 0 and tick > 1:
		emit_signal("game_over", "Your last province has fallen. The chronicles record your name only briefly.", false)
		return
	if float(owned_count) / float(total) >= 0.7:
		emit_signal("game_over", "%d of %d provinces are yours. The world bows." % [owned_count, total], true)
		return
