extends "res://tests/test_case.gd"
## Winding: with cull_back, an inward-facing triangle is an invisible hole.


func _faces_outward(mesh: ArrayMesh, center: Vector3, label: String) -> void:
	var bad := 0
	var count := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size(), 3):
			# Godot front faces are clockwise: normal = (c - a) x (b - a)
			var n := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])
			var mid := (v[i] + v[i + 1] + v[i + 2]) / 3.0
			count += 1
			if n.dot(mid - center) <= 0.0:
				bad += 1
	check(count > 0, label + ": no triangles")
	check(bad == 0, "%s: %d of %d triangles face inward" % [label, bad, count])


func test_box_faces_outward() -> void:
	var kit := MeshKit.new()
	kit.box("limestone", Vector3(1, 2, 3), Vector3(2, 4, 6), [])
	_faces_outward(kit.commit(), Vector3(1, 2, 3), "box")


func test_tessellated_box_faces_outward() -> void:
	var kit := MeshKit.new()
	kit.box("limestone", Vector3.ZERO, Vector3(20, 9, 13), [])
	var mesh := kit.commit()
	_faces_outward(mesh, Vector3.ZERO, "big box")
	check(mesh.surface_get_array_len(0) > 36, "big box was not tessellated")


func test_lathe_faces_outward() -> void:
	var kit := MeshKit.new()
	kit.lathe("clay", PackedVector2Array([Vector2(0.2, 0), Vector2(0.5, 0.5), Vector2(0.3, 1.0)]), 8,
			Vector3.ZERO, 1.0, true, "", true)
	_faces_outward(kit.commit(), Vector3(0, 0.5, 0), "lathe")


func test_blob_faces_outward() -> void:
	var kit := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	kit.blob("rock", Vector3(3, 1, 2), Vector3.ONE, 0.2, rng)
	_faces_outward(kit.commit(), Vector3(3, 1, 2), "blob")


func test_all_props_build() -> void:
	for name: String in Props.MODELS + Props.EXTRA:
		var kit := Props.build(name)
		check(not kit.is_empty(), "prop %s is empty" % name)


## The plank hull must be closed: every edge is shared by two triangles,
## except along the open top (the sheer). Open ends showed as a slit.
func test_hull_is_closed_below_the_sheer() -> void:
	var kit := MeshKit.new()
	var sec := Props.hull(kit, 16.0, 2.4, 1.3, 0.9, 1.3, 13, "dark", "hull")
	check(is_zero_approx(sec[0][1]) and is_zero_approx(sec[-1][1]), "hull ends must close to zero beam")
	var key := func(v: Vector3) -> String:
		var u := v + Vector3.ZERO  # -0.0 -> 0.0
		return "%.4f,%.4f,%.4f" % [u.x, u.y, u.z]
	var sheer := {}
	for a: Array in sec:
		for s: float in [1.0, -1.0]:
			sheer[key.call(Vector3(a[0], a[3], a[1] * s))] = true
	var edges := {}
	var mesh := kit.commit()
	var outward := 0
	var total := 0
	for si in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size(), 3):
			var n := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])
			var mid := (v[i] + v[i + 1] + v[i + 2]) / 3.0
			total += 1
			outward += int(n.dot(mid - Vector3(mid.x, 6.0, 0.0)) > 0.0)
			for e in [[v[i], v[i + 1]], [v[i + 1], v[i + 2]], [v[i + 2], v[i]]]:
				var ka: String = key.call(e[0])
				var kb: String = key.call(e[1])
				var k := ka + "|" + kb if ka < kb else kb + "|" + ka
				edges[k] = edges.get(k, 0) + 1
	check(outward == total, "hull: %d of %d triangles face inward" % [total - outward, total])
	var open := 0
	for k: String in edges:
		if edges[k] == 1:
			var ends := k.split("|")
			if not (sheer.has(ends[0]) and sheer.has(ends[1])):
				open += 1
	check(open == 0, "hull has %d open edges below the sheer" % open)
