extends Node
##
## Global game state. Registered as an autoload in project.godot so any scene
## can read `GameState.hype` or call `GameState.advance_tick()`.
##

signal tick_advanced(tick: int)
signal hype_changed(new_total: int)
signal backlash_changed(new_total: float)
signal news_emitted(headline: String)
@warning_ignore("unused_signal")
signal region_milestone(region_id: String, threshold: float)
@warning_ignore("unused_signal")
signal channels_changed(region_id: String)
signal game_over(reason: String, won: bool)

const TICK_SECONDS := 1.0  # one in-game day per real second at 1x speed

var tick: int = 0
var speed: float = 1.0  # 0 = paused, 1/2/4 multipliers
var hype: int = 0
var backlash: float = 0.0  # 0.0 .. 100.0, you lose at 100

var regions: Array = []           # Array of Region
var regions_by_id: Dictionary = {} # id -> Region

# Traits the player has unlocked. Each trait id maps to its definition below.
var owned_traits: Dictionary = {}

# Active distribution channels per region.
# Shape: region_id -> Array[{channel_id: String, ticks_remaining: int}]
# ticks_remaining < 0 means permanent.
var region_channels: Dictionary = {}

# Distribution channels the player can activate in a region.
# growth_bonus is a multiplier added to that region's growth (1 + sum of bonuses).
# duration_ticks < 0 = permanent. requires_trait = "" means no gate.
const CHANNEL_CATALOG := {
	"streaming": {
		"name": "Streaming Launch",
		"cost": 40,
		"growth_bonus": 0.5,
		"duration_ticks": -1,
		"requires_trait": "",
		"blurb": "Local Spotify rollout. Permanent moderate growth.",
		"color": Color(0.20, 0.85, 0.45),
	},
	"radio": {
		"name": "Radio Push",
		"cost": 60,
		"growth_bonus": 0.35,
		"duration_ticks": -1,
		"requires_trait": "",
		"blurb": "FM stations add you to rotation. Slow burn, permanent.",
		"color": Color(1.0, 0.55, 0.1),
	},
	"live_tour": {
		"name": "Live Tour Stop",
		"cost": 120,
		"growth_bonus": 1.5,
		"duration_ticks": 14,
		"requires_trait": "",
		"blurb": "Two-week tour leg. Big boost, then expires.",
		"color": Color(0.95, 0.25, 0.30),
	},
	"tiktok_push": {
		"name": "TikTok Push",
		"cost": 80,
		"growth_bonus": 2.2,
		"duration_ticks": 7,
		"requires_trait": "tiktok_dance",
		"blurb": "Influencer payola. Viral surge that fades fast.",
		"color": Color(0.95, 0.30, 0.85),
	},
	"sync_deal": {
		"name": "Sync Deal",
		"cost": 180,
		"growth_bonus": 0.6,
		"duration_ticks": -1,
		"requires_trait": "",
		"blurb": "Your track lands in a hit show. Permanent push.",
		"color": Color(0.15, 0.70, 1.0),
	},
}

# v0 trait catalog. Each trait modifies the spread sim in some way.
# `cost` is hype points. `effects` is a free-form bag the sim reads.
const TRAIT_CATALOG := {
	"tiktok_dance": {
		"name": "TikTok Dance Hook",
		"cost": 50,
		"effects": {"spread_bonus": 0.15, "backlash_per_tick": 0.05},
		"blurb": "A 7-second loop achieves sentience. Spread +15%, mild critic groans.",
	},
	"masked_persona": {
		"name": "Masked Persona",
		"cost": 75,
		"effects": {"backlash_resist": 0.25},
		"blurb": "Nobody knows what you look like. Backlash accrues 25% slower.",
	},
	"festival_circuit": {
		"name": "Festival Circuit",
		"cost": 100,
		"effects": {"spread_bonus_climate": {"temperate": 0.20, "tropical": 0.20}},
		"blurb": "Summer main-stage slots. Big spread in temperate + tropical regions.",
	},
	"pirate_radio": {
		"name": "Pirate Radio + Defector USBs",
		"cost": 150,
		"effects": {"unlock_closed_regions": true},
		"blurb": "Reach regions that block streaming. Required for the hard nuts.",
	},
	"surprise_drop": {
		"name": "Surprise Album Drop",
		"cost": 120,
		"effects": {"hype_burst": 200},
		"blurb": "Instant +200 hype. One-shot.",
	},
}


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


