extends Node3D
## Sea plane east of the shore plus the opposite (Asian) shore of the strait
## as a hazy silhouette beyond the fog.

const HAZE := Color("#d9a774")


## Grid: 4 m cells near the shore (where the swell is seen up close),
## coarser towards the horizon, where fog hides it anyway.
const SHORE_Z := Vector2(-512.0, 512.0)
const SHORE_SAMPLES := 256


func _ready() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "Water"
	sea.mesh = _grid()
	var mat: ShaderMaterial = Mats.get_mat("water").duplicate()
	mat.set_shader_parameter("shore_tex", _shore_texture())
	mat.set_shader_parameter("shore_z_range", SHORE_Z)
	var sun: DirectionalLight3D = get_parent().get_node_or_null("Atmosphere/Sun")
	if sun:
		mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z)  # towards the sun
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Waves move vertices; keep the sea from being culled when they rise.
	sea.extra_cull_margin = 4.0
	add_child(sea)
	add_child(_far_shore())


static func _axis(segments: Array) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for seg: Array in segments:
		var v: float = seg[0]
		while v < seg[1] - 0.001:
			a.append(v)
			v += seg[2]
	a.append(segments[-1][1])
	return a


static func _grid() -> ArrayMesh:
	var xs := _axis([[20.0, 420.0, 4.0], [420.0, 1620.0, 20.0], [1620.0, 8100.0, 300.0]])
	var zs := _axis([[-4500.0, -1500.0, 300.0], [-1500.0, -300.0, 20.0], [-300.0, 300.0, 4.0],
			[300.0, 1500.0, 20.0], [1500.0, 4500.0, 300.0]])
	var verts := PackedVector3Array()
	verts.resize(xs.size() * zs.size())
	for j in zs.size():
		for i in xs.size():
			verts[j * xs.size() + i] = Vector3(xs[i], Topo.SEA_LEVEL, zs[j])
	var idx := PackedInt32Array()
	var nx := xs.size()
	for j in zs.size() - 1:
		for i in nx - 1:
			var a := j * nx + i
			# clockwise seen from above (Godot front faces), alternating diagonals
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Waterline x per z as a 1-px-high float texture for the shader.
static func _shore_texture() -> ImageTexture:
	var img := Image.create(SHORE_SAMPLES, 1, false, Image.FORMAT_RF)
	for i in SHORE_SAMPLES:
		var z := lerpf(SHORE_Z.x, SHORE_Z.y, float(i) / (SHORE_SAMPLES - 1))
		img.set_pixel(i, 0, Color(Topo.waterline_x(z), 0, 0))
	return ImageTexture.create_from_image(img)


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
