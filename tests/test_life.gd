extends "res://tests/test_case.gd"
## Signs of life: things lying on the street sit on smooth paving (no stairs), worn stone
## lies on the floor it wears, the dog breathes at a stepped 15 fps, and some
## roofs miss tiles while the street's layout is unchanged.

const L := preload("res://scripts/world/life.gd")


func test_street_litter_lies_on_flat_paving() -> void:
	var xs: Array[float] = L.flat_street_x()
	check(xs.size() >= 3, "too few flat stretches: %d" % xs.size())
	for x in xs:
		var slope := absf(Topo.street_height(x + 0.8) - Topo.street_height(x - 0.8)) / 1.6
		check(slope < Topo.STAIR_SLOPE, "x %.1f is on a stair (slope %.2f)" % [x, slope])
		var p: Vector3 = L.street_edge(x, 1.0, 0.45)
		check(absf(p.z - Topo.street_z(x)) < Topo.STREET_HALF, "litter off the paving at x %.1f" % x)


func test_worn_patches_lie_on_their_floors() -> void:
	for w: Array in L.WORN:
		var c: Vector3 = w[0]
		var floor_y := Topo.surface(c.x, c.z)
		# the temple step stands on the terrace: 0.16 above it
		check(c.y >= floor_y - 0.01 and c.y <= floor_y + 0.2, "worn patch at %s floats or sinks (floor %.2f)" % [c, floor_y])


func test_dog_breathes_stepped() -> void:
	var a := Dog.pose_at(1.0 + 0.2 / 15.0, -10.0)
	check(a == Dog.pose_at(1.0 + 0.7 / 15.0, -10.0), "changes within one 15 fps step")
	var moved := false
	for i in 30:
		moved = moved or Dog.pose_at(1.0 + (i + 0.5) / 15.0, -10.0) != a
	check(moved, "the dog does not breathe")
	check(Dog.pose_at(5.05, 5.0).y > 0.0 and Dog.pose_at(5.5, 5.0).y == 0.0, "ear twitches briefly")


func test_dog_clear_of_the_stoa() -> void:
	# the stoa's west end wall stands at x 12.0..12.6, its stylobate reaches z -4.7
	# and stands 0.32 above the paving; the dog is about 1.5 m long, 0.4 wide
	check(L.DOG.x - 0.75 > 12.6, "the dog's tail is in the stoa's end wall")
	check(L.DOG.z - 0.25 > -4.7, "the dog lies in the stoa's step")


## The well left the square for the lane: it must stand clear of the way past and
## on ground flat enough to carry a curb, and the yard must sit across from it.
func test_well_stands_off_the_lane() -> void:
	var p := L.well_pos()
	var d := absf(p.z - Topo.street_z(p.x))
	check(d > Topo.STREET_HALF + 0.4, "the well stands in the lane: %.2f m from its centre" % d)
	var lo := INF
	var hi := -INF
	for dx: float in [-0.6, 0.0, 0.6]:
		for dz: float in [-0.6, 0.0, 0.6]:
			var h := Topo.surface(p.x + dx, p.z + dz)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	check(hi - lo < 0.3, "the well stands on a slope: %.2f m under it" % (hi - lo))


func test_yard_is_across_the_lane() -> void:
	var c := L.yard_pos()
	var d := c.z - Topo.street_z(c.x)
	var w := L.well_pos()
	check(absf(d) > Topo.STREET_HALF + 1.0, "the yard's fence is in the lane")
	check(signf(d) != signf(w.z - Topo.street_z(w.x)), "the yard is on the well's side, not across")
