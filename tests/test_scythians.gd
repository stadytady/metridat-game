extends "res://tests/test_case.gd"
## The Scythians and the altar of Apollo: a horseman rides his track to the end
## and back, on the ground and far from the walked route; the Scythian look puts
## a hood on the head and trousers on the legs; the morning offering burns only
## in the morning; the altar stands clear of the lampstand and the blocks.

const S := preload("res://scripts/world/scythians.gd")
const A := preload("res://scripts/world/altar.gd")
const D := preload("res://scripts/core/director.gd")


func test_a_horseman_rides_to_the_end_and_back() -> void:
	var pts: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]
	var total := Rider.length_of(pts)
	check(is_equal_approx(total, 20.0), "the route is %.1f m, not 20" % total)
	var start: Array = Rider.along(pts, 0.0)
	var mid: Array = Rider.along(pts, 15.0)
	var end_: Array = Rider.along(pts, 20.0)
	var back: Array = Rider.along(pts, 25.0)
	var home: Array = Rider.along(pts, 40.0)
	check((start[0] as Vector2).is_equal_approx(Vector2.ZERO), "he does not start at the start")
	check((mid[0] as Vector2).is_equal_approx(Vector2(10, 5)) and (mid[1] as Vector2).is_equal_approx(Vector2(0, 1)), "half way along the second leg: %s" % [mid])
	check((end_[0] as Vector2).is_equal_approx(Vector2(10, 10)), "he does not reach the end: %s" % [end_])
	check((back[0] as Vector2).is_equal_approx(Vector2(10, 5)) and (back[1] as Vector2).is_equal_approx(Vector2(0, -1)),
			"on the way back he is at %s facing %s" % [back[0], back[1]])
	check((home[0] as Vector2).is_equal_approx(Vector2.ZERO), "he does not come home: %s" % [home])


func test_the_horsemen_keep_to_the_steppe() -> void:
	var track := S.track_points()
	for p: Vector3 in track:
		check(is_equal_approx(p.y, Topo.terrain(p.x, p.z)), "the track floats at %s" % p)
		check(p.x < Topo.HILL_CENTER.x - Topo.HILL_HALF.x - 8.0, "the track comes onto the hill at %s" % p)
	# round the kurgans, not through them: a mound is built over the terrain
	for k: Array in preload("res://scripts/world/steppe.gd").KURGANS:
		var c := Vector2(k[0], k[1])
		for i in track.size() - 1:
			var near := Geometry2D.get_closest_point_to_segment(c, Vector2(track[i].x, track[i].z), Vector2(track[i + 1].x, track[i + 1].z))
			check(near.distance_to(c) > float(k[2]) + 1.5, "the horsemen ride through the kurgan at %s (%.1f m from its middle)" % [c, near.distance_to(c)])
	# nowhere near the route the bot (and the player) walks
	var d: Node = D.new()
	Engine.get_main_loop().root.add_child(d)
	var route: Array = d._route()
	d.free()
	for s: Variant in route:
		if s is Vector2:
			var q: Vector2 = s
			for p: Vector3 in track:
				check(q.distance_to(Vector2(p.x, p.z)) > 12.0, "the horsemen ride over the route at %s" % q)
	# and they keep to the track: a horseman put along it stands on the ground
	var r := Rider.new()
	r.route = track
	r.rider_look = Figure.LOOKS["scythian_rider"]
	Engine.get_main_loop().root.add_child(r)
	for k in 30:
		r.step(1.3)
		check(absf(r.global_position.y - Topo.terrain(r.global_position.x, r.global_position.z)) < 0.01, "the horseman leaves the ground at %s" % r.global_position)
	var moved := r.travelled
	r.free()
	check(moved > 30.0, "in 39 s the horseman rode %.1f m" % moved)


func _materials(root: Node, joint: String) -> PackedStringArray:
	var out := PackedStringArray()
	var j: Node = root.find_child(joint, true, false)
	for mi: MeshInstance3D in j.find_children("*", "MeshInstance3D", false, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null:
				out.append(m.resource_name)
	return out


func test_the_scythian_wears_hood_coat_and_trousers() -> void:
	var look: Dictionary = Figure.LOOKS["scythian"]
	var root := Node3D.new()
	Figure.build(root, "chiton", look)
	var head := _materials(root, "head")
	var hip := _materials(root, "l_hip")
	var arm := _materials(root, "l_elbow")
	var greek := Node3D.new()
	Figure.build(greek, "chiton", Figure.LOOKS["potter"])
	var greek_hip := _materials(greek, "l_hip")
	root.free()
	greek.free()
	check(String(look.hood) in head, "no hood on the Scythian's head: %s" % [head])
	check(String(look.trousers) in hip and not "skin" in hip, "the Scythian's legs are bare: %s" % [hip])
	check(String(look.cloth) in arm, "the Scythian's forearms are bare: %s" % [arm])
	check("skin" in greek_hip, "the potter is in trousers: %s" % [greek_hip])


func test_the_morning_offering_and_the_altar_s_place() -> void:
	check(A.offering_at(0.05) and A.offering_at(A.MORNING_END - 0.01), "no fire on the altar in the morning")
	check(not A.offering_at(A.MORNING_END + 0.01) and not A.offering_at(0.9), "the fire burns on past the morning")
	var spot := A.SPOT
	# the lampstand by the view, and the building blocks south of it
	var x1 := Topo.HILL_CENTER.x + Topo.HILL_HALF.x - 0.3
	for lamp: Vector2 in [Vector2(x1 - 1.6, -3.1), Vector2(x1 - 1.6, 3.1)]:
		check(lamp.distance_to(spot) > 2.0, "the altar crowds the lampstand at %s" % lamp)
	for block: Vector2 in [Vector2(Topo.HILL_CENTER.x + 4, -5.6), Vector2(Topo.HILL_CENTER.x + 3, -6.2)]:
		check(absf(block.y - spot.y) > A.SIZE.z / 2.0 + 0.6 or absf(block.x - spot.x) > A.SIZE.x / 2.0 + 0.7,
				"the altar stands on a building block at %s" % block)
	check(A.PRIEST.y > spot.y, "the priest does not stand before the altar")
	# and off the walked route: the bot goes to the sherd on the blocks past it
	var d: Node = D.new()
	Engine.get_main_loop().root.add_child(d)
	var route: Array = d._route()
	d.free()
	var half := Vector2(A.SIZE.x, A.SIZE.z) / 2.0 + Vector2(0.2, 0.2)  # with its stepped base
	for s: Variant in route:
		if s is Vector2:
			var q: Vector2 = s
			var off := Vector2(maxf(absf(q.x - spot.x) - half.x, 0.0), maxf(absf(q.y - spot.y) - half.y, 0.0))
			check(off.length() > 1.0, "the altar stands in the way at the route step %s" % q)
