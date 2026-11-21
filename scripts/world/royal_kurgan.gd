class_name RoyalKurgan
extends District
## The Royal Kurgan out on the steppe below the park: the stone tomb of a
## Bosporan king (the real one near Kerch, 4th century BCE: a dromos ~37 m long
## under a stepped corbel vault, a square chamber closing in a stepped dome
## 8.84 m high, the whole under a mound ~17-20 m high). It looks the way it
## does today: a tall round mound in dry grass and scrub, and in its east side
## an open cut between low rubble walls leading to a dressed stone front with the
## tall, narrow, stepped mouth of the dromos in it. The chamber keeps its real
## size; the dromos and the mound are shortened (DROMOS_LEN, MOUND_H) to fit the
## terrace. Blocks still come from a quarry up the slope; a porter carries them
## to the pile by the cut, a mason finishes its walls, Xanthos the master
## builder stands at the cut (a talker). By lamplight the workers are gone;
## Xanthos stays.

const NPC := preload("res://scripts/npc/npc.gd")
const FLICKER := preload("res://scripts/world/flicker.gd")
const TAP := preload("res://assets/audio/hammer.wav")

## One course of blocks.
const COURSE := 0.44
## The chamber: inner half-width (4.4 m square), courses (8.8 m), the courses
## that rise straight before the walls step in, its outer half-width, the top
## inner half-width.
const CHAMBER_HALF := 2.2
const CHAMBER_COURSES := 20
const CHAMBER_UPRIGHT := 4
const CHAMBER_OUT := 2.9
const CHAMBER_TOP_HALF := 0.25
## The doorway from the dromos into the chamber.
const DOOR_HALF := 0.8
const DOOR_COURSES := 6
## The dromos: inner half-width (2.8 m wide at the floor), the courses that rise
## straight, the step each course after that takes inwards (small steps: the
## tall narrow mouth of the real one), and its outer half-width.
const DROMOS_HALF := 1.4
const DROMOS_UPRIGHT := 3
const DROMOS_STEP := 0.09
const DROMOS_OUT := 2.2
## The stone front the dromos opens in: where its outer face stands (east of the
## chamber's centre), how thick, how wide; its top is the mound's surface there.
const FACADE_X := 12.0
const FACADE_T := 0.8
const FACADE_HALF := 5.5
const DROMOS_LEN := FACADE_X - FACADE_T - CHAMBER_OUT
## The mound: its foot, its height at the crown, and how full its shoulders are.
const MOUND_R := 22.0
const MOUND_H := 12.0
const MOUND_SHAPE := 1.3
const MOUND_CELL := 0.5
## The open cut before the front: its half-width between the rubble walls, the
## walls' height, and how steeply the earth rises behind them.
const CUT_HALF := 2.6
const CUT_WALL := 1.0
const CUT_BANK := 2.0
## The quarry on the slope up towards the park: the foot of its face, the
## benches cut back into the hill (each BENCH_STEP higher and further east).
const QUARRY := Vector2(-122.5, 60.0)
const BENCHES := 3
const BENCH_DEPTH := 2.0
const BENCH_STEP := 0.9
const BENCH_WIDTH := 7.0
## People, relative to the chamber's centre: the builder by the cut, the mason
## at its north wall, the pile of blocks beside its mouth, the basket in the
## cut; the quarryman at the face and the porter's round (world x, z).
const BUILDER := Vector2(23.6, -2.6)
const MASON := Vector2(17.0, 1.9)
const PILE := Vector2(23.4, 4.6)
const BASKET := Vector2(15.6, -2.15)
const QUARRYMAN := Vector2(-123.6, 61.6)
const PORTER_ROUTE := [
	[-124.4, 58.2, "pick", 2.6, -90.0],
	[-126.8, 57.6, "walk", 0.0, NAN],
	[-128.6, 57.0, "pick", 1.6, 90.0],
	[-126.8, 57.6, "walk", 0.0, NAN],
]
const PORTER_TAKE := 0
const PORTER_DROP := 2
## The quarryman's pick, between blows (s).
const TAP_EVERY := 1.6
const TAP_REACH := 22.0
## How much of the sky's light gets in (vertex alpha, psx_lit's AO): at the
## mouth, at the back of the dromos, and in the chamber.
const AMBIENT_MOUTH := 0.6
const AMBIENT_DEEP := 0.03
const AMBIENT_CHAMBER := 0.02
## The dromos is built in pieces this long, so the dark can deepen along it.
const DROMOS_PIECE := 1.0
## Tufts of dry grass and scrub on the mound.
const TUFTS := 520
const SCRUB := 26

