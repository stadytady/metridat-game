extends Node3D
## Birds over the city by day: gulls circling the beach, the anchorage and the
## strait below the hill, and a flock of pigeons feeding on the agora right on
## the way across it. By night they are all gone to roost.

## Gulls: [circle centre (y = height), radius, rad/s].
const GULLS := [
	[Vector3(62, 13, 10), 9.0, 0.32],
	[Vector3(66, 16, 16), 12.0, -0.26],
	[Vector3(128, 14, -10), 16.0, 0.22],
	[Vector3(136, 18, 20), 20.0, -0.18],
	[Vector3(90, 22, -30), 24.0, 0.15],
	[Vector3(40, 26, 30), 18.0, -0.2],
	[Vector3(-20, 34, -18), 14.0, 0.24],
]
const PIGEONS := Vector3(27.5, Topo.AGORA_H, 1.6)
const PIGEON_RADIUS := 1.4
const PIGEON_COUNT := 6


func _ready() -> void:
	for i in GULLS.size():
		var g: Array = GULLS[i]
		var b := Bird.new()
		b.name = "gull_%d" % i
		b.kind = Bird.Kind.GULL
		b.home = g[0]
		b.radius = g[1]
		b.speed = g[2]
		add_child(b)
	for i in PIGEON_COUNT:
		var b := Bird.new()
		b.name = "pigeon_%d" % i
		b.kind = Bird.Kind.PIGEON
		b.home = PIGEONS
		b.radius = PIGEON_RADIUS
		add_child(b)
