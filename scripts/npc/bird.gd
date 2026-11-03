class_name Bird
extends Node3D
## A gull soaring in circles over the water, or a pigeon pecking on the agora
## that bursts up into a loop over the square when someone comes close and
## settles again. Rigid boxes like the hens, wings flapped at a stepped 15 fps.
## No collider (AGENTS.md, invariant 4). Both are gone by night. Faces -Z.

enum Kind { GULL, PIGEON }

const FLIGHT_TIME := 7.0
const SCARE_DIST := 3.0

var kind := Kind.GULL
## Gull: centre of its circle (y is the height). Pigeon: the patch it feeds on.
var home := Vector3.ZERO
var radius := 10.0
## Gull: rad/s round the circle, sign is the direction.
var speed := 0.25
## Pigeon: times it has taken off (the walkthrough checks it).
var took_off := 0
var flying := false

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _parts := {}
var _from := Vector3.ZERO
var _land := Vector3.ZERO
var _flight := 0.0
var _peck_in := 0.0


func _ready() -> void:
	add_to_group(&"bird")
	add_to_group(&"gull" if kind == Kind.GULL else &"pigeon")
	_rng.seed = hash(name)
	_t = _rng.randf() * 20.0
	_build()
	if kind == Kind.GULL:
		scale = Vector3.ONE * 1.4  # a few pixels against the sky must still read
		position = soar_at(home, radius, speed, _t)
	else:
		position = _spot()
		rotation.y = _rng.randf_range(0, TAU)
		flying = false


func _part(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	_parts[n] = p
	return p


func _mesh(parent: Node3D, kit: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build() -> void:
	var gull := kind == Kind.GULL
	var f := "hen_white" if gull else "pigeon"
	var k := 1.0 if gull else 0.7
	var body := _part("body", self, Vector3(0, 0.1 * k, 0))
	var bk := MeshKit.new()
	bk.box(f, Vector3.ZERO, Vector3(0.12, 0.12, 0.4) * k, [])
	bk.box(f, Vector3(0, 0.03, -0.24) * k, Vector3(0.09, 0.09, 0.1) * k, [])  # head
	bk.box("beak", Vector3(0, 0.02, -0.32) * k, Vector3(0.03, 0.025, 0.07) * k, [])
	bk.box("dark" if not gull else f, Vector3(0, 0.0, 0.26) * k, Vector3(0.1, 0.02, 0.14) * k, [])  # tail
	if not gull:
		bk.box("rooster_tail", Vector3(0, 0.0, -0.17) * k, Vector3(0.1, 0.1, 0.06) * k, [])  # green-sheened neck
	_mesh(body, bk)
	for s: float in [1.0, -1.0]:
		var w := _part("wing_l" if s < 0 else "wing_r", body, Vector3(0.06 * s, 0.03, -0.02) * k)
		var wk := MeshKit.new()
		wk.box(f, Vector3(0.28 * s, 0, 0) * k, Vector3(0.56, 0.02, 0.18) * k, [])
		wk.box("dark", Vector3(0.5 * s, 0.001, 0.01) * k, Vector3(0.14, 0.022, 0.15) * k, [])  # wing tip
		_mesh(w, wk)


## Wing angle in degrees at a stepped 15 fps: a full beat when flapping, a
## shallow dihedral when gliding.
static func wing_angle(t: float, flapping: bool) -> float:
	var q := floorf(t * 15.0) / 15.0
	return sin(q * 14.0) * 50.0 if flapping else 8.0


## Gulls glide most of the time and beat their wings for a second or so now and then.
static func gull_flapping(t: float) -> bool:
	return fposmod(t, 7.0) < 1.2


## A point on the gull's circle; the height wobbles a little.
static func soar_at(centre: Vector3, r: float, w: float, t: float) -> Vector3:
	var a := t * w
	return centre + Vector3(cos(a) * r, sin(t * 0.4) * 1.5, sin(a) * r)


## A pigeon's flight from where it took off to where it lands, s in 0..1:
## up into a wide loop over the square and down again.
static func flight_at(from: Vector3, land: Vector3, s: float) -> Vector3:
	s = clampf(s, 0.0, 1.0)
	var lift := sin(PI * s)
	var a := s * TAU
	return from.lerp(land, s) + Vector3(sin(a) * 5.0 * lift, 6.0 * lift, (1.0 - cos(a)) * 2.0 * lift)


func _spot() -> Vector3:
	var a := _rng.randf_range(0, TAU)
	var r := _rng.randf_range(0.0, radius)
	return home + Vector3(cos(a) * r, 0, sin(a) * r)


func _process(delta: float) -> void:
	_t += delta
	visible = Game.time_target() < 0.85
	if not visible:
		return
	if kind == Kind.GULL:
		_soar()
	else:
		_pigeon(delta)


func _soar() -> void:
	var p := soar_at(home, radius, speed, _t)
	var ahead := soar_at(home, radius, speed, _t + 0.2)
	position = p
	_face(ahead - p)
	rotation.z = -0.35 * signf(speed)  # banked into the turn
	_wings(wing_angle(_t, gull_flapping(_t + float(hash(name) % 7))))


func _pigeon(delta: float) -> void:
	if flying:
		_flight += delta / FLIGHT_TIME
		var p := flight_at(_from, _land, _flight)
		_face(flight_at(_from, _land, _flight + 0.02) - p)
		position = p
		_wings(wing_angle(_t, _flight < 0.85))
		(_parts.body as Node3D).rotation.x = 0.0
		if _flight >= 1.0:
			flying = false
			position = _land
			_peck_in = _rng.randf_range(0.5, 2.0)
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var c := cam.global_position
		if Vector2(c.x - global_position.x, c.z - global_position.z).length() < SCARE_DIST and absf(c.y - global_position.y) < 3.0:
			flying = true
			took_off += 1
			_flight = 0.0
			_from = position
			_land = _spot()
			return
	_wings(0.0, 0.3)  # folded against the body
	_peck_in -= delta
	var peck := _peck_in < 0.3
	if _peck_in <= 0.0:
		_peck_in = _rng.randf_range(0.8, 3.0)
		rotation.y += _rng.randf_range(-1.0, 1.0)
	(_parts.body as Node3D).rotation.x = -0.5 if peck and floori(_t * 15.0) % 4 < 2 else 0.0


func _face(d: Vector3) -> void:
	if Vector2(d.x, d.z).length() > 0.001:
		rotation.y = atan2(-d.x, -d.z)


func _wings(deg: float, span: float = 1.0) -> void:
	for n: String in ["wing_r", "wing_l"]:
		var w := _parts[n] as Node3D
		w.rotation_degrees.z = deg if n == "wing_r" else -deg
		w.scale = Vector3(span, 1, 1)
