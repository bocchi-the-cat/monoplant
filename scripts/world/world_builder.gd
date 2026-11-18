class_name WorldBuilder
extends Node3D
## Builds the greenhouse and the one city block entirely from primitives.
## Layout is hand-placed so the prototype stays functional and legible.

const GREENHOUSE_HALF_X := 6.12
const GREENHOUSE_HALF_Z := 5.13
const ROAD_Z := 16.0
const FRONTAGE_Z := 22.0

var pots: Array[PlantPot] = []


func _ready() -> void:
	add_to_group("world")
	_build_environment()
	_build_ground()
	_build_greenhouse()
	_build_street()
	_build_city()
	_build_park()
	_spawn_buyers()


# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = Palette.sky_material()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.72
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Palette.color("fog")
	env.fog_light_energy = 0.9
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-46, 155, 0)
	sun.light_color = Color("ffe9c9")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _no_shadow(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _glass_box(parent: Node, size: Vector3, pos: Vector3, collide := true) -> void:
	if collide:
		_no_shadow(Build.solid_box(parent, size, pos, Palette.glass()))
	else:
		_no_shadow(Build.box(parent, size, pos, Palette.glass()))


# --------------------------------------------------------------------------
# Ground, road, sidewalk
# --------------------------------------------------------------------------

func _build_ground() -> void:
	var g := Node3D.new()
	g.name = "Ground"
	add_child(g)
	Build.ground(g, Vector2(140, 140), Vector3.ZERO, Palette.textured("grass", 4.0, 0.12), "Lawn")

	# Greenhouse apron + entry path
	Build.box(g, Vector3(14.0, 0.04, 6.0), Vector3(0, 0.02, 8.0), Palette.mat("concrete"), Vector3.ZERO, "Apron")
	Build.box(g, Vector3(2.6, 0.05, 5.6), Vector3(0, 0.03, 12.8), Palette.mat("concrete"), Vector3.ZERO, "Path")

	# Road
	Build.solid_box(g, Vector3(96, 0.1, 8.0), Vector3(0, 0.05, ROAD_Z), Palette.textured("asphalt", 8.0, 0.2), Vector3.ZERO, "Road")
	Build.solid_box(g, Vector3(96, 0.16, 2.0), Vector3(0, 0.08, ROAD_Z - 5.0), Palette.textured("sidewalk", 6.0, 0.16), Vector3.ZERO, "SidewalkNear")
	Build.solid_box(g, Vector3(96, 0.16, 2.0), Vector3(0, 0.08, ROAD_Z + 5.0), Palette.textured("sidewalk", 6.0, 0.16), Vector3.ZERO, "SidewalkFar")
	Build.box(g, Vector3(96, 0.1, 0.22), Vector3(0, 0.17, ROAD_Z - 6.05), Palette.mat("curb"), Vector3.ZERO, "CurbNear")
	Build.box(g, Vector3(96, 0.1, 0.22), Vector3(0, 0.17, ROAD_Z + 6.05), Palette.mat("curb"), Vector3.ZERO, "CurbFar")

	# Centre dashes
	for i in 16:
		var x := -60.0 + float(i) * 8.0
		Build.box(g, Vector3(3.2, 0.02, 0.16), Vector3(x, 0.11, ROAD_Z), Palette.flat(Color("d8d2c0"), 0.8), Vector3.ZERO, "LaneDash")

	# Crosswalk in front of the greenhouse
	for i in 7:
		Build.box(g, Vector3(0.62, 0.02, 4.2), Vector3(-1.9 + float(i) * 0.63, 0.115, ROAD_Z), Palette.flat(Color("cfc9b8"), 0.85), Vector3.ZERO, "Zebra")

	# Parking bays
	for i in 5:
		Build.box(g, Vector3(0.12, 0.02, 4.0), Vector3(10.0 + float(i) * 3.4, 0.11, ROAD_Z + 2.6), Palette.flat(Color("cfc9b8"), 0.9), Vector3.ZERO, "BayLine")


# --------------------------------------------------------------------------
# Greenhouse
# --------------------------------------------------------------------------

func _build_greenhouse() -> void:
	var b := Node3D.new()
	b.name = "Greenhouse"
	add_child(b)

	# Floor slab
	Build.solid_box(b, Vector3(12.2, 0.12, 10.2), Vector3(0, -0.04, 0), Palette.textured("floor_tile", 5.0, 0.14), Vector3.ZERO, "Floor")
	Build.box(b, Vector3(12.0, 0.02, 10.0), Vector3(0, 0.03, 0), Palette.textured("floor_tile", 9.0, 0.1), Vector3.ZERO, "FloorTop")

	# --- base walls (0 - 1m) ---
	Build.solid_box(b, Vector3(12.6, 1.0, 0.26), Vector3(0, 0.5, -GREENHOUSE_HALF_Z), Palette.textured("brick_pale", 4.0, 0.14), Vector3.ZERO, "WallBackBase")
	Build.solid_box(b, Vector3(0.26, 1.0, 10.5), Vector3(-GREENHOUSE_HALF_X, 0.5, 0), Palette.textured("brick_pale", 4.0, 0.14), Vector3.ZERO, "WallLeftBase")
	Build.solid_box(b, Vector3(0.26, 1.0, 10.5), Vector3(GREENHOUSE_HALF_X, 0.5, 0), Palette.textured("brick_pale", 4.0, 0.14), Vector3.ZERO, "WallRightBase")

	# Front base with a 2.3m door gap
	Build.solid_box(b, Vector3(5.0, 1.0, 0.26), Vector3(-3.7, 0.5, GREENHOUSE_HALF_Z), Palette.textured("brick_pale", 4.0, 0.14), Vector3.ZERO, "WallFrontBaseL")
	Build.solid_box(b, Vector3(5.0, 1.0, 0.26), Vector3(3.7, 0.5, GREENHOUSE_HALF_Z), Palette.textured("brick_pale", 4.0, 0.14), Vector3.ZERO, "WallFrontBaseR")

	# --- glass above ---
	_glass_box(b, Vector3(12.4, 2.2, 0.08), Vector3(0, 2.1, -GREENHOUSE_HALF_Z))
	_glass_box(b, Vector3(0.08, 2.2, 10.2), Vector3(-GREENHOUSE_HALF_X, 2.1, 0))
	_glass_box(b, Vector3(0.08, 2.2, 10.2), Vector3(GREENHOUSE_HALF_X, 2.1, 0))
	_glass_box(b, Vector3(5.0, 2.2, 0.08), Vector3(-3.7, 2.1, GREENHOUSE_HALF_Z))
	_glass_box(b, Vector3(5.0, 2.2, 0.08), Vector3(3.7, 2.1, GREENHOUSE_HALF_Z))
	_glass_box(b, Vector3(2.4, 0.8, 0.08), Vector3(0, 2.8, GREENHOUSE_HALF_Z))

	# --- frame ---
	var frame := Palette.mat("metal_dark")
	for x in [-GREENHOUSE_HALF_X, -3.06, 3.06, GREENHOUSE_HALF_X]:
		for z in [-GREENHOUSE_HALF_Z, GREENHOUSE_HALF_Z]:
			Build.box(b, Vector3(0.16, 3.3, 0.16), Vector3(x, 1.65, z), frame, Vector3.ZERO, "Post")
	for z in [-GREENHOUSE_HALF_Z, 0.0, GREENHOUSE_HALF_Z]:
		for x in [-GREENHOUSE_HALF_X, GREENHOUSE_HALF_X]:
			Build.box(b, Vector3(0.16, 3.3, 0.16), Vector3(x, 1.65, z), frame, Vector3.ZERO, "Post")
	# horizontal rails
	Build.box(b, Vector3(12.5, 0.14, 0.18), Vector3(0, 1.02, -GREENHOUSE_HALF_Z), frame)
	Build.box(b, Vector3(12.5, 0.14, 0.18), Vector3(0, 1.02, GREENHOUSE_HALF_Z), frame)
	Build.box(b, Vector3(0.18, 0.14, 10.4), Vector3(-GREENHOUSE_HALF_X, 1.02, 0), frame)
	Build.box(b, Vector3(0.18, 0.14, 10.4), Vector3(GREENHOUSE_HALF_X, 1.02, 0), frame)
	# top beams
	Build.box(b, Vector3(12.5, 0.16, 0.22), Vector3(0, 3.18, -GREENHOUSE_HALF_Z), frame)
	Build.box(b, Vector3(12.5, 0.16, 0.22), Vector3(0, 3.18, GREENHOUSE_HALF_Z), frame)
	Build.box(b, Vector3(0.22, 0.16, 10.6), Vector3(-GREENHOUSE_HALF_X, 3.18, 0), frame)
	Build.box(b, Vector3(0.22, 0.16, 10.6), Vector3(GREENHOUSE_HALF_X, 3.18, 0), frame)

	# door frame
	Build.box(b, Vector3(0.16, 2.45, 0.2), Vector3(-1.2, 1.22, GREENHOUSE_HALF_Z), frame)
	Build.box(b, Vector3(0.16, 2.45, 0.2), Vector3(1.2, 1.22, GREENHOUSE_HALF_Z), frame)
	Build.box(b, Vector3(2.56, 0.18, 0.2), Vector3(0, 2.42, GREENHOUSE_HALF_Z), frame)
	# door leaf, propped open
	Build.box(b, Vector3(1.1, 2.3, 0.09), Vector3(1.78, 1.15, 5.82), Palette.mat("wood"), Vector3(0, deg_to_rad(-52), 0), "OpenDoor")

	# --- roof ---
	# Perimeter trim only: a full slab would black out the skylight.
	Build.box(b, Vector3(12.5, 0.16, 0.3), Vector3(0, 3.32, -GREENHOUSE_HALF_Z), Palette.mat("metal_dark"), Vector3.ZERO, "RoofTrimBack")
	Build.box(b, Vector3(12.5, 0.16, 0.3), Vector3(0, 3.32, GREENHOUSE_HALF_Z), Palette.mat("metal_dark"), Vector3.ZERO, "RoofTrimFront")
	Build.box(b, Vector3(0.3, 0.16, 10.4), Vector3(-GREENHOUSE_HALF_X, 3.32, 0), Palette.mat("metal_dark"), Vector3.ZERO, "RoofTrimLeft")
	Build.box(b, Vector3(0.3, 0.16, 10.4), Vector3(GREENHOUSE_HALF_X, 3.32, 0), Palette.mat("metal_dark"), Vector3.ZERO, "RoofTrimRight")
	_glass_box(b, Vector3(12.3, 0.05, 10.2), Vector3(0, 3.36, 0), false)
	for z in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		Build.box(b, Vector3(12.4, 0.1, 0.12), Vector3(0, 3.34, z), frame, Vector3.ZERO, "RoofBeam")
	Build.box(b, Vector3(0.12, 0.12, 10.3), Vector3(0, 3.4, 0), frame, Vector3.ZERO, "Ridge")
	# roof vent
	Build.solid_box(b, Vector3(1.3, 0.34, 1.3), Vector3(0, 3.6, -1.2), Palette.mat("metal"), Vector3.ZERO, "RoofVent")

	# --- benches ---
	for sx in [-1.0, 1.0]:
		var bx: float = 3.2 * float(sx)
		Build.solid_box(b, Vector3(3.7, 0.12, 1.0), Vector3(bx, 0.88, -3.3), Palette.mat("wood"), Vector3.ZERO, "BenchTop")
		for lx in [-1.6, 1.6]:
			for lz in [-0.38, 0.38]:
				Build.box(b, Vector3(0.1, 0.88, 0.1), Vector3(bx + lx, 0.44, -3.3 + lz), Palette.mat("wood_dark"))
		Build.box(b, Vector3(3.6, 0.06, 0.9), Vector3(bx, 0.42, -3.3), Palette.mat("wood_dark"))

	# --- pots ---
	var idx := 0
	for sx in [-1.0, 1.0]:
		for i in 3:
			var pos := Vector3(3.2 * sx + (float(i) - 1.0), 0.94, -3.3)
			_spawn_pot(pos, idx)
			idx += 1

	# --- fixtures ---
	var counter := ShopCounter.new()
	counter.position = Vector3(5.35, 0.03, 1.5)
	add_child(counter)

	var tap := WaterTap.new()
	tap.position = Vector3(-5.35, 0.03, -3.6)
	add_child(tap)

	# Packing bench (order packing comes online with the board)
	Build.solid_box(b, Vector3(0.9, 0.95, 2.2), Vector3(-5.35, 0.48, 2.2), Palette.mat("wood_dark"), Vector3.ZERO, "PackBench")
	Build.box(b, Vector3(1.02, 0.08, 2.32), Vector3(-5.35, 0.99, 2.2), Palette.mat("wood_pale"))
	Build.box(b, Vector3(0.5, 0.3, 0.5), Vector3(-5.35, 1.18, 1.5), Palette.mat("box_cardboard"))
	Build.box(b, Vector3(0.4, 0.02, 0.5), Vector3(-5.35, 1.34, 1.5), Palette.mat("seed_packet"))
	var pack_station := PackingStation.new()
	pack_station.position = Vector3(-5.35, 0.03, 2.2)
	add_child(pack_station)

	# Notice board (interactable) on a brick pier so it isn't hung on glass.
	Build.solid_box(b, Vector3(0.3, 2.6, 2.3), Vector3(-6.0, 1.3, 0.2), Palette.textured("brick_pale", 3.0, 0.12), Vector3.ZERO, "BoardPier")
	Build.solid_box(b, Vector3(0.1, 1.15, 1.5), Vector3(-5.82, 1.85, 0.2), Palette.mat("wood_dark"), Vector3.ZERO, "BoardFrame")
	for i in 3:
		Build.box(b, Vector3(0.02, 0.3, 0.38), Vector3(-5.75, 2.1 - float(i % 2) * 0.42, -0.25 + float(i) * 0.4), Palette.flat(Color("efe9d8"), 0.85), Vector3(0, 0, deg_to_rad(-3.0 + float(i) * 3.0)))
	Build.label(b, "ORDERS", Vector3(-5.72, 2.6, 0.2), 44, Palette.color("ui_text"), 0.0042)
	var board := OrderBoard.new()
	board.position = Vector3(-5.7, 1.62, 0.2)
	add_child(board)

	# Grow lights
	for x in [-3.2, 3.2]:
		Build.box(b, Vector3(2.6, 0.1, 0.3), Vector3(x, 2.95, -3.3), Palette.glow("grow_light", 1.6), Vector3.ZERO, "GrowTube")
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 2.85, -3.3)
		lamp.light_color = Palette.color("grow_light")
		lamp.light_energy = 2.2
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		b.add_child(lamp)

	# warm fill for the shop side
	var fill := OmniLight3D.new()
	fill.position = Vector3(3.6, 2.7, 2.4)
	fill.light_color = Palette.color("lamp_warm")
	fill.light_energy = 1.3
	fill.omni_range = 8.0
	b.add_child(fill)

	# --- interior dressing ---
	_build_greenhouse_props(b)

	# Entrance sign
	Build.box(b, Vector3(3.4, 0.7, 0.12), Vector3(0, 3.78, 5.26), Palette.mat("wood_dark"), Vector3.ZERO, "SignBoard")
	Build.label(b, "PETAL & PROFIT", Vector3(0, 3.78, 5.34), 34, Palette.color("ui_accent"), 0.004)

	# Hanging pots
	for x in [-5.2, 5.2]:
		for z in [-1.2, 4.0]:
			Build.cylinder(b, 0.02, 0.02, 0.5, Vector3(x, 2.95, z), Palette.mat("metal_dark"), 4)
			Build.cylinder(b, 0.13, 0.1, 0.22, Vector3(x, 2.6, z), Palette.mat("pot"), 8)
			Build.sphere(b, 0.16, Vector3(x, 2.72, z), Palette.mat("leaf_light"))


