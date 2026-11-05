extends District
## Small signs that people live here: broken sherds on the street, a basket
## forgotten by a wall, washing drying in a yard, a chopping block with chips
## and a woodpile by the potter's kiln, stone worn pale by centuries of feet,
## and a dog asleep by the stoa. Nothing here has a collider in anyone's way.

## Out on the paving by the stoa's west end, clear of its end wall (x 12.6)
## and of the raised stylobate (z -4.7).
const DOG := Vector3(13.6, Topo.AGORA_H, -3.9)
## The well used to stand on the square and left the west lane bare; it now waits
## in the bend where the lane leaves the agora, on the grass by the wall, clear of
## the way past. The water carrier works there.
const WELL_X := 5.0
const WELL_SIDE := -1.0
const WELL_OFF := 1.1

## A yard on the other side of the same lane: a fence, hay and a mule.
const YARD_X := 2.6
const YARD_OFF := 2.2
## The pen is five metres across and a little over three deep.
const YARD_HALF := 2.5
const YARD_DEPTH := 3.4
const NPC := preload("res://scripts/npc/npc.gd")
## Where feet have worn the stone: [centre, size, yaw deg].
const WORN := [
	[Vector3(9.6, Topo.AGORA_H, 0.0), Vector2(2.6, 3.4), 0.0],  # where the street enters the agora
	[Vector3(46.0, Topo.SANCT_H + 0.16, -26.15), Vector2(1.6, 0.26), 0.0],  # the temple's bottom step, before the door
	[Vector3(-82.6, Topo.HILL_PLATFORM_TOP, 0.0), Vector2(2.2, 2.4), 0.0],  # the terrace's edge where the way down starts
]

var _cloths: Array[Node3D] = []
var _t := 0.0


## Stretches of the street paved as a smooth ramp (Arch.path builds stairs
## only where it is steeper than Topo.STAIR_SLOPE): things lie on the paving
## there instead of floating over a step.
static func flat_street_x() -> Array[float]:
	var out: Array[float] = []
	var x := Topo.STREET[0].x + 4.0
	while x < Topo.STREET[-1].x - 4.0:
		if absf(Topo.street_height(x + 0.8) - Topo.street_height(x - 0.8)) / 1.6 < Topo.STAIR_SLOPE * 0.8:
			out.append(x)
			x += 9.0
		else:
			x += 0.5
	return out


static func street_edge(x: float, side: float, inset: float) -> Vector3:
	var dz := Topo.street_z(x + 0.5) - Topo.street_z(x - 0.5)
	var out := Vector3(-dz, 0, 1).normalized() * side
	return Vector3(x, Topo.street_height(x), Topo.street_z(x)) + out * (Topo.STREET_HALF - inset)


## Where the well-head stands: on the grass a metre past the paving, on the ground
## it actually stands on, so the curb never hangs over a step.
static func well_pos() -> Vector3:
	var p := street_edge(WELL_X, WELL_SIDE, -WELL_OFF)
	p.y = Topo.surface(p.x, p.z)
	return p


## The yard's centre, on the other side of the lane.
static func yard_pos() -> Vector3:
	var p := street_edge(YARD_X, -WELL_SIDE, -YARD_OFF)
	p.y = Topo.surface(p.x, p.z)
	return p


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2511
	var kit := MeshKit.new()
	var flats := flat_street_x()
	for i in flats.size():
		var x: float = flats[i]
		_sherds(kit, rng, street_edge(x, 1.0 if i % 2 == 0 else -1.0, 0.45))
	_sherds(kit, rng, Vector3(10.4, Topo.AGORA_H, 2.4))
	if flats.size() > 1:
		_basket(kit, street_edge(flats[1] + 2.0, -1.0, 0.3))
	_worn(kit)
	_woodpile(kit, rng)
	add_child(kit.build("Life"))
	_washing()
	_well()
	_yard()
	var dog := Dog.new()
	dog.position = DOG
	dog.scale = Vector3.ONE * 1.3  # a big yard dog, and readable at 640x360
	dog.rotation.y = deg_to_rad(-100.0)  # along the stoa's end wall, head towards the square
	add_child(dog)
	_folk()


## People crossing the square on their own business: a porter with a jar, a woman
## with a basket, a boy who runs. They have no colliders and no lines, so they
## never stand in the walkthrough's way - they are weather, not furniture.
const FOLK := [
	# [from, to, speed, pose, body, scale]
	[Vector3(30.0, 0, -3.4), Vector3(15.5, 0, -2.2), 0.55, "carry", "chiton_dark", 1.0],
	[Vector3(14.0, 0, 2.2), Vector3(29.0, 0, 3.6), 0.45, "stand", "chiton", 0.95],
	[Vector3(18.5, 0, 8.0), Vector3(31.0, 0, 6.4), 1.05, "stand", "chiton_dark", 0.8],
]


