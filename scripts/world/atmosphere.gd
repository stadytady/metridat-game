extends Node3D
## Late-afternoon light: low warm sun from the west (behind the player on the
## hill, so the city faces are lit and shadows run towards the sea), painted
## panorama sky, PS1-style linear depth fog that melts the sea into the haze.

const FOG := Color("#d9a774")
const SUN_ELEVATION := 20.0

var sun: DirectionalLight3D


func _ready() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = preload("res://assets/textures/sky.png")
	sky_mat.filter = false
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8d8078")
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 560.0
	env.fog_depth_curve = 1.15
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#ffbd7a")
	sun.light_energy = 1.9
	sun.rotation_degrees = Vector3(-SUN_ELEVATION, -100.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	sun.shadow_opacity = 0.85
	add_child(sun)