func _spawn_pot(pos: Vector3, index: int) -> void:
	var pot := PlantPot.new()
	pot.pot_index = index
	pot.position = pos
	add_child(pot)
	pots.append(pot)


func _build_greenhouse_props(b: Node3D) -> void:
	# Soil bags
	for i in 3:
		Build.box(b, Vector3(0.5, 0.36, 0.34), Vector3(-4.4 + float(i) * 0.55, 0.2, -4.5), Palette.mat("box_cardboard"), Vector3(0, float(i) * 0.3, 0), "SoilBag")
	# Crates
	Build.solid_box(b, Vector3(0.7, 0.7, 0.7), Vector3(4.6, 0.36, -4.5), Palette.mat("wood_pale"), Vector3.ZERO, "Crate")
	Build.box(b, Vector3(0.72, 0.06, 0.72), Vector3(4.6, 0.72, -4.5), Palette.mat("wood_dark"))
	# Shelf with seed packets on the back wall
	Build.box(b, Vector3(4.6, 0.08, 0.4), Vector3(-2.4, 1.7, -4.95), Palette.mat("wood"))
	Build.box(b, Vector3(4.6, 0.08, 0.4), Vector3(-2.4, 2.2, -4.95), Palette.mat("wood"))
	for i in 6:
		Build.box(b, Vector3(0.26, 0.34, 0.18), Vector3(-4.2 + float(i) * 0.72, 1.92, -4.95), Palette.mat("seed_packet"), Vector3(0, 0.2 * float(i), 0))
	# Stool + broom
	Build.cylinder(b, 0.2, 0.18, 0.55, Vector3(2.0, 0.3, 3.8), Palette.mat("wood"), 8, "Stool")
	Build.cylinder(b, 0.02, 0.02, 1.4, Vector3(5.6, 0.72, -4.3), Palette.mat("wood_dark"), 5, "BroomHandle")
	# Buckets
	for i in 2:
		Build.cylinder(b, 0.17, 0.15, 0.3, Vector3(5.0 - float(i) * 0.42, 0.18, -2.2), Palette.mat("can_metal"), 10, "Bucket")
	# Rug at the entrance
	Build.box(b, Vector3(1.9, 0.015, 1.0), Vector3(0, 0.045, 4.3), Palette.flat(Color("7a5c4a"), 1.0), Vector3.ZERO, "Mat")
	# Wall clock
	# Wall clock, face turned into the room
	var clock := Build.cylinder(b, 0.24, 0.24, 0.05, Vector3(2.7, 2.4, -5.02), Palette.mat("trim"), 12, "Clock")
	clock.rotation_degrees.x = 90.0
	var clock_face := Build.cylinder(b, 0.21, 0.21, 0.03, Vector3(2.7, 2.4, -4.985), Palette.flat(Color("efe9d8"), 0.9), 12, "ClockFace")
	clock_face.rotation_degrees.x = 90.0


