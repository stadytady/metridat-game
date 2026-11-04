extends District
## Merchant ships on the strait. In the afternoon they are out in the haze;
## as the day goes they make for an anchorage off the beach below the agora,
## and by night they ride at anchor there with a lantern lit. Nobody sails
## the strait in the dark. The hour is the atmosphere's (DayCycle), so the
## ships follow the same evening as the sky.

## start, start heading (deg), scale, anchorage
const SHIPS := [
	[Vector3(260, 0, -70), 25.0, 1.0, Vector3(118, 0, -34)],
	[Vector3(470, 0, 120), -40.0, 1.15, Vector3(128, 0, 10)],
	[Vector3(820, 0, -260), 70.0, 1.3, Vector3(146, 0, 46)],
	[Vector3(380, 0, -190), 55.0, 1.05, Vector3(134, 0, -66)],
	[Vector3(640, 0, 60), -15.0, 1.2, Vector3(156, 0, -12)],
]

## The ship model has its keel at y = 0; sink it to its waterline.
const WATERLINE := -1.0
## Under way from this hour, at anchor by that one.
const SAIL_FROM := 0.12
const ANCHOR_BY := 0.85
## Lanterns are lit once the ships ride at anchor in the dusk.
const LANTERN_FROM := 0.8

var _ships: Array[Node3D] = []
var _lanterns: Array[OmniLight3D] = []
var _t := 0.0
var _atm: Node


## 0 at the start, 1 at anchor; eases in and out of the passage.
static func progress(hour: float) -> float:
	return smoothstep(SAIL_FROM, ANCHOR_BY, hour)


static func position_at(start: Vector3, anchor: Vector3, hour: float) -> Vector3:
	return start.lerp(anchor, progress(hour))


## Heading (deg about y; the model's bow is +x): the starting heading at rest,
## turning onto the course as the ship gets under way.
static func heading_at(start: Vector3, start_yaw: float, anchor: Vector3, hour: float) -> float:
	var d := anchor - start
	var course := rad_to_deg(atan2(-d.z, d.x))
	var turn := smoothstep(0.0, 0.08, progress(hour))
	return rad_to_deg(lerp_angle(deg_to_rad(start_yaw), deg_to_rad(course), turn))


func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	for s: Array in SHIPS:
		var n := place("ship", s[0], s[1], Vector3.ONE * float(s[2]))
		for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ships.append(n)
		# a lantern hung at the stern post
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-7.4, 3.6, 0)
		lamp.light_color = Color(1, 0.62, 0.3)
		lamp.omni_range = 9.0
		lamp.set_script(preload("res://scripts/world/flicker.gd"))
		lamp.base_energy = 1.4
		lamp.amount = 0.3
		lamp.visible = false
		n.add_child(lamp)
		# the lantern itself: a small unlit flame, a point of light across the water
		var kit := MeshKit.new()
		kit.box("flame", Vector3.ZERO, Vector3(0.35, 0.45, 0.35), [])
		var glow := MeshInstance3D.new()
		glow.mesh = kit.commit()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(glow)
		_lanterns.append(lamp)


func _process(delta: float) -> void:
	_t += delta
	var hour: float = _atm.t if _atm else 0.0
	for i in _ships.size():
		var n := _ships[i]
		var s: Array = SHIPS[i]
		var p := position_at(s[0], s[3], hour)
		var yaw := deg_to_rad(heading_at(s[0], s[1], s[3], hour))
		var k := float(s[2])
		# ride the same waves the sea draws, so no crest ever washes over the deck
		var f := Sea.float_pose(p, yaw, 7.0 * k, 2.2 * k)
		n.position = Vector3(p.x, WATERLINE * k + f.x, p.z)
		n.rotation = Vector3(f.y, yaw, f.z)
		_lanterns[i].visible = hour >= LANTERN_FROM
