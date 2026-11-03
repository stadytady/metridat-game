extends Node3D
## Chickens by the main route: a rooster and hens by the potter's workshop on
## the agora, hens in the first courtyard on the street (by the stamped amphora).
## Homes are flat floors, so a chicken keeps the home's height.


func _ready() -> void:
	_flock("agora", Vector3(15.2, Topo.AGORA_H, 5.4), 1.5, [["rooster", true], ["hen", false], ["hen_white", false]])
	var street: Node = get_parent().get_node_or_null("Street")
	if street and not street.courtyards.is_empty():
		var xf: Transform3D = street.courtyards[0]
		_flock("yard", xf * Vector3(0.4, 0, -1.2), 0.9, [["hen", false], ["hen_white", false], ["hen", false]])


func _flock(tag: String, home: Vector3, radius: float, birds: Array) -> void:
	for i in birds.size():
		var c := Chicken.new()
		c.name = "%s_%d" % [tag, i]
		c.home = home
		c.radius = radius
		c.feathers = birds[i][0]
		c.rooster = birds[i][1]
		add_child(c)
