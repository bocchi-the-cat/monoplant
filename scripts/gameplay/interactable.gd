class_name Interactable
extends StaticBody3D
## Base for everything the crosshair can act on.
## Occupies the "interactable" physics layer (4) and optionally blocks the player.

@export var display_name := "Object"
@export var collision_size := Vector3(0.6, 1.7, 0.6)
@export var collision_offset := Vector3(0, 0.85, 0)
@export var blocks_player := true

var enabled := true


func _ready() -> void:
	collision_layer = (1 if blocks_player else 0) | 4
	collision_mask = 0
	if not _has_shape():
		_add_shape()


func _has_shape() -> bool:
	for c in get_children():
		if c is CollisionShape3D:
			return true
	return false


func _add_shape() -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collision_size
	cs.shape = shape
	cs.position = collision_offset
	add_child(cs)


func is_available() -> bool:
	return enabled


## Text shown by the HUD while the crosshair is on this object. Empty hides it.
func get_prompt(_player: Node) -> String:
	return ""


## Called when the player presses E while focused.
func interact(_player: Node) -> void:
	pass
