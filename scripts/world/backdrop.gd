extends District
## The rest of the city on the slopes of the hill, built as Panticapaeum was:
## the slopes cut into terraces held up by stone retaining walls, a street
## along each terrace following the lie of the ground, rows of houses fronting
## it, wall to wall, and steep stepped lanes running straight down the slope
## between the terraces. On the flatter ground east of the agora the streets
## keep the same north-south run. Batched into one mesh; everything collides,
## and the city wall bounds the play area north and south.
##
## Lived in: hearth smoke rises from some roofs through the day, and after
## dusk lamps show in some windows.

const WALL_Z := 78.0
## Terrace streets: about every ten metres down the slope, each following the
## contour through that point; north-south runs at these x on the flatter
## ground east of the agora.
const TERRACES_X := [-58.0, -48.0, -38.0, -28.0, -18.0, -8.0]
const FLAT_STREETS_X := [14.0, 28.0, 42.0]
const TERRACE_SLOPE_END := 4.0
## Stepped lanes down the slope, at about these z.
const STAIRS_Z := [-64.0, -46.0, -28.0, 20.0, 37.0, 55.0]
const Z_SPAN := Vector2(-73.0, 73.0)
const Z_STEP := 2.5
const LANE_HALF := 0.9
const LANE_SEG := 1.5
## Hearths smoking: one roof in this many.
const SMOKE_EVERY := 7
## Windows lit from this hour, with the town's lamps.
const GLOW_FROM := DayCycle.LAMPS_ON

var _glow: Node3D
## The one house you can walk into, and the lamp beside its door.
var _cottage_lamp: WallLamp
var _cottage_at := Transform3D.IDENTITY
## The householder in the cottage: a woman with her hair under a kerchief.
var _woman: Npc
var _smoke: Array[GPUParticles3D] = []
## Lamps on the walls of the back lanes: with the cottage's one they make the
## town a scatter of fires at night instead of one lit street and a black map.
var _lane_lamps: Array[WallLamp] = []
## Who works at a doorstep by day and goes in at dusk, who keeps walking, and the
## one man who only comes out once the lamps are lit.
var _porch_people: Array[Npc] = []
var _walker_people: Array[Npc] = []
var _watchman: Npc
var _night := false
var _atm: Node


## Where the ground falls through `level` going east (downhill) at z: the contour.
static func _contour_x(level: float, z: float) -> float:
	var x := -66.0
	while x < TERRACE_SLOPE_END:
		if Topo.terrain(x, z) <= level:
			var lo := x - 1.0
			var hi := x
			for i in 6:
				var mid := (lo + hi) / 2.0
				if Topo.terrain(mid, z) > level:
					lo = mid
				else:
					hi = mid
			return hi
		x += 1.0
	return NAN


## The terrace streets as polylines of (x, z), north to south. A contour that
## leaves the slope is broken there; each run is smoothed so the street bends
## with the hill, not with every bump in it.
static func streets() -> Array:
	var out := []
	for x_at: float in TERRACES_X:
		# the terrace's height: the ground at that x, either side of the street axis
		var level := (Topo.terrain(x_at, 30.0) + Topo.terrain(x_at, -30.0)) / 2.0
		var run := PackedVector2Array()
		var z := Z_SPAN.x
		while z <= Z_SPAN.y:
			var x := _contour_x(level, z)
			if is_nan(x):
				if run.size() > 3:
					out.append(_smooth(run))
				run = PackedVector2Array()
			else:
				run.append(Vector2(x, z))
			z += Z_STEP
		if run.size() > 3:
			out.append(_smooth(run))
	for x0: float in FLAT_STREETS_X:
		var run := PackedVector2Array()
		var z := Z_SPAN.x
		while z <= Z_SPAN.y:
			run.append(Vector2(x0 + 2.2 * sin(z * 0.045 + x0) + 1.2 * sin(z * 0.11), z))
			z += Z_STEP
		out.append(run)
	return out