# --------------------------------------------------------------------------
# Street furniture
# --------------------------------------------------------------------------

func _build_street() -> void:
	var s := Node3D.new()
	s.name = "Street"
	add_child(s)

	for i in 2:
		_street_lamp(s, Vector3(-14.0 + float(i) * 21.0, 0.16, ROAD_Z - 5.4), true)
	for i in 2:
		_street_lamp(s, Vector3(-7.0 + float(i) * 21.0, 0.16, ROAD_Z + 5.4), false)

	# Bins, hydrant, planters
	Build.solid_box(s, Vector3(0.7, 1.05, 0.7), Vector3(-7.4, 0.68, ROAD_Z - 4.6), Palette.mat("metal_dark"), Vector3.ZERO, "Bin")
	Build.box(s, Vector3(0.78, 0.1, 0.78), Vector3(-7.4, 1.22, ROAD_Z - 4.6), Palette.mat("metal"))
	Build.solid_box(s, Vector3(0.34, 0.8, 0.34), Vector3(6.8, 0.55, ROAD_Z - 4.7), Palette.mat("flower_red"), Vector3.ZERO, "Hydrant")
	Build.sphere(s, 0.19, Vector3(6.8, 0.95, ROAD_Z - 4.7), Palette.mat("flower_red"))
	for i in 3:
		var x := 2.6 + float(i) * 2.2
		Build.solid_box(s, Vector3(1.0, 0.55, 1.0), Vector3(x, 0.43, ROAD_Z + 4.6), Palette.mat("concrete"), Vector3.ZERO, "Planter")
		Build.box(s, Vector3(0.9, 0.06, 0.9), Vector3(x, 0.72, ROAD_Z + 4.6), Palette.mat("soil"))
		Build.sphere(s, 0.28, Vector3(x, 0.88, ROAD_Z + 4.6), Palette.mat("leaf_light"))

	# Parked car (very low poly, reads as a car from a distance)
	_build_car(s, Vector3(11.0, 0.16, ROAD_Z + 2.6), Color("58708a"))
	_build_car(s, Vector3(-9.6, 0.16, ROAD_Z - 2.6), Color("8c5a4a"))

	# Bus stop
	Build.solid_box(s, Vector3(3.0, 0.1, 1.4), Vector3(-16.0, 3.0, ROAD_Z - 4.9), Palette.mat("metal_dark"), Vector3.ZERO, "ShelterRoof")
	Build.box(s, Vector3(0.1, 2.9, 0.1), Vector3(-17.4, 1.55, ROAD_Z - 4.5), Palette.mat("metal_dark"))
	Build.box(s, Vector3(0.1, 2.9, 0.1), Vector3(-14.6, 1.55, ROAD_Z - 4.5), Palette.mat("metal_dark"))
	Build.label(s, "BUS", Vector3(-16.0, 2.5, ROAD_Z - 5.02), 26, Palette.color("ui_accent"), 0.0035)


