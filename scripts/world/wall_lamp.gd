class_name WallLamp
extends Node3D
## An oil lamp on a bracket beside a door: dark by day, lit when the sun is down.
## Same flame and flicker as the street lamps, so the town looks one piece at night.

const DUSK := DayCycle.LAMPS_ON

var lit := false
var _light: OmniLight3D
var _flame: GPUParticles3D
var _sound: AudioStreamPlayer3D
var _ignite: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"wall_lamp")
	var kit := MeshKit.new()
	# iron bracket and the dish of the lamp
	kit.box("dark", Vector3(0, 0.06, 0.06), Vector3(0.06, 0.06, 0.34), ["bottom"], {})
	kit.box("dark", Vector3(0, 0.18, 0.2), Vector3(0.05, 0.24, 0.05), ["bottom"], {})
	kit.box("clay", Vector3(0, 0.3, 0.2), Vector3(0.2, 0.08, 0.2), ["bottom"], {})
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	add_child(mi)
	_flame = Lamp._make_flame(0.07)
	_flame.position = Vector3(0, 0.37, 0.2)
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.42, 0.2)
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	_light.set_script(preload("res://scripts/world/flicker.gd"))
	_light.base_energy = 1.5
	_light.amount = 0.4
	_light.visible = false
	add_child(_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = preload("res://assets/audio/fire.wav")
	_sound.volume_db = -24.0
	_sound.unit_size = 1.2
	_sound.max_distance = 10.0
	_sound.position = Vector3(0, 0.3, 0.2)
	add_child(_sound)
	_ignite = AudioStreamPlayer3D.new()
	_ignite.stream = preload("res://assets/audio/lamp_ignite.wav")
	_ignite.volume_db = -15.0
	_ignite.unit_size = 1.4
	_ignite.max_distance = 12.0
	_ignite.position = Vector3(0, 0.3, 0.2)
	add_child(_ignite)
	set_lit(false)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_flame.emitting = on
	_flame.visible = on
	_light.visible = on
	if on:
		_ignite.play()
		_sound.pitch_scale = randf_range(0.95, 1.06)
		_sound.play(randf() * 2.5)
	else:
		_sound.stop()
