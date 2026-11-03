class_name Figure
extends RefCounted
## Rigid-segment low-poly person, the way PS1 games built characters: one box
## mesh per body part hanging off a joint (Node3D), animated by rotating the
## joints. Faces -Z. A positive X rotation swings a limb forward.

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
	"potter": {"pelvis": Vector3(0, 0, 0), "chest": Vector3(22, 0, 0), "head": Vector3(15, 0, 0),
		"l_shoulder": Vector3(55, 0, 8), "r_shoulder": Vector3(55, 0, -8), "l_elbow": Vector3(35, 0, 0), "r_elbow": Vector3(35, 0, 0),
		"l_hip": Vector3(90, 0, 4), "r_hip": Vector3(90, 0, -4), "l_knee": Vector3(-95, 0, 0), "r_knee": Vector3(-95, 0, 0)},
	# squatting by the wheel, one arm on its rim
	"turner": {"chest": Vector3(30, 0, 0), "head": Vector3(-10, 0, 0),
		"r_shoulder": Vector3(70, 0, -10), "r_elbow": Vector3(20, 0, 0), "l_shoulder": Vector3(25, 0, 10), "l_elbow": Vector3(60, 0, 0),
		"l_hip": Vector3(115, 0, 10), "r_hip": Vector3(115, 0, -10), "l_knee": Vector3(-140, 0, 0), "r_knee": Vector3(-140, 0, 0)},
}

## Pelvis height for a pose (seated figures sit on something low).
const SEAT := {"stand": 0.92, "potter": 0.46, "turner": 0.32}


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
		_:
			return {"chest": Vector3(sin(q * 1.1) * 2, 0, 0)}