static func _smooth(run: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in run.size():
		var sx := 0.0
		var n := 0
		for k in range(maxi(0, i - 2), mini(run.size(), i + 3)):
			sx += run[k].x
			n += 1
		out.append(Vector2(sx / n, run[i].y))
	return out


## The stepped lanes, straight down the slope (west to east), wandering a little.
static func stairs() -> Array:
	var out := []
	for z0: float in STAIRS_Z:
		var run := PackedVector2Array()
		var x := -66.0
		while x <= 56.0:
			run.append(Vector2(x, z0 + 2.0 * sin(x * 0.06 + z0) + 0.8 * sin(x * 0.17)))
			x += Z_STEP
		out.append(run)
	return out


static func _dist_to(runs: Array, p: Vector2) -> float:
	var best := INF
	for run: PackedVector2Array in runs:
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			if minf(absf(p.x - a.x), absf(p.x - b.x)) > best + 4.0 and minf(absf(p.y - a.y), absf(p.y - b.y)) > best + 4.0:
				continue  # a segment (at most a few metres long) this far off cannot be nearer
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


static func _footprint(hs: Dictionary) -> Array[Vector2]:
	var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
	var out: Array[Vector2] = []
	for sx: float in [-0.5, 0.0, 0.5]:
		for sz: float in [-0.5, 0.0, 0.5]:
			var q := basis * Vector3(sx * hs.w, 0, sz * hs.d)
			out.append(hs.pos + Vector2(q.x, q.z))
	return out


## `others`: the street runs other than the one the house fronts (its own
## street bends under the corners of a straight house on a curve).
static func _site_ok(hs: Dictionary, houses: Array, stair_runs: Array, others: Array) -> bool:
	for p in _footprint(hs):
		if Topo.is_reserved(p.x, p.y, 1.0) or Topo.in_house(p.x, p.y, 2.0) or Topo.on_pier(p.x, p.y, 2.0):
			return false
		if Topo.terrain(p.x, p.y) < 2.2 or absf(p.y) > WALL_Z - 4.0:
			return false
		if _dist_to(stair_runs, p) < LANE_HALF + 0.4 or _dist_to(others, p) < LANE_HALF + 0.2:
			return false
		if on_house(houses, p.x, p.y, -0.15):  # neighbours may share a wall, not overlap
			return false
	return true


## The houses: rows along both sides of each street, fronts on the street,
## neighbours wall to wall with now and then a gap or a yard.
## {pos, yaw, w, d, h, opts}.
static func plan() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var street_runs := streets()
	var stair_runs := stairs()
	# every street gets a row on its uphill (west) side first, then a row on
	# its downhill side wherever the ground between the terraces is still free
	for r in street_runs.size() * 2:
		var run: PackedVector2Array = street_runs[r % street_runs.size()]
		var east := r >= street_runs.size()
		var others := street_runs.filter(func(o: PackedVector2Array) -> bool: return o != run)
		var i := 0
		var carry := rng.randf_range(0.0, 3.0)
		while i < run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var seg := a.distance_to(b)
			if carry > seg:
				carry -= seg
				i += 1
				continue
			var w := rng.randf_range(4.5, 7.5)
			var d := rng.randf_range(4.5, 6.5)
			var p := a.lerp(b, carry / seg)
			var t := (b - a).normalized()
			var n := Vector2(-t.y, t.x)
			if (n.x > 0.0) != east:
				n = -n  # uphill (west) on the first pass, downhill (east) on the second
			var front := p + n * (LANE_HALF + 0.4)
			var hs := {
				"pos": front + n * (d / 2.0),
				"yaw": atan2(-n.x, -n.y),
				"w": w, "d": d,
				"h": rng.randf_range(3.0, 4.3),
				"opts": {
					"roof": "gable" if rng.randf() < 0.65 else "flat",
					"door": rng.randf() < 0.7,
					"door_x": rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0),
					"windows": rng.randi_range(0, 2),
					"seed": int(p.x * 10.0) * 1000 + int(p.y * 10.0),
				},
			}
			# along the row: the next house about one width on, wall to wall,
			# sometimes after a gap (a yard, a passage)
			var step := w + (rng.randf_range(1.5, 3.5) if rng.randf() < 0.25 else 0.05)
			if _site_ok(hs, out, stair_runs, others):
				out.append(hs)
			else:
				step = 2.0
			carry += step
	return out


## Is (x, z) on a house's footprint (with a margin)?
static func on_house(houses: Array, x: float, z: float, margin: float) -> bool:
	for hs: Dictionary in houses:
		if absf(x - hs.pos.x) > 6.0 + margin or absf(z - hs.pos.y) > 6.0 + margin:
			continue  # far off: no house here is more than 12 m across
		var local := Basis.from_euler(Vector3(0, hs.yaw, 0)).inverse() * Vector3(x - hs.pos.x, 0, z - hs.pos.y)
		if absf(local.x) < hs.w / 2.0 + margin and absf(local.z) < hs.d / 2.0 + margin:
			return true
	return false


static func _lane_ok(houses: Array, m: Vector2) -> bool:
	return not (on_house(houses, m.x, m.y, LANE_HALF) or Topo.is_reserved(m.x, m.y, 1.0) or Topo.in_house(m.x, m.y, 1.0)
			or Topo.on_pier(m.x, m.y, 1.0) or Topo.terrain(m.x, m.y) < 2.4 or absf(m.y) > WALL_Z - 3.0)


## Lane pieces [a, b] along the terrace streets and down the stepped lanes,
## cut wherever a house, the city centre or the shore is in the way.
static func lanes(houses: Array) -> Array:
	var out := []
	for run: PackedVector2Array in streets() + stairs():
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var n := maxi(1, int(a.distance_to(b) / LANE_SEG))
			for k in n:
				var p0 := a.lerp(b, float(k) / n)
				var p1 := a.lerp(b, float(k + 1) / n)
				if _lane_ok(houses, (p0 + p1) / 2.0):
					out.append([p0, p1])
	return out


