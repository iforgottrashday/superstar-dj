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
@warning_ignore("unused_signal")
signal pending_event_changed
@warning_ignore("unused_signal")
signal faction_power_state_changed
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
	"crusader": {
		"name": "Crusader Coalition",
		"color": Color(0.95, 0.92, 0.78),
		"start_region": "",
		"attack_bonus": 0.40,
		"defense_bonus": 0.30,
		"production_bonus": 0.30,
		"aggression": 1.0,
		"blurb": "The Pope's coalition. They have come for you.",
	},
	"steppe_horde": {
		"name": "The Great Horde",
		"color": Color(0.35, 0.18, 0.10),
		"start_region": "",
		"attack_bonus": 0.50,
		"defense_bonus": 0.0,
		"production_bonus": 0.40,
		"aggression": 1.0,
		"blurb": "The steppe has unified to crush the upstart.",
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

# Active temporary modifiers stack. Each: {type, value, expires_at: tick}
# Types: attack, defense, production, siege.
var temp_modifiers: Array = []

# Random-event machinery.
var all_events: Array = []
var events_seen: Dictionary = {}
var pending_event: Variant = null
var pre_event_speed: float = 0.0
var ticks_until_next_event: int = 10  # seeded; refreshed after each event

# World-reaction escalations. Thresholds tick down player province count.
var crusade_threshold: int = 5
var crusade_triggered: bool = false
var khan_threshold: int = 8
var khan_triggered: bool = false

# Faction signature ability state.
var lightning_raid_ready_at: int = 0
var diet_ready_at: int = 0
var greek_fire_ready_at: int = 0
var recruitment_ready_at: int = 0
var gunpowder_used: bool = false
var gunpowder_pending: bool = false    # next player attack is buffed
var greek_fire_pending: bool = false   # next attack on player is repelled


func _ready() -> void:
	_load_regions()
	all_events = EventSystem.load_events()
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
	bonus += current_modifier_value("attack")
	return bonus


func player_defense_bonus() -> float:
	var bonus: float = float(FACTION_CATALOG[player_faction]["defense_bonus"])
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("defense_bonus", 0.0))
	bonus += current_modifier_value("defense")
	return bonus


func player_siege_bonus() -> float:
	var bonus: float = 0.0
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("siege_bonus", 0.0))
	bonus += current_modifier_value("siege")
	return bonus


func player_production_bonus() -> float:
	var bonus: float = float(FACTION_CATALOG[player_faction]["production_bonus"])
	for tech_id in owned_techs.keys():
		var fx: Dictionary = TECH_CATALOG[tech_id]["effects"]
		bonus += float(fx.get("production_bonus", 0.0))
	bonus += current_modifier_value("production")
	return bonus


# ─── Temp modifiers (event-driven, time-limited bonuses/penalties) ───

func apply_modifier(type_id: String, value: float, ticks: int) -> void:
	temp_modifiers.append({
		"type": type_id,
		"value": value,
		"expires_at": tick + ticks,
	})


func decay_modifiers() -> void:
	var kept: Array = []
	for m in temp_modifiers:
		if int(m["expires_at"]) > tick:
			kept.append(m)
	temp_modifiers = kept


func current_modifier_value(type_id: String) -> float:
	var total: float = 0.0
	for m in temp_modifiers:
		if String(m["type"]) == type_id:
			total += float(m["value"])
	return total


# ─── World-reaction escalations ───

func check_escalations() -> void:
	var owned: int = owned_regions(player_faction).size()
	if not crusade_triggered and owned >= crusade_threshold:
		_trigger_crusade()
	if not khan_triggered and owned >= khan_threshold:
		_trigger_khan_of_khans()


func _trigger_crusade() -> void:
	crusade_triggered = true
	var target = _pick_escalation_target(["hre", "france", "iberia", "byzantium", "eastern_eu", "england"])
	if target == null:
		return
	set_region_owner(target.id, "crusader")
	target.army = 200
	emit_signal("region_army_changed", target.id)
	emit_signal("news_emitted",
		"⚔  POPE URBAN PREACHES A CRUSADE. 200 swords gather in %s. They ride for you." % String(target.name))


func _trigger_khan_of_khans() -> void:
	khan_triggered = true
	var target = _pick_escalation_target(["mongolia", "central_asia", "russia"])
	if target == null:
		return
	set_region_owner(target.id, "steppe_horde")
	target.army = 260
	emit_signal("region_army_changed", target.id)
	emit_signal("news_emitted",
		"⚔  THE GREAT HORDE RIDES. The steppe is one. 260 lances at %s." % String(target.name))


func _pick_escalation_target(preferred_ids: Array):
	for region_id in preferred_ids:
		var r = regions_by_id.get(region_id)
		if r != null and String(r.owner) != player_faction:
			return r
	# Fallback — any non-player region.
	for r in regions:
		if String(r.owner) != player_faction:
			return r
	return null


