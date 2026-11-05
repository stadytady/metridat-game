class_name Figure
extends RefCounted
## Rigid-segment low-poly person, the way PS1 games built characters: one box
## mesh per body part hanging off a joint (Node3D), animated by rotating the
## joints. Faces -Z. A positive X rotation swings a hanging limb forward, but
## tips an upright segment (chest, head) backwards: lean forward is negative X.

## joint name -> [parent, offset from parent, segment size, segment material, segment centre offset]
const RIG := {
	"pelvis": ["", Vector3(0, 0.92, 0), Vector3(0.32, 0.16, 0.2), "chiton", Vector3(0, 0, 0)],
	"chest": ["pelvis", Vector3(0, 0.08, 0), Vector3(0.36, 0.5, 0.21), "chiton", Vector3(0, 0.25, 0)],
	"head": ["chest", Vector3(0, 0.52, 0), Vector3(0.19, 0.23, 0.21), "skin", Vector3(0, 0.13, 0)],
	"l_shoulder": ["chest", Vector3(-0.23, 0.46, 0), Vector3(0.09, 0.3, 0.09), "skin", Vector3(0, -0.15, 0)],
	"l_elbow": ["l_shoulder", Vector3(0, -0.3, 0), Vector3(0.08, 0.28, 0.08), "skin", Vector3(0, -0.14, 0)],
	"r_shoulder": ["chest", Vector3(0.23, 0.46, 0), Vector3(0.09, 0.3, 0.09), "skin", Vector3(0, -0.15, 0)],
	"r_elbow": ["r_shoulder", Vector3(0, -0.3, 0), Vector3(0.08, 0.28, 0.08), "skin", Vector3(0, -0.14, 0)],
	"l_hip": ["pelvis", Vector3(-0.09, -0.06, 0), Vector3(0.13, 0.44, 0.14), "chiton", Vector3(0, -0.22, 0)],
	"l_knee": ["l_hip", Vector3(0, -0.44, 0), Vector3(0.1, 0.44, 0.1), "skin", Vector3(0, -0.22, 0)],
	"r_hip": ["pelvis", Vector3(0.09, -0.06, 0), Vector3(0.13, 0.44, 0.14), "chiton", Vector3(0, -0.22, 0)],
	"r_knee": ["r_hip", Vector3(0, -0.44, 0), Vector3(0.1, 0.44, 0.1), "skin", Vector3(0, -0.22, 0)],
}

