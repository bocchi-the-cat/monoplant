class_name CustomerDB
extends RefCounted
## The cast of buyers. Positions are hand-placed near landmarks so the player can
## find them from the street. Preferences drive the price multipliers.

static var CUSTOMERS := {
	"rosa": {
		"name": "Rosa",
		"role": "Park regular",
		"place": "Park bench, east side",
		"preferences": ["daisy", "tulip"],
		"pos": Vector3(26.4, 0.04, 27.2),
		"yaw": 180.0,
		"shirt": "flower_pink",
		"pants": "trim",
		"skin": Color("c98d6b"),
		"hair": Color("4a3b30"),
		"greeting": "Morning! Those flowers look fresh.",
	},
	"marcus": {
		"name": "Marcus",
		"role": "Number 14",
		"place": "Stoop of the brick house",
		"preferences": ["sunflower", "marigold"],
		"pos": Vector3(0.5, 0.34, 21.0),
		"yaw": 0.0,
		"shirt": "flower_orange",
		"pants": "metal_dark",
		"skin": Color("8a5a3c"),
		"hair": Color("241d18"),
		"greeting": "You're the greenhouse one, right? Good.",
	},
	"ivy": {
		"name": "Ivy",
		"role": "Florist",
		"place": "Flora & Feed storefront",
		"preferences": ["orchid", "rose"],
		"pos": Vector3(-27.0, 0.34, 21.0),
		"yaw": 0.0,
		"shirt": "flower_purple",
		"pants": "wall_inner",
		"skin": Color("e0b091"),
		"hair": Color("7a3f2a"),
		"greeting": "I buy the fancy stock. Orchids, roses. No weeds.",
	},
	"dennis": {
		"name": "Dennis",
		"role": "Bus stop loiterer",
		"place": "Bus shelter, greenhouse side",
		"preferences": ["marigold"],
		"pos": Vector3(-16.0, 0.17, 11.7),
		"yaw": 0.0,
		"shirt": "stucco_green",
		"pants": "brick_dark",
		"skin": Color("b07a55"),
		"hair": Color("6d6a63"),
		"greeting": "Buying for the missus. She likes the orange ones.",
	},
}


static func all_ids() -> Array:
	return CUSTOMERS.keys()


static func get_customer(id: String) -> Dictionary:
	return CUSTOMERS.get(id, {})


static func display_name(id: String) -> String:
	return String(get_customer(id).get("name", id))


static func place(id: String) -> String:
	return String(get_customer(id).get("place", ""))


static func preferences_text(id: String) -> String:
	var prefs: Array = get_customer(id).get("preferences", [])
	var names: Array = []
	for f in prefs:
		var data := FlowerDB.get_flower(String(f))
		if not data.is_empty():
			names.append(String(data["name"]))
	return ", ".join(names)
