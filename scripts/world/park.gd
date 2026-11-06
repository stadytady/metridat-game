extends District
## The park on the flanks of the acropolis. North and south of the theatre the
## hill's shoulders were empty ground - the city below starts at the street - so
## the whole slope is laid out as a grove: a long stone walk on each side, two
## cross walks, olive rows between them, figures on their plinths along the walks
## and benches facing them. It runs from the terrace parapet out to the brow over
## the roofs, some 25 m each way, and back over the flat top of the hill to an
## outer walk that closes the loop: a grove about 25 x 30 m on either side.
##
## The grove is one mesh: a hundred-odd trees as separate nodes would cost more draw calls
## than the whole city, so `Props.olive_tree` takes a transform and writes into a
## shared kit.

## The long walk: |z| of its centreline, half width, west and east ends.
const WALK_Z := 19.0
const WALK_HALF := 1.4
const WALK_FROM := -96.0
const WALK_TO := -71.0
## Where the walk comes out of the terrace parapet (a gate is cut for it there).
const GATE_X := -86.0
const TERRACE_EDGE := 7.7
## Cross walks: x, half width, and the |z| they span - from the inner rows out
## to the outer walk, so the walks close into a loop.
const CROSS_X := [-92.0, -78.0]
const CROSS_HALF := 1.0
const CROSS_FROM := 12.4
const CROSS_TO := 30.4
## The outer walk: |z|, joining the far ends of the cross walks.
const OUTER_Z := 30.4
## Olive rows, |z| offsets from the street axis: three inside the long walk,
## three between it and the outer walk, three beyond. The flat top of the hill
## runs out to |z| 48, so the grove has room.
const ROWS := [11.0, 13.6, 16.2, 21.8, 24.4, 27.0, 33.8, 36.4, 39.0]
const TREE_STEP := 3.6
## How much room an olive leaves, from a walk's edge or a thing's centre: its
## crown may shade the walk a little, never stand in it.
const TREE_CLEAR := 1.0
const FIGURE_CLEAR := 2.4
const BENCH_CLEAR := 1.9
## Figures: [x, |z|, kind, yaw on the north side in degrees]. Figures face +z
## (Arch.statue/herm); 180 turns them to the long walk, 90 down it to the east.
## The south side mirrors them (yaw 180 - a). They lean on one real find - the
## marble goddess from Panticapaeum's palace well, more than 2.5 m in the
## museum's description (see the README) - and she closes the long walk at its
## west end, looking down it to the sea.
const FIGURES := [
	[-98.4, 19.0, "goddess", 90.0],
	[-89.6, 21.8, "youth", 180.0],
	[-81.6, 21.8, "youth", 180.0],
	[-92.0, 33.2, "herm", 180.0],
	[-78.0, 33.2, "herm", 180.0],
]
## Benches: [x, |z|], each across the walk from a figure, under no tree.
const BENCHES := [
	[-89.6, 16.8],
	[-81.6, 16.8],
	[-85.0, 28.0],
]
## Where the marble head lies (a find): beside the north gate walk, east of it.
const HEAD_FIND := Vector2(-84.3, 11.2)
## Cypresses: [x, |z|]. Two pairs flank the walk down from the terrace gate and
## two stand behind the goddess: the dark verticals over the round olives.
const CYPRESSES := [
	[-88.4, 12.8], [-83.6, 12.8], [-88.4, 15.6], [-83.6, 15.6],
	[-98.6, 16.6], [-98.6, 21.4],
]