## Pose angles in degrees, Vector3(x, y, z) per joint; missing joints stay 0.
const POSES := {
	"stand": {},
	# on a low stool, leaning over the wheel, hands forward on the clay
	"potter": {"pelvis": Vector3(0, 0, 0), "chest": Vector3(-22, 0, 0), "head": Vector3(-12, 0, 0),
		"l_shoulder": Vector3(55, 0, 8), "r_shoulder": Vector3(55, 0, -8), "l_elbow": Vector3(35, 0, 0), "r_elbow": Vector3(35, 0, 0),
		"l_hip": Vector3(90, 0, 4), "r_hip": Vector3(90, 0, -4), "l_knee": Vector3(-95, 0, 0), "r_knee": Vector3(-95, 0, 0)},
	# squatting by the wheel, one arm on its rim
	"turner": {"chest": Vector3(-30, 0, 0), "head": Vector3(15, 0, 0),
		"r_shoulder": Vector3(70, 0, -10), "r_elbow": Vector3(20, 0, 0), "l_shoulder": Vector3(25, 0, 10), "l_elbow": Vector3(60, 0, 0),
		"l_hip": Vector3(115, 0, 10), "r_hip": Vector3(115, 0, -10), "l_knee": Vector3(-140, 0, 0), "r_knee": Vector3(-140, 0, 0)},
	# on a stone, mending the net spread over his knees
	# lying on the back on a fleece, the body tipped over the pelvis, arms by the sides
	"sleep": {"pelvis": Vector3(90, 0, 0), "head": Vector3(-12, 0, 0), "l_shoulder": Vector3(0, 0, 6), "r_shoulder": Vector3(0, 0, -6),
		"l_knee": Vector3(-8, 0, 0), "r_knee": Vector3(-8, 0, 0)},
	# kneeling by the bread oven, leaning in, one hand at the oven's mouth
	"baker": {"chest": Vector3(-30, 0, 0), "head": Vector3(-18, 0, 0),
		"r_shoulder": Vector3(70, 0, -6), "r_elbow": Vector3(15, 0, 0), "l_shoulder": Vector3(40, 0, 10), "l_elbow": Vector3(55, 0, 0),
		"l_hip": Vector3(25, 0, 6), "r_hip": Vector3(25, 0, -6), "l_knee": Vector3(-115, 0, 0), "r_knee": Vector3(-115, 0, 0)},
	# hugging an amphora against the chest
	"carry": {"chest": Vector3(4, 0, 0), "l_shoulder": Vector3(50, 0, 14), "r_shoulder": Vector3(50, 0, -14),
		"l_elbow": Vector3(70, 0, 0), "r_elbow": Vector3(70, 0, 0)},
	# an actor declaiming: one arm thrown out to the seats, a mask in the other hand
	"declaim": {"head": Vector3(8, 0, 0), "r_shoulder": Vector3(115, 0, -25), "r_elbow": Vector3(10, 0, 0),
		"l_shoulder": Vector3(40, 0, 12), "l_elbow": Vector3(75, 0, 0), "r_hip": Vector3(-10, 0, 0), "l_hip": Vector3(12, 0, 0)},
	# at a well, leaning over the curb, both hands on the rope
	"draw": {"chest": Vector3(-18, 0, 0), "head": Vector3(-10, 0, 0),
		"l_shoulder": Vector3(75, 0, 10), "r_shoulder": Vector3(75, 0, -10), "l_elbow": Vector3(35, 0, 0), "r_elbow": Vector3(35, 0, 0)},
	"mender": {"chest": Vector3(-28, 0, 0), "head": Vector3(-22, 0, 0),
		"l_shoulder": Vector3(20, 0, 10), "r_shoulder": Vector3(20, 0, -10), "l_elbow": Vector3(45, 0, 0), "r_elbow": Vector3(45, 0, 0),
		"l_hip": Vector3(80, 0, 10), "r_hip": Vector3(80, 0, -10), "l_knee": Vector3(-60, 0, 0), "r_knee": Vector3(-60, 0, 0)},
	# walking upright: the stride itself comes from step_motion()
	"walk": {"chest": Vector3(-4, 0, 0), "head": Vector3(-8, 0, 0)},
	# stopped and thinking about the part: chin on the hand, eyes on the stones
	"think": {"chest": Vector3(-6, 0, 0), "head": Vector3(-14, 0, 0),
		"r_shoulder": Vector3(42, 0, -12), "r_elbow": Vector3(105, 0, 0), "l_shoulder": Vector3(8, 0, 6)},
}

## Pelvis height for a pose (seated figures sit on something low).
const SEAT := {"stand": 0.92, "potter": 0.46, "turner": 0.32, "mender": 0.4, "sleep": 0.12, "baker": 0.5, "carry": 0.92, "declaim": 0.92, "draw": 0.92,
	"walk": 0.92, "think": 0.92}


## Builds the joints under `root`; returns {joint name: Node3D}.
static func build(root: Node3D, body_mat: String = "chiton") -> Dictionary:
	var joints := {}
	for name: String in RIG:
		var spec: Array = RIG[name]
		var j := Node3D.new()
		j.name = name
		j.position = spec[1]
		var parent: Node3D = root if spec[0] == "" else joints[spec[0]]
		parent.add_child(j)
		joints[name] = j
		var mat: String = body_mat if spec[3] == "chiton" else spec[3]
		var kit := MeshKit.new()
		kit.box(mat, spec[4], spec[2], [])
		if name == "head":
			kit.box("hair", Vector3(0, 0.25, 0.02), Vector3(0.21, 0.07, 0.23), [])
			kit.box("hair", Vector3(0, 0.15, 0.1), Vector3(0.21, 0.16, 0.05), [])
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		j.add_child(mi)
	return joints


