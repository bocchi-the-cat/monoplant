extends Node
## Per-buyer trust and the one formula that turns a flower into a price.

const TRUST_MAX := 100
const PREFERENCE_BONUS := 1.3
const OFF_PREFERENCE := 0.8
const TRUST_PRICE_BONUS := 500.0

var trust: Dictionary = {}


func _ready() -> void:
	new_run()


func new_run() -> void:
	trust.clear()
	for id in CustomerDB.all_ids():
		trust[id] = 0
		EventBus.trust_changed.emit(id, 0)


func get_trust(customer_id: String) -> int:
	return int(trust.get(customer_id, 0))


func add_trust(customer_id: String, amount: int) -> void:
	if not trust.has(customer_id):
		return
	trust[customer_id] = clampi(get_trust(customer_id) + amount, 0, TRUST_MAX)
	EventBus.trust_changed.emit(customer_id, get_trust(customer_id))


func multiplier(flower_id: String, customer_id: String) -> float:
	var customer := CustomerDB.get_customer(customer_id)
	var prefs: Array = customer.get("preferences", [])
	var mult := 1.0
	if not prefs.is_empty():
		mult = PREFERENCE_BONUS if prefs.has(flower_id) else OFF_PREFERENCE
	mult *= 1.0 + float(get_trust(customer_id)) / TRUST_PRICE_BONUS
	return mult


func quote(flower_id: String, customer_id: String) -> int:
	var base := int(FlowerDB.get_flower(flower_id).get("base_value", 0))
	if base <= 0:
		return 0
	return maxi(1, int(round(float(base) * multiplier(flower_id, customer_id))))


func sells_preference(flower_id: String, customer_id: String) -> bool:
	var prefs: Array = CustomerDB.get_customer(customer_id).get("preferences", [])
	return prefs.has(flower_id)
