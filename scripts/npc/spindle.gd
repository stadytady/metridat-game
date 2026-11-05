class_name Spindle
extends Node3D
## A drop spindle hanging on its thread from a spinner's right hand. The thread
## stays plumb whatever the arm does, so the spindle is not parented to the hand:
## it follows the hand's position each frame. It turns and sinks as the yarn is
## drawn out, then is wound up to the hand again and the cycle repeats.

const CYCLE := 8.0  # seconds: drawing out, then winding up
const DRAW := 6.5  # of which drawing the yarn out
const TOP := 0.35  # thread length right after winding, m
const BOTTOM := 0.6  # thread length when she stops to wind, m
const TURNS := 3.0  # spindle turns per second while it hangs free

var hand: Node3D
var _t := 0.0
var _thread: MeshInstance3D
var _body: MeshInstance3D


## Thread length at time t: grows from TOP to BOTTOM while drawing, shrinks back
## while winding. Stepped at 15 fps like the figures.
static func drop(t: float) -> float:
	var k := fposmod(floorf(t * 15.0) / 15.0, CYCLE)
	if k < DRAW:
		return lerpf(TOP, BOTTOM, k / DRAW)
	return lerpf(BOTTOM, TOP, (k - DRAW) / (CYCLE - DRAW))


## Spindle's turn about the vertical, radians. It spins only while hanging free:
## when she winds the yarn on, she holds it still.
static func turn(t: float) -> float:
	var q := floorf(t * 15.0) / 15.0
	var whole := floorf(q / CYCLE)
	var k := minf(fposmod(q, CYCLE), DRAW)
	return fposmod((whole * DRAW + k) * TURNS * TAU, TAU)


## The distaff in the left hand, upright, with a hank of raw wool at its top.
## The pose's forearm is tipped forward 130 degrees; the stick undoes that and
## leans a little back and out, the wool by her shoulder.
static func hold_distaff(joints: Dictionary) -> void:
	var elbow: Node3D = joints.get("l_elbow")
	if elbow == null:
		return
	var grip := Node3D.new()
	grip.name = "Distaff"
	grip.position = Vector3(0, -0.27, 0)
	grip.rotation_degrees.x = -115.0
	grip.rotation_degrees.z = 15.0  # out to her left, clear of the face
	elbow.add_child(grip)
	var kit := MeshKit.new()
	kit.box("wood", Vector3(0, 0.16, 0), Vector3(0.025, 0.46, 0.025), [])
	kit.box("fleece", Vector3(0, 0.33, 0), Vector3(0.07, 0.14, 0.07), [])
	kit.box("fleece", Vector3(0, 0.33, 0), Vector3(0.09, 0.08, 0.09), [])
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	grip.add_child(mi)


## The point the thread hangs from: the right hand of the figure.
static func right_hand(joints: Dictionary) -> Node3D:
	var marker := Node3D.new()
	marker.name = "SpinHand"
	marker.position = Vector3(0, -0.29, 0)
	(joints["r_elbow"] as Node3D).add_child(marker)
	return marker


func _ready() -> void:
	var tk := MeshKit.new()
	tk.box("fleece", Vector3(0, -0.5, 0), Vector3(0.012, 1.0, 0.012), [])  # unit length, scaled
	_thread = MeshInstance3D.new()
	_thread.mesh = tk.commit()
	add_child(_thread)
	var bk := MeshKit.new()
	bk.box("wood", Vector3(0, -0.12, 0), Vector3(0.022, 0.26, 0.022), [])  # shaft
	bk.box("fleece", Vector3(0, -0.1, 0), Vector3(0.05, 0.1, 0.05), [])  # the cop of spun yarn
	bk.box("clay", Vector3(0, -0.2, 0), Vector3(0.09, 0.03, 0.09), [])  # whorl
	_body = MeshInstance3D.new()
	_body.mesh = bk.commit()
	add_child(_body)


func _process(delta: float) -> void:
	if hand == null or not hand.is_inside_tree():
		return
	_t += delta
	var top := hand.global_position
	var d := drop(_t)
	_thread.global_transform = Transform3D(Basis.from_scale(Vector3(1, d, 1)), top)
	_body.global_transform = Transform3D(Basis(Vector3.UP, turn(_t)), top - Vector3(0, d, 0))
