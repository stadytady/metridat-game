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


func test_shrouded_figure_hides_the_body() -> void:
	var root := Node3D.new()
	var joints := Figure.shrouded(root)
	var void_z := INF  # front-most z of the void, in the head's frame (the face looks to -z)
	var hem := INF  # lowest point of the robe, in the root's frame
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var joint := mi.get_parent() as Node3D
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(s)
			check(mat.resource_name in ["robe", "void"], "%s shows %s" % [joint.name, mat.resource_name])
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				if mat.resource_name == "void" and joint == joints["head"]:
					void_z = minf(void_z, v.z)
				if joint == joints["pelvis"]:
					hem = minf(hem, joint.position.y + v.y)
	check(void_z < INF, "no void under the hood")
	# the head's face is at z = -0.105: the void covers it, inside the hood's -0.19 rim
	check(void_z < -0.105 and void_z > -0.19, "the void is not under the hood: z %.3f" % void_z)
	check(hem < 0.1, "the robe stops %.2f m above the ground" % hem)
	root.free()


func test_apparition_crumbles_away() -> void:
	check(is_equal_approx(Apparition.fade_at(0.0), 1.0) and is_equal_approx(Apparition.fade_at(0.05), 1.0), "fades before its first 15 fps step")
	check(Apparition.fade_at(Apparition.DISSOLVE) == 0.0, "still there after %.1f s" % Apparition.DISSOLVE)
	var last := 1.0
	for i in 40:
		var f := Apparition.fade_at(i * 0.05)
		check(f <= last, "comes back at %.2f s" % (i * 0.05))
		last = f
	var a := Apparition.new()
	Figure.shrouded(a)
	for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := (mi.material_override if mi.material_override else mi.mesh.surface_get_material(s)) as ShaderMaterial
			check(mat.shader.resource_path.ends_with("psx_ghost.gdshader"), "%s can not dissolve" % mi.get_parent().name)
	var head: GeometryInstance3D = a.find_children("Shroud", "MeshInstance3D", true, false)[0]
	a.vanish()
	a._process(Apparition.DISSOLVE / 2.0)
	var half: Variant = head.get_instance_shader_parameter(&"fade")
	check(a.visible and half is float and half > 0.3 and half < 0.7, "half way: visible %s, fade %s" % [a.visible, half])
	a._process(Apparition.DISSOLVE)
	check(not a.visible, "still there after the dissolve")
	a.reset()
	var whole: Variant = head.get_instance_shader_parameter(&"fade")
	check(a.visible and not a.gone and whole is float and whole == 1.0, "not whole again after reset")
	a.free()
