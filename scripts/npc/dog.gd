class_name Dog
extends Node3D
## A dog asleep against a wall, curled up, built like the hens from rigid
## boxes: it breathes and now and then twitches an ear (stepped at 15 fps,
## PS1-style). No collider: it is never in the way. Faces -Z, head on its paws.

## Set by Omens at night: a point the dog lifts its head to watch. INF: asleep.
var watch := Vector3.INF
var _parts := {}
var _t := 0.0
var _twitch_at := 3.0


func _ready() -> void:
	add_to_group(&"dog")
	_t = randf() * 5.0
	# Lying stretched out on its side-ish, head forward on the front paws:
	# the silhouette (long body, head, pricked ears, legs) reads as a dog.
	var body := _part("body", self, Vector3(0, 0.13, 0.05))
	var k := MeshKit.new()
	k.box("fur", Vector3(0, 0, 0), Vector3(0.28, 0.22, 0.6), [])  # ribcage and loin
	k.box("fur", Vector3(0, 0.0, -0.33), Vector3(0.24, 0.2, 0.12), [])  # chest
	k.box("fur", Vector3(0.14, -0.05, 0.22), Vector3(0.1, 0.16, 0.24), [])  # haunch
	k.box("fur", Vector3(0.1, -0.11, 0.42), Vector3(0.22, 0.05, 0.08), [])  # hind paw tucked forward
	k.box("fur", Vector3(-0.1, -0.06, 0.4), Vector3(0.05, 0.05, 0.3), [])  # tail laid along the side
	_mesh(body, k)
	var legs := MeshKit.new()
	for s: float in [1.0, -1.0]:
		legs.box("fur", Vector3(0.07 * s, 0.03, -0.55), Vector3(0.06, 0.06, 0.32), [])  # front legs stretched out
	var lmi := MeshInstance3D.new()
	lmi.mesh = legs.commit()
	add_child(lmi)
	var head := _part("head", self, Vector3(0, 0.15, -0.6))
	var hk := MeshKit.new()
	hk.box("fur", Vector3(0, 0, 0), Vector3(0.18, 0.15, 0.18), [])  # skull
	hk.box("fur", Vector3(0, -0.035, -0.15), Vector3(0.1, 0.08, 0.14), [])  # muzzle resting on the paws
	hk.box("dark", Vector3(0, -0.02, -0.225), Vector3(0.05, 0.04, 0.02), [])  # nose
	hk.box("dark", Vector3(0.06, 0.025, -0.091), Vector3(0.04, 0.012, 0.01), [])  # closed eyes
	hk.box("dark", Vector3(-0.06, 0.025, -0.091), Vector3(0.04, 0.012, 0.01), [])
	_mesh(head, hk)
	for s: float in [1.0, -1.0]:
		var ear := _part("ear_l" if s < 0 else "ear_r", head, Vector3(0.06 * s, 0.075, 0.03))
		var ek := MeshKit.new()
		ek.box("fur", Vector3(0, 0.05, 0), Vector3(0.05, 0.1, 0.04), [])  # pricked
		_mesh(ear, ek)


func _part(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	_parts[name] = n
	return n


func _mesh(parent: Node3D, kit: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	parent.add_child(mi)


## Breath and ear at a stepped 15 fps: (body scale y, ear tilt in degrees).
static func pose_at(t: float, twitch_at: float) -> Vector2:
	var q := floorf(t * 15.0) / 15.0
	var breath := 1.0 + 0.04 * sin(q * 2.2)
	var since := q - twitch_at
	var ear := 25.0 if since >= 0.0 and since < 0.2 else 0.0
	return Vector2(breath, ear)


func _process(delta: float) -> void:
	_t += delta
	if _t > _twitch_at + 0.4:
		_twitch_at = _t + randf_range(3.0, 9.0)
	var p := pose_at(_t, _twitch_at)
	(_parts.body as Node3D).scale = Vector3(1, p.x, 1)
	var head := _parts.head as Node3D
	if watch == Vector3.INF:
		head.position = Vector3(0, 0.15, -0.6)
		head.rotation = Vector3.ZERO
		(_parts.ear_r as Node3D).rotation_degrees.x = -p.y
		return
	# awake: head up off the paws, turned to what it hears, ears still
	head.position = Vector3(0, 0.3, -0.52)
	var to := global_transform.affine_inverse() * watch - head.position
	head.rotation = Vector3(clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.2, 0.5), clampf(atan2(-to.x, -to.z), -1.2, 1.2), 0)
	(_parts.ear_r as Node3D).rotation_degrees.x = 0.0