func add_hype(amount: int) -> void:
	hype += amount
	emit_signal("hype_changed", hype)


func add_backlash(amount: float) -> void:
	# Masked Persona slows accrual.
	if owned_traits.has("masked_persona"):
		amount *= 1.0 - float(TRAIT_CATALOG["masked_persona"]["effects"]["backlash_resist"])
	backlash = clamp(backlash + amount, 0.0, 100.0)
	emit_signal("backlash_changed", backlash)
	if backlash >= 100.0:
		emit_signal("game_over", "You got cancelled. The discourse won.", false)


func buy_trait(trait_id: String) -> bool:
	if owned_traits.has(trait_id):
		return false
	if not TRAIT_CATALOG.has(trait_id):
		return false
	var def: Dictionary = TRAIT_CATALOG[trait_id]
	var cost: int = def["cost"]
	if hype < cost:
		return false
	hype -= cost
	owned_traits[trait_id] = true
	emit_signal("hype_changed", hype)
	# Handle one-shot effects.
	if def["effects"].has("hype_burst"):
		add_hype(int(def["effects"]["hype_burst"]))
	emit_signal("news_emitted", "TRAIT UNLOCKED: " + def["name"])
	return true


func activate_channel(region_id: String, channel_id: String) -> bool:
	if not CHANNEL_CATALOG.has(channel_id):
		return false
	if not regions_by_id.has(region_id):
		return false
	var def: Dictionary = CHANNEL_CATALOG[channel_id]
	var trait_gate: String = String(def["requires_trait"])
	if trait_gate != "" and not owned_traits.has(trait_gate):
		return false
	# One of each channel per region. Re-activating a timed channel refreshes it.
	var active: Array = region_channels.get(region_id, [])
	for ch in active:
		if String(ch["channel_id"]) == channel_id:
			if int(def["duration_ticks"]) < 0:
				return false  # already permanent, no refresh
			# Refresh the duration (paying again).
			if hype < int(def["cost"]):
				return false
			hype -= int(def["cost"])
			ch["ticks_remaining"] = int(def["duration_ticks"])
			emit_signal("hype_changed", hype)
			emit_signal("channels_changed", region_id)
			emit_signal("news_emitted", "%s refreshed in %s." % [def["name"], regions_by_id[region_id].name])
			return true
	if hype < int(def["cost"]):
		return false
	hype -= int(def["cost"])
	active.append({
		"channel_id": channel_id,
		"ticks_remaining": int(def["duration_ticks"]),
	})
	region_channels[region_id] = active
	emit_signal("hype_changed", hype)
	emit_signal("channels_changed", region_id)
	emit_signal("news_emitted", "%s activated in %s." % [def["name"], regions_by_id[region_id].name])
	return true


func region_channel_bonus(region_id: String) -> float:
	if not region_channels.has(region_id):
		return 0.0
	var bonus: float = 0.0
	for ch in region_channels[region_id]:
		var def: Dictionary = CHANNEL_CATALOG[String(ch["channel_id"])]
		bonus += float(def["growth_bonus"])
	return bonus


func decay_channels() -> void:
	# Called once per tick. Counts down timed channels, drops the expired ones.
	for region_id in region_channels.keys():
		var kept: Array = []
		var any_expired: bool = false
		for ch in region_channels[region_id]:
			var remaining: int = int(ch["ticks_remaining"])
			if remaining < 0:
				kept.append(ch)  # permanent
			elif remaining > 1:
				ch["ticks_remaining"] = remaining - 1
				kept.append(ch)
			else:
				any_expired = true
				var def: Dictionary = CHANNEL_CATALOG[String(ch["channel_id"])]
				emit_signal("news_emitted",
					"%s wraps in %s." % [def["name"], regions_by_id[region_id].name])
		region_channels[region_id] = kept
		if any_expired:
			emit_signal("channels_changed", region_id)


func global_fanbase_pct() -> float:
	var total_pop := 0.0
	var fans := 0.0
	for r in regions:
		total_pop += r.population
		fans += r.population * r.fanbase_pct
	if total_pop <= 0.0:
		return 0.0
	return fans / total_pop


func check_world_domination() -> void:
	if global_fanbase_pct() >= 0.95:
		emit_signal("game_over", "You are the planet's DJ. Everyone is your fan.", true)
