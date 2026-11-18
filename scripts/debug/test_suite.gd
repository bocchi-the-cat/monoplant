class_name TestSuite
extends RefCounted
## Headless logic checks. Run with: godot --headless --path . -- --test

static var _passed := 0
static var _failed := 0


static func run(tree: SceneTree) -> int:
	_passed = 0
	_failed = 0
	print("--- PETAL & PROFIT TESTS ---")
	_test_hotbar()
	_test_planting(tree)
	_test_dry_stall(tree)
	_test_watering(tree)
	_test_growth_math()
	_test_economy()
	_test_customers()
	_test_orders()
	_test_delivery(tree)
	_test_save(tree)
	_test_ui(tree)
	_test_recovery(tree)
	_test_full_loop(tree)
	Inventory.start_new_run()
	GameState.reset_run()
	print("--- %d passed, %d failed ---" % [_passed, _failed])
	return 0 if _failed == 0 else 1


static func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)


static func _first_pot(tree: SceneTree) -> PlantPot:
	var world := tree.get_first_node_in_group("world")
	if world == null:
		return null
	return world.pots[0]


static func _test_hotbar() -> void:
	print("[hotbar]")
	Inventory.start_new_run()
	_check(Inventory.slots.size() == 8, "eight slots exist")
	_check(Inventory.count_of("seed:daisy") == 3, "starts with 3 daisy seeds")
	_check(Inventory.count_of("seed:marigold") == 3, "starts with 3 marigold seeds")
	_check(Inventory.count_of("can:watering") == 1, "starts with a watering can")
	var leftover := Inventory.add("seed:daisy", 200)
	_check(leftover == 0, "200 extra seeds all fit")
	_check(Inventory.count_of("seed:daisy") == 203, "stack totals add up")
	var took := Inventory.take_from_slot(0, 10)
	_check(int(took.get("count", 0)) == 10, "taking from a slot reports the stack")
	_check(Inventory.count_of("seed:daisy") == 193, "removed seeds are gone")


static func _test_planting(tree: SceneTree) -> void:
	print("[planting]")
	Inventory.start_new_run()
	var pot := _first_pot(tree)
	if pot == null:
		_check(false, "world pots available")
		return
	pot._clear()
	Inventory.select(Inventory.find_slot("seed:daisy"))
	pot.interact(null)
	_check(pot.planted, "seed plants in an empty pot")
	_check(pot.species == "daisy", "plant remembers its species")
	_check(Inventory.count_of("seed:daisy") == 2, "planting consumes one seed")
	_check(pot.water == 100.0, "new plant starts watered")

	var before := pot.progress
	pot._process(5.0)
	_check(pot.progress > before, "growth advances over time")
	_check(pot.water < 100.0, "water drains while growing")

	pot.progress = 1.0
	pot._process(0.016)
	pot.interact(null)
	_check(pot.spent, "harvest marks the plant spent")
	_check(Inventory.count_of("bloom:daisy") >= 1, "harvest yields at least one bloom")
	pot.interact(null)
	_check(not pot.planted, "clearing resets the pot")
	_check(pot.progress == 0.0, "cleared pot has zero growth")


static func _test_dry_stall(tree: SceneTree) -> void:
	print("[dry stall]")
	Inventory.start_new_run()
	var pot := _first_pot(tree)
	pot._clear()
	Inventory.select(Inventory.find_slot("seed:marigold"))
	pot.interact(null)
	pot.water = 0.0
	var before := pot.progress
	pot._process(4.0)
	_check(is_equal_approx(pot.progress, before), "growth stalls at zero water")
	_check(pot.get_info()["stage"] == "Seed", "dry plant reports seed stage")


static func _test_watering(tree: SceneTree) -> void:
	print("[watering]")
	Inventory.start_new_run()
	var pot := _first_pot(tree)
	pot._clear()
	Inventory.select(Inventory.find_slot("seed:daisy"))
	pot.interact(null)
	pot.water = 0.0
	var can_slot := Inventory.find_slot("can:watering")
	var charges := Inventory.can_charges(can_slot)
	Inventory.select(can_slot)
	pot.interact(null)
	_check(pot.water == 100.0, "watering refills the pot")
	_check(Inventory.can_charges(can_slot) == charges - 1, "watering spends one charge")
	Inventory.refill_can(can_slot)
	_check(Inventory.can_charges(can_slot) == ItemDB.CAN_MAX_CHARGES, "tap refill restores charges")


