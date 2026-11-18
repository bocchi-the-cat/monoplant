class_name WaterTap
extends Interactable
## Greenhouse tap. Free refills for the watering can.

func _ready() -> void:
	display_name = "Tap"
	collision_size = Vector3(0.9, 1.3, 0.8)
	collision_offset = Vector3(0, 0.65, 0)
	_build()
	super._ready()


func _build() -> void:
	Build.solid_box(self, Vector3(0.9, 0.85, 0.7), Vector3(0, 0.425, 0), Palette.mat("metal_dark"), Vector3.ZERO, "Basin")
	Build.box(self, Vector3(0.8, 0.08, 0.6), Vector3(0, 0.88, 0), Palette.mat("metal"), Vector3.ZERO, "BasinTop")
	Build.cylinder(self, 0.045, 0.045, 0.5, Vector3(-0.1, 1.13, -0.15), Palette.mat("metal"), 8, "Faucet")
	Build.box(self, Vector3(0.24, 0.05, 0.05), Vector3(-0.02, 1.36, -0.15), Palette.mat("metal"), Vector3.ZERO, "Spout")
	Build.label(self, "TAP", Vector3(0, 1.62, 0), 26, Palette.color("ui_dim"), 0.003)


func _selected_can_index() -> int:
	var slot := Inventory.selected_slot()
	if slot.is_empty() or not ItemDB.is_can(String(slot["id"])):
		return -1
	return Inventory.selected


func is_actionable(_player: Node) -> bool:
	return _selected_can_index() >= 0


func get_prompt(_player: Node) -> String:
	if _selected_can_index() < 0:
		return "Tap - select the watering can"
	return "Refill watering can"


func interact(_player: Node) -> void:
	var idx := _selected_can_index()
	if idx < 0:
		EventBus.notify("Select the watering can first")
		return
	Inventory.refill_can(idx)
	EventBus.notify("Watering can refilled")