func _folk() -> void:
	for f: Array in FOLK:
		var n: Npc = NPC.new()
		n.talkable = false
		n.stops_for_player = false
		n.pose = f[3]
		n.body_mat = f[4]
		n.figure_scale = f[5]
		n.patrol = PackedVector3Array([f[1] - f[0], Vector3.ZERO])
		n.patrol_speed = f[2]
		n.patrol_pause = 0.6
		n.patrol_poses = PackedStringArray([f[3], f[3]])
		n.position = Vector3(f[0].x, Topo.AGORA_H, f[0].z)
		add_child(n)
		n.collision_layer = 0


## A broken pot: a scatter of curved red sherds, one with a black-glazed face.
func _sherds(kit: MeshKit, rng: RandomNumberGenerator, at: Vector3) -> void:
	# big enough to read at 640x360: a hand-sized sherd is a few pixels
	for i in rng.randi_range(7, 11):
		var p := at + Vector3(rng.randf_range(-0.55, 0.55), 0.02, rng.randf_range(-0.4, 0.4))
		kit.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), p)
		kit.box("clay" if i % 3 else "redfigure", Vector3.ZERO, Vector3(rng.randf_range(0.12, 0.24), 0.02, rng.randf_range(0.09, 0.17)), [])
	kit.xform = Transform3D.IDENTITY


func _basket(kit: MeshKit, at: Vector3) -> void:
	kit.lathe("basket", PackedVector2Array([Vector2(0.16, 0.0), Vector2(0.21, 0.22), Vector2(0.22, 0.26)]), 8, at, 2.0, true, "basket")
	kit.box("basket", at + Vector3(0, 0.36, 0), Vector3(0.36, 0.03, 0.03), [])  # handle
	for s: float in [1.0, -1.0]:
		kit.box("basket", at + Vector3(0.17 * s, 0.31, 0), Vector3(0.03, 0.1, 0.03), [])


## Stone worn smooth: pale cut-out patches a hair above the paving.
func _worn(kit: MeshKit) -> void:
	for w: Array in WORN:
		var c: Vector3 = w[0]
		var size: Vector2 = w[1]
		kit.xform = Transform3D(Basis(Vector3.UP, deg_to_rad(w[2])), c + Vector3(0, 0.012, 0))
		var hx := size.x / 2.0
		var hz := size.y / 2.0
		kit.quad("worn", Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz),
				PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
	kit.xform = Transform3D.IDENTITY


## Firewood for the kiln: a stack of split logs, a chopping block with an axe
## mark, and pale chips and shavings scattered round it.
func _woodpile(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var y := Topo.AGORA_H
	var block := Vector3(19.5, y, 8.1)
	kit.lathe("bark", PackedVector2Array([Vector2(0.22, 0.0), Vector2(0.21, 0.42)]), 7, block, 1.0, false, "wood", true)
	kit.add_collider(block + Vector3(0, 0.21, 0), Vector3(0.44, 0.42, 0.44))
	for i in 18:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(0.3, 0.9)
		var p := block + Vector3(cos(a) * r, 0.01, sin(a) * r)
		kit.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), p)
		kit.box("wood", Vector3.ZERO, Vector3(rng.randf_range(0.05, 0.14), 0.012, rng.randf_range(0.02, 0.05)), [])
	kit.xform = Transform3D.IDENTITY
	# split logs stacked against the shed's back wall, east of the kiln
	var base := Vector3(19.6, y, 10.0)
	for row in 3:
		for i in 4 - row:
			var p := base + Vector3((i - (3 - row) / 2.0) * 0.24, 0.11 + row * 0.19, 0)
			kit.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), p)
			kit.lathe("bark", PackedVector2Array([Vector2(0.1, -0.45), Vector2(0.1, 0.45)]), 5, Vector3.ZERO, 1.0, false, "wood", true)
	kit.xform = Transform3D.IDENTITY
	kit.add_collider(base + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.9))


