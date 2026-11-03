extends District
## Lamps along the route, hill -> street -> agora -> sanctuary stair, placed
## at the edges so the way stays clear (the walkthrough walks the centre).

const LAMP := preload("res://scenes/interactables/lamp.tscn")


func _ready() -> void:
	var c := Topo.HILL_CENTER
	var x1 := c.x + Topo.HILL_HALF.x - 0.3
	for sz: float in [-1.0, 1.0]:
		_lamp("lampstand", Vector3(x1 - 1.6, Topo.HILL_PLATFORM_TOP, sz * 3.1))
	var side := 1.0
	for x: float in [-60.0, -50.0, -41.0, -32.0, -22.0, -12.0, -2.0]:
		var dz := Topo.street_z(x + 0.5) - Topo.street_z(x - 0.5)
		var out := Vector3(-dz, 0, 1).normalized() * side
		var p := Vector3(x, Topo.street_height(x), Topo.street_z(x)) + out * (Topo.STREET_HALF - 0.35)
		_lamp("lampstand", p)
		side = -side
	var a := Topo.AGORA_CENTER - Vector2(Topo.AGORA_HALF.x - 1.2, 0)
	for sz: float in [-3.2, 3.2]:
		_lamp("torch_post", Vector3(a.x, Topo.AGORA_H, a.y + sz))
	var s0 := Topo.SANCT_STAIR[0]
	var s1 := Topo.SANCT_STAIR[1]
	var dir := Vector3(s1.x - s0.x, 0, s1.z - s0.z).normalized()
	var perp := Vector3(-dir.z, 0, dir.x) * (Topo.SANCT_STAIR_HALF + 0.5)
	for p: Vector3 in [s0 - dir * 0.8, s1 + dir * 0.8]:
		for sgn: float in [-1.0, 1.0]:
			var q := p + perp * sgn
			_lamp("torch_post", Vector3(q.x, Topo.surface(q.x, q.z), q.z))
	# two torches flanking the temple door (Hecate's torches)
	var sc := Topo.SANCT_CENTER
	for sx: float in [-1.9, 1.9]:
		_lamp("torch_post", Vector3(sc.x + sx, Topo.SANCT_H, -25.7))


func _lamp(kind: String, pos: Vector3) -> void:
	var l: Node3D = LAMP.instantiate()
	l.kind = kind
	l.position = pos
	add_child(l)
