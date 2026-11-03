extends RayCast3D
## Finds the Inspectable under the crosshair and triggers it on "interact".
## Polls the Input singleton: the world SubViewport receives no input events.

signal target_changed(target: Inspectable)

var current: Inspectable


func _physics_process(_delta: float) -> void:
	var hit := _find(get_collider()) if is_colliding() else null
	if hit != current:
		current = hit
		target_changed.emit(hit)
	if current and not Game.ui_blocking and Input.is_action_just_pressed(&"interact"):
		current.inspect()


## Test hook: same as pressing E now.
func try_interact() -> bool:
	force_raycast_update()
	var hit := _find(get_collider()) if is_colliding() else null
	if hit == null:
		return false
	hit.inspect()
	return true


## Models may carry their own colliders; the Inspectable is an ancestor.
static func _find(o: Object) -> Inspectable:
	var n := o as Node
	while n != null and not (n is Inspectable):
		n = n.get_parent()
	return n as Inspectable