## Washing on a line across the second courtyard on the street, stirring a little.
func _washing() -> void:
	var street: Node = get_parent().get_node_or_null("Street")
	if street == null or street.courtyards.size() < 2:
		return
	var xf: Transform3D = street.courtyards[1]
	var line := MeshKit.new()
	line.xform = xf
	for sx: float in [-1.9, 1.9]:
		line.box("wood", Vector3(sx, 1.0, -3.2), Vector3(0.08, 2.0, 0.08), ["bottom"])
	line.box("dark", Vector3(0, 1.92, -3.2), Vector3(3.8, 0.02, 0.02), [])
	add_child(line.build("WashingLine"))
	var mats := ["chiton", "cloth", "chiton_dark"]
	for i in 3:
		var pivot := Node3D.new()
		pivot.transform = xf * Transform3D(Basis.IDENTITY, Vector3(-1.2 + i * 1.2, 1.92, -3.2))
		add_child(pivot)
		var k := MeshKit.new()
		var w := 0.45 + 0.1 * (i % 2)
		var h := 0.9 - 0.15 * i
		k.quad(mats[i], Vector3(-w, -h, 0), Vector3(w, -h, 0), Vector3(w, 0, 0), Vector3(-w, 0, 0))
		k.quad(mats[i], Vector3(w, -h, 0), Vector3(-w, -h, 0), Vector3(-w, 0, 0), Vector3(w, 0, 0))
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		pivot.add_child(mi)
		_cloths.append(pivot)


func _process(delta: float) -> void:
	_t += delta
	var q := floorf(_t * 15.0) / 15.0
	for i in _cloths.size():
		_cloths[i].rotation.x = sin(q * 1.3 + i * 1.7) * 0.12


## The pen as data, so the fence can be checked without building it: posts around
## a rectangle with a gate in the middle of the lane side, and the rails between
## them. A pen is closed by definition — the gate is the only opening.
static func yard_fence() -> Dictionary:
	var c := yard_pos()
	var front := c.z - YARD_DEPTH * 0.5
	var back := c.z + YARD_DEPTH * 0.5
	var left := c.x - YARD_HALF
	var right := c.x + YARD_HALF
	var gate := 0.55
	var posts: Array[Vector2] = []
	var rails: Array[Vector2i] = []
	# the lane side: two runs with the gate between them
	var front_xs: Array[float] = [left, c.x - 1.5, c.x - gate, c.x + gate, c.x + 1.5, right]
	for x: float in front_xs:
		posts.append(Vector2(x, front))
	for i in 4:
		if i == 2:
			continue  # the gate opening
		rails.append(Vector2i(i, i + 1))
	# both sides: a post every third of the depth, so no rail is a long plank
	var left_back := -1
	var right_back := -1
	for side: float in [left, right]:
		var corner := 0 if is_equal_approx(side, left) else 5
		var first := posts.size()
		for s in range(1, 4):
			posts.append(Vector2(side, front + (back - front) * float(s) / 3.0))
		rails.append(Vector2i(corner, first))
		for s in 2:
			rails.append(Vector2i(first + s, first + s + 1))
		if is_equal_approx(side, left):
			left_back = first + 2
		else:
			right_back = first + 2
	# the back: three posts between the corners
	var first_back := posts.size()
	for s in 3:
		posts.append(Vector2(left + (right - left) * float(s + 1) / 4.0, back))
	rails.append(Vector2i(left_back, first_back))
	rails.append(Vector2i(first_back, first_back + 1))
	rails.append(Vector2i(first_back + 1, first_back + 2))
	rails.append(Vector2i(first_back + 2, right_back))
	return {"centre": c, "posts": posts, "rails": rails, "gate": Vector2i(2, 3)}

## A yard across the lane from the well: a fenced pen with a gate standing open,
## hay in a manger, and a mule in it with nothing to do. Every post stands on the
## ground it is actually set in and every rail runs between two posts, because the
## ground here falls a quarter of a metre across the pen.
func _yard() -> void:
	var fence := yard_fence()
	var gate: Vector2i = fence["gate"]
	var posts: Array = fence["posts"]
	var kit := MeshKit.new()
	for p: Vector2 in posts:
		_yard_post(kit, p.x, p.y)
	for r: Vector2i in fence["rails"]:
		var a: Vector2 = posts[r.x]
		var b: Vector2 = posts[r.y]
		_yard_rail(kit, a, b, 0.55)
		_yard_rail(kit, a, b, 0.95)
	# the gate itself: one leaf standing open into the pen
	var hinge: Vector2 = posts[gate.x]
	var swing := deg_to_rad(58.0)
	var tip := hinge + Vector2(cos(swing), sin(swing)) * 1.05
	_yard_rail(kit, hinge, tip, 0.55)
	_yard_rail(kit, hinge, tip, 0.92)
	# manger with hay inside, by the back fence
	var m: Vector3 = (fence["centre"] as Vector3) + Vector3(-1.3, 0, 0.9)
	m.y = Topo.surface(m.x, m.z)
	kit.box("wood", m + Vector3(0, 0.34, 0), Vector3(1.5, 0.5, 0.5), ["bottom"], {})
	kit.box("bread", m + Vector3(0, 0.61, 0), Vector3(1.4, 0.2, 0.42), ["bottom"], {})
	kit.add_collider(m + Vector3(0, 0.22, 0), Vector3(1.5, 0.44, 0.5))
	add_child(kit.build("Yard"))
	var mule := Mule.new()
	mule.position = (fence["centre"] as Vector3) + Vector3(0.55, 0, 0.35)
	mule.position.y = Topo.surface(mule.position.x, mule.position.z)
	mule.rotation.y = deg_to_rad(125.0)  # head down to the manger, three quarters on
	add_child(mule)


