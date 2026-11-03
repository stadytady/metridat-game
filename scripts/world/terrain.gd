extends Node3D
## Terrain on a tensor grid: 3 m cells over the play area, coarser outside.
## One grid means no cracks between detail levels. Material is chosen per
## triangle (dirt in the city, grass outside, sand on the beach, rock on steep ground).

const CITY_MIN := Vector2(-84, -75)
const CITY_MAX := Vector2(60, 75)


static func axis(core_min: float, core_max: float, outer: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	var v := -outer
	while v < core_min - 60.0:
		a.append(v)
		v += 30.0
	v = core_min - 60.0
	while v < core_min:
		a.append(v)
		v += 10.0
	v = core_min
	while v < core_max:
		a.append(v)
		v += 3.0
	v = core_max
	while v < core_max + 60.0:
		a.append(v)
		v += 10.0
	v = core_max + 60.0
	while v <= outer:
		a.append(v)
		v += 30.0
	return a


func _ready() -> void:
	var xs := axis(-150.0, 90.0, 1200.0)
	var zs := axis(-120.0, 120.0, 1200.0)
	var h := PackedFloat32Array()
	h.resize(xs.size() * zs.size())
	for j in zs.size():
		for i in xs.size():
			h[j * xs.size() + i] = Topo.terrain(xs[i], zs[j])
	var shade := FastNoiseLite.new()
	shade.seed = 9
	shade.frequency = 0.05
	var patch := FastNoiseLite.new()
	patch.seed = 21
	patch.frequency = 0.03
	var kit := MeshKit.new()
	var nx := xs.size()
	for j in zs.size() - 1:
		for i in nx - 1:
			var p00 := Vector3(xs[i], h[j * nx + i], zs[j])
			var p10 := Vector3(xs[i + 1], h[j * nx + i + 1], zs[j])
			var p01 := Vector3(xs[i], h[(j + 1) * nx + i], zs[j + 1])
			var p11 := Vector3(xs[i + 1], h[(j + 1) * nx + i + 1], zs[j + 1])
			for t: Array in [[p01, p11, p10], [p01, p10, p00]]:
				var a: Vector3 = t[0]
				var b: Vector3 = t[1]
				var c: Vector3 = t[2]
				var mid := (a + b + c) / 3.0
				if mid.y < -3.0:
					continue  # under the sea, never seen
				var n := (b - a).cross(c - a).normalized()
				kit.color = Color.WHITE * (0.88 + 0.12 * shade.get_noise_2d(mid.x, mid.z))
				kit.color.a = 1.0
				kit.tri(_material(mid, n, patch), a, b, c,
						Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = kit.commit()
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.set_meta(&"surface", &"dirt")
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _material(mid: Vector3, n: Vector3, patch: FastNoiseLite) -> String:
	if n.y < 0.78:
		return "rock"
	# Beach: wet sand at the waterline, dry sand above, its upper edge ragged
	# so it meets the grass in patches, not along a contour line.
	if mid.y < 0.45:
		return "sand_wet"
	if mid.y < 3.2 + patch.get_noise_2d(mid.x * 2.5, mid.z * 2.5) * 0.7:
		return "sand"
	var in_city := mid.x > CITY_MIN.x and mid.x < CITY_MAX.x and mid.z > CITY_MIN.y and mid.z < CITY_MAX.y
	if in_city:
		return "grass" if patch.get_noise_2d(mid.x, mid.z) > 0.45 else "earth"
	return "grass" if patch.get_noise_2d(mid.x, mid.z) > -0.25 else "earth"
