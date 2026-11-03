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
			var key := src.resource_name.to_lower()
			if ResourceLoader.exists("res://assets/materials/%s.tres" % key):
				mi.set_surface_override_material(i, get_mat(key))


static func clear() -> void:
	_cache.clear()
