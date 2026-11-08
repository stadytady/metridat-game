class_name Sea
extends Node3D
## Sea plane east of the shore plus the opposite (Asian) shore of the strait
## as a hazy silhouette beyond the fog. The waves are computed in the water
## shader; height_at() is the same sum on the CPU, on the same clock, so
## ships can ride them instead of being washed over.



## Grid: 4 m cells near the shore (where the swell is seen up close),
## coarser towards the horizon, where fog hides it anyway.
const SHORE_Z := Vector2(-512.0, 512.0)
const SHORE_SAMPLES := 256
## The wind comes in off the strait (from the east, +x) and blows inland: the
## swell rolls towards the shore and the hearth smoke leans up the hill. One
## direction for both, so the sea and the roofs agree.
const ONSHORE := Vector2(-1.0, 0.0)
## psx_water defaults: dir.x, dir.y (the way the crests travel), wavelength,
## amplitude. Every train runs shoreward (dir.x < 0), the long swell most nearly
## along ONSHORE.
const WAVES := [Vector4(-1.0, -0.25, 42.0, 0.55), Vector4(-0.75, 0.65, 24.0, 0.28), Vector4(-0.3, -1.0, 14.0, 0.16),
	Vector4(-1.0, 0.1, 8.0, 0.09)]
const SPEED := 0.75
const AMPLITUDE := 1.0
## The harbour by the pier is sheltered: the swell there is a third of the open strait's.
const CALM_RADIUS := 26.0
const CALM := 0.68


static var _calm := Vector2.INF


static func calm_center() -> Vector2:
	if _calm == Vector2.INF:
		_calm = Vector2((Topo.pier_x0() + Topo.pier_x1()) / 2.0 + 4.0, Topo.PIER_Z - 3.0)
	return _calm

## Seconds on the sea's clock; the shader reads it as sea_time.
static var clock := 0.0
var _mat: ShaderMaterial


## Height of the water surface above sea level at (x, z) and time t, exactly as
## psx_water's vertex shader moves it (shoaling towards the shore, calm at the waterline).
static func height_at(x: float, z: float, t: float = clock) -> float:
	var shore_d := x - shore_x(z)
	var shoal := 1.0 - smoothstep(0.0, 70.0, shore_d)
	var h := 0.0
	for i in WAVES.size():
		var wv: Vector4 = WAVES[i]
		var d := Vector2(wv.x, wv.y).normalized()
		var len := wv.z * lerpf(1.0, 0.6, shoal)
		var k := TAU / len
		var w := sqrt(9.8 * k) * SPEED
		var a := wv.w * lerpf(1.0, 1.7, shoal)
		var s := sin(d.dot(Vector2(x, z)) * k - w * t + float(i) * 1.7)
		h += a * (s + 0.25 * s * absf(s))
	var calm := 1.0 - CALM * (1.0 - smoothstep(CALM_RADIUS * 0.5, CALM_RADIUS, Vector2(x, z).distance_to(calm_center())))
	return h * AMPLITUDE * smoothstep(-1.0, 6.0, shore_d) * calm


## How a hull floats at `pos` heading `yaw` (rad about y; the model's bow is +x):
## Vector3(heave, roll, pitch) in metres and radians. The hull spans the waves,
## so it rides their average over its length and beam, not each crest.
static func float_pose(pos: Vector3, yaw: float, half_len: float, half_beam: float, t: float = clock) -> Vector3:
	var fwd := Vector3(cos(yaw), 0, -sin(yaw))
	var side := Vector3(sin(yaw), 0, cos(yaw))
	var bow := height_at(pos.x + fwd.x * half_len, pos.z + fwd.z * half_len, t)
	var stern := height_at(pos.x - fwd.x * half_len, pos.z - fwd.z * half_len, t)
	var port := height_at(pos.x + side.x * half_beam, pos.z + side.z * half_beam, t)
	var star := height_at(pos.x - side.x * half_beam, pos.z - side.z * half_beam, t)
	var mid := height_at(pos.x, pos.z, t)
	var heave := (bow + stern + port + star + mid * 2.0) / 6.0
	return Vector3(heave, -atan2(port - star, half_beam * 2.0), atan2(bow - stern, half_len * 2.0))


func _ready() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "Water"
	sea.mesh = _grid()
	var mat: ShaderMaterial = Mats.get_mat("water").duplicate()
	_mat = mat
	mat.set_shader_parameter("shore_tex", _shore_texture())
	mat.set_shader_parameter("shore_z_range", SHORE_Z)
	var c := calm_center()
	mat.set_shader_parameter("calm", Vector4(c.x, c.y, CALM_RADIUS, CALM))
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Waves move vertices; keep the sea from being culled when they rise.
	sea.extra_cull_margin = 4.0
	add_child(sea)
	add_child(_far_shore())


func _process(delta: float) -> void:
	clock = fmod(clock + delta, 3600.0)
	_mat.set_shader_parameter("sea_time", clock)


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
	var table := _shore_table()
	for i in SHORE_SAMPLES:
		img.set_pixel(i, 0, Color(table[i], 0, 0))
	return ImageTexture.create_from_image(img)


## The waterline sampled once (Topo.waterline_x walks the terrain, far too slow
## to call per wave sample); the shader gets the same table as shore_tex.
static var _shore := PackedFloat32Array()


static func _shore_table() -> PackedFloat32Array:
	if _shore.is_empty():
		_shore.resize(SHORE_SAMPLES)
		for i in SHORE_SAMPLES:
			_shore[i] = Topo.waterline_x(lerpf(SHORE_Z.x, SHORE_Z.y, float(i) / (SHORE_SAMPLES - 1)))
	return _shore


## The waterline as the shader reads it: shore_tex with linear filtering
## (texel centres at (i + 0.5) / N, clamped at the ends).
static func shore_x(z: float) -> float:
	var table := _shore_table()
	var u := clampf((z - SHORE_Z.x) / (SHORE_Z.y - SHORE_Z.x), 0.0, 1.0)
	var f := clampf(u * SHORE_SAMPLES - 0.5, 0.0, SHORE_SAMPLES - 1.0)
	var i := mini(int(f), SHORE_SAMPLES - 2)
	return lerpf(table[i], table[i + 1], f - i)


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
	mat.set_shader_parameter("haze", 0.62)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "FarShore"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
