extends Node
## The order board: three standing requests, packing them into boxes,
## and tracking packed orders until they are delivered.

const BOARD_SIZE := 3

var requests: Array = []
var active: Array = []
var _next_id := 1


func _ready() -> void:
	new_run()


func new_run() -> void:
	requests.clear()
	active.clear()
	_next_id = 1
	for i in BOARD_SIZE:
		_add_request()
	EventBus.order_board_changed.emit()


func _unlocked_flowers() -> Array:
	var out: Array = []
	for id in FlowerDB.all_ids():
		if GameState.is_unlocked(id):
			out.append(id)
	# Orders never ask for wildflowers: they are a solo safety net, not a contract crop.
	return out


func _add_request() -> void:
	var unlocked := _unlocked_flowers()
	if unlocked.is_empty():
		return
	var customer_ids := CustomerDB.all_ids()
	if customer_ids.is_empty():
		return

	# Prefer pairing a customer with a flower they actually like; fall back to
	# a random pairing once in a while so the board still feels varied.
	var pairs: Array = []
	for cid in customer_ids:
		for f in CustomerDB.get_customer(String(cid)).get("preferences", []):
			if unlocked.has(String(f)):
				pairs.append([String(cid), String(f)])

	var customer_id := ""
	var flower_id := ""
	if pairs.is_empty() or randf() < 0.12:
		customer_id = String(customer_ids[randi() % customer_ids.size()])
		flower_id = String(unlocked[randi() % unlocked.size()])
	else:
		var pair: Array = pairs[randi() % pairs.size()]
		customer_id = String(pair[0])
		flower_id = String(pair[1])

	var tier := int(FlowerDB.get_flower(flower_id).get("tier", 1))
	var max_qty := 3 if tier >= 2 else 5
	var qty := randi_range(2, max_qty)
	var unit := CustomerSystem.quote(flower_id, customer_id)
	var reward := int(round(float(unit) * float(qty) * 1.15)) + 5

	requests.append({
		"id": _next_id,
		"customer_id": customer_id,
		"flower_id": flower_id,
		"qty": qty,
		"reward": reward,
		"status": "open",
	})
	_next_id += 1
	EventBus.order_board_changed.emit()


func get_request(order_id: int) -> Dictionary:
	for r in requests:
		if int(r["id"]) == order_id:
			return r
	return {}


func next_order_id() -> int:
	return _next_id


func set_next_order_id(value: int) -> void:
	_next_id = maxi(value, 1)


func active_for_customer(customer_id: String) -> Array:
	var out: Array = []
	for o in active:
		if String(o["customer_id"]) == customer_id:
			out.append(o)
	return out


func can_pack(req: Dictionary) -> bool:
	var bloom := FlowerDB.bloom_item(String(req.get("flower_id", "")))
	return Inventory.has(bloom, int(req.get("qty", 1)))


func pack(order_id: int) -> bool:
	var req := get_request(order_id)
	if req.is_empty() or not can_pack(req):
		return false

	var flower_id := String(req["flower_id"])
	var qty := int(req["qty"])
	var bloom := FlowerDB.bloom_item(flower_id)

	Inventory.remove_item(bloom, qty)
	var meta := {
		"order_id": int(req["id"]),
		"customer_id": String(req["customer_id"]),
		"flower_id": flower_id,
		"qty": qty,
		"reward": int(req["reward"]),
	}
	if Inventory.add("box:order", 1, meta) > 0:
		Inventory.add(bloom, qty)
		EventBus.notify("Hotbar full - make room for the box")
		return false

	requests.erase(req)
	req["status"] = "packed"
	active.append(req)
	_add_request()
	EventBus.order_board_changed.emit()
	EventBus.notify("Packed %d x %s for %s" % [qty, FlowerDB.get_flower(flower_id)["name"], CustomerDB.display_name(String(req["customer_id"]))])
	return true


func complete(order_id: int) -> Dictionary:
	for o in active:
		if int(o["id"]) == order_id:
			active.erase(o)
			EventBus.order_board_changed.emit()
			return o
	return {}


func reset_if_stale() -> void:
	# After a save load, drop packed orders that no longer have a matching box.
	var kept: Array = []
	for o in active:
		var found := false
		for i in Inventory.SLOT_COUNT:
			var s = Inventory.slots[i]
			if s != null and String(s["id"]) == "box:order" and int(s["meta"].get("order_id", -1)) == int(o["id"]):
				found = true
				break
		if found:
			kept.append(o)
	active = kept
