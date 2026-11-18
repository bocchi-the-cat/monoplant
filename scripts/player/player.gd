class_name Player
extends CharacterBody3D
## First-person controller: movement, look, crosshair interaction, hotbar input,
## and the little held-item viewmodel.

signal focus_changed(node)

@export var walk_speed := 3.6
@export var sprint_speed := 5.9
@export var ground_accel := 14.0
@export var air_accel := 3.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0023
@export var interact_range := 3.2

var gravity: float = 15.7
var ui_open := false
var spawn_point := Vector3.ZERO

var _focus: Node = null
var _bob := 0.0
var _base_fov := 74.0
var _was_on_floor := true

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var ray: RayCast3D = $Head/Camera/Ray
@onready var hands: Node3D = $Head/Camera/Hands


func _ready() -> void:
	add_to_group("player")
	spawn_point = global_position
	_base_fov = camera.fov
	ray.target_position = Vector3(0, 0, -interact_range)
	EventBus.ui_blocked.connect(_on_ui_blocked)
	EventBus.hotbar_changed.connect(_refresh_viewmodel)
	EventBus.slot_selected.connect(_on_slot_selected)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_viewmodel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ui_open:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-86.0), deg_to_rad(86.0))
		return

	if ui_open:
		return

	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("drop_item"):
		_drop_selected()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Inventory.cycle(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Inventory.cycle(1)

	for i in Inventory.SLOT_COUNT:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			Inventory.select(i)
			break


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	var input_dir := Vector2.ZERO
	if not ui_open:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var wish := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var sprinting := Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	var target_speed := sprint_speed if sprinting else walk_speed
	var accel := ground_accel if is_on_floor() else air_accel

	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.move_toward(wish * target_speed, accel * delta * (wish.length() if wish.length() > 0.0 else 1.6))
	velocity.x = horiz.x
	velocity.z = horiz.z

	if not ui_open and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	move_and_slide()

	if global_position.y < -12.0:
		global_position = spawn_point
		velocity = Vector3.ZERO

	_update_bob(delta, sprinting)
	_update_focus()


func _update_bob(delta: float, sprinting: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.4:
		_bob += delta * (14.0 if sprinting else 9.5)
		var amount := clampf(speed / sprint_speed, 0.0, 1.0)
		camera.position = Vector3(cos(_bob * 0.5) * 0.014 * amount, absf(sin(_bob)) * 0.028 * amount - 0.008, 0.0)
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 9.0)

	var target_fov := _base_fov + (4.0 if sprinting and speed > 1.0 else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)

	if not _was_on_floor and is_on_floor():
		camera.position.y -= 0.035
	_was_on_floor = is_on_floor()


func _update_focus() -> void:
	ray.force_raycast_update()
	var next_focus: Node = null
	if ray.is_colliding():
		var hit := ray.get_collider()
		if hit is Interactable and hit.is_available():
			next_focus = hit
	if next_focus != _focus:
		_focus = next_focus
		focus_changed.emit(_focus)


func get_focus() -> Node:
	return _focus


func _try_interact() -> void:
	if _focus != null and is_instance_valid(_focus) and _focus.has_method("interact"):
		_focus.interact(self)


func _drop_selected() -> void:
	var slot := Inventory.selected_slot()
	if slot.is_empty():
		return
	var data := Inventory.take_from_slot(Inventory.selected, int(slot["count"]))
	if data.is_empty():
		return
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var pos := global_position + forward * 1.15
	pos.y = global_position.y + 0.35
	ItemPickup.spawn(get_tree().current_scene, data, pos)
	EventBus.notify("Dropped %s" % ItemDB.display_name(String(data["id"])))


func _on_ui_blocked(blocked: bool) -> void:
	ui_open = blocked
	if blocked:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_slot_selected(_index: int) -> void:
	_refresh_viewmodel()


func _refresh_viewmodel() -> void:
	if not is_instance_valid(hands):
		return
	for c in hands.get_children():
		c.queue_free()
	var slot := Inventory.selected_slot()
	if slot.is_empty():
		return
	var id := String(slot["id"])
	var key := ItemDB.color_key(id)
	if ItemDB.is_seed(id):
		Build.box(hands, Vector3(0.042, 0.062, 0.014), Vector3.ZERO, Palette.flat(Palette.color("seed_packet"), 0.85))
		Build.box(hands, Vector3(0.038, 0.018, 0.016), Vector3(0, 0.018, 0), Palette.flat(ItemDB.swatch_color(id), 0.7))
		Build.box(hands, Vector3(0.028, 0.010, 0.016), Vector3(0, -0.006, 0), Palette.flat(Color("efe9d8"), 0.9))
		Build.box(hands, Vector3(0.04, 0.004, 0.016), Vector3(0, -0.026, 0), Palette.mat("trim"))
	elif ItemDB.is_bloom(id):
		Build.cylinder(hands, 0.005, 0.007, 0.22, Vector3(0, 0.03, 0), Palette.mat("stem"), 5)
		Build.sphere(hands, 0.034, Vector3(0, 0.16, 0), Palette.mat(key))
		for i in 7:
			var a := TAU * float(i) / 7.0
			Build.box(hands, Vector3(0.05, 0.009, 0.024), Vector3(cos(a) * 0.04, 0.16, sin(a) * 0.04), Palette.mat(key), Vector3(0, -a, deg_to_rad(12)))
	elif ItemDB.is_can(id):
		Build.cylinder(hands, 0.052, 0.068, 0.15, Vector3(0, 0.02, 0), Palette.mat("can_metal"), 10)
		Build.box(hands, Vector3(0.1, 0.014, 0.014), Vector3(0.075, 0.065, 0), Palette.mat("metal_dark"))
		Build.box(hands, Vector3(0.016, 0.008, 0.07), Vector3(0.0, 0.095, 0), Palette.mat("metal_dark"))
	elif ItemDB.kind(id) == "box":
		Build.box(hands, Vector3(0.1, 0.076, 0.09), Vector3(0, 0.01, 0), Palette.mat("box_cardboard"))
		Build.box(hands, Vector3(0.104, 0.012, 0.032), Vector3(0, 0.05, 0), Palette.flat(Color("d8cdb4"), 0.9))
		Build.box(hands, Vector3(0.012, 0.076, 0.092), Vector3(0, 0.01, 0), Palette.flat(Color("8f6f4a"), 0.85))
	else:
		Build.box(hands, Vector3(0.12, 0.1, 0.12), Vector3.ZERO, Palette.mat(key))