var _workers: Array[Npc] = []
var _lamp: OmniLight3D
var _tap: AudioStreamPlayer3D
var _tap_t := 0.0
var _atm: Node
var _home := true


static func center() -> Vector3:
	return Vector3(Topo.KURGAN_CENTER.x, Topo.KURGAN_H, Topo.KURGAN_CENTER.y)


## A point given relative to the chamber's centre (x east, z south), on the ground.
static func at(local: Vector2) -> Vector3:
	var p := Topo.KURGAN_CENTER + local
	return Vector3(p.x, Topo.terrain(p.x, p.y) + earth_height(p.x, p.y), p.y)


## The chamber's inner half-width at course i: straight, then stepping in.
static func chamber_half(i: int) -> float:
	if i < CHAMBER_UPRIGHT:
		return CHAMBER_HALF
	var u := float(i - CHAMBER_UPRIGHT + 1) / float(CHAMBER_COURSES - CHAMBER_UPRIGHT)
	return lerpf(CHAMBER_HALF, CHAMBER_TOP_HALF, u)


static func chamber_height() -> float:
	return CHAMBER_COURSES * COURSE


## The dromos's inner half-width at course i, and how many courses it takes to
## close (the last one before the cap).
static func dromos_half(i: int) -> float:
	return DROMOS_HALF - maxf(0.0, i - DROMOS_UPRIGHT + 1) * DROMOS_STEP


static func dromos_courses() -> int:
	var i := 0
	while dromos_half(i) > 0.3:
		i += 1
	return i + 1


## The top of the dromos's capstones over the floor.
static func dromos_height() -> float:
	return dromos_courses() * COURSE + 0.3


## Where the dromos starts (the chamber's east face) and where it meets the back
## of the front, as x offsets from the centre.
static func dromos_x0() -> float:
	return CHAMBER_OUT


static func dromos_x1() -> float:
	return FACADE_X - FACADE_T


## The mouth in the stone front, in the world.
static func mouth() -> Vector2:
	return Topo.KURGAN_CENTER + Vector2(FACADE_X, 0.0)


## How much of the sky's ambient light reaches the stone at x (offset east of
## the centre): falling off from the mouth to the back of the dromos, and the
## chamber beyond its door darker still.
static func ambient_at(x: float) -> float:
	if x < dromos_x0():
		return AMBIENT_CHAMBER
	var u := clampf((x - dromos_x0()) / (FACADE_X - dromos_x0()), 0.0, 1.0)
	return lerpf(AMBIENT_DEEP, AMBIENT_MOUTH, pow(u, 2.5))


## The mound's height at distance d from its centre: a full round crown.
static func mound_at(d: float) -> float:
	if d >= MOUND_R:
		return 0.0
	return MOUND_H * pow(1.0 - (d / MOUND_R) * (d / MOUND_R), MOUND_SHAPE)


## How high the earth stands over the terrace at (x, z): the mound, except in
## front of the stone front, where the cut runs in between its rubble walls and
## the earth banks up steeply behind them.
static func earth_height(x: float, z: float) -> float:
	var dx := x - Topo.KURGAN_CENTER.x
	var dz := z - Topo.KURGAN_CENTER.y
	var h := mound_at(sqrt(dx * dx + dz * dz))
	if dx < FACADE_X:
		return h
	var off := absf(dz)
	if off <= CUT_HALF:
		return 0.0
	return minf(h, CUT_WALL + (off - CUT_HALF) * CUT_BANK)


