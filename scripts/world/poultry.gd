extends Node3D
## Chickens by the main route: a rooster and hens by the potter's workshop on
## the agora, hens in the first courtyard on the street (by the stamped amphora),
## two in Myrto's yard on the west side away from the oven, and a few in the
## mule's pen across the lane from the well. Homes are flat floors, so a chicken
## keeps the home's height; the pen falls across, so its hens follow the ground.

const LIFE := preload("res://scripts/world/life.gd")
const HOUSE := preload("res://scripts/world/house.gd")
## Myrto's hens: the west half of the yard, clear of the pithoi by the wall
## and of the mason's block (a find, House.MASON_MARK).
const MYRTO_HENS := Vector3(22.6, Topo.HOUSE_H, 19.0)
const MYRTO_RADIUS := 1.0
## The pen's hens: towards the gate side of the pen, the mule's hay at the back.
const PEN_OFFSET := Vector3(-0.8, 0, -0.3)
const PEN_RADIUS := 1.1


static func pen_home() -> Vector3:
	var c: Vector3 = LIFE.yard_pos() + PEN_OFFSET
	c.y = Topo.surface(c.x, c.z)
	return c


func _ready() -> void:
	_flock("agora", Vector3(15.2, Topo.AGORA_H, 5.4), 1.5, [["rooster", true], ["hen", false], ["hen_white", false]])
	var street: Node = get_parent().get_node_or_null("Street")
	if street and not street.courtyards.is_empty():
		var xf: Transform3D = street.courtyards[0]
		_flock("yard", xf * Vector3(0.4, 0, -1.2), 0.9, [["hen", false], ["hen_white", false], ["hen", false]])
	_flock("myrto", MYRTO_HENS, MYRTO_RADIUS, [["hen_white", false], ["hen", false]])
	_flock("pen", pen_home(), PEN_RADIUS, [["hen", false], ["hen_white", false], ["hen", false]], true)


func _flock(tag: String, home: Vector3, radius: float, birds: Array, follow_ground := false) -> void:
	for i in birds.size():
		var c := Chicken.new()
		c.name = "%s_%d" % [tag, i]
		c.home = home
		c.radius = radius
		c.feathers = birds[i][0]
		c.rooster = birds[i][1]
		c.follow_ground = follow_ground
		add_child(c)
