extends "res://tests/test_case.gd"
## Rigid-segment NPC rig: every joint is built, poses seat the body, motion steps at 15 fps.


func test_build_creates_all_joints() -> void:
	var root := Node3D.new()
	var joints := Figure.build(root)
	check(joints.size() == Figure.RIG.size(), "one joint per RIG entry")
	for name: String in Figure.RIG:
		var parent_name: String = Figure.RIG[name][0]
		var expected: Node = root if parent_name == "" else joints[parent_name]
		check((joints[name] as Node).get_parent() == expected, "%s hangs off %s" % [name, parent_name])
	root.free()


func test_poses_name_known_joints() -> void:
	for pose: String in Figure.POSES:
		check(Figure.SEAT.has(pose), "pose %s has a seat height" % pose)
		for j: String in Figure.POSES[pose]:
			check(Figure.RIG.has(j), "pose %s names unknown joint %s" % [pose, j])
	var root := Node3D.new()
	var joints := Figure.build(root)
	Figure.apply_pose(joints, "potter")
	check(is_equal_approx((joints["pelvis"] as Node3D).position.y, Figure.SEAT["potter"]), "potter sits")
	check((joints["l_hip"] as Node3D).rotation_degrees.x > 45.0, "seated thighs swing forward")
	root.free()


func test_motion_is_stepped() -> void:
	for pose: String in ["potter", "turner", "mender", "stand"]:
		var moved := false
		for i in 45:
			var t := 1.0 + (i + 0.25) / 15.0  # mid-step: no float edge at the step boundary
			var a := Figure.motion(pose, t)
			check(a == Figure.motion(pose, t + 0.5 / 15.0), "%s: changes within one 15 fps step at %.2f" % [pose, t])
			moved = moved or a != Figure.motion(pose, t + 1.0 / 15.0)
		check(moved, "%s: never moves in 3 s" % pose)