static func _test_growth_math() -> void:
	print("[growth math]")
	_check(FlowerDB.stage_name(0.0) == "Seed", "0% is seed stage")
	_check(FlowerDB.stage_name(0.5) == "Leafy", "50% is leafy stage")
	_check(FlowerDB.stage_name(1.0) == "Bloom", "100% is bloom stage")
	_check(FlowerDB.water_drain_rate("daisy") > 0.0, "drain rate is positive")
	var daisy := FlowerDB.get_flower("daisy")
	_check(int(daisy["yield_min"]) <= int(daisy["yield_max"]), "yield range is valid")
	_check(FlowerDB.bloom_item("daisy") == "bloom:daisy", "item id mapping")


static func _test_economy() -> void:
	print("[economy]")
	GameState.reset_run()
	_check(GameState.money == 60, "starts with $60")
	_check(not GameState.is_unlocked("tulip"), "tulip starts locked")
	GameState.add_money(260)
	_check(GameState.is_unlocked("tulip"), "tulip unlocks at $250 earned")
	_check(GameState.total_earned == 260, "total earned tracks income")
	var ok := GameState.spend(100)
	_check(ok and GameState.money == 220, "spending deducts correctly")
	_check(not GameState.spend(9999), "cannot overspend")
	_check(GameState.money == 220, "failed purchase leaves balance alone")


static func _test_customers() -> void:
	print("[customers]")
	GameState.reset_run()
	CustomerSystem.new_run()
	var rosa_daisy := CustomerSystem.quote("daisy", "rosa")
	var marcus_daisy := CustomerSystem.quote("daisy", "marcus")
	_check(rosa_daisy > marcus_daisy, "preferred buyer pays more")
	var before := CustomerSystem.quote("daisy", "rosa")
	CustomerSystem.add_trust("rosa", 100)
	_check(CustomerSystem.quote("daisy", "rosa") > before, "trust raises the price")
	_check(CustomerSystem.get_trust("rosa") == 100, "trust caps at 100")
	CustomerSystem.add_trust("rosa", 50)
	_check(CustomerSystem.get_trust("rosa") == 100, "trust never exceeds the cap")
	_check(CustomerSystem.sells_preference("daisy", "rosa"), "preference lookup")
	_check(not CustomerSystem.sells_preference("rose", "rosa"), "off-preference lookup")


static func _test_orders() -> void:
	print("[orders]")
	GameState.reset_run()
	CustomerSystem.new_run()
	Inventory.start_new_run()
	OrderSystem.new_run()
	_check(OrderSystem.requests.size() == 3, "board starts with three requests")

	var req: Dictionary = OrderSystem.requests[0]
	var flower_id := String(req["flower_id"])
	var qty := int(req["qty"])
	var bloom := FlowerDB.bloom_item(flower_id)
	Inventory.add(bloom, qty)
	_check(OrderSystem.can_pack(req), "packing allowed when flowers are present")
	var order_id := int(req["id"])
	_check(OrderSystem.pack(order_id), "packing consumes flowers into a box")
	_check(Inventory.count_of("box:order") == 1, "box lands in the hotbar")
	_check(Inventory.count_of(bloom) == 0, "flowers were consumed")
	_check(OrderSystem.active.size() == 1, "order moves to in-transit")
	_check(OrderSystem.requests.size() == 3, "board refills after packing")

	var delivered := OrderSystem.complete(order_id)
	_check(not delivered.is_empty(), "completion returns the order")
	_check(OrderSystem.active.is_empty(), "in-transit list clears on completion")


