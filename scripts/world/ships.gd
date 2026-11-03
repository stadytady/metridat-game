extends District
## Merchant ships on the strait. They mostly matter as silhouettes in the haze.

const SHIPS := [
	[Vector3(260, 0, -70), 25.0, 1.0],
	[Vector3(470, 0, 120), -40.0, 1.15],
	[Vector3(820, 0, -260), 70.0, 1.3],
]

## The ship model has its keel at y = 0; sink it to its waterline.
const WATERLINE := -1.0

var _ships: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	for s: Array in SHIPS:
		var n := place("ship", s[0], s[1], Vector3.ONE * float(s[2]))
		for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ships.append(n)


func _process(delta: float) -> void:
	_t += delta
	for i in _ships.size():
		var n := _ships[i]
		var base: Vector3 = SHIPS[i][0]
		n.position.y = base.y + WATERLINE * float(SHIPS[i][2]) + sin(_t * 0.7 + i) * 0.25
		n.rotation.z = sin(_t * 0.5 + i * 2.0) * 0.03
		n.rotation.x = sin(_t * 0.6 + i) * 0.02