# ─── Random events ───

func try_trigger_event() -> void:
	if pending_event != null:
		return
	ticks_until_next_event -= 1
	if ticks_until_next_event > 0:
		return
	# Reset the next-event timer regardless of whether we actually fire one.
	ticks_until_next_event = randi_range(8, 16)
	var ev = EventSystem.pick_event(self, all_events)
	if ev == null:
		return
	present_event(ev)


func present_event(ev: Dictionary) -> void:
	pending_event = ev
	pre_event_speed = speed
	speed = 0.0
	events_seen[String(ev["id"])] = true
	emit_signal("news_emitted", "✶ " + String(ev["title"]))
	emit_signal("pending_event_changed")


func resolve_event_choice(choice_index: int) -> void:
	if pending_event == null:
		return
	var ev: Dictionary = pending_event
	var choices: Array = ev["choices"]
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	EventSystem.apply_effects(self, choice.get("effects", {}))
	pending_event = null
	speed = max(pre_event_speed, 1.0)
	emit_signal("pending_event_changed")


# ─── Faction signature powers ───

func can_use_faction_power() -> bool:
	match player_faction:
		"mongol":
			return tick >= lightning_raid_ready_at
		"hre":
			return tick >= diet_ready_at
		"byzantium":
			return tick >= greek_fire_ready_at and not greek_fire_pending
		"mamluk":
			return tick >= recruitment_ready_at
		"song":
			return not gunpowder_used
	return false


func faction_power_name() -> String:
	match player_faction:
		"mongol": return "Lightning Raid"
		"hre": return "Diet of Princes"
		"byzantium": return "Greek Fire"
		"mamluk": return "Recruitment Drive"
		"song": return "Gunpowder Stratagem"
	return ""


func faction_power_blurb() -> String:
	match player_faction:
		"mongol": return "Riders flock to your standard. +60 army to your strongest province. 20-turn cooldown."
		"hre": return "Imperial Diet convenes. +30% defense everywhere for 8 turns. 25-turn cooldown."
		"byzantium": return "Roll the fire-ships into the harbor. The next attack on you is repelled. 25-turn cooldown."
		"mamluk": return "Slave-soldier markets reopen. +15 army to ALL your provinces. 25-turn cooldown."
		"song": return "The Imperial Foundry primes. Your next attack deals +200% damage. Once per game."
	return ""


func faction_power_cooldown() -> int:
	match player_faction:
		"mongol": return maxi(0, lightning_raid_ready_at - tick)
		"hre": return maxi(0, diet_ready_at - tick)
		"byzantium": return maxi(0, greek_fire_ready_at - tick)
		"mamluk": return maxi(0, recruitment_ready_at - tick)
		"song":
			if gunpowder_used: return -1
			return 0
	return 0


func use_faction_power() -> bool:
	if not can_use_faction_power():
		return false
	match player_faction:
		"mongol":
			var r = _strongest_owned()
			if r != null:
				r.army = int(r.army) + 60
				emit_signal("region_army_changed", r.id)
			lightning_raid_ready_at = tick + 20
			emit_signal("news_emitted", "Banner-call! Riders flock to your standard.")
		"hre":
			apply_modifier("defense", 0.30, 8)
			diet_ready_at = tick + 25
			emit_signal("news_emitted", "The Diet of Princes convenes. Walls thicken across the realm.")
		"byzantium":
			greek_fire_pending = true
			greek_fire_ready_at = tick + 25
			emit_signal("news_emitted", "Greek fire is rolled to the docks. The next assault will burn.")
		"mamluk":
			for r in owned_regions(player_faction):
				r.army = int(r.army) + 15
				emit_signal("region_army_changed", r.id)
			recruitment_ready_at = tick + 25
			emit_signal("news_emitted", "Recruitment drive. Fifteen lances per province join the standard.")
		"song":
			gunpowder_pending = true
			gunpowder_used = true
			emit_signal("news_emitted", "The Imperial Foundry primes the dragons of war.")
	emit_signal("faction_power_state_changed")
	return true


func _strongest_owned():
	var owned: Array = owned_regions(player_faction)
	if owned.is_empty():
		return null
	var best = owned[0]
	for r in owned:
		if int(r.army) > int(best.army):
			best = r
	return best


func check_victory() -> void:
	var owned_count: int = owned_regions(player_faction).size()
	var total: int = regions.size()
	if owned_count == 0 and tick > 1:
		emit_signal("game_over", "Your last province has fallen. The chronicles record your name only briefly.", false)
		return
	if float(owned_count) / float(total) >= 0.7:
		emit_signal("game_over", "%d of %d provinces are yours. The world bows." % [owned_count, total], true)
		return