## The mysterious figure (the night street, the dream path): a standing body
## wrapped in a black robe to the ground, a mantle over the shoulders, wide
## sleeves over the hands and a deep hood. Under the hood there is no face,
## only black (`void`), the same from every angle and in any light. Both
## materials use psx_ghost, so an Apparition can dissolve it.
static func shrouded(root: Node3D) -> Dictionary:
	var joints := build(root, "robe")
	apply_pose(joints, "stand")
	var robe: Material = Mats.get_mat("robe")
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = robe  # skin and hair too: nothing of the body shows
	var pelvis := MeshKit.new()
	# flared to the ground, a little short of it so it never sinks into a slope
	pelvis.lathe("robe", PackedVector2Array([Vector2(0.36, -0.9), Vector2(0.27, -0.45), Vector2(0.2, 0.12)]), 7)
	_attach(joints["pelvis"], pelvis)
	var chest := MeshKit.new()
	chest.box("robe", Vector3(0, 0.26, 0), Vector3(0.42, 0.56, 0.27), [])
	chest.box("robe", Vector3(0, 0.45, 0.01), Vector3(0.58, 0.14, 0.33), [])  # mantle over the shoulders
	_attach(joints["chest"], chest)
	for side: String in ["l", "r"]:
		var upper := MeshKit.new()
		upper.box("robe", Vector3(0, -0.15, 0), Vector3(0.15, 0.32, 0.15), [])
		_attach(joints[side + "_shoulder"], upper)
		var sleeve := MeshKit.new()
		sleeve.box("robe", Vector3(0, -0.17, 0), Vector3(0.19, 0.36, 0.19), [])  # wide, swallowing the hand
		_attach(joints[side + "_elbow"], sleeve)
	var hood := MeshKit.new()
	hood.box("robe", Vector3(0, 0.34, -0.01), Vector3(0.31, 0.07, 0.36), [])  # crown, peaked forward
	for sx: float in [-1.0, 1.0]:
		hood.box("robe", Vector3(sx * 0.13, 0.13, -0.01), Vector3(0.05, 0.38, 0.36), [])
	hood.box("robe", Vector3(0, 0.13, 0.15), Vector3(0.31, 0.38, 0.06), [])  # back
	hood.box("robe", Vector3(0, -0.03, 0.12), Vector3(0.36, 0.14, 0.14), [])  # falling onto the mantle
	hood.box("void", Vector3(0, 0.13, -0.12), Vector3(0.21, 0.27, 0.02), [])  # where the face should be
	_attach(joints["head"], hood)
	return joints


static func _attach(joint: Node3D, kit: MeshKit) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Shroud"
	mi.mesh = kit.commit()
	joint.add_child(mi)


## A woman's figure: hair down the back under a kerchief, and a long chiton over
## the legs. The same recipe as Myrto at her oven, kept here so any NPC can wear it.
static func dress_woman(joints: Dictionary) -> void:
	var head: Node3D = joints.get("head")
	if head != null:
		var hk := MeshKit.new()
		hk.box("hair", Vector3(0, 0.02, 0.12), Vector3(0.18, 0.3, 0.06), [])  # down the back
		hk.box("cloth", Vector3(0, 0.25, 0.02), Vector3(0.23, 0.06, 0.25), [])  # kerchief
		hk.box("cloth", Vector3(0, 0.17, 0.11), Vector3(0.23, 0.14, 0.05), [])
		_attach(head, hk)
	var pelvis: Node3D = joints.get("pelvis")
	if pelvis != null:
		var sk := MeshKit.new()
		sk.box("chiton_dark", Vector3(0, -0.22, 0.05), Vector3(0.42, 0.42, 0.5), [])  # skirt
		_attach(pelvis, sk)

static func apply_pose(joints: Dictionary, pose: String, extra: Dictionary = {}) -> void:
	var p: Dictionary = POSES.get(pose, {})
	for name: String in joints:
		var deg: Vector3 = p.get(name, Vector3.ZERO) + extra.get(name, Vector3.ZERO)
		(joints[name] as Node3D).rotation_degrees = deg
	(joints["pelvis"] as Node3D).position.y = SEAT.get(pose, 0.92)


