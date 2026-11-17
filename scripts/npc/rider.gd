class_name Rider
extends Node3D
## A Scythian horseman, or a horse alone: the mule's build with short ears and a
## heavy mane (Mule.build_body), and on its back a figure in Scythian dress in
## the "ride" pose. It walks its route at a horse's walk and back again, legs
## stepping in diagonal pairs at 15 fps; a horse with no route stands, swishing
## its tail, and now and then puts its head down to the grass.
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
## Where along the route (metres from the start, folded back at the ends).
var travelled := 0.0
var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _joints := {}
var _t := 0.0


func _ready() -> void:
	var parts := Mule.build_body(self, HORSE)
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
		position = Vector3(p.x, Topo.terrain(p.x, p.y), p.y)
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
	if not _joints.is_empty():
		Figure.apply_pose(_joints, "ride", {"chest": Vector3(sin(q * 5.2) * 2.5 if moving else 0.0, 0, 0)})