## The herms at the corners where a terrace street meets a stepped lane. Herms
## stood at Greek street corners; here they are what tells the eye that a side
## street is a street and not a gap between two walls. Each stands clear of both
## lanes - a lane is 1.8 m wide and a herm 1.35 m off its centre leaves room to
## pass with a jar on your head. [{pos, dir}]
static func crossing_herms(houses: Array) -> Array:
	var out := []
	var stair_runs := stairs()
	var street_runs := streets()
	for sx: float in TERRACES_X:
		for sz: float in STAIRS_Z:
			var at := Vector2(sx + 1.35, sz + 1.6)
			if Topo.terrain(at.x, at.y) < 2.4 or absf(at.y) > WALL_Z - 6.0:
				continue
			if Topo.is_reserved(at.x, at.y, 1.2) or Topo.in_house(at.x, at.y, 1.0):
				continue
			if on_house(houses, at.x, at.y, 0.5):
				continue
			# the streets are contours, not straight lines: the corner has to be
			# measured against where they actually run
			if _dist_to(stair_runs, at) < LANE_HALF + 0.45 or _dist_to(street_runs, at) < LANE_HALF + 0.45:
				continue
			out.append({"pos": Vector3(at.x, Topo.terrain(at.x, at.y), at.y),
					"dir": Vector3(-1.0, 0.0, -1.0).normalized()})
	return out


## What stands by the walls of the side streets: one house in three has something
## left beside its door - a pithos, a basket, a stack of firewood, an amphora, a
## quern, a bench. It is the cheapest way to stop a terrace of walls reading as
## scenery: somebody lives here, and put their jar down by the door.
## [{pos, kind, dir}]
const PROP_KINDS := ["pithos", "basket", "woodpile", "amphora", "quern", "bench"]

static func wall_props(houses: Array) -> Array:
	var out := []
	for hs: Dictionary in houses:
		var seed := hash(int(hs.opts.get("seed", 0)) * 7 + 11)
		if posmod(seed, 3) != 0:
			continue
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		var front := Vector3(hs.pos.x, 0, hs.pos.y) + basis * Vector3(0, 0, hs.d / 2.0)
		var dx: float = hs.opts.get("door_x", 0.0) + (1.05 if posmod(seed >> 6, 2) == 0 else -1.05)
		dx = clampf(dx, -hs.w / 2.0 + 0.7, hs.w / 2.0 - 0.7)
		var at := front + basis * Vector3(dx, 0, 0.42)
		at.y = Topo.terrain(at.x, at.z)
		out.append({"pos": at, "kind": PROP_KINDS[posmod(seed >> 3, PROP_KINDS.size())], "dir": basis.z})
	return out


## People going about their business on the terrace streets: each walks a length
## of one street and comes back, so somebody crosses a back lane now and then and
## the eye catches movement away from the main street. The routes are cut out of
## the streets' own polylines, so a walker follows the contour and never takes a
## shortcut through a house. [{"points": Array[Vector3], "key": String}]
static func walker_routes() -> Array:
	var out := []
	var runs := streets()
	if runs.size() < TERRACES_X.size():
		return out
	# four streets, each over a different stretch of its run: two terraces in
	# the middle of the slope, one near the top, one on the flat ground east
	var picks := [0, 2, 4, 6]
	for k in picks.size():
		if picks[k] >= runs.size():
			continue
		var run: PackedVector2Array = runs[picks[k]]
		if run.size() < 30:
			continue
		var start := 6 + k * 5
		var stop := mini(run.size() - 8, start + 10)
		if stop - start < 6:
			continue
		var there: Array[Vector3] = []
		for i in range(start, stop):
			var p := run[i]
			there.append(Vector3(p.x, Topo.surface(p.x, p.y), p.y))
		var points: Array[Vector3] = there.duplicate()
		for i in range(stop - 2, start - 1, -1):
			points.append(there[i - start])
		out.append({"points": points, "key": "walker%d" % k})
	return out


## The workshops that spill out of the houses into the lanes: a woman at a
## warp-weighted loom, a man weaving a basket in his doorway, a child sitting on
## a step. One house here and there carries a scene, and the scene keeps to the
## wall side of the lane so there is still room to walk past.
## [{pos, kind, yaw}]
const PORCH_KINDS := ["loom", "baskets", "child"]
## How far into the lane a scene may stand: a lane is 1.8 m across and the wall
## is 1.3 m off its centre.
const PORCH_OUT := 0.3

static func porch_scenes(houses: Array) -> Array:
	var out := []
	for hs: Dictionary in houses:
		if out.size() >= 5:
			break
		var seed := hash(int(hs.opts.get("seed", 0)) * 23 + 7)
		if posmod(seed, 19) != 0:
			continue
		if Topo.is_reserved(hs.pos.x, hs.pos.y, 3.0):
			continue
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		var at := Vector3(hs.pos.x, 0, hs.pos.y) + basis * Vector3(0, 0, hs.d / 2.0 + PORCH_OUT)
		at.y = Topo.surface(at.x, at.z)
		out.append({"pos": at, "kind": PORCH_KINDS[out.size() % PORCH_KINDS.size()], "yaw": hs.yaw})
	return out


## Wall lamps beside the doors of the back lanes: one house in nine, seeded, and
## never in the walked street's sight, so a night walk is a walk from one pool of
## lamplight to the next instead of a black corridor. [{pos, yaw}]
const LANE_LAMP_EVERY := 9
const LANE_LAMPS_MAX := 14

