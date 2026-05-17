class_name Region
extends RefCounted
##
## A single region (province) of medieval Eurasia. v1 of the conquest engine.
##

var id: String = ""
var name: String = ""
var population: float = 0.0      # in millions, drives recruitment per tick
var owner: String = "neutral"    # faction id, "neutral" if unclaimed
var army: int = 0                # army strength garrisoned here
var fortified: bool = false      # walls/castles — defense multiplier in combat
var climate: String = "temperate" # temperate | tropical | arid | cold
var neighbors: Array = []        # neighboring region ids — only adjacent regions can attack


func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", ""))
	name = String(d.get("name", id))
	population = float(d.get("population", 0.0))
	owner = String(d.get("owner", "neutral"))
	army = int(d.get("army", 0))
	fortified = bool(d.get("fortified", false))
	climate = String(d.get("climate", "temperate"))
	neighbors = d.get("neighbors", [])
