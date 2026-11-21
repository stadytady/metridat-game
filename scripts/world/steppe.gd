extends District
## The steppe west of the town, the way it looks from the hill: dry grass, burial
## mounds with stone women on top, a shepherd's fold and a flock that grazes
## there. Nothing here is on the route: it is the land the city looks at. The
## mounds are solid, since the Royal Kurgan's pocket (royal_kurgan.gd) and the
## west slope bring a few in reach.

const SHEEP := preload("res://scripts/npc/sheep.gd")

## Burial mounds, the way the Bosporan steppe is dotted with them: (x, z, radius,
## height). The further out, the bigger they read — a mound has to clear the rise
## of the ground behind it or it disappears into the plain.
## (The mound that stood at -122, 26 made way for the Royal Kurgan's terrace.)
## Round, not flat: the same full crown as the Royal Kurgan's (RoyalKurgan.
## mound_at), in the same dry grass. The last three stand far out on the
## skyline, where only their shapes come through the haze.
const KURGANS := [
	[-114.0, -18.0, 11.0, 4.6],
	[-136.0, -44.0, 15.0, 5.8],
	[-152.0, -56.0, 16.0, 6.2],
	[-168.0, 12.0, 19.0, 7.0],
	[-196.0, -84.0, 24.0, 8.6],
	[-208.0, 44.0, 22.0, 8.0],
	[-236.0, -16.0, 30.0, 10.0],
	[-272.0, 64.0, 26.0, 8.5],
	[-300.0, -58.0, 32.0, 10.5],
	[-262.0, -124.0, 22.0, 7.5],
]
## The two nearest mounds carry a stone woman, facing the town.
const STONE_WOMEN := 2
## Near the hill the steppe is thick: tufts in two shades, dry bushes, stones.
const NEAR_FROM := -100.0
const NEAR_TO := -160.0
const NEAR_Z := 78.0
const NEAR_TUFTS := 2600
const BUSHES := 70
const STONES := 50

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
	_near()
	_flock()


## The plain west of town is straw, not lawn: one terrain-following sheet recolours
## it from the terrace edge to the fog, and everything else stands on top of it.
func _field() -> void:
	var kit := MeshKit.new()
	var x := FIELD_FROM
	while x > FIELD_TO:
		var z := -FIELD_Z
		while z < FIELD_Z:
			# not over the Royal Kurgan's floors: the straw would lie in its passage
			if RoyalKurgan.over_stone(Rect2(x - FIELD_CELL, z, FIELD_CELL, FIELD_CELL)):
				z += FIELD_CELL
				continue
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 5480
	for i in KURGANS.size():
		var k: Array = KURGANS[i]
		var r: float = k[2]
		var h: float = k[3]
		var at := Vector3(k[0], Topo.terrain(k[0], k[1]), k[1])
		kit.lathe("steppe", mound_profile(r, h), 24, at, r * 0.5, false, "steppe", true)
		# tufts and a few bushes over the near ones; out in the haze they'd be lost
		if at.distance_to(Vector3(Topo.HILL_CENTER.x, at.y, Topo.HILL_CENTER.y)) < 90.0:
			for t in int(r * r * 0.9):
				var a := rng.randf() * TAU
				var d := sqrt(rng.randf()) * r * 0.95
				var p := at + Vector3(cos(a) * d, mound_height(r, h, d) - 0.05, sin(a) * d)
				_tuft(kit, p, rng.randf_range(0.3, 0.55), rng.randf() * PI, rng.randf_range(0.78, 1.0))
			for b in int(r * 0.6):
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.2, 0.85) * r
				var rad := rng.randf_range(0.4, 0.8)
				kit.color = Color(0.72, 0.64, 0.52)
				kit.blob("bark", at + Vector3(cos(a) * d, mound_height(r, h, d) + rad * 0.25, sin(a) * d), Vector3(rad, rad * 0.6, rad), 0.3, rng)
				kit.color = Color.WHITE
		if i < STONE_WOMEN:
			var top := at + Vector3(0, h - 0.1, 0)
			var to_town := Vector2(Topo.HILL_CENTER.x - k[0], Topo.HILL_CENTER.y - k[1])
			Props.stone_woman(kit, top, atan2(-to_town.x, -to_town.y))
	var root := kit.build("Kurgans")
	add_child(root)
	# the Royal Kurgan's pocket brings some of them in reach: walk over, not into
	root.add_child(District.trimesh_body((root.get_node("Mesh") as MeshInstance3D).mesh, &"dirt"))


