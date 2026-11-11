class_name District
extends Node3D
## Base for the self-building parts of the map: helpers to place baked props
## with simple colliders and to drop in inspectable scenes.

var _body: StaticBody3D


func props_body() -> StaticBody3D:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "PropColliders"
		_body.set_meta(&"surface", &"stone")
		add_child(_body)
	return _body


## The ship model is the same everywhere: a hull whose rail is 1.97 m off the keel at
## midships and tapers to a point at 8.5 m, and a deck that has to sit inside it.
## Measured once from the model, kept here so both the sailing ships and the moored
## one lay the same deck.
const SHIP_HULL_PLAN := [
	[0.0, 1.97], [1.0, 1.93], [2.0, 1.90], [3.0, 1.82],
	[4.0, 1.63], [5.0, 1.34], [6.0, 1.14], [7.0, 0.94],
]
## The deck keeps a hand's width inside the rail and stops short of the points.
const SHIP_DECK_PLAN := [
	[0.0, 1.86], [1.0, 1.82], [2.0, 1.76], [3.0, 1.70],
	[4.0, 1.52], [5.0, 1.22], [6.0, 1.00], [6.5, 0.82],
]
const SHIP_DECK_END := 6.5
const SHIP_DECK_STEP := 0.5
const SHIP_DECK_Y := 0.86


static func _half_beam(plan: Array, x: float) -> float:
	var ax := absf(x)
	for i in plan.size() - 1:
		var a: Array = plan[i]
		var b: Array = plan[i + 1]
		if ax <= float(b[0]):
			var t: float = (ax - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	return float(plan[plan.size() - 1][1])


## Half the hull's beam at a distance from midships.
static func ship_hull_half_beam(x: float) -> float:
	return _half_beam(SHIP_HULL_PLAN, x)


## Half the width of the deck at a distance from midships.
static func ship_deck_half_beam(x: float) -> float:
	return _half_beam(SHIP_DECK_PLAN, minf(absf(x), SHIP_DECK_END))


## A deck that follows the hull instead of a slab laid over it: strips between the
## measured beams, and a transom closing each end so the boat is not a scoop.
## Built in the model's own units, so a scaled ship node scales the deck with it.
## Furls (1) or sets (0) a ship's sail: psx_sail reads it per instance.
static func set_furl(ship: Node3D, amount: float) -> void:
	for g: GeometryInstance3D in ship.find_children("*", "GeometryInstance3D", true, false):
		g.set_instance_shader_parameter(&"furl", clampf(amount, 0.0, 1.0))


func laid_ship_deck(ship: Node3D, deck_y := SHIP_DECK_Y) -> void:
	var kit := MeshKit.new()
	var x := -SHIP_DECK_END
	while x < SHIP_DECK_END - 0.01:
		var x1 := minf(x + SHIP_DECK_STEP, SHIP_DECK_END)
		var w0 := ship_deck_half_beam(x)
		var w1 := ship_deck_half_beam(x1)
		kit.quad("wood", Vector3(x, deck_y, -w0), Vector3(x, deck_y, w0),
				Vector3(x1, deck_y, w1), Vector3(x1, deck_y, -w1))
		x = x1
	for sx: float in [-1.0, 1.0]:
		var ex: float = sx * (SHIP_DECK_END - 0.2)
		var w := ship_deck_half_beam(SHIP_DECK_END - 0.4)
		if sx > 0.0:
			kit.quad("hull", Vector3(ex, deck_y, -w), Vector3(ex, deck_y, w), Vector3(ex, 0.3, w), Vector3(ex, 0.3, -w))
		else:
			kit.quad("hull", Vector3(ex, deck_y, w), Vector3(ex, deck_y, -w), Vector3(ex, 0.3, -w), Vector3(ex, 0.3, w))
	var mi := MeshInstance3D.new()
	mi.name = "Deck"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ship.add_child(mi)


## Instances a baked model. radius > 0 adds an upright cylinder collider.

## Instances a baked model. radius > 0 adds an upright cylinder collider.
func place(model: String, pos: Vector3, yaw_deg: float = 0.0, scale: Vector3 = Vector3.ONE,
		radius: float = 0.0, height: float = 0.0) -> Node3D:
	var n := Props.instance(model)
	n.transform = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(yaw_deg), 0)).scaled(scale), pos)
	add_child(n)
	if radius > 0.0:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		cs.position = pos + Vector3(0, height / 2.0, 0)
		props_body().add_child(cs)
	return n


## Something lost for an errand: hidden until the quest is taken (QuestItem).
func spawn_quest_item(quest: String, pos: Vector3, yaw_deg: float = 0.0) -> QuestItem:
	var q := QuestItem.new()
	q.name = "Quest_" + quest
	q.quest = quest
	q.position = pos
	q.rotation.y = deg_to_rad(yaw_deg)
	add_child(q)
	return q


func spawn_inspectable(id: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var path := "res://scenes/interactables/%s.tscn" % id
	if not ResourceLoader.exists(path):
		push_warning("inspectable scene missing: " + path)
		return null
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	add_child(n)
	return n


## A deck laid over a hull whose own floor is its bottom (the ship model): the
## boat can ride low in the water and still be dry inside. `deck_y` and `size` are
## in the model's units, so a scaled hull gets a scaled deck.
static func min_terrain(center: Vector2, half: Vector2) -> float:
	var m := INF
	for sx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for sz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			m = minf(m, Topo.terrain(center.x + half.x * sx, center.y + half.y * sz))
	return m
