class_name PlantVisual
extends Node3D
## Procedural low-poly plant. One builder for every species; the flower table
## drives petal count, colours, height and bloom style.

var species_id := ""
var data: Dictionary = {}

var _stem: MeshInstance3D
var _leaves: Array[MeshInstance3D] = []
var _bloom: Node3D
var _bloom_center: MeshInstance3D
var _stem_mat: StandardMaterial3D
var _time := 0.0
var _phase := 0.0
var _water := 100.0
var _growth := 0.0
var _spent := false


func build(id: String) -> void:
	species_id = id
	data = FlowerDB.get_flower(id)
	_phase = randf() * TAU
	_stem_mat = Palette.flat(Palette.color("stem"), 0.9)

	_stem = MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.02
	stem_mesh.bottom_radius = 0.031
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 5
	stem_mesh.rings = 1
	_stem.mesh = stem_mesh
	_stem.material_override = _stem_mat
	add_child(_stem)

	var leaf_mat := Palette.mat("leaf")
	for i in 5:
		var leaf := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.095
		lm.height = 0.022
		lm.radial_segments = 6
		lm.rings = 3
		leaf.mesh = lm
		leaf.material_override = leaf_mat
		var side := 1.0 if i % 2 == 0 else -1.0
		leaf.rotation = Vector3(0.0, deg_to_rad(26.0 if side > 0 else -26.0), deg_to_rad(-30.0 * side))
		leaf.scale = Vector3(1.0, 1.0, 0.62)
		add_child(leaf)
		_leaves.append(leaf)

	_bloom = Node3D.new()
	add_child(_bloom)

	var petal_count := int(data.get("petal_count", 8))
	var bloom_size := float(data.get("bloom_size", 0.08))
	var petal_mat := Palette.mat(String(data.get("bloom_color", "flower_white")))
	var style := String(data.get("style", "ring"))

	for i in petal_count:
		var petal := MeshInstance3D.new()
		var pm := BoxMesh.new()
		match style:
			"bell":
				pm.size = Vector3(bloom_size * 0.55, bloom_size * 1.15, bloom_size * 0.22)
			"cluster":
				pm.size = Vector3(bloom_size * 0.7, bloom_size * 0.9, bloom_size * 0.3)
			_:
				pm.size = Vector3(bloom_size * 1.0, bloom_size * 0.2, bloom_size * 0.45)
		petal.mesh = pm
		petal.material_override = petal_mat
		var a := TAU * float(i) / float(petal_count)
		var radius := bloom_size * 0.55
		match style:
			"bell":
				petal.position = Vector3(cos(a) * radius * 0.7, bloom_size * 0.5, sin(a) * radius * 0.7)
				petal.rotation = Vector3(cos(a) * deg_to_rad(-12.0), -a, sin(a) * deg_to_rad(12.0))
			"cluster":
				petal.position = Vector3(cos(a) * radius * 0.45, bloom_size * 0.35 + float(i % 3) * bloom_size * 0.16, sin(a) * radius * 0.45)
				petal.rotation = Vector3(deg_to_rad(20.0), -a, deg_to_rad(-20.0))
			_:
				petal.position = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
				petal.rotation = Vector3(cos(a) * deg_to_rad(10.0), -a, sin(a) * deg_to_rad(10.0))
		_bloom.add_child(petal)

	_bloom_center = MeshInstance3D.new()
	var cm := SphereMesh.new()
	var center_radius := bloom_size * (0.55 if petal_count > 10 else 0.34)
	cm.radius = center_radius
	cm.height = center_radius * 2.0
	cm.radial_segments = 8
	cm.rings = 4
	_bloom_center.mesh = cm
	_bloom_center.material_override = Palette.mat(String(data.get("center_color", "flower_yellow")))
	_bloom_center.position.y = bloom_size * (0.18 if style == "cluster" else 0.05)
	_bloom.add_child(_bloom_center)

	update_growth(0.0)
	set_process(true)


func update_growth(t: float) -> void:
	_growth = clampf(t, 0.0, 1.0)
	var full_height := float(data.get("stem_height", 0.5))
	var h := full_height * clampf(0.06 + _growth * 0.94, 0.02, 1.0)
	h = full_height * pow(_growth, 0.55)

	_stem.visible = _growth > 0.01
	_stem.scale = Vector3(1.0, maxf(h, 0.02), 1.0)
	_stem.position.y = h * 0.5

	for i in _leaves.size():
		var leaf := _leaves[i]
		var gate := 0.1 + float(i) * 0.075
		var local := clampf((_growth - gate) / 0.12, 0.0, 1.0)
		leaf.visible = local > 0.01
		leaf.scale = Vector3(1.0, 1.0, 0.62) * maxf(local, 0.001)
		var side := 1.0 if i % 2 == 0 else -1.0
		leaf.position = Vector3(side * 0.105 * local, h * (0.26 + float(i) * 0.14), 0.0)

	var bloom_scale := clampf((_growth - 0.62) / 0.38, 0.0, 1.0)
	_bloom.visible = bloom_scale > 0.01 and not _spent
	_bloom.position.y = h + 0.015
	_bloom.scale = Vector3.ONE * maxf(bloom_scale, 0.001)
	_bloom.rotation.z = deg_to_rad(6.0 * bloom_scale)


func set_water(water: float) -> void:
	_water = water


func set_spent() -> void:
	_spent = true
	_bloom.visible = false
	_stem_mat.albedo_color = Palette.color("leaf_dark")
	for leaf in _leaves:
		leaf.material_override = Palette.mat("leaf_dark")


func _process(delta: float) -> void:
	_time += delta
	var sway := sin(_time * 1.5 + _phase) * 0.014
	var dry := 1.0 if _water > 2.0 else 0.0
	rotation.z = sway * (0.4 + _growth) + (1.0 - dry) * 0.05
	rotation.x = cos(_time * 1.1 + _phase) * 0.008
	if _bloom.visible:
		_bloom.rotation.y += delta * 0.06
