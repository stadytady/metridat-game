class_name MeshKit
extends RefCounted
## Low-poly mesh builder. Collects flat-shaded triangles per material and
## commits them into one ArrayMesh (one surface per material), so a whole
## district is a handful of draw calls. Also collects box colliders.
##
## Convention: polygons are passed counter-clockwise as seen from the front
## (right-hand normal points outward). Godot's front faces are clockwise, so
## triangles are emitted reversed.

## Current transform applied to every added vertex.
var xform := Transform3D.IDENTITY
## Vertex color multiplied into albedo (cheap baked shading).
var color := Color.WHITE

var _tools := {}
var _colliders: Array = []


func _st(mat: String) -> SurfaceTool:
	var st: SurfaceTool = _tools.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return st


func is_empty() -> bool:
	return _tools.is_empty()


func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var pa := xform * a
	var pb := xform * b
	var pc := xform * c
	var n := (pb - pa).cross(pc - pa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var st := _st(mat)
	for v: Array in [[pa, ua], [pc, uc], [pb, ub]]:
		st.set_normal(n)
		st.set_color(color)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Quads longer than this get tessellated: affine texture mapping (PS1) warps
## badly across big polygons, so PS1 games subdivided large surfaces too.
var max_edge := 3.0


## Planar UVs from the quad's own edges: u along a->b, v along a->d, in meters
## of local space, so adjacent quads on one wall line up.
func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uvs: PackedVector2Array = PackedVector2Array()) -> void:
	if uvs.is_empty():
		var t := (b - a).normalized()
		var s := (d - a).normalized()
		uvs = PackedVector2Array([
			Vector2(a.dot(t), -a.dot(s)), Vector2(b.dot(t), -b.dot(s)),
			Vector2(c.dot(t), -c.dot(s)), Vector2(d.dot(t), -d.dot(s)),
		])
	var nu := maxi(1, ceili(maxf(a.distance_to(b), d.distance_to(c)) / max_edge))
	var nv := maxi(1, ceili(maxf(a.distance_to(d), b.distance_to(c)) / max_edge))
	if nu == 1 and nv == 1:
		tri(mat, a, b, c, uvs[0], uvs[1], uvs[2])
		tri(mat, a, c, d, uvs[0], uvs[2], uvs[3])
		return
	for j in nv:
		for i in nu:
			var u0 := float(i) / nu
			var u1 := float(i + 1) / nu
			var v0 := float(j) / nv
			var v1 := float(j + 1) / nv
			var pa := _bilerp(a, b, c, d, u0, v0)
			var pb := _bilerp(a, b, c, d, u1, v0)
			var pc := _bilerp(a, b, c, d, u1, v1)
			var pd := _bilerp(a, b, c, d, u0, v1)
			var ta := _bilerp2(uvs, u0, v0)
			var tb := _bilerp2(uvs, u1, v0)
			var tc := _bilerp2(uvs, u1, v1)
			var td := _bilerp2(uvs, u0, v1)
			tri(mat, pa, pb, pc, ta, tb, tc)
			tri(mat, pa, pc, pd, ta, tc, td)


static func _bilerp(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float, v: float) -> Vector3:
	return a.lerp(b, u).lerp(d.lerp(c, u), v)


static func _bilerp2(uv: PackedVector2Array, u: float, v: float) -> Vector2:
	return uv[0].lerp(uv[1], u).lerp(uv[3].lerp(uv[2], u), v)


## Axis-aligned box in local space. `skip` lists faces to omit: "top", "bottom", "px", "nx", "pz", "nz".
## `mats` may override the material per face.
func box(mat: String, center: Vector3, size: Vector3, skip: Array = ["bottom"], mats: Dictionary = {}) -> void:
	var h := size / 2.0
	var p := func(sx: float, sy: float, sz: float) -> Vector3:
		return center + Vector3(sx * h.x, sy * h.y, sz * h.z)
	var faces := {
		"top": [p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1)],
		"bottom": [p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1)],
		"px": [p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1)],
		"nx": [p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1)],
		"pz": [p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1)],
		"nz": [p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1)],
	}
	for f: String in faces:
		if f in skip:
			continue
		var q: Array = faces[f]
		quad(mats.get(f, mat), q[0], q[1], q[2], q[3])


## Box that also gets a collider.
func solid_box(mat: String, center: Vector3, size: Vector3, skip: Array = ["bottom"], mats: Dictionary = {}) -> void:
	box(mat, center, size, skip, mats)
	add_collider(center, size)


func add_collider(center: Vector3, size: Vector3) -> void:
	_colliders.append([xform * Transform3D(Basis.IDENTITY, center), size])


