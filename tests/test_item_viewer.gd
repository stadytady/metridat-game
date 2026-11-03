extends "res://tests/test_case.gd"
## The viewer frames any find: the camera distance fits the bounding sphere,
## and every find has a model with real geometry.


func test_fit_distance_frames_the_sphere() -> void:
	for size: Vector3 in [Vector3(0.02, 0.01, 0.02), Vector3(0.4, 0.1, 0.3), Vector3(1.7, 1.5, 1.5), Vector3(1, 2.2, 0.7)]:
		var box := AABB(-size / 2.0, size)
		var r := size.length() / 2.0
		var d := ItemViewer.fit_distance(box, 32.0, 0.92)
		var half := asin(r / d)  # angular radius of the sphere at that distance
		check(half <= deg_to_rad(16.0) + 1e-5, "%s overflows the view" % size)
		check(half >= deg_to_rad(16.0) * 0.8, "%s too small in the view" % size)
	var a := ItemViewer.fit_distance(AABB(Vector3.ZERO, Vector3.ONE), 32.0, 0.8)
	var b := ItemViewer.fit_distance(AABB(Vector3.ZERO, Vector3.ONE * 3.0), 32.0, 0.8)
	check(is_equal_approx(b, a * 3.0), "distance scales with size")


func test_model_aabb_sees_offset_children() -> void:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 2, 1)
	mi.mesh = bm
	mi.position = Vector3(3, 0, 0)
	root.add_child(mi)
	tree.root.add_child(root)
	var box := ItemViewer.model_aabb(root)
	check(box.get_center().is_equal_approx(Vector3(3, 0, 0)), "centre follows the child: %s" % box.get_center())
	check(box.size.is_equal_approx(Vector3(1, 2, 1)), "size: %s" % box.size)
	root.free()


func test_every_find_has_a_model_with_geometry() -> void:
	for f in DirAccess.get_files_at("res://data/discoveries"):
		if not f.ends_with(".tres"):
			continue
		var d: Discovery = load("res://data/discoveries/" + f)
		check(d.model != null, "%s has no model" % d.id)
		if d.model == null:
			continue
		var n := d.model.instantiate() as Node3D
		tree.root.add_child(n)
		await tree.process_frame
		var box := ItemViewer.model_aabb(n)
		check(box.size.length() > 0.02, "%s model is empty: %s" % [d.id, box])
		n.free()


## Positive pitch tips the top of the find towards the camera: flat finds
## must show their face, not their edge or underside.
func test_flat_finds_are_seen_from_above() -> void:
	var coin := AABB(Vector3.ZERO, Vector3(0.32, 0.066, 0.32))
	var jar := AABB(Vector3.ZERO, Vector3(0.34, 0.78, 0.34))
	check(ItemViewer.rest_pitch(coin) > ItemViewer.rest_pitch(jar), "flat finds tilt more")
	for box: AABB in [coin, jar]:
		var up := Basis(Vector3.RIGHT, ItemViewer.rest_pitch(box)) * Vector3.UP
		check(up.z > 0.3, "top must face the camera (+z): %s" % up)
