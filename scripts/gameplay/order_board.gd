class_name OrderBoard
extends Interactable
## Wall-mounted board. Opens the request list.

func _ready() -> void:
	display_name = "Order Board"
	collision_size = Vector3(0.4, 1.4, 1.7)
	collision_offset = Vector3(0, 0, 0)
	blocks_player = false
	super._ready()


func get_prompt(_player: Node) -> String:
	return "Read order board (%d open)" % OrderSystem.requests.size()


func interact(_player: Node) -> void:
	EventBus.board_requested.emit()
