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


## The pen is a pen: posts around it, rails between neighbours, one gate opening.
func test_yard_fence_is_a_closed_pen_with_one_gate() -> void:
	var f: Dictionary = L.yard_fence()
	var posts: Array = f["posts"]
	var rails: Array = f["rails"]
	var gate: Vector2i = f["gate"]
	# every rail is a short span between two posts, not a plank hanging in the air
	for r: Vector2i in rails:
		var a: Vector2 = posts[r.x]
		var b: Vector2 = posts[r.y]
		var span := a.distance_to(b)
		check(span <= 1.6, "a rail spans %.2f m between posts" % span)
	# no post stands on its own
	var used := {}
	for r: Vector2i in rails:
		used[r.x] = true
		used[r.y] = true
	for i in posts.size():
		check(used.has(i), "post %d has no rails" % i)
	# the gate is the only way in, and a person fits through it
	var opening: float = (posts[gate.x] as Vector2).distance_to(posts[gate.y] as Vector2)
	check(opening > 0.9, "the gate is only %.2f m wide" % opening)
	check(opening < 1.4, "the gate is %.2f m — the pen barely closes" % opening)
	# the fence is off the paving, or the lane would run through the pen
	for p: Vector2 in posts:
		var off := absf(p.y - Topo.street_z(p.x))
		check(off > Topo.STREET_HALF, "a post stands on the lane at %s" % p)

## The tail hangs behind the rump: inside it, a mule looks docked.
func test_mule_tail_hangs_behind_the_rump() -> void:
	var mule := preload("res://scripts/world/mule.gd")
	check(mule.TAIL_Z > 0.65, "the tail sits in the rump at z=%.2f" % mule.TAIL_Z)


## The gate is shut: a leaf that reaches across the opening.
func test_yard_gate_leaf_closes_the_opening() -> void:
	var f: Dictionary = L.yard_fence()
	var posts: Array = f["posts"]
	var gate: Vector2i = f["gate"]
	var opening: float = (posts[gate.x] as Vector2).distance_to(posts[gate.y] as Vector2)
	check(L.GATE_LEAF >= opening - 0.1, "the leaf is %.2f m for a %.2f m gate" % [L.GATE_LEAF, opening])
	check(L.GATE_SWING_DEG < 20.0, "the gate stands open at %.0f deg" % L.GATE_SWING_DEG)

## The mule walks its pen: grazes at the tufts, drinks at the trough, and never
## takes its body through the fence. Forty minutes of its day in 0.1 s ticks.
func test_mule_walks_grazes_and_drinks_inside_the_pen() -> void:
	var M := preload("res://scripts/world/mule.gd")
	var m: Node3D = M.new()
	var walk := L.yard_walk()
	m.bounds = walk
	var c := L.yard_pos()
	for g: Vector2 in L.TUFTS:
		m.tufts.append(Vector2(c.x + g.x, c.z + g.y))
		check(walk.grow(M.REACH).has_point(Vector2(c.x + g.x, c.z + g.y)), "a tuft is out of the mule's reach at %s" % g)
	var t := L.trough_pos()
	m.drink_at = Vector2(t.x, t.z)
	m.position = c
	var start := Vector2(c.x, c.z)
	var far := 0.0
	var outside := 0
	var fence := Rect2(c.x - L.YARD_HALF, c.z - L.YARD_DEPTH * 0.5, L.YARD_HALF * 2.0, L.YARD_DEPTH)
	for i in 24000:
		m.step(0.1)
		var p := Vector2(m.position.x, m.position.z)
		far = maxf(far, p.distance_to(start))
		# the body (half a metre either side of its middle along its length) stays in
		var fwd := Vector2(-sin(m.rotation.y), -cos(m.rotation.y)) * 0.7
		if not fence.has_point(p + fwd) or not fence.has_point(p - fwd):
			outside += 1
	check(outside == 0, "the mule's body went through the fence %d times" % outside)
	check(far > 1.5, "the mule hardly moved: %.2f m" % far)
	check(m.grazed >= 10, "the mule grazed only %d times" % m.grazed)
	check(m.drunk >= 1, "the mule never drank")
	m.free()
