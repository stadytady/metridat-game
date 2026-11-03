extends District
## What the night brings to the city, kept quiet so the dream keeps its force:
## a pale light walking on the strait where no boat is, a lamp lit beside
## Hecate's supper at the crossroads where the street meets the agora, a dark
## figure at the turn of the street that is gone when you come close, the
## yard dog awake and watching the sanctuary, and dogs howling far off.
## By day there is only the fisherman's fish left on its stone and the
## bowls at the crossroads. Nothing here has a collider.

## Night, by the atmosphere's hour (the last find brings 1.0).
const NIGHT := 0.95
## The fisherman's offering: a fish on a flat stone at the water's edge.
const FISH_STONE := Vector2(0.0, 19.5)  # x is taken from the waterline
## Hecate's supper where the street comes into the agora, by the stoa's end.
const SUPPER := Vector3(9.8, Topo.AGORA_H, -3.6)
## The figure stands at the turn of the street, facing up towards the agora.
const FIGURE_X := -29.5
const VANISH_DIST := 12.0
## Where the dogs howl from: beyond the sanctuary.
const HOWL_FROM := Vector3(70, 14, -60)
const SANCTUARY := Vector3(46.0, Topo.SANCT_H + 1.0, -27.0)

var figure: Node3D
var vanished := false
var wisp: Node3D
var supper_lamp: OmniLight3D
var howls := 0
var night := false

var _atm: Node
var _howl: AudioStreamPlayer3D
var _howl_in := 8.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _night_parts: Array[Node3D] = []


static func is_night(hour: float) -> bool:
	return hour >= NIGHT


## The light's wandering over the strait: slow loops well off the beach.
static func wisp_at(t: float) -> Vector3:
	var x := 106.0 + sin(t * 0.07) * 9.0 + sin(t * 0.19) * 2.0
	var z := 14.0 + sin(t * 0.05 + 1.0) * 18.0
	return Vector3(x, 1.6 + sin(t * 0.9) * 0.3, z)


## The light shows and goes in turns, a pop as on the dream path: true while shown.
static func wisp_shown(t: float) -> bool:
	return fposmod(t, 11.0) < 7.0


static func figure_point() -> Vector3:
	var x := FIGURE_X
	var dz := Topo.street_z(x + 0.5) - Topo.street_z(x - 0.5)
	var side := Vector3(-dz, 0, 1).normalized()
	return Vector3(x, Topo.street_height(x), Topo.street_z(x)) + side * (Topo.STREET_HALF - 0.6)


func _ready() -> void:
	_rng.seed = 519
	_atm = get_parent().get_node_or_null("Atmosphere")
	var kit := MeshKit.new()
	_fish_stone(kit)
	_supper(kit)
	add_child(kit.build("Omens"))
	_wisp()
	_figure()
	_howl = AudioStreamPlayer3D.new()
	_howl.name = "NightHowl"
	_howl.stream = preload("res://assets/audio/dog_howl.wav")
	_howl.position = HOWL_FROM
	_howl.unit_size = 40.0
	_howl.max_distance = 400.0
	_howl.volume_db = -10.0
	add_child(_howl)
	_set_night(false)


func _fish_stone(kit: MeshKit) -> void:
	var z := FISH_STONE.y
	var x := Topo.waterline_x(z) - 2.2
	var c := Vector3(x, Topo.terrain(x, z), z)
	kit.box("rock", c + Vector3(0, 0.12, 0), Vector3(0.7, 0.3, 0.55), ["bottom"])
	kit.xform = Transform3D(Basis(Vector3.UP, 0.5), c + Vector3(0, 0.29, 0))
	kit.box("fish", Vector3.ZERO, Vector3(0.36, 0.06, 0.09), ["bottom"])
	kit.box("fish", Vector3(-0.2, 0, 0), Vector3(0.06, 0.05, 0.11), ["bottom"])  # tail
	kit.xform = Transform3D.IDENTITY


