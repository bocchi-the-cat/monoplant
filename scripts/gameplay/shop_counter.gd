class_name ShopCounter
extends Interactable
## The greenhouse seed counter. Opens the supply shop UI.

func _ready() -> void:
	display_name = "Seed Counter"
	collision_size = Vector3(1.1, 1.3, 2.7)
	collision_offset = Vector3(0, 0.65, 0)
	_build()
	super._ready()


func _build() -> void:
	Build.solid_box(self, Vector3(0.9, 0.95, 2.6), Vector3(0, 0.475, 0), Palette.mat("wood_dark"), Vector3.ZERO, "Counter")
	Build.box(self, Vector3(1.02, 0.08, 2.75), Vector3(0, 0.99, 0), Palette.mat("wood_pale"), Vector3.ZERO, "CounterTop")
	Build.box(self, Vector3(0.34, 0.22, 0.42), Vector3(0.05, 1.12, 0.75), Palette.mat("metal_dark"), Vector3.ZERO, "Register")
	Build.box(self, Vector3(0.3, 0.02, 0.24), Vector3(0.05, 1.24, 0.75), Palette.glow("neon_teal", 1.2), Vector3.ZERO, "Screen")
	for i in 3:
		Build.box(self, Vector3(0.22, 0.16, 0.3), Vector3(0.0, 1.11, -0.75 + float(i) * 0.34), Palette.mat("seed_packet"), Vector3(0, float(i) * 0.4, 0), "SeedBox")
	Build.label(self, "SEEDS & SUPPLIES", Vector3(0, 2.25, 0), 34, Palette.color("ui_accent"), 0.0042)


func get_prompt(_player: Node) -> String:
	return "Browse seeds"


func interact(_player: Node) -> void:
	EventBus.shop_requested.emit()