func _street_lamp(parent: Node3D, pos: Vector3, with_light: bool) -> void:
	Build.cylinder(parent, 0.06, 0.09, 5.0, pos + Vector3(0, 2.5, 0), Palette.mat("metal_dark"), 8, "LampPole")
	Build.box(parent, Vector3(0.9, 0.08, 0.08), pos + Vector3(0.45, 5.0, 0), Palette.mat("metal_dark"))
	Build.sphere(parent, 0.17, pos + Vector3(0.9, 4.92, 0), Palette.glow("lamp_warm", 1.5), "LampBulb")
	if with_light:
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0.9, 4.8, 0)
		light.light_color = Palette.color("lamp_warm")
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.shadow_enabled = false
		parent.add_child(light)


func _build_car(parent: Node3D, pos: Vector3, color: Color) -> void:
	Build.solid_box(parent, Vector3(4.2, 0.7, 1.9), pos + Vector3(0, 0.55, 0), Palette.flat(color, 0.55, 0.35), Vector3.ZERO, "CarBody")
	Build.box(parent, Vector3(2.2, 0.6, 1.7), pos + Vector3(-0.2, 1.15, 0), Palette.flat(color.darkened(0.15), 0.4, 0.4), Vector3.ZERO, "CarCabin")
	Build.box(parent, Vector3(1.9, 0.42, 1.62), pos + Vector3(-0.2, 1.18, 0), Palette.mat("glass_dark"), Vector3.ZERO, "CarGlass")
	for sx in [-1.3, 1.3]:
		for sz in [-0.95, 0.95]:
			var wheel := Build.cylinder(parent, 0.34, 0.34, 0.24, pos + Vector3(sx, 0.34, sz), Palette.flat(Color("1c1d20"), 0.95), 10, "Wheel")
			wheel.rotation_degrees = Vector3(0, 0, 90)
	Build.box(parent, Vector3(0.1, 0.22, 0.5), pos + Vector3(2.1, 0.6, 0.6), Palette.glow("lamp_warm", 1.0))


