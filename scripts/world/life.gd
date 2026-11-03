extends District
## Small signs that people live here: broken sherds on the street, a basket
## forgotten by a wall, washing drying in a yard, a chopping block with chips
## and a woodpile by the potter's kiln, stone worn pale by centuries of feet,
## and a dog asleep by the stoa. Nothing here has a collider in anyone's way.

const DOG := Vector3(12.9, Topo.AGORA_H, -4.6)  # against the stoa's west end
## Where feet have worn the stone: [centre, size, yaw deg].
const WORN := [
	[Vector3(9.6, Topo.AGORA_H, 0.0), Vector2(2.6, 3.4), 0.0],  # where the street enters the agora
	[Vector3(46.0, Topo.SANCT_H + 0.16, -26.15), Vector2(1.6, 0.26), 0.0],  # the temple's bottom step, before the door
	[Vector3(-82.6, Topo.HILL_PLATFORM_TOP, 0.0), Vector2(2.2, 2.4), 0.0],  # the terrace's edge where the way down starts
]

var _cloths: Array[Node3D] = []
var _t := 0.0


## Stretches of the street paved as a smooth ramp (Arch.path builds stairs
## only where it is steeper than Topo.STAIR_SLOPE): things lie on the paving
## there instead of floating over a step.
static func flat_street_x() -> Array[float]:
	var out: Array[float] = []
	var x := Topo.STREET[0].x + 4.0
	while x < Topo.STREET[-1].x - 4.0:
		if absf(Topo.street_height(x + 0.8) - Topo.street_height(x - 0.8)) / 1.6 < Topo.STAIR_SLOPE * 0.8:
			out.append(x)
			x += 9.0
		else:
			x += 0.5
	return out


static func street_edge(x: float, side: float, inset: float) -> Vector3:
	var dz := Topo.street_z(x + 0.5) - Topo.street_z(x - 0.5)
	var out := Vector3(-dz, 0, 1).normalized() * side
	return Vector3(x, Topo.street_height(x), Topo.street_z(x)) + out * (Topo.STREET_HALF - inset)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2511
	var kit := MeshKit.new()
	var flats := flat_street_x()
	for i in flats.size():
		var x: float = flats[i]
		_sherds(kit, rng, street_edge(x, 1.0 if i % 2 == 0 else -1.0, 0.45))
	_sherds(kit, rng, Vector3(10.4, Topo.AGORA_H, 2.4))
	if flats.size() > 1:
		_basket(kit, street_edge(flats[1] + 2.0, -1.0, 0.3))
	_worn(kit)
	_woodpile(kit, rng)
	add_child(kit.build("Life"))
	_washing()
	var dog := Dog.new()
	dog.position = DOG
	dog.scale = Vector3.ONE * 1.3  # a big yard dog, and readable at 640x360
	dog.rotation.y = deg_to_rad(-100.0)  # along the stoa's end wall, head towards the square
	add_child(dog)


## A broken pot: a scatter of curved red sherds, one with a black-glazed face.
func _sherds(kit: MeshKit, rng: RandomNumberGenerator, at: Vector3) -> void:
	# big enough to read at 640x360: a hand-sized sherd is a few pixels
	for i in rng.randi_range(7, 11):
		var p := at + Vector3(rng.randf_range(-0.55, 0.55), 0.02, rng.randf_range(-0.4, 0.4))
		kit.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), p)
		kit.box("clay" if i % 3 else "redfigure", Vector3.ZERO, Vector3(rng.randf_range(0.12, 0.24), 0.02, rng.randf_range(0.09, 0.17)), [])
	kit.xform = Transform3D.IDENTITY


func _basket(kit: MeshKit, at: Vector3) -> void:
	kit.lathe("basket", PackedVector2Array([Vector2(0.16, 0.0), Vector2(0.21, 0.22), Vector2(0.22, 0.26)]), 8, at, 2.0, true, "basket")
	kit.box("basket", at + Vector3(0, 0.36, 0), Vector3(0.36, 0.03, 0.03), [])  # handle
	for s: float in [1.0, -1.0]:
		kit.box("basket", at + Vector3(0.17 * s, 0.31, 0), Vector3(0.03, 0.1, 0.03), [])


