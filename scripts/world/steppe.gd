extends District
## The steppe west of the town, the way it looks from the hill: dry grass, burial
## mounds with stone women on top, a shepherd's fold and a flock that grazes
## there. Nothing here is on the route and nothing collides: it is the land the
## city looks at, not a place to walk to.

const SHEEP := preload("res://scripts/npc/sheep.gd")

## Burial mounds, the way the Bosporan steppe is dotted with them: (x, z, radius,
## height). The further out, the bigger they read — a mound has to clear the rise
## of the ground behind it or it disappears into the plain.
const KURGANS := [
	[-114.0, -18.0, 11.0, 3.0],
	[-122.0, 26.0, 13.0, 3.6],
	[-136.0, -44.0, 15.0, 4.2],
	[-152.0, -56.0, 16.0, 4.4],
	[-168.0, 12.0, 19.0, 5.2],
	[-196.0, -84.0, 24.0, 6.4],
	[-208.0, 44.0, 22.0, 5.8],
	[-236.0, -16.0, 30.0, 7.5],
]

## Long low ridges behind the mounds: (x, z, length, width, height). The steppe
## rolls rather than hills, but it does roll.
const RIDGES := [
	[-196.0, -128.0, 120.0, 46.0, 8.0],
	[-236.0, 138.0, 140.0, 52.0, 10.0],
	[-286.0, 4.0, 200.0, 70.0, 13.0],
]

## The dry-grass sheet over the plain: a terrain-following grid, one mesh.
const FIELD_FROM := -99.0
const FIELD_TO := -238.0
const FIELD_Z := 122.0
const FIELD_CELL := 3.0

## The flock grazes around here: a walk west of the terrace, still in sight.
const PASTURE := Vector2(-110.0, 18.0)
## How far from that centre a sheep may wander.
const ROAM := 26.0
const PASTURE_R := 9.0
const SHEEP_COUNT := 9
## Tufts of dry grass, spread over this stretch of the steppe.
const GRASS_FROM := -102.0
const GRASS_TO := -168.0
const GRASS_Z := 92.0
const GRASS_COUNT := 1400


## Where the mounds stand, as points (used by the tests).
static func kurgan_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k: Array in KURGANS:
		out.append(Vector3(k[0], Topo.terrain(k[0], k[1]), k[1]))
	return out


static func pasture() -> Vector3:
	return Vector3(PASTURE.x, Topo.terrain(PASTURE.x, PASTURE.y), PASTURE.y)


func _ready() -> void:
	_field()
	_ridges()
	_kurgans()
	_grass()
	_flock()


## The plain west of town is straw, not lawn: one terrain-following sheet recolours
## it from the terrace edge to the fog, and everything else stands on top of it.
func _field() -> void:
	var kit := MeshKit.new()
	var x := FIELD_FROM
	while x > FIELD_TO:
		var z := -FIELD_Z
		while z < FIELD_Z:
			var a := Vector3(x, Topo.terrain(x, z) + 0.18, z)
			var b := Vector3(x - FIELD_CELL, Topo.terrain(x - FIELD_CELL, z) + 0.18, z)
			var c := Vector3(x - FIELD_CELL, Topo.terrain(x - FIELD_CELL, z + FIELD_CELL) + 0.18, z + FIELD_CELL)
			var d := Vector3(x, Topo.terrain(x, z + FIELD_CELL) + 0.18, z + FIELD_CELL)
			kit.quad("steppe", a, b, c, d, PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)]))
			z += FIELD_CELL
		x -= FIELD_CELL
	add_child(kit.build("Field"))


## Long ridges on the skyline: a unit dome scaled wide and low, so the steppe rolls
## the way it does in the distance instead of ending in a flat line.
func _ridges() -> void:
	for r: Array in RIDGES:
		var k := MeshKit.new()
		k.lathe("distant_land", PackedVector2Array([
			Vector2(1.0, -0.15), Vector2(0.88, 0.28), Vector2(0.6, 0.66), Vector2(0.0, 1.0)]),
			16, Vector3.ZERO, 10.0, true, "distant_land", true)
		var n := k.build("Ridge")
		n.scale = Vector3(r[2] * 0.5, r[4], r[3] * 0.5)
		n.position = Vector3(r[0], Topo.terrain(r[0], r[1]) - 0.6, r[1])
		add_child(n)


## A mound is a lathe with a low, wide profile; the biggest wears a stone woman.
func _kurgans() -> void:
	var kit := MeshKit.new()
	for i in KURGANS.size():
		var k: Array = KURGANS[i]
		var x: float = k[0]
		var z: float = k[1]
		var r: float = k[2]
		var h: float = k[3]
		var y := Topo.terrain(x, z)
		var at := Vector3(x, y, z)
		kit.lathe("earth", PackedVector2Array([
			Vector2(r, -0.4), Vector2(r * 0.92, h * 0.2), Vector2(r * 0.6, h * 0.62),
			Vector2(r * 0.26, h * 0.92), Vector2(0.0, h)]), 12, at, 4.0, false, "earth", true)
		# A stone woman on the two nearest mounds: the steppe is full of them.
		if i < 2:
			var top := at + Vector3(0, h - 0.15, 0)
			kit.box("limestone", top + Vector3(0, 0.55, 0), Vector3(0.34, 1.1, 0.22), ["bottom"], {})
			kit.box("limestone", top + Vector3(0, 1.22, 0), Vector3(0.24, 0.28, 0.24), ["bottom"], {})
	add_child(kit.build("Kurgans"))


## Dry grass: crossed blades, batched into one mesh. At this distance they read as
## speckles, which is exactly what a steppe does.
func _grass() -> void:
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in GRASS_COUNT:
		var x := rng.randf_range(GRASS_TO, GRASS_FROM)
		var z := rng.randf_range(-GRASS_Z, GRASS_Z)
		var y := Topo.terrain(x, z)
		if y < 6.0:
			continue
		var p := Vector3(x, y, z)
		var s := rng.randf_range(0.22, 0.5)
		var w := s * 0.5
		var lean := rng.randf_range(0.1, 0.35) * s
		var a := rng.randf() * PI
		var d := Vector3(cos(a), 0, sin(a)) * w
		var up := Vector3(rng.randf_range(-0.2, 0.2) * s, s, rng.randf_range(-0.2, 0.2) * s)
		kit.quad("steppe", p - d, p + d, p + d + up + Vector3(lean * d.x, 0, lean * d.z), p - d + up - Vector3(lean * d.x, 0, lean * d.z))
		if i % 3 == 0:
			var a2 := a + PI * 0.5
			var d2 := Vector3(cos(a2), 0, sin(a2)) * w
			kit.quad("steppe", p - d2, p + d2, p + d2 + up, p - d2 + up)
	add_child(kit.build("Grass"))


func _flock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in SHEEP_COUNT:
		var a := TAU * i / SHEEP_COUNT + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(1.5, PASTURE_R * 0.8)
		var p := Vector3(PASTURE.x, 0, PASTURE.y) + Vector3(cos(a), 0, sin(a)) * r
		p.y = Topo.terrain(p.x, p.z)
		var s: Sheep = SHEEP.new()
		s.name = "Sheep%d" % i
		s.home = p
		s.radius = rng.randf_range(6.0, ROAM)
		s.position = p
		s.rotation.y = rng.randf() * TAU
		add_child(s)
