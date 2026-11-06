extends "res://tests/test_case.gd"
## The park on the hill's flanks: two long walks with a grove either side. What
## can silently go wrong is a walk hanging in the air or climbing like a wall, a
## tree planted in the middle of the walk, and a park that has shrunk back to a
## flowerbed without anyone noticing - so the size is a test too.

const PARK := preload("res://scripts/world/park.gd")


func _walks() -> Array[Array]:
	var out: Array[Array] = []
	for side: float in [1.0, -1.0]:
		for w: Array in PARK.walks(side):
			out.append(w[0])
	return out


func _distance_to_walks(p: Vector2) -> float:
	var best := INF
	for walk: Array in _walks():
		var pts: Array[Vector3] = walk
		for i in pts.size() - 1:
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


## A park, not a flowerbed: the walks run out over the flank and the grove is a
## grove.
func test_the_park_is_big() -> void:
	var trees := PARK.tree_spots()
	check(trees.size() >= 76, "the grove is only %d trees" % trees.size())
	var span := 0.0
	var depth := 0.0
	for p: Vector2 in trees:
		span = maxf(span, absf(p.x - PARK.GATE_X))
		depth = maxf(depth, absf(p.y))
	check(span >= 8.0, "the grove reaches only %.1f m either way" % span)
	check(depth >= 36.0, "the grove is only %.1f m out from the axis" % depth)


func test_walks_follow_the_ground() -> void:
	for walk: Array in _walks():
		var pts: Array[Vector3] = walk
		check(pts.size() >= 2, "a walk has %d points" % pts.size())
		for i in pts.size():
			var p := pts[i]
			check(absf(p.y - (Topo.terrain(p.x, p.z) + 0.05)) < 0.05,
					"a walk floats %.2f m over the ground at %s" % [p.y - Topo.terrain(p.x, p.z), p])
			if i > 0:
				var a := pts[i - 1]
				var run := Vector2(p.x - a.x, p.z - a.z).length()
				var rise := absf(p.y - a.y)
				check(rise / maxf(run, 0.001) < 0.5,
						"a walk climbs %.2f m over %.2f m" % [rise, run])


## The walk leaves the terrace through its gate: the park starts where the
## terrace ends, not ten metres away.
func test_the_walk_starts_at_the_terrace_gate() -> void:
	for side: float in [1.0, -1.0]:
		var c := PARK.connector_points(side)
		var first := c[0]
		check(absf(first.x - PARK.GATE_X) < 0.01, "the gate walk starts at x %.2f" % first.x)
		check(absf(absf(first.z) - PARK.TERRACE_EDGE) < 1.8,
				"the gate walk starts %.2f m from the parapet" % (absf(first.z) - PARK.TERRACE_EDGE))
		var last := c[c.size() - 1]
		check(absf(absf(last.z) - PARK.WALK_Z) < 3.0,
				"the gate walk stops %.2f m short of the long walk" % (PARK.WALK_Z - absf(last.z)))


func test_trees_keep_off_the_walks() -> void:
	for p: Vector2 in PARK.tree_spots():
		var d := _distance_to_walks(p)
		check(d > PARK.WALK_HALF + 0.4, "an olive stands %.2f m from a walk at %s" % [d, p])
		check(p.x > -99.0, "an olive grew in the steppe at %s" % p)
		check(absf(p.y) > Topo.HILL_HALF.y + 1.5, "an olive grew on the terrace at %s" % p)


func test_figures_stand_off_the_walk() -> void:
	var spots := PARK.figure_spots()
	check(spots.size() >= 8, "only %d figures" % spots.size())
	for p: Vector3 in spots:
		check(absf(p.y - (Topo.terrain(p.x, p.z) + 0.05)) < 0.2,
				"a figure floats %.2f m at %s" % [p.y - Topo.terrain(p.x, p.z), p])
		var d := _distance_to_walks(Vector2(p.x, p.z))
		check(d > PARK.WALK_HALF + 0.6, "a figure blocks the walk at %s (%.1f m)" % [p, d])


func test_statue_and_herm_build_geometry() -> void:
	var kit := MeshKit.new()
	var xf := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var tall := Arch.statue(kit, xf, {"h": 2.2, "mat": "column", "helmet": true, "plinth": 0.45})
	check(tall > 2.6, "the helmeted goddess is only %.2f m" % tall)
	var youth := Arch.statue(kit, xf, {"h": 1.7, "mat": "bronze_old", "arm": "up", "plinth": 0.35})
	check(youth > 1.9 and youth < 2.4, "the bronze youth is %.2f m" % youth)
	var herm := Arch.herm(kit, xf, 1.5)
	check(herm > 1.4, "the herm is only %.2f m" % herm)
	var mesh := kit.commit()
	check(mesh != null and mesh.get_surface_count() > 0, "the figures left an empty mesh")
	check(kit._colliders.size() >= 3, "the figures have no colliders")


## The bug this park once had: rows planted without looking, so a crown grew
## through every statue and bench. Nothing stands in a tree.
func test_figures_and_benches_stand_clear_of_the_trees() -> void:
	var trees := PARK.tree_spots()
	for c: Vector2 in PARK.cypress_spots():
		trees.append(c)
	for f: Vector3 in PARK.figure_spots():
		for t: Vector2 in trees:
			var d := t.distance_to(Vector2(f.x, f.z))
			check(d >= 2.0, "a tree grows %.1f m from the figure at %s" % [d, f])
	for b: Array in PARK.BENCHES:
		for side: float in [1.0, -1.0]:
			var p := Vector2(b[0], side * float(b[1]))
			check(PARK.walk_clearance(p) > 0.0, "a bench stands on a walk at %s" % p)
			for t: Vector2 in trees:
				check(t.distance_to(p) >= 1.5, "a tree grows through the bench at %s" % p)


## Each figure looks at a walk, not into the trees: its gaze reaches the stone
## within a few steps.
func test_figures_face_a_walk() -> void:
	var spots := PARK.figure_spots()
	var looks := PARK.figure_facing()
	check(spots.size() == looks.size(), "%d figures, %d facings" % [spots.size(), looks.size()])
	for i in spots.size():
		var p := Vector2(spots[i].x, spots[i].z)
		var reaches := false
		for k in range(1, 9):
			if PARK.walk_clearance(p + looks[i] * 0.5 * k) < 0.0:
				reaches = true
		check(reaches, "the figure at %s looks away from the walk" % p)


func test_cypresses_keep_off_the_walks() -> void:
	for c: Vector2 in PARK.cypress_spots():
		check(PARK.walk_clearance(c) > 0.8, "a cypress stands on a walk at %s" % c)
		check(absf(c.y) > Topo.HILL_HALF.y + 1.5, "a cypress grew on the terrace at %s" % c)


## The marble head (a find) lies beside the north gate walk: off the stone,
## clear of every crown, and close enough to the walk to be seen from it.
func test_the_marble_head_lies_by_the_walk() -> void:
	var p: Vector2 = PARK.HEAD_FIND
	var edge := PARK.walk_clearance(p)
	check(edge > 0.3, "the head lies on the walk (%.2f m from its edge)" % edge)
	check(edge < 1.5, "the head is %.2f m from the walk, lost in the grove" % edge)
	var trees := PARK.tree_spots()
	trees.append_array(PARK.cypress_spots())
	for t: Vector2 in trees:
		check(t.distance_to(p) > 1.2, "a tree grows %.2f m from the head" % t.distance_to(p))
