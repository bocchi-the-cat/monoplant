class_name PackingStation
extends Interactable
## Bench where loose blooms become a sealed order box.

func _ready() -> void:
	display_name = "Packing Bench"
	collision_size = Vector3(1.1, 1.7, 2.35)
	collision_offset = Vector3(0, 0.85, 0)
	super._ready()


func get_prompt(_player: Node) -> String:
	if OrderSystem.requests.is_empty():
		return "Packing bench - no open orders"
	return "Pack an order"


func is_actionable(_player: Node) -> bool:
	return not OrderSystem.requests.is_empty()


func interact(_player: Node) -> void:
	EventBus.pack_requested.emit()