static func lane_lamps(houses: Array) -> Array:
	var out := []
	for hs: Dictionary in houses:
		if out.size() >= LANE_LAMPS_MAX:
			break
		if not hs.opts.get("door", false):
			continue
		var seed := hash(int(hs.opts.get("seed", 0)) * 29 + 11)
		if posmod(seed, LANE_LAMP_EVERY) != 0:
			continue
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		# beside the door, on the plaster, a hand off the corner of the frame
		var at := Vector3(hs.pos.x, 0, hs.pos.y) + basis * Vector3(float(hs.opts.get("door_x", 0.0)) + 0.95, 0, hs.d / 2.0 + 0.07)
		at.y = Topo.surface(at.x, at.z)
		out.append({"pos": at, "yaw": hs.yaw})
	return out


## A second place to draw water: a well head in a back lane, on a terrace where
## the houses leave a gap, with a woman standing at it and her jar beside her.
## The one on the forecourt has the round and the dialogue; this one is what a
## lane needs - a corner where people come, not just a wall to walk past.
## {} when no spot along the terraces is free.
static func fountain_at(houses: Array) -> Dictionary:
	var runs := streets()
	for r in TERRACES_X.size():
		if r >= runs.size():
			break
		var run: PackedVector2Array = runs[r]
		var i := 14
		while i < run.size() - 10:
			var p := run[i]
			var next := run[mini(i + 1, run.size() - 1)]
			var t := (next - p).normalized()
			var side := Vector2(-t.y, t.x)
			for s: float in [1.0, -1.0]:
				var at := p + side * s * 1.55
				if Topo.terrain(at.x, at.y) < 2.6 or absf(at.y) > WALL_Z - 8.0:
					continue
				if Topo.is_reserved(at.x, at.y, 2.0) or on_house(houses, at.x, at.y, 0.9):
					continue
				return {"pos": Vector3(at.x, Topo.surface(at.x, at.y), at.y),
						"dir": Vector3(side.x * s, 0, side.y * s)}
			i += 7
	return {}