## Small working motions on top of a pose. Time is quantised to 15 fps:
## PS1-era animation stepped visibly.
static func motion(pose: String, t: float) -> Dictionary:
	var q := floorf(t * 15.0) / 15.0
	match pose:
		"potter":
			var s := sin(q * 2.4)
			return {"l_shoulder": Vector3(s * 7, 0, 0), "r_shoulder": Vector3(-s * 7, 0, 0),
				"l_elbow": Vector3(s * 10, 0, 0), "r_elbow": Vector3(-s * 10, 0, 0), "chest": Vector3(sin(q * 0.7) * 3, 0, 0)}
		"turner":
			return {"r_shoulder": Vector3(sin(q * 6.0) * 18, cos(q * 6.0) * 15, 0), "r_elbow": Vector3(cos(q * 6.0) * 12, 0, 0),
				"chest": Vector3(sin(q * 6.0) * 4, 0, 0)}
		"baker":
			# pat the dough flat between the hands, then reach in and slap it on the oven wall
			var k := fposmod(q * 0.35, 1.0)
			if k < 0.6:
				var pat := absf(sin(q * 9.0))
				return {"l_elbow": Vector3(pat * 18, 0, 0), "r_shoulder": Vector3(-25, 0, 10), "r_elbow": Vector3(50 - pat * 18, 0, 0)}
			var reach := sin((k - 0.6) / 0.4 * PI)
			return {"r_shoulder": Vector3(reach * 25, 0, 0), "r_elbow": Vector3(-reach * 15, 0, 0), "chest": Vector3(-reach * 10, 0, 0)}
		"draw":
			# hand over hand on the rope: one arm reaches up while the other pulls down
			var k := sin(q * 3.2)
			return {"l_shoulder": Vector3(k * 28, 0, 0), "r_shoulder": Vector3(-k * 28, 0, 0),
				"l_elbow": Vector3(-k * 20, 0, 0), "r_elbow": Vector3(k * 20, 0, 0), "chest": Vector3(absf(k) * 6, 0, 0)}
		"carry":
			# shifting the weight of the jar
			return {"chest": Vector3(sin(q * 1.6) * 3, sin(q * 0.8) * 4, 0)}
		"declaim":
			# the free arm sweeps across the seats, the head follows
			var sweep := sin(q * 0.9)
			return {"r_shoulder": Vector3(sweep * 12, sweep * 25, 0), "head": Vector3(0, sweep * 15, 0), "chest": Vector3(0, sweep * 6, 0)}
		"sleep":
			# slow breathing
			return {"chest": Vector3(sin(q * 1.4) * 2.0, 0, 0)}
		"mender":
			# the needle goes through, the arm pulls the twine out and up
			var k := fposmod(q * 0.8, 1.0)
			var pull := k * 4.0 if k < 0.25 else maxf(0.0, 1.0 - (k - 0.25) * 2.0)
			return {"r_shoulder": Vector3(-pull * 30, 0, -pull * 25), "r_elbow": Vector3(-pull * 35, 0, 0),
				"head": Vector3(0, pull * 8, 0)}
		_:
			return {"chest": Vector3(sin(q * 1.1) * 2, 0, 0)}


## One stride of a walking figure, driven by the distance covered (phase in
## cycles, 1.0 = both legs back where they started). Legs and arms swing in
## opposition and the knees only bend backwards, the way a knee does.
static func step_motion(phase: float) -> Dictionary:
	var s := sin(phase * TAU)
	var swing := s * 24.0
	return {
		"l_hip": Vector3(swing, 0, 0),
		"r_hip": Vector3(-swing, 0, 0),
		"l_knee": Vector3(-maxf(0.0, -s) * 26.0, 0, 0),
		"r_knee": Vector3(-maxf(0.0, s) * 26.0, 0, 0),
		"l_shoulder": Vector3(-swing * 0.55, 0, 0),
		"r_shoulder": Vector3(swing * 0.55, 0, 0),
	}
