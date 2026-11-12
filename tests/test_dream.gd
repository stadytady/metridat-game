extends "res://tests/test_case.gd"
## The dream's mirror stands on the altar facing the path, handle down, and
## sits on the slab instead of sinking into it.


func test_mirror_faces_the_path() -> void:
	var D := load("res://scripts/world/dream.gd")
	var b: Basis = D.mirror_basis()
	var face := b * Vector3.UP  # the model lies face up
	var handle := b * Vector3(0, 0, 1)  # the handle runs along +z
	check(face.z < -0.8, "face must turn to the path (-z): %s" % face)
	check(face.y > 0.1, "leaning back, the face catches the sky: %s" % face)
	check(handle.y < -0.8, "handle must point down: %s" % handle)
	# the handle's knob (0.32 from the centre) must rest on the slab, not under it
	var knob_y: float = D.MIRROR_LIFT + (b * Vector3(0, 0, 0.32)).y
	check(knob_y > -0.02 and knob_y < 0.06, "handle end should stand on the altar: %.3f" % knob_y)


func test_doors_swing_open_in_steps() -> void:
	var D := load("res://scripts/world/dream.gd")
	check(D.door_open_at(0.0) == 0.0, "the doors start shut")
	check(D.door_open_at(0.05) == 0.0, "the doors move before their first 15 fps step")
	check(is_equal_approx(D.door_open_at(D.DOOR_SECONDS), 1.0), "not wide open after %.1f s" % D.DOOR_SECONDS)
	var last := 0.0
	for i in 60:
		var f: float = D.door_open_at(i * 0.06)
		check(f >= last, "the doors swing back at %.2f s" % (i * 0.06))
		last = f


func test_tomb_stair_is_walkable_and_deep() -> void:
	var D := load("res://scripts/world/dream.gd")
	check(D.STEP_RISE <= 0.3, "a step is a wall: %.2f" % D.STEP_RISE)
	check(D.DEPTH >= 4.0, "the stair is not long: %.1f m down" % D.DEPTH)
	check(rad_to_deg(atan2(D.DEPTH, D.STEPS * D.STEP_RUN)) < 40.0, "the stair is too steep to walk")
	# what one walks on stays within a hand of the drawn treads
	for i in D.STEPS:
		var z0: float = D.STAIR_Z + i * D.STEP_RUN
		var tread: float = -(i + 1) * D.STEP_RISE
		for u: float in [0.05, 0.5, 0.95]:
			var walk: float = D.tomb_floor(z0 + u * D.STEP_RUN) - 0.1
			check(absf(walk - tread) <= 0.15, "step %d: ramp %.2f vs tread %.2f" % [i, walk, tread])
	check(D.tomb_floor(D.stair_end() + 1.0) == -D.DEPTH, "the passage is not level at the stair's foot")


func test_chamber_lies_under_the_mound() -> void:
	var D := load("res://scripts/world/dream.gd")
	var c: Vector3 = D.chamber_center()
	# the mound's surface (its lathe profile) over a point at radius r from its centre
	var surface := func(r: float) -> float:
		var prof := [Vector2(D.MOUND_R, -0.2), Vector2(D.MOUND_R * 0.8, D.MOUND_H * 0.45), Vector2(D.MOUND_R * 0.45, D.MOUND_H * 0.85), Vector2(0.0, D.MOUND_H)]
		for i in prof.size() - 1:
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[i + 1]
			if r <= a.x and r >= b.x:
				return lerpf(a.y, b.y, (a.x - r) / (a.x - b.x))
		return -1.0
	# every dome course that rises above the ground must stay inside the mound
	var outer: float = D.CHAMBER_HALF + 0.4
	for k in D.CH_COURSES + 1:
		var top: float = c.y + D.CH_WALL_H + D.CH_COURSE_H * (k + 1)
		if k == D.CH_COURSES:
			top = c.y + D.CH_WALL_H + D.CH_COURSE_H * D.CH_COURSES + 0.2  # the capstone
		if top <= 0.0:
			continue
		for corner: Vector2 in [Vector2(outer, outer), Vector2(-outer, outer), Vector2(outer, -outer), Vector2(-outer, -outer)]:
			var r := Vector2(c.x + corner.x - D.MOUND.x, c.z + corner.y - D.MOUND.z).length()
			check(top < surface.call(r), "dome course %d breaks the mound at r %.1f: %.2f over %.2f" % [k, r, top, surface.call(r)])
	# the dome closes: courses step in until a slab can cover the gap
	var gap: float = D.CHAMBER_HALF - D.CH_COURSE_IN * D.CH_COURSES
	check(gap > 0.0 and gap < 0.6, "the corbelled dome does not close: gap %.2f" % gap)
	var hall_gap: float = D.HALL_HALF - D.COURSE_IN * D.COURSES
	check(hall_gap > 0.0 and hall_gap < 0.3, "the dromos vault does not close: gap %.2f" % hall_gap)


func test_mound_is_cut_only_for_the_passage() -> void:
	var D := load("res://scripts/world/dream.gd")
	var cut := 0
	for i in D.MOUND_SEGMENTS:
		for j in 3:
			if D.mound_cut(i, j):
				cut += 1
				var a: float = TAU * i / D.MOUND_SEGMENTS
				var b: float = TAU * (i + 1) / D.MOUND_SEGMENTS
				# the hole stays within the passage's stone walls, so no gap shows beside them
				for ang: float in [a, b]:
					check(absf(cos(ang)) * D.MOUND_R <= D.HALL_HALF + 0.4 + 0.01, "the cut is wider than the passage at sector %d" % i)
	check(cut >= 2, "the mound is not cut for the passage: %d sectors" % cut)
	check(cut <= 2, "too much of the mound is cut: %d sectors" % cut)
	# the doorway (its full width at the mound's foot) falls in the cut
	var half_angle: float = asin(D.DOOR_HALF / D.MOUND_R)
	var lo := -PI / 2.0 - half_angle
	var hi := -PI / 2.0 + half_angle
	for ang: float in [lo, hi]:
		var i: int = int(floor(fposmod(ang, TAU) / TAU * D.MOUND_SEGMENTS))
		check(D.mound_cut(i, 0), "the doorway's edge at %.1f deg is under the mound's earth" % rad_to_deg(ang))


## The meadow has no patchwork: neighbouring ground cells meet with the same
## UVs on their shared corners (the texture runs on), and every cell is grass of
## one tint (a cell of its own material or colour was a 4 m rectangle with a
## hard edge).
func test_the_meadow_has_no_seams() -> void:
	var D := preload("res://scripts/world/dream.gd")
	var a: PackedVector2Array = D.ground_uvs([Vector3(0, 0.3, 4), Vector3(4, 0.5, 4), Vector3(4, 0.2, 0), Vector3(0, 0.1, 0)])
	var b: PackedVector2Array = D.ground_uvs([Vector3(4, 0.5, 4), Vector3(8, 0.9, 4), Vector3(8, 0.4, 0), Vector3(4, 0.2, 0)])
	check(a[1].is_equal_approx(b[0]) and a[2].is_equal_approx(b[3]), "two cells meet with different UVs: %s / %s" % [a, b])
	var src := FileAccess.get_file_as_string("res://scripts/world/dream.gd")
	check(not src.contains('"grass" if rng.randf()'), "the meadow still picks grass or earth per cell")
	check(src.contains('kit.quad("grass", d, c, b, a, ground_uvs('), "the meadow cells do not take plan UVs")
