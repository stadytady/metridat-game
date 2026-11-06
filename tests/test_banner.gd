extends "res://tests/test_case.gd"
## The red cloth between the stoa's columns: tied along its top, free below,
## the hem only ever blowing out onto the square, never back into the columns,
## and both faces moving as one.

const AGORA := preload("res://scripts/world/agora.gd")


func test_the_top_edge_stays_tied_and_the_hem_moves() -> void:
	var t := 0.0
	var hem_moved := false
	while t < 20.0:
		for i in 11:
			var u := i / 10.0
			check(is_zero_approx(AGORA.banner_offset(Vector2(u, 0.0), t)), "the tied edge comes loose at u %.1f" % u)
			var hem := AGORA.banner_offset(Vector2(u, 1.0), t)
			check(hem >= 0.0, "the hem swings back into the columns: %.3f at u %.1f, t %.1f" % [hem, u, t])
			check(hem < 0.5, "the hem flies %.2f m out" % hem)
			if hem > 0.15:
				hem_moved = true
		t += 0.25
	check(hem_moved, "the hem never blows out")
	# it moves: not the same at two moments
	check(absf(AGORA.banner_offset(Vector2(0.5, 1.0), 0.0) - AGORA.banner_offset(Vector2(0.5, 1.0), 1.7)) > 0.02, "the cloth hangs dead still")


## Cut fine enough to bend, its UVs running 0..1 with the tied edge at v = 0
## on both faces, and clear of the shafts at either end.
func test_the_cloth_is_cut_to_bend() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(4, 0, 0)
	var mi := AGORA.banner(a, b)
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	check(verts.size() >= 2 * 6 * 30, "the cloth has only %d vertices: too coarse to bend" % verts.size())
	check(mi.mesh.surface_get_material(0).resource_name == "banner_red", "the cloth is not on the banner material")
	for i in verts.size():
		var v := verts[i]
		var uv := uvs[i]
		# v = 0 exactly on the top edge (y = 0), 1 on the hem
		check(absf(uv.y - (-v.y / AGORA.BANNER_DROP)) < 0.01, "uv %.2f does not follow the drop at y %.2f" % [uv.y, v.y])
		check(absf(v.x) <= b.x / 2.0 - AGORA.BANNER_INSET + 0.001, "the cloth runs into a column at x %.2f" % v.x)
	mi.free()


## The shader moves the cloth along its local z, not its normal: the two faces
## stay together.
func test_the_shader_moves_both_faces_together() -> void:
	var src := FileAccess.get_file_as_string("res://assets/shaders/psx_banner.gdshader")
	check(src.contains("vec3(0.0, 0.0, offset("), "the banner shader does not move the cloth along its own z")
	check(not src.contains("NORMAL *"), "the banner shader pushes along the normal: the faces would part")