static func _test_delivery(tree: SceneTree) -> void:
	print("[delivery]")
	GameState.reset_run()
	CustomerSystem.new_run()
	Inventory.start_new_run()
	OrderSystem.new_run()
	var world := tree.get_first_node_in_group("world")
	if world == null:
		_check(false, "world available")
		return

	var req: Dictionary = OrderSystem.requests[0]
	var flower_id := String(req["flower_id"])
	var customer_id := String(req["customer_id"])
	var qty := int(req["qty"])
	var reward := int(req["reward"])
	Inventory.add(FlowerDB.bloom_item(flower_id), qty)
	if not OrderSystem.pack(int(req["id"])):
		_check(false, "order packs for delivery")
		return

	var buyer = world.get_node_or_null("Buyers/Buyer_" + customer_id)
	if buyer == null:
		_check(false, "buyer for %s exists" % customer_id)
		return
	_check(buyer.get_prompt(null).contains("Deliver"), "buyer asks for the box")
	var before := GameState.money
	buyer.interact(null)
	_check(GameState.money == before + reward, "delivery pays the order reward")
	_check(Inventory.count_of("box:order") == 0, "box leaves the hotbar")
	_check(OrderSystem.active.is_empty(), "order closes on delivery")
	_check(CustomerSystem.get_trust(customer_id) == 12, "delivery builds trust")


static func _test_save(tree: SceneTree) -> void:
	print("[save/load]")
	GameState.reset_run()
	CustomerSystem.new_run()
	Inventory.start_new_run()
	OrderSystem.new_run()
	var pot := _first_pot(tree)
	if pot == null:
		_check(false, "world pots available")
		return

	GameState.add_money(940)
	CustomerSystem.add_trust("rosa", 40)
	Inventory.add("bloom:tulip", 7)
	pot.restore({"planted": true, "species": "tulip", "progress": 0.55, "water": 33.0, "spent": false})
	_check(SaveSystem.save_game(), "save writes a file")
	var pot_data := SaveSystem._pots_to_data()
	_check(pot_data.size() == 6, "all six pots are written")
	_check(bool(pot_data[0].get("planted", false)) and String(pot_data[0].get("species", "")) == "tulip", "pot data records species")
	_check(int(pot_data[0].get("water", 0)) == 33, "pot data records water")

	# Scramble everything the save is meant to restore.
	GameState.reset_run()
	CustomerSystem.new_run()
	Inventory.start_new_run()
	pot.restore({})

	_check(SaveSystem.load_game(), "load reads the file back")
	_check(GameState.money == 1000, "money survives a save")
	_check(GameState.total_earned == 940, "earned total survives a save")
	_check(CustomerSystem.get_trust("rosa") == 40, "trust survives a save")
	_check(Inventory.count_of("bloom:tulip") == 7, "hotbar stocks survive a save")
	_check(pot.planted and pot.species == "tulip", "planted pot survives a save")
	_check(is_equal_approx(pot.progress, 0.55), "growth progress survives a save")
	_check(is_equal_approx(pot.water, 33.0), "pot water survives a save")
	SaveSystem.delete_save()
	_check(not SaveSystem.has_save(), "deleting the save clears it")


static func _test_ui(tree: SceneTree) -> void:
	print("[ui]")
	GameState.reset_run()
	Inventory.start_new_run()
	OrderSystem.new_run()
	var main := tree.current_scene
	var hud = main.get_node_or_null("HUD") if main != null else null
	if hud == null:
		_check(false, "hud is available")
		return

	hud.open_shop()
	_check(hud.modal_open, "shop opens")
	var before := GameState.money
	var seeds_before := Inventory.count_of("seed:daisy")
	hud._buy_seed("daisy")
	_check(GameState.money == before - 4, "buying a seed charges the price")
	_check(Inventory.count_of("seed:daisy") == seeds_before + 1, "buying a seed adds it to the hotbar")

	hud.open_sell("rosa")
	_check(hud.modal_open, "sell window opens")
	hud.open_board()
	_check(hud.modal_open, "order board opens")
	hud.open_pack()
	_check(hud.modal_open, "packing bench opens")
	hud.open_pause()
	_check(hud.modal_open, "pause menu opens")
	hud._close_modal()
	_check(not hud.modal_open, "closing a modal clears the flag")