## Where the watchman paces: up and down the street past the first crossing herm,
## three metres either way. Empty when the town has no crossing to stand on.
static func watch_route(houses: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var herms := crossing_herms(houses)
	if herms.is_empty():
		return out
	var h: Vector3 = herms[0].pos
	for dz: float in [-3.0, 3.0]:
		var p := Vector3(h.x, 0, h.z + dz)
		p.y = Topo.surface(p.x, p.z)
		out.append(p)
	return out


## The animals of the back streets: a dog asleep by the herm at a crossing, and
## hens scratching about by the lane's well. Both spots are already known to be
## clear of houses and of the lanes, because the herm and the well stand there.
## [{pos, kind}]
static func animal_spots(houses: Array) -> Array:
	var out := []
	var herms := crossing_herms(houses)
	if herms.size() >= 2:
		var at: Vector3 = herms[1].pos + Vector3(1.15, 0, -0.95)
		at.y = Topo.surface(at.x, at.z)
		out.append({"pos": at, "kind": "dog", "yaw": 0.6})
	var well := fountain_at(houses)
	if not well.is_empty():
		var flock_at: Vector3 = well.pos + Vector3(-1.25, 0, 1.05)
		flock_at.y = Topo.surface(flock_at.x, flock_at.z)
		out.append({"pos": flock_at, "kind": "flock", "yaw": 0.0})
	return out


## The dog and the hens. The dog keeps the habits of the one by the stoa (it
## sleeps, breathes, lifts its head); the hens roost at night on their own.
func _animals(houses: Array) -> void:
	for s: Dictionary in animal_spots(houses):
		var at: Vector3 = s.pos
		if String(s.kind) == "dog":
			var dog := Dog.new()
			dog.name = "LaneDog"
			dog.position = at
			dog.scale = Vector3.ONE * 1.1
			dog.rotation.y = float(s.yaw)
			add_child(dog)
			continue
		var birds := [["rooster", true], ["hen", false], ["hen_white", false]]
		for i in birds.size():
			var hen := Chicken.new()
			hen.name = "LaneHen%d" % i
			hen.home = at
			hen.radius = 1.4
			hen.feathers = birds[i][0]
			hen.rooster = birds[i][1]
			add_child(hen)


## The well head in the lane, with the woman who has come for water.
func _fountain(houses: Array) -> void:
	var spot := fountain_at(houses)
	if spot.is_empty():
		return
	var at: Vector3 = spot.pos
	var dir: Vector3 = spot.dir
	var kit := MeshKit.new()
	Arch.well_head(kit, at)
	add_child(kit.build("LaneWell"))
	var jar := Props.instance("amphora")
	jar.scale = Vector3.ONE * 0.8
	jar.position = at + dir * 0.75 + Vector3(0, 0.02, 0)
	add_child(jar)
	# the woman: standing with her hands on the rope, the way the carrier draws
	var woman: Npc = Npc.new()
	woman.name = "LaneCarrier"
	woman.npc_id = "water_carrier"
	woman.talkable = false
	woman.stops_for_player = false
	woman.solid = false
	woman.pose = "draw"
	woman.position = at + dir * 0.95
	# she stands on the far side and looks back at the curb: local -z must point
	# along -dir, so the yaw is atan2(dir.x, dir.z) and no half turn on top
	woman.rotation.y = atan2(dir.x, dir.z)
	add_child(woman)


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var houses := plan()
	var cottage := _pick_cottage(houses)
	if cottage:
		cottage["opts"]["cottage"] = true
	for hs: Dictionary in houses:
		_house(kit, glow, hs)
	_walls(kit)
	_herms(kit, houses)
	_wall_props(kit, houses)
	add_child(kit.build("Backdrop"))
	_glow = glow.build("WindowGlow")
	add_child(_glow)
	_lanes(houses)
	_terraces(houses)
	_hearths(houses)
	_voices(houses)
	_walkers()
	_porches(houses)
	_lane_lamps_at(houses)
	_fountain(houses)
	_animals(houses)
	_watchman_at(houses)
	if _cottage_lamp != null:
		_cottage_lamp.set_lit(false)


## The lamps of the back lanes, hung on the plaster beside a door. Their own
## process lights them with the town's dusk, like the cottage's one.
func _lane_lamps_at(houses: Array) -> void:
	for l: Dictionary in lane_lamps(houses):
		var lamp := WallLamp.new()
		lamp.position = l.pos + Vector3(0, 1.62, 0)
		lamp.rotation.y = l.yaw
		add_child(lamp)
		_lane_lamps.append(lamp)


## The porch scenes: the prop batched into the city mesh, the person on their own
## as an Npc, because they move.
func _porches(houses: Array) -> void:
	var kit := MeshKit.new()
	var i := 0
	for s: Dictionary in porch_scenes(houses):
		var yaw := float(s.yaw)
		var out := Basis.from_euler(Vector3(0, yaw, 0)) * Vector3(0, 0, 1)
		var at: Vector3 = s.pos
		match String(s.kind):
			"loom":
				Arch.loom(kit, Arch.frame(at, out))
				var loom_seat := at + out * 0.6
				_seat(kit, loom_seat, Figure.SEAT["weave"] - 0.04, "wood")
				_porch_people.append(_porch_npc(loom_seat, yaw + PI, "weave", 1.0, "Weaver%d" % i,
						{"woman": true, "kerchief": "cloth", "skirt": "long", "cloth": "chiton_blue"}))
			"baskets":
				Arch.basket_work(kit, Arch.frame(at, out))
				var bench_seat := at + out * 0.34
				_seat(kit, bench_seat, Figure.SEAT["mender"] - 0.03, "limestone")
				_porch_people.append(_porch_npc(bench_seat, yaw + PI, "mender", 1.0, "Basketmaker%d" % i,
						{"beard": 1, "hair": 2, "cloth": "chiton"}))
			_:
				_porch_people.append(_porch_npc(at + out * 0.1, yaw, "sit", 0.62, "Doorstep%d" % i,
						{"beard": 0, "hair": 0, "cloth": "chiton_ochre"}))
		i += 1
	add_child(kit.build("Porches"))


## Something to sit on: the poses put the pelvis at a seat height, so a worker
## without one under them hovers.
func _seat(kit: MeshKit, at: Vector3, height: float, mat: String) -> void:
	kit.box(mat, at + Vector3(0, height * 0.5, 0), Vector3(0.36, height, 0.36), [])


func _porch_npc(at: Vector3, yaw: float, pose: String, scale: float, key: String, look: Dictionary = {}) -> Npc:
	var n: Npc = Npc.new()
	n.name = key
	n.npc_id = key
	n.talkable = false
	n.stops_for_player = false
	n.solid = false
	n.pose = pose
	n.look = look
	n.figure_scale = scale
	n.position = at
	n.rotation.y = yaw
	add_child(n)
	return n


## The people on the terrace streets: they walk their stretch and come back, on
## the ground's own height, so a stepped lane does not leave them wading. No
## collider and no lines - they are weather, not furniture, and the scripted
## route never meets them.
func _walkers() -> void:
	for i in walker_routes().size():
		var route: Dictionary = walker_routes()[i]
		var points: Array[Vector3] = route.points
		if points.size() < 4:
			continue
		var n: Npc = Npc.new()
		n.name = "Walker%d" % i
		n.npc_id = String(route.key)
		n.talkable = false
		n.stops_for_player = false
		n.solid = false
		n.follow_ground = true
		n.figure_scale = 0.94 + 0.04 * float(i % 3)
		n.patrol_speed = 0.42 + 0.05 * float(i % 4)
		n.patrol_pause = 0.0
		n.position = points[0]
		var offsets := PackedVector3Array()
		for p: Vector3 in points:
			offsets.append(p - points[0])
		n.patrol = offsets
		# a walker walks: no pause at every sample point, only at the two ends,
		# and a plain stand there instead of the actor's declamation
		n.patrol_poses = PackedStringArray(["stand"])
		var pauses := PackedFloat32Array()
		pauses.resize(offsets.size())
		pauses[0] = 1.4
		pauses[offsets.size() - 1] = 1.4
		n.patrol_pauses = pauses
		add_child(n)
		_walker_people.append(n)


## A watchman with a lantern, out only after dusk: he paces the stretch of street
## by the first crossing herm. The model is an ordinary Npc; the lantern hangs on
## his right hand - a clay dish, a flame of its own and a small warm light - so
## the back street has one moving fire in it at night.
func _watchman_at(houses: Array) -> void:
	var route := watch_route(houses)
	if route.size() < 2:
		return
	var n: Npc = Npc.new()
	n.name = "Watchman"
	n.npc_id = "watchman"
	n.talkable = false
	n.stops_for_player = false
	n.solid = false
	n.follow_ground = true
	n.look = {"beard": 1, "hair": 2, "cloth": "chiton_dark"}
	n.position = route[0]
	var offsets := PackedVector3Array()
	for p: Vector3 in route:
		offsets.append(p - route[0])
	n.patrol = offsets
	n.patrol_speed = 0.34
	n.patrol_poses = PackedStringArray(["stand"])
	var pauses := PackedFloat32Array()
	pauses.resize(offsets.size())
	pauses[0] = 3.0
	pauses[offsets.size() - 1] = 3.0
	n.patrol_pauses = pauses
	add_child(n)
	var hand: Node3D = n.joints["r_elbow"]
	hand.add_child(_lantern())
	n.visible = false
	_watchman = n


## The lantern itself: a dish on a hook, a flame and a light that flickers.
func _lantern() -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern"
	root.position = Vector3(0, -0.3, 0)
	var kit := MeshKit.new()
	kit.lathe("clay", PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.09, 0.05), Vector2(0.1, 0.09)]), 8,
			Vector3.ZERO, 1.0, true)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	root.add_child(mi)
	var flame := Lamp._make_flame(0.06)
	flame.position = Vector3(0, 0.12, 0)
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.18, 0)
	light.light_color = Color(1.0, 0.62, 0.3)
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.set_script(preload("res://scripts/world/flicker.gd"))
	light.base_energy = 1.2
	light.amount = 0.35
	root.add_child(light)
	return root