## The top of the front: the mound's surface over the mouth.
static func facade_top() -> float:
	return mound_at(FACADE_X - FACADE_T)


## Whether (x, z) is under the mound or in the quarry: the steppe's grass is not
## grown there (the mound has its own).
static func covers(x: float, z: float) -> bool:
	var dx := x - Topo.KURGAN_CENTER.x
	var dz := z - Topo.KURGAN_CENTER.y
	if Vector2(dx, dz).length() < MOUND_R + 0.5:
		return true
	return Topo.in_rect(x, z, quarry_center(), quarry_half())


## The floors the steppe's straw must not lie over: the chamber and the dromos
## (under the earth, but the straw sheet would show in them) and the cut.
static func stone_rects() -> Array[Rect2]:
	var c := Topo.KURGAN_CENTER
	var o := CHAMBER_OUT + 0.1
	return [Rect2(c.x - o, c.y - o, o * 2.0, o * 2.0),
		Rect2(c.x + dromos_x0(), c.y - DROMOS_OUT - 0.1, FACADE_X - dromos_x0(), (DROMOS_OUT + 0.1) * 2.0),
		Rect2(c.x + FACADE_X - FACADE_T, c.y - CUT_HALF - 0.6, MOUND_R - FACADE_X + FACADE_T + 0.5, (CUT_HALF + 0.6) * 2.0)]


static func over_stone(r: Rect2) -> bool:
	for s: Rect2 in stone_rects():
		if s.intersects(r):
			return true
	return false


## Inside the passage or the chamber (the floor the player walks in the dark).
static func inside(x: float, z: float) -> bool:
	var dx := x - Topo.KURGAN_CENTER.x
	var dz := z - Topo.KURGAN_CENTER.y
	if absf(dx) < CHAMBER_HALF and absf(dz) < CHAMBER_HALF:
		return true
	return dx > dromos_x0() and dx < FACADE_X and absf(dz) < DROMOS_HALF


static func quarry_center() -> Vector2:
	return QUARRY + Vector2(BENCHES * BENCH_DEPTH * 0.5, 0.0)


static func quarry_half() -> Vector2:
	return Vector2(BENCHES * BENCH_DEPTH * 0.5 + 1.0, BENCH_WIDTH * 0.5 + 0.5)


## The top of bench k: each one a step higher than the foot of the face.
static func bench_top(k: int) -> float:
	return Topo.terrain(QUARRY.x, QUARRY.y) + (k + 1) * BENCH_STEP


static func porter_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r: Array in PORTER_ROUTE:
		out.append(Vector2(r[0], r[1]))
	return out


## Whether the workers are out at this hour: by lamplight they have gone home.
static func at_work(hour: float) -> bool:
	return hour < DayCycle.LAMPS_ON


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	_chamber(kit)
	_dromos(kit)
	_facade(kit)
	_cut(kit)
	_pile(kit)
	_quarry(kit)
	add_child(kit.build("RoyalKurgan"))
	_mound()
	_growth()
	# a clay lamp on the chamber floor, left by the masons: the only light in there
	var lamp_at := center() + Vector3(-CHAMBER_HALF + 0.5, 0.06, CHAMBER_HALF - 0.5)
	var lk := MeshKit.new()
	lk.xform = Transform3D(Basis.from_scale(Vector3.ONE * 2.0), lamp_at)
	Props.oil_lamp(lk)
	add_child(lk.build("ChamberLamp"))
	_lamp = OmniLight3D.new()
	_lamp.set_script(FLICKER)
	_lamp.base_energy = 1.4
	_lamp.amount = 0.35
	_lamp.light_color = Color(1.0, 0.72, 0.42)
	_lamp.omni_range = 5.5
	_lamp.shadow_enabled = false
	_lamp.position = lamp_at + Vector3(0.0, 0.25, 0.0)
	add_child(_lamp)
	# the block on top of the pile, the next to go in
	spawn_inspectable("corbel_block", at(PILE) + Vector3(0.05, 0.88, 0.05), 80.0)
	spawn_inspectable("earth_basket", at(BASKET) + Vector3(0, 0.06, 0), 30.0)
	_builder()
	_mason()
	_quarryman()
	_porter()
	_tap = AudioStreamPlayer3D.new()
	_tap.stream = TAP
	_tap.pitch_scale = 0.72
	_tap.unit_size = 5.0
	_tap.max_distance = TAP_REACH
	_tap.volume_db = -8.0
	_tap.position = Vector3(QUARRY.x + 0.5, bench_top(0), QUARRYMAN.y)
	add_child(_tap)
	step(_hour())


