extends District
## Olive trees and cypresses, shrubs, the rocky shore, and the invisible
## boundary that keeps the player on land.

const TREE_SPOTS := [
	Vector2(-102, 11), Vector2(-76, 12), Vector2(-104, -12), Vector2(-75, -13), Vector2(-108, 3), Vector2(-94, 15),
	Vector2(-96, -16), Vector2(-60, 14), Vector2(-58, -15), Vector2(36, 12), Vector2(10, -12.5), Vector2(57, -22),
	Vector2(30, 15), Vector2(-110, 18), Vector2(-112, -20), Vector2(-120, 5),
]


const FISHING := preload("res://scripts/world/fishing.gd")


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for p: Vector2 in TREE_SPOTS:
		place("olive_tree", Vector3(p.x, Topo.terrain(p.x, p.y) - 0.1, p.y), rng.randf_range(0, 360),
				Vector3.ONE * rng.randf_range(0.85, 1.25), 0.2, 2.0)
	for i in 10:
		var z := rng.randf_range(-70, 70)
		var x := rng.randf_range(-130, -98)
		place("cypress", Vector3(x, Topo.terrain(x, z) - 0.1, z), 0.0, Vector3.ONE * rng.randf_range(0.8, 1.2), 0.2, 2.0)
	_shrubs(rng)
	_shore(rng)
	_boundary()


func _shrubs(rng: RandomNumberGenerator) -> void:
	var kit := MeshKit.new()
	var n := 0
	while n < 160:
		var x := rng.randf_range(-130, 62)
		var z := rng.randf_range(-76, 76)
		if Topo.is_reserved(x, z, 0.5):
			continue
		var t := Topo.terrain(x, z)
		if t < 1.5:
			continue
		var r := rng.randf_range(0.35, 0.8)
		kit.color = Color(1, 1, 1) * rng.randf_range(0.8, 1.05)
		kit.color.a = 1
		# Not on the camp, the beach sand or the house; a scratch kit keeps the rng sequence.
		var k := MeshKit.new() if t < 3.4 or Topo.in_rect(x, z, Topo.CAMP_CENTER, Topo.CAMP_HALF, r) \
				or Topo.in_house(x, z, r + 1.0) else kit
		k.blob("foliage", Vector3(x, t + r * 0.4, z), Vector3(r * 1.2, r * 0.75, r), 0.25, rng)
		n += 1
	var node := kit.build("Shrubs")
	add_child(node)
	(node.get_node("Mesh") as GeometryInstance3D).visibility_range_end = 180.0


func _shore(rng: RandomNumberGenerator) -> void:
	var kit := MeshKit.new()
	var z := -140.0
	while z < 140.0:
		var x := 62.0 + Topo.coast_shift(z) * 1.0 + rng.randf_range(-3, 6)
		var r := rng.randf_range(0.5, 2.4)
		var t := Topo.terrain(x, z)
		kit.color = Color(1, 1, 1) * rng.randf_range(0.8, 1.0)
		kit.color.a = 1
		# Rocks on the camp are built into a scratch kit: the rng sequence, and
		# with it every other rock, stays as it was.
		var k := MeshKit.new() if Topo.in_rect(x, z, Topo.CAMP_CENTER, Topo.CAMP_HALF, r) \
				or Topo.in_house(x, z, r + 1.0) or Topo.on_pier(x, z, r + 1.0) \
				or Vector2(x, z).distance_to(FISHING.CORMORANT_SAND) < FISHING.CORMORANT_CLEAR + r else kit
		if t >= 0.0:
			k.blob("rock", Vector3(x, t + r * 0.3, z), Vector3(r * 1.3, r * 0.8, r), 0.3, rng)
		else:
			# In the surf: tall enough that its foot stays below the deepest trough.
			k.blob("rock", Vector3(x, -0.8 - r * 0.1, z), Vector3(r * 1.3, r + 1.0, r), 0.3, rng)
		z += rng.randf_range(2.0, 5.0)
	for i in 6:
		var sx := rng.randf_range(75, 110)
		var sz := rng.randf_range(-90, 90)
		var r := rng.randf_range(1.5, 4.0)
		# Sunk deep: wave troughs reach about a metre below sea level.
		(MeshKit.new() if Topo.on_pier(sx, sz, r + 4.0) else kit).blob("rock", Vector3(sx, -r * 0.2, sz), Vector3(r, r * 1.6, r * 0.9), 0.35, rng)
	add_child(kit.build("Shore"))


## Walls along the waterline (sampled from the terrain) and the western edge.
func _boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	add_child(body)
	for w: Array in boundary_walls():
		_wall(body, w[0], w[1])


## The wall segments [a, b]. Along the waterline, except where the pier goes
## out: there the wall runs round the pier's sides and end instead.
static func boundary_walls() -> Array:
	var out := []
	var prev := Vector3.INF
	var z := -80.0
	var lo := Topo.PIER_Z - Topo.PIER_HALF - 0.3
	var hi := Topo.PIER_Z + Topo.PIER_HALF + 0.3
	while z <= 80.0:
		var x := 40.0
		while x < 120.0 and Topo.terrain(x, z) > 0.4:
			x += 0.5
		var p := Vector3(x, 0, z)
		if prev != Vector3.INF:
			if prev.z < hi and p.z > lo:
				var a := prev.lerp(p, (lo - prev.z) / (p.z - prev.z))
				var b := prev.lerp(p, (hi - prev.z) / (p.z - prev.z))
				var end := Topo.pier_x1() + 0.3
				out.append([prev, a])
				out.append([a, Vector3(end, 0, lo)])
				out.append([Vector3(end, 0, lo), Vector3(end, 0, hi)])
				out.append([Vector3(end, 0, hi), b])
				out.append([b, p])
			else:
				out.append([prev, p])
		prev = p
		z += 4.0
	out.append([Vector3(-128, 0, -80), Vector3(-128, 0, 80)])
	out.append([Vector3(-128, 0, -80), Vector3(prev.x, 0, -80)])
	out.append([Vector3(-128, 0, 80), Vector3(prev.x, 0, 80)])
	return out


func _wall(body: StaticBody3D, a: Vector3, b: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var d := b - a
	sh.size = Vector3(d.length() + 0.5, 80.0, 0.5)
	cs.shape = sh
	cs.transform = Arch.frame((a + b) / 2.0, d)
	body.add_child(cs)