## What goes on behind the walls: a hammer, a loom, a baby, a dog, a woman
## humming, each on its own house and its own clock.
func _voices(houses: Array) -> void:
	var voices := StreetVoices.new()
	voices.name = "Voices"
	voices.houses = houses
	add_child(voices)


func _house(kit: MeshKit, glow: MeshKit, hs: Dictionary) -> void:
	var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
	var center := Vector3(hs.pos.x, 0, hs.pos.y)
	var lo := INF
	var hi := -INF
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var q := center + basis * Vector3(sx * hs.w, 0, sz * hs.d)
			var t := Topo.terrain(q.x, q.z)
			lo = minf(lo, t)
			hi = maxf(hi, t)
	var front := center + basis * Vector3(0, 0, hs.d / 2.0)
	# The house stands on its street, not on the highest corner of its plot: a
	# door hanging a metre over the lane is what makes a row of houses read as a
	# film set. The slope behind the house is taken up by the foundation, the way
	# a terraced town is cut into its hill.
	front.y = Topo.terrain(front.x, front.z)
	var opts: Dictionary = hs.opts.duplicate()
	# Facade detail is derived from the house's own seed and not drawn from
	# plan()'s sequence: the city must not shift by a metre because a door got a
	# frame. Two doors in five sit in a stone reveal, one in five stands open, and
	# most windows get a sill and shutters.
	var ds := hash(int(opts.get("seed", 0)))
	opts["recess"] = posmod(ds, 5) < 2
	opts["ajar"] = opts.get("door", false) and posmod(ds >> 2, 5) == 0
	opts["frames"] = posmod(ds >> 5, 3) != 0
	# the ground along the front is not flat either: a step or two by the door
	var door_at := front + basis * Vector3(float(opts.get("door_x", 0.0)), 0, 0.3)
	opts["steps"] = clampi(roundi((front.y - Topo.terrain(door_at.x, door_at.z)) / Arch.FLOOR_STEP), 0, 2)
	opts["drop"] = maxf(front.y - lo, 0.0) + 1.0
	opts["glow"] = glow
	hs["front"] = front
	var xf := Transform3D(basis, front)
	if opts.get("cottage", false):
		var info := Arch.cottage(kit, xf, hs.w, hs.d, hs.h, opts)
		_cottage_at = xf
		_cottage_lamp = WallLamp.new()
		_cottage_lamp.name = "DoorLamp"
		_cottage_lamp.position = xf * (info["lamp"] as Vector3)
		_cottage_lamp.rotation.y = hs.yaw
		add_child(_cottage_lamp)
		_place_woman(xf, info, hs.yaw)
		# the room is not a cellar: a small warm light of its own
		var room := OmniLight3D.new()
		room.position = xf * Vector3(0, 1.7, -hs.d * 0.5)
		room.light_color = Color(1.0, 0.66, 0.35)
		room.omni_range = 5.0
		room.light_energy = 0.0
		room.set_script(preload("res://scripts/world/flicker.gd"))
		room.base_energy = 0.85
		room.amount = 0.2
		add_child(room)
	else:
		Arch.house(kit, xf, hs.w, hs.d, hs.h, opts)


## The woman of the house, standing on the new floor between the bench and the
## shelf, spinning wool. Her look (Figure.LOOKS) dresses her as a woman: hair,
## kerchief, long chiton, because an empty room with a bench in it could be anyone's.
func _place_woman(xf: Transform3D, info: Dictionary, yaw: float) -> void:
	var woman := Npc.new()
	woman.name = "CottageWoman"
	woman.npc_id = "cottage_woman"
	woman.talkable = false
	woman.stops_for_player = false
	woman.pose = "spin"
	woman.body_mat = "chiton"  # her own dye from Figure.LOOKS
	woman.position = xf * (info["woman"] as Vector3)
	woman.rotation.y = yaw
	add_child(woman)
	# she spins: distaff in the left hand, the spindle hanging from the right
	Spindle.hold_distaff(woman.joints)
	var spindle := Spindle.new()
	spindle.name = "Spindle"
	spindle.hand = Spindle.right_hand(woman.joints)
	add_child(spindle)
	_woman = woman

