class_name Build
extends RefCounted
## Tiny geometry helpers so level dressing stays readable and testable.


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO, name := "Box") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func solid_box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO, name := "Solid") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	return body


static func cylinder(parent: Node, top_radius: float, bottom_radius: float, height: float, pos: Vector3, material: Material, segments := 10, name := "Cyl") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material, name := "Sphere") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, pos: Vector3, font_size := 32, color := Color.WHITE, pixel := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.55)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	parent.add_child(l)
	return l


## Flat plane of grass/asphalt with a thin collision slab under the surface.
static func ground(parent: Node, size: Vector2, pos: Vector3, material: Material, name := "Ground") -> StaticBody3D:
	return solid_box(parent, Vector3(size.x, 0.4, size.y), pos - Vector3(0, 0.2, 0), material, Vector3.ZERO, name)