func _chamber(kit: MeshKit) -> void:
	var c := center()
	kit.color = Color(1, 1, 1, AMBIENT_CHAMBER)
	kit.solid_box("limestone", c + Vector3(0, 0.03, 0), Vector3(CHAMBER_HALF * 2.0, 0.06, CHAMBER_HALF * 2.0), [])
	for i in CHAMBER_COURSES:
		var w := chamber_half(i)
		var o := CHAMBER_OUT
		var y := c.y + (i + 0.5) * COURSE
		var t := o - w
		# where a course oversails the one below, its underside is in sight
		var skip: Array = ["bottom"] if i < CHAMBER_UPRIGHT else []
		# north and south run the full width, west and east fit between them
		for s: float in [-1.0, 1.0]:
			kit.solid_box("limestone", Vector3(c.x, y, c.z + s * (w + t / 2.0)), Vector3(o * 2.0, COURSE, t), skip)
		kit.solid_box("limestone", Vector3(c.x - w - t / 2.0, y, c.z), Vector3(t, COURSE, w * 2.0), skip)
		var ex := c.x + w + t / 2.0
		if i < DOOR_COURSES:
			var side := w - DOOR_HALF
			for s: float in [-1.0, 1.0]:
				kit.solid_box("limestone", Vector3(ex, y, c.z + s * (DOOR_HALF + side / 2.0)), Vector3(t, COURSE, side), skip)
		else:
			kit.solid_box("limestone", Vector3(ex, y, c.z), Vector3(t, COURSE, w * 2.0), skip)
	var top := c.y + chamber_height()
	kit.solid_box("limestone", Vector3(c.x, top + 0.15, c.z), Vector3(CHAMBER_OUT * 2.0, 0.3, CHAMBER_OUT * 2.0), [])
	kit.color = Color.WHITE


func _dromos(kit: MeshKit) -> void:
	var c := center()
	var n := dromos_courses()
	# the doorway's floor, through the chamber's wall
	kit.color = Color(1, 1, 1, AMBIENT_CHAMBER)
	kit.solid_box("limestone", Vector3(c.x + (CHAMBER_HALF + CHAMBER_OUT) / 2.0, c.y + 0.03, c.z), Vector3(CHAMBER_OUT - CHAMBER_HALF, 0.06, DOOR_HALF * 2.0), [])
	# in pieces along its length, each a shade lighter towards the mouth
	var x := dromos_x0()
	while x < FACADE_X - 0.001:
		var x1 := minf(x + DROMOS_PIECE, FACADE_X)
		kit.color = Color(1, 1, 1, ambient_at((x + x1) / 2.0))
		var mid := c.x + (x + x1) / 2.0
		var len := x1 - x
		kit.solid_box("limestone", Vector3(mid, c.y + 0.03, c.z), Vector3(len, 0.06, DROMOS_HALF * 2.0), [])
		# the walls stop at the back of the front; the floor runs out through it
		if x < dromos_x1():
			var wx1 := minf(x1, dromos_x1())
			var wmid := c.x + (x + wx1) / 2.0
			var wlen := wx1 - x
			for i in n:
				var w := dromos_half(i)
				var y := c.y + (i + 0.5) * COURSE
				var t := DROMOS_OUT - w
				var skip: Array = ["bottom"] if i < DROMOS_UPRIGHT else []
				for s: float in [-1.0, 1.0]:
					kit.solid_box("limestone", Vector3(wmid, y, c.z + s * (w + t / 2.0)), Vector3(wlen, COURSE, t), skip)
			kit.solid_box("limestone", Vector3(wmid, c.y + n * COURSE + 0.15, c.z), Vector3(wlen, 0.3, DROMOS_OUT * 2.0), [])
		x = x1
	kit.color = Color.WHITE