static func _test_recovery(tree: SceneTree) -> void:
	print("[recovery]")
	# A player who blew every dollar and every seed can still grow something.
	GameState.reset_run()
	Inventory.start_new_run()
	for i in Inventory.SLOT_COUNT:
		Inventory.slots[i] = null
	GameState.money = 1
	GameState.total_earned = 0

	var pot := _first_pot(tree)
	pot._clear()
	Inventory.select(Inventory.find_slot("seed:wildflower"))
	_check(Inventory.find_slot("seed:wildflower") == -1, "no free seeds when broke")

	var bought := Inventory.add("seed:wildflower", 1)
	_check(bought == 0, "wildflower seed is purchasable state-wise")
	GameState.money = 1 - int(FlowerDB.STARTER_COST)
	Inventory.select(Inventory.find_slot("seed:wildflower"))
	_check(pot.get_prompt(null) != "", "broke player gets a planting prompt")
	pot.interact(null)
	_check(pot.planted, "broke player can still plant")
	_check(pot.species == FlowerDB.STARTER_SPECIES, "wildflower goes in the pot")
	pot.progress = 1.0
	pot._process(0.016)
	pot.interact(null)
	var blooms := Inventory.count_of("bloom:wildflower")
	_check(blooms >= 1, "wildflower harvests into blooms")
	_check(blooms >= 1 and ItemDB.base_value("bloom:wildflower") == int(FlowerDB.STARTER_VALUE), "wildflower has a sell value")
	var price := CustomerSystem.quote(FlowerDB.STARTER_SPECIES, "rosa")
	_check(price > 0, "wildflower sells for real money")
	pot._clear()
	Inventory.start_new_run()
	GameState.reset_run()


static func _test_full_loop(tree: SceneTree) -> void:
	print("[full loop]")
	GameState.reset_run()
	CustomerSystem.new_run()
	Inventory.start_new_run()
	OrderSystem.new_run()
	var world := tree.get_first_node_in_group("world")
	if world == null or world.pots.is_empty():
		_check(false, "world available")
		return
	var pot: PlantPot = world.pots[0]
	pot._clear()

	# 1. Plant
	Inventory.select(Inventory.find_slot("seed:daisy"))
	pot.interact(null)
	_check(pot.planted and pot.species == "daisy", "loop: planted")

	# 2. Grow to dry, then water
	pot.water = 0.0
	var stalled := pot.progress
	pot._process(2.0)
	_check(is_equal_approx(pot.progress, stalled), "loop: dry plant stalls")
	var can := Inventory.find_slot("can:watering")
	Inventory.select(can)
	pot.interact(null)
	_check(pot.water == 100.0, "loop: watered")

	# 3. Finish growing
	pot.progress = 1.0
	pot._process(0.016)
	pot.interact(null)
	_check(pot.spent, "loop: harvested")
	_check(Inventory.count_of("bloom:daisy") > 0, "loop: bloom in hotbar")
	pot.interact(null)
	_check(not pot.planted, "loop: pot cleared")

	# 4. Sell a bloom to Rosa
	var rosa = world.get_node_or_null("Buyers/Buyer_rosa")
	if rosa == null:
		_check(false, "loop: rosa exists")
		return
	var before := GameState.money
	var had := Inventory.count_of("bloom:daisy")
	var unit := CustomerSystem.quote("daisy", "rosa")
	Inventory.remove_item("bloom:daisy", 1)
	GameState.add_money(unit)
	_check(GameState.money == before + unit, "loop: sold one daisy")
	_check(Inventory.count_of("bloom:daisy") == had - 1, "loop: stock decreased")

	# 5. Pack an order end to end
	var req: Dictionary = OrderSystem.requests[0]
	var flower_id := String(req["flower_id"])
	var qty := int(req["qty"])
	Inventory.add(FlowerDB.bloom_item(flower_id), qty)
	_check(OrderSystem.pack(int(req["id"])), "loop: packed an order")
	_check(Inventory.count_of("box:order") == 1, "loop: box created")

	var box_slot := Inventory.find_slot("box:order")
	var box = Inventory.slots[box_slot]
	var meta: Dictionary = box["meta"]
	Inventory.take_from_slot(box_slot, 1)
	var reward := int(meta["reward"])
	var money_before := GameState.money
	GameState.add_money(reward)
	CustomerSystem.add_trust(String(meta["customer_id"]), 12)
	OrderSystem.complete(int(meta["order_id"]))
	_check(GameState.money == money_before + reward, "loop: delivered for reward")
	_check(Inventory.count_of("box:order") == 0, "loop: box consumed")
	_check(OrderSystem.active.is_empty(), "loop: order closed")

	pot._clear()
	Inventory.start_new_run()
	GameState.reset_run()
