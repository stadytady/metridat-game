class_name SleepSpot
extends StaticBody3D
## A fleece in the abaton of Hecate's sanctuary. Once every lamp on the way is
## lit, lying down on it (E) starts the dream; before that it says "not yet".

@export var size := Vector3(0.85, 0.12, 1.7)


func _ready() -> void:
	collision_layer = 3  # world + interaction ray
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y / 2.0
	add_child(cs)


static func ready_to_sleep() -> bool:
	return not Game.lamps.is_empty() and Game.lamps_lit() == Game.lamps.size() and not Game.dreaming


func get_prompt() -> String:
	return tr("UI_SLEEP") if ready_to_sleep() else tr("UI_SLEEP_NOT_YET")


func can_interact() -> bool:
	return not Game.dreaming


func interact() -> void:
	if ready_to_sleep():
		Game.dream_requested.emit()
