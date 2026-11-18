extends Node
## One JSON save slot. Growth is real time, so losing a run on quit would hurt:
## the pause menu saves, quitting saves, and a timer autosaves along the way.

const SAVE_PATH := "user://petal_and_profit_save.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_game() -> bool:
	var data := {
		"version": VERSION,
		"money": GameState.money,
		"total_earned": GameState.total_earned,
		"pots_owned": GameState.pots_owned,
		"spent_total": GameState.spent_total,
		"plants_harvested": GameState.plants_harvested,
		"deliveries_made": GameState.deliveries_made,
		"slots": _slots_to_data(),
		"selected": Inventory.selected,
		"trust": CustomerSystem.trust.duplicate(),
		"requests": OrderSystem.requests.duplicate(true),
		"active": OrderSystem.active.duplicate(true),
		"next_order_id": OrderSystem.next_order_id(),
		"pots": _pots_to_data(),
		"player": _player_to_data(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is not valid JSON")
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		return false

	GameState.money = int(data.get("money", GameState.START_MONEY))
	GameState.total_earned = int(data.get("total_earned", 0))
	GameState.pots_owned = int(data.get("pots_owned", GameState.START_POTS))
	GameState.spent_total = int(data.get("spent_total", 0))
	GameState.plants_harvested = int(data.get("plants_harvested", 0))
	GameState.deliveries_made = int(data.get("deliveries_made", 0))
	EventBus.money_changed.emit(GameState.money, 0)

	_load_slots(data.get("slots", []))
	Inventory.select(int(data.get("selected", 0)))

	CustomerSystem.trust.clear()
	for id in CustomerDB.all_ids():
		CustomerSystem.trust[String(id)] = 0
	var trust: Dictionary = data.get("trust", {})
	for key in trust:
		if CustomerSystem.trust.has(String(key)):
			CustomerSystem.trust[String(key)] = clampi(int(trust[key]), 0, CustomerSystem.TRUST_MAX)
			EventBus.trust_changed.emit(String(key), CustomerSystem.get_trust(String(key)))

	OrderSystem.requests.clear()
	for r in data.get("requests", []):
		OrderSystem.requests.append(_clean_order(r))
	OrderSystem.active.clear()
	for o in data.get("active", []):
		OrderSystem.active.append(_clean_order(o))
	OrderSystem.set_next_order_id(int(data.get("next_order_id", 1)))
	OrderSystem.reset_if_stale()
	EventBus.order_board_changed.emit()

	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.get("pots") != null:
		var pot_data: Array = data.get("pots", [])
		for i in world.pots.size():
			if i < pot_data.size():
				world.pots[i].restore(pot_data[i])

	_restore_player(data.get("player", {}))
	return true


func _slots_to_data() -> Array:
	var out: Array = []
	for s in Inventory.slots:
		if s == null:
			out.append(null)
		else:
			out.append({"id": s["id"], "count": int(s["count"]), "meta": s["meta"].duplicate(true)})
	return out


func _load_slots(raw: Array) -> void:
	for i in Inventory.SLOT_COUNT:
		Inventory.slots[i] = null
	for i in mini(raw.size(), Inventory.SLOT_COUNT):
		var s = raw[i]
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var id := String(s.get("id", ""))
		if not ItemDB.exists(id):
			continue
		var meta: Dictionary = s.get("meta", {})
		if meta.has("charges"):
			meta["charges"] = int(meta["charges"])
		Inventory.slots[i] = {"id": id, "count": int(s.get("count", 1)), "meta": meta}
	EventBus.hotbar_changed.emit()


func _pots_to_data() -> Array:
	var out: Array = []
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return out
	for pot in world.pots:
		out.append(pot.to_data())
	return out


func _clean_order(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return {
		"id": int(raw.get("id", 0)),
		"customer_id": String(raw.get("customer_id", "")),
		"flower_id": String(raw.get("flower_id", "")),
		"qty": int(raw.get("qty", 1)),
		"reward": int(raw.get("reward", 0)),
		"status": String(raw.get("status", "open")),
	}


func _player_to_data() -> Dictionary:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return {}
	return {"pos": [p.global_position.x, p.global_position.y, p.global_position.z], "yaw": p.rotation.y}


func _restore_player(raw: Dictionary) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or raw.is_empty():
		return
	var pos: Array = raw.get("pos", [])
	if pos.size() == 3:
		p.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	p.rotation.y = float(raw.get("yaw", 0.0))
