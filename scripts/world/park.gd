extends District
## The grove either side of the theatre, on the summit terrace. A Greek acropolis
## was crowded with greenery and dedications, not just with stone: two planted
## beds with olives and cypresses, benches facing the orchestra, and figures on
## plinths. The figures are scenery, not a claim - the one fact they lean on is
## that the excavators of Panticapaeum lifted a marble goddess more than 2.5 m
## tall out of the fill of the palace well (see the README).

## The two beds, [x, z] of the corner and [width, depth]. They run along the north
## and south edges of the terrace, clear of the seat ring and of the walk to the
## steps down.
const BEDS := [Rect2(-93.0, 5.4, 9.2, 1.9), Rect2(-93.0, -7.3, 9.2, 1.9)]
## Figure per bed: [x, z, kind]. Kinds: "youth" (bronze), "goddess" (marble, helmeted),
## "herm" (a pillar with a head). Each faces the orchestra.
const FIGURES := [
	[-88.0, 6.9, "youth"],
	[-84.6, 6.9, "herm"],
	[-89.0, -6.72, "goddess"],
]
## Trees: [x, z, "olive"/"cypress", scale].
const TREES := [
	[-92.2, 6.35, "cypress", 1.0],
	[-90.3, 6.30, "olive", 0.85],
	[-85.4, 6.35, "olive", 0.75],
	[-92.4, -6.35, "cypress", 0.92],
	[-90.4, -6.30, "olive", 0.8],
	[-86.6, -6.35, "olive", 0.9],
]
## Benches: [x, z, yaw_deg] - the seat faces the orchestra.
const BENCHES := [
	[-86.4, 6.55, 180.0],
	[-84.4, -6.6, 0.0],
]


static func bed_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b: Rect2 in BEDS:
		out.append(b)
	return out


## Where each figure stands, base on the terrace paving.
static func figure_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f: Array in FIGURES:
		out.append(Vector3(f[0], Topo.HILL_PLATFORM_TOP, f[1]))
	return out


func _ready() -> void:
	var kit := MeshKit.new()
	var top := Topo.HILL_PLATFORM_TOP
	for bed: Rect2 in BEDS:
		_bed(kit, bed, top)
	for f: Array in FIGURES:
		_figure(kit, f, top)
	for b: Array in BENCHES:
		Arch.bench(kit, Arch.frame(Vector3(b[0], top, b[1]), Vector3.RIGHT), 1.5)
	add_child(kit.build("Park"))
	_trees(top)


## A bed of soil held by a low kerb: the paving of the terrace keeps its edges,
## the roots get earth, and you can step over the kerb without noticing it.
func _bed(kit: MeshKit, bed: Rect2, top: float) -> void:
	var c := bed.get_center()
	kit.box("earth", Vector3(c.x, top + 0.02, c.y), Vector3(bed.size.x, 0.04, bed.size.y), ["bottom"])
	for sz: float in [-1.0, 1.0]:
		kit.solid_box("limestone", Vector3(c.x, top + 0.065, c.y + sz * (bed.size.y * 0.5 + 0.08)),
				Vector3(bed.size.x + 0.32, 0.13, 0.16), ["bottom"])
		kit.solid_box("limestone", Vector3(c.x + sz * (bed.size.x * 0.5 + 0.08), top + 0.065, c.y),
				Vector3(0.16, 0.13, bed.size.y), ["bottom"])


func _figure(kit: MeshKit, f: Array, top: float) -> void:
	var at := Vector3(f[0], top, f[1])
	# local +z must look back at the orchestra, so the north bed faces south
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(180.0 if f[1] > 0.0 else 0.0)), at)
	match String(f[2]):
		"goddess":
			Arch.statue(kit, xf, {"h": 2.4, "mat": "column", "helmet": true, "plinth": 0.6})
		"youth":
			Arch.statue(kit, xf, {"h": 1.7, "mat": "bronze", "arm": "up"})
		"herm":
			Arch.herm(kit, xf, 1.6)


func _trees(top: float) -> void:
	for t: Array in TREES:
		var at := Vector3(t[0], top + 0.04, t[1])
		var s := float(t[3])
		if String(t[2]) == "cypress":
			place("cypress", at, 0.0, Vector3.ONE * s)
		else:
			place("olive_tree", at, 20.0, Vector3(s * 1.25, s * 0.8, s * 1.25))
