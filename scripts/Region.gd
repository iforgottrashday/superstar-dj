class_name Region
extends RefCounted
##
## A single region of the world. v0 keeps the resolution at ~12 macro regions —
## enough to feel global without modeling 200 countries.
##

var id: String = ""
var name: String = ""
var population: float = 0.0        # in millions
var fanbase_pct: float = 0.0       # 0.0 .. 1.0
var culture_resistance: float = 0.0 # 0.0 .. 1.0, friction against new sound
var climate: String = "temperate"   # temperate | tropical | arid | cold
var closed: bool = false            # requires pirate_radio trait to enter
var neighbors: Array = []           # neighboring region ids — spread bleeds across


func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", ""))
	name = String(d.get("name", id))
	population = float(d.get("population", 0.0))
	fanbase_pct = float(d.get("fanbase_pct", 0.0))
	culture_resistance = float(d.get("culture_resistance", 0.0))
	climate = String(d.get("climate", "temperate"))
	closed = bool(d.get("closed", false))
	neighbors = d.get("neighbors", [])
