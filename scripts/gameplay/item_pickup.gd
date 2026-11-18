class_name ItemPickup
extends Area3D
## A loose stack on the ground. Auto-collects when the player walks over it.

var stack: Dictionary = {}
var _visual: Node3D
var _time := 0.0
var _warned := false

static func spawn(parent: Node, data: Dictionary, pos: Vector3) -> ItemPickup:
	var p := ItemPickup.new()
	p.stack = data
	p.position = pos
	parent.add_child(p)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player body
	monitoring = true
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var id := String(stack.get("id", ""))
	var key := ItemDB.color_key(id)
	if ItemDB.is_bloom(id):
		Build.cylinder(_visual, 0.008, 0.012, 0.24, Vector3(0, 0.12, 0), Palette.mat("stem"), 5)
		Build.sphere(_visual, 0.05, Vector3(0, 0.26, 0), Palette.mat(key))
		for i in 6:
			var a := TAU * float(i) / 6.0
			Build.box(_visual, Vector3(0.075, 0.012, 0.032), Vector3(cos(a) * 0.06, 0.26, sin(a) * 0.06), Palette.mat(key), Vector3(0, -a, deg_to_rad(14)))
	elif ItemDB.is_can(id):
		Build.cylinder(_visual, 0.07, 0.09, 0.2, Vector3(0, 0.1, 0), Palette.mat("can_metal"), 10)
		Build.box(_visual, Vector3(0.12, 0.02, 0.02), Vector3(0.1, 0.16, 0), Palette.mat("metal_dark"))
	else:
		Build.box(_visual, Vector3(0.17, 0.22, 0.08), Vector3(0, 0.11, 0), Palette.mat(key))
		Build.label(_visual, ItemDB.short_label(id).replace("\n", " "), Vector3(0, 0.3, 0), 20, Palette.color("ui_text"), 0.0025)


func _process(delta: float) -> void:
	_time += delta
	if _visual:
		_visual.position.y = sin(_time * 2.4) * 0.03
		_visual.rotation.y += delta * 0.5


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_try_collect()


func _try_collect() -> void:
	if stack.is_empty():
		return
	var leftover := Inventory.add(String(stack["id"]), int(stack["count"]), stack.get("meta", {}))
	if leftover == 0:
		EventBus.notify("+%d %s" % [int(stack["count"]), ItemDB.display_name(String(stack["id"]))])
		queue_free()
		return
	if leftover < int(stack["count"]):
		stack["count"] = leftover
		EventBus.notify("Hands full")
	elif not _warned:
		_warned = true
		EventBus.notify("Hotbar full - press G to drop something")
