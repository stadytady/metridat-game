class_name Mule
extends Node3D
## A yard mule, built from boxes the way the dog and the hens are: a low barrel
## on four legs, a neck carried forward, long ears and a tail that never stops.
## Everything is stepped at 15 fps.

const BODY_Y := 1.12

var _head: Node3D
var _tail: Node3D
var _ear_l: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"mule")
	_t = randf() * 4.0
	var kit := MeshKit.new()
	# barrel low and long, with a deeper chest and a rounded croup
	kit.box("fur", Vector3(0, BODY_Y, 0.0), Vector3(0.46, 0.46, 1.05), [])
	kit.box("fur", Vector3(0, BODY_Y + 0.02, -0.5), Vector3(0.42, 0.44, 0.36), [])
	kit.box("fur", Vector3(0, BODY_Y, 0.5), Vector3(0.4, 0.4, 0.3), [])
	# four legs, thick enough to read at 640x360, with dark hooves
	for sx: float in [-0.15, 0.15]:
		for sz: float in [-0.42, 0.44]:
			kit.box("fur", Vector3(sx, 0.5, sz), Vector3(0.13, 0.95, 0.15), [])
			kit.box("dark", Vector3(sx, 0.03, sz), Vector3(0.15, 0.06, 0.17), [])
	add_child(kit.build("Mule"))
	# neck and head on a pivot at the withers, so the head can hang into the hay
	_head = Node3D.new()
	_head.position = Vector3(0, BODY_Y + 0.16, -0.58)
	add_child(_head)
	var hk := MeshKit.new()
	hk.box("fur", Vector3(0, 0.1, -0.06), Vector3(0.2, 0.42, 0.24), [])  # neck
	hk.box("hair", Vector3(0, 0.14, -0.19), Vector3(0.06, 0.34, 0.08), [])  # mane down the back of the neck
	hk.box("fur", Vector3(0, 0.24, -0.28), Vector3(0.17, 0.2, 0.36), [])  # skull
	hk.box("fur", Vector3(0, 0.18, -0.48), Vector3(0.13, 0.14, 0.16), [])  # muzzle
	hk.box("dark", Vector3(0, 0.16, -0.56), Vector3(0.09, 0.08, 0.04), [])  # nose
	hk.box("dark", Vector3(0.075, 0.26, -0.3), Vector3(0.03, 0.03, 0.03), [])  # eyes
	hk.box("dark", Vector3(-0.075, 0.26, -0.3), Vector3(0.03, 0.03, 0.03), [])
	hk.box("fur", Vector3(0.06, 0.42, -0.2), Vector3(0.05, 0.26, 0.05), [])  # ears, long as a mule's
	hk.box("fur", Vector3(-0.06, 0.42, -0.2), Vector3(0.05, 0.26, 0.05), [])
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit()
	_head.add_child(hm)
	_ear_l = _head
	# tail on its own pivot
	_tail = Node3D.new()
	_tail.position = Vector3(0, BODY_Y + 0.18, 0.6)
	add_child(_tail)
	var tk := MeshKit.new()
	tk.box("hair", Vector3(0, -0.26, 0), Vector3(0.05, 0.5, 0.05), [])
	tk.box("dark", Vector3(0, -0.54, 0), Vector3(0.09, 0.12, 0.09), [])
	var tm := MeshInstance3D.new()
	tm.mesh = tk.commit()
	_tail.add_child(tm)


func _process(delta: float) -> void:
	_t += delta
	var q := floorf(_t * 15.0) / 15.0
	# head hangs into the hay and lifts now and then
	_head.rotation_degrees.x = -14.0 + sin(q * 0.8) * 7.0
	_tail.rotation_degrees.z = sin(q * 2.1) * 14.0