func _supper(kit: MeshKit) -> void:
	for i in 2:
		var p := SUPPER + Vector3(0.36 * i, 0, 0.1 * i)
		kit.lathe("clay", PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.14, 0.07), Vector2(0.15, 0.09)]), 7, p, 1.0, true, "clay", false)
		kit.box("bark" if i == 0 else "clay", p + Vector3(0, 0.08, 0), Vector3(0.12, 0.04, 0.1), [])  # bread, a cake
	var at := SUPPER + Vector3(0.18, 0, -0.3)
	kit.lathe("clay", PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.08, 0.03), Vector2(0.06, 0.07)]), 6, at, 1.0, true, "dark", true)
	kit.box("clay", at + Vector3(0.09, 0.055, 0), Vector3(0.07, 0.025, 0.03), [])
	var flame := MeshKit.new()
	flame.box("flame", at + Vector3(0.12, 0.1, 0), Vector3(0.04, 0.07, 0.04), [])
	var fm := MeshInstance3D.new()
	fm.mesh = flame.commit()
	add_child(fm)
	_night_parts.append(fm)
	supper_lamp = OmniLight3D.new()
	supper_lamp.position = at + Vector3(0.1, 0.35, 0)
	supper_lamp.light_color = Color(1, 0.66, 0.36)
	supper_lamp.omni_range = 3.0
	supper_lamp.set_script(preload("res://scripts/world/flicker.gd"))
	supper_lamp.base_energy = 1.4
	supper_lamp.amount = 0.3
	add_child(supper_lamp)
	_night_parts.append(supper_lamp)


func _wisp() -> void:
	wisp = Node3D.new()
	wisp.name = "Wisp"
	var k := MeshKit.new()
	k.box("wisp", Vector3.ZERO, Vector3(0.6, 0.8, 0.6), [])
	k.box("wisp", Vector3(0, 0.75, 0), Vector3(0.25, 0.5, 0.25), [])  # a tongue of pale flame
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wisp.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.88, 1.0)
	light.omni_range = 16.0
	light.set_script(preload("res://scripts/world/flicker.gd"))
	light.base_energy = 3.0
	light.amount = 0.2
	wisp.add_child(light)
	add_child(wisp)
	wisp.position = wisp_at(0.0)


## A standing person, all dark, like the figures on the dream path.
func _figure() -> void:
	figure = Node3D.new()
	figure.name = "NightFigure"
	figure.position = figure_point()
	figure.rotation.y = -PI / 2.0  # faces +x, up the street towards the agora
	add_child(figure)
	var joints := Figure.build(figure, "dark")
	Figure.apply_pose(joints, "stand")
	var dark: Material = Mats.get_mat("dark")
	for mi: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = dark


func _set_night(on: bool) -> void:
	night = on
	for n in _night_parts:
		n.visible = on
	figure.visible = on and not vanished
	for d: Node in get_tree().get_nodes_in_group(&"dog"):
		d.set("watch", SANCTUARY if on else Vector3.INF)


func _process(delta: float) -> void:
	_t += delta
	var hour: float = _atm.t if _atm else 0.0
	if is_night(hour) != night:
		_set_night(is_night(hour))
	wisp.visible = night and wisp_shown(_t)
	if not night:
		return
	wisp.position = wisp_at(_t)
	var cam := get_viewport().get_camera_3d()
	if cam and figure.visible:
		var d := Vector2(figure.global_position.x - cam.global_position.x, figure.global_position.z - cam.global_position.z)
		if d.length() < VANISH_DIST:
			figure.visible = false  # a pop, not a fade
			vanished = true
	if Game.dreaming:
		return
	_howl_in -= delta
	if _howl_in <= 0.0:
		_howl.pitch_scale = _rng.randf_range(0.85, 1.0)
		_howl.play()
		howls += 1
		_howl_in = _rng.randf_range(20.0, 40.0)
