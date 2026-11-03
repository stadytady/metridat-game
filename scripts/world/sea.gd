extends Node3D
## Sea plane east of the shore plus the opposite (Asian) shore of the strait
## as a hazy silhouette beyond the fog.

const HAZE := Color("#d9a774")


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	plane.subdivide_width = 90
	plane.subdivide_depth = 90
	var sea := MeshInstance3D.new()
	sea.name = "Water"
	sea.mesh = plane
	sea.material_override = Mats.get_mat("water")
	sea.position = Vector3(3500, Topo.SEA_LEVEL, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	add_child(_far_shore())


## The strait is narrowed for readability: the real one is wider than the fog allows.
func _far_shore() -> MeshInstance3D:
	var kit := MeshKit.new()
	kit.max_edge = INF  # past the fog, affine warp is invisible
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.004
	var x_front := 1500.0
	var x_back := 2300.0
	var z := -3200.0
	var prev_h := 0.0
	var step := 80.0
	while z < 3200.0:
		var h := 25.0 + 45.0 * (n.get_noise_1d(z) * 0.5 + 0.5) + rng.randf_range(-4, 4)
		if z > -3200.0:
			var fx := x_front + 60.0 * sin(z * 0.003)
			var fx2 := x_front + 60.0 * sin((z + step) * 0.003)
			# front slope facing the city (west), then the back
			kit.quad("distant_land", Vector3(fx, -2, z), Vector3(fx2, -2, z + step),
					Vector3(fx2 + 300, h, z + step), Vector3(fx + 300, prev_h, z))
			kit.quad("distant_land", Vector3(fx + 300, prev_h, z), Vector3(fx2 + 300, h, z + step),
					Vector3(x_back, 10, z + step), Vector3(x_back, 10, z))
		prev_h = h
		z += step
	var mesh := kit.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/psx_haze.gdshader")
	mat.set_shader_parameter("land_color", Color("#5a5446"))
	mat.set_shader_parameter("haze_color", HAZE)
	mat.set_shader_parameter("haze", 0.62)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "FarShore"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