# --------------------------------------------------------------------------
# City facades
# --------------------------------------------------------------------------

func _build_city() -> void:
	var c := Node3D.new()
	c.name = "City"
	add_child(c)

	_facade(c, -14.0, 10.0, 8.6, 8.0, "stucco_warm", -2.6, "12", "brick")
	_facade(c, 0.5, 11.0, 9.4, 8.0, "brick", 0.0, "14", "stucco_green")
	_facade(c, 14.5, 9.0, 7.4, 8.0, "stucco_green", 2.2, "16", "brick")

	# Supply store block, further down the street
	_storefront(c, Vector3(-27.0, 0, FRONTAGE_Z + 4.0), "FLORA & FEED")

	# Alley walls between the two first facades
	Build.solid_box(c, Vector3(0.5, 5.0, 8.0), Vector3(-7.6, 2.5, FRONTAGE_Z + 4.0), Palette.textured("brick_dark", 4.0, 0.16), Vector3.ZERO, "AlleyWall")
	Build.solid_box(c, Vector3(0.5, 5.0, 8.0), Vector3(6.0, 2.5, FRONTAGE_Z + 4.0), Palette.textured("brick_dark", 4.0, 0.16), Vector3.ZERO, "AlleyWall2")


func _facade(parent: Node3D, x: float, width: float, height: float, depth: float, wall_key: String, door_x: float, number_text: String, awning_key: String) -> void:
	var front := FRONTAGE_Z
	var center_z := front + depth * 0.5
	Build.solid_box(parent, Vector3(width, height, depth), Vector3(x, height * 0.5, center_z), Palette.textured(wall_key, 3.0, 0.09), Vector3.ZERO, "House")
	Build.solid_box(parent, Vector3(width + 0.6, 0.5, depth + 0.6), Vector3(x, height + 0.2, center_z), Palette.mat("roof"), Vector3.ZERO, "Roof")
	# cornice
	Build.box(parent, Vector3(width + 0.3, 0.18, 0.18), Vector3(x, height - 0.2, front - 0.08), Palette.mat("trim"))

	var columns := [-0.28, 0.0, 0.28]
	for floor in 2:
		for col in columns:
			var wx: float = x + width * float(col)
			if floor == 0 and absf(wx - (x + door_x)) < 1.6:
				continue
			var wy := 2.35 + float(floor) * 2.9
			Build.box(parent, Vector3(1.5, 1.7, 0.09), Vector3(wx, wy, front - 0.04), Palette.mat("glass_dark"), Vector3.ZERO, "Window")
			Build.box(parent, Vector3(1.72, 0.12, 0.16), Vector3(wx, wy + 0.9, front - 0.07), Palette.mat("trim"))
			Build.box(parent, Vector3(1.72, 0.12, 0.16), Vector3(wx, wy - 0.9, front - 0.07), Palette.mat("trim"))
			Build.box(parent, Vector3(0.12, 1.9, 0.16), Vector3(wx - 0.8, wy, front - 0.07), Palette.mat("trim"))
			Build.box(parent, Vector3(0.12, 1.9, 0.16), Vector3(wx + 0.8, wy, front - 0.07), Palette.mat("trim"))
			if floor == 0 and col == 0.28:
				Build.box(parent, Vector3(1.5, 0.28, 0.34), Vector3(wx, wy - 0.95, front - 0.2), Palette.mat("wood_dark"), Vector3.ZERO, "WindowBox")
				for i in 3:
					Build.sphere(parent, 0.1, Vector3(wx - 0.45 + float(i) * 0.45, wy - 0.79, front - 0.2), Palette.mat("flower_pink" if i % 2 == 0 else "flower_white"))

	# Door and stoop
	var dx := x + door_x
	Build.box(parent, Vector3(1.35, 2.5, 0.12), Vector3(dx, 1.25, front - 0.05), Palette.mat("wood_dark"), Vector3.ZERO, "Door")
	Build.box(parent, Vector3(0.1, 0.1, 0.06), Vector3(dx + 0.45, 1.2, front - 0.12), Palette.mat("metal"), Vector3.ZERO, "Handle")
	Build.box(parent, Vector3(1.9, 0.16, 0.16), Vector3(dx, 2.6, front - 0.09), Palette.mat("trim"))
	Build.solid_box(parent, Vector3(2.2, 0.32, 1.2), Vector3(dx, 0.16, front - 0.7), Palette.mat("concrete"), Vector3.ZERO, "Stoop")
	Build.box(parent, Vector3(2.5, 0.12, 1.1), Vector3(dx, 3.0, front - 0.6), Palette.mat(awning_key), Vector3(deg_to_rad(-8.0), 0, 0), "Awning")
	Build.label(parent, number_text, Vector3(dx, 3.6, front - 0.42), 30, Palette.color("ui_text"), 0.004)

	# Lamp beside the door, AC unit and drainpipe
	Build.box(parent, Vector3(0.14, 0.2, 0.2), Vector3(dx + 1.0, 2.4, front - 0.12), Palette.glow("lamp_warm", 1.2), Vector3.ZERO, "PorchLamp")
	Build.solid_box(parent, Vector3(0.9, 0.7, 0.5), Vector3(x + width * 0.34, 3.9, front - 0.27), Palette.mat("metal"), Vector3.ZERO, "AC")
	Build.cylinder(parent, 0.06, 0.06, height, Vector3(x + width * 0.45, height * 0.5, front - 0.12), Palette.mat("metal_dark"), 6, "Drainpipe")
	# Trash bin on the stoop
	Build.solid_box(parent, Vector3(0.45, 0.75, 0.45), Vector3(dx - 1.24, 0.5, front - 0.5), Palette.mat("metal_dark"), Vector3.ZERO, "Bin")