## The dressed front: coursed blocks up to the mound's surface, the mouth left
## open in the dromos's own stepped profile, so it reads tall and narrow.
func _facade(kit: MeshKit) -> void:
	var c := center()
	var x := c.x + FACADE_X - FACADE_T / 2.0
	var top := facade_top()
	var n := dromos_courses()
	var i := 0
	while i * COURSE < top:
		var hgt := minf(COURSE, top - i * COURSE)
		var y := c.y + i * COURSE + hgt / 2.0
		if i < n:
			var w := dromos_half(i)
			var side := FACADE_HALF - w
			var skip: Array = ["bottom"] if i < DROMOS_UPRIGHT else []
			for s: float in [-1.0, 1.0]:
				kit.solid_box("limestone", Vector3(x, y, c.z + s * (w + side / 2.0)), Vector3(FACADE_T, hgt, side), skip)
		else:
			kit.solid_box("limestone", Vector3(x, y, c.z), Vector3(FACADE_T, hgt, FACADE_HALF * 2.0), [])
		i += 1


## The cut: a gravel floor out from the front to the mound's foot, and a low wall
## of rough stones each side holding back the earth. Stones sized from their
## index, not an rng: nothing after them moves.
func _cut(kit: MeshKit) -> void:
	var c := center()
	var x0 := c.x + FACADE_X
	var x1 := c.x + MOUND_R + 0.5
	kit.box("path", Vector3((x0 + x1) / 2.0, c.y + 0.02, c.z), Vector3(x1 - x0, 0.04, CUT_HALF * 2.0), ["bottom"])
	for s: float in [-1.0, 1.0]:
		var x := x0
		var k := 0
		while x < x1:
			var l := 0.55 + 0.25 * float((k * 7) % 5) / 4.0
			var lx := minf(l, x1 - x)
			var h := CUT_WALL * (0.85 + 0.15 * float((k * 3) % 4) / 3.0)
			var tint := 0.82 + 0.06 * float((k * 5) % 4)
			kit.color = Color(tint, tint, tint * 0.97)
			kit.solid_box("limestone", Vector3(x + lx / 2.0, c.y + h / 2.0, c.z + s * (CUT_HALF + 0.25)), Vector3(lx - 0.04, h, 0.5), ["bottom"])
			x += l
			k += 1
	kit.color = Color.WHITE


## The blocks the porter has brought down, stacked beside the cut.
func _pile(kit: MeshKit) -> void:
	var p := at(PILE)
	for b: Array in [[Vector3(-0.5, 0.22, 0.0), 0.0], [Vector3(0.55, 0.22, 0.1), 0.2], [Vector3(0.05, 0.66, 0.05), -0.15],
			[Vector3(0.1, 0.22, 0.85), 0.5]]:
		kit.xform = Transform3D(Basis(Vector3.UP, b[1]), p + (b[0] as Vector3))
		kit.box("limestone", Vector3.ZERO, Vector3(0.9, 0.44, 0.55), [])
	kit.xform = Transform3D.IDENTITY
	kit.add_collider(p + Vector3(0.05, 0.44, 0.3), Vector3(1.9, 0.88, 1.6))