## The corner herms, batched into the city mesh: four boxes each.
func _herms(kit: MeshKit, houses: Array) -> void:
	for h: Dictionary in crossing_herms(houses):
		Arch.herm(kit, Arch.frame(h.pos, h.dir), 1.35)
	kit.xform = Transform3D.IDENTITY


## What the neighbours left by their walls, batched into the same mesh.
func _wall_props(kit: MeshKit, houses: Array) -> void:
	for p: Dictionary in wall_props(houses):
		var at: Vector3 = p.pos
		var xf := Transform3D(Basis(Vector3.UP, atan2(p.dir.x, p.dir.z)), at)
		kit.xform = xf
		match String(p.kind):
			"pithos":
				kit.lathe("clay", PackedVector2Array([Vector2(0.12, 0.0), Vector2(0.26, 0.18), Vector2(0.28, 0.4),
						Vector2(0.22, 0.56), Vector2(0.17, 0.6)]), 8, Vector3.ZERO, 1.0, true)
			"basket":
				kit.lathe("basket", PackedVector2Array([Vector2(0.14, 0.0), Vector2(0.2, 0.2), Vector2(0.21, 0.26)]), 8,
						Vector3.ZERO, 2.0, true, "basket")
			"woodpile":
				for i in 4:
					kit.box("wood", Vector3(-0.42 + i * 0.28, 0.1, 0), Vector3(0.22, 0.2, 0.5), [])
				for i in 3:
					kit.box("wood", Vector3(-0.28 + i * 0.28, 0.3, 0), Vector3(0.22, 0.2, 0.5), [])
			"amphora":
				Props.amphora(kit)
			"quern":
				kit.box("limestone", Vector3(0, 0.06, 0), Vector3(0.56, 0.12, 0.44), [])
				kit.lathe("limestone", PackedVector2Array([Vector2(0.22, 0.12), Vector2(0.24, 0.2), Vector2(0.12, 0.24)]),
						10, Vector3.ZERO, 1.0, true)
				kit.box("wood", Vector3(0.28, 0.2, 0), Vector3(0.26, 0.04, 0.04), [])
			_:
				# a bench, built without a collider like the rest of the goods: the
				# streets of the backdrop are walked by the scripted route, and a
				# bench with a body in it stopped the bot dead on its way to the beach
				kit.box("limestone", Vector3(0, 0.42, 0), Vector3(1.2, 0.14, 0.5), ["bottom"])
				for sx: float in [1.0, -1.0]:
					kit.box("limestone", Vector3(sx * 0.3, 0.18, 0), Vector3(0.3, 0.36, 0.42), ["bottom"])
	kit.xform = Transform3D.IDENTITY