static func _line(side: float, a: Vector2, b: Vector2, step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := maxi(1, ceili(a.distance_to(b) / step))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var z := side * p.y
		out.append(Vector3(p.x, Topo.terrain(p.x, z) + 0.05, z))
	return out


## The ground the walk is laid on, sampled so it follows the slope.
static func walk_points(side: float) -> Array[Vector3]:
	return _line(side, Vector2(WALK_FROM, WALK_Z), Vector2(WALK_TO, WALK_Z), 3.0)


## From the terrace gate down onto the long walk. The gate steps (hilltop.gd)
## take the drop from the platform; the walk starts at their foot.
static func connector_points(side: float) -> Array[Vector3]:
	return _line(side, Vector2(GATE_X, TERRACE_EDGE + 1.35), Vector2(GATE_X, WALK_Z), 1.5)


static func cross_points(side: float, x: float) -> Array[Vector3]:
	return _line(side, Vector2(x, CROSS_FROM), Vector2(x, CROSS_TO), 1.5)


static func outer_points(side: float) -> Array[Vector3]:
	return _line(side, Vector2(CROSS_X[0], OUTER_Z), Vector2(CROSS_X[1], OUTER_Z), 2.0)


## Every walk of one side, each with its half width.
static func walks(side: float) -> Array:
	var out := [[walk_points(side), WALK_HALF], [connector_points(side), CROSS_HALF], [outer_points(side), WALK_HALF]]
	for cx: float in CROSS_X:
		out.append([cross_points(side, cx), CROSS_HALF])
	return out


## Distance from p (x, z) to the edge of the nearest walk (negative on it).
static func walk_clearance(p: Vector2) -> float:
	var best := INF
	for side: float in [1.0, -1.0]:
		for w: Array in walks(side):
			var pts: Array[Vector3] = w[0]
			for i in pts.size() - 1:
				var a := Vector2(pts[i].x, pts[i].z)
				var b := Vector2(pts[i + 1].x, pts[i + 1].z)
				var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				best = minf(best, p.distance_to(a + ab * t) - float(w[1]))
	return best


## The things on the ground of the park: [x, z] of every figure and bench.
static func _mirrored(list: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Array in list:
		for side: float in [1.0, -1.0]:
			out.append(Vector2(e[0], side * float(e[1])))
	return out


static func _clear_of(p: Vector2, spots: Array[Vector2], r: float) -> bool:
	for q: Vector2 in spots:
		if p.distance_to(q) < r:
			return false
	return true


## Every olive of the grove: [x, z]. A tree goes wherever its row has room: off
## the walks, and far enough from figures and benches for its crown not to
## swallow them.
static func tree_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var figures := _mirrored(FIGURES)
	var benches := _mirrored(BENCHES)
	var cypresses := _mirrored(CYPRESSES)
	for side: float in [1.0, -1.0]:
		for r in ROWS.size():
			var row: float = ROWS[r]
			# every other row shifted half a step: the old quincunx planting
			var x := WALK_FROM + 0.8 + float(r % 2) * TREE_STEP * 0.5
			while x <= WALK_TO - 0.8:
				var p := Vector2(x, side * row)
				if walk_clearance(p) > TREE_CLEAR and _clear_of(p, figures, FIGURE_CLEAR) \
						and _clear_of(p, benches, BENCH_CLEAR) and _clear_of(p, cypresses, TREE_CLEAR):
					out.append(p)
				x += TREE_STEP
	return out


static func cypress_spots() -> Array[Vector2]:
	return _mirrored(CYPRESSES)


## Where each figure stands, base on the ground, in FIGURES order, north first.
static func figure_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector2 in _mirrored(FIGURES):
		out.append(Vector3(p.x, Topo.terrain(p.x, p.y) + 0.05, p.y))
	return out


## Which way each figure looks (x, z), in figure_spots() order.
static func figure_facing() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for f: Array in FIGURES:
		for side: float in [1.0, -1.0]:
			var a := deg_to_rad(float(f[3]) if side > 0.0 else 180.0 - float(f[3]))
			out.append(Vector2(sin(a), cos(a)))
	return out


func _ready() -> void:
	var kit := MeshKit.new()
	for side: float in [1.0, -1.0]:
		for w: Array in walks(side):
			Arch.path(kit, w[0], w[1])
	_figures(kit)
	_benches(kit)
	_grove(kit)
	add_child(kit.build("Park"))
	# the marble head on its straw by the north gate walk, looking at the walk
	spawn_inspectable("goddess_head", Vector3(HEAD_FIND.x, Topo.terrain(HEAD_FIND.x, HEAD_FIND.y), HEAD_FIND.y), -90.0)


func _grove(kit: MeshKit) -> void:
	var i := 0
	for p: Vector2 in tree_spots():
		# A little scatter in size and turn, none in place: the rows are the point.
		var s := 0.75 + 0.1 * float(i % 4)
		var spin := float(i % 7) * 0.9
		var xf := Transform3D(Basis(Vector3.UP, spin).scaled(Vector3(s * 1.15, s * 0.8, s * 1.15)),
				Vector3(p.x, Topo.terrain(p.x, p.y) - 0.05, p.y))
		Props.olive_tree(kit, 5000 + i, xf)
		i += 1
	for p: Vector2 in cypress_spots():
		kit.xform = Transform3D(Basis.IDENTITY.scaled(Vector3(0.9, 0.85, 0.9)), Vector3(p.x, Topo.terrain(p.x, p.y) - 0.05, p.y))
		Props.cypress(kit)
	kit.xform = Transform3D.IDENTITY


func _figures(kit: MeshKit) -> void:
	var spots := figure_spots()
	var looks := figure_facing()
	for i in spots.size():
		var f: Array = FIGURES[i / 2]
		var xf := Transform3D(Basis(Vector3.UP, atan2(looks[i].x, looks[i].y)), spots[i])
		match String(f[2]):
			"goddess":
				Arch.statue(kit, xf, {"h": 2.2, "mat": "column", "helmet": true, "plinth": 0.45})
			"youth":
				Arch.statue(kit, xf, {"h": 1.7, "mat": "bronze_old", "arm": "up", "plinth": 0.35})
			_:
				Arch.herm(kit, xf, 1.5)


func _benches(kit: MeshKit) -> void:
	for p: Vector2 in _mirrored(BENCHES):
		var at := Vector3(p.x, Topo.terrain(p.x, p.y) + 0.05, p.y)
		Arch.bench(kit, Arch.frame(at, Vector3.RIGHT), 1.6)
