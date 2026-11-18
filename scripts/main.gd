extends Node3D
## Entry point. Owns the spawn kit, player placement, and the debug screenshot hook.

@onready var world: WorldBuilder = $World
@onready var player: Player = $Player
@onready var hud: HUD = $HUD


func _ready() -> void:
	hud.player = player
	player.spawn_point = player.global_position
	GameState.reset_run()
	Inventory.start_new_run()
	CustomerSystem.new_run()
	OrderSystem.new_run()

	var args := OS.get_cmdline_user_args()
	var loaded := false
	if args.has("--newrun"):
		SaveSystem.delete_save()
	if not (args.has("--test") or args.has("--demo") or args.has("--tour")):
		loaded = SaveSystem.load_game()
	if loaded:
		EventBus.notify("Welcome back - run loaded")
	else:
		EventBus.notify("Welcome to Petal & Profit")
		EventBus.notify("Select seeds with 1-8, then press E at a planter")
		EventBus.notify("Buyers: Rosa in the park, Marcus at No.14, Ivy at Flora & Feed")
		var autosave := Timer.new()
		autosave.wait_time = 60.0
		autosave.autostart = true
		autosave.timeout.connect(func() -> void: SaveSystem.save_game())
		add_child(autosave)

	if args.has("--savetest"):
		SaveSystem.delete_save()
		GameState.add_money(939)
		Inventory.add("bloom:rose", 3)
		SaveSystem.save_game()
		print("SAVE_WRITTEN")
		get_tree().quit()
		return

	if args.has("--test"):
		_run_tests()
		return
	if args.has("--tour"):
		_run_tour()
		return
	if args.has("--demo"):
		_setup_demo(args.has("--stage"))
		var aim_x := -3.2
		for a in args:
			if a.begins_with("--aim-x="):
				aim_x = float(a.split("=")[1])
		if args.has("--aim") or aim_x != -3.2:
			player.global_position = Vector3(aim_x, 0.12, -1.25)
			player.rotation.y = 0.0
	for a in args:
		if a.begins_with("--at="):
			var parts := a.substr(5).split(",")
			if parts.size() == 3:
				player.global_position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		elif a.begins_with("--look="):
			player.rotation.y = deg_to_rad(float(a.substr(7)))
	if args.has("--prepack") and not OrderSystem.requests.is_empty():
		var req: Dictionary = OrderSystem.requests[0]
		Inventory.add(FlowerDB.bloom_item(String(req["flower_id"])), int(req["qty"]))
		OrderSystem.pack(int(req["id"]))
	var modal_arg := ""
	for a in args:
		if a.begins_with("--modal="):
			modal_arg = a.substr(8)
	if modal_arg != "":
		await get_tree().process_frame
		_open_debug_modal(modal_arg)
	if args.has("--shot"):
		_capture_shot()


func _open_debug_modal(name: String) -> void:
	match name:
		"sell":
			hud.open_sell("rosa")
		"board":
			hud.open_board()
		"pack":
			hud.open_pack()
		"pause":
			hud.open_pause()
		"shop":
			hud.open_shop()


func _start_new_run() -> void:
	GameState.reset_run()
	Inventory.start_new_run()
	CustomerSystem.new_run()
	OrderSystem.new_run()


func _run_tests() -> void:
	await get_tree().process_frame
	var code: int = TestSuite.run(get_tree())
	get_tree().quit(code)


func _run_tour() -> void:
	# Walks the player up to each interactable and checks the crosshair finds it.
	await get_tree().process_frame
	var names := ["OrderBoard", "PackingStation"]
	var found := 0
	for buyer in get_node("World/Buyers").get_children():
		names.append(String(buyer.name))
	for n in names:
		var node: Node3D = get_node_or_null("World/Buyers/" + n)
		if node == null:
			node = _find_by_class(get_node("World"), n)
		if node == null:
			print("TOUR MISSING  ", n)
			continue
		var offset := Vector3(0, 0.05, -1.8)
		if n == "OrderBoard":
			offset = Vector3(1.8, 0.05, -0.8)
		player.global_position = Vector3(node.global_position.x + offset.x, 0.15, node.global_position.z + offset.z)
		var dir := -offset.normalized()
		player.rotation.y = atan2(-dir.x, -dir.z)
		await get_tree().physics_frame
		await get_tree().physics_frame
		player._update_focus()
		var target := player._focus
		var prompt: String = String(target.get_prompt(player)) if target != null else "<none>"
		var ok := target == node
		if ok:
			found += 1
		else:
			var hit: Object = player.ray.get_collider() if player.ray.is_colliding() else null
			print("   ray hit: ", hit, "  dist: ", player.ray.get_collision_point() if player.ray.is_colliding() else Vector3.ZERO)
		print("%s  %s -> %s" % ["TOUR OK  " if ok else "TOUR FAIL", n, prompt])
	print("TOUR DONE %d/%d" % [found, names.size()])
	get_tree().quit()


func _find_by_class(root: Node, cls: String) -> Node3D:
	for child in root.get_children():
		if child.get_script() != null and String(child.get_script().get_global_name()) == cls:
			return child
		var nested := _find_by_class(child, cls)
		if nested != null:
			return nested
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.save_game()
		get_tree().quit()


func _setup_demo(evenly: bool) -> void:
	var species := ["daisy", "marigold", "tulip", "sunflower", "orchid", "rose"]
	var progress := [0.18, 0.42, 0.7, 0.82, 1.0, 0.96]
	var water := [100.0, 62.0, 30.0, 4.0, 90.0, 55.0]
	for i in world.pots.size():
		var pot := world.pots[i]
		var id: String = species[i % species.size()]
		pot.planted = false
		pot.spent = false
		pot.species = id
		pot.planted = true
		pot.progress = 1.0 if evenly else float(progress[i % progress.size()])
		pot.water = float(water[i % water.size()])
		pot._last_stage = FlowerDB.growth_stage(pot.progress)
		var vis := PlantVisual.new()
		vis.position = Vector3(0, 0.33, 0)
		pot.add_child(vis)
		vis.build(id)
		vis.update_growth(pot.progress)
		vis.set_water(pot.water)
		pot._visual = vis
		pot._update_soil()

	# A little stock so sell / pack screens can be exercised in demo mode.
	Inventory.add("bloom:daisy", 4)
	Inventory.add("bloom:marigold", 3)
	Inventory.add("bloom:tulip", 2)
	Inventory.add("bloom:rose", 1)


func _capture_shot() -> void:
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://debug_shot.png")
	print("SHOT_SAVED")
	get_tree().quit()