## The quarry: benches stepping back into the slope, their faces to the west,
## and blocks cut free lying at the foot.
func _quarry(kit: MeshKit) -> void:
	var foot := Topo.terrain(QUARRY.x, QUARRY.y)
	for k in BENCHES:
		var x := QUARRY.x + k * BENCH_DEPTH + BENCH_DEPTH / 2.0
		var lo := foot - 1.5
		var hi := bench_top(k)
		# the living rock, not coursed masonry: only what is cut free is block
		kit.solid_box("rock", Vector3(x, (lo + hi) / 2.0, QUARRY.y), Vector3(BENCH_DEPTH, hi - lo, BENCH_WIDTH - k * 0.8), ["bottom"])
	var cut := Vector3(QUARRY.x + 0.5, bench_top(0) + 0.002, QUARRY.y + 1.6)
	kit.box("dark", cut + Vector3(0, 0, -0.32), Vector3(1.0, 0.004, 0.06), ["bottom"])
	kit.box("dark", cut + Vector3(0.48, 0, 0), Vector3(0.06, 0.004, 0.6), ["bottom"])
	for b: Array in [[Vector2(-1.4, -1.8), 0.3], [Vector2(-2.2, 0.4), -0.2], [Vector2(-1.2, 2.6), 0.6]]:
		var q := QUARRY + (b[0] as Vector2)
		kit.xform = Transform3D(Basis(Vector3.UP, b[1]), Vector3(q.x, Topo.terrain(q.x, q.y), q.y))
		kit.box("limestone", Vector3(0, 0.2, 0), Vector3(0.9, 0.44, 0.55), [])
	kit.xform = Transform3D.IDENTITY


## The mound: a height grid over the terrace, in dry grass, with a body of its own
## shape. Where the earth drops sheer (behind the stone front) no face is made:
## the front stands there, and a slope through it would close the mouth.
func _mound() -> void:
	var kit := MeshKit.new()
	var c := center()
	var n := int(ceil((MOUND_R + 0.5) / MOUND_CELL))
	for j in range(-n, n):
		for i in range(-n, n):
			var x0 := c.x + i * MOUND_CELL
			var z0 := c.z + j * MOUND_CELL
			var x1 := x0 + MOUND_CELL
			var z1 := z0 + MOUND_CELL
			var hs := [earth_height(x0, z0), earth_height(x0, z1), earth_height(x1, z1), earth_height(x1, z0)]
			var lo: float = hs.min()
			var hi: float = hs.max()
			if hi <= 0.0 or hi - lo > 2.5:
				continue
			var y := c.y - 0.02
			kit.quad("steppe", Vector3(x0, y + hs[0], z0), Vector3(x0, y + hs[1], z1), Vector3(x1, y + hs[2], z1), Vector3(x1, y + hs[3], z0),
					PackedVector2Array([Vector2(x0, z0) * 0.3, Vector2(x0, z1) * 0.3, Vector2(x1, z1) * 0.3, Vector2(x1, z0) * 0.3]))
	var root := kit.build("Mound", &"dirt")
	add_child(root)
	var mi: MeshInstance3D = root.get_node_or_null("Mesh")
	if mi != null:
		root.add_child(District.trimesh_body(mi.mesh, &"dirt"))


## Dry grass and low scrub over the mound, as it stands today: tufts as crossed
## blades, bushes as dark blobs. Its own rng, so nothing else moves.
func _growth() -> void:
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5470
	var c := center()
	for t in TUFTS:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (MOUND_R - 0.5)
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		var h := earth_height(x, z)
		var s := rng.randf_range(0.3, 0.6)
		var yaw := rng.randf() * PI
		if h < 0.2:
			continue
		Props.tuft(kit, Vector3(x, c.y + h - 0.02, z), s, yaw, 0.75 + 0.25 * fmod(float(t) * 0.618, 1.0))
	for b in SCRUB:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, MOUND_R - 2.0)
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		var rad := rng.randf_range(0.5, 1.1)
		var h := earth_height(x, z)
		if h < 0.3:
			continue
		kit.color = Color(0.75, 0.66, 0.55)
		kit.blob("bark", Vector3(x, c.y + h + rad * 0.3, z), Vector3(rad, rad * 0.7, rad), 0.3, rng)
	kit.color = Color.WHITE
	add_child(kit.build("Growth"))


