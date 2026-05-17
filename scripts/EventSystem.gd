class_name EventSystem
extends RefCounted
##
## Event picker + effect applier. Stateless — all state lives on GameState.
##
## Events are defined in data/events.json. Each has preconditions, a weight,
## and a list of choices. apply_effect() interprets the effect dictionaries
## attached to each choice.
##


static func load_events() -> Array:
	var f := FileAccess.open("res://data/events.json", FileAccess.READ)
	if f == null:
		push_error("Could not load events.json")
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


static func pick_event(gs: Node, all_events: Array) -> Variant:
	# Filter by preconditions, then weighted random.
	var pool: Array = []
	for ev in all_events:
		if not _passes_conditions(gs, ev):
			continue
		if gs.events_seen.has(String(ev["id"])):
			# Don't repeat events within a single game (some are one-shot).
			# Exception: severe_winter, trade_caravan, hero_emerges can repeat.
			if not _is_repeatable(String(ev["id"])):
				continue
		pool.append(ev)
	if pool.is_empty():
		return null
	var total_weight: float = 0.0
	for ev in pool:
		total_weight += float(ev.get("weight", 1))
	var roll: float = randf() * total_weight
	var acc: float = 0.0
	for ev in pool:
		acc += float(ev.get("weight", 1))
		if roll <= acc:
			return ev
	return pool[pool.size() - 1]


static func _is_repeatable(event_id: String) -> bool:
	return event_id in ["severe_winter", "trade_caravan", "hero_emerges", "comet"]


static func _passes_conditions(gs: Node, ev: Dictionary) -> bool:
	var min_year: int = int(ev.get("min_year", 0))
	if gs.tick < min_year:
		return false
	var min_provinces: int = int(ev.get("min_provinces", 0))
	if gs.owned_regions(gs.player_faction).size() < min_provinces:
		return false
	var min_gold: int = int(ev.get("min_gold", 0))
	if gs.treasury < min_gold:
		return false
	var forbidden: Array = ev.get("forbidden_factions", [])
	if forbidden.has(gs.player_faction):
		return false
	var required: Array = ev.get("required_factions", [])
	if required.size() > 0 and not required.has(gs.player_faction):
		return false
	return true


static func apply_effects(gs: Node, effects: Dictionary) -> void:
	# Each key is one effect type. Values defined in events.json.
	for key in effects.keys():
		var key_str: String = String(key)
		var value: Variant = effects[key]
		# Strip numeric suffix (e.g., "modifier2" -> "modifier") so events can
		# fire the same effect kind twice in a single choice.
		var base_key: String = _strip_suffix(key_str)
		_apply_one(gs, base_key, value)


static func _strip_suffix(s: String) -> String:
	var out: String = s
	while out.length() > 0 and out[out.length() - 1].is_valid_int():
		out = out.substr(0, out.length() - 1)
	return out


static func _apply_one(gs: Node, key: String, value: Variant) -> void:
	match key:
		"gold":
			gs.add_treasury(int(value))
		"army_pct_random_owned":
			var r = _random_owned_region(gs)
			if r != null:
				var pct: float = float(value)
				var new_army: int = int(float(r.army) * (1.0 + pct))
				r.army = max(0, new_army)
				gs.emit_signal("region_army_changed", r.id)
		"army_pct_random_owned_again":
			# Same as above but separate roll (used by Black Death).
			var r2 = _random_owned_region(gs)
			if r2 != null:
				var pct2: float = float(value)
				r2.army = max(0, int(float(r2.army) * (1.0 + pct2)))
				gs.emit_signal("region_army_changed", r2.id)
		"army_flat_random_owned":
			var r3 = _random_owned_region(gs)
			if r3 != null:
				r3.army = max(0, int(r3.army) + int(value))
				gs.emit_signal("region_army_changed", r3.id)
		"army_flat_strongest_owned":
			var r4 = _strongest_owned_region(gs)
			if r4 != null:
				r4.army = max(0, int(r4.army) + int(value))
				gs.emit_signal("region_army_changed", r4.id)
		"fortify_random_owned":
			var r5 = _random_unfortified_owned(gs)
			if r5 != null:
				r5.fortified = true
				gs.emit_signal("region_army_changed", r5.id)
				gs.emit_signal("news_emitted", "%s is fortified." % String(r5.name))
		"modifier":
			var def: Dictionary = value
			gs.apply_modifier(String(def["type"]), float(def["value"]), int(def["ticks"]))
		"enemy_army_boost":
			var er = _random_enemy_region(gs)
			if er != null:
				er.army = int(er.army) + int(value)
				gs.emit_signal("region_army_changed", er.id)
				gs.emit_signal("news_emitted", "Mercenaries take service with %s in %s." % [
					String(gs.FACTION_CATALOG[String(er.owner)]["name"]),
					String(er.name),
				])
		"accelerate_crusade":
			gs.crusade_threshold = mini(int(gs.crusade_threshold), 4)
			gs.emit_signal("news_emitted", "Defiance noted. The Pope's letter darkens.")
		_:
			push_warning("Unknown event effect: " + key)


static func _random_owned_region(gs: Node):
	var owned: Array = gs.owned_regions(gs.player_faction)
	if owned.is_empty():
		return null
	return owned[randi() % owned.size()]


static func _strongest_owned_region(gs: Node):
	var owned: Array = gs.owned_regions(gs.player_faction)
	if owned.is_empty():
		return null
	var best = owned[0]
	for r in owned:
		if int(r.army) > int(best.army):
			best = r
	return best


static func _random_unfortified_owned(gs: Node):
	var pool: Array = []
	for r in gs.owned_regions(gs.player_faction):
		if not bool(r.fortified):
			pool.append(r)
	if pool.is_empty():
		# Fall back to any owned region.
		return _random_owned_region(gs)
	return pool[randi() % pool.size()]


static func _random_enemy_region(gs: Node):
	var pool: Array = []
	for r in gs.regions:
		var o: String = String(r.owner)
		if o != gs.player_faction and o != "neutral":
			pool.append(r)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]
