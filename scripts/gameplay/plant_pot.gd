class_name PlantPot
extends Interactable
## A single planter. Owns one plant's growth state and all the interaction rules.
## Growth runs on wall-clock time, so it keeps going while you are across town.

var pot_index := 0
var planted := false
var species := ""
var progress := 0.0
var water := 100.0
var spent := false

var _visual: PlantVisual
var _soil: MeshInstance3D
var _soil_mat: StandardMaterial3D
var _ready_glow: MeshInstance3D
var _dry_mark: Label3D
var _last_stage := -1
var _time := 0.0


func _ready() -> void:
	display_name = "Planter"
	collision_size = Vector3(0.62, 1.95, 0.62)
	collision_offset = Vector3(0, 0.95, 0)
	_build_pot()
	super._ready()
	set_process(true)


func _build_pot() -> void:
	Build.cylinder(self, 0.215, 0.16, 0.3, Vector3(0, 0.15, 0), Palette.mat("pot"), 10, "PotBody")
	Build.cylinder(self, 0.228, 0.228, 0.05, Vector3(0, 0.295, 0), Palette.mat("pot_dark"), 10, "PotRim")
	_soil_mat = Palette.flat(Palette.color("soil"), 0.98)
	_soil = Build.cylinder(self, 0.196, 0.196, 0.04, Vector3(0, 0.315, 0), _soil_mat, 10, "Soil")

	_ready_glow = Build.sphere(self, 0.035, Vector3(0, 1.15, 0), Palette.glow("flower_yellow", 3.0), "ReadyGlow")
	_ready_glow.visible = false

	_dry_mark = Build.label(self, "DRY", Vector3(0, 1.0, 0), 28, Palette.color("ui_bad"), 0.0035)
	_dry_mark.visible = false


func _process(delta: float) -> void:
	if not planted or spent:
		_steady_markers()
		return
	_time += delta

	if progress < 1.0:
		if water > 0.0:
			progress = minf(1.0, progress + delta / maxf(1.0, float(FlowerDB.get_flower(species).get("grow_time", 60.0))))
			water = maxf(0.0, water - FlowerDB.water_drain_rate(species) * delta)
		else:
			water = 0.0
		var stage := FlowerDB.growth_stage(progress)
		if stage != _last_stage:
			_last_stage = stage
			EventBus.plant_changed.emit(self)
			if stage == 4:
				EventBus.notify("%s is ready to harvest" % _flower_name())

	_visual.update_growth(progress)
	_visual.set_water(water)
	_update_soil()
	_steady_markers()


func _steady_markers() -> void:
	var ready := planted and not spent and progress >= 1.0
	_ready_glow.visible = ready
	if ready:
		_ready_glow.position.y = 1.05 + sin(_time * 2.5) * 0.03
	_dry_mark.visible = planted and not spent and water <= 0.5 and progress < 1.0


func _update_soil() -> void:
	var wet := clampf(water / 100.0, 0.0, 1.0)
	_soil_mat.albedo_color = Palette.color("soil_dry").lerp(Palette.color("soil_wet"), wet)


func _flower_name() -> String:
	return String(FlowerDB.get_flower(species).get("name", "Flower"))


func _selected_can_charges() -> int:
	var slot := Inventory.selected_slot()
	if slot.is_empty() or not ItemDB.is_can(String(slot["id"])):
		return 0
	return Inventory.can_charges(Inventory.selected)


func _selected_seed() -> String:
	var slot := Inventory.selected_slot()
	if slot.is_empty() or not ItemDB.is_seed(String(slot["id"])):
		return ""
	return ItemDB.flower_of(String(slot["id"]))


func is_actionable(_player: Node) -> bool:
	if not planted:
		var fl := _selected_seed()
		return fl != "" and GameState.is_unlocked(fl)
	if spent or progress >= 1.0:
		return true
	return water < 95.0 and _selected_can_charges() > 0


func get_prompt(_player: Node) -> String:
	if not planted:
		var fl := _selected_seed()
		if fl == "":
			return "Empty planter - select seeds"
		if not GameState.is_unlocked(fl):
			return "%s is locked" % String(FlowerDB.get_flower(fl).get("name", fl))
		var count := int(Inventory.selected_slot().get("count", 0))
		return "Plant %s (%d left)" % [String(FlowerDB.get_flower(fl).get("name", fl)), count]
	if spent:
		return "Clear spent plant"
	if progress >= 1.0:
		return "Harvest %s" % _flower_name()
	if _selected_can_charges() > 0 and water < 95.0:
		return "Water %s (%d%%)" % [_flower_name(), int(water)]
	if water <= 0.5:
		return "Dry - select the watering can"
	return ""