## A mound's height at distance d from its middle: a full round crown, the same
## shape as the Royal Kurgan's.
static func mound_height(r: float, h: float, d: float) -> float:
	if d >= r:
		return 0.0
	return h * pow(1.0 - (d / r) * (d / r), 1.3)


## Its outline for the lathe, foot (a little under the ground) to crown.
static func mound_profile(r: float, h: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(r, -0.4)])
	for f: float in [0.96, 0.88, 0.76, 0.6, 0.42, 0.22, 0.0]:
		out.append(Vector2(r * f, mound_height(r, h, r * f)))
	return out


static func _tuft(kit: MeshKit, p: Vector3, s: float, yaw: float, shade: float) -> void:
	Props.tuft(kit, p, s, yaw, shade)


## The steppe near the hill, where the eye is: thick grass in two shades of
## straw, dry bushes, stones in the grass. Nothing collides; its own rng, so the
## tufts, mounds and flock before it stay where they were.
func _near() -> void:
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5481
	for i in NEAR_TUFTS:
		var x := rng.randf_range(NEAR_TO, NEAR_FROM)
		var z := rng.randf_range(-NEAR_Z, NEAR_Z)
		var s := rng.randf_range(0.25, 0.55)
		var yaw := rng.randf() * PI
		var shade := rng.randf_range(0.7, 1.0)
		if not _open(x, z):
			continue
		_tuft(kit, Vector3(x, Topo.terrain(x, z) + 0.12, z), s, yaw, shade)
	for i in BUSHES:
		var x := rng.randf_range(NEAR_TO, NEAR_FROM)
		var z := rng.randf_range(-NEAR_Z, NEAR_Z)
		var rad := rng.randf_range(0.35, 0.9)
		if not _open(x, z):
			continue
		kit.color = Color(0.7, 0.62, 0.5)
		kit.blob("bark", Vector3(x, Topo.terrain(x, z) + rad * 0.3, z), Vector3(rad, rad * 0.65, rad), 0.3, rng)
	for i in STONES:
		var x := rng.randf_range(NEAR_TO, NEAR_FROM)
		var z := rng.randf_range(-NEAR_Z, NEAR_Z)
		var rad := rng.randf_range(0.15, 0.45)
		if not _open(x, z):
			continue
		kit.color = Color(0.85, 0.83, 0.78)
		kit.blob("rock", Vector3(x, Topo.terrain(x, z) + rad * 0.2, z), Vector3(rad * 1.3, rad * 0.6, rad), 0.3, rng)
	kit.color = Color.WHITE
	add_child(kit.build("NearSteppe"))


## Whether (x, z) is open steppe: not on the hill's terrace or the park, not on
## a mound, the Royal Kurgan or its quarry, and above the shore.
static func _open(x: float, z: float) -> bool:
	if Topo.terrain(x, z) < 6.0 or RoyalKurgan.covers(x, z):
		return false
	if x > -102.0 and absf(z) < 42.0:
		return false
	for k: Array in KURGANS:
		if Vector2(x, z).distance_to(Vector2(k[0], k[1])) < float(k[2]):
			return false
	return true


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
		# none through the Royal Kurgan's stone or its earth: built into a scratch
		# kit, so the rng runs on and every other tuft stays where it was
		var k := MeshKit.new() if RoyalKurgan.covers(x, z) else kit
		var s := rng.randf_range(0.22, 0.5)
		var w := s * 0.5
		var lean := rng.randf_range(0.1, 0.35) * s
		var a := rng.randf() * PI
		var d := Vector3(cos(a), 0, sin(a)) * w
		var up := Vector3(rng.randf_range(-0.2, 0.2) * s, s, rng.randf_range(-0.2, 0.2) * s)
		k.quad("steppe", p - d, p + d, p + d + up + Vector3(lean * d.x, 0, lean * d.z), p - d + up - Vector3(lean * d.x, 0, lean * d.z))
		if i % 3 == 0:
			var a2 := a + PI * 0.5
			var d2 := Vector3(cos(a2), 0, sin(a2)) * w
			k.quad("steppe", p - d2, p + d2, p + d2 + up, p - d2 + up)
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