## A fence post, standing on the ground where it is set.
func _yard_post(kit: MeshKit, x: float, z: float) -> void:
	var y := Topo.surface(x, z)
	kit.box("wood", Vector3(x, y + 0.55, z), Vector3(0.11, 1.15, 0.11), [], {})
	kit.add_collider(Vector3(x, y + 0.55, z), Vector3(0.11, 1.15, 0.11))


## A rail between two points on the ground, tilted to follow the slope between them.
func _yard_rail(kit: MeshKit, a: Vector2, b: Vector2, height: float) -> void:
	var pa := Vector3(a.x, Topo.surface(a.x, a.y) + height, a.y)
	var pb := Vector3(b.x, Topo.surface(b.x, b.y) + height, b.y)
	var dir := pb - pa
	var length := dir.length()
	if length < 0.02:
		return
	var x_axis := dir / length
	var z_axis := x_axis.cross(Vector3.UP).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	kit.xform = Transform3D(Basis(x_axis, y_axis, z_axis), (pa + pb) * 0.5)
	kit.box("wood", Vector3.ZERO, Vector3(length, 0.075, 0.06), [], {})
	kit.add_collider(Vector3.ZERO, Vector3(length, 0.075, 0.06))
	kit.xform = Transform3D.IDENTITY

## A stone well-head with a wooden frame and pulley, and a woman drawing water
## hand over hand, her hydria waiting by the curb.
func _well() -> void:
	var w := well_pos()
	var kit := MeshKit.new()
	kit.lathe("limestone", PackedVector2Array([Vector2(0.6, 0.0), Vector2(0.62, 0.12), Vector2(0.54, 0.2), Vector2(0.54, 0.74),
		Vector2(0.62, 0.8), Vector2(0.6, 0.86)]), 10, w, 2.0, false, "dark", true)
	kit.add_collider(w + Vector3(0, 0.43, 0), Vector3(1.24, 0.86, 1.24))
	for sx: float in [-0.78, 0.78]:
		kit.solid_box("wood", w + Vector3(sx, 1.1, 0), Vector3(0.12, 2.2, 0.12), ["bottom"])
	kit.box("wood", w + Vector3(0, 2.15, 0), Vector3(1.8, 0.12, 0.12), [])
	kit.xform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), w + Vector3(0, 1.98, 0))
	kit.lathe("wood", PackedVector2Array([Vector2(0.14, -0.04), Vector2(0.14, 0.04)]), 8, Vector3.ZERO, 1.0, false, "wood", true)  # pulley
	kit.xform = Transform3D.IDENTITY
	kit.box("cloth", w + Vector3(0, 1.4, -0.12), Vector3(0.03, 1.2, 0.03), [])  # the rope down into the shaft
	kit.xform = Transform3D(Basis(Vector3.RIGHT, -0.62), w + Vector3(0, 1.5, 0.32))
	kit.box("cloth", Vector3.ZERO, Vector3(0.03, 0.03, 0.95), [])  # and over to her hands
	kit.xform = Transform3D.IDENTITY
	add_child(kit.build("Well"))
	place("amphora", w + Vector3(0.75, 0, 0.75), 30.0, Vector3.ONE * 0.75)
	var woman: Npc = NPC.new()
	woman.npc_id = "water_carrier"
	woman.name_key = "NPC_SAILOR_NAME"
	woman.pose = "draw"
	woman.body_mat = "chiton"
	woman.talkable = false
	woman.position = w + Vector3(0, 0, 1.0)  # faces -z, the well
	add_child(woman)
	var hk := MeshKit.new()
	hk.box("hair", Vector3(0, 0.02, 0.12), Vector3(0.18, 0.3, 0.06), [])  # hair down the back
	hk.box("chiton_dark", Vector3(0, 0.25, 0.02), Vector3(0.23, 0.06, 0.25), [])  # kerchief
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit()
	(woman.joints["head"] as Node3D).add_child(hm)
	var sk := MeshKit.new()
	sk.box("chiton", Vector3(0, -0.45, 0), Vector3(0.36, 0.8, 0.26), [])  # a long chiton to the ankles
	var sm := MeshInstance3D.new()
	sm.mesh = sk.commit()
	(woman.joints["pelvis"] as Node3D).add_child(sm)