func _storefront(parent: Node3D, pos: Vector3, title: String) -> void:
	var front := FRONTAGE_Z
	Build.solid_box(parent, Vector3(14.0, 6.2, 8.0), Vector3(pos.x, 3.1, pos.z + 0.0), Palette.textured("brick", 4.0, 0.12), Vector3.ZERO, "Store")
	Build.solid_box(parent, Vector3(14.6, 0.5, 8.6), Vector3(pos.x, 6.4, pos.z), Palette.mat("roof"), Vector3.ZERO, "StoreRoof")
	# big display windows
	for i in 2:
		var wx := pos.x - 3.2 + float(i) * 4.4
		Build.box(parent, Vector3(3.2, 2.2, 0.1), Vector3(wx, 1.6, front - 0.02), Palette.mat("glass_dark"), Vector3.ZERO, "StoreWindow")
		Build.box(parent, Vector3(3.4, 0.14, 0.18), Vector3(wx, 2.75, front - 0.05), Palette.mat("wood_dark"))
	# door
	Build.box(parent, Vector3(1.6, 2.5, 0.12), Vector3(pos.x, 1.25, front - 0.03), Palette.mat("glass_dark"), Vector3.ZERO, "StoreDoor")
	Build.box(parent, Vector3(1.8, 0.16, 0.16), Vector3(pos.x, 2.6, front - 0.06), Palette.mat("wood_dark"))
	# sign
	Build.box(parent, Vector3(7.0, 1.0, 0.18), Vector3(pos.x, 4.4, front - 0.06), Palette.mat("wood_dark"), Vector3.ZERO, "StoreSign")
	Build.label(parent, title, Vector3(pos.x, 4.4, front - 0.3), 46, Palette.color("neon_teal"), 0.0055)
	# awning stripes
	for i in 5:
		Build.box(parent, Vector3(2.6, 0.1, 1.2), Vector3(pos.x - 5.2 + float(i) * 2.6, 3.4, front - 0.5), Palette.mat("neon_teal" if i % 2 == 0 else "ui_panel"), Vector3(deg_to_rad(-10.0), 0, 0), "AwningStripe")
	Build.solid_box(parent, Vector3(2.4, 0.3, 1.2), Vector3(pos.x, 0.15, front - 0.6), Palette.mat("concrete"), Vector3.ZERO, "StoreStep")