func interact(_player: Node) -> void:
	if not planted:
		var fl := _selected_seed()
		if fl == "":
			EventBus.notify("Select a seed packet in your hotbar")
			return
		if not GameState.is_unlocked(fl):
			EventBus.notify("%s unlocks at $%d earned" % [
				String(FlowerDB.get_flower(fl).get("name", fl)),
				int(FlowerDB.get_flower(fl).get("unlock_earned", 0)),
			])
			return
		if Inventory.consume_selected(1):
			_plant(fl)
		return
	if spent:
		_clear()
		return
	if progress >= 1.0:
		_harvest()
		return
	if water < 95.0 and _selected_can_charges() > 0:
		if Inventory.use_can_charge(Inventory.selected):
			water = 100.0
			_visual.set_water(water)
			_update_soil()
			EventBus.plant_changed.emit(self)
		return
	if water <= 0.5:
		EventBus.notify("Select the watering can (refill at the tap)")
	else:
		EventBus.notify("%s is still growing" % _flower_name())


func _plant(flower_id: String) -> void:
	planted = true
	spent = false
	species = flower_id
	progress = 0.0
	water = 100.0
	_last_stage = 0
	if _visual != null:
		_visual.queue_free()
	_visual = PlantVisual.new()
	_visual.position = Vector3(0, 0.33, 0)
	add_child(_visual)
	_visual.build(flower_id)
	_update_soil()
	_steady_markers()
	EventBus.plant_changed.emit(self)
	EventBus.notify("Planted %s" % _flower_name())


func restore(data: Dictionary) -> void:
	if not bool(data.get("planted", false)):
		_clear()
		return
	species = String(data.get("species", "daisy"))
	if FlowerDB.get_flower(species).is_empty():
		_clear()
		return
	planted = true
	spent = bool(data.get("spent", false))
	progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	water = clampf(float(data.get("water", 100.0)), 0.0, 100.0)
	if _visual != null:
		_visual.queue_free()
	_visual = PlantVisual.new()
	_visual.position = Vector3(0, 0.33, 0)
	add_child(_visual)
	_visual.build(species)
	_visual.update_growth(progress)
	_visual.set_water(water)
	if spent:
		_visual.set_spent()
	_last_stage = FlowerDB.growth_stage(progress)
	_update_soil()
	_steady_markers()
	EventBus.plant_changed.emit(self)


func to_data() -> Dictionary:
	return {
		"planted": planted,
		"species": species,
		"progress": progress,
		"water": water,
		"spent": spent,
	}


func _harvest() -> void:
	var f := FlowerDB.get_flower(species)
	var count := randi_range(int(f.get("yield_min", 1)), int(f.get("yield_max", 1)))
	var bloom := FlowerDB.bloom_item(species)
	var leftover := Inventory.add(bloom, count)
	if leftover > 0:
		ItemPickup.spawn(get_tree().current_scene, {
			"id": bloom,
			"count": leftover,
			"meta": {},
		}, global_position + Vector3(0.35, 0.55, 0.0))
		if leftover == count:
			EventBus.notify("Hands full - harvest dropped on the bench")
	GameState.plants_harvested += 1
	spent = true
	progress = 1.0
	if _visual:
		_visual.set_spent()
	_steady_markers()
	EventBus.plant_changed.emit(self)
	EventBus.notify("Harvested %d x %s" % [count - leftover, _flower_name()])


func _clear() -> void:
	if _visual != null:
		_visual.queue_free()
		_visual = null
	planted = false
	spent = false
	species = ""
	progress = 0.0
	water = 100.0
	_last_stage = -1
	_ready_glow.visible = false
	_dry_mark.visible = false
	_update_soil()
	EventBus.plant_changed.emit(self)


func get_info() -> Dictionary:
	if not planted:
		return {"empty": true}
	return {
		"empty": false,
		"flower": species,
		"name": _flower_name(),
		"stage": FlowerDB.stage_name(progress),
		"stage_index": FlowerDB.growth_stage(progress),
		"progress": progress,
		"time_left": FlowerDB.stage_time_left(species, progress),
		"water": water,
		"ready": progress >= 1.0,
		"spent": spent,
	}


func get_save_data() -> Dictionary:
	return {
		"index": pot_index,
		"planted": planted,
		"species": species,
		"progress": progress,
		"water": water,
		"spent": spent,
	}


func apply_save_data(data: Dictionary) -> void:
	if not bool(data.get("planted", false)):
		return
	_plant(String(data.get("species", "daisy")))
	progress = float(data.get("progress", 0.0))
	water = float(data.get("water", 100.0))
	spent = bool(data.get("spent", false))
	_last_stage = FlowerDB.growth_stage(progress)
	if _visual:
		_visual.update_growth(progress)
		if spent:
			_visual.set_spent()
	_update_soil()
	_steady_markers()
