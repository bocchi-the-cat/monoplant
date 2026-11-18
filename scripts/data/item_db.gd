class_name ItemDB
extends RefCounted
## Every carryable thing in the game, derived from the flower table.
## Hotbar stacks are plain dictionaries: { id, count, meta }.

const CAN_MAX_CHARGES := 6

static var _items: Dictionary = {}


static func _ensure() -> void:
	if not _items.is_empty():
		return
	for flower_id in FlowerDB.all_ids():
		var f := FlowerDB.get_flower(flower_id)
		_items[FlowerDB.seed_item(flower_id)] = {
			"name": "%s Seeds" % f["name"],
			"kind": "seed",
			"flower": flower_id,
			"stack": 99,
			"value": int(f["seed_cost"]),
			"color": "seed_packet",
			"desc": f.get("desc", ""),
		}
		_items[FlowerDB.bloom_item(flower_id)] = {
			"name": f["name"],
			"kind": "bloom",
			"flower": flower_id,
			"stack": 50,
			"value": int(f["base_value"]),
			"color": f["bloom_color"],
			"desc": "Cut %s. Sell it or pack it into an order." % f["name"],
		}
	_items["seed:wildflower"] = {
		"name": "Wildflower Seeds",
		"kind": "seed",
		"flower": "wildflower",
		"stack": 99,
		"value": int(FlowerDB.STARTER_COST),
		"color": "flower_white",
		"desc": "Cheap filler seed. Grows in %ds and sells for $%d. Always in stock." % [
			int(FlowerDB.STARTER_GROW_TIME), int(FlowerDB.STARTER_VALUE),
		],
	}
	_items["bloom:wildflower"] = {
		"name": "Wildflower",
		"kind": "bloom",
		"flower": "wildflower",
		"stack": 50,
		"value": int(FlowerDB.STARTER_VALUE),
		"color": "flower_white",
		"desc": "Cut wildflowers. Cheap, but somebody always buys them.",
	}
	_items["can:watering"] = {
		"name": "Watering Can",
		"kind": "can",
		"stack": 1,
		"value": 12,
		"color": "can_metal",
		"desc": "Waters one pot per charge. Refill at the greenhouse tap.",
	}
	_items["box:order"] = {
		"name": "Order Box",
		"kind": "box",
		"stack": 1,
		"value": 0,
		"color": "box_cardboard",
		"desc": "A packed bouquet ready for delivery.",
	}


static func get_item(id: String) -> Dictionary:
	_ensure()
	return _items.get(id, {})


static func exists(id: String) -> bool:
	_ensure()
	return _items.has(id)


static func display_name(id: String) -> String:
	return String(get_item(id).get("name", id))


static func color_key(id: String) -> String:
	return String(get_item(id).get("color", "ui_panel"))


## Seeds use their flower's colour so the hotbar reads at a glance.
static func swatch_color(id: String) -> Color:
	var item := get_item(id)
	if String(item.get("kind", "")) == "seed":
		var flower_id := String(item.get("flower", ""))
		var f := FlowerDB.get_flower(flower_id)
		if not f.is_empty():
			return Palette.color(String(f.get("bloom_color", "flower_white")))
	return Palette.color(color_key(id))


static func max_stack(id: String) -> int:
	return int(get_item(id).get("stack", 1))


static func kind(id: String) -> String:
	return String(get_item(id).get("kind", ""))


static func flower_of(id: String) -> String:
	return String(get_item(id).get("flower", ""))


static func base_value(id: String) -> int:
	return int(get_item(id).get("value", 0))


static func is_seed(id: String) -> bool:
	return kind(id) == "seed"


static func is_bloom(id: String) -> bool:
	return kind(id) == "bloom"


static func is_can(id: String) -> bool:
	return kind(id) == "can"


static func short_label(id: String) -> String:
	# Two-line hotbar label: "Daisy" / "Seeds"
	var item := get_item(id)
	if is_seed(id):
		return "%s\nSeeds" % FlowerDB.get_flower(item["flower"])["name"]
	if is_bloom(id):
		return "%s\nBloom" % item["name"]
	if is_can(id):
		return "Watering\nCan"
	if kind(id) == "box":
		return "Order\nBox"
	return display_name(id)
