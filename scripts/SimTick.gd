class_name SimTick
extends RefCounted
##
## The simulation step. Pure function over GameState — runs once per game tick.
## Spread model:
##   growth = base_rate
##          * (1 - culture_resistance)
##          * (1 + trait_spread_bonus)
##          * (1 + climate_bonus)
##          * (1 + neighbor_pressure)
## Closed regions ignored unless pirate_radio is owned.
##

const BASE_GROWTH := 0.008          # per tick when nothing else applies
const NEIGHBOR_WEIGHT := 0.6        # how much neighbor fanbase pulls you up
const HYPE_PER_FAN_MILLION := 1.0   # hype gained per million new fans
const BACKLASH_FROM_FAME := 0.04    # passive backlash per tick once you're big


static func step(gs: Node) -> void:
	var spread_bonus := 0.0
	var climate_bonus: Dictionary = {}
	var unlock_closed := false
	var traits: Dictionary = gs.owned_traits
	for trait_id in traits.keys():
		var def: Dictionary = gs.TRAIT_CATALOG[trait_id]
		var fx: Dictionary = def["effects"]
		if fx.has("spread_bonus"):
			spread_bonus += float(fx["spread_bonus"])
		if fx.has("backlash_per_tick"):
			gs.add_backlash(float(fx["backlash_per_tick"]))
		if fx.has("spread_bonus_climate"):
			for c in fx["spread_bonus_climate"].keys():
				climate_bonus[c] = float(climate_bonus.get(c, 0.0)) + float(fx["spread_bonus_climate"][c])
		if fx.has("unlock_closed_regions") and bool(fx["unlock_closed_regions"]):
			unlock_closed = true

	# Passive backlash that scales quadratically with fame. Late game becomes
	# a race against cancellation; early game still accrues a slow drip.
	var global_pct: float = gs.global_fanbase_pct()
	var raw_backlash: float = 0.05 + global_pct * 0.6 + global_pct * global_pct * 2.5
	gs.add_backlash(raw_backlash)

	var new_fans_global: float = 0.0
	for r in gs.regions:
		if bool(r.closed) and not unlock_closed:
			continue
		var neighbor_pressure: float = _neighbor_pressure(r, gs)
		var c_bonus: float = float(climate_bonus.get(r.climate, 0.0))
		var current: float = float(r.fanbase_pct)
		var growth: float = BASE_GROWTH \
			* (1.0 - float(r.culture_resistance)) \
			* (1.0 + spread_bonus) \
			* (1.0 + c_bonus) \
			* (1.0 + neighbor_pressure * NEIGHBOR_WEIGHT)
		# Seeded regions (already > 0) grow faster than pristine ones.
		if current > 0.0:
			growth *= 1.0 + current  # snowball
		else:
			growth *= 0.2  # cold-start penalty
		var prev: float = current
		r.fanbase_pct = clampf(current + growth, 0.0, 1.0)
		var after: float = float(r.fanbase_pct)
		var delta_fans: float = (after - prev) * float(r.population)
		new_fans_global += delta_fans
		# Milestone news + visual pulse signal.
		if prev < 0.5 and after >= 0.5:
			gs.emit_signal("news_emitted", "%s hits 50%% fandom. Local radio is now mostly you." % r.name)
			gs.emit_signal("region_milestone", r.id, 0.5)
		elif prev < 0.9 and after >= 0.9:
			gs.emit_signal("news_emitted", "%s achieves total saturation. Government issues earplug subsidies." % r.name)
			gs.emit_signal("region_milestone", r.id, 0.9)

	if new_fans_global > 0.0:
		gs.add_hype(int(new_fans_global * HYPE_PER_FAN_MILLION))

	gs.check_world_domination()


static func _neighbor_pressure(r, gs: Node) -> float:
	if r.neighbors.is_empty():
		return 0.0
	var sum: float = 0.0
	var count: int = 0
	for nid in r.neighbors:
		if gs.regions_by_id.has(nid):
			sum += float(gs.regions_by_id[nid].fanbase_pct)
			count += 1
	if count == 0:
		return 0.0
	return sum / float(count)
