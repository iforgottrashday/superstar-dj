extends Node
##
## Global game state for APEX — predator territorial conquest.
## Player picks a species; all predators vie for control of the wild kingdom.
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

# Playable + AI predator species. The player picks one; the rest are
# AI-driven. Each has color, starting territory, combat bonuses, and AI
# personality (aggression = how often it considers hunting per tick).
const FACTION_CATALOG := {
	"wolves": {
		"name": "Wolves",
		"color": Color(0.55, 0.62, 0.70),
		"start_region": "deep_woods",
		"attack_bonus": 0.25,
		"defense_bonus": 0.10,
		"production_bonus": 0.20,
		"aggression": 0.9,
		"blurb": "Pack hunters. Coordinated and relentless. Strong attack, decent defense, fast cub production. The standard apex starter.",
	},
	"bears": {
		"name": "Bears",
		"color": Color(0.45, 0.30, 0.18),
		"start_region": "cave_system",
		"attack_bonus": 0.40,
		"defense_bonus": 0.25,
		"production_bonus": 0.00,
		"aggression": 0.4,
		"blurb": "Solitary brutes. Highest attack, thick fur, but slow breeders. Best playing defensively from a fortified den.",
	},
	"lions": {
		"name": "Lions",
		"color": Color(0.90, 0.65, 0.20),
		"start_region": "tall_grass",
		"attack_bonus": 0.20,
		"defense_bonus": 0.30,
		"production_bonus": 0.15,
		"aggression": 0.7,
		"blurb": "Pride territorial. Strong defenders of held ground. Balanced offense + defense. The savanna lords.",
	},
	"eagles": {
		"name": "Eagles",
		"color": Color(0.30, 0.30, 0.50),
		"start_region": "eagle_perch",
		"attack_bonus": 0.15,
		"defense_bonus": -0.05,
		"production_bonus": 0.30,
		"aggression": 0.85,
		"blurb": "Sky hunters. Fragile in melee but raise many young. Signature power lets them strike non-adjacent territory.",
	},
	"crocs": {
		"name": "Crocodiles",
		"color": Color(0.25, 0.50, 0.30),
		"start_region": "river_bend",
		"attack_bonus": 0.30,
		"defense_bonus": 0.40,
		"production_bonus": 0.05,
		"aggression": 0.5,
		"blurb": "Ambush predators. Bristling jaws, armored hide. Strongest defense in the kingdom; patient hunters from the water.",
	},
	"neutral": {
		"name": "Wild Game",
		"color": Color(0.55, 0.55, 0.58),
		"start_region": "",
		"attack_bonus": 0.0,
		"defense_bonus": 0.10,
		"production_bonus": 0.0,
		"aggression": 0.0,
		"blurb": "",
	},
	"hunters": {
		"name": "Human Hunters",
		"color": Color(0.95, 0.92, 0.78),
		"start_region": "",
		"attack_bonus": 0.40,
		"defense_bonus": 0.30,
		"production_bonus": 0.30,
		"aggression": 1.0,
		"blurb": "Two-legged invaders from beyond the ridge. They carry steel and fire. They have come for you.",
	},
	"wild_dogs": {
		"name": "Wild Dog Pack",
		"color": Color(0.35, 0.18, 0.10),
		"start_region": "",
		"attack_bonus": 0.50,
		"defense_bonus": 0.0,
		"production_bonus": 0.40,
		"aggression": 1.0,
		"blurb": "Rival predators have united against the new apex. Hyenas, jackals, scavenger packs — all hungry.",
	},
}

