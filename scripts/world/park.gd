extends District
## The park on the flanks of the acropolis. North and south of the theatre the
## hill's shoulders were empty ground - the city below starts at the street - so
## the whole slope is laid out as a grove: a long stone walk on each side, two
## cross walks, olive rows between them, figures on their plinths along the walks
## and benches facing them. It runs from the terrace parapet out to the brow over
## the roofs, some 25 m each way.
##
## The grove is one mesh: fifty trees as separate nodes would cost more draw calls
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
## Short cross walks: x, half width, and the |z| they span.
const CROSS_X := [-92.0, -78.0]
const CROSS_HALF := 1.0
const CROSS_FROM := 12.4
const CROSS_TO := 24.6
## Olive rows, |z| offsets from the street axis. The two inner rows flank the
## long walk, the two outer ones close the grove.
const ROWS := [11.0, 13.6, 16.2, 21.8, 24.4, 27.0]
const TREE_STEP := 4.2
## Figures: [x, |z|, kind]; each faces the walk from its outer side. They lean on
## one real find - the marble goddess from Panticapaeum's palace well, more than
## 2.5 m in the museum's description (see the README).
const FIGURES := [
	[-94.8, 21.8, "herm"],
	[-88.0, 21.6, "youth"],
	[-82.0, 21.8, "youth"],
	[-73.0, 16.4, "goddess"],
]
## Benches: [x, |z|], facing the walk.
const BENCHES := [
	[-90.0, 17.0],
	[-80.0, 17.0],
]


## The ground the walk is laid on, sampled so it follows the slope.
static func walk_points(side: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x := WALK_FROM
	while x <= WALK_TO + 0.01:
		var z := side * WALK_Z
		out.append(Vector3(x, Topo.terrain(x, z) + 0.05, z))
		x += 3.0
	return out


## From the terrace gate down onto the long walk.
static func connector_points(side: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	# the gate steps (hilltop.gd) take the drop from the platform; the walk
	# starts at their foot
	var z := side * (TERRACE_EDGE + 1.35)
	while absf(z) <= WALK_Z + 0.01:
		out.append(Vector3(GATE_X, Topo.terrain(GATE_X, z) + 0.05, z))
		z += side * 1.5
	return out


static func cross_points(side: float, x: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var z := side * CROSS_FROM
	while absf(z) <= CROSS_TO + 0.01:
		out.append(Vector3(x, Topo.terrain(x, z) + 0.05, z))
		z += side * 1.5
	return out


## Every olive of the grove: [x, z]. Trees keep clear of the walks, of the two
## cross walks and of the gate walk, which all run through the rows.
static func tree_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for side: float in [1.0, -1.0]:
		for row: float in ROWS:
			var x := WALK_FROM + 0.8
			while x <= WALK_TO - 0.8:
				var blocked := false
				# the cross walks only span part of the depth
				if absf(row) > CROSS_FROM - 1.8 and absf(row) < CROSS_TO + 1.8:
					for cx: float in CROSS_X:
						if absf(x - cx) < CROSS_HALF + 1.6:
							blocked = true
				# the gate walk runs out along one x, up to the long walk
				if absf(row) < WALK_Z + 0.5 and absf(x - GATE_X) < CROSS_HALF + 1.6:
					blocked = true
				if not blocked:
					out.append(Vector2(x, side * row))
				x += TREE_STEP
	return out


## Where each figure stands, base on the ground.
static func figure_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f: Array in FIGURES:
		for side: float in [1.0, -1.0]:
			var z: float = side * float(f[1])
			out.append(Vector3(f[0], Topo.terrain(f[0], z) + 0.05, z))
	return out


func _ready() -> void:
	var kit := MeshKit.new()
	for side: float in [1.0, -1.0]:
		Arch.path(kit, walk_points(side), WALK_HALF)
		Arch.path(kit, connector_points(side), CROSS_HALF)
		for cx: float in CROSS_X:
			Arch.path(kit, cross_points(side, cx), CROSS_HALF)
		_figures(kit, side)
		_benches(kit, side)
	_grove(kit)
	add_child(kit.build("Park"))


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


func _figures(kit: MeshKit, side: float) -> void:
	for f: Array in FIGURES:
		var z: float = side * float(f[1])
		var at := Vector3(f[0], Topo.terrain(f[0], z) + 0.05, z)
		# local +z looks back at the walk, so the north side faces south
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(180.0 if side > 0.0 else 0.0)), at)
		match String(f[2]):
			"goddess":
				Arch.statue(kit, xf, {"h": 2.2, "mat": "column", "helmet": true, "plinth": 0.45})
			"youth":
				Arch.statue(kit, xf, {"h": 1.7, "mat": "bronze_old", "arm": "up", "plinth": 0.35})
			_:
				Arch.herm(kit, xf, 1.5)


func _benches(kit: MeshKit, side: float) -> void:
	for b: Array in BENCHES:
		var z: float = side * float(b[1])
		var at := Vector3(b[0], Topo.terrain(b[0], z) + 0.05, z)
		Arch.bench(kit, Arch.frame(at, Vector3.RIGHT), 1.6)
