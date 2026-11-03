extends Area3D
## Shows the location title when the player walks in.

@export var title := ""


func _ready() -> void:
	monitorable = false
	body_entered.connect(func(b: Node3D) -> void:
		if b is CharacterBody3D:
			Game.location_entered.emit(title))