## Trodden earth between the rows, hugging the ground.
func _lanes(houses: Array) -> void:
	var kit := MeshKit.new()
	for seg: Array in lanes(houses):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var side := (b - a).normalized().orthogonal() * LANE_HALF
		var pts := [a - side, b - side, b + side, a + side]  # counter-clockwise seen from above
		var v := []
		for p: Vector2 in pts:
			v.append(Vector3(p.x, Topo.terrain(p.x, p.y) + 0.08, p.y))
		kit.quad("path", v[0], v[1], v[2], v[3])
	var node := kit.build("Lanes")
	add_child(node)
	(node.get_node("Mesh") as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Retaining walls along the downhill edge of each terrace street (left open
## where a stepped lane comes through), and stone steps down the steep lanes.
func _terraces(houses: Array) -> void:
	var kit := MeshKit.new()
	var stair_runs := stairs()
	for run: PackedVector2Array in streets():
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var m := (a + b) / 2.0
			if not _lane_ok(houses, m) or _dist_to(stair_runs, m) < 2.2:
				continue
			var t := (b - a).normalized()
			var down := Vector2(t.y, -t.x)
			if down.x < 0.0:
				down = -down  # east, downhill
			var e := m + down * (LANE_HALF + 0.2)
			var top := Topo.terrain(m.x, m.y) + 0.35
			var foot := Topo.terrain(e.x + down.x * 0.8, e.y + down.y * 0.8)
			if top - foot < 0.5:
				continue  # the ground hardly falls here: no wall needed
			kit.xform = Transform3D(Basis(Vector3.UP, atan2(-t.y, t.x)), Vector3(e.x, (top + foot - 0.4) / 2.0, e.y))
			kit.solid_box("limestone", Vector3.ZERO, Vector3(a.distance_to(b) + 0.08, top - foot + 0.4, 0.45), ["bottom"])
	for run: PackedVector2Array in stair_runs:
		for i in run.size() - 1:
			var a := run[i]
			var b := run[i + 1]
			var t := (b - a).normalized()
			var n := int(a.distance_to(b) / 1.1)
			for k in n:
				var p := a.lerp(b, (k + 0.5) / n)
				var q := p + t * 1.1
				var drop := Topo.terrain(p.x, p.y) - Topo.terrain(q.x, q.y)
				if drop < 0.15 or not _lane_ok(houses, p):
					continue
				kit.xform = Transform3D(Basis(Vector3.UP, atan2(-t.y, t.x)), Vector3(p.x, Topo.terrain(p.x, p.y) + 0.02, p.y))
				kit.box("limestone", Vector3.ZERO, Vector3(0.3, 0.16, LANE_HALF * 2.0), ["bottom"])
	kit.xform = Transform3D.IDENTITY
	add_child(kit.build("Terraces"))


## Smoke from the hearths under some roofs, through the day.
func _hearths(houses: Array) -> void:
	var pots := MeshKit.new()
	for i in houses.size():
		if i % SMOKE_EVERY != 3:
			continue
		var hs: Dictionary = houses[i]
		var basis := Basis.from_euler(Vector3(0, hs.yaw, 0))
		var gable: bool = hs.opts.roof == "gable"
		var ridge := minf(hs.d * 0.22, 1.4) if gable else 0.0
		var base: Vector3 = hs.front + basis * Vector3(hs.w * 0.25, hs.h + ridge, -hs.d / 2.0)
		# no chimneys: a terracotta smoke pot astride the ridge tiles, or on a flat
		# roof a smoke hole with a clay rim; the smoke leaves from its mouth
		var mouth := 0.55 if gable else 0.16
		if gable:
			pots.lathe("clay", PackedVector2Array([Vector2(0.24, -0.15), Vector2(0.2, 0.3), Vector2(0.15, 0.5), Vector2(0.17, mouth)]), 7,
					base, 2.0, false, "dark", true)
		else:
			pots.lathe("clay", PackedVector2Array([Vector2(0.4, -0.05), Vector2(0.36, mouth)]), 8, base, 2.0, false, "dark", true)
		var top := base + Vector3(0, mouth, 0)
		var smoke := Lamp._make_flame(0.4)
		var pm: ParticleProcessMaterial = smoke.process_material
		var g := Gradient.new()
		g.set_color(0, Color(0.36, 0.34, 0.32))
		g.set_color(1, Color(0.27, 0.26, 0.25))
		(pm.color_ramp as GradientTexture1D).gradient = g
		pm.initial_velocity_min = 0.25
		pm.initial_velocity_max = 0.45
		pm.spread = 18.0
		pm.gravity = Vector3(0.2, 0.1, 0)  # the breeze off the strait leans it a little
		pm.scale_min = 0.6
		pm.scale_max = 1.3
		# each puff swells as it rises, then shrinks away: a ragged plume, not a column
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(0.5, 1.0))
		curve.add_point(Vector2(1.0, 0.2))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
		(smoke.draw_pass_1.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		smoke.amount = 12
		smoke.lifetime = 4.5
		smoke.position = top
		smoke.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 6, 6))
		smoke.emitting = true
		smoke.visible = true
		add_child(smoke)
		_smoke.append(smoke)
	add_child(pots.build("SmokePots"))


## The house nearest the sea on the right hand as you come down: the one you can
## walk into. Chosen as the easternmost house on the +z side, so it is always the
## same house whatever the city grows into.
func _pick_cottage(houses: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_x := -INF
	for hs: Dictionary in houses:
		var z: float = hs.pos.y
		if z < 0.0:
			continue
		if hs.pos.x > best_x:
			best_x = hs.pos.x
			best = hs
	return best


func _process(_delta: float) -> void:
	var hour: float = _atm.t if _atm else 0.0
	_glow.visible = hour >= GLOW_FROM
	if _cottage_lamp != null:
		_cottage_lamp.set_lit(hour >= WallLamp.DUSK)
	for lamp: WallLamp in _lane_lamps:
		lamp.set_lit(hour >= WallLamp.DUSK)
	# Night in the back streets: the looms and the baskets are carried in, half
	# the walkers go home, and the watchman comes out with his lantern.
	var night := hour >= WallLamp.DUSK
	if night != _night:
		_night = night
		for p: Npc in _porch_people:
			p.visible = not night
		for i in _walker_people.size():
			_walker_people[i].visible = not night or i % 2 == 0
		if _watchman != null:
			_watchman.visible = night
	var day := hour < 0.95
	for s in _smoke:
		if s.emitting != day:
			s.emitting = day


func _walls(kit: MeshKit) -> void:
	for side: float in [1.0, -1.0]:
		var x := -110.0
		var seg := 0
		while x < 62.0:
			var x2 := x + 10.0
			var a := Vector3(x, Topo.terrain(x, side * WALL_Z), side * WALL_Z)
			var b := Vector3(x2, Topo.terrain(x2, side * WALL_Z), side * WALL_Z)
			var base := minf(a.y, b.y) - 1.5
			var top := maxf(a.y, b.y) + 4.0
			kit.solid_box("limestone", Vector3((x + x2) / 2.0, (base + top) / 2.0, side * WALL_Z), Vector3(10.2, top - base, 1.8), ["bottom"])
			if seg % 4 == 0:
				var tb := a.y - 1.5
				kit.solid_box("limestone", Vector3(x, tb + 3.6, side * WALL_Z), Vector3(6.0, 7.2, 6.0), ["bottom"])
				kit.box("roof", Vector3(x, tb + 7.3, side * WALL_Z), Vector3(6.4, 0.25, 6.4), ["bottom"])
			x = x2
			seg += 1