func _builder() -> void:
	var n: Npc = NPC.new()
	n.name = "Builder"
	n.npc_id = "builder"
	n.name_key = "NPC_BUILDER_NAME"
	n.dialogue = load("res://data/dialogues/builder.dialogue") as DialogueResource
	n.look = {"beard": 2, "hair": 0, "cloth": "chiton_dark"}
	n.pose = "stand"
	n.position = at(BUILDER)
	# a figure faces its local -z: turned to whoever comes down from the park
	var d := Vector2(-1.0, 0.15)
	n.rotation.y = atan2(d.x, d.y)
	add_child(n)


func _worker(id: String, look: Dictionary, pos: Vector3, yaw: float, pose: String) -> Npc:
	var n: Npc = NPC.new()
	n.name = id.capitalize()
	n.npc_id = id
	n.name_key = "NPC_BUILDER_NAME"
	n.look = look
	n.pose = pose
	n.talkable = false
	n.solid = false
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	_workers.append(n)
	return n


func _mason() -> void:
	# in the cut, bent over the north wall he is setting
	_worker("kurgan_mason", {"beard": 1, "hair": 2, "cloth": "chiton_ochre"}, at(MASON), 0.0, "pick")


func _quarryman() -> void:
	var p := Vector3(QUARRYMAN.x, Topo.terrain(QUARRYMAN.x, QUARRYMAN.y), QUARRYMAN.y)
	_worker("quarryman", {"beard": 0, "hair": 1, "cloth": "chiton"}, p, -PI / 2.0, "pick")


func _porter() -> void:
	var r0: Array = PORTER_ROUTE[0]
	var p := Vector3(r0[0], Topo.terrain(r0[0], r0[1]), r0[1])
	var n := _worker("kurgan_porter", {"beard": 1, "hair": 0, "cloth": "chiton_dark"}, p, 0.0, "stand")
	n.follow_ground = true
	var home := Vector3(r0[0], 0, r0[1])
	var pts := PackedVector3Array()
	var poses := PackedStringArray()
	var pauses := PackedFloat32Array()
	var faces := PackedFloat32Array()
	for r: Array in PORTER_ROUTE:
		pts.append(Vector3(r[0], 0, r[1]) - home)
		poses.append(r[2])
		pauses.append(r[3])
		faces.append(r[4])
	n.patrol = pts
	n.patrol_poses = poses
	n.patrol_pauses = pauses
	n.patrol_faces = faces
	n.patrol_speed = 0.7
	n.stops_for_player = false
	n.carry_pose = "carry"
	var block := MeshInstance3D.new()
	var bk := MeshKit.new()
	bk.box("limestone", Vector3.ZERO, Vector3(0.5, 0.28, 0.34), [])
	block.mesh = bk.commit()
	block.position = Vector3(0, 0.02, -0.3)
	(n.joints["chest"] as Node3D).add_child(block)
	block.visible = false
	n.reached.connect(func(k: int) -> void:
		if k == PORTER_TAKE:
			block.visible = true
			n.carrying = true
		elif k == PORTER_DROP:
			block.visible = false
			n.carrying = false)


func _hour() -> float:
	return float(_atm.t) if _atm != null else Game.time_target()


func _process(delta: float) -> void:
	step(_hour())
	if _home:
		return
	_tap_t += delta
	if _tap_t >= TAP_EVERY:
		_tap_t = fmod(_tap_t, TAP_EVERY)
		_tap.play()
		Game.caption("CAP_QUARRY", _tap.global_position, TAP_REACH)


func step(hour: float) -> void:
	var home := not at_work(hour)
	if home == _home and not _workers.is_empty() and _workers[0].visible == not home:
		return
	_home = home
	for w: Npc in _workers:
		w.visible = not home
		w.process_mode = Node.PROCESS_MODE_DISABLED if home else Node.PROCESS_MODE_INHERIT
	_lamp.visible = not home


func builder() -> Npc:
	return get_node("Builder")


func workers() -> Array[Npc]:
	return _workers
