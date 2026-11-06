extends "res://tests/test_case.gd"
## Cormorants on the beach: they hold their wings out to dry and fold them
## again, walk their patch of sand without leaving it or sinking into it, and
## stand above the surf, well away from the ship and the route.

const FISHING := preload("res://scripts/world/fishing.gd")
const HARBOUR := preload("res://scripts/world/harbour.gd")


func test_wings_fold_and_spread() -> void:
	check(is_zero_approx(Cormorant.wing_spread(Cormorant.State.STAND, 1.0)), "a standing cormorant holds its wings out")
	check(is_zero_approx(Cormorant.wing_spread(Cormorant.State.WALK, 1.0)), "a walking cormorant holds its wings out")
	var t := 0.0
	var lo := INF
	var hi := -INF
	while t < 12.0:
		var w := Cormorant.wing_spread(Cormorant.State.DRY, t)
		lo = minf(lo, w)
		hi = maxf(hi, w)
		t += 1.0 / 15.0
	check(lo > 65.0, "drying, the wings droop to %.0f deg" % lo)
	check(hi < 100.0, "drying, the wings fold back over the shoulders at %.0f deg" % hi)
	check(hi - lo > 4.0, "drying, it never shakes its wings")


## Five minutes of a sand bird's day in 0.1 s ticks: it dries its wings, walks,
## stays inside its patch and on the sand's own height.
func test_a_cormorant_dries_walks_and_stays_home() -> void:
	var b := Cormorant.new()
	b.name = "TestCormorant"
	b.home = Vector3(FISHING.CORMORANT_SAND.x, Topo.terrain(FISHING.CORMORANT_SAND.x, FISHING.CORMORANT_SAND.y), FISHING.CORMORANT_SAND.y)
	b.radius = FISHING.CORMORANT_SAND_R
	Engine.get_main_loop().root.add_child(b)
	var far := Vector3(INF, 0, INF)
	var worst := 0.0
	for k in 3000:
		b.step(0.1, far)
		var d := Vector2(b.position.x - b.home.x, b.position.z - b.home.z).length()
		check(d <= b.radius + 0.01, "it wandered %.2f m from home" % d)
		worst = maxf(worst, absf(b.position.y - Topo.terrain(b.position.x, b.position.z)))
	check(b.dried > 30.0, "in five minutes it dried its wings for only %.0f s" % b.dried)
	check(b.walked > 2.0, "in five minutes it walked only %.1f m" % b.walked)
	check(worst < 0.02, "it walks %.2f m off the sand" % worst)
	b.queue_free()


## The colony is above the surf, about fifty metres from the ship, and the
## rock-sitters stay on their rocks.
func test_the_colony_is_on_the_beach_by_the_ship() -> void:
	var ship: Vector3 = HARBOUR.ship_pos()
	var c := FISHING.CORMORANT_SAND
	var d := Vector2(ship.x, ship.z).distance_to(c)
	check(d > 40.0 and d < 65.0, "the cormorants are %.0f m from the ship" % d)
	check(Topo.terrain(c.x, c.y) - FISHING.CORMORANT_SAND_R * 0.4 > 1.0, "the sand patch runs down into the surf")
	for top: Vector3 in FISHING.cormorant_rock_tops():
		check(top.y > 1.2, "a rock top is awash at %.2f m" % top.y)
	var b := Cormorant.new()
	b.home = FISHING.cormorant_rock_tops()[0]
	b.on_rock = true
	Engine.get_main_loop().root.add_child(b)
	for k in 600:
		b.step(0.1, b.home + Vector3(1.0, 0, 0))  # even with someone right beside it
	check(b.position.distance_to(b.home) < 0.01, "a rock-sitter left its rock")
	check(b.walked == 0.0, "a rock-sitter walked")
	b.queue_free()
