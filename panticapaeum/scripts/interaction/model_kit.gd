extends Node3D
## Model built at runtime from Props.build(kind): for small one-off pieces
## that are not worth a GLB.

@export var kind := ""


func _ready() -> void:
	add_child(Props.build(kind).build("Model"))
