extends "res://tests/test_case.gd"
## Every surface of every baked model finds one of our materials: the importer's
## own is plain white, and that is how the slope's cypresses and the sanctuary's
## figurine went chalk-coloured (glTF had renamed "cypress" to "cypress2").


func test_every_model_surface_has_our_material() -> void:
	for m: String in Props.MODELS:
		var n: Node = (load("res://assets/models/%s.glb" % m) as PackedScene).instantiate()
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(i)
				var name: String = src.resource_name if src != null else ""
				check(Mats.material_key(name) != "", "%s surface %d (%s) has none of our materials" % [m, i, name])
		n.free()
	check(Mats.material_key("cypress2") == "cypress", "a renamed material is not found")
	check(Mats.material_key("nothing_like_it") == "", "a stranger's material is taken for ours")
