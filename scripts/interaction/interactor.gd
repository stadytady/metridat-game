extends RayCast3D
## Finds the interactable under the crosshair (any node with interact() and
## get_prompt(), e.g. Inspectable, Lamp) and triggers it on "interact".
## Polls the Input singleton: the world SubViewport receives no input events.

signal target_changed(target: Node)

var current: Node


func _physics_process(_delta: float) -> void:
	var hit := _find(get_collider()) if is_colliding() else null
	if hit != current:
		current = hit
		target_changed.emit(hit)
	if current and not Game.ui_blocking and Input.is_action_just_pressed(&"interact"):
		current.interact()


## Test hook: same as pressing E now.
func try_interact() -> bool:
	force_raycast_update()
	var hit := _find(get_collider()) if is_colliding() else null
	if hit == null:
		return false
	hit.interact()
	return true


## Models may carry their own colliders; the interactable is an ancestor.
## Ones that are done (a lit lamp) say so through can_interact().
static func _find(o: Object) -> Node:
	var n := o as Node
	while n != null and not n.has_method(&"interact"):
		n = n.get_parent()
	if n != null and n.has_method(&"can_interact") and not n.can_interact():
		return null
	return n
