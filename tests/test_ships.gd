extends "res://tests/test_case.gd"
## Ships come in from the strait during the day and are at anchor by night:
## afternoon at the start (the trailer's ship stays where it was framed), night
## at the anchorage, only ever closer on the way, anchorages in deep water and
## apart from each other.

const S := preload("res://scripts/world/ships.gd")


func test_afternoon_at_sea_night_at_anchor() -> void:
	for s: Array in S.SHIPS:
		var start: Vector3 = s[0]
		var anchor: Vector3 = s[3]
		check(S.position_at(start, anchor, 0.0).is_equal_approx(start), "afternoon: at its start")
		check(is_equal_approx(S.heading_at(start, s[1], anchor, 0.0), s[1]), "afternoon: on its old heading")
		check(S.position_at(start, anchor, 1.0).is_equal_approx(anchor), "night: at anchor")
		check(S.position_at(start, anchor, DayCycle.DREAM).is_equal_approx(anchor), "the dream does not move them")
		var prev := INF
		for i in 41:
			var d := S.position_at(start, anchor, i / 40.0).distance_to(anchor)
			check(d <= prev + 1e-4, "a ship moves away from its anchorage at %.2f" % (i / 40.0))
			prev = d


## Anchored hulls sit in the sea with their laid decks above it, like the moored one.
func test_decks_stay_above_the_water() -> void:
	for s: Array in S.SHIPS:
		var a: Vector3 = s[3]
		var k := float(s[2])
		var water := Topo.SEA_LEVEL + Sea.height_at(a.x, a.z)
		var heave := Sea.float_pose(a, 0.0, 7.0 * k, 2.2 * k).x
		var deck: float = (S.WATERLINE + District.SHIP_DECK_Y) * k + heave
		var keel: float = (S.WATERLINE + S.HULL_BOTTOM) * k + heave
		check(deck > water, "anchored ship deck under water: %.2f vs %.2f" % [deck, water])
		check(keel < water - 0.25 * k, "anchored ship floats on top: keel %.2f vs %.2f" % [keel, water])


func test_anchorages_in_deep_water_and_apart() -> void:
	for i in S.SHIPS.size():
		var a: Vector3 = S.SHIPS[i][3]
		check(Topo.terrain(a.x, a.z) < -3.0, "anchorage %d too shallow: %.1f" % [i, Topo.terrain(a.x, a.z)])
		check(a.x > Topo.waterline_x(a.z) + 30.0, "anchorage %d too close to the beach" % i)
		for j in range(i + 1, S.SHIPS.size()):
			var b: Vector3 = S.SHIPS[j][3]
			check(a.distance_to(b) > 25.0, "anchorages %d and %d overlap" % [i, j])


## The deck follows the hull: no strip of it hangs over a gunwale or past the stern.
func test_the_deck_stays_inside_the_hull() -> void:
	check(District.SHIP_DECK_END < 8.5, "the deck runs past the hull's tip: %.2f" % District.SHIP_DECK_END)
	var x := 0.0
	while x <= District.SHIP_DECK_END:
		var deck: float = District.ship_deck_half_beam(x)
		var hull: float = District.ship_hull_half_beam(x)
		check(deck < hull, "at %.1f m the deck is %.2f wide, the hull %.2f" % [x, deck, hull])
		check(deck > hull - 0.45, "at %.1f m the deck leaves a %.2f m gap" % [x, hull - deck])
		x += 0.5

## Riding at anchor through a minute of swell, the keel never comes out of the
## water anywhere along the hull. The keel is the model's origin; the old
## "bottom" at -0.67 was the steering oar, and the hull lay on top of the sea.
func test_the_keel_stays_in_the_water_through_the_swell() -> void:
	var worst := -INF
	for s: Array in S.SHIPS:
		var a: Vector3 = s[3]
		var k := float(s[2])
		var yaw := deg_to_rad(S.heading_at(s[0], s[1], a, 1.0))
		var fwd := Vector3(cos(yaw), 0, -sin(yaw))
		for step in 120:
			var t := step * 0.5
			var f := Sea.float_pose(a, yaw, 7.0 * k, 2.2 * k, t)
			for x: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
				var p := a + fwd * x * k
				# pitch (f.z) lifts the bow when positive
				var keel := (S.WATERLINE + S.HULL_BOTTOM) * k + f.x + tan(f.z) * x * k
				var water := Topo.SEA_LEVEL + Sea.height_at(p.x, p.z, t)
				worst = maxf(worst, keel - water)
	check(worst < -0.05, "an anchored keel comes %.2f m out of the water in the swell" % worst)


## HULL_BOTTOM is the hull's keel, read from the model amidships (the steering
## oars hang lower at the stern; taken for the keel, they put the hull on top
## of the sea). Both the anchored ships and the moored one use it.
func test_the_keel_constant_is_the_hull_keel() -> void:
	var root := Props.build("ship").build("Ship")
	var low := INF
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh
		for sidx in m.get_surface_count():
			var verts: PackedVector3Array = m.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				if absf(v.x) < 5.0:
					low = minf(low, v.y)
	root.free()
	check(absf(low - S.HULL_BOTTOM) < 0.05, "the keel amidships is at %.2f, HULL_BOTTOM says %.2f" % [low, S.HULL_BOTTOM])
	check(absf(low - preload("res://scripts/world/harbour.gd").HULL_BOTTOM) < 0.05, "the moored ship's HULL_BOTTOM is not its keel")


## At anchor and alongside the canvas is furled; out on the strait it is set.
func test_sails_are_furled_at_anchor_and_set_under_way() -> void:
	check(S.furl_at(0.0) == 0.0, "a ship out on the strait in the afternoon sails furled")
	check(S.furl_at(0.5) < 0.05, "a ship on her passage has taken her sail in already")
	check(is_equal_approx(S.furl_at(1.0), 1.0), "a ship at anchor by night has her sail set")
	var n := Props.instance("ship")
	Engine.get_main_loop().root.add_child(n)
	District.set_furl(n, 1.0)
	var furled := true
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		furled = furled and is_equal_approx(float(g.get_instance_shader_parameter(&"furl")), 1.0)
	n.free()
	check(furled, "set_furl does not reach the sail's shader")
	var shader := FileAccess.get_file_as_string("res://assets/shaders/psx_sail.gdshader")
	check(shader.contains("instance uniform float furl"), "psx_sail has no furl")