## Surface of revolution around local +Y. profile: Vector2(radius, y) bottom to top.
## v_fit: texture v spans the whole profile once (pots); otherwise v = -y in meters.
func lathe(mat: String, profile: PackedVector2Array, segments: int, center: Vector3 = Vector3.ZERO,
		u_repeat: float = 1.0, v_fit: bool = true, cap_mat: String = "", top_cap: bool = false) -> void:
	var y0 := profile[0].y
	var y1 := profile[profile.size() - 1].y
	var span := maxf(y1 - y0, 0.001)
	var ring := func(r: float, y: float, i: int) -> Vector3:
		var ang := TAU * float(i) / float(segments)
		return center + Vector3(cos(ang) * r, y, sin(ang) * r)
	for i in segments:
		var u0 := float(i) / segments * u_repeat
		var u1 := float(i + 1) / segments * u_repeat
		for j in profile.size() - 1:
			var lo := profile[j]
			var hi := profile[j + 1]
			var v_lo := (y1 - lo.y) / span if v_fit else -lo.y
			var v_hi := (y1 - hi.y) / span if v_fit else -hi.y
			var a: Vector3 = ring.call(lo.x, lo.y, i)
			var b: Vector3 = ring.call(lo.x, lo.y, i + 1)
			var c: Vector3 = ring.call(hi.x, hi.y, i + 1)
			var d: Vector3 = ring.call(hi.x, hi.y, i)
			# Angle grows towards +z from +x, so a,d,c,b is counter-clockwise from outside.
			var ua := Vector2(u0, v_lo)
			var ub := Vector2(u1, v_lo)
			var uc := Vector2(u1, v_hi)
			var ud := Vector2(u0, v_hi)
			if lo.x < 0.0001:
				tri(mat, a, d, c, ua, ud, uc)
			elif hi.x < 0.0001:
				tri(mat, a, d, b, ua, ud, ub)
			else:
				tri(mat, a, d, c, ua, ud, uc)
				tri(mat, a, c, b, ua, uc, ub)
	var cm := cap_mat if cap_mat != "" else mat
	if profile[0].x > 0.0001:
		_cap(cm, profile[0], segments, center, ring, false)
	if top_cap and profile[profile.size() - 1].x > 0.0001:
		_cap(cm, profile[profile.size() - 1], segments, center, ring, true)


func _cap(mat: String, pr: Vector2, segments: int, center: Vector3, ring: Callable, up: bool) -> void:
	var mid := center + Vector3(0, pr.y, 0)
	for i in segments:
		var a: Vector3 = ring.call(pr.x, pr.y, i)
		var b: Vector3 = ring.call(pr.x, pr.y, i + 1)
		var ua := Vector2(a.x - center.x, a.z - center.z)
		var ub := Vector2(b.x - center.x, b.z - center.z)
		if up:
			tri(mat, mid, b, a, Vector2.ZERO, ub, ua)
		else:
			tri(mat, mid, a, b, Vector2.ZERO, ua, ub)


## Gable roof whose eaves line sits on the wall tops (local y = 0), ridge along x.
## Slopes continue past the walls by `overhang` and get an underside.
func gable_roof(roof_mat: String, gable_mat: String, w: float, d: float, h: float, overhang: float,
		under_mat: String = "wood", gable_inside: bool = false) -> void:
	var hw := w / 2.0 + overhang
	var hd := d / 2.0
	var od := hd + overhang
	var drop := -h * overhang / hd
	# south (+z) and north (-z) slopes
	var s := [Vector3(-hw, drop, od), Vector3(hw, drop, od), Vector3(hw, h, 0), Vector3(-hw, h, 0)]
	var n := [Vector3(hw, drop, -od), Vector3(-hw, drop, -od), Vector3(-hw, h, 0), Vector3(hw, h, 0)]
	for q: Array in [s, n]:
		quad(roof_mat, q[0], q[1], q[2], q[3])
		quad(under_mat, q[1], q[0], q[3], q[2])
	var gx := w / 2.0
	for sx: float in [1.0, -1.0]:
		var a := Vector3(gx * sx, 0, hd * sx)
		var b := Vector3(gx * sx, 0, -hd * sx)
		var c := Vector3(gx * sx, h, 0)
		tri(gable_mat, a, b, c, Vector2(a.z, 0), Vector2(b.z, 0), Vector2(0, -h))
		if gable_inside:  # seen from inside (an open temple): the sky must not show through
			tri(gable_mat, b, a, c, Vector2(b.z, 0), Vector2(a.z, 0), Vector2(0, -h))


## Jittered icosahedron: the basic PS1 rock / canopy blob.
func blob(mat: String, center: Vector3, radius: Vector3, jitter: float, rng: RandomNumberGenerator) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var f := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var pts: Array[Vector3] = []
	for p: Vector3 in v:
		var k := 1.0 + rng.randf_range(-jitter, jitter)
		pts.append(center + p.normalized() * radius * k)
	for face: Array in f:
		# Icosahedron table is counter-clockwise from outside, as tri() expects.
		var a: Vector3 = pts[face[0]]
		var b: Vector3 = pts[face[1]]
		var c: Vector3 = pts[face[2]]
		tri(mat, a, b, c, Vector2(a.x + a.z, -a.y), Vector2(b.x + b.z, -b.y), Vector2(c.x + c.z, -c.y))


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat: String in _tools:
		var st: SurfaceTool = _tools[mat]
		st.set_material(Mats.get_mat(mat))
		st.commit(mesh)
	return mesh


## MeshInstance3D + StaticBody3D with the collected box colliders.
func build(name: String, surface: StringName = &"stone") -> Node3D:
	var root := Node3D.new()
	root.name = name
	if not is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = commit()
		root.add_child(mi)
	if not _colliders.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.set_meta(&"surface", surface)
		for c: Array in _colliders:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = c[1]
			cs.shape = shape
			cs.transform = c[0]
			body.add_child(cs)
		root.add_child(body)
	return root
