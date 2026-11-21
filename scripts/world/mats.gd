class_name Mats
extends RefCounted
## Shared material registry: assets/materials/<name>.tres, loaded once.

static var _cache := {}


static func get_mat(name: String) -> Material:
	var m: Material = _cache.get(name)
	if m == null:
		var path := "res://assets/materials/%s.tres" % name
		assert(ResourceLoader.exists(path), "missing material " + path)
		m = load(path)
		_cache[name] = m
	return m


## Replaces materials of an imported model by name: a glTF material called
## "clay" becomes assets/materials/clay.tres (glTF cannot carry our shaders).
static func apply_to(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			if src == null:
				continue
			var key := material_key(src.resource_name)
			if key != "":
				mi.set_surface_override_material(i, get_mat(key))


## Which of our materials a model's surface means. The glTF export renames a
## material that clashes with a node ("cypress" became "cypress2"), so a
## trailing number is dropped when the name itself is not one of ours; without
## this the surface stayed the importer's plain white (the slope's cypresses).
static func material_key(name: String) -> String:
	var key := name.to_lower()
	if ResourceLoader.exists("res://assets/materials/%s.tres" % key):
		return key
	var bare := key.rstrip("0123456789").trim_suffix("_").trim_suffix(".")
	if bare != key and ResourceLoader.exists("res://assets/materials/%s.tres" % bare):
		return bare
	return ""


static func clear() -> void:
	_cache.clear()
