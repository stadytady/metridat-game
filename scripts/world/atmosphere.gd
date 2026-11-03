extends Node3D
## Light, sky and fog for the hour of DayCycle. Starts in the late afternoon:
## low warm sun from the west (behind the player on the hill, so the city
## faces are lit and shadows run towards the sea); every find moves the
## evening on, the last one brings the night with a cold moon from the east.

const SUN_YAW := -100.0
## Seconds for the light to catch up with a new target hour.
const TRANSITION := 12.0

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
## Current hour (0..1); eases towards Game.time_target().
var t := 0.0


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://assets/shaders/psx_sky.gdshader")
	sky_mat.set_shader_parameter("day_tex", preload("res://assets/textures/sky.png"))
	sky_mat.set_shader_parameter("dusk_tex", preload("res://assets/textures/sky_dusk.png"))
	sky_mat.set_shader_parameter("night_tex", preload("res://assets/textures/sky_night.png"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
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
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	sun.shadow_opacity = 0.85
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#8fa4d8")
	moon.rotation_degrees = Vector3(-38.0, 70.0, 0.0)  # high in the east, over the strait
	moon.shadow_enabled = false
	add_child(moon)

	t = Game.time_target()
	apply(t)


func _process(delta: float) -> void:
	var target := Game.time_target()
	if is_equal_approx(t, target):
		return
	# Automation (screenshots, trailer) jumps straight to its hour.
	# Automation and the dream (entered and left behind a fade) jump straight there.
	var snap := Game.time_override >= 0.0 or Game.dreaming or t > 1.0
	t = target if snap else move_toward(t, target, delta / TRANSITION)
	apply(t)


func apply(hour: float) -> void:
	var k := DayCycle.sample(hour)
	sun.rotation_degrees = Vector3(-maxf(k.sun_elevation, 1.0), SUN_YAW, 0.0)
	sun.light_color = k.sun_color
	sun.light_energy = k.sun_energy
	sun.visible = k.sun_energy > 0.01
	moon.light_energy = k.moon_energy
	moon.visible = k.moon_energy > 0.01
	env.ambient_light_color = k.ambient_color
	env.ambient_light_energy = k.ambient_energy
	env.fog_light_color = k.fog_color
	env.fog_depth_begin = k.fog_begin
	env.fog_depth_end = k.fog_end
	sky_mat.set_shader_parameter("weights", k.sky_weights)
	var tint: Color = k.light_tint
	RenderingServer.global_shader_parameter_set(&"psx_light_tint", Vector3(tint.r, tint.g, tint.b))
	RenderingServer.global_shader_parameter_set(&"psx_fog_color", k.fog_color)
	var key := sun if sun.visible else moon
	RenderingServer.global_shader_parameter_set(&"psx_key_dir", key.global_transform.basis.z)
