extends Node
## Eight-slot hotbar. Slots are `null` or { id: String, count: int, meta: Dictionary }.
## This is deliberately the entire inventory: carry space is the constraint.

const SLOT_COUNT := 8

var slots: Array = []
var selected: int = 0


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = null


func start_new_run() -> void:
	for i in SLOT_COUNT:
		slots[i] = null
	selected = 0
	add("seed:daisy", 3)
	add("seed:marigold", 3)
	add("can:watering", 1, {"charges": ItemDB.CAN_MAX_CHARGES})
	EventBus.hotbar_changed.emit()
	EventBus.slot_selected.emit(selected)


## Adds items and returns how many did NOT fit.
func add(id: String, count := 1, meta := {}) -> int:
	if count <= 0:
		return 0
	if not ItemDB.exists(id):
		push_warning("Unknown item id: " + id)
		return count
	var max_stack := ItemDB.max_stack(id)
	var left := count

	for i in SLOT_COUNT:
		var s = slots[i]
		if s != null and s["id"] == id and s["meta"] == meta and s["count"] < max_stack:
			var moved: int = mini(max_stack - int(s["count"]), left)
			s["count"] = int(s["count"]) + moved
			left -= moved
			if left <= 0:
				break

	if left > 0:
		for i in SLOT_COUNT:
			if slots[i] == null:
				var moved: int = mini(max_stack, left)
				slots[i] = {"id": id, "count": moved, "meta": meta.duplicate(true)}
				left -= moved
				if left <= 0:
					break

	if left != count:
		EventBus.hotbar_changed.emit()
	return left


## Tries to add and reports failure cleanly. Returns false if nothing fit at all.
func try_add(id: String, count := 1, meta := {}) -> bool:
	var leftover := add(id, count, meta)
	if leftover == count:
		return false
	if leftover > 0:
		EventBus.notify("Hands full - some items left behind")
	return true


func count_of(id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == id:
			total += int(s["count"])
	return total


func has(id: String, count := 1) -> bool:
	return count_of(id) >= count


func remove_from_slot(index: int, count := 1) -> Dictionary:
	return take_from_slot(index, count)


## Removes up to `count` from a slot and returns what was removed as a stack dict.
func take_from_slot(index: int, count := 1) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return {}
	var s = slots[index]
	var taken: int = mini(count, int(s["count"]))
	var out := {"id": s["id"], "count": taken, "meta": s["meta"].duplicate(true)}
	s["count"] = int(s["count"]) - taken
	if int(s["count"]) <= 0:
		slots[index] = null
	EventBus.hotbar_changed.emit()
	return out


## Removes a specific item id from anywhere in the hotbar.
func remove_item(id: String, count := 1) -> int:
	var left := count
	for i in SLOT_COUNT:
		if left <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == id:
			var taken: int = mini(int(s["count"]), left)
			s["count"] = int(s["count"]) - taken
			left -= taken
			if int(s["count"]) <= 0:
				slots[i] = null
	if left != count:
		EventBus.hotbar_changed.emit()
	return count - left


func find_slot(id: String) -> int:
	for i in SLOT_COUNT:
		if slots[i] != null and slots[i]["id"] == id:
			return i
	return -1


func selected_slot() -> Dictionary:
	if selected < 0 or selected >= SLOT_COUNT:
		return {}
	var s = slots[selected]
	return s if s != null else {}


func select(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	selected = index
	EventBus.slot_selected.emit(selected)


func cycle(direction: int) -> void:
	select((selected + direction + SLOT_COUNT) % SLOT_COUNT)


func consume_selected(count := 1) -> bool:
	var s = selected_slot()
	if s.is_empty() or int(s["count"]) < count:
		return false
	take_from_slot(selected, count)
	return true


func use_can_charge(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	var s = slots[index]
	if s == null or not ItemDB.is_can(s["id"]):
		return false
	var charges := int(s["meta"].get("charges", 0))
	if charges <= 0:
		return false
	s["meta"]["charges"] = charges - 1
	EventBus.hotbar_changed.emit()
	return true


func refill_can(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	var s = slots[index]
	if s == null or not ItemDB.is_can(s["id"]):
		return false
	s["meta"]["charges"] = ItemDB.CAN_MAX_CHARGES
	EventBus.hotbar_changed.emit()
	return true


func can_charges(index: int) -> int:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return 0
	return int(slots[index]["meta"].get("charges", 0))


func sort_slots() -> void:
	var filled: Array = []
	for s in slots:
		if s != null:
			filled.append(s)
	for i in SLOT_COUNT:
		slots[i] = filled[i] if i < filled.size() else null
	EventBus.hotbar_changed.emit()