# Adaptations the player can develop. Bonuses stack with species modifiers.
const TECH_CATALOG := {
	"sharp_claws": {
		"name": "Sharp Claws",
		"cost": 80,
		"effects": {"attack_bonus": 0.10},
		"blurb": "Heavy keratin claws. Attack +10% across all hunts.",
	},
	"thick_fur": {
		"name": "Thick Fur",
		"cost": 120,
		"effects": {"defense_bonus": 0.15, "fortify_owned": true},
		"blurb": "Dense undercoat. Fortify every territory you currently hold. Permanent defense +15%.",
	},
	"night_vision": {
		"name": "Night Vision",
		"cost": 100,
		"effects": {"siege_bonus": 0.40},
		"blurb": "Tapetum lucidum. Attacks on fortified dens +40% (the prey can't see you coming).",
	},
	"pack_coordination": {
		"name": "Pack Coordination",
		"cost": 90,
		"effects": {"production_bonus": 0.15},
		"blurb": "Better hunt signaling. Cub / young production +15%.",
	},
	"endurance": {
		"name": "Endurance",
		"cost": 140,
		"effects": {"defense_bonus": 0.20},
		"blurb": "Built-in stamina. Defense +20%. You outlast every challenger.",
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
var crusade_threshold: int = 5    # Hunters arrive (renamed from crusade)
var crusade_triggered: bool = false
var khan_threshold: int = 8       # Wild Dog pack rises (renamed from khan of khans)
var khan_triggered: bool = false

# Faction signature ability state.
var wolf_howl_ready_at: int = 0
var bear_rage_ready_at: int = 0
var lion_defense_ready_at: int = 0
var eagle_brood_ready_at: int = 0
var croc_strike_ready_at: int = 0
var croc_strike_primed: bool = false    # next player attack is buffed


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


func reset_for_new_run() -> void:
	# Wipe per-run state. all_events stays loaded; only the play-through
	# variables get reset. Regions are rehydrated from the JSON so all
	# territories return to their starting owners + armies.
	tick = 0
	speed = 0.0
	player_faction = ""
	owned_techs.clear()
	treasury = 0
	temp_modifiers.clear()
	events_seen.clear()
	pending_event = null
	pre_event_speed = 0.0
	ticks_until_next_event = 10
	crusade_threshold = 5
	crusade_triggered = false
	khan_threshold = 8
	khan_triggered = false
	wolf_howl_ready_at = 0
	bear_rage_ready_at = 0
	lion_defense_ready_at = 0
	eagle_brood_ready_at = 0
	croc_strike_ready_at = 0
	croc_strike_primed = false
	_accum = 0.0
	_load_regions()


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
	# Hunters appear in the territory closest to human civilization (the
	# burned woods, the plains near roads).
	var target = _pick_escalation_target(["burnt_wood", "wild_meadow", "tall_grass", "fern_grove", "stone_meadow"])
	if target == null:
		return
	set_region_owner(target.id, "hunters")
	target.army = 200
	emit_signal("region_army_changed", target.id)
	emit_signal("news_emitted",
		"⚠  HUNTERS HAVE COME. 200 armed men have crossed the ridge at %s. They are tracking you." % String(target.name))


func _trigger_khan_of_khans() -> void:
	khan_triggered = true
	# Rival packs gather in the wild interior — scavenger country.
	var target = _pick_escalation_target(["mud_wallow", "boulder_field", "burnt_wood", "stone_meadow"])
	if target == null:
		return
	set_region_owner(target.id, "wild_dogs")
	target.army = 260
	emit_signal("region_army_changed", target.id)
	emit_signal("news_emitted",
		"⚠  RIVAL PACKS UNITE. 260 jaws gather at %s. They want what you have." % String(target.name))


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
		"wolves":
			return tick >= wolf_howl_ready_at
		"bears":
			return tick >= bear_rage_ready_at
		"lions":
			return tick >= lion_defense_ready_at
		"eagles":
			return tick >= eagle_brood_ready_at
		"crocs":
			return tick >= croc_strike_ready_at and not croc_strike_primed
	return false


func faction_power_name() -> String:
	match player_faction:
		"wolves": return "Pack Howl"
		"bears": return "Awakening Rage"
		"lions": return "Territorial Stand"
		"eagles": return "Brood of Fledglings"
		"crocs": return "Death Roll"
	return ""


func faction_power_blurb() -> String:
	match player_faction:
		"wolves": return "Every wolf raises its head and answers. Attack +50% for 5 turns. 20-turn cooldown."
		"bears": return "The bear erupts. +60 pack at your strongest territory. 25-turn cooldown."
		"lions": return "The pride forms a wall. Defense +60% for 4 turns. 22-turn cooldown."
		"eagles": return "All nests fledge at once. +15 hunters to EVERY territory you hold. 25-turn cooldown."
		"crocs": return "Patient water-strike. Your next attack deals +200% damage. 30-turn cooldown."
	return ""


func faction_power_cooldown() -> int:
	match player_faction:
		"wolves": return maxi(0, wolf_howl_ready_at - tick)
		"bears": return maxi(0, bear_rage_ready_at - tick)
		"lions": return maxi(0, lion_defense_ready_at - tick)
		"eagles": return maxi(0, eagle_brood_ready_at - tick)
		"crocs":
			if croc_strike_primed:
				return -1  # not on cooldown but waiting for player to spend it
			return maxi(0, croc_strike_ready_at - tick)
	return 0


func use_faction_power() -> bool:
	if not can_use_faction_power():
		return false
	match player_faction:
		"wolves":
			apply_modifier("attack", 0.50, 5)
			wolf_howl_ready_at = tick + 20
			emit_signal("news_emitted", "The pack howls! Every wolf raises its head. Attack +50% for five seasons.")
		"bears":
			var r = _strongest_owned()
			if r != null:
				r.army = int(r.army) + 60
				emit_signal("region_army_changed", r.id)
			bear_rage_ready_at = tick + 25
			emit_signal("news_emitted", "The bear erupts from its den. Sixty new claws join the strongest territory.")
		"lions":
			apply_modifier("defense", 0.60, 4)
			lion_defense_ready_at = tick + 22
			emit_signal("news_emitted", "The pride forms a wall. Defense +60% for four seasons.")
		"eagles":
			for r in owned_regions(player_faction):
				r.army = int(r.army) + 15
				emit_signal("region_army_changed", r.id)
			eagle_brood_ready_at = tick + 25
			emit_signal("news_emitted", "Every nest fledges at once. Fifteen young hunters in every territory.")
		"crocs":
			croc_strike_primed = true
			croc_strike_ready_at = tick + 30
			emit_signal("news_emitted", "The river goes still. Something is waiting. Your next strike will be brutal.")
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
		emit_signal("game_over", "Your last territory has fallen. The forest forgets you.", false)
		return
	if float(owned_count) / float(total) >= 0.7:
		emit_signal("game_over", "%d of %d territories are yours. You are the apex predator." % [owned_count, total], true)
		return
