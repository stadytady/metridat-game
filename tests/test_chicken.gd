extends "res://tests/test_case.gd"
## Chickens stay home and run away from the player, never towards them.


func test_clamp_home() -> void:
	var home := Vector3(10, 5, -3)
	var p := Chicken.clamp_home(Vector3(20, 9, -3), home, 1.5)
	check(p.is_equal_approx(Vector3(11.5, 5, -3)), "clamped onto the circle at home height: %s" % p)
	var q := Chicken.clamp_home(Vector3(10.5, 7, -2.8), home, 1.5)
	check(q.is_equal_approx(Vector3(10.5, 5, -2.8)), "inside stays put: %s" % q)


func test_flee_moves_away_and_stays_home() -> void:
	var home := Vector3.ZERO
	var r := 1.6
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		var a := rng.randf_range(0, TAU)
		var p := Chicken.clamp_home(Vector3(cos(a), 0, sin(a)) * rng.randf_range(0, r), home, r)
		var b := rng.randf_range(0, TAU)
		var threat := p + Vector3(cos(b), 0, sin(b)) * rng.randf_range(0.3, Chicken.FLEE_DIST)
		var t := Chicken.flee_target(p, threat, home, r)
		check(Vector2(t.x, t.z).length() <= r + 1e-3, "target outside home: %s" % t)
		var d0 := Vector2(p.x - threat.x, p.z - threat.z).length()
		var d1 := Vector2(t.x - threat.x, t.z - threat.z).length()
		check(d1 >= d0 - 1e-3, "runs towards the threat: %.2f -> %.2f" % [d0, d1])


const POULTRY := preload("res://scripts/world/poultry.gd")
const LIFE := preload("res://scripts/world/life.gd")
const HOUSE := preload("res://scripts/world/house.gd")


## Myrto's hens keep to the yard between the house's front wall and the rooms,
## clear of the pithoi by the west wall and of the oven.
func test_myrtos_hens_keep_to_her_yard() -> void:
	var h := POULTRY.MYRTO_HENS
	var r := POULTRY.MYRTO_RADIUS
	var b: Rect2 = HOUSE.bounds()
	check(h.x - r > b.position.x + HOUSE.WALL_T + 0.3 and h.x + r < HOUSE.DIVIDE_X, "the hens run out of the yard in x")
	check(is_equal_approx(h.y, Topo.HOUSE_H), "the hens stand off the yard's floor")
	check(h.z - r > b.position.y + HOUSE.WALL_T + 0.2 and h.z + r < HOUSE.RANGE_Z - 0.3, "the hens run into a wall in z")
	for p: Vector2 in [Vector2(20.5, 17.2), Vector2(21.4, 16.9), HOUSE.MASON_MARK]:
		check(Vector2(h.x, h.z).distance_to(p) > r + 0.6, "the hens run into the pithos or the block at %s" % p)
	check(Vector2(h.x, h.z).distance_to(HOUSE.OVEN) > r + 1.2, "the hens run into the oven")


## The pen's hens stay inside the fence, and on its ground: the pen falls
## across, so a hen at the home's height would float or sink.
func test_the_pens_hens_stay_in_the_pen_on_the_ground() -> void:
	var h: Vector3 = POULTRY.pen_home()
	var r := POULTRY.PEN_RADIUS
	var c: Vector3 = LIFE.yard_pos()
	check(absf(h.x - c.x) + r < LIFE.YARD_HALF - 0.3, "the hens get through the side fence")
	check(absf(h.z - c.z) + r < LIFE.YARD_DEPTH * 0.5 - 0.3, "the hens get through the front or back fence")
	# someone watching from the lane, out of scaring range: past the fog a
	# chicken does no work at all, and would never leave its spot
	var cam := Camera3D.new()
	Engine.get_main_loop().root.add_child(cam)
	cam.global_position = h + Vector3(8.0, 1.6, 0.0)
	cam.make_current()
	var hen := Chicken.new()
	hen.home = h
	hen.radius = r
	hen.follow_ground = true
	Engine.get_main_loop().root.add_child(hen)
	var start := hen.position
	var walked := 0.0
	var worst := 0.0
	for k in 600:
		hen._process(0.1)
		worst = maxf(worst, absf(hen.position.y - Topo.surface(hen.position.x, hen.position.z)))
		walked = maxf(walked, Vector2(hen.position.x - start.x, hen.position.z - start.z).length())
		check(Vector2(hen.position.x - h.x, hen.position.z - h.z).length() <= r + 0.05, "a hen left the pen's ground at %s" % hen.position)
	check(walked > 0.4, "the hen never walked about the pen (%.2f m)" % walked)
	check(worst < 0.01, "a hen in the pen is %.2f m off the ground" % worst)
	hen.free()
	cam.free()
