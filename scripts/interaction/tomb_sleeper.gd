class_name TombSleeper
extends StaticBody3D
## The one asleep on the couch in the dream's burial chamber, under a fleece,
## lying as the dreamer lay down in the abaton. Leaning over them (E) ends the
## dream. Only a body to look at: it does not talk.

signal leaned

@export var size := Vector3(2.0, 0.9, 0.9)

var _figure: Node3D
var _joints: Dictionary
var _t := 0.0


func _ready() -> void:
	collision_layer = 3  # world + interaction ray
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y / 2.0
	add_child(cs)
	# Lying along local x, head to -x: the figure's sleep pose lies along its +z.
	_figure = Node3D.new()
	_figure.name = "Sleeper"
	_figure.rotation.y = -PI / 2.0
	_figure.position = Vector3(0.15, 0.55, 0)  # on the couch's top
	add_child(_figure)
	_joints = Figure.build(_figure, "chiton")
	Figure.apply_pose(_joints, "sleep")


func get_prompt() -> String:
	return tr("UI_LEAN")


func can_interact() -> bool:
	return Game.dreaming


func interact() -> void:
	leaned.emit()


func _process(delta: float) -> void:
	_t += delta
	Figure.apply_pose(_joints, "sleep", Figure.motion("sleep", _t))