# --------------------------------------------------------------------------
# Park
# --------------------------------------------------------------------------

func _build_park() -> void:
	var p := Node3D.new()
	p.name = "Park"
	add_child(p)

	# Sits on the far side of the road, east of the row of houses.
	Build.ground(p, Vector2(16.0, 13.0), Vector3(28.0, 0.02, 28.5), Palette.textured("grass_pale", 4.0, 0.1), "ParkLawn")
	# low wall along part of the street side, leaving the east end open to walk in
	for i in 3:
		Build.solid_box(p, Vector3(1.8, 0.5, 0.35), Vector3(21.5 + float(i) * 2.0, 0.27, 22.2), Palette.mat("brick_pale"), Vector3.ZERO, "ParkWall")

	_tree(p, Vector3(22.5, 0.02, 25.0), 1.0)
	_tree(p, Vector3(32.0, 0.02, 25.6), 1.25)
	_tree(p, Vector3(25.5, 0.02, 32.0), 0.9)
	_tree(p, Vector3(33.0, 0.02, 31.5), 1.1)

	_bench(p, Vector3(25.0, 0.02, 27.0), 0.0)
	_bench(p, Vector3(30.0, 0.02, 29.4), PI * 0.5)

	# Fountain-ish centrepiece
	Build.cylinder(p, 1.5, 1.5, 0.35, Vector3(28.5, 0.2, 28.5), Palette.mat("concrete"), 12, "Basin")
	Build.cylinder(p, 1.35, 1.35, 0.1, Vector3(28.5, 0.36, 28.5), Palette.flat(Color("5f7d86"), 0.2, 0.3), 12, "Water")
	Build.cylinder(p, 0.35, 0.5, 1.2, Vector3(28.5, 0.9, 28.5), Palette.mat("concrete"), 8, "Plinth")

	# Picnic table
	Build.solid_box(p, Vector3(2.2, 0.12, 1.0), Vector3(34.0, 0.78, 33.0), Palette.mat("wood"), Vector3.ZERO, "PicnicTop")
	for lx in [-0.85, 0.85]:
		for lz in [-0.42, 0.42]:
			Build.box(p, Vector3(0.1, 0.78, 0.1), Vector3(34.0 + lx, 0.39, 33.0 + lz), Palette.mat("wood_dark"))


