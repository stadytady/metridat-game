class_name Lamp
extends StaticBody3D
## A lamp or torch on the route that the player lights with E. Unlit it is
## just a prop; lit it gets a flickering omni light, a small PS1 flame and
## a quiet crackle. (Greek towns had no street lighting: the row of lamps is
## a game device, built from period objects - bronze lampstands, clay oil
## lamps, torches.)

@export_enum("lampstand", "torch_post") var kind := "lampstand"

var lit := false
var _light: OmniLight3D
var _flame: GPUParticles3D
var _sound: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 3
	set_meta(&"surface", &"stone")
	add_to_group(&"lamp")
	add_child(Props.build(kind).build("Model"))
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 1.6
	cs.shape = shape
	cs.position.y = 0.8
	add_child(cs)
	var y: float = Props.FLAME_Y[kind]
	_light = OmniLight3D.new()
	_light.position.y = y + 0.15
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 7.5 if kind == "torch_post" else 6.0
	_light.shadow_enabled = false
	_light.set_script(preload("res://scripts/world/flicker.gd"))
	_light.base_energy = 1.8 if kind == "torch_post" else 1.4
	_light.amount = 0.35
	_light.visible = false
	add_child(_light)
	_flame = _make_flame(0.12 if kind == "torch_post" else 0.07)
	_flame.position.y = y
	add_child(_flame)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = preload("res://assets/audio/fire.wav")
	_sound.volume_db = -16.0
	_sound.unit_size = 1.5
	_sound.max_distance = 12.0
	_sound.position.y = y
	add_child(_sound)
	Game.lamps.append(self)


func _exit_tree() -> void:
	Game.lamps.erase(self)


func can_interact() -> bool:
	return not lit


func get_prompt() -> String:
	return tr("UI_LIGHT_TORCH") if kind == "torch_post" else tr("UI_LIGHT_LAMP")


func interact() -> void:
	if lit:
		return
	lit = true
	_light.visible = true
	_flame.emitting = true
	_flame.visible = true
	_sound.play(randf() * 4.0)
	Game.lamp_lit.emit(Game.lamps_lit(), Game.lamps.size())


static func _make_flame(size: float) -> GPUParticles3D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.85, 0.4))
	grad.set_color(1, Color(0.6, 0.12, 0.02))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	ramp.width = 8
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.3, 0)
	pm.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.fixed_fps = 15
	p.process_material = pm
	p.draw_pass_1 = quad
	p.emitting = false
	p.visible = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
