extends "res://tests/test_case.gd"
## The grove either side of the theatre: beds on the terrace, figures on their
## plinths in the beds, nothing of it on the route the bot walks, and the
## geometry really built (a statue helper that returns a height but no triangles
## would pass a position test and still leave an empty terrace).

const PARK := preload("res://scripts/world/park.gd")
const THEATRE := preload("res://scripts/world/theatre.gd")


## The terrace is a rectangle of paving; nothing of the park may leave it.
func _on_terrace(p: Vector3, margin: float = 0.0) -> bool:
	var c := Topo.HILL_CENTER
	var h := Topo.HILL_HALF
	return absf(p.x - c.x) <= h.x - margin and absf(p.z - c.y) <= h.y - margin


## Seat blocks are boxes turned about y: their corners give the footprint.
func _seat_footprints() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b: Array in THEATRE.seat_blocks():
		var centre: Vector3 = b[0]
		var yaw: float = b[1]
		var size: Vector3 = b[2]
		var basis := Basis(Vector3.UP, yaw)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for sx: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				var corner: Vector3 = centre + basis * Vector3(size.x * sx, 0.0, size.z * sz)
				lo = Vector2(minf(lo.x, corner.x), minf(lo.y, corner.z))
				hi = Vector2(maxf(hi.x, corner.x), maxf(hi.y, corner.z))
		out.append(Rect2(lo, hi - lo))
	return out


func test_beds_stay_on_the_terrace_and_off_the_seats() -> void:
	var beds := PARK.bed_rects()
	check(beds.size() == 2, "expected two beds, got %d" % beds.size())
	var seats := _seat_footprints()
	for bed: Rect2 in beds:
		check(_on_terrace(Vector3(bed.position.x, Topo.HILL_PLATFORM_TOP, bed.position.y), 0.0),
				"a bed starts off the terrace at %s" % bed.position)
		check(_on_terrace(Vector3(bed.end.x, Topo.HILL_PLATFORM_TOP, bed.end.y), 0.0),
				"a bed runs off the terrace to %s" % bed.end)
		for s: Rect2 in seats:
			check(not bed.intersects(s, false), "a bed grows through a seat block at %s" % s.position)


func test_every_figure_stands_in_a_bed() -> void:
	var beds := PARK.bed_rects()
	var spots := PARK.figure_spots()
	check(spots.size() >= 3, "only %d figures" % spots.size())
	for p: Vector3 in spots:
		check(is_equal_approx(p.y, Topo.HILL_PLATFORM_TOP),
				"a figure floats or sinks: %.2f vs %.2f" % [p.y, Topo.HILL_PLATFORM_TOP])
		check(_on_terrace(p, 0.6), "a figure stands too near the parapet at %s" % p)
		var inside := false
		for bed: Rect2 in beds:
			if bed.grow(0.35).has_point(Vector2(p.x, p.z)):
				inside = true
		check(inside, "a figure stands on bare paving at %s" % p)


func test_the_grove_keeps_out_of_the_walk() -> void:
	# The bot crosses the terrace on its way to Fedr, the sherd and the steps.
	var route := [Vector2(-88.4, -0.8), Vector2(-87.0, -4.6), Vector2(-82.0, 0.0), Vector2(-89.0, 0.0)]
	for p: Vector3 in PARK.figure_spots():
		for r: Vector2 in route:
			check(Vector2(p.x, p.z).distance_to(r) > 1.6,
					"a figure blocks the walk at %s (%.1f m from %s)" % [p, Vector2(p.x, p.z).distance_to(r), r])
	for bed: Rect2 in PARK.bed_rects():
		for r: Vector2 in route:
			check(not bed.has_point(r), "the walk runs through a bed at %s" % r)


func test_statue_and_herm_build_geometry() -> void:
	var kit := MeshKit.new()
	var xf := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var tall := Arch.statue(kit, xf, {"h": 2.4, "mat": "column", "helmet": true, "plinth": 0.6})
	check(tall > 2.8, "the helmeted goddess is only %.2f m" % tall)
	var youth := Arch.statue(kit, xf, {"h": 1.7, "mat": "bronze", "arm": "up"})
	check(youth > 1.9 and youth < 2.4, "the bronze youth is %.2f m" % youth)
	var herm := Arch.herm(kit, xf, 1.6)
	check(herm > 1.5, "the herm is only %.2f m" % herm)
	var mesh := kit.commit()
	check(mesh != null and mesh.get_surface_count() > 0, "the figures left an empty mesh")
	check(kit._colliders.size() >= 3, "the figures have no colliders")
