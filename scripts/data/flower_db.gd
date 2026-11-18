class_name FlowerDB
extends RefCounted
## Static content table for every flower species.
## Balance changes happen here and nowhere else.

const STAGE_NAMES := ["Seed", "Sprout", "Leafy", "Budding", "Bloom"]
const STAGE_THRESHOLDS := [0.0, 0.14, 0.38, 0.68, 1.0]

## The safety net. Costs $1, always in stock, and grows into an ordinary daisy.
## Without this a player who spends their last dollar on seeds can soft-lock.
const STARTER_SPECIES := "wildflower"
const STARTER_GROW_TIME := 60.0
const STARTER_VALUE := 3
const STARTER_COST := 1

const FLOWERS := {
	"daisy": {
		"name": "Daisy",
		"tier": 1,
		"grow_time": 75.0,
		"seed_cost": 4,
		"base_value": 8,
		"yield_min": 1,
		"yield_max": 3,
		"unlock_earned": 0,
		"petal_count": 8,
		"style": "ring",
		"bloom_size": 0.09,
		"bloom_color": "flower_white",
		"center_color": "flower_yellow",
		"stem_height": 0.42,
		"desc": "Cheap, fast, always in demand.",
	},
	"marigold": {
		"name": "Marigold",
		"tier": 1,
		"grow_time": 100.0,
		"seed_cost": 6,
		"base_value": 11,
		"yield_min": 1,
		"yield_max": 2,
		"unlock_earned": 0,
		"petal_count": 6,
		"style": "ring",
		"bloom_size": 0.1,
		"bloom_color": "flower_orange",
		"center_color": "flower_orange_deep",
		"stem_height": 0.5,
		"desc": "Hardy orange bloom. Steady seller.",
	},
	"tulip": {
		"name": "Tulip",
		"tier": 2,
		"grow_time": 200.0,
		"seed_cost": 12,
		"base_value": 24,
		"yield_min": 1,
		"yield_max": 2,
		"unlock_earned": 250,
		"petal_count": 5,
		"style": "bell",
		"bloom_size": 0.12,
		"bloom_color": "flower_pink",
		"center_color": "flower_pink_deep",
		"stem_height": 0.62,
		"desc": "Elegant and pink. Better margins.",
	},
	"sunflower": {
		"name": "Sunflower",
		"tier": 2,
		"grow_time": 240.0,
		"seed_cost": 15,
		"base_value": 30,
		"yield_min": 1,
		"yield_max": 2,
		"unlock_earned": 250,
		"petal_count": 12,
		"style": "ring",
		"bloom_size": 0.16,
		"bloom_color": "flower_yellow",
		"center_color": "flower_brown",
		"stem_height": 0.78,
		"desc": "Tall, bright, and worth the wait.",
	},
	"orchid": {
		"name": "Orchid",
		"tier": 3,
		"grow_time": 300.0,
		"seed_cost": 25,
		"base_value": 52,
		"yield_min": 1,
		"yield_max": 1,
		"unlock_earned": 900,
		"petal_count": 5,
		"style": "ring",
		"bloom_size": 0.11,
		"bloom_color": "flower_purple",
		"center_color": "flower_white",
		"stem_height": 0.66,
		"desc": "Fussy, slow, and very profitable.",
	},
	"rose": {
		"name": "Rose",
		"tier": 3,
		"grow_time": 420.0,
		"seed_cost": 35,
		"base_value": 74,
		"yield_min": 1,
		"yield_max": 1,
		"unlock_earned": 900,
		"petal_count": 9,
		"style": "cluster",
		"bloom_size": 0.11,
		"bloom_color": "flower_red",
		"center_color": "flower_red_deep",
		"stem_height": 0.7,
		"desc": "The classic. The money maker.",
	},
}

const ORDER := ["daisy", "marigold", "tulip", "sunflower", "orchid", "rose"]


static func get_flower(id: String) -> Dictionary:
	if id == STARTER_SPECIES:
		var daisy := FLOWERS["daisy"].duplicate()
		daisy["name"] = "Wildflower"
		daisy["grow_time"] = STARTER_GROW_TIME
		daisy["seed_cost"] = STARTER_COST
		daisy["base_value"] = STARTER_VALUE
		daisy["tier"] = 1
		daisy["unlock_earned"] = 0
		daisy["petal_count"] = 6
		daisy["bloom_size"] = 0.075
		daisy["desc"] = "Cheap filler bloom. Never sells out."
		return daisy
	return FLOWERS.get(id, {})


static func has_flower(id: String) -> bool:
	return id == STARTER_SPECIES or FLOWERS.has(id)


static func all_ids() -> Array:
	return ORDER.duplicate()


static func unlocked(flower_id: String, total_earned: int) -> bool:
	var data := get_flower(flower_id)
	return total_earned >= int(data.get("unlock_earned", 0))


static func seed_item(flower_id: String) -> String:
	return "seed:" + flower_id


static func bloom_item(flower_id: String) -> String:
	return "bloom:" + flower_id


static func growth_stage(progress: float) -> int:
	var stage := 0
	for i in STAGE_THRESHOLDS.size():
		if progress >= float(STAGE_THRESHOLDS[i]):
			stage = i
	return stage


static func stage_name(progress: float) -> String:
	return STAGE_NAMES[growth_stage(progress)]


static func stage_time_left(flower_id: String, progress: float) -> float:
	var grow := float(get_flower(flower_id).get("grow_time", 60.0))
	return maxf(0.0, grow * (1.0 - progress))


## Water drains so a full pot runs dry at ~75% growth: every plant needs one top-up.
static func water_drain_rate(flower_id: String) -> float:
	var grow := maxf(1.0, float(get_flower(flower_id).get("grow_time", 60.0)))
	return 100.0 / (grow * 0.75)
