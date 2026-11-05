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

## Ride low in the water like the moored ship, with a deck laid over the model's
## own floor so the boat stays dry inside.
const WATERLINE := 0.0
const DECK_Y := 0.86
## The hull's own half beams at deck level, measured from the model; the test keeps
## the deck inside them.
const HULL_PLAN := [
	[0.0, 1.97], [1.0, 1.93], [2.0, 1.90], [3.0, 1.82],
	[4.0, 1.63], [5.0, 1.34], [6.0, 1.14], [7.0, 0.94],
]

## The hull's own plan at deck level, measured from the model: [distance from
## midships, half beam]. A straight box deck would hang over the sides and past the
## stern — it used to, 8 m wide on a 3.9 m hull.
const DECK_PLAN := [
	[0.0, 1.86], [1.0, 1.82], [2.0, 1.76], [3.0, 1.70],
	[4.0, 1.52], [5.0, 1.22], [6.0, 1.00], [6.5, 0.82],
]
## How far aft and forward the deck runs, and the rail it sits on.
const DECK_END := 6.5
const DECK_STEP := 0.5
## The model's keel, from its mesh bounds: the test keeps it under the sea.
const HULL_BOTTOM := -0.67
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


## Half the hull's beam at a distance from midships, so the deck can follow it.
static func deck_half_beam(x: float) -> float:
	var ax := absf(x)
	if ax >= DECK_END:
		return DECK_PLAN[DECK_PLAN.size() - 1][1]
	for i in DECK_PLAN.size() - 1:
		var a: Array = DECK_PLAN[i]
		var b: Array = DECK_PLAN[i + 1]
		if ax <= b[0]:
			var t: float = (ax - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(a[1], b[1], t)
	return DECK_PLAN[DECK_PLAN.size() - 1][1]


## The hull's half beam at a distance from midships, for the tests.
static func hull_half_beam(x: float) -> float:
	var ax := absf(x)
	for i in HULL_PLAN.size() - 1:
		var a: Array = HULL_PLAN[i]
		var b: Array = HULL_PLAN[i + 1]
		if ax <= b[0]:
			var t: float = (ax - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(a[1], b[1], t)
	return HULL_PLAN[HULL_PLAN.size() - 1][1]

## A deck that follows the hull instead of a slab laid over it: strips between the
## measured beams, and a transom closing each end so the boat is not a scoop.
## The ship node carries its own scale, so the deck is built in the model's own units.
func _shaped_deck(ship: Node3D) -> void:
	var kit := MeshKit.new()
	var x := -DECK_END
	while x < DECK_END - 0.01:
		var x1 := minf(x + DECK_STEP, DECK_END)
		var w0 := deck_half_beam(x)
		var w1 := deck_half_beam(x1)
		kit.quad("wood", Vector3(x, DECK_Y, -w0), Vector3(x, DECK_Y, w0),
				Vector3(x1, DECK_Y, w1), Vector3(x1, DECK_Y, -w1))
		x = x1
	for sx: float in [-1.0, 1.0]:
		var ex: float = sx * (DECK_END - 0.2)
		var w := deck_half_beam(DECK_END - 0.4)
		var top := DECK_Y
		var low := 0.3
		if sx > 0.0:
			kit.quad("hull", Vector3(ex, top, -w), Vector3(ex, top, w), Vector3(ex, low, w), Vector3(ex, low, -w))
		else:
			kit.quad("hull", Vector3(ex, top, w), Vector3(ex, top, -w), Vector3(ex, low, -w), Vector3(ex, low, w))
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ship.add_child(mi)

func _ready() -> void:
	_atm = get_parent().get_node_or_null("Atmosphere")
	for s: Array in SHIPS:
		var n := place("ship", s[0], s[1], Vector3.ONE * float(s[2]))
		_shaped_deck(n)
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
