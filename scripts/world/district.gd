class_name District
extends Node3D
## Base for the self-building parts of the map: helpers to place baked props
## with simple colliders and to drop in inspectable scenes.

var _body: StaticBody3D


func props_body() -> StaticBody3D:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "PropColliders"
		_body.set_meta(&"surface", &"stone")
		add_child(_body)
	return _body


## Instances a baked model. radius > 0 adds an upright cylinder collider.
func place(model: String, pos: Vector3, yaw_deg: float = 0.0, scale: Vector3 = Vector3.ONE,
		radius: float = 0.0, height: float = 0.0) -> Node3D:
	var n := Props.instance(model)
	n.transform = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(yaw_deg), 0)).scaled(scale), pos)
	add_child(n)
	if radius > 0.0:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.position = pos + Vector3(0, height / 2.0, 0)
		props_body().add_child(cs)
	return n


func spawn_inspectable(id: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var path := "res://scenes/interactables/%s.tscn" % id
	if not ResourceLoader.exists(path):
		push_warning("inspectable scene missing: " + path)
		return null
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	add_child(n)
	return n


static func min_terrain(center: Vector2, half: Vector2) -> float:
	var m := INF
	for sx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for sz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			m = minf(m, Topo.terrain(center.x + half.x * sx, center.y + half.y * sz))
	return m
