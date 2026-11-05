class_name Figure
extends RefCounted
## Rigid-segment low-poly person, the way PS1 games built characters: one mesh
## per body part hanging off a joint (Node3D), animated by rotating the joints.
## The parts are tapered (six-sided limbs, a torso wider at the shoulders),
## with hands, sandalled feet, a painted face and a look (LOOKS) of its own. Faces -Z. A positive X rotation swings a hanging limb forward, but
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


## How a person looks: "woman", "beard" (0 none, 1 short, 2 full), "hair"
## (0 cropped, 1 curly, 2 thinning), "cloth" (dyed tunic, only where the caller
## left the plain "chiton"), "kerchief" (its cloth), "skirt" ("short" tunic, "long" to the
## ankles, "none" when the caller dresses the legs itself), "shroud" (no face
## parts: a hood goes over the head).
const LOOKS := {
	"potter": {"beard": 2, "hair": 1, "cloth": "chiton_ochre"},
	"turner": {"beard": 0, "hair": 0},
	"fisher": {"beard": 1, "hair": 2},
	"sailor": {"beard": 2, "hair": 0},
	"carrier": {"beard": 1, "hair": 1},
	"splicer": {"beard": 0, "hair": 1},
	"actor": {"beard": 0, "hair": 1, "cloth": "chiton_red"},
	"baker": {"woman": true, "kerchief": "cloth", "skirt": "none"},
	"water_carrier": {"woman": true, "kerchief": "chiton_dark", "skirt": "long", "cloth": "chiton_blue"},
}
const DYES := ["chiton", "chiton_red", "chiton_blue", "chiton_ochre"]
const FACES := ["face_bare", "face_short", "face_beard", "face_woman"]


## A look for anyone: the named ones from LOOKS, the rest picked by a hash of
## their key, so the same person looks the same every time and two passers-by
## are not twins.
static func look_for(key: String) -> Dictionary:
	if LOOKS.has(key):
		return LOOKS[key]
	var h := hash(key)
	return {"beard": posmod(h, 3), "hair": posmod(h >> 3, 3), "cloth": DYES[posmod(h >> 6, DYES.size())]}


static func face_of(look: Dictionary) -> String:
	return FACES[3] if look.get("woman", false) else FACES[clampi(int(look.get("beard", 0)), 0, 2)]


## Builds the joints under `root`; returns {joint name: Node3D}.
static func build(root: Node3D, body_mat: String = "chiton", look: Dictionary = {}) -> Dictionary:
	var cloth: String = look.get("cloth", body_mat) if body_mat == "chiton" else body_mat
	var joints := {}
	for name: String in RIG:
		var spec: Array = RIG[name]
		var j := Node3D.new()
		j.name = name
		j.position = spec[1]
		var parent: Node3D = root if spec[0] == "" else joints[spec[0]]
		parent.add_child(j)
		joints[name] = j
		var kit := MeshKit.new()
		_segment(kit, name, cloth, look)
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		j.add_child(mi)
	return joints


