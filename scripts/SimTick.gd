class_name SimTick
extends RefCounted
##
## One tick of the conquest sim. Runs once per game day at 1x speed.
##
## Order of operations per tick:
##   1. Recruitment — every owned region grows its army based on population
##   2. AI factions act — pick a target, send army, resolve combat
##   3. Player gains treasury based on holdings (passive income)
##   4. Victory / defeat check
##

const BASE_RECRUIT_PER_POP := 0.05    # army gained per million population per tick
const COMBAT_NOISE := 0.12            # random ±12% on each side's strength roll
const FORTIFIED_MULT := 1.40          # fortified regions get +40% defense
const ATTACK_SEND_FRACTION := 0.7     # AI sends 70% of strongest stack
const AI_MIN_ARMY_TO_ATTACK := 25     # don't bother if smaller than this
const TREASURY_PER_REGION_PER_TICK := 2
const TREASURY_PER_VICTORY := 25


static func step(gs: Node) -> void:
	gs.decay_modifiers()
	_recruit(gs)
	_ai_actions(gs)
	_passive_income(gs)
	_faction_curse_check(gs)
	gs.check_escalations()
	gs.try_trigger_event()
	gs.check_victory()


static func _recruit(gs: Node) -> void:
	for r in gs.regions:
		var owner_id: String = String(r.owner)
		if owner_id == "neutral":
			continue  # neutrals stay static, only defend
		var faction_def: Dictionary = gs.FACTION_CATALOG[owner_id]
		var production_bonus: float = float(faction_def["production_bonus"])
		# Player gets tech-based production bonus too.
		if owner_id == gs.player_faction:
			production_bonus = gs.player_production_bonus()
		var pop: float = float(r.population)
		var recruits: float = pop * BASE_RECRUIT_PER_POP * (1.0 + production_bonus)
		# Even tiny regions produce at least 1 per tick if owned.
		var added: int = max(1, int(recruits + 0.5))
		r.army = int(r.army) + added
		gs.emit_signal("region_army_changed", r.id)


static func _ai_actions(gs: Node) -> void:
	for faction_id in gs.FACTION_CATALOG.keys():
		if faction_id == gs.player_faction or faction_id == "neutral":
			continue
		_ai_act_for(gs, faction_id)


static func _ai_act_for(gs: Node, faction_id: String) -> void:
	var faction_def: Dictionary = gs.FACTION_CATALOG[faction_id]
	var aggression: float = float(faction_def["aggression"])
	# Aggression gates whether to even consider attacking this tick.
	if randf() > aggression:
		return
	var owned: Array = gs.owned_regions(faction_id)
	if owned.is_empty():
		return
	# Build a list of plausible attacks: (from, to, expected_outcome_score).
	var candidates: Array = []
	for r in owned:
		if int(r.army) < AI_MIN_ARMY_TO_ATTACK:
			continue
		for nid in r.neighbors:
			var n = gs.regions_by_id.get(nid)
			if n == null:
				continue
			if String(n.owner) == faction_id:
				continue
			# Rough score: our_army × atk_bonus / (their_army × def_mult).
			var atk: float = float(r.army) * (1.0 + float(faction_def["attack_bonus"]))
			var def_mult: float = 1.0
			if String(n.owner) != "neutral":
				def_mult += float(gs.FACTION_CATALOG[String(n.owner)]["defense_bonus"])
			if bool(n.fortified):
				def_mult *= FORTIFIED_MULT
			var def_v: float = float(maxi(int(n.army), 1)) * def_mult
			var ratio: float = atk / def_v
			candidates.append({"from": r, "to": n, "ratio": ratio})
	if candidates.is_empty():
		return
	# Pick the best ratio target. If it's still under 1.0, only attack 1-in-3 (gambles).
	candidates.sort_custom(_compare_ratio)
	var best: Dictionary = candidates[-1]  # highest ratio at end
	if float(best["ratio"]) < 1.0 and randf() > 0.33:
		return
	var from_r = best["from"]
	var to_r = best["to"]
	var send: int = int(float(from_r.army) * ATTACK_SEND_FRACTION)
	if send < 10:
		return
	_resolve_attack(gs, from_r, to_r, send, faction_id)


static func _compare_ratio(a: Dictionary, b: Dictionary) -> bool:
	return float(a["ratio"]) < float(b["ratio"])


static func resolve_player_attack(gs: Node, from_r, to_r, send: int) -> Dictionary:
	# Used by Main.gd when the player issues an attack.
	# Returns {"won": bool, "atk_strength": float, "def_strength": float}.
	return _resolve_attack(gs, from_r, to_r, send, gs.player_faction)


