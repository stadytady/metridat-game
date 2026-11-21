extends SceneTree
func _init() -> void:
	var xf: Transform3D = load("res://scripts/world/mint.gd").frame()
	var floor_y := xf.origin.y + 0.75 + Arch.FLOOR_LIFT
	print("front y=", xf.origin.y, " floor top=", floor_y)
	for z in [0.5, 1.5, 2.5, 3.5, 4.5]:
		var s := ""
		for x in [-2.2, -1.0, 0.0, 1.0, 2.2]:
			var p := xf * Vector3(x, 0, -z)
			s += "%+.2f " % (Topo.terrain(p.x, p.z) - floor_y)
		print("depth ", z, ": ", s)
	quit()
