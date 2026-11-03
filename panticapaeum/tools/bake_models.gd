extends SceneTree
## Bakes Props geometry into assets/models/*.glb.
##   godot --headless --path . -s res://tools/bake_models.gd
## Materials are exported as untextured StandardMaterial3D named after the project
## material ("clay", "bark", ...); Mats.apply_to() swaps in the PSX shaders on load.


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models"))
	var failed := 0
	for name: String in Props.MODELS:
		var kit := Props.build(name)
		var mesh := kit.commit()
		for i in mesh.get_surface_count():
			var src: ShaderMaterial = mesh.surface_get_material(i)
			var std := StandardMaterial3D.new()
			std.resource_name = src.resource_name
			# No texture: embedded images would be extracted next to the GLB on import.
			std.albedo_color = src.get_shader_parameter(&"tint")
			std.roughness = 1.0
			mesh.surface_set_material(i, std)
		var root := Node3D.new()
		root.name = name
		var mi := MeshInstance3D.new()
		mi.name = name + "_mesh"
		mi.mesh = mesh
		root.add_child(mi)
		mi.owner = root
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var path := "res://assets/models/%s.glb" % name
		var err := doc.append_from_scene(root, state)
		if err == OK:
			err = doc.write_to_filesystem(state, path)
		root.free()
		if err != OK:
			failed += 1
			push_error("bake %s: %s" % [name, error_string(err)])
			continue
		_write_import(name)
		print("baked ", path)
	quit(1 if failed else 0)


## Low-poly models must not get auto-LODs (they would collapse) or shadow meshes.
func _write_import(name: String) -> void:
	var p := ProjectSettings.globalize_path("res://assets/models/%s.glb.import" % name)
	if FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"scene\"\nimporter_version=1\ntype=\"PackedScene\"\n\n"
		+ "[deps]\n\nsource_file=\"res://assets/models/%s.glb\"\n\n" % name
		+ "[params]\n\nmeshes/generate_lods=false\nmeshes/create_shadow_meshes=false\n"
		+ "meshes/light_baking=0\nanimation/import=false\n")
