class_name Rider
extends Node3D
## A Scythian horseman, or a horse alone: the mule's build with short ears and a
## heavy mane (Mule.build_body), and on its back a figure in Scythian dress in
## the "ride" pose. It walks its route at a horse's walk and back again, legs
## stepping in diagonal pairs at 15 fps; a horse with no route stands, swishing
## its tail, and now and then puts its head down to the grass.
## The same walker carries the pack donkeys of the Street of Jars: a donkey's
## long ears ({"ears": 0.26}), baskets slung on its sides (`panniers`) and its
## driver on foot at its shoulder (`walker_look`, striding in step).
## No collider: weather, not furniture, like the hens and the mule.

const HORSE := {"ears": 0.11, "mane": 0.09}
## The rider's pelvis sits this high on the horse's back (over BODY_Y).
const SADDLE := 0.24
const WALK := 1.1  # m/s, a horse's walk

## Points on the ground (y ignored: Topo.terrain), walked to the end and back.
var route: Array[Vector3] = []
var speed := WALK
## The rider's Figure look; empty for a horse without a rider.
var rider_look: Dictionary = {}
## The animal's build for Mule.build_body (HORSE by default).
var body: Dictionary = HORSE
## A driver walking at its left shoulder (a Figure look); empty for none.
var walker_look: Dictionary = {}
## Two baskets slung over its back, one each side.
var panniers := false
## Follow the paving where there is any (Topo.surface), not the earth under it.
var on_paving := false
var _walker := {}
var _stride := 0.0
## Where along the route (metres from the start, folded back at the ends).
var travelled := 0.0
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _joints := {}
var _t := 0.0


func _ready() -> void:
	var parts := Mule.build_body(self, body)
	_legs.assign(parts.legs)
	_head = parts.head
	_tail = parts.tail
	if not rider_look.is_empty():
		var seat := Node3D.new()
		seat.name = "Rider"
		seat.position = Vector3(0, Mule.BODY_Y + SADDLE - Figure.SEAT["ride"], -0.05)
		add_child(seat)
		_joints = Figure.build(seat, "chiton", rider_look)
		Figure.apply_pose(_joints, "ride")
	if panniers:
		var pk := MeshKit.new()
		for sx: float in [-1.0, 1.0]:
			pk.lathe("basket", PackedVector2Array([Vector2(0.13, -0.24), Vector2(0.17, 0.1)]), 6,
					Vector3(sx * 0.34, Mule.BODY_Y - 0.02, 0.05), 1.0, true, "basket", false)
			pk.box("clay", Vector3(sx * 0.34, Mule.BODY_Y + 0.12, 0.05), Vector3(0.18, 0.08, 0.18), [])  # what it carries
		pk.box("cloth", Vector3(0, Mule.BODY_Y + 0.25, 0.05), Vector3(0.52, 0.04, 0.5), [])  # the pad over its back
		var pm := MeshInstance3D.new()
		pm.mesh = pk.commit()
		add_child(pm)
	if not walker_look.is_empty():
		var w := Node3D.new()
		w.name = "Driver"
		w.position = Vector3(-0.6, 0.0, -0.35)
		add_child(w)
		_walker = Figure.build(w, "chiton", walker_look)
		Figure.apply_pose(_walker, "walk")
	_t = float(hash(name) % 1000) / 100.0
	step(0.0)


## The route's length, start to end.
static func length_of(pts: Array[Vector3]) -> float:
	var n := 0.0
	for i in pts.size() - 1:
		n += Vector2(pts[i].x, pts[i].z).distance_to(Vector2(pts[i + 1].x, pts[i + 1].z))
	return n


## Where a rider is after going `s` metres along the route and back again
## (ping-pong), and which way it faces: [Vector2 position, Vector2 heading].
static func along(pts: Array[Vector3], s: float) -> Array:
	if pts.size() < 2:
		var p := Vector2(pts[0].x, pts[0].z) if not pts.is_empty() else Vector2.ZERO
		return [p, Vector2(0, -1)]
	var total := length_of(pts)
	var u := fposmod(s, total * 2.0)
	var back := u > total
	var d := total * 2.0 - u if back else u
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var seg := a.distance_to(b)
		if d <= seg or i == pts.size() - 2:
			var dir := (b - a).normalized()
			return [a.lerp(b, clampf(d / maxf(seg, 0.001), 0.0, 1.0)), -dir if back else dir]
		d -= seg
	return [Vector2(pts[-1].x, pts[-1].z), Vector2(0, -1)]


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_t += delta
	var q := floorf(_t * 15.0) / 15.0
	var moving := route.size() >= 2
	if moving:
		travelled += speed * delta
		var at: Array = along(route, travelled)
		var p: Vector2 = at[0]
		var h: Vector2 = at[1]
		position = Vector3(p.x, Topo.surface(p.x, p.y) if on_paving else Topo.terrain(p.x, p.y), p.y)
		# a horse faces its local -z, like a figure
		rotation.y = atan2(-h.x, -h.y)
	# the walk: diagonal pairs swinging; a standing horse shifts its weight
	var swing := sin(q * 5.2) * (24.0 if moving else 0.0)
	for i in _legs.size():
		var pair := 1.0 if i == 0 or i == 3 else -1.0
		_legs[i].rotation_degrees.x = swing * pair
	_tail.rotation_degrees.z = sin(q * 1.7) * 14.0
	# head: nodding at the walk; standing, now and then down to graze
	var graze := 0.0 if moving else clampf(sin(q * 0.35) * 2.0 - 0.8, 0.0, 1.0)
	_head.rotation_degrees.x = sin(q * 5.2) * 4.0 * (1.0 if moving else 0.0) - graze * 55.0
	if not _walker.is_empty():
		_stride = fposmod(_stride + speed * delta / 1.3, 1.0) if moving else _stride
		Figure.apply_pose(_walker, "walk", Figure.step_motion(_stride) if moving else {})
	if not _joints.is_empty():
		Figure.apply_pose(_joints, "ride", {"chest": Vector3(sin(q * 5.2) * 2.5 if moving else 0.0, 0, 0)})