static func _resolve_attack(gs: Node, from_r, to_r, send: int, attacker_faction: String) -> Dictionary:
	# Subtract the attacking force from the home region.
	from_r.army = int(from_r.army) - send
	gs.emit_signal("region_army_changed", from_r.id)

	var atk_def: Dictionary = gs.FACTION_CATALOG[attacker_faction]
	var defender_faction: String = String(to_r.owner)
	var def_def: Dictionary = gs.FACTION_CATALOG.get(defender_faction, gs.FACTION_CATALOG["neutral"])

	# Attacker strength.
	var atk_bonus: float = float(atk_def["attack_bonus"])
	if attacker_faction == gs.player_faction:
		atk_bonus = gs.player_attack_bonus()
	var atk_strength: float = float(send) * (1.0 + atk_bonus)
	# Siege bonus vs fortified — only player has tech for this, but the path is shared.
	if bool(to_r.fortified):
		if attacker_faction == gs.player_faction:
			atk_strength *= 1.0 + gs.player_siege_bonus()
	# Song Gunpowder Stratagem — one-shot 3x multiplier on the player's next attack.
	if attacker_faction == gs.player_faction and gs.gunpowder_pending:
		atk_strength *= 3.0
		gs.gunpowder_pending = false
		gs.emit_signal("news_emitted", "GUNPOWDER DRAGONS roar from %s." % String(from_r.name))
	atk_strength *= randf_range(1.0 - COMBAT_NOISE, 1.0 + COMBAT_NOISE)

	# Defender strength.
	var def_bonus: float = float(def_def["defense_bonus"])
	if defender_faction == gs.player_faction:
		def_bonus = gs.player_defense_bonus()
	var def_strength: float = float(maxi(int(to_r.army), 1)) * (1.0 + def_bonus)
	if bool(to_r.fortified):
		def_strength *= FORTIFIED_MULT
	def_strength *= randf_range(1.0 - COMBAT_NOISE, 1.0 + COMBAT_NOISE)

	var atk_name: String = String(atk_def["name"])
	var def_name: String = String(def_def["name"])
	var result: Dictionary = {
		"won": false,
		"atk_strength": atk_strength,
		"def_strength": def_strength,
	}

	# Byzantium Greek Fire: a single attack on the player is repelled regardless.
	var greek_fire_save: bool = (
		gs.greek_fire_pending
		and defender_faction == gs.player_faction
		and atk_strength > def_strength
	)
	if greek_fire_save:
		gs.greek_fire_pending = false
		to_r.army = max(1, int(float(to_r.army) * 0.4))
		gs.emit_signal("news_emitted",
			"GREEK FIRE! %s's assault on %s burns in the harbor." % [atk_name, String(to_r.name)])
		gs.emit_signal("region_army_changed", to_r.id)
		return result

	if atk_strength > def_strength:
		# Attacker wins. Survivors occupy.
		var survivors: int = max(1, int((atk_strength - def_strength) * 0.55))
		to_r.army = survivors
		gs.set_region_owner(to_r.id, attacker_faction)
		# When a region flips, it loses its fortification status (siege wreckage).
		to_r.fortified = false
		gs.emit_signal("news_emitted",
			"%s seizes %s. Defenders routed; survivors number %d." % [atk_name, String(to_r.name), survivors])
		if attacker_faction == gs.player_faction:
			gs.add_treasury(TREASURY_PER_VICTORY)
		result["won"] = true
	else:
		# Defender wins. Attacking force destroyed.
		var defender_survivors: int = max(0, int((def_strength - atk_strength) * 0.45))
		to_r.army = defender_survivors
		gs.emit_signal("news_emitted",
			"%s breaks the assault on %s. %s retreats with heavy losses." % [def_name, String(to_r.name), atk_name])
		# Mamluk Slave Soldier Reinforcement — passive: surviving defenders get reinforced.
		if defender_faction == "mamluk" and defender_faction == gs.player_faction:
			to_r.army = int(to_r.army) + 25
			gs.emit_signal("news_emitted",
				"Slave-soldier markets reopen overnight. %s gains 25 troops." % String(to_r.name))

	gs.emit_signal("region_army_changed", to_r.id)
	return result


static func _passive_income(gs: Node) -> void:
	var owned: int = gs.owned_regions(gs.player_faction).size()
	if owned > 0:
		gs.add_treasury(owned * TREASURY_PER_REGION_PER_TICK)


# Each faction has a passive curse that periodically rolls a check against them.
static func _faction_curse_check(gs: Node) -> void:
	if gs.tick <= 0:
		return
	var f: String = String(gs.player_faction)
	if f == "mongol" and gs.tick % 15 == 0 and randf() < 0.25:
		var owned: Array = gs.owned_regions(f)
		if owned.size() > 1:
			var r = owned[randi() % owned.size()]
			gs.set_region_owner(r.id, "neutral")
			gs.emit_signal("news_emitted",
				"%s tires of steppe rule and raises its own banners." % String(r.name))
	elif f == "hre" and gs.tick % 30 == 0 and randf() < 0.30:
		gs.apply_modifier("production", -1.0, 5)
		gs.emit_signal("news_emitted",
			"The princes squabble at Augsburg. Tax collection stalls for five years.")
	elif f == "byzantium" and gs.tick % 25 == 0 and randf() < 0.25:
		var r2 = _random_owned(gs)
		if r2 != null:
			r2.army = max(1, int(float(r2.army) * 0.85))
			gs.emit_signal("region_army_changed", r2.id)
			gs.emit_signal("news_emitted",
				"Iconoclast riots in %s. The garrison thins." % String(r2.name))
	elif f == "mamluk" and gs.tick % 40 == 0 and randf() < 0.30:
		gs.treasury = maxi(0, gs.treasury - 50)
		gs.apply_modifier("production", -0.5, 5)
		gs.emit_signal("news_emitted",
			"A coup in Cairo. The new sultan empties the treasury — and the granaries.")
	elif f == "song" and gs.tick % 20 == 0 and randf() < 0.25:
		var r3 = _random_owned(gs)
		if r3 != null:
			r3.army = max(1, int(float(r3.army) * 0.90))
			gs.emit_signal("region_army_changed", r3.id)
			gs.emit_signal("news_emitted",
				"Peasant revolt in %s. Tax collectors flee for the capital." % String(r3.name))


static func _random_owned(gs: Node):
	var owned: Array = gs.owned_regions(gs.player_faction)
	if owned.is_empty():
		return null
	return owned[randi() % owned.size()]
