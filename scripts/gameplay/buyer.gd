class_name Buyer
extends Interactable
## A customer standing in town. Sells to you (loose blooms) and receives
## packed order boxes. Turns to face the player when they get close.

var customer_id := ""
var _body: Node3D
var _label: Label3D
var _base_yaw := 0.0


func _ready() -> void:
	var c := CustomerDB.get_customer(customer_id)
	display_name = String(c.get("name", "Buyer"))
	collision_size = Vector3(0.8, 1.9, 0.8)
	collision_offset = Vector3(0, 0.95, 0)
	_base_yaw = rotation.y
	_build(c)
	if _label == null:
		_label = Build.label(self, "%s\n%s" % [CustomerDB.display_name(customer_id), String(c.get("role", ""))], Vector3(0, 2.28, 0), 30, Palette.color("ui_text"), 0.0034)
	super._ready()
	set_process(true)


func _build(c: Dictionary) -> void:
	_body = Node3D.new()
	add_child(_body)

	var shirt := Palette.mat(String(c.get("shirt", "flower_pink")))
	var pants := Palette.mat(String(c.get("pants", "trim")))
	var skin := Palette.flat(c.get("skin", Color("c98d6b")), 0.85)
	var hair := Palette.flat(c.get("hair", Color("3a2e26")), 0.9)

	for side in [-1.0, 1.0]:
		Build.box(_body, Vector3(0.16, 0.82, 0.18), Vector3(0.11 * side, 0.41, 0), pants, Vector3.ZERO, "Leg")
		Build.box(_body, Vector3(0.18, 0.1, 0.26), Vector3(0.11 * side, 0.05, 0.02), Palette.mat("trim"), Vector3.ZERO, "Shoe")
	Build.box(_body, Vector3(0.46, 0.62, 0.27), Vector3(0, 1.06, 0), shirt, Vector3.ZERO, "Torso")
	for side in [-1.0, 1.0]:
		Build.box(_body, Vector3(0.13, 0.58, 0.16), Vector3(0.31 * side, 1.05, 0), shirt, Vector3(0, 0, deg_to_rad(4.0 * side)), "Arm")
		Build.box(_body, Vector3(0.12, 0.12, 0.13), Vector3(0.33 * side, 0.73, 0.02), skin, Vector3.ZERO, "Hand")
	Build.box(_body, Vector3(0.13, 0.1, 0.13), Vector3(0, 1.42, 0), skin, Vector3.ZERO, "Neck")
	Build.box(_body, Vector3(0.27, 0.31, 0.25), Vector3(0, 1.6, 0), skin, Vector3.ZERO, "Head")
	Build.box(_body, Vector3(0.29, 0.1, 0.27), Vector3(0, 1.75, 0), hair, Vector3.ZERO, "Hair")
	Build.box(_body, Vector3(0.06, 0.06, 0.05), Vector3(-0.07, 1.62, 0.13), Palette.flat(Color("1c1a18"), 0.7), Vector3.ZERO, "Eye")
	Build.box(_body, Vector3(0.06, 0.06, 0.05), Vector3(0.07, 1.62, 0.13), Palette.flat(Color("1c1a18"), 0.7), Vector3.ZERO, "Eye")

	# Marker ring coloured by their favourite flower: a thin halo, not a spotlight.
	var prefs: Array = c.get("preferences", [])
	var ring_key := "neon_teal"
	if not prefs.is_empty():
		ring_key = String(FlowerDB.get_flower(String(prefs[0])).get("bloom_color", "neon_teal"))
	var ring_mat := Palette.glow(ring_key, 0.55)
	for i in 16:
		var a := TAU * float(i) / 16.0
		var seg := Build.box(self, Vector3(0.2, 0.02, 0.055), Vector3(cos(a) * 0.5, 0.035, sin(a) * 0.5), ring_mat, Vector3(0, -a, 0), "Marker")
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target_yaw := _base_yaw
	if player != null:
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < 6.0 and to.length() > 0.05:
			# The blocky model's face points along +Z, so yaw is measured from there.
			target_yaw = atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 4.0, 0.0, 1.0))


func _matching_box() -> Dictionary:
	for i in Inventory.SLOT_COUNT:
		var s = Inventory.slots[i]
		if s == null:
			continue
		if String(s["id"]) != "box:order":
			continue
		if String(s["meta"].get("customer_id", "")) != customer_id:
			continue
		return {"index": i, "meta": s["meta"]}
	return {}


func get_prompt(_player: Node) -> String:
	var box := _matching_box()
	if not box.is_empty():
		var meta: Dictionary = box["meta"]
		var flower := String(FlowerDB.get_flower(String(meta.get("flower_id", ""))).get("name", "flowers"))
		return "Deliver %d x %s  \u2192  $%d" % [int(meta.get("qty", 0)), flower, int(meta.get("reward", 0))]
	return "Sell flowers to %s" % display_name


func is_actionable(_player: Node) -> bool:
	return true


func interact(_player: Node) -> void:
	var box := _matching_box()
	if box.is_empty():
		EventBus.sell_requested.emit(customer_id)
		return
	var meta: Dictionary = box["meta"]
	var taken := Inventory.take_from_slot(int(box["index"]), 1)
	if taken.is_empty():
		return
	var reward := int(meta.get("reward", 0))
	GameState.add_money(reward)
	GameState.deliveries_made += 1
	CustomerSystem.add_trust(customer_id, 12)
	OrderSystem.complete(int(meta.get("order_id", -1)))
	EventBus.sale_completed.emit(customer_id, reward)
	EventBus.notify("Delivered to %s: +$%d" % [display_name, reward])
