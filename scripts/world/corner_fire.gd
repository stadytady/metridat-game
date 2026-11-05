class_name CornerFire
extends Node3D
## A fire that nobody lights by hand: a torch at the corner of the theatre, a
## brazier at the corner of the square, a lamp beside a stoa column. Same flame,
## same flicker, same quiet crackle as a route lamp; whoever owns it decides when
## it is lit (the theatre answers the two lamps by the orchestra, the agora waits
## for dusk).

## Which prop to build: a torch post or a bronze lampstand.
@export var kind := "torch_post"
## Lamps beside the columns burn without their own crackle: ten of them at once
## would be a roar.
@export var quiet := false

var lit := false
var _light: OmniLight3D
var _flame: GPUParticles3D
var _sound: AudioStreamPlayer3D
var _ignite: AudioStreamPlayer3D


func _ready() -> void:
	add_child(Props.build(kind).build("Model"))
	var y: float = Props.FLAME_Y[kind]
	_light = OmniLight3D.new()
	_light.position.y = y + 0.2
	_light.light_color = Color(1.0, 0.6, 0.28)
	_light.omni_range = 9.0 if kind == "torch_post" else 6.5
	_light.shadow_enabled = false
	_light.set_script(preload("res://scripts/world/flicker.gd"))
	_light.base_energy = 2.0 if kind == "torch_post" else 1.3
	_light.amount = 0.45
	_light.visible = false
	add_child(_light)
	_flame = Lamp._make_flame(0.16 if kind == "torch_post" else 0.08)
	_flame.position.y = y
	add_child(_flame)
	if quiet:
		return
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = preload("res://assets/audio/fire.wav")
	_sound.volume_db = -20.0
	_sound.unit_size = 1.6
	_sound.max_distance = 14.0
	_sound.position.y = y
	add_child(_sound)
	_ignite = AudioStreamPlayer3D.new()
	_ignite.stream = preload("res://assets/audio/lamp_ignite.wav")
	_ignite.volume_db = -13.0
	_ignite.unit_size = 1.4
	_ignite.max_distance = 12.0
	_ignite.position.y = y
	add_child(_ignite)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	_light.visible = on
	_flame.emitting = on
	_flame.visible = on
	if _sound == null:
		return
	if on:
		_ignite.play()
		_sound.pitch_scale = randf_range(0.94, 1.05)
		_sound.play(randf() * 3.0)
	else:
		_sound.stop()