## Stone worn smooth: pale cut-out patches a hair above the paving.
func _worn(kit: MeshKit) -> void:
	for w: Array in WORN:
		var c: Vector3 = w[0]
		var size: Vector2 = w[1]
		kit.xform = Transform3D(Basis(Vector3.UP, deg_to_rad(w[2])), c + Vector3(0, 0.012, 0))
		var hx := size.x / 2.0
		var hz := size.y / 2.0
		kit.quad("worn", Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz),
				PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
	kit.xform = Transform3D.IDENTITY


## Firewood for the kiln: a stack of split logs, a chopping block with an axe
## mark, and pale chips and shavings scattered round it.
func _woodpile(kit: MeshKit, rng: RandomNumberGenerator) -> void:
	var y := Topo.AGORA_H
	var block := Vector3(19.5, y, 8.1)
	kit.lathe("bark", PackedVector2Array([Vector2(0.22, 0.0), Vector2(0.21, 0.42)]), 7, block, 1.0, false, "wood", true)
	kit.add_collider(block + Vector3(0, 0.21, 0), Vector3(0.44, 0.42, 0.44))
	for i in 18:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(0.3, 0.9)
		var p := block + Vector3(cos(a) * r, 0.01, sin(a) * r)
		kit.xform = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), p)
		kit.box("wood", Vector3.ZERO, Vector3(rng.randf_range(0.05, 0.14), 0.012, rng.randf_range(0.02, 0.05)), [])
	kit.xform = Transform3D.IDENTITY
	# split logs stacked against the shed's back wall, east of the kiln
	var base := Vector3(19.6, y, 10.0)
	for row in 3:
		for i in 4 - row:
			var p := base + Vector3((i - (3 - row) / 2.0) * 0.24, 0.11 + row * 0.19, 0)
			kit.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), p)
			kit.lathe("bark", PackedVector2Array([Vector2(0.1, -0.45), Vector2(0.1, 0.45)]), 5, Vector3.ZERO, 1.0, false, "wood", true)
	kit.xform = Transform3D.IDENTITY
	kit.add_collider(base + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.9))


## Washing on a line across the second courtyard on the street, stirring a little.
func _washing() -> void:
	var street: Node = get_parent().get_node_or_null("Street")
	if street == null or street.courtyards.size() < 2:
		return
	var xf: Transform3D = street.courtyards[1]
	var line := MeshKit.new()
	line.xform = xf
	for sx: float in [-1.9, 1.9]:
		line.box("wood", Vector3(sx, 1.0, -3.2), Vector3(0.08, 2.0, 0.08), ["bottom"])
	line.box("dark", Vector3(0, 1.92, -3.2), Vector3(3.8, 0.02, 0.02), [])
	add_child(line.build("WashingLine"))
	var mats := ["chiton", "cloth", "chiton_dark"]
	for i in 3:
		var pivot := Node3D.new()
		pivot.transform = xf * Transform3D(Basis.IDENTITY, Vector3(-1.2 + i * 1.2, 1.92, -3.2))
		add_child(pivot)
		var k := MeshKit.new()
		var w := 0.45 + 0.1 * (i % 2)
		var h := 0.9 - 0.15 * i
		k.quad(mats[i], Vector3(-w, -h, 0), Vector3(w, -h, 0), Vector3(w, 0, 0), Vector3(-w, 0, 0))
		k.quad(mats[i], Vector3(w, -h, 0), Vector3(-w, -h, 0), Vector3(-w, 0, 0), Vector3(w, 0, 0))
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		pivot.add_child(mi)
		_cloths.append(pivot)


func _process(delta: float) -> void:
	_t += delta
	var q := floorf(_t * 15.0) / 15.0
	for i in _cloths.size():
		_cloths[i].rotation.x = sin(q * 1.3 + i * 1.7) * 0.12
