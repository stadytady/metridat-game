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


func test_walk_stride_is_symmetric_and_loops() -> void:
	var start := Figure.step_motion(0.0)
	var back := Figure.step_motion(1.0)
	for joint: String in start:
		check(is_equal_approx(start[joint].x, back[joint].x), "%s does not come back after one stride" % joint)
	var mid := Figure.step_motion(0.25)
	check(absf(mid["l_hip"].x) > 10.0, "no stride at a quarter of the cycle")
	check(is_equal_approx(mid["l_hip"].x, -mid["r_hip"].x), "both legs swing the same way")
	check(is_equal_approx(mid["l_shoulder"].x, -mid["r_shoulder"].x), "both arms swing the same way")
	check(absf(mid["l_hip"].x) < 45.0, "stride of %.0f deg is a split" % absf(mid["l_hip"].x))
	var both_bent := 0
	for i in 20:
		var m := Figure.step_motion(i / 20.0)
		if m["l_knee"].x < -0.5 and m["r_knee"].x < -0.5:
			both_bent += 1
	check(both_bent == 0, "%d frames with both knees bent" % both_bent)


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


func test_named_people_look_different() -> void:
	var seen := {}
	for id: String in Figure.LOOKS:
		var l: Dictionary = Figure.look_for(id)
		seen["%s|%s|%s|%s" % [Figure.face_of(l), l.get("hair", 0), l.get("cloth", ""), l.get("woman", false)]] = true
	check(seen.size() == Figure.LOOKS.size(), "two named people look alike: %d looks for %d people" % [seen.size(), Figure.LOOKS.size()])
	check(Figure.face_of(Figure.look_for("baker")) == "face_woman", "Myrto has a man's face")
	check(Figure.face_of(Figure.look_for("potter")) == "face_beard", "the potter lost his beard")


func test_passers_by_vary_and_keep_their_look() -> void:
	var faces := {}
	var dyes := {}
	for i in 40:
		var key := "%d,%d" % [i * 37, -i * 11]
		var l := Figure.look_for(key)
		check(l == Figure.look_for(key), "a passer-by changes look: %s" % key)
		faces[Figure.face_of(l)] = true
		dyes[l.get("cloth", "")] = true
	check(faces.size() >= 3, "passers-by have %d faces" % faces.size())
	check(dyes.size() >= 3, "passers-by wear %d colours" % dyes.size())


func test_the_face_is_painted_on_the_front() -> void:
	for look: Dictionary in [Figure.look_for("potter"), Figure.look_for("baker"), Figure.look_for("turner")]:
		var root := Node3D.new()
		var joints := Figure.build(root, "chiton", look)
		var want := Figure.face_of(look)
		var found := false
		for mi: MeshInstance3D in (joints["head"] as Node3D).find_children("*", "MeshInstance3D", false, false):
			for s in mi.mesh.get_surface_count():
				if mi.mesh.surface_get_material(s).resource_name != want:
					continue
				found = true
				var v: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for i in range(0, v.size(), 3):
					var n := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])
					check(n.z < 0.0, "%s faces into the head" % want)
					check(v[i].z < -0.105, "%s sits inside the head at z %.3f" % [want, v[i].z])
		check(found, "no %s on the head" % want)
		# every part hangs something off its joint
		for name: String in Figure.RIG:
			check((joints[name] as Node3D).get_child_count() > 0, "%s has no mesh" % name)
		root.free()
