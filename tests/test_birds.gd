extends "res://tests/test_case.gd"
## Birds: wings beat at a stepped 15 fps, gulls stay on their circle and clear
## of the ground, pigeons take off from and land back on their patch.

const B := preload("res://scripts/world/birds.gd")


func test_wings_stepped_and_flap_wider_than_glide() -> void:
	check(Bird.wing_angle(1.0 + 0.1 / 15.0, true) == Bird.wing_angle(1.0 + 0.9 / 15.0, true), "changes within one 15 fps step")
	var widest := 0.0
	for i in 30:
		widest = maxf(widest, absf(Bird.wing_angle(i / 15.0, true)))
	check(widest > 30.0, "flapping wings barely move: %.1f" % widest)
	check(absf(Bird.wing_angle(0.5, false)) < 15.0, "gliding wings beat")


func test_gulls_circle_above_the_ground() -> void:
	for g: Array in B.GULLS:
		var c: Vector3 = g[0]
		var r: float = g[1]
		for i in 24:
			var p := Bird.soar_at(c, r, g[2], i * 1.3)
			check(absf(Vector2(p.x - c.x, p.z - c.z).length() - r) < 0.01, "gull off its circle at %s" % c)
			check(p.y > Topo.terrain(p.x, p.z) + 5.0, "gull at %s skims the ground" % p)


func test_pigeon_flight_leaves_and_returns() -> void:
	var from := B.PIGEONS
	var land := B.PIGEONS + Vector3(0.8, 0, -0.5)
	check(Bird.flight_at(from, land, 0.0).distance_to(from) < 0.001, "does not start where it stood")
	check(Bird.flight_at(from, land, 1.0).distance_to(land) < 0.001, "does not land where it meant to")
	check(Bird.flight_at(from, land, 0.5).y > from.y + 4.0, "does not get up over the square")
	for i in 21:
		var p := Bird.flight_at(from, land, i / 20.0)
		check(Topo.in_rect(p.x, p.z, Topo.AGORA_CENTER, Topo.AGORA_HALF), "flies out of the agora at %s" % p)
		check(p.y >= Topo.AGORA_H - 0.001, "goes under the paving at %s" % p)
