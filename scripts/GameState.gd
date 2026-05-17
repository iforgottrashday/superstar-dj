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