## One body part, in its joint's frame (limbs hang down -y, the face looks -z).
static func _segment(kit: MeshKit, name: String, cloth: String, look: Dictionary) -> void:
	var woman: bool = look.get("woman", false)
	match name:
		"pelvis":
			kit.frustum(cloth, Vector3(0, -0.08, 0), Vector2(0.36 if woman else 0.31, 0.21), Vector2(0.32, 0.2), 0.16)
			kit.box("belt", Vector3(0, 0.07, 0), Vector3(0.33, 0.04, 0.215), [])
			var skirt: String = look.get("skirt", "long" if woman else "short")
			if skirt == "short":
				# the tunic's hem flares over the thighs, a madder border at its edge
				kit.frustum(cloth, Vector3(0, -0.32, 0), Vector2(0.42, 0.3), Vector2(0.32, 0.21), 0.26, ["top", "bottom"], 4)
				kit.frustum("hem", Vector3(0, -0.34, 0), Vector2(0.425, 0.305), Vector2(0.42, 0.3), 0.03, ["top", "bottom"])
			elif skirt == "long":
				kit.frustum(cloth, Vector3(0, -0.84, 0), Vector2(0.46, 0.36), Vector2(0.34, 0.22), 0.8, ["top", "bottom"], 5)
				kit.frustum("hem", Vector3(0, -0.86, 0), Vector2(0.465, 0.365), Vector2(0.46, 0.36), 0.03, ["top", "bottom"])
		"chest":
			var waist := Vector2(0.29 if woman else 0.31, 0.2)
			var shoulders := Vector2(0.36 if woman else 0.4, 0.22)
			kit.frustum(cloth, Vector3.ZERO, waist, shoulders, 0.44, ["bottom"], 3)
			# shoulders sloping to the neck, then the neck itself
			kit.frustum(cloth, Vector3(0, 0.44, 0), shoulders, Vector2(0.24, 0.17), 0.08, ["bottom"])
			kit.lathe("skin", PackedVector2Array([Vector2(0.045, 0.5), Vector2(0.045, 0.57)]), 6, Vector3.ZERO, 1.0, true, "", true)
		"head":
			kit.box("skin", Vector3(0, 0.13, 0), Vector3(0.19, 0.23, 0.21), [])
			if look.get("shroud", false):
				return
			# the face: a painted quad just proud of the front, uv 0..1 so the
			# whole 32 px face lands on it, mirrored as seen from the front
			var z := -0.1065
			var x := 0.095
			kit.quad(face_of(look), Vector3(x, 0.015, z), Vector3(-x, 0.015, z), Vector3(-x, 0.245, z), Vector3(x, 0.245, z),
					PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
			kit.box("skin", Vector3(0, 0.12, -0.118), Vector3(0.035, 0.05, 0.025), [])  # nose
			_hair(kit, look)
		"l_shoulder", "r_shoulder":
			kit.lathe("skin", PackedVector2Array([Vector2(0.038, -0.3), Vector2(0.046, 0.0)]), 6, Vector3.ZERO, 1.0, true, "", true)
			# a short sleeve of the tunic over the top of the arm
			kit.lathe(cloth, PackedVector2Array([Vector2(0.058, -0.13), Vector2(0.06, 0.03)]), 6, Vector3.ZERO, 1.0, true, "", true)
		"l_elbow", "r_elbow":
			kit.lathe("skin", PackedVector2Array([Vector2(0.03, -0.24), Vector2(0.038, 0.0)]), 6, Vector3.ZERO, 1.0, true, "", true)
			kit.box("skin", Vector3(0, -0.285, -0.005), Vector3(0.05, 0.085, 0.03), [])  # hand
		"l_hip", "r_hip":
			kit.lathe("skin", PackedVector2Array([Vector2(0.052, -0.44), Vector2(0.068, 0.0)]), 6, Vector3.ZERO, 1.0, true, "", true)
		"l_knee", "r_knee":
			kit.lathe("skin", PackedVector2Array([Vector2(0.036, -0.4), Vector2(0.05, 0.0)]), 6, Vector3.ZERO, 1.0, true, "", true)
			kit.box("belt", Vector3(0, -0.415, -0.045), Vector3(0.075, 0.05, 0.2), [])  # a sandalled foot


static func _hair(kit: MeshKit, look: Dictionary) -> void:
	if look.get("woman", false):
		kit.box("hair", Vector3(0, 0.25, 0.02), Vector3(0.21, 0.07, 0.23), [])
		kit.box("hair", Vector3(0, 0.02, 0.12), Vector3(0.18, 0.3, 0.06), [])  # down the back
		var kerchief: String = look.get("kerchief", "")
		if not kerchief.is_empty():
			kit.box(kerchief, Vector3(0, 0.26, 0.02), Vector3(0.23, 0.06, 0.25), [])
			kit.box(kerchief, Vector3(0, 0.18, 0.11), Vector3(0.23, 0.14, 0.05), [])
		return
	match int(look.get("hair", 0)):
		1:  # curly: fuller on top and over the ears
			kit.box("hair", Vector3(0, 0.26, 0.02), Vector3(0.23, 0.09, 0.25), [])
			kit.box("hair", Vector3(0, 0.15, 0.1), Vector3(0.23, 0.18, 0.07), [])
		2:  # thinning: a fringe of grey-dark at the back and sides
			kit.box("hair", Vector3(0, 0.255, 0.05), Vector3(0.2, 0.035, 0.15), [])
			kit.box("hair", Vector3(0, 0.15, 0.1), Vector3(0.21, 0.14, 0.05), [])
		_:  # cropped
			kit.box("hair", Vector3(0, 0.25, 0.02), Vector3(0.21, 0.07, 0.23), [])
			kit.box("hair", Vector3(0, 0.15, 0.1), Vector3(0.21, 0.16, 0.05), [])
	match int(look.get("beard", 0)):
		1:
			kit.box("hair", Vector3(0, 0.02, -0.085), Vector3(0.16, 0.06, 0.05), [])
		2:
			kit.box("hair", Vector3(0, 0.0, -0.08), Vector3(0.19, 0.11, 0.07), [])


## The mysterious figure (the night street, the dream path): a standing body
## wrapped in a black robe to the ground, a mantle over the shoulders, wide
## sleeves over the hands and a deep hood. Under the hood there is no face,
## only black (`void`), the same from every angle and in any light. Both
## materials use psx_ghost, so an Apparition can dissolve it.
static func shrouded(root: Node3D) -> Dictionary:
	var joints := build(root, "robe", {"shroud": true, "skirt": "none"})
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