func _tree(parent: Node3D, pos: Vector3, scale_factor: float) -> void:
	Build.cylinder(parent, 0.14 * scale_factor, 0.22 * scale_factor, 2.6 * scale_factor, pos + Vector3(0, 1.3 * scale_factor, 0), Palette.mat("trunk"), 7, "Trunk")
	Build.sphere(parent, 1.15 * scale_factor, pos + Vector3(0, 3.0 * scale_factor, 0), Palette.mat("leaf"), "Canopy")
	Build.sphere(parent, 0.85 * scale_factor, pos + Vector3(0.7 * scale_factor, 3.5 * scale_factor, 0.3 * scale_factor), Palette.mat("leaf_light"), "Canopy")
	Build.sphere(parent, 0.75 * scale_factor, pos + Vector3(-0.6 * scale_factor, 3.3 * scale_factor, -0.4 * scale_factor), Palette.mat("leaf_dark"), "Canopy")


func _bench(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	Build.solid_box(holder, Vector3(1.9, 0.1, 0.55), Vector3(0, 0.48, 0), Palette.mat("wood"), Vector3.ZERO, "BenchSeat")
	Build.box(holder, Vector3(1.9, 0.5, 0.09), Vector3(0, 0.75, -0.24), Palette.mat("wood"), Vector3(deg_to_rad(-8.0), 0, 0), "BenchBack")
	for lx in [-0.8, 0.8]:
		Build.box(holder, Vector3(0.1, 0.48, 0.5), Vector3(lx, 0.24, 0), Palette.mat("metal_dark"))


# --------------------------------------------------------------------------
# Buyers
# --------------------------------------------------------------------------

func _spawn_buyers() -> void:
	var holder := Node3D.new()
	holder.name = "Buyers"
	add_child(holder)
	for id in CustomerDB.all_ids():
		var c := CustomerDB.get_customer(String(id))
		var buyer := Buyer.new()
		buyer.customer_id = String(id)
		buyer.position = c.get("pos", Vector3.ZERO)
		buyer.rotation.y = deg_to_rad(float(c.get("yaw", 0.0)))
		buyer.name = "Buyer_" + String(id)
		holder.add_child(buyer)
